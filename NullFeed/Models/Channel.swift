import Foundation

struct Channel: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let youtubeChannelId: String
    let name: String
    let slug: String
    let description: String?
    let bannerUrl: String?
    let avatarUrl: String?
    let lastCheckedAt: Date?
    let trackingMode: String?
    // Present on the channel-detail payload (absent elsewhere → nil): whether
    // this user is subscribed, the content types they've hidden for the channel,
    // and the distinct types the channel actually has. Together they drive the
    // per-channel filter menu.
    let isSubscribed: Bool?
    let hiddenContentTypes: [String]?
    let availableContentTypes: [String]?
}

extension Channel {
    /// Types the channel actually has, as [ContentType] (dropping unknowns) —
    /// what the filter menu lists.
    var availableContentTypesParsed: [ContentType] {
        (availableContentTypes ?? [])
            .map(ContentType.init(wireValue:))
            .filter { $0 != .unknown }
    }

    func isHidden(_ type: ContentType) -> Bool {
        (hiddenContentTypes ?? []).contains(type.rawValue)
    }

    /// Whether to offer the filter: only when subscribed and there's more than
    /// one kind of media to sift.
    var showContentFilter: Bool {
        (isSubscribed ?? false) && availableContentTypesParsed.count > 1
    }
}
