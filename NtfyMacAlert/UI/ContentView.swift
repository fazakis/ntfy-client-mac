import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: NtfyClientViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            SettingsView()

            Divider()

            lastAlertPreview

            HStack {
                Text("Received alerts")
                    .font(.headline)

                Spacer()

                Text("\(viewModel.receivedMessages.count)")
                    .foregroundStyle(.secondary)

                Button("Clear Alerts") {
                    viewModel.clearAlerts()
                }
                .disabled(viewModel.receivedMessages.isEmpty)
            }

            alertList
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 620)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.and.waves.left.and.right.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("NtfyMacAlert")
                    .font(.title2.bold())

                Text("Native macOS alerts from ntfy.sh topics")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusIndicator(status: viewModel.status)
        }
    }

    @ViewBuilder
    private var lastAlertPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last alert")
                .font(.headline)

            if let lastMessage = viewModel.lastMessage {
                AlertRowView(message: lastMessage, compact: true)
            } else {
                Text("No alerts received yet. Connect to a topic, then publish a test message.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var alertList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if viewModel.receivedMessages.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Alerts will appear here.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    ForEach(viewModel.receivedMessages) { message in
                        AlertRowView(message: message)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct StatusIndicator: View {
    let status: ConnectionStatus

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(status.label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(statusTextColor)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }

    private var color: Color {
        switch status {
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

    private var statusTextColor: Color {
        if case .error = status {
            return .red
        }
        return .primary
    }
}

#Preview {
    ContentView()
        .environmentObject(NtfyClientViewModel())
}
