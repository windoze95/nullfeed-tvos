import Foundation

@MainActor
@Observable
final class StorageService {
    private let defaults: UserDefaults

    init() {
        self.defaults = .standard
    }

    var serverUrl: String? {
        get { defaults.string(forKey: AppConstants.serverUrlKey) }
        set { defaults.set(newValue, forKey: AppConstants.serverUrlKey) }
    }

    var selectedUserId: String? {
        get { defaults.string(forKey: AppConstants.selectedUserIdKey) }
        set { defaults.set(newValue, forKey: AppConstants.selectedUserIdKey) }
    }

    var sessionToken: String? {
        get { defaults.string(forKey: AppConstants.sessionTokenKey) }
        set { defaults.set(newValue, forKey: AppConstants.sessionTokenKey) }
    }

    var preferredQuality: String {
        get { defaults.string(forKey: AppConstants.preferredQualityKey) ?? "1080p" }
        set { defaults.set(newValue, forKey: AppConstants.preferredQualityKey) }
    }

    func clearSession() {
        defaults.removeObject(forKey: AppConstants.selectedUserIdKey)
        defaults.removeObject(forKey: AppConstants.sessionTokenKey)
    }

    func clearAll() {
        defaults.removeObject(forKey: AppConstants.serverUrlKey)
        defaults.removeObject(forKey: AppConstants.selectedUserIdKey)
        defaults.removeObject(forKey: AppConstants.sessionTokenKey)
        defaults.removeObject(forKey: AppConstants.preferredQualityKey)
    }
}
