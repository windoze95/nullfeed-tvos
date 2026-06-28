import Foundation

@MainActor
@Observable
final class HomeViewModel {
    var continueWatching: [FeedItem] = []
    var newEpisodes: [FeedItem] = []
    var recentlyAdded: [FeedItem] = []
    var recommendations: [Recommendation] = []
    var isLoading = false
    var isRefreshing = false
    var error: String?

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    var isEmpty: Bool {
        continueWatching.isEmpty && newEpisodes.isEmpty
            && recentlyAdded.isEmpty && recommendations.isEmpty
    }

    /// Load everything the screen shows -- the feed rows and the recommendations
    /// rail -- concurrently so the initial render settles in a single pass.
    /// Recommendations load independently (see `loadRecommendations`), so a
    /// recommendations failure never blanks the feed.
    func load() async {
        async let feed: Void = loadFeed()
        async let recs: Void = loadRecommendations()
        _ = await (feed, recs)
    }

    func loadFeed() async {
        isLoading = true
        error = nil

        do {
            // One round trip returns all three rows; the server decides what
            // counts as continue-watching / new / recently-added.
            let feed = try await api.getHomeFeed()
            continueWatching = feed.continueWatching
            newEpisodes = feed.newEpisodes
            recentlyAdded = feed.recentlyAdded
        } catch {
            // Only surface an error when nothing is on screen; a failed refresh
            // shouldn't blank rows that are already showing.
            self.error = isEmpty ? error.localizedDescription : nil
        }

        isLoading = false
    }

    /// Load the "Recommended for you" rail (the same recommendations shown on the
    /// Discover tab). These are supplementary to the feed, so a failure neither
    /// surfaces an error nor blanks rows already on screen; the row is simply
    /// omitted while empty.
    func loadRecommendations() async {
        if let recs = try? await api.getRecommendations() {
            recommendations = recs
        }
    }

    /// Remove a recommendation from the rail after the user subscribes to or
    /// dismisses it, mirroring the Discover tab. Best-effort: the card stays put
    /// if the server doesn't accept the dismiss, so it won't quietly reappear.
    func dismissRecommendation(_ id: String) async {
        do {
            try await api.dismissRecommendation(id)
            recommendations.removeAll { $0.id == id }
        } catch {
            // Leave the card in place; it will resolve on the next load.
        }
    }

    /// Trigger a server-side poll of every channel, then reload the feed and
    /// recommendations so any freshly-found content shows up.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        try? await api.pollAllChannels()
        await load()
        isRefreshing = false
    }
}
