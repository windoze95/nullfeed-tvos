import Foundation

@MainActor
@Observable
final class AuthViewModel {
    var serverUrl = ""
    var profiles: [User] = []
    var isLoading = false
    var isConnected = false
    var error: String?

    private let storage: StorageService
    private let api: APIClient
    private let appState: AppState

    init(storage: StorageService, api: APIClient, appState: AppState) {
        self.storage = storage
        self.api = api
        self.appState = appState

        if let savedUrl = storage.serverUrl, !savedUrl.isEmpty {
            serverUrl = savedUrl
        }
    }

    func connectToServer() async {
        let trimmed = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = "Please enter a server URL"
            return
        }

        isLoading = true
        error = nil

        storage.serverUrl = trimmed

        let healthy = await api.checkHealth()
        guard healthy else {
            self.error = "Could not connect to server"
            isConnected = false
            isLoading = false
            return
        }

        do {
            try await loadProfiles()
            isConnected = true
        } catch {
            self.error = "Could not connect to server: \(error.localizedDescription)"
            isConnected = false
        }

        isLoading = false
    }

    func loadProfiles() async throws {
        profiles = try await api.getProfiles()
    }

    func selectProfile(userId: String, pin: String? = nil) async {
        isLoading = true
        error = nil

        do {
            let response = try await api.selectProfile(userId: userId, pin: pin)
            appState.login(user: response.user, token: response.token)
        } catch {
            self.error = "Failed to select profile: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
