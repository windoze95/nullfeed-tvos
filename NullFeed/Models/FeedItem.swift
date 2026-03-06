import Foundation

struct FeedItem: Codable, Identifiable, Sendable {
    let channel: Channel
    let video: Video

    var id: String { video.id }
}
