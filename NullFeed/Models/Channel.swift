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
}
