import SwiftUI

struct SearchView: View {
    @Environment(APIClient.self) private var api
    @State private var viewModel: SearchViewModel?
    @State private var searchText = ""
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let vm = viewModel {
                    content(vm)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NullFeedTheme.background)
            // Route through a dedicated enum so pushing a video to the player
            // doesn't collide with the `Video.self` destination that
            // ChannelDetailView declares for its own rows once it's on the stack.
            .navigationDestination(for: SearchDestination.self) { destination in
                switch destination {
                case let .player(videoId):
                    PlayerView(videoId: videoId)
                case let .channel(channelId):
                    ChannelDetailView(channelId: channelId)
                }
            }
            .searchable(text: $searchText, prompt: "Search videos and channels")
        }
        .task {
            if viewModel == nil {
                viewModel = SearchViewModel(api: api)
            }
        }
        .onChange(of: searchText) { _, newValue in
            viewModel?.queryChanged(newValue)
        }
    }

    @ViewBuilder
    private func content(_ vm: SearchViewModel) -> some View {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Idle: nothing typed yet.
            EmptyStateView(
                iconName: "magnifyingglass",
                title: "Search NullFeed",
                subtitle: "Find videos and channels in your library"
            )
        } else {
            StateView(state: .resolve(
                isLoading: vm.isLoading,
                isEmpty: vm.isEmpty,
                error: vm.error,
                empty: (
                    icon: "magnifyingglass",
                    title: "No Results",
                    subtitle: "Nothing matched \u{201C}\(searchText)\u{201D}"
                ),
                retry: { vm.retry() }
            )) {
                results(vm)
            }
        }
    }

    @ViewBuilder
    private func results(_ vm: SearchViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                if !vm.channels.isEmpty {
                    ContentRowView(title: "Channels") {
                        ForEach(vm.channels) { channel in
                            Button {
                                path.append(SearchDestination.channel(channelId: channel.id))
                            } label: {
                                ChannelCardView(channel: channel)
                            }
                            .buttonStyle(CardButtonStyle())
                        }
                    }
                }

                if !vm.videos.isEmpty {
                    videoSection(vm)
                }
            }
            .padding(.vertical, NullFeedTheme.contentPadding)
        }
    }

    @ViewBuilder
    private func videoSection(_ vm: SearchViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Videos")
                .font(NullFeedTheme.headlineSmall)
                .foregroundStyle(NullFeedTheme.textPrimary)
                .padding(.horizontal, NullFeedTheme.contentPadding)

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(AppConstants.videoCardWidth), spacing: 40), count: 4),
                spacing: 40
            ) {
                ForEach(vm.videos) { video in
                    VideoCardView(video: video) {
                        path.append(SearchDestination.player(videoId: video.id))
                    }
                    .onAppear {
                        // Reaching the last card pulls the next page.
                        if video.id == vm.videos.last?.id {
                            Task { await vm.loadMore() }
                        }
                    }
                }
            }
            .padding(.horizontal, NullFeedTheme.contentPadding)

            if vm.isLoadingMore {
                ProgressView()
                    .tint(NullFeedTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
        }
    }
}

/// Navigation targets reachable from search. A dedicated type keeps the video
/// destination distinct from `ChannelDetailView`'s own `Video.self` rows.
private enum SearchDestination: Hashable {
    case player(videoId: String)
    case channel(channelId: String)
}
