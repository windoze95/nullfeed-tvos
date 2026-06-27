import Foundation

enum WebSocketEventType: String, Sendable {
    case downloadProgress = "download_progress"
    case downloadComplete = "download_complete"
    case previewReady = "preview_ready"
    case newEpisode = "new_episode"
    case recommendationReady = "recommendation_ready"
    case unknown
}

struct WebSocketEvent: Sendable {
    let type: WebSocketEventType
    let videoId: String?
    let percentage: Double?

    init(type: WebSocketEventType, videoId: String? = nil, percentage: Double? = nil) {
        self.type = type
        self.videoId = videoId
        self.percentage = percentage
    }

    static func from(json: [String: Any]) -> WebSocketEvent {
        let typeStr = json["type"] as? String ?? ""
        let data = json["data"] as? [String: Any] ?? [:]
        let eventType = WebSocketEventType(rawValue: typeStr) ?? .unknown
        let videoId = data["video_id"] as? String
        // Backend sends download progress under the key `percentage` (0-100).
        let percentage = data["percentage"] as? Double
        return WebSocketEvent(type: eventType, videoId: videoId, percentage: percentage)
    }
}

@MainActor
@Observable
final class WebSocketClient {
    private var task: URLSessionWebSocketTask?
    private var serverUrl: String?
    private var userId: String?
    private var token: String?
    private(set) var isConnected = false

    // Each observer (player, feeds, ...) gets its own stream so events are
    // broadcast to all of them rather than competing for a single stream.
    private var subscribers: [UUID: AsyncStream<WebSocketEvent>.Continuation] = [:]

    /// Subscribe to the live event stream. Every subscriber receives every event.
    /// The subscription ends (and is cleaned up) when the consuming task is
    /// cancelled or the returned stream is dropped.
    func subscribe() -> AsyncStream<WebSocketEvent> {
        var continuation: AsyncStream<WebSocketEvent>.Continuation!
        let stream = AsyncStream<WebSocketEvent> { continuation = $0 }
        let id = UUID()
        subscribers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.removeSubscriber(id) }
        }
        return stream
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers[id] = nil
    }

    func connect(serverUrl: String, userId: String, token: String?) {
        disconnect()
        self.serverUrl = serverUrl
        self.userId = userId
        self.token = token
        doConnect()
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
        serverUrl = nil
        userId = nil
        token = nil
    }

    private func doConnect() {
        guard let serverUrl, let userId else { return }

        let wsScheme = serverUrl.hasPrefix("https") ? "wss" : "ws"
        let host = serverUrl
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
        let path = AppConstants.websocket(userId)
        guard var components = URLComponents(string: "\(wsScheme)://\(host)\(path)") else { return }
        // The backend closes the socket with code 4401 unless a valid session
        // token is supplied as a query parameter.
        if let token, !token.isEmpty {
            components.queryItems = [URLQueryItem(name: "token", value: token)]
        }
        guard let url = components.url else { return }

        let wsTask = URLSession.shared.webSocketTask(with: url)
        self.task = wsTask
        wsTask.resume()
        isConnected = true
        receiveMessage()
    }

    private func receiveMessage() {
        guard let task else { return }
        task.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let message):
                    self.handleMessage(message)
                    self.receiveMessage()
                case .failure:
                    self.isConnected = false
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let jsonString: String
        switch message {
        case .string(let text):
            jsonString = text
        case .data(let data):
            guard let text = String(data: data, encoding: .utf8) else { return }
            jsonString = text
        @unknown default:
            return
        }

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        broadcast(WebSocketEvent.from(json: json))
    }

    private func broadcast(_ event: WebSocketEvent) {
        for continuation in subscribers.values {
            continuation.yield(event)
        }
    }

    private func scheduleReconnect() {
        task = nil
        isConnected = false
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard let self, self.serverUrl != nil else { return }
            self.doConnect()
        }
    }
}
