import SwiftUI

@main
struct NullFeedApp: App {
    @State private var storage: StorageService
    @State private var api: APIClient
    @State private var webSocket: WebSocketClient
    @State private var appState: AppState

    init() {
        let storage = StorageService()
        let api = APIClient(storage: storage)
        let appState = AppState(storage: storage, api: api)
        _storage = State(initialValue: storage)
        _api = State(initialValue: api)
        _webSocket = State(initialValue: WebSocketClient())
        _appState = State(initialValue: appState)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(storage)
                .environment(api)
                .environment(webSocket)
                .environment(appState)
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
