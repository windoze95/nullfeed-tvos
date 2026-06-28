import Foundation

@MainActor
@Observable
final class StorageService {
    private let defaults: UserDefaults

    init() {
        self.defaults = .standard
        // Backfill the App Group suite on launch so the Top Shelf extension has
        // the current session even for logins that predate this mirroring -- and
        // re-sync it if the shared copy ever drifts from `.standard`.
        syncSharedDefaults()
    }

    var serverUrl: String? {
        get { defaults.string(forKey: AppConstants.serverUrlKey) }
        set {
            defaults.set(newValue, forKey: AppConstants.serverUrlKey)
            syncSharedDefaults()
        }
    }

    var selectedUserId: String? {
        get { defaults.string(forKey: AppConstants.selectedUserIdKey) }
        set {
            defaults.set(newValue, forKey: AppConstants.selectedUserIdKey)
            syncSharedDefaults()
        }
    }

    var sessionToken: String? {
        get { defaults.string(forKey: AppConstants.sessionTokenKey) }
        set {
            defaults.set(newValue, forKey: AppConstants.sessionTokenKey)
            syncSharedDefaults()
        }
    }

    var preferredQuality: String {
        get { defaults.string(forKey: AppConstants.preferredQualityKey) ?? "1080p" }
        set { defaults.set(newValue, forKey: AppConstants.preferredQualityKey) }
    }

    /// A stable identifier for this install, used to key push registration on the
    /// backend. Generated on first access and persisted; kept across logins (and
    /// `clearSession`/`clearAll`) so re-registration updates the same record.
    var deviceId: String {
        if let existing = defaults.string(forKey: AppConstants.deviceIdKey) {
            return existing
        }
        let generated = UUID().uuidString
        defaults.set(generated, forKey: AppConstants.deviceIdKey)
        return generated
    }

    func clearSession() {
        defaults.removeObject(forKey: AppConstants.selectedUserIdKey)
        defaults.removeObject(forKey: AppConstants.sessionTokenKey)
        syncSharedDefaults()
    }

    func clearAll() {
        defaults.removeObject(forKey: AppConstants.serverUrlKey)
        defaults.removeObject(forKey: AppConstants.selectedUserIdKey)
        defaults.removeObject(forKey: AppConstants.sessionTokenKey)
        defaults.removeObject(forKey: AppConstants.preferredQualityKey)
        syncSharedDefaults()
    }

    /// Mirror the server + session into the App Group suite after any change, so
    /// the Top Shelf extension -- which can't read `.standard` -- sees the
    /// current values. App-only keys (quality, device id) aren't shared.
    private func syncSharedDefaults() {
        SharedDefaults.update(
            serverUrl: serverUrl,
            sessionToken: sessionToken,
            selectedUserId: selectedUserId
        )
    }
}
