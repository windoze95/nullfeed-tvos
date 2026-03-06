import Foundation

enum AppConstants {
    static let appName = "NullFeed"
    static let defaultServerPort = "8484"
    static let appGroup = "group.codes.julian.nullfeed"

    // MARK: - Storage Keys
    static let serverUrlKey = "server_url"
    static let selectedUserIdKey = "selected_user_id"
    static let sessionTokenKey = "session_token"
    static let preferredQualityKey = "preferred_quality"

    // MARK: - API Paths
    static let apiBase = "/api"
    static let authProfiles = "\(apiBase)/auth/profiles"
    static let authSelect = "\(apiBase)/auth/select"
    static let authCreate = "\(apiBase)/auth/create"
    static let channels = "\(apiBase)/channels"
    static let channelSubscribe = "\(apiBase)/channels/subscribe"
    static let activeDownloads = "\(apiBase)/videos/downloads"
    static let feedContinueWatching = "\(apiBase)/feed/continue-watching"
    static let feedNewEpisodes = "\(apiBase)/feed/new-episodes"
    static let feedRecentlyAdded = "\(apiBase)/feed/recently-added"
    static let discover = "\(apiBase)/discover"
    static let discoverRefresh = "\(apiBase)/discover/refresh"
    static let health = "\(apiBase)/health"

    static func channelDetail(_ id: String) -> String { "\(apiBase)/channels/\(id)" }
    static func channelVideos(_ id: String) -> String { "\(apiBase)/channels/\(id)/videos" }
    static func channelRefreshImages(_ id: String) -> String { "\(apiBase)/channels/\(id)/refresh-images" }
    static func channelUnsubscribe(_ id: String) -> String { "\(apiBase)/channels/\(id)/unsubscribe" }
    static func videoDetail(_ id: String) -> String { "\(apiBase)/videos/\(id)" }
    static func videoStream(_ id: String) -> String { "\(apiBase)/videos/\(id)/stream" }
    static func videoProgress(_ id: String) -> String { "\(apiBase)/videos/\(id)/progress" }
    static func videoDownload(_ id: String) -> String { "\(apiBase)/videos/\(id)/download" }
    static func videoCancel(_ id: String) -> String { "\(apiBase)/videos/\(id)/cancel" }
    static func videoPreview(_ id: String) -> String { "\(apiBase)/videos/\(id)/preview" }
    static func videoPreviewStream(_ id: String) -> String { "\(apiBase)/videos/\(id)/preview-stream" }
    static func discoverDismiss(_ id: String) -> String { "\(apiBase)/discover/\(id)/dismiss" }
    static func websocket(_ userId: String) -> String { "/ws/\(userId)" }

    // MARK: - Playback
    static let progressSaveIntervalSeconds = 10
    static let skipForwardSeconds = 10
    static let skipBackwardSeconds = 10

    // MARK: - UI
    static let cardAspectRatio: CGFloat = 16.0 / 9.0
    static let videoCardWidth: CGFloat = 400
    static let channelCardWidth: CGFloat = 360
    static let contentRowHeight: CGFloat = 300
}
