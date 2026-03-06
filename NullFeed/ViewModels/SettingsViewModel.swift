import Foundation

@MainActor
@Observable
final class SettingsViewModel {
    private let storage: StorageService
    private let appState: AppState

    init(storage: StorageService, appState: AppState) {
        self.storage = storage
        self.appState = appState
    }

    var serverUrl: String {
        storage.serverUrl ?? "Not configured"
    }

    var currentUser: User? {
        appState.currentUser
    }

    var preferredQuality: String {
        get { storage.preferredQuality }
        set { storage.preferredQuality = newValue }
    }

    func logout() {
        appState.logout()
    }
}
