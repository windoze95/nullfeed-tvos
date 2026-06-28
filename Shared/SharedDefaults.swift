import Foundation

/// Server location and session credentials shared between the NullFeed app and
/// its Top Shelf extension via an App Group `UserDefaults` suite. The app keeps
/// them in `.standard` for its own use and mirrors them here on every change
/// (see `StorageService`); the extension -- which can't import the app target --
/// reads them from this suite to build Top Shelf content without re-authenticating.
///
/// Both targets compile this file (see the `Shared` sources in `project.yml`),
/// so the App Group name and key strings have a single definition.
enum SharedDefaults {
    /// App Group both targets belong to. Must match the
    /// `com.apple.security.application-groups` entitlement in `project.yml`.
    static let appGroup = "group.codes.julian.nullfeed"

    /// `UserDefaults` keys for the shared credentials. `AppConstants` aliases
    /// these for the app's own `.standard` access, so the app and the extension
    /// always agree on the names.
    enum Key {
        static let serverUrl = "server_url"
        static let sessionToken = "session_token"
        static let selectedUserId = "selected_user_id"
    }

    /// The shared suite, or nil when the App Group isn't provisioned (e.g. a
    /// build without the entitlement). Callers treat nil as "nothing shared".
    private static var suite: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static var serverUrl: String? { suite?.string(forKey: Key.serverUrl) }
    static var sessionToken: String? { suite?.string(forKey: Key.sessionToken) }
    static var selectedUserId: String? { suite?.string(forKey: Key.selectedUserId) }

    /// Mirror the current server + session into the shared suite. A nil value
    /// removes that key, so this also covers `clearSession`/`clearAll`.
    static func update(serverUrl: String?, sessionToken: String?, selectedUserId: String?) {
        guard let suite else { return }
        write(serverUrl, forKey: Key.serverUrl, in: suite)
        write(sessionToken, forKey: Key.sessionToken, in: suite)
        write(selectedUserId, forKey: Key.selectedUserId, in: suite)
    }

    private static func write(_ value: String?, forKey key: String, in suite: UserDefaults) {
        if let value {
            suite.set(value, forKey: key)
        } else {
            suite.removeObject(forKey: key)
        }
    }
}
