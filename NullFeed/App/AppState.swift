import SwiftUI

@MainActor
@Observable
final class AppState {
    var currentUser: User?
    var isAuthenticated: Bool { currentUser != nil }
    var isLoading = true

    private let storage: StorageService
    private let api: APIClient

    init(storage: StorageService, api: APIClient) {
        self.storage = storage
        self.api = api
    }

    func checkSession() async {
        defer { isLoading = false }

        guard let token = storage.sessionToken,
              let userId = storage.selectedUserId,
              !token.isEmpty, !userId.isEmpty else {
            return
        }

        let healthy = await api.checkHealth()
        guard healthy else {
            storage.clearSession()
            return
        }

        do {
            let profiles = try await api.getProfiles()
            currentUser = profiles.first { $0.id == userId }
        } catch {
            storage.clearSession()
        }
    }

    func login(user: User, token: String) {
        storage.sessionToken = token
        storage.selectedUserId = user.id
        currentUser = user
    }

    func logout() {
        storage.clearSession()
        currentUser = nil
    }
}
