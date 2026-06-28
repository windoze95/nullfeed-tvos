import SwiftUI

@MainActor
@Observable
final class AppState {
    var currentUser: User?
    var isAuthenticated: Bool { currentUser != nil }
    var isLoading = true

    private let storage: StorageService
    private let api: APIClient
    private let webSocket: WebSocketClient

    init(storage: StorageService, api: APIClient, webSocket: WebSocketClient) {
        self.storage = storage
        self.api = api
        self.webSocket = webSocket
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
            if let user = profiles.first(where: { $0.id == userId }) {
                currentUser = user
                connectWebSocket(userId: userId)
            } else {
                storage.clearSession()
            }
        } catch {
            storage.clearSession()
        }
    }

    func login(user: User, token: String) {
        storage.sessionToken = token
        storage.selectedUserId = user.id
        currentUser = user
        connectWebSocket(userId: user.id)
    }

    func logout() {
        webSocket.disconnect()
        storage.clearSession()
        currentUser = nil
    }

    private func connectWebSocket(userId: String) {
        guard let serverUrl = storage.serverUrl, !serverUrl.isEmpty else { return }
        // The socket fetches its own short-lived ticket; the session token (read
        // from storage, already set by login/checkSession) never goes on the URL.
        webSocket.connect(serverUrl: serverUrl, userId: userId)
    }
}
