import Foundation

struct HomeFeed: Codable, Sendable {
    var continueWatching: [FeedItem] = []
    var newEpisodes: [FeedItem] = []
    var recentlyAdded: [FeedItem] = []
}
