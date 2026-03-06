import Foundation

@MainActor
@Observable
final class HomeViewModel {
    var continueWatching: [FeedItem] = []
    var newEpisodes: [FeedItem] = []
    var recentlyAdded: [FeedItem] = []
    var isLoading = false
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

        async let cw = api.getContinueWatching()
        async let ne = api.getNewEpisodes()
        async let ra = api.getRecentlyAdded()

        do {
            let (cwResult, neResult, raResult) = try await (cw, ne, ra)
            continueWatching = cwResult
            newEpisodes = neResult
            recentlyAdded = raResult
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
