import Foundation

@MainActor
@Observable
final class APIClient {
    private let session = URLSession.shared
    private let storage: StorageService

    init(storage: StorageService) {
        self.storage = storage
    }

    private var baseURL: String {
        storage.serverUrl ?? "http://localhost:8484"
    }

    // MARK: - HTTP Helpers

    private func buildRequest(_ method: String, path: String, body: [String: Any]? = nil) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = storage.sessionToken {
            request.setValue(token, forHTTPHeaderField: "X-User-Token")
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.requestFailed
        }
        return data
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try buildRequest("GET", path: path)
        let data = try await perform(request)
        return try JSONDecoder.nullFeed.decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any]? = nil) async throws -> T {
        let request = try buildRequest("POST", path: path, body: body)
        let data = try await perform(request)
        return try JSONDecoder.nullFeed.decode(T.self, from: data)
    }

    private func postVoid(_ path: String, body: [String: Any]? = nil) async throws {
        let request = try buildRequest("POST", path: path, body: body)
        _ = try await perform(request)
    }

    private func putVoid(_ path: String, body: [String: Any]? = nil) async throws {
        let request = try buildRequest("PUT", path: path, body: body)
        _ = try await perform(request)
    }

    private func deleteVoid(_ path: String) async throws {
        let request = try buildRequest("DELETE", path: path)
        _ = try await perform(request)
    }

    // MARK: - Auth

    func getProfiles() async throws -> [User] {
        try await post(AppConstants.authProfiles)
    }

    func selectProfile(userId: String, pin: String? = nil) async throws -> (user: User, token: String) {
        var body: [String: Any] = ["user_id": userId]
        if let pin { body["pin"] = pin }
        let response: SelectProfileResponse = try await post(AppConstants.authSelect, body: body)
        return (user: response.user, token: response.token)
    }

    func createProfile(displayName: String, avatarUrl: String? = nil, pin: String? = nil) async throws -> User {
        var body: [String: Any] = ["display_name": displayName]
        if let avatarUrl { body["avatar_url"] = avatarUrl }
        if let pin { body["pin"] = pin }
        return try await post(AppConstants.authCreate, body: body)
    }

    // MARK: - Channels

    func getChannels() async throws -> [Channel] {
        try await get(AppConstants.channels)
    }

    func getChannel(_ id: String) async throws -> Channel {
        try await get(AppConstants.channelDetail(id))
    }

    func getChannelVideos(_ channelId: String) async throws -> [Video] {
        let request = try buildRequest("GET", path: AppConstants.channelVideos(channelId))
        let data = try await perform(request)
        // Backend may return paginated {items: [...]} or plain array
        if let paginated = try? JSONDecoder.nullFeed.decode(PaginatedVideos.self, from: data) {
            return paginated.items
        }
        return try JSONDecoder.nullFeed.decode([Video].self, from: data)
    }

    func subscribeToChannel(url: String, trackingMode: String = "FUTURE_ONLY") async throws {
        try await postVoid(AppConstants.channelSubscribe, body: ["url": url, "tracking_mode": trackingMode])
    }

    func refreshChannelImages(_ channelId: String) async throws -> Channel {
        try await post(AppConstants.channelRefreshImages(channelId))
    }

    func unsubscribeFromChannel(_ channelId: String) async throws {
        try await deleteVoid(AppConstants.channelUnsubscribe(channelId))
    }

    // MARK: - Videos

    func getVideo(_ id: String) async throws -> Video {
        try await get(AppConstants.videoDetail(id))
    }

    func getVideoStreamUrl(_ id: String) -> String {
        var url = "\(baseURL)\(AppConstants.videoStream(id))"
        if let token = storage.sessionToken { url += "?token=\(token)" }
        return url
    }

    func getPreviewStreamUrl(_ id: String) -> String {
        var url = "\(baseURL)\(AppConstants.videoPreviewStream(id))"
        if let token = storage.sessionToken { url += "?token=\(token)" }
        return url
    }

    func updateProgress(videoId: String, positionSeconds: Int) async throws {
        try await putVoid(AppConstants.videoProgress(videoId), body: ["position_seconds": positionSeconds])
    }

    func deleteVideo(_ videoId: String) async throws {
        try await deleteVoid(AppConstants.videoDetail(videoId))
    }

    func downloadVideo(_ videoId: String) async throws {
        try await postVoid(AppConstants.videoDownload(videoId))
    }

    func cancelDownload(_ videoId: String) async throws {
        try await postVoid(AppConstants.videoCancel(videoId))
    }

    func requestPreview(_ videoId: String) async throws {
        try await postVoid(AppConstants.videoPreview(videoId))
    }

    func getActiveDownloads() async throws -> [Video] {
        try await get(AppConstants.activeDownloads)
    }

    // MARK: - Feed

    func getContinueWatching() async throws -> [FeedItem] {
        try await get(AppConstants.feedContinueWatching)
    }

    func getNewEpisodes() async throws -> [FeedItem] {
        try await get(AppConstants.feedNewEpisodes)
    }

    func getRecentlyAdded() async throws -> [FeedItem] {
        try await get(AppConstants.feedRecentlyAdded)
    }

    // MARK: - Discover

    func getRecommendations() async throws -> [Recommendation] {
        try await get(AppConstants.discover)
    }

    func dismissRecommendation(_ id: String) async throws {
        try await postVoid(AppConstants.discoverDismiss(id))
    }

    func refreshRecommendations() async throws {
        try await postVoid(AppConstants.discoverRefresh)
    }

    // MARK: - Health

    func checkHealth() async -> Bool {
        do {
            let request = try buildRequest("GET", path: AppConstants.health)
            _ = try await perform(request)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Response Types

private struct SelectProfileResponse: Decodable {
    let user: User
    let token: String
}

private struct PaginatedVideos: Decodable {
    let items: [Video]
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .requestFailed: "Request failed"
        }
    }
}
