import Foundation

@MainActor
@Observable
final class LibraryViewModel {
    var channels: [Channel] = []
    var isLoading = false
    var isRefreshing = false
    var error: String?

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func loadChannels() async {
        isLoading = true
        error = nil
        do {
            channels = try await api.getChannels()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Trigger a server-side poll of every channel, then reload the catalog.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        try? await api.pollAllChannels()
        await loadChannels()
        isRefreshing = false
    }

    @discardableResult
    func subscribeToChannel(url: String, trackingMode: String = "FUTURE_ONLY") async -> Bool {
        error = nil
        do {
            try await api.subscribeToChannel(url: url, trackingMode: trackingMode)
            await loadChannels()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func unsubscribeFromChannel(_ id: String) async {
        do {
            try await api.unsubscribeFromChannel(id)
            channels.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
