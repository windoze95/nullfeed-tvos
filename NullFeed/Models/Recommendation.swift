import Foundation

struct Recommendation: Codable, Identifiable, Sendable {
    let id: String
    let channelName: String
    let channelId: String?
    let youtubeChannelId: String?
    let reasoning: String
    let avatarUrl: String?
    let bannerUrl: String?
    var dismissed: Bool = false
}
