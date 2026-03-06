import Foundation

enum RetentionPolicy: String, Codable, Sendable {
    case keepAll = "KEEP_ALL"
    case keepLastN = "KEEP_LAST_N"
    case keepWatched = "KEEP_WATCHED"
}

struct Subscription: Codable, Sendable {
    let userId: String
    let channelId: String
    let subscribedAt: Date
    var retentionPolicy: RetentionPolicy = .keepAll
    let retentionCount: Int?
}
