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
    let progress: Double?

    init(type: WebSocketEventType, videoId: String? = nil, progress: Double? = nil) {
        self.type = type
        self.videoId = videoId
        self.progress = progress
    }

    static func from(json: [String: Any]) -> WebSocketEvent {
        let typeStr = json["type"] as? String ?? ""
        let data = json["data"] as? [String: Any] ?? [:]
        let eventType: WebSocketEventType
        switch typeStr {
        case "download_progress": eventType = .downloadProgress
        case "download_complete": eventType = .downloadComplete
        case "preview_ready": eventType = .previewReady
        case "new_episode": eventType = .newEpisode
        case "recommendation_ready": eventType = .recommendationReady
        default: eventType = .unknown
        }
        let videoId = data["video_id"] as? String
        let progress = data["progress"] as? Double
        return WebSocketEvent(type: eventType, videoId: videoId, progress: progress)
    }
}

@MainActor
@Observable
final class WebSocketClient {
    private var task: URLSessionWebSocketTask?
    private var serverUrl: String?
    private var userId: String?
    private(set) var isConnected = false

    private var continuation: AsyncStream<WebSocketEvent>.Continuation?
    private(set) var events: AsyncStream<WebSocketEvent>

    init() {
        var cont: AsyncStream<WebSocketEvent>.Continuation?
        events = AsyncStream { cont = $0 }
        continuation = cont
    }

    func connect(serverUrl: String, userId: String) {
        disconnect()
        self.serverUrl = serverUrl
        self.userId = userId
        doConnect()
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
        serverUrl = nil
        userId = nil
    }

    private func doConnect() {
        guard let serverUrl, let userId else { return }

        let wsScheme = serverUrl.hasPrefix("https") ? "wss" : "ws"
        let host = serverUrl
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
        let path = AppConstants.websocket(userId)
        guard let url = URL(string: "\(wsScheme)://\(host)\(path)") else { return }

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

        let event = WebSocketEvent.from(json: json)
        continuation?.yield(event)
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

    private func resetStream() {
        continuation?.finish()
        var cont: AsyncStream<WebSocketEvent>.Continuation?
        events = AsyncStream { cont = $0 }
        continuation = cont
    }

}
