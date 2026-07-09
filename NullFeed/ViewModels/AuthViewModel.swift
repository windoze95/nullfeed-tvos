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
        guard let normalized = APIClient.normalizedServerURL(serverUrl) else {
            error = "Enter a valid server address"
            return
        }

        isLoading = true
        error = nil

        serverUrl = normalized
        storage.serverUrl = normalized

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

    @discardableResult
    func selectProfile(userId: String, pin: String? = nil) async -> ProfileSelectOutcome {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response = try await api.selectProfile(userId: userId, pin: pin)
            appState.login(user: response.user, token: response.token)
            return .success
        } catch APIError.httpStatus(let code, _, _) {
            switch code {
            case 403:
                // Wrong or missing PIN -- let the caller re-prompt.
                return .incorrectPin
            case 429:
                return .lockedOut
            default:
                self.error = "Failed to select profile (HTTP \(code))"
                return .failed(self.error ?? "Failed to select profile")
            }
        } catch {
            self.error = "Failed to select profile: \(error.localizedDescription)"
            return .failed(error.localizedDescription)
        }
    }
}

enum ProfileSelectOutcome: Sendable {
    case success
    case incorrectPin
    case lockedOut
    case failed(String)
}
