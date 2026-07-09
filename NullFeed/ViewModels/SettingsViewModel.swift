import Foundation

@MainActor
@Observable
final class SettingsViewModel {
    enum ConnectionState: Equatable {
        case unchecked
        case checking
        case connected
        case unreachable
    }

    var serverUrl: String
    var connectionState: ConnectionState = .unchecked
    var message: String?
    var youtubeAccountStatus: YouTubeAccountStatus?
    var youtubeAccountError: String?
    var isLoadingYouTubeAccount = false

    private let storage: StorageService
    private let api: APIClient
    private let appState: AppState

    init(storage: StorageService, api: APIClient, appState: AppState) {
        self.storage = storage
        self.api = api
        self.appState = appState
        serverUrl = storage.serverUrl ?? ""
    }

    var normalizedServerUrl: String? {
        APIClient.normalizedServerURL(serverUrl)
    }

    var isCheckingConnection: Bool {
        connectionState == .checking
    }

    var hasUnsavedServerUrl: Bool {
        normalizedServerUrl != storage.serverUrl
    }

    var currentUser: User? {
        appState.currentUser
    }

    var version: String {
        let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return value ?? "—"
    }

    var build: String {
        let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return value ?? "—"
    }

    @discardableResult
    func testConnection() async -> Bool {
        guard let normalizedServerUrl else {
            connectionState = .unreachable
            message = "Enter a valid HTTP or HTTPS server address."
            return false
        }

        let testedUrl = normalizedServerUrl
        connectionState = .checking
        message = nil
        let reachable = await api.checkHealth(serverURL: testedUrl)
        // Ignore a result for text that changed while the request was in flight.
        guard self.normalizedServerUrl == testedUrl else {
            connectionState = .unchecked
            return false
        }
        connectionState = reachable ? .connected : .unreachable
        message = reachable ? "Server is reachable." : "Could not reach this server."
        return reachable
    }

    func saveServerUrl() async {
        guard let normalizedServerUrl else {
            connectionState = .unreachable
            message = "Enter a valid HTTP or HTTPS server address."
            return
        }
        guard await testConnection() else { return }

        storage.serverUrl = normalizedServerUrl
        serverUrl = normalizedServerUrl
        appState.serverConfigurationDidChange()
        message = "Connected and saved."
    }

    func loadYouTubeAccountStatus() async {
        guard currentUser?.isAdmin == true else { return }
        isLoadingYouTubeAccount = true
        youtubeAccountError = nil
        do {
            youtubeAccountStatus = try await api.getYouTubeAccountStatus()
        } catch {
            youtubeAccountError = error.localizedDescription
        }
        isLoadingYouTubeAccount = false
    }

    func logout() {
        appState.logout()
    }
}
