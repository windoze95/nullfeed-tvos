import SwiftUI

@MainActor
@Observable
final class AppState {
    var currentUser: User?
    var isAuthenticated: Bool { currentUser != nil }
    var isLoading = true

    /// A video to open in the player, set from a notification payload or a
    /// `nullfeed://player/<id>` deep link and observed by `RootView`, which
    /// presents the player over the current tab. Cleared automatically when the
    /// player is dismissed (the `fullScreenCover` binding writes back nil).
    var deepLinkVideo: DeepLinkVideo?

    /// A deep-link target captured before a profile was active (e.g. the app was
    /// opened from the Top Shelf while signed out); applied once authenticated.
    private var pendingDeepLinkVideoId: String?

    /// The UIKit app delegate, used to request notification authorization and
    /// APNs registration. Weak to avoid a retain cycle (it holds AppState).
    weak var pushRegistrar: (any PushRegistering)?

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
                onAuthenticated()
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
        onAuthenticated()
    }

    func logout() {
        webSocket.disconnect()
        // Best-effort: tell the backend to stop pushing to this device while the
        // session token is still valid. Capture the credentials and fire-and-
        // forget so sign-out stays instant and local state is cleared even if the
        // server is unreachable.
        let deviceId = storage.deviceId
        if let token = storage.sessionToken {
            Task { try? await api.unregisterPushToken(deviceId: deviceId, sessionToken: token) }
        }
        storage.clearSession()
        currentUser = nil
        deepLinkVideo = nil
        pendingDeepLinkVideoId = nil
    }

    /// Open `videoId` in the player. Defers until a profile is active when the
    /// app isn't authenticated yet (e.g. a Top Shelf deep link before sign-in).
    func openVideo(_ videoId: String) {
        guard isAuthenticated else {
            pendingDeepLinkVideoId = videoId
            return
        }
        deepLinkVideo = DeepLinkVideo(id: videoId)
    }

    /// Send a freshly minted APNs device token to the backend. Best-effort: a
    /// server without push configured returns `{"enabled": false}`, which is fine.
    func registerPushToken(_ tokenHex: String) async {
        guard isAuthenticated else { return }
        do {
            let result = try await api.registerPushToken(token: tokenHex, deviceId: storage.deviceId)
            if !result.enabled {
                NSLog("[Push] Backend reports push disabled; nothing to register.")
            }
        } catch {
            NSLog("[Push] Token registration failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    /// Run once a profile becomes active (a fresh login or a restored session):
    /// request notification permission + APNs registration and flush any deep
    /// link captured before sign-in.
    private func onAuthenticated() {
        pushRegistrar?.requestAuthorizationAndRegister()
        if let pending = pendingDeepLinkVideoId {
            pendingDeepLinkVideoId = nil
            deepLinkVideo = DeepLinkVideo(id: pending)
        }
    }

    private func connectWebSocket(userId: String) {
        guard let serverUrl = storage.serverUrl, !serverUrl.isEmpty else { return }
        // The socket fetches its own short-lived ticket; the session token (read
        // from storage, already set by login/checkSession) never goes on the URL.
        webSocket.connect(serverUrl: serverUrl, userId: userId)
    }
}

/// A video the app should open in the player, captured from a notification
/// payload or a `nullfeed://player/<id>` deep link. Identifiable so it can drive
/// a `fullScreenCover(item:)`.
struct DeepLinkVideo: Identifiable, Hashable, Sendable {
    let id: String
}
