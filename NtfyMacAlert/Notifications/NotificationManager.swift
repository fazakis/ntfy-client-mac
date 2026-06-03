import AppKit
import Foundation
import UserNotifications

enum NotificationPermissionStatus: Equatable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
    case unknown

    init(_ authorizationStatus: UNAuthorizationStatus) {
        switch authorizationStatus {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        case .provisional:
            self = .provisional
        case .ephemeral:
            self = .ephemeral
        @unknown default:
            self = .unknown
        }
    }

    var label: String {
        switch self {
        case .notDetermined:
            return "Not requested"
        case .denied:
            return "Denied"
        case .authorized:
            return "Allowed"
        case .provisional:
            return "Provisionally allowed"
        case .ephemeral:
            return "Temporarily allowed"
        case .unknown:
            return "Unknown"
        }
    }

    var helpText: String {
        switch self {
        case .notDetermined:
            return "Click Request Notifications, or wait for the first alert/test notification."
        case .denied:
            return "macOS will not show bubbles until notifications are enabled in System Settings."
        case .authorized:
            return "macOS notifications are allowed. If bubbles still do not appear, check banner/list style and Focus mode."
        case .provisional, .ephemeral:
            return "Notifications are allowed in a limited mode. Enable full banners in System Settings if needed."
        case .unknown:
            return "Refresh the status or check macOS System Settings → Notifications."
        }
    }

    var allowsNotificationDelivery: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied, .unknown:
            return false
        }
    }

    var canRequestFromApp: Bool {
        self == .notDetermined
    }
}

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func permissionStatus() async -> NotificationPermissionStatus {
        let settings = await center.notificationSettings()
        return NotificationPermissionStatus(settings.authorizationStatus)
    }

    @discardableResult
    func requestAuthorization() async -> NotificationPermissionStatus {
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        return await permissionStatus()
    }

    func openSystemNotificationSettings() {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "gr.fazakis.NtfyMacAlert"
        let urlStrings = [
            "x-apple.systempreferences:com.apple.preference.notifications?id=\(bundleIdentifier)",
            "x-apple.systempreferences:com.apple.preference.notifications",
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
        ]

        for urlString in urlStrings {
            guard let url = URL(string: urlString) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    func show(message: NtfyMessage) async {
        var permissionStatus = await permissionStatus()

        if permissionStatus == .notDetermined {
            permissionStatus = await requestAuthorization()
        }

        guard permissionStatus.allowsNotificationDelivery else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = notificationTitle(for: message)
        content.body = message.displayBody
        content.threadIdentifier = message.topic ?? "ntfy"

        if let topic = message.topic, !topic.isEmpty {
            content.subtitle = topic
        }

        if let click = message.click {
            content.userInfo["click"] = click
        }

        // The app plays its own bundled characteristic sound via NSSound. We still
        // present the native banner/list entry here, including while the menu-bar
        // popover is open, but avoid adding a second default notification sound.
        let request = UNNotificationRequest(
            identifier: "ntfy-\(message.id)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            print("NtfyMacAlert notification delivery failed: \(error.localizedDescription)")
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    private func notificationTitle(for message: NtfyMessage) -> String {
        if let title = message.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }

        if let topic = message.topic?.trimmingCharacters(in: .whitespacesAndNewlines), !topic.isEmpty {
            return "ntfy: \(topic)"
        }

        return "ntfy message"
    }
}
