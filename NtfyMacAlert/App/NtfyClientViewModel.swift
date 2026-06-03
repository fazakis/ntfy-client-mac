import Combine
import Foundation

@MainActor
final class NtfyClientViewModel: ObservableObject {
    @Published var serverURL: String {
        didSet { settingsStore.serverURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    @Published var topic: String {
        didSet { settingsStore.topic = topic.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    @Published var token: String {
        didSet { keychainStore.saveToken(token) }
    }

    @Published var status: ConnectionStatus = .disconnected
    @Published var receivedMessages: [NtfyMessage] = []
    @Published var notificationPermissionStatus: NotificationPermissionStatus = .unknown
    @Published var launchAtLoginEnabled = false
    @Published var launchAtLoginStatus = "Disabled"
    @Published var launchAtLoginError: String?
    @Published var soundEnabled: Bool {
        didSet { settingsStore.soundEnabled = soundEnabled }
    }

    private let streamClient = NtfyStreamClient()
    private let notificationManager = NotificationManager()
    private let soundManager = SoundManager()
    private let launchAtLoginManager = LaunchAtLoginManager()
    private let settingsStore: SettingsStore
    private let keychainStore: KeychainStore

    private var streamTask: Task<Void, Never>?
    private var activeConnectionID: UUID?
    private var shouldReconnect = false
    private var currentAttemptConnected = false

    var lastMessage: NtfyMessage? {
        receivedMessages.first
    }

    var isConnectedOrConnecting: Bool {
        status.isRunning
    }

    init(settingsStore: SettingsStore = SettingsStore(), keychainStore: KeychainStore = KeychainStore()) {
        self.settingsStore = settingsStore
        self.keychainStore = keychainStore
        self.serverURL = settingsStore.serverURL
        self.topic = settingsStore.topic
        self.soundEnabled = settingsStore.soundEnabled
        self.token = keychainStore.readToken() ?? ""
        refreshLaunchAtLoginStatus()

        Task { [weak self] in
            await self?.finishLaunch()
        }
    }

    func connect() {
        let trimmedServerURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTopic.isEmpty else {
            status = .error("Topic/channel cannot be empty.")
            return
        }

        serverURL = trimmedServerURL.isEmpty ? "https://ntfy.sh" : trimmedServerURL
        topic = trimmedTopic
        token = trimmedToken
        settingsStore.reconnectOnLaunch = true

        streamTask?.cancel()

        let connectionID = UUID()
        let serverToUse = serverURL
        activeConnectionID = connectionID
        shouldReconnect = true
        status = .connecting

        streamTask = Task { [weak self] in
            await self?.runConnectionLoop(
                connectionID: connectionID,
                serverURL: serverToUse,
                topic: trimmedTopic,
                token: trimmedToken
            )
        }
    }

    func disconnect() {
        settingsStore.reconnectOnLaunch = false
        shouldReconnect = false
        activeConnectionID = nil
        streamTask?.cancel()
        streamTask = nil
        status = .disconnected
    }

    func clearAlerts() {
        receivedMessages.removeAll()
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        launchAtLoginError = nil

        do {
            try launchAtLoginManager.setEnabled(enabled)
        } catch {
            launchAtLoginError = error.localizedDescription
        }

        refreshLaunchAtLoginStatus()
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = launchAtLoginManager.isEnabled
        launchAtLoginStatus = launchAtLoginManager.statusLabel
    }

    func testSound() {
        soundManager.play()
    }

    func refreshNotificationPermissionStatus() {
        Task { [weak self] in
            guard let self else { return }
            notificationPermissionStatus = await notificationManager.permissionStatus()
        }
    }

    func requestNotificationPermission() {
        Task { [weak self] in
            guard let self else { return }
            notificationPermissionStatus = await notificationManager.requestAuthorization()
        }
    }

    func openNotificationSettings() {
        notificationManager.openSystemNotificationSettings()
    }

    func testNotification() {
        let testMessage = NtfyMessage(
            id: "test-\(UUID().uuidString)",
            time: Int(Date().timeIntervalSince1970),
            event: "message",
            topic: topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "test" : topic.trimmingCharacters(in: .whitespacesAndNewlines),
            title: "NtfyMacAlert test",
            message: "If you see this bubble, macOS notifications are working for this app.",
            priority: nil,
            tags: ["test"]
        )

        Task { [weak self] in
            guard let self else { return }
            await notificationManager.show(message: testMessage)
            notificationPermissionStatus = await notificationManager.permissionStatus()
        }
    }

    private func finishLaunch() async {
        await requestNotificationPermissionIfNeeded()
        reconnectOnLaunchIfNeeded()
    }

    private func requestNotificationPermissionIfNeeded() async {
        notificationPermissionStatus = await notificationManager.permissionStatus()

        if notificationPermissionStatus == .notDetermined {
            notificationPermissionStatus = await notificationManager.requestAuthorization()
        }
    }

    private func reconnectOnLaunchIfNeeded() {
        guard settingsStore.reconnectOnLaunch else { return }
        guard !isConnectedOrConnecting else { return }

        let savedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !savedTopic.isEmpty else {
            settingsStore.reconnectOnLaunch = false
            return
        }

        connect()
    }

    private func runConnectionLoop(connectionID: UUID, serverURL: String, topic: String, token: String) async {
        let backoffSeconds = [1, 2, 5, 10, 30]
        var backoffIndex = 0

        while isCurrentConnection(connectionID), shouldReconnect, !Task.isCancelled {
            if backoffIndex == 0 {
                status = .connecting
            } else {
                status = .reconnecting
            }

            currentAttemptConnected = false

            do {
                try await streamClient.subscribe(
                    serverURL: serverURL,
                    topic: topic,
                    token: token,
                    onConnected: { [weak self] in
                        await self?.markConnected(connectionID: connectionID)
                    },
                    onMessage: { [weak self] message in
                        await self?.handleIncomingMessage(message, connectionID: connectionID)
                    }
                )

                if isCurrentConnection(connectionID), shouldReconnect, !Task.isCancelled {
                    status = .reconnecting
                }
            } catch is CancellationError {
                break
            } catch let error as NtfyStreamClientError {
                guard isCurrentConnection(connectionID), shouldReconnect, !Task.isCancelled else { break }
                status = .error(error.localizedDescription)

                if error.shouldStopReconnecting {
                    settingsStore.reconnectOnLaunch = false
                    shouldReconnect = false
                    break
                }
            } catch {
                guard isCurrentConnection(connectionID), shouldReconnect, !Task.isCancelled else { break }
                status = .error(error.localizedDescription)
            }

            guard isCurrentConnection(connectionID), shouldReconnect, !Task.isCancelled else { break }

            if currentAttemptConnected {
                backoffIndex = 0
            }

            let delay = backoffSeconds[min(backoffIndex, backoffSeconds.count - 1)]
            backoffIndex += 1
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
        }

        if isCurrentConnection(connectionID) {
            if case .error = status {
                // Keep the actionable error visible instead of replacing it with
                // "Disconnected" after a permanent connection failure.
            } else {
                status = .disconnected
            }
            activeConnectionID = nil
            streamTask = nil
        }
    }

    private func markConnected(connectionID: UUID) {
        guard isCurrentConnection(connectionID) else { return }
        currentAttemptConnected = true
        status = .connected
    }

    private func handleIncomingMessage(_ message: NtfyMessage, connectionID: UUID) async {
        guard isCurrentConnection(connectionID) else { return }

        receivedMessages.insert(message, at: 0)
        if receivedMessages.count > 500 {
            receivedMessages.removeLast(receivedMessages.count - 500)
        }

        if soundEnabled {
            soundManager.play()
        }

        await notificationManager.show(message: message)
    }

    private func isCurrentConnection(_ connectionID: UUID) -> Bool {
        activeConnectionID == connectionID
    }
}
