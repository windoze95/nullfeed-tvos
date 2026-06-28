import Foundation

@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    var channels: [Channel] = []
    var videos: [Video] = []
    var total = 0
    var isLoading = false
    var isLoadingMore = false
    var error: String?

    private let api: APIClient
    /// Cursor for the next video page; nil once the last page has loaded.
    private var nextCursor: String?
    /// The in-flight debounce-plus-search task, cancelled on every keystroke so a
    /// stale query can never overwrite a newer one.
    private var searchTask: Task<Void, Never>?

    private let debounce = Duration.milliseconds(400)
    private let pageSize = 20

    init(api: APIClient) {
        self.api = api
    }

    var isEmpty: Bool { channels.isEmpty && videos.isEmpty }
    var canLoadMore: Bool { nextCursor != nil }

    /// React to a new query string. Cancels any pending search, debounces, then
    /// runs the search. A blank query clears results without hitting the network.
    func queryChanged(_ newQuery: String) {
        query = newQuery
        searchTask?.cancel()

        let trimmed = newQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clear()
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: self?.debounce ?? .zero)
            guard !Task.isCancelled else { return }
            await self?.runSearch(trimmed)
        }
    }

    /// Re-run the current query (used by the error state's retry button).
    func retry() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        searchTask?.cancel()
        searchTask = Task { [weak self] in await self?.runSearch(trimmed) }
    }

    private func clear() {
        channels = []
        videos = []
        total = 0
        nextCursor = nil
        error = nil
        isLoading = false
    }

    private func runSearch(_ q: String) async {
        isLoading = true
        error = nil
        do {
            // Channel matches and the first video page in parallel.
            async let channelsReq = api.searchChannels(q)
            async let videosReq = api.searchVideos(q: q, cursor: nil, limit: pageSize)
            let foundChannels = try await channelsReq
            let page = try await videosReq
            // A keystroke arriving mid-request cancels this task; don't publish
            // results for a query the user has already moved on from.
            guard !Task.isCancelled else { return }
            channels = foundChannels
            videos = page.items
            total = page.total
            nextCursor = page.nextCursor
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Append the next page of video results, if any. A load-more failure keeps
    /// what's already on screen rather than surfacing an error.
    func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore, !isLoading else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoadingMore = true
        do {
            let page = try await api.searchVideos(q: trimmed, cursor: cursor, limit: pageSize)
            videos.append(contentsOf: page.items)
            total = page.total
            nextCursor = page.nextCursor
        } catch {
            // Keep the current results; the user can scroll to retry.
        }
        isLoadingMore = false
    }
}
