import SwiftUI

@main
struct NullFeedApp: App {
    @State private var storage: StorageService
    @State private var api: APIClient
    @State private var webSocket: WebSocketClient
    @State private var appState: AppState
    @State private var queue: QueueViewModel

    init() {
        let storage = StorageService()
        let api = APIClient(storage: storage)
        let webSocket = WebSocketClient(api: api)
        let appState = AppState(storage: storage, api: api, webSocket: webSocket)
        _storage = State(initialValue: storage)
        _api = State(initialValue: api)
        _webSocket = State(initialValue: webSocket)
        _appState = State(initialValue: appState)
        _queue = State(initialValue: QueueViewModel(api: api))
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
                _ = videoId
            }
        case "channel":
            if let channelId = url.pathComponents.dropFirst().first {
                _ = channelId
            }
        default:
            break
        }
    }
}
