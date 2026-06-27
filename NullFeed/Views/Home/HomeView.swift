import SwiftUI

struct HomeView: View {
    @Environment(APIClient.self) private var api
    @Environment(WebSocketClient.self) private var webSocket
    @State private var viewModel: HomeViewModel?
    @State private var path = NavigationPath()
    @Namespace private var feedFocus

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let viewModel {
                    StateView(state: .resolve(
                        isLoading: viewModel.isLoading,
                        isEmpty: viewModel.isEmpty,
                        error: viewModel.error,
                        empty: (
                            icon: "play.rectangle.on.rectangle",
                            title: "Nothing Here Yet",
                            subtitle: "Subscribe to channels and download videos to start watching."
                        ),
                        retry: { Task { await viewModel.loadFeed() } }
                    )) {
                        feedContent(viewModel: viewModel)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NullFeedTheme.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") {
                        Task { await viewModel?.refresh() }
                    }
                }
            }
            .navigationDestination(for: Video.self) { video in
                PlayerView(videoId: video.id)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = HomeViewModel(api: api)
            }
            await viewModel?.loadFeed()
        }
        .task {
            // Refresh the feeds when a download finishes or a preview becomes
            // ready, so newly playable content appears without a manual reload.
            for await event in webSocket.subscribe() {
                switch event.type {
                case .downloadComplete, .previewReady:
                    await viewModel?.loadFeed()
                default:
                    break
                }
            }
        }
    }

    @ViewBuilder
    private func feedContent(viewModel: HomeViewModel) -> some View {
        // First card of the first non-empty row gets deterministic initial focus.
        let firstFocusID = viewModel.continueWatching.first?.id
            ?? viewModel.newEpisodes.first?.id
            ?? viewModel.recentlyAdded.first?.id

        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 40) {
                if !viewModel.continueWatching.isEmpty {
                    ContentRowView(title: "Continue Watching") {
                        ForEach(viewModel.continueWatching) { item in
                            VideoCardView(feedItem: item) {
                                path.append(item.video)
                            }
                            .prefersDefaultFocus(item.id == firstFocusID, in: feedFocus)
                        }
                    }
                }

                if !viewModel.newEpisodes.isEmpty {
                    ContentRowView(title: "New Episodes") {
                        ForEach(viewModel.newEpisodes) { item in
                            VideoCardView(feedItem: item) {
                                path.append(item.video)
                            }
                            .prefersDefaultFocus(item.id == firstFocusID, in: feedFocus)
                        }
                    }
                }

                if !viewModel.recentlyAdded.isEmpty {
                    ContentRowView(title: "Recently Added") {
                        ForEach(viewModel.recentlyAdded) { item in
                            VideoCardView(feedItem: item) {
                                path.append(item.video)
                            }
                            .prefersDefaultFocus(item.id == firstFocusID, in: feedFocus)
                        }
                    }
                }
            }
            .padding(.vertical, NullFeedTheme.contentPadding)
            .focusScope(feedFocus)
        }
    }
}
