import Foundation

@MainActor
@Observable
final class HomeViewModel {
    var continueWatching: [FeedItem] = []
    var newEpisodes: [FeedItem] = []
    var recentlyAdded: [FeedItem] = []
    var isLoading = false
    var isRefreshing = false
    var error: String?

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    var isEmpty: Bool {
        continueWatching.isEmpty && newEpisodes.isEmpty && recentlyAdded.isEmpty
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

    /// Trigger a server-side poll of every channel, then reload the feed so any
    /// freshly-found content shows up.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        try? await api.pollAllChannels()
        await loadFeed()
        isRefreshing = false
    }
}
