import AppKit
import SwiftUI

@main
struct NtfyMacAlertApp: App {
    @StateObject private var viewModel = NtfyClientViewModel()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: 0) {
                ContentView()
                    .environmentObject(viewModel)

                Divider()

                HStack {
                    statusSummary

                    Spacer()

                    Button("Quit NtfyMacAlert") {
                        NSApplication.shared.terminate(nil)
                    }
                    .keyboardShortcut("q", modifiers: [.command])
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        } label: {
            Label(menuBarTitle, systemImage: menuBarIconName)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarTitle: String {
        if viewModel.receivedMessages.isEmpty {
            return "NtfyMacAlert"
        }
        return "NtfyMacAlert (\(viewModel.receivedMessages.count))"
    }

    private var menuBarIconName: String {
        switch viewModel.status {
        case .connected:
            return "bell.and.waves.left.and.right.fill"
        case .connecting, .reconnecting:
            return "bell.badge.fill"
        case .error:
            return "bell.badge.fill"
        case .disconnected:
            return "bell"
        }
    }

    private var statusSummary: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(viewModel.status.label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var statusColor: Color {
        switch viewModel.status {
        case .connected:
            return .green
        case .connecting, .reconnecting:
            return .orange
        case .error:
            return .red
        case .disconnected:
            return .secondary
        }
    }
}
