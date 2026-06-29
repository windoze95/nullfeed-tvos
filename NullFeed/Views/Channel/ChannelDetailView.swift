import SwiftUI

struct ChannelDetailView: View {
    let channelId: String
    @Environment(APIClient.self) private var api
    @Environment(QueueViewModel.self) private var queue
    @State private var viewModel: ChannelDetailViewModel?
    @Namespace private var listFocus

    var body: some View {
        ZStack {
            NullFeedTheme.background.ignoresSafeArea()

            if let vm = viewModel {
                if vm.isLoading && vm.channel == nil {
                    LoadingView()
                } else if let channel = vm.channel {
                    content(vm: vm, channel: channel)
                } else if let error = vm.error {
                    ErrorStateView(message: error) {
                        Task { await vm.load(channelId: channelId) }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh") {
                    Task { await viewModel?.refresh(channelId: channelId) }
                }
            }
        }
        .navigationDestination(for: Video.self) { video in
            // Every episode plays on selection — a not-yet-cached one starts via
            // instant-stream (the player handles it).
            PlayerView(videoId: video.id)
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ChannelDetailViewModel(api: api)
            }
            Task { await viewModel?.load(channelId: channelId) }
            // Seed queue membership so the rows show Add vs Remove correctly.
            Task { await queue.ensureLoaded() }
        }
    }

    @ViewBuilder
    private func content(vm: ChannelDetailViewModel, channel: Channel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Banner header
                ZStack(alignment: .bottomLeading) {
                    AsyncImageView(url: channel.bannerUrl, cornerRadius: 0)
                        .frame(height: 300)
                        .clipped()

                    LinearGradient(
                        colors: [.clear, NullFeedTheme.background],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 150)

                    HStack(spacing: 20) {
                        AsyncImageView(url: channel.avatarUrl, cornerRadius: 30)
                            .frame(width: 60, height: 60)

                        Text(channel.name)
                            .font(NullFeedTheme.headlineMedium)
                            .foregroundStyle(NullFeedTheme.textPrimary)
                    }
                    .padding(.horizontal, NullFeedTheme.contentPadding)
                    .padding(.bottom, 20)
                }

                // Videos
                if vm.videos.isEmpty {
                    EmptyStateView(
                        iconName: "play.rectangle",
                        title: "No Videos",
                        subtitle: "Videos will appear here"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(vm.videos.enumerated()), id: \.element.id) { index, video in
                            videoRow(vm: vm, video: video)
                                .buttonStyle(CardButtonStyle())
                                .prefersDefaultFocus(index == 0, in: listFocus)
                                .contextMenu { actionMenu(vm: vm, video: video) }
                        }
                    }
                    .padding(.horizontal, NullFeedTheme.contentPadding)
                    .focusScope(listFocus)
                }
            }
        }
    }

    /// Every episode plays on selection — a not-yet-cached one starts via
    /// instant-stream. Caching is invisible, so there's no separate
    /// download/actions path.
    @ViewBuilder
    private func videoRow(vm: ChannelDetailViewModel, video: Video) -> some View {
        NavigationLink(value: video) { VideoListRowView(video: video) }
    }

    /// Long-press menu: watch-later only (caching is automatic/invisible).
    @ViewBuilder
    private func actionMenu(vm: ChannelDetailViewModel, video: Video) -> some View {
        if queue.isQueued(video.id) {
            Button(role: .destructive) {
                Task { await queue.remove(video.id) }
            } label: {
                Label("Remove from Queue", systemImage: "minus.circle")
            }
        } else {
            Button {
                Task { await queue.add(video) }
            } label: {
                Label("Add to Queue", systemImage: "plus.circle")
            }
        }
    }
}
