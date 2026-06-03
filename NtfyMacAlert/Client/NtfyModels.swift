import Foundation

struct NtfyAttachment: Codable, Equatable {
    let name: String?
    let type: String?
    let size: Int?
    let expires: Int?
    let url: String?
}

struct NtfyMessage: Identifiable, Codable, Equatable {
    let id: String
    let time: Int?
    let event: String?
    let topic: String?
    let title: String?
    let message: String?
    let priority: Int?
    let tags: [String]?
    let click: String?
    let attachment: NtfyAttachment?
    let receivedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case time
        case event
        case topic
        case title
        case message
        case priority
        case tags
        case click
        case attachment
        case receivedAt
    }

    init(
        id: String,
        time: Int? = nil,
        event: String? = nil,
        topic: String? = nil,
        title: String? = nil,
        message: String? = nil,
        priority: Int? = nil,
        tags: [String]? = nil,
        click: String? = nil,
        attachment: NtfyAttachment? = nil,
        receivedAt: Date = Date()
    ) {
        self.id = id
        self.time = time
        self.event = event
        self.topic = topic
        self.title = title
        self.message = message
        self.priority = priority
        self.tags = tags
        self.click = click
        self.attachment = attachment
        self.receivedAt = receivedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.time = try container.decodeIfPresent(Int.self, forKey: .time)
        self.event = try container.decodeIfPresent(String.self, forKey: .event)
        self.topic = try container.decodeIfPresent(String.self, forKey: .topic)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.message = try container.decodeIfPresent(String.self, forKey: .message)
        self.priority = try container.decodeIfPresent(Int.self, forKey: .priority)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags)
        self.click = try container.decodeIfPresent(String.self, forKey: .click)
        self.attachment = try container.decodeIfPresent(NtfyAttachment.self, forKey: .attachment)
        self.receivedAt = try container.decodeIfPresent(Date.self, forKey: .receivedAt) ?? Date()
    }

    var isUserMessage: Bool {
        event == nil || event == "message"
    }

    var displayTitle: String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedTitle, !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        let trimmedTopic = topic?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedTopic, !trimmedTopic.isEmpty {
            return "ntfy alert: \(trimmedTopic)"
        }

        return "ntfy alert"
    }

    var displayBody: String {
        let trimmedMessage = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedMessage, !trimmedMessage.isEmpty {
            return trimmedMessage
        }
        return "(No message body)"
    }

    func replacingMissingTopic(with fallbackTopic: String) -> NtfyMessage {
        guard topic?.isEmpty != false else { return self }
        return NtfyMessage(
            id: id,
            time: time,
            event: event,
            topic: fallbackTopic,
            title: title,
            message: message,
            priority: priority,
            tags: tags,
            click: click,
            attachment: attachment,
            receivedAt: receivedAt
        )
    }
}

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case error(String)

    var label: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .reconnecting:
            return "Reconnecting"
        case .error(let message):
            return "Error: \(message)"
        }
    }

    var isRunning: Bool {
        switch self {
        case .connecting, .connected, .reconnecting:
            return true
        case .disconnected, .error:
            return false
        }
    }
}
