import Foundation

@MainActor
@Observable
final class DiscoverViewModel {
    var recommendations: [Recommendation] = []
    var isLoading = false
    var error: String?

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func loadRecommendations() async {
        isLoading = true
        error = nil
        do {
            recommendations = try await api.getRecommendations()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func dismissRecommendation(_ id: String) async {
        do {
            try await api.dismissRecommendation(id)
            recommendations.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refreshRecommendations() async {
        do {
            try await api.refreshRecommendations()
            await loadRecommendations()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
