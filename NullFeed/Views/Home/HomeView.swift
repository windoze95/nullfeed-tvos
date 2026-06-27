import SwiftUI

struct HomeView: View {
    @Environment(APIClient.self) private var api
    @Environment(WebSocketClient.self) private var webSocket
    @State private var viewModel: HomeViewModel?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let viewModel {
                    if viewModel.isLoading && viewModel.isEmpty {
                        LoadingView()
                    } else if viewModel.isEmpty {
                        EmptyStateView(
                            iconName: "play.rectangle.on.rectangle",
                            title: "Nothing Here Yet",
                            subtitle: "Subscribe to channels and download videos to start watching."
                        )
                    } else {
                        feedContent(viewModel: viewModel)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NullFeedTheme.background)
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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 40) {
                if !viewModel.continueWatching.isEmpty {
                    ContentRowView(title: "Continue Watching") {
                        ForEach(viewModel.continueWatching) { item in
                            VideoCardView(feedItem: item) {
                                path.append(item.video)
                            }
                        }
                    }
                }

                if !viewModel.newEpisodes.isEmpty {
                    ContentRowView(title: "New Episodes") {
                        ForEach(viewModel.newEpisodes) { item in
                            VideoCardView(feedItem: item) {
                                path.append(item.video)
                            }
                        }
                    }
                }

                if !viewModel.recentlyAdded.isEmpty {
                    ContentRowView(title: "Recently Added") {
                        ForEach(viewModel.recentlyAdded) { item in
                            VideoCardView(feedItem: item) {
                                path.append(item.video)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, NullFeedTheme.contentPadding)
        }
    }
}
