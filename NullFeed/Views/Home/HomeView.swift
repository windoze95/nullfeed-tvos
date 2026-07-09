import SwiftUI

struct HomeView: View {
    @Environment(APIClient.self) private var api
    @Environment(WebSocketClient.self) private var webSocket
    @Environment(AppState.self) private var appState
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
                            subtitle: "Subscribe to channels to start watching."
                        ),
                        retry: { Task { await viewModel.loadFeed() } }
                    )) {
                        feedContent(viewModel: viewModel)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NullFeedBackdrop())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        path.append(HomeRoute.queue)
                    } label: {
                        Label("Up Next", systemImage: "rectangle.stack.badge.play")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel?.refresh() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel?.isRefreshing == true)
                }
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .queue:
                    QueueView()
                }
            }
            .onChange(of: path.count) { _, newCount in
                // Returning from Up Next may have changed queue/feed state. A
                // reload with content already on screen swaps in place without a
                // loading flash.
                if newCount == 0 {
                    Task { await viewModel?.loadFeed() }
                }
            }
            .onChange(of: appState.presentedVideo) { oldValue, newValue in
                // Playback is no longer a navigation-stack entry, so refresh the
                // resume rows when the root-level cover goes away.
                if oldValue != nil, newValue == nil {
                    Task { await viewModel?.loadFeed() }
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = HomeViewModel(api: api)
            }
            await viewModel?.load()
        }
        .task {
            // Refresh content when it changes server-side -- a download finishes,
            // a preview becomes ready, a new episode arrives, watch progress
            // changes, or fresh recommendations are computed -- so the rows stay
            // current without a manual reload.
            for await event in webSocket.subscribe() {
                switch event.type {
                case .downloadComplete, .previewReady, .newEpisode, .progressUpdated:
                    await viewModel?.loadFeed()
                case .recommendationReady:
                    await viewModel?.loadRecommendations()
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
            ?? viewModel.recommendations.first?.id

        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeaderView(
                    symbol: "play.rectangle.on.rectangle.fill",
                    title: "NullFeed",
                    subtitle: homeSubtitle
                )
                .padding(.horizontal, NullFeedTheme.contentPadding)
                .padding(.bottom, 12)

                if !viewModel.continueWatching.isEmpty {
                    ContentRowView(title: "Continue Watching") {
                        ForEach(viewModel.continueWatching) { item in
                            VideoCardView(feedItem: item) {
                                appState.openVideo(item.video.id)
                            }
                            .prefersDefaultFocus(item.id == firstFocusID, in: feedFocus)
                        }
                    }
                }

                if !viewModel.newEpisodes.isEmpty {
                    ContentRowView(title: "New Episodes") {
                        ForEach(viewModel.newEpisodes) { item in
                            VideoCardView(feedItem: item) {
                                appState.openVideo(item.video.id)
                            }
                            .prefersDefaultFocus(item.id == firstFocusID, in: feedFocus)
                        }
                    }
                }

                if !viewModel.recentlyAdded.isEmpty {
                    ContentRowView(title: "Recently Added") {
                        ForEach(viewModel.recentlyAdded) { item in
                            VideoCardView(feedItem: item) {
                                appState.openVideo(item.video.id)
                            }
                            .prefersDefaultFocus(item.id == firstFocusID, in: feedFocus)
                        }
                    }
                }

                // The same recommendations shown on the Discover tab, surfaced
                // here as a discovery rail. Omitted entirely when there are none.
                if !viewModel.recommendations.isEmpty {
                    ContentRowView(title: "Recommended for You") {
                        ForEach(viewModel.recommendations) { rec in
                            RecommendationCardView(
                                recommendation: rec,
                                onSubscribe: {
                                    if let ytId = rec.youtubeChannelId {
                                        Task {
                                            do {
                                                try await api.subscribeToChannel(
                                                    url: "https://youtube.com/channel/\(ytId)"
                                                )
                                                await viewModel.dismissRecommendation(rec.id)
                                            } catch {
                                                // Keep the recommendation visible so the
                                                // viewer can retry when connectivity returns.
                                            }
                                        }
                                    }
                                },
                                onDismiss: {
                                    Task { await viewModel.dismissRecommendation(rec.id) }
                                }
                            )
                            .frame(width: AppConstants.channelCardWidth)
                            .prefersDefaultFocus(rec.id == firstFocusID, in: feedFocus)
                        }
                    }
                }
            }
            .padding(.top, 38)
            .padding(.bottom, NullFeedTheme.contentPadding)
            .focusScope(feedFocus)
        }
    }

    private var homeSubtitle: String {
        guard let name = appState.currentUser?.displayName, !name.isEmpty else {
            return "Your videos, ready when you are"
        }
        return "Welcome back, \(name)"
    }
}

/// Navigation targets reachable from Home beyond playing a video.
private enum HomeRoute: Hashable {
    case queue
}
