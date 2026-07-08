import Foundation

enum AppConstants {
    static let appName = "NullFeed"
    static let defaultServerPort = "8484"
    /// App Group shared with the Top Shelf extension. Single-sourced in
    /// `SharedDefaults`, which both targets compile.
    static let appGroup = SharedDefaults.appGroup

    // MARK: - Storage Keys
    // The shared credential keys are defined in `SharedDefaults` so the app and
    // the Top Shelf extension agree on them; aliased here for `.standard` access.
    static let serverUrlKey = SharedDefaults.Key.serverUrl
    static let selectedUserIdKey = SharedDefaults.Key.selectedUserId
    static let sessionTokenKey = SharedDefaults.Key.sessionToken
    static let preferredQualityKey = "preferred_quality"
    /// Stable per-install id sent with push (de)registration. Generated once and
    /// kept across logins so it always targets the same device record.
    static let deviceIdKey = "device_id"

    // MARK: - API Paths
    static let apiBase = "/api"
    static let authProfiles = "\(apiBase)/auth/profiles"
    static let authSelect = "\(apiBase)/auth/select"
    static let authCreate = "\(apiBase)/auth/create"
    static let authWsTicket = "\(apiBase)/auth/ws-ticket"
    static let channels = "\(apiBase)/channels"
    static let videos = "\(apiBase)/videos"
    static let channelSubscribe = "\(apiBase)/channels/subscribe"
    static let channelSubscribeBulk = "\(apiBase)/channels/subscribe-bulk"
    static let channelsPoll = "\(apiBase)/channels/poll"
    static let youtubeResolve = "\(apiBase)/youtube/resolve"
    static let youtubeSuggestions = "\(apiBase)/youtube/suggestions"
    static let activeDownloads = "\(apiBase)/videos/downloads"
    static let videosPrewarm = "\(apiBase)/videos/prewarm"
    static let feedHome = "\(apiBase)/feed/home"
    static let feedContinueWatching = "\(apiBase)/feed/continue-watching"
    static let feedNewEpisodes = "\(apiBase)/feed/new-episodes"
    static let feedRecentlyAdded = "\(apiBase)/feed/recently-added"
    static let discover = "\(apiBase)/discover"
    static let discoverRefresh = "\(apiBase)/discover/refresh"
    static let queue = "\(apiBase)/queue"
    static let health = "\(apiBase)/health"
    static let pushRegister = "\(apiBase)/push/register"

    static func channelDetail(_ id: String) -> String { "\(apiBase)/channels/\(id)" }
    static func channelPoll(_ id: String) -> String { "\(apiBase)/channels/\(id)/poll" }
    static func channelVideos(_ id: String) -> String { "\(apiBase)/channels/\(id)/videos" }
    static func channelContentFilter(_ id: String) -> String { "\(apiBase)/channels/\(id)/content-filter" }
    static func channelRefreshImages(_ id: String) -> String { "\(apiBase)/channels/\(id)/refresh-images" }
    static func channelUnsubscribe(_ id: String) -> String { "\(apiBase)/channels/\(id)/unsubscribe" }
    static func videoDetail(_ id: String) -> String { "\(apiBase)/videos/\(id)" }
    static func videoStream(_ id: String) -> String { "\(apiBase)/videos/\(id)/stream" }
    static func videoInstantStream(_ id: String) -> String { "\(apiBase)/videos/\(id)/instant-stream" }
    static func videoAdSegments(_ id: String) -> String { "\(apiBase)/videos/\(id)/ad-segments" }
    static func videoPlaybackTicket(_ id: String) -> String { "\(apiBase)/videos/\(id)/playback-ticket" }
    static func videoProgress(_ id: String) -> String { "\(apiBase)/videos/\(id)/progress" }
    static func videoDownload(_ id: String) -> String { "\(apiBase)/videos/\(id)/download" }
    static func videoCancel(_ id: String) -> String { "\(apiBase)/videos/\(id)/cancel" }
    static func videoCache(_ id: String) -> String { "\(apiBase)/videos/\(id)/cache" }
    static func videoPreview(_ id: String) -> String { "\(apiBase)/videos/\(id)/preview" }
    static func videoPreviewStream(_ id: String) -> String { "\(apiBase)/videos/\(id)/preview-stream" }
    static func videoQueue(_ id: String) -> String { "\(apiBase)/videos/\(id)/queue" }
    static func discoverDismiss(_ id: String) -> String { "\(apiBase)/discover/\(id)/dismiss" }
    static func websocket(_ userId: String) -> String { "/ws/\(userId)" }

    // MARK: - Networking
    /// Longer request timeout for endpoints that drive yt-dlp server-side
    /// (handle resolve, suggestions, create-from-handle, bulk subscribe).
    static let slowRequestTimeout: TimeInterval = 90

    // MARK: - Playback
    static let progressSaveIntervalSeconds = 10
    static let skipForwardSeconds = 10
    static let skipBackwardSeconds = 10
    /// How far to rewind from a saved position when resuming, so the viewer
    /// re-orients on a few seconds of context before the cut they left off at.
    static let resumeRewindSeconds = 10
    /// While playing a preview and waiting for the HQ download, how often to
    /// poll the video's status as a WebSocket fallback — the download_complete
    /// event fires exactly once, so a dropped connection would otherwise leave
    /// the player on the preview for the whole session.
    static let hqPollIntervalSeconds = 20

    // MARK: - UI
    static let cardAspectRatio: CGFloat = 16.0 / 9.0
    // Max videos one /prewarm call asks the backend to pre-generate previews for.
    static let prewarmBatchSize = 12
    static let videoCardWidth: CGFloat = 400
    static let channelCardWidth: CGFloat = 360
    static let contentRowHeight: CGFloat = 300
}
