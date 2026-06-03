import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: NtfyClientViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Server URL")
                        .foregroundStyle(.secondary)
                    TextField("https://ntfy.sh", text: $viewModel.serverURL)
                        .textFieldStyle(.roundedBorder)
                        .disabled(viewModel.isConnectedOrConnecting)
                }

                GridRow {
                    Text("Topic/channel")
                        .foregroundStyle(.secondary)
                    TextField("my-test-topic-123", text: $viewModel.topic)
                        .textFieldStyle(.roundedBorder)
                        .disabled(viewModel.isConnectedOrConnecting)
                }

                GridRow {
                    Text("Access token")
                        .foregroundStyle(.secondary)
                    SecureField("Optional bearer token", text: $viewModel.token)
                        .textFieldStyle(.roundedBorder)
                        .disabled(viewModel.isConnectedOrConnecting)
                }
            }

            HStack(spacing: 12) {
                Button(viewModel.isConnectedOrConnecting ? "Disconnect" : "Connect") {
                    if viewModel.isConnectedOrConnecting {
                        viewModel.disconnect()
                    } else {
                        viewModel.connect()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)

                Toggle("Sound enabled", isOn: $viewModel.soundEnabled)
                    .toggleStyle(.switch)

                Button("Test Sound") {
                    viewModel.testSound()
                }

                Button("Test Notification") {
                    viewModel.testNotification()
                }

                Spacer()
            }

            launchAtLoginRow

            notificationPermissionRow

            if case .error(let message) = viewModel.status {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            viewModel.refreshLaunchAtLoginStatus()
            viewModel.refreshNotificationPermissionStatus()
        }
    }

    private var launchAtLoginRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Toggle("Open at login", isOn: Binding(
                    get: { viewModel.launchAtLoginEnabled },
                    set: { viewModel.setLaunchAtLoginEnabled($0) }
                ))
                .toggleStyle(.switch)

                Spacer()

                Text(viewModel.launchAtLoginStatus)
                    .font(.caption)
                    .foregroundStyle(viewModel.launchAtLoginEnabled ? Color.green : Color.secondary)

                Button("Refresh") {
                    viewModel.refreshLaunchAtLoginStatus()
                }
            }

            Text("Start NtfyMacAlert automatically when you log in. If macOS says approval is required, enable it in System Settings → General → Login Items.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let launchAtLoginError = viewModel.launchAtLoginError {
                Label(launchAtLoginError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(10)
        .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    private var notificationPermissionRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Label("Notifications: \(viewModel.notificationPermissionStatus.label)", systemImage: notificationPermissionIcon)
                    .foregroundStyle(notificationPermissionColor)
                    .font(.callout.weight(.medium))

                Spacer()

                if viewModel.notificationPermissionStatus.canRequestFromApp {
                    Button("Request Notifications") {
                        viewModel.requestNotificationPermission()
                    }
                }

                Button("Open Notification Settings") {
                    viewModel.openNotificationSettings()
                }

                Button("Refresh") {
                    viewModel.refreshNotificationPermissionStatus()
                }
            }

            Text(viewModel.notificationPermissionStatus.helpText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    private var notificationPermissionIcon: String {
        switch viewModel.notificationPermissionStatus {
        case .authorized, .provisional, .ephemeral:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined, .unknown:
            return "questionmark.circle.fill"
        }
    }

    private var notificationPermissionColor: Color {
        switch viewModel.notificationPermissionStatus {
        case .authorized, .provisional, .ephemeral:
            return .green
        case .denied:
            return .red
        case .notDetermined, .unknown:
            return .orange
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(NtfyClientViewModel())
        .padding()
}
