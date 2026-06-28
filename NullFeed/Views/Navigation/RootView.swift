import SwiftUI

struct RootView: View {
    @Environment(StorageService.self) private var storage
    @Environment(APIClient.self) private var api
    @Environment(AppState.self) private var appState

    @State private var authViewModel: AuthViewModel?

    var body: some View {
        @Bindable var appState = appState
        Group {
            if appState.isLoading {
                LoadingView()
            } else if appState.isAuthenticated {
                MainTabView()
            } else if let viewModel = authViewModel {
                if viewModel.isConnected {
                    ProfilePickerView(viewModel: viewModel)
                } else {
                    ServerSetupView(viewModel: viewModel)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NullFeedTheme.background)
        // A notification payload or Top Shelf "play" deep link opens the player
        // over whatever is showing. Driven by AppState so any surface that wants
        // to start playback just sets `deepLinkVideo` (only set once authenticated).
        .fullScreenCover(item: $appState.deepLinkVideo) { video in
            PlayerView(videoId: video.id)
        }
        .task {
            if authViewModel == nil {
                authViewModel = AuthViewModel(storage: storage, api: api, appState: appState)
            }
            await appState.checkSession()
        }
    }
}
