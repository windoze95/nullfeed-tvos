import Foundation

@MainActor
@Observable
final class LibraryViewModel {
    var channels: [Channel] = []
    var isLoading = false
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

    func subscribeToChannel(url: String, trackingMode: String = "FUTURE_ONLY") async {
        do {
            try await api.subscribeToChannel(url: url, trackingMode: trackingMode)
            await loadChannels()
        } catch {
            self.error = error.localizedDescription
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
