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
        .background(NullFeedBackdrop())
        // Playback always lives above the entire app shell. That keeps tabs,
        // toolbars, and nested navigation out of the video experience whether
        // playback began from a card, search, queue, notification, or Top Shelf.
        .fullScreenCover(item: $appState.presentedVideo) { video in
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
