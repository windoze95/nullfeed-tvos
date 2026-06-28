import UIKit
import UserNotifications

/// Lets `AppState` ask the UIKit app delegate to request notification
/// authorization and register with APNs, without taking a direct dependency on
/// UIKit. The delegate is the concrete conformer.
@MainActor
protocol PushRegistering: AnyObject {
    func requestAuthorizationAndRegister()
}

/// Bridges the SwiftUI `App` to the UIKit/APNs lifecycle: requests notification
/// authorization, registers the APNs device token with the backend, and routes
/// remote-notification payloads to the player. Installed via
/// `@UIApplicationDelegateAdaptor` in `NullFeedApp`; `appState` is wired in once
/// the SwiftUI layer appears.
///
/// tvOS note: there is no notification-tap delegate (`didReceiveNotification`
/// `Response` is unavailable on tvOS), so a tapped/opened notification reaches
/// the player two ways instead -- a `nullfeed://player/<id>` deep link (the Top
/// Shelf "play" action and `onOpenURL`) and `didReceiveRemoteNotification` for a
/// payload delivered to the running app. Both funnel through `AppState.openVideo`.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// The app's shared state hub, set by `NullFeedApp` after launch. Weak to
    /// avoid a retain cycle (AppState holds the delegate as `pushRegistrar`).
    weak var appState: AppState?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - PushRegistering

    /// Request notification authorization and, if granted, register with APNs.
    /// Safe to call on every launch: the system prompts only once, and a repeat
    /// `registerForRemoteNotifications()` simply refreshes the device token.
    func requestAuthorizationAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                NSLog("[Push] Authorization error: \(error.localizedDescription)")
            }
            guard granted else { return }
            Task { @MainActor in
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // MARK: - APNs registration callbacks

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await appState?.registerPushToken(token) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NSLog("[Push] Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // MARK: - Remote notification payload

    /// Deliver a remote notification's payload to the app. On tvOS this is the
    /// available hook for reacting to a push (the iOS tap handler does not
    /// exist), so pull the target video id and open the player.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if let videoId = Self.videoId(from: userInfo) {
            appState?.openVideo(videoId)
        }
        completionHandler(.noData)
    }

    /// Pull the target video id from an APNs payload. The new-episode push nests
    /// it under `data` (`{"type": "new_episode", "video_id": "..."}`); a
    /// top-level `video_id` is accepted as a fallback.
    private static func videoId(from userInfo: [AnyHashable: Any]) -> String? {
        if let data = userInfo["data"] as? [AnyHashable: Any], let id = data["video_id"] as? String {
            return id
        }
        return userInfo["video_id"] as? String
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Surface a notification that arrives while the app is foregrounded.
    /// `nonisolated` so it satisfies the requirement regardless of how the SDK
    /// isolates the protocol; it touches no actor-isolated state.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

extension AppDelegate: PushRegistering {}
