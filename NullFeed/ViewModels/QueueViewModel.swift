import Foundation

/// App-level store for the user's watch-later queue. Injected via the
/// environment (like `AppState`) so the Queue surface, the channel action menus,
/// and the player's auto-advance all read and mutate one source of truth.
///
/// Add/remove are optimistic: the in-memory list updates immediately and rolls
/// back if the network call fails. The backend's add/remove are idempotent, so a
/// stale membership check (e.g. a video on a not-yet-loaded page) at worst issues
/// a harmless duplicate request.
@MainActor
@Observable
final class QueueViewModel {
    var items: [Video] = []
    var total = 0
    var isLoading = false
    var isLoadingMore = false
    var error: String?

    private let api: APIClient
    /// Cursor for the next page; nil once the last page has loaded.
    private var nextCursor: String?
    /// Whether a first load has completed, so `ensureLoaded()` only fetches once
    /// for callers that just need membership.
    private var hasLoaded = false

    init(api: APIClient) {
        self.api = api
    }

    var isEmpty: Bool { items.isEmpty }
    var canLoadMore: Bool { nextCursor != nil }

    func isQueued(_ id: String) -> Bool {
        items.contains { $0.id == id }
    }

    /// The item that plays after `id` in queue order, or nil if `id` is the last
    /// item or isn't in the loaded list. Used by the player's auto-advance.
    func videoAfter(_ id: String) -> Video? {
        guard let index = items.firstIndex(where: { $0.id == id }),
              index + 1 < items.count else { return nil }
        return items[index + 1]
    }

    /// Reload the first page. Used by the Queue surface on appear so it reflects
    /// items watched or removed since the last visit.
    func load() async {
        isLoading = true
        error = nil
        do {
            let page = try await api.getQueue(cursor: nil)
            items = page.items
            total = page.total
            nextCursor = page.nextCursor
            hasLoaded = true
            prewarmPreviews(for: items)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Best-effort: pre-generate previews for queued videos that aren't already
    /// playable, so opening one from the queue lands on the ready-preview fast
    /// path instead of the cold instant-stream path.
    private func prewarmPreviews(for videos: [Video]) {
        let ids = videos.filter { !$0.isPlayable }
            .prefix(AppConstants.prewarmBatchSize)
            .map(\.id)
        guard !ids.isEmpty else { return }
        Task { [api] in try? await api.prewarmPreviews(Array(ids)) }
    }

    /// Load the first page once, for callers that only need membership (e.g. the
    /// channel action menus). A no-op if a load has already happened.
    func ensureLoaded() async {
        guard !hasLoaded, !isLoading else { return }
        await load()
    }

    /// Append the next page, if any. A load-more failure keeps what's on screen.
    func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        do {
            let page = try await api.getQueue(cursor: cursor)
            items.append(contentsOf: page.items)
            total = page.total
            nextCursor = page.nextCursor
        } catch {
            // Keep the current results; the user can scroll to retry.
        }
        isLoadingMore = false
    }

    /// Optimistically add a video to the back of the queue, rolling back if the
    /// request fails.
    func add(_ video: Video) async {
        guard !isQueued(video.id) else { return }
        items.append(video)
        total += 1
        do {
            try await api.addToQueue(video.id)
        } catch {
            items.removeAll { $0.id == video.id }
            total = max(0, total - 1)
            self.error = error.localizedDescription
        }
    }

    /// Optimistically remove a video from the queue, restoring it in place if the
    /// request fails.
    func remove(_ id: String) async {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            // Not in our (possibly partial) list; still issue the idempotent
            // delete so the server drops it.
            try? await api.removeFromQueue(id)
            return
        }
        let removed = items.remove(at: index)
        total = max(0, total - 1)
        do {
            try await api.removeFromQueue(id)
        } catch {
            items.insert(removed, at: min(index, items.count))
            total += 1
            self.error = error.localizedDescription
        }
    }
}
