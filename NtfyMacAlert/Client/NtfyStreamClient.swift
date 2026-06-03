import Foundation

enum NtfyStreamClientError: LocalizedError {
    case invalidServerURL
    case invalidTopic
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "Enter a valid http or https ntfy server URL."
        case .invalidTopic:
            return "Enter a topic/channel name before connecting."
        case .invalidResponse:
            return "The ntfy server returned an invalid response."
        case .httpError(let statusCode):
            return "The ntfy server returned HTTP \(statusCode)."
        }
    }

    var shouldStopReconnecting: Bool {
        switch self {
        case .invalidServerURL, .invalidTopic:
            return true
        case .httpError(let statusCode):
            return [400, 401, 403, 404].contains(statusCode)
        case .invalidResponse:
            return false
        }
    }
}

struct NtfyStreamClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    func subscribe(
        serverURL: String,
        topic: String,
        token: String?,
        onConnected: @escaping @Sendable () async -> Void,
        onMessage: @escaping @Sendable (NtfyMessage) async -> Void
    ) async throws {
        let trimmedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTopic.isEmpty else { throw NtfyStreamClientError.invalidTopic }

        let request = try makeSubscribeRequest(serverURL: serverURL, topic: trimmedTopic, token: token)
        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NtfyStreamClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NtfyStreamClientError.httpError(httpResponse.statusCode)
        }

        await onConnected()

        // ntfy's /json endpoint is a newline-delimited JSON stream. URLSession's
        // AsyncBytes.lines lets us process one complete JSON object at a time
        // without buffering the whole connection or blocking the main thread.
        for try await line in bytes.lines {
            try Task.checkCancellation()

            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }

            guard let data = trimmedLine.data(using: .utf8) else { continue }

            // Keepalive/open events and rare malformed lines should not crash or
            // tear down a healthy stream. Network/server failures still throw.
            guard let decoded = try? decoder.decode(NtfyMessage.self, from: data) else { continue }
            guard decoded.isUserMessage else { continue }

            await onMessage(decoded.replacingMissingTopic(with: trimmedTopic))
        }
    }

    private func makeSubscribeRequest(serverURL: String, topic: String, token: String?) throws -> URLRequest {
        let trimmedServer = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmedServer),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host?.isEmpty == false else {
            throw NtfyStreamClientError.invalidServerURL
        }

        var topicAllowedCharacters = CharacterSet.urlPathAllowed
        topicAllowedCharacters.remove(charactersIn: "/")
        let encodedTopic = topic.addingPercentEncoding(withAllowedCharacters: topicAllowedCharacters) ?? topic
        var path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        path = path.isEmpty ? "\(encodedTopic)/json" : "\(path)/\(encodedTopic)/json"
        components.path = "/\(path)"
        components.query = nil
        components.fragment = nil

        guard let url = components.url else { throw NtfyStreamClientError.invalidServerURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")

        let trimmedToken = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedToken, !trimmedToken.isEmpty {
            request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
        }

        return request
    }
}
