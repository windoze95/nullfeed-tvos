import SwiftUI

struct ChannelDetailView: View {
    let channelId: String
    @Environment(APIClient.self) private var api
    @State private var viewModel: ChannelDetailViewModel?

    var body: some View {
        ZStack {
            NullFeedTheme.background.ignoresSafeArea()

            if let vm = viewModel {
                if vm.isLoading && vm.channel == nil {
                    LoadingView()
                } else if let channel = vm.channel {
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
                                    ForEach(vm.videos) { video in
                                        NavigationLink(value: video) {
                                            VideoListRowView(video: video)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, NullFeedTheme.contentPadding)
                            }
                        }
                    }
                }

                if let error = vm.error {
                    Text(error)
                        .font(NullFeedTheme.bodySmall)
                        .foregroundStyle(NullFeedTheme.error)
                }
            }
        }
        .navigationDestination(for: Video.self) { video in
            if video.isPlayable {
                PlayerView(videoId: video.id)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ChannelDetailViewModel(api: api)
            }
            Task { await viewModel?.load(channelId: channelId) }
        }
    }
}
