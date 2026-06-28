import Foundation

/// Identity resolved from a YouTube handle via `POST /api/youtube/resolve`.
/// Used to preview a profile's name/avatar before creating it.
struct YoutubeProfile: Decodable, Sendable {
    let handle: String
    let channelId: String
    let name: String
    let description: String?
    let avatarUrl: String?
    let bannerUrl: String?
    let followerCount: Int?
}

/// A channel the resolved YouTube profile follows, offered for bulk subscribe
/// via `POST /api/youtube/suggestions`. `source` is "featured" or "playlists".
struct ChannelSuggestion: Decodable, Identifiable, Sendable {
    let youtubeChannelId: String
    let name: String
    let handle: String?
    let avatarUrl: String?
    let source: String
    let score: Int

    var id: String { youtubeChannelId }
}

/// Per-item outcome of `POST /api/channels/subscribe-bulk`.
/// `status` is "subscribed", "already_subscribed", or "error".
struct BulkSubscribeResult: Decodable, Sendable {
    let youtubeChannelId: String
    let status: String
    let channelId: String?
    let detail: String?
}
