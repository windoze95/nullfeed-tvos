import SwiftUI

struct SearchView: View {
    @Environment(APIClient.self) private var api
    @Environment(AppState.self) private var appState
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
            .background(NullFeedBackdrop())
            .navigationDestination(for: SearchDestination.self) { destination in
                switch destination {
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
                ScreenHeaderView(
                    symbol: "magnifyingglass",
                    title: "Search Results",
                    subtitle: resultSubtitle(vm)
                )
                .padding(.horizontal, NullFeedTheme.contentPadding)

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

            LazyVGrid(columns: NullFeedLayout.videoGridColumns, spacing: NullFeedLayout.gridSpacing) {
                ForEach(vm.videos) { video in
                    VideoCardView(video: video) {
                        appState.openVideo(video.id)
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

    private func resultSubtitle(_ vm: SearchViewModel) -> String {
        let total = vm.channels.count + vm.total
        return "\(total) \(total == 1 ? "match" : "matches") for “\(searchText)”"
    }
}

/// Browsing destinations stay in Search's stack. Playback is intentionally
/// presented by RootView above the entire app shell instead.
private enum SearchDestination: Hashable {
    case channel(channelId: String)
}
