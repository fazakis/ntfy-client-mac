import SwiftUI

struct AlertRowView: View {
    let message: NtfyMessage
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            HStack(spacing: 8) {
                Text(message.receivedAt, format: .dateTime.hour().minute().second())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                if let topic = message.topic, !topic.isEmpty {
                    Pill(text: topic, systemImage: "number", color: .blue)
                }

                if let priority = message.priority {
                    Pill(text: "P\(priority)", systemImage: "flag.fill", color: priorityColor(priority))
                }

                Spacer(minLength: 8)
            }

            if let title = message.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(title)
                    .font(compact ? .callout.bold() : .headline)
            }

            Text(message.displayBody)
                .font(compact ? .callout : .body)
                .foregroundStyle(.primary)
                .lineLimit(compact ? 2 : 4)
                .textSelection(.enabled)

            if let tags = message.tags, !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Pill(text: tag, systemImage: "tag", color: .purple)
                    }
                }
            }
        }
        .padding(compact ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    private func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 1...2:
            return .secondary
        case 4:
            return .orange
        case 5...:
            return .red
        default:
            return .green
        }
    }
}

private struct Pill: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }
}

#Preview {
    AlertRowView(
        message: NtfyMessage(
            id: "preview",
            time: Int(Date().timeIntervalSince1970),
            event: "message",
            topic: "my-test-topic-123",
            title: "Server alert",
            message: "Hello from ntfy",
            priority: 4,
            tags: ["warning", "mac"]
        )
    )
    .padding()
}
