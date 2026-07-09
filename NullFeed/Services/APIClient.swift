import Foundation

@MainActor
@Observable
final class APIClient {
    private let session = URLSession.shared
    private let storage: StorageService

    /// Cached short-lived stream/WS tickets, so repeated stream URL builds for
    /// the same video (its preview then full quality) and a freshly reconnected
    /// socket don't each mint a new one. See `playbackTicket(videoId:)` and
    /// `wsTicket(forceRefresh:)`.
    private var playbackTicketCache: (videoId: String, ticket: CachedTicket)?
    private var wsTicketCache: CachedTicket?

    init(storage: StorageService) {
        self.storage = storage
    }

    /// Couch-friendly server address normalization. The setup keyboard does not
    /// need to force users to type a scheme, and a trailing slash must not turn
    /// every request into `//api/...`.
    nonisolated static func normalizedServerURL(_ value: String) -> String? {
        var candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return nil }
        if !candidate.contains("://") {
            candidate = "http://\(candidate)"
        }
        while candidate.hasSuffix("/") {
            candidate.removeLast()
        }

        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.host != nil else {
            return nil
        }
        return candidate
    }

    private var baseURL: String {
        storage.serverUrl.flatMap(Self.normalizedServerURL) ?? "http://localhost:8484"
    }

    /// Resolve a possibly-relative media path served by the backend
    /// (e.g. "/data/thumbnails/x.jpg") into an absolute URL string.
    /// Absolute URLs and nil/empty values pass through unchanged.
    func mediaURL(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http://") || path.hasPrefix("https://") { return path }
        return "\(baseURL)\(path)"
    }

    // MARK: - HTTP Helpers

    private func buildRequest(_ method: String, path: String, body: [String: Any]? = nil, timeout: TimeInterval? = nil, authToken: String? = nil) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // `authToken` overrides the stored session token, used so a sign-out can
        // still authenticate the push de-registration after the session is cleared.
        if let token = authToken ?? storage.sessionToken {
            request.setValue(token, forHTTPHeaderField: "X-User-Token")
        }
        if let timeout { request.timeoutInterval = timeout }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.requestFailed
        }
        guard (200...299).contains(http.statusCode) else {
            // Non-2xx bodies are the standard {detail, code} error envelope;
            // decode it so the PIN flow can branch on status and views can
            // surface the real message.
            let envelope = try? JSONDecoder.nullFeed.decode(ErrorEnvelope.self, from: data)
            throw APIError.httpStatus(http.statusCode, detail: envelope?.detail, code: envelope?.code)
        }
        return data
    }

    /// Percent-encode a query parameter value. Uses the RFC 3986 unreserved set
    /// so opaque cursors (which may contain +, /, =) and free-text queries
    /// survive the round trip -- `URLComponents` notably leaves "+" unescaped,
    /// which the server would otherwise read as a space.
    private func encodeQuery(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try buildRequest("GET", path: path)
        let data = try await perform(request)
        return try JSONDecoder.nullFeed.decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any]? = nil, timeout: TimeInterval? = nil) async throws -> T {
        let request = try buildRequest("POST", path: path, body: body, timeout: timeout)
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

    private func put<T: Decodable>(_ path: String, body: [String: Any]? = nil) async throws -> T {
        let request = try buildRequest("PUT", path: path, body: body)
        let data = try await perform(request)
        return try JSONDecoder.nullFeed.decode(T.self, from: data)
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

    /// Create a profile. Provide a `displayName`, a `youtubeHandle`, or both: the
    /// backend resolves a handle to fill in the name/avatar when `displayName` is
    /// omitted. Resolving runs yt-dlp server-side, so handle creates use the
    /// slow timeout.
    func createProfile(
        displayName: String? = nil,
        avatarUrl: String? = nil,
        pin: String? = nil,
        youtubeHandle: String? = nil
    ) async throws -> User {
        var body: [String: Any] = [:]
        if let displayName { body["display_name"] = displayName }
        if let avatarUrl { body["avatar_url"] = avatarUrl }
        if let pin { body["pin"] = pin }
        if let youtubeHandle { body["youtube_handle"] = youtubeHandle }
        let timeout: TimeInterval? = youtubeHandle != nil ? AppConstants.slowRequestTimeout : nil
        return try await post(AppConstants.authCreate, body: body, timeout: timeout)
    }

    /// Mint (or reuse) a short-lived WebSocket ticket, used as the `?ticket=`
    /// credential when opening the realtime socket so the session token isn't
    /// exposed in the socket URL. Cached until shortly before it expires and
    /// bound to the current session; `forceRefresh` skips the cache so a
    /// reconnect always opens with a fresh ticket.
    func wsTicket(forceRefresh: Bool = false) async throws -> String {
        if !forceRefresh,
           let cached = wsTicketCache,
           cached.isValid(for: storage.sessionToken) {
            return cached.value
        }
        let response: TicketResponse = try await post(AppConstants.authWsTicket)
        let ticket = CachedTicket(response, sessionToken: storage.sessionToken)
        wsTicketCache = ticket
        return ticket.value
    }

    // MARK: - YouTube Import

    /// Resolve a YouTube handle or channel URL into a profile preview
    /// (name, avatar, follower count). Unauthenticated; used pre-login.
    func resolveYoutubeHandle(_ handle: String) async throws -> YoutubeProfile {
        try await post(
            AppConstants.youtubeResolve,
            body: ["handle": handle],
            timeout: AppConstants.slowRequestTimeout
        )
    }

    /// Fetch the channels a resolved YouTube profile follows, offered as
    /// bulk-subscribe suggestions. Unauthenticated; used pre-login.
    func getYoutubeSuggestions(handle: String) async throws -> [ChannelSuggestion] {
        let response: SuggestionsResponse = try await post(
            AppConstants.youtubeSuggestions,
            body: ["handle": handle],
            timeout: AppConstants.slowRequestTimeout
        )
        return response.suggestions
    }

    /// Subscribe to up to 25 channels at once. Requires a session token, so call
    /// after `selectProfile`. Per-item errors don't fail the batch.
    func subscribeBulk(_ items: [ChannelSuggestion]) async throws -> [BulkSubscribeResult] {
        let payload: [[String: Any]] = items.map {
            ["youtube_channel_id": $0.youtubeChannelId, "name": $0.name]
        }
        let response: BulkSubscribeResponse = try await post(
            AppConstants.channelSubscribeBulk,
            body: ["items": payload],
            timeout: AppConstants.slowRequestTimeout
        )
        return response.results
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

    /// Replace the content types hidden for a channel (the per-channel filter),
    /// returning the updated channel. An empty list clears the filter.
    func setContentFilter(_ channelId: String, hidden: [String]) async throws -> Channel {
        try await put(AppConstants.channelContentFilter(channelId), body: ["hidden_content_types": hidden])
    }

    func unsubscribeFromChannel(_ channelId: String) async throws {
        try await deleteVoid(AppConstants.channelUnsubscribe(channelId))
    }

    /// Ask the server to poll every subscribed channel for new content.
    /// Fire-and-forget: the server enqueues the work and returns immediately.
    func pollAllChannels() async throws {
        try await postVoid(AppConstants.channelsPoll)
    }

    /// Ask the server to poll a single channel for new content.
    func pollChannel(_ channelId: String) async throws {
        try await postVoid(AppConstants.channelPoll(channelId))
    }

    // MARK: - Videos

    func getVideo(_ id: String) async throws -> Video {
        try await get(AppConstants.videoDetail(id))
    }

    /// Full-quality stream URL, authenticated with a short-lived playback ticket
    /// (`?ticket=`) rather than the session token, so the long-lived credential
    /// never lands in a media URL. Throws if a ticket can't be minted; the caller
    /// should surface that instead of playing an unauthenticated URL the server
    /// would reject.
    func getVideoStreamUrl(_ id: String) async throws -> String {
        let ticket = try await playbackTicket(videoId: id)
        return "\(baseURL)\(AppConstants.videoStream(id))?ticket=\(encodeQuery(ticket))"
    }

    /// Detected sponsor/ad segments (seconds) for client-side skipping. Empty
    /// when detection is still pending or finds none.
    func getAdSegments(_ id: String) async throws -> [AdSegment] {
        let response: AdSegmentsResponse = try await get(AppConstants.videoAdSegments(id))
        return response.segments
    }

    /// Preview stream URL, ticket-authenticated like `getVideoStreamUrl`.
    func getPreviewStreamUrl(_ id: String) async throws -> String {
        let ticket = try await playbackTicket(videoId: id)
        return "\(baseURL)\(AppConstants.videoPreviewStream(id))?ticket=\(encodeQuery(ticket))"
    }

    /// Instant-start stream URL, ticket-authenticated like `getVideoStreamUrl`.
    /// The backend resolves and reverse-proxies a progressive source so a
    /// not-yet-downloaded video plays immediately on a cold press.
    func getInstantStreamUrl(_ id: String) async throws -> String {
        let ticket = try await playbackTicket(videoId: id)
        return "\(baseURL)\(AppConstants.videoInstantStream(id))?ticket=\(encodeQuery(ticket))"
    }

    /// Mint (or reuse) a short-lived playback ticket for `videoId`, used as the
    /// `?ticket=` credential on `/stream` and `/preview-stream`. Cached per video
    /// until shortly before it expires and bound to the current session, so the
    /// same video's preview and full-quality streams share one ticket while a
    /// different video, an expiry, or a profile switch forces a fresh mint.
    func playbackTicket(videoId: String) async throws -> String {
        if let cached = playbackTicketCache,
           cached.videoId == videoId,
           cached.ticket.isValid(for: storage.sessionToken) {
            return cached.ticket.value
        }
        let response: TicketResponse = try await post(AppConstants.videoPlaybackTicket(videoId))
        let ticket = CachedTicket(response, sessionToken: storage.sessionToken)
        playbackTicketCache = (videoId, ticket)
        return ticket.value
    }

    /// Save the user's playback position. Pass `isWatched: true` when the video
    /// has finished so the backend marks it watched; combined with
    /// `positionSeconds: 0` this also clears the resume position.
    func updateProgress(videoId: String, positionSeconds: Int, isWatched: Bool = false) async throws {
        try await putVoid(
            AppConstants.videoProgress(videoId),
            body: ["position_seconds": positionSeconds, "is_watched": isWatched]
        )
    }

    func deleteVideo(_ videoId: String) async throws {
        try await deleteVoid(AppConstants.videoDetail(videoId))
    }

    func downloadVideo(_ videoId: String) async throws {
        try await postVoid(AppConstants.videoDownload(videoId))
    }

    /// Records an evictable cache claim and (server-side) kicks off the HQ
    /// download, hidden from the Downloads tab. Called when the user starts
    /// instant playback of a not-yet-downloaded video so the player can swap up
    /// to HQ. Best-effort and idempotent.
    func cacheVideo(_ videoId: String) async throws {
        try await postVoid(AppConstants.videoCache(videoId))
    }

    func cancelDownload(_ videoId: String) async throws {
        try await postVoid(AppConstants.videoCancel(videoId))
    }

    func requestPreview(_ videoId: String) async throws {
        try await postVoid(AppConstants.videoPreview(videoId))
    }

    /// Pre-generate 360p previews for videos the user is likely to play next, so
    /// a later tap lands on the ready-preview fast path instead of the cold
    /// instant-stream path. Best-effort; the backend dedupes and caps the batch.
    func prewarmPreviews(_ videoIds: [String]) async throws {
        guard !videoIds.isEmpty else { return }
        try await postVoid(AppConstants.videosPrewarm, body: ["video_ids": videoIds])
    }

    func getActiveDownloads() async throws -> [Video] {
        try await get(AppConstants.activeDownloads)
    }

    // MARK: - Search

    /// Search the catalog for videos matching `q`. Pages are cursor-based: pass
    /// the previous page's `nextCursor` back as `cursor`; a nil `nextCursor` in
    /// the response means there are no more pages.
    func searchVideos(q: String, cursor: String? = nil, limit: Int = 20) async throws -> VideoSearchPage {
        var query = "q=\(encodeQuery(q))&limit=\(limit)"
        if let cursor { query += "&cursor=\(encodeQuery(cursor))" }
        return try await get("\(AppConstants.videos)?\(query)")
    }

    /// Search subscribed channels by name. Returns the full match list (the
    /// backend does not paginate channel matches).
    func searchChannels(_ q: String) async throws -> [Channel] {
        try await get("\(AppConstants.channels)?q=\(encodeQuery(q))")
    }

    // MARK: - Feed

    /// Unified home feed (continue-watching, new-episodes, recently-added) in a
    /// single round trip; each row shares the per-feed item shape.
    func getHomeFeed() async throws -> HomeFeed {
        try await get(AppConstants.feedHome)
    }

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

    // MARK: - Queue

    /// Add a video to the watch-later queue. Idempotent server-side, so adding a
    /// video that's already queued is a no-op.
    func addToQueue(_ videoId: String) async throws {
        try await postVoid(AppConstants.videoQueue(videoId))
    }

    /// Remove a video from the watch-later queue. Idempotent server-side, so
    /// removing a video that isn't queued is a no-op.
    func removeFromQueue(_ videoId: String) async throws {
        try await deleteVoid(AppConstants.videoQueue(videoId))
    }

    /// One page of the watch-later queue, in play order. Cursor-based like
    /// search: pass the previous page's `nextCursor` back as `cursor`; a nil
    /// `nextCursor` in the response means this was the last page.
    func getQueue(cursor: String? = nil) async throws -> VideoSearchPage {
        var path = AppConstants.queue
        if let cursor { path += "?cursor=\(encodeQuery(cursor))" }
        return try await get(path)
    }

    // MARK: - Settings

    /// Read-only on Apple TV: exporting and pasting a cookies.txt remains a
    /// phone/web task, but admins can still see whether age-gated playback is
    /// configured and healthy from the couch.
    func getYouTubeAccountStatus() async throws -> YouTubeAccountStatus {
        try await get(AppConstants.settingsYoutubeCookies)
    }

    // MARK: - Health

    func checkHealth(serverURL: String? = nil) async -> Bool {
        do {
            let root: String
            if let serverURL {
                guard let normalized = Self.normalizedServerURL(serverURL) else { return false }
                root = normalized
            } else {
                root = baseURL
            }
            guard let url = URL(string: "\(root)\(AppConstants.health)") else { return false }
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200...299).contains(http.statusCode)
        } catch {
            return false
        }
    }

    /// Tickets are scoped to one backend. Clear them before reconnecting after
    /// the user changes the server address in Settings.
    func resetConnectionState() {
        playbackTicketCache = nil
        wsTicketCache = nil
    }

    // MARK: - Push Notifications

    /// Register this device's APNs token so the backend can send new-episode
    /// pushes. Returns the backend's push state (`{enabled, registered}`);
    /// `enabled` is false when the server has no push gateway configured, which
    /// callers should treat as a no-op rather than an error.
    @discardableResult
    func registerPushToken(token: String, deviceId: String) async throws -> PushRegistration {
        let request = try buildRequest("POST", path: AppConstants.pushRegister, body: [
            "device_token": token,
            "device_id": deviceId,
            "platform": "ios",
        ])
        let data = try await perform(request)
        return (try? JSONDecoder.nullFeed.decode(PushRegistration.self, from: data))
            ?? PushRegistration(enabled: false, registered: false)
    }

    /// Remove this device's push registration, e.g. on sign-out. `sessionToken`
    /// overrides the stored token so the call still authenticates when invoked
    /// while the session is being torn down.
    func unregisterPushToken(deviceId: String, sessionToken: String? = nil) async throws {
        let request = try buildRequest(
            "DELETE",
            path: AppConstants.pushRegister,
            body: ["device_id": deviceId],
            authToken: sessionToken
        )
        _ = try await perform(request)
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

private struct SuggestionsResponse: Decodable {
    let suggestions: [ChannelSuggestion]
}

/// The backend's push state after a register call. `enabled` is false when no
/// push gateway is configured server-side; `registered` confirms the token was
/// stored. Both tolerate omission so a bare `{"enabled": false}` still decodes.
struct PushRegistration: Decodable {
    let enabled: Bool
    let registered: Bool

    init(enabled: Bool, registered: Bool) {
        self.enabled = enabled
        self.registered = registered
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        registered = try c.decodeIfPresent(Bool.self, forKey: .registered) ?? false
    }

    private enum CodingKeys: String, CodingKey { case enabled, registered }
}

private struct BulkSubscribeResponse: Decodable {
    let results: [BulkSubscribeResult]
}

struct YouTubeAccountStatus: Decodable, Sendable {
    let configured: Bool
    let stale: Bool
    let updatedAt: String?
    let lastError: String?
}

/// A minted stream/WS ticket: `{ticket, expires_in}` (seconds).
private struct TicketResponse: Decodable {
    let ticket: String
    let expiresIn: Int
}

/// A cached ticket: its value, the instant it should be treated as expired (set
/// a little before the real expiry so a slow connection can't outlast it), and
/// the session it was minted for so a profile switch invalidates it.
private struct CachedTicket {
    let value: String
    let expiresAt: Date
    let sessionToken: String

    /// Retire a ticket this long before its real expiry, so it's never handed to
    /// a player or socket with only a sliver of life left.
    private static let safetyMargin: TimeInterval = 15

    init(_ response: TicketResponse, sessionToken: String?) {
        value = response.ticket
        expiresAt = Date().addingTimeInterval(max(0, TimeInterval(response.expiresIn) - Self.safetyMargin))
        self.sessionToken = sessionToken ?? ""
    }

    func isValid(for sessionToken: String?) -> Bool {
        (sessionToken ?? "") == self.sessionToken && Date() < expiresAt
    }
}

/// The backend's standard error body: a human-readable `detail` and a stable
/// machine `code`. Both optional so a partial or non-JSON body still decodes.
private struct ErrorEnvelope: Decodable {
    let detail: String?
    let code: String?
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case requestFailed
    /// Non-2xx response. Carries the HTTP status plus the decoded error
    /// envelope ({detail, code}) when present, so callers can branch on the
    /// status (e.g. the PIN flow) while views surface `detail`.
    case httpStatus(Int, detail: String?, code: String?)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .requestFailed: "Request failed"
        case .httpStatus(let status, let detail, _): detail ?? "Request failed (HTTP \(status))"
        }
    }
}
