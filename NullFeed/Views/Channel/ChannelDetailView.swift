import SwiftUI

struct ChannelDetailView: View {
    let channelId: String
    @Environment(APIClient.self) private var api
    @Environment(WebSocketClient.self) private var webSocket
    @Environment(QueueViewModel.self) private var queue
    @State private var viewModel: ChannelDetailViewModel?
    @State private var actionSheetVideo: Video?
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
            // Only playable videos navigate here now; non-playable rows open the
            // actions sheet instead of pushing a blank player (issue #16).
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
        .task {
            // Mirror live download progress onto the rows: advance the bar as
            // `download_progress` events arrive and flip a row to playable once
            // its download completes.
            for await event in webSocket.subscribe() {
                await viewModel?.handle(event)
            }
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
                        subtitle: "Videos will appear here once downloaded"
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
        .sheet(item: $actionSheetVideo) { video in
            VideoActionsSheet(
                video: video,
                thumbnailURL: api.mediaURL(video.thumbnailUrl),
                isQueued: queue.isQueued(video.id),
                onAddToQueue: { Task { await queue.add(video) } },
                onRemoveFromQueue: { Task { await queue.remove(video.id) } },
                onDownload: { Task { await vm.downloadVideo(video.id) } },
                onCancel: { Task { await vm.cancelDownload(video.id) } },
                onDelete: { Task { await vm.deleteVideo(video.id) } }
            )
        }
    }

    /// A playable video plays on selection (unchanged); a non-playable one opens
    /// the actions sheet instead of pushing a blank player.
    @ViewBuilder
    private func videoRow(vm: ChannelDetailViewModel, video: Video) -> some View {
        let row = VideoListRowView(video: video, downloadProgress: vm.downloadProgress[video.id])
        if video.isPlayable {
            NavigationLink(value: video) { row }
        } else {
            Button { actionSheetVideo = video } label: { row }
        }
    }

    /// Long-press menu mirroring the sheet's status-appropriate actions, so even
    /// playable rows can be downloaded (HQ upgrade) or deleted from the couch.
    @ViewBuilder
    private func actionMenu(vm: ChannelDetailViewModel, video: Video) -> some View {
        if video.isDownloadable {
            Button {
                Task { await vm.downloadVideo(video.id) }
            } label: {
                Label(video.status == .failed ? "Retry Download" : "Download", systemImage: "arrow.down.circle")
            }
        }
        if video.isInProgress {
            Button(role: .destructive) {
                Task { await vm.cancelDownload(video.id) }
            } label: {
                Label("Cancel Download", systemImage: "xmark.circle")
            }
        }
        if video.status == .complete {
            Button(role: .destructive) {
                Task { await vm.deleteVideo(video.id) }
            } label: {
                Label("Delete Download", systemImage: "trash")
            }
        }
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
