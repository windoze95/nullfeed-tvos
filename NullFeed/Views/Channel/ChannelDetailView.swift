import SwiftUI

struct ChannelDetailView: View {
    let channelId: String
    @Environment(APIClient.self) private var api
    @Environment(QueueViewModel.self) private var queue
    @Environment(AppState.self) private var appState
    @State private var viewModel: ChannelDetailViewModel?
    @Namespace private var listFocus

    var body: some View {
        ZStack {
            NullFeedBackdrop()

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
            // Per-channel content-type filter — only when subscribed and the
            // channel has more than one kind of media. A checklist of just the
            // types it has; toggling persists and re-fetches the gated list.
            if let vm = viewModel, let channel = vm.channel, channel.showContentFilter {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(channel.availableContentTypesParsed, id: \.self) { type in
                            Button {
                                Task { await vm.toggleContentType(type, channelId: channelId) }
                            } label: {
                                Label(
                                    type.menuLabel,
                                    systemImage: channel.isHidden(type) ? "square" : "checkmark.square"
                                )
                            }
                        }
                    } label: {
                        Label(
                            "Filter",
                            systemImage: (channel.hiddenContentTypes ?? []).isEmpty
                                ? "line.3.horizontal.decrease.circle"
                                : "line.3.horizontal.decrease.circle.fill"
                        )
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel?.refresh(channelId: channelId) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel?.isRefreshing == true)
            }
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
                    Group {
                        if let bannerUrl = channel.bannerUrl {
                            AsyncImageView(url: api.mediaURL(bannerUrl), cornerRadius: 0)
                        } else {
                            LinearGradient(
                                colors: [NullFeedTheme.cardHover, NullFeedTheme.background],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
                    .frame(height: 320)
                    .clipped()

                    LinearGradient(
                        colors: [.clear, NullFeedTheme.background.opacity(0.96)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 210)

                    HStack(alignment: .bottom, spacing: 24) {
                        AsyncImageView(url: api.mediaURL(channel.avatarUrl), cornerRadius: 42)
                            .frame(width: 84, height: 84)
                            .overlay {
                                ZStack {
                                    Circle().stroke(.white.opacity(0.16), lineWidth: 2)
                                    if channel.avatarUrl?.isEmpty != false {
                                        Text(channel.name.prefix(1).uppercased())
                                            .font(NullFeedTheme.headlineSmall)
                                            .foregroundStyle(NullFeedTheme.accent)
                                    }
                                }
                            }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(channel.name)
                                .font(NullFeedTheme.headlineMedium)
                                .foregroundStyle(NullFeedTheme.textPrimary)

                            if let description = channel.description, !description.isEmpty {
                                Text(description)
                                    .font(NullFeedTheme.bodySmall)
                                    .foregroundStyle(NullFeedTheme.textSecondary)
                                    .lineLimit(2)
                                    .frame(maxWidth: 1050, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal, NullFeedTheme.contentPadding)
                    .padding(.bottom, 24)
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
                    LazyVStack(spacing: 14) {
                        ForEach(Array(vm.videos.enumerated()), id: \.element.id) { index, video in
                            videoRow(vm: vm, video: video)
                                .buttonStyle(CardButtonStyle())
                                .prefersDefaultFocus(index == 0, in: listFocus)
                                .contextMenu { actionMenu(vm: vm, video: video) }
                        }
                    }
                    .padding(.horizontal, NullFeedTheme.contentPadding)
                    .padding(.bottom, NullFeedTheme.contentPadding)
                    .focusScope(listFocus)
                }
            }
        }
        .scrollClipDisabled()
    }

    /// Every episode plays on selection — a not-yet-cached one starts via
    /// instant-stream. Caching is invisible, so there's no separate
    /// download/actions path.
    @ViewBuilder
    private func videoRow(vm: ChannelDetailViewModel, video: Video) -> some View {
        Button {
            appState.openVideo(video.id)
        } label: {
            VideoListRowView(video: video)
        }
    }

    /// Long-press menu: watch-later only (caching is automatic/invisible).
    @ViewBuilder
    private func actionMenu(vm: ChannelDetailViewModel, video: Video) -> some View {
        if queue.isQueued(video.id) {
            Button(role: .destructive) {
                Task { await queue.remove(video.id) }
            } label: {
                Label("Remove from Up Next", systemImage: "minus.circle")
            }
        } else {
            Button {
                Task { await queue.add(video) }
            } label: {
                Label("Add to Up Next", systemImage: "plus.circle")
            }
        }
    }
}
