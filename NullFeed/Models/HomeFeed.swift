import Foundation

struct HomeFeed: Codable, Sendable {
    var continueWatching: [FeedItem] = []
    var newEpisodes: [FeedItem] = []
    var recentlyAdded: [FeedItem] = []
}

extension HomeFeed {
    private enum CodingKeys: String, CodingKey {
        case continueWatching, newEpisodes, recentlyAdded
    }

    // Decode each row defensively: an omitted section is a valid empty row, not
    // a decode error. (Stored-property defaults alone don't do this — Swift's
    // synthesized Decodable still requires every key.)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        continueWatching = try c.decodeIfPresent([FeedItem].self, forKey: .continueWatching) ?? []
        newEpisodes = try c.decodeIfPresent([FeedItem].self, forKey: .newEpisodes) ?? []
        recentlyAdded = try c.decodeIfPresent([FeedItem].self, forKey: .recentlyAdded) ?? []
    }
}
