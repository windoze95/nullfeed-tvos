import SwiftUI

@main
struct NullFeedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var storage: StorageService
    @State private var api: APIClient
    @State private var webSocket: WebSocketClient
    @State private var appState: AppState
    @State private var queue: QueueViewModel

    init() {
        let storage = StorageService()
        let api = APIClient(storage: storage)
        let webSocket = WebSocketClient(api: api)
        let queue = QueueViewModel(api: api)
        let appState = AppState(
            storage: storage,
            api: api,
            webSocket: webSocket,
            queue: queue
        )
        _storage = State(initialValue: storage)
        _api = State(initialValue: api)
        _webSocket = State(initialValue: webSocket)
        _appState = State(initialValue: appState)
        _queue = State(initialValue: queue)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(storage)
                .environment(api)
                .environment(webSocket)
                .environment(appState)
                .environment(queue)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Bridge the UIKit app delegate (APNs callbacks) to app state.
                    // Both refs are weak; setting them here -- before any login or
                    // restored session triggers registration -- keeps the wiring
                    // in place when the token/payload callbacks fire.
                    appDelegate.appState = appState
                    appState.pushRegistrar = appDelegate
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "nullfeed" else { return }

        switch url.host {
        case "player":
            if let videoId = url.pathComponents.dropFirst().first {
                appState.openVideo(videoId)
            }
        case "channel":
            if let channelId = url.pathComponents.dropFirst().first {
                _ = channelId  // Channel deep-linking is not supported yet.
            }
        default:
            break
        }
    }
}
