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

        // Run the three feeds concurrently but handle each independently so one
        // failing endpoint doesn't blank the rows that loaded fine.
        async let cw = api.getContinueWatching()
        async let ne = api.getNewEpisodes()
        async let ra = api.getRecentlyAdded()

        var lastError: String?
        do { continueWatching = try await cw } catch { lastError = error.localizedDescription }
        do { newEpisodes = try await ne } catch { lastError = error.localizedDescription }
        do { recentlyAdded = try await ra } catch { lastError = error.localizedDescription }

        // Only surface an error when nothing loaded at all; otherwise show what
        // we have and stay silent about the partial failure.
        error = isEmpty ? lastError : nil

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
