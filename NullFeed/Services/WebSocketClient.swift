import Foundation

enum WebSocketEventType: String, Sendable {
    case downloadProgress = "download_progress"
    case downloadComplete = "download_complete"
    case previewReady = "preview_ready"
    case newEpisode = "new_episode"
    case progressUpdated = "progress_updated"
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
    private let api: APIClient
    private var task: URLSessionWebSocketTask?
    /// The in-flight connect attempt (ticket fetch + open, or a scheduled
    /// reconnect), cancelled by `disconnect()` so a teardown can't be raced by a
    /// socket that was still being opened.
    private var connectTask: Task<Void, Never>?
    private var serverUrl: String?
    private var userId: String?
    private(set) var isConnected = false

    init(api: APIClient) {
        self.api = api
    }

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

    func connect(serverUrl: String, userId: String) {
        disconnect()
        self.serverUrl = serverUrl
        self.userId = userId
        doConnect()
    }

    func disconnect() {
        connectTask?.cancel()
        connectTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
        serverUrl = nil
        userId = nil
    }

    /// Open the socket after fetching a WS ticket to authenticate it. The fetch
    /// is async, so this hops onto a task and opens the socket once the ticket
    /// lands; `forceTicketRefresh` (set on reconnect) bypasses the cached ticket
    /// so a dropped-and-restored socket never reuses a stale credential.
    private func doConnect(forceTicketRefresh: Bool = false) {
        guard let serverUrl, let userId else { return }
        connectTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let ticket: String
            do {
                ticket = try await self.api.wsTicket(forceRefresh: forceTicketRefresh)
            } catch {
                // No ticket means the server would just reject the socket, so
                // don't open one -- back off and retry rather than wedge silently.
                guard !Task.isCancelled, self.serverUrl == serverUrl else { return }
                self.scheduleReconnect()
                return
            }
            // connect()/disconnect() may have moved on while the ticket was in
            // flight; only open if this attempt is still the current one.
            guard !Task.isCancelled, self.serverUrl == serverUrl, self.userId == userId else { return }
            self.openSocket(serverUrl: serverUrl, userId: userId, ticket: ticket)
        }
    }

    private func openSocket(serverUrl: String, userId: String, ticket: String) {
        let wsScheme = serverUrl.hasPrefix("https") ? "wss" : "ws"
        let host = serverUrl
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
        let path = AppConstants.websocket(userId)
        guard var components = URLComponents(string: "\(wsScheme)://\(host)\(path)") else { return }
        // The backend closes the socket with code 4401 unless a valid ticket is
        // supplied as a query parameter.
        components.queryItems = [URLQueryItem(name: "ticket", value: ticket)]
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
        connectTask?.cancel()
        connectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard let self, !Task.isCancelled, self.serverUrl != nil else { return }
            // Reconnect with a fresh ticket -- the prior one may be spent or aged.
            self.doConnect(forceTicketRefresh: true)
        }
    }
}
