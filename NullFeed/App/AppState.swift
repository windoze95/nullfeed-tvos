import SwiftUI

@MainActor
@Observable
final class AppState {
    var currentUser: User?
    var isAuthenticated: Bool { currentUser != nil }
    var isLoading = true
    /// Changes when Settings saves a new backend origin. The app shell uses it
    /// to rebuild data-backed screens so content from two servers never mixes.
    var serverRevision = 0

    /// The video currently presented above the app shell. Every play action,
    /// including Top Shelf and notification deep links, comes through this one
    /// route so the tab bar and navigation stack never remain visible behind
    /// playback. Cleared automatically when the full-screen player is dismissed.
    var presentedVideo: PlaybackDestination?

    /// A deep-link target captured before a profile was active (e.g. the app was
    /// opened from the Top Shelf while signed out); applied once authenticated.
    private var pendingDeepLinkVideoId: String?

    /// The UIKit app delegate, used to request notification authorization and
    /// APNs registration. Weak to avoid a retain cycle (it holds AppState).
    weak var pushRegistrar: (any PushRegistering)?

    private let storage: StorageService
    private let api: APIClient
    private let webSocket: WebSocketClient
    private let queue: QueueViewModel

    init(
        storage: StorageService,
        api: APIClient,
        webSocket: WebSocketClient,
        queue: QueueViewModel
    ) {
        self.storage = storage
        self.api = api
        self.webSocket = webSocket
        self.queue = queue
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
        queue.reset()
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
        queue.reset()
        currentUser = nil
        presentedVideo = nil
        pendingDeepLinkVideoId = nil
    }

    /// Open `videoId` in the player. Defers until a profile is active when the
    /// app isn't authenticated yet (e.g. a Top Shelf deep link before sign-in).
    func openVideo(_ videoId: String) {
        guard isAuthenticated else {
            pendingDeepLinkVideoId = videoId
            return
        }
        presentedVideo = PlaybackDestination(id: videoId)
    }

    /// Rebind services after Settings saves a different server address. The
    /// active profile remains selected (useful when only the host name changed),
    /// while tickets and the realtime socket are recreated for the new origin.
    func serverConfigurationDidChange() {
        api.resetConnectionState()
        queue.reset()
        serverRevision += 1
        guard let userId = currentUser?.id else { return }
        webSocket.disconnect()
        connectWebSocket(userId: userId)
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
            presentedVideo = PlaybackDestination(id: pending)
        }
    }

    private func connectWebSocket(userId: String) {
        guard let serverUrl = storage.serverUrl, !serverUrl.isEmpty else { return }
        // The socket fetches its own short-lived ticket; the session token (read
        // from storage, already set by login/checkSession) never goes on the URL.
        webSocket.connect(serverUrl: serverUrl, userId: userId)
    }
}

/// A play request from any app surface. Identifiable so it can drive the single
/// root-level `fullScreenCover(item:)` used for navigation-free playback.
struct PlaybackDestination: Identifiable, Hashable, Sendable {
    let id: String
}
