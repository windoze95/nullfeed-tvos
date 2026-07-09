import SwiftUI

struct VideoCardView: View {
    private let video: Video
    private let channelName: String
    private let channelAvatarUrl: String?
    var onSelect: (() -> Void)?

    @Environment(APIClient.self) private var api
    @Environment(QueueViewModel.self) private var queue

    /// Build from a feed row, which carries its own channel object.
    init(feedItem: FeedItem, onSelect: (() -> Void)? = nil) {
        self.video = feedItem.video
        self.channelName = feedItem.channel.name
        self.channelAvatarUrl = feedItem.channel.avatarUrl
        self.onSelect = onSelect
    }

    /// Build from a bare video (e.g. search results), reading the channel name
    /// off the video itself since no separate channel object is available.
    init(video: Video, onSelect: (() -> Void)? = nil) {
        self.video = video
        self.channelName = video.channelName
        self.channelAvatarUrl = nil
        self.onSelect = onSelect
    }

    var body: some View {
        Button {
            onSelect?()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                thumbnailView
                infoView
            }
            .frame(width: AppConstants.videoCardWidth)
            .contentShape(RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
        }
        .buttonStyle(CardButtonStyle())
        .contextMenu {
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
        .task { await queue.ensureLoaded() }
        .accessibilityLabel("\(video.title), \(channelName)")
        .accessibilityHint("Play video")
    }

    private var thumbnailView: some View {
        ZStack(alignment: .bottomTrailing) {
            AsyncImageView(url: thumbnailUrl)
                .aspectRatio(AppConstants.cardAspectRatio, contentMode: .fill)
                .frame(width: AppConstants.videoCardWidth, height: AppConstants.videoCardWidth / AppConstants.cardAspectRatio)
                .clipped()

            if video.durationSeconds > 0 {
                Text(video.formattedDuration)
                    .font(NullFeedTheme.caption)
                    .foregroundStyle(NullFeedTheme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(8)
            }

            // Why this video can't play (age-restricted, members-only, …) —
            // hidden once a local file makes it playable anyway. Otherwise the
            // content-type pill (Short/Live/…) takes the same corner; the two
            // never show together.
            if let reason = video.activeUnplayableReason {
                UnplayableBadgeView(reason: reason)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if let type = video.badgeContentType {
                ContentTypeBadgeView(type: type)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            if video.watchProgress > 0 && !video.isWatched {
                VStack {
                    Spacer()
                    ProgressBarView(progress: video.watchProgress)
                }
            }

            if video.isWatched {
                Label("Watched", systemImage: "checkmark.circle.fill")
                    .font(NullFeedTheme.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.72), in: Capsule())
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }

            if queue.isQueued(video.id) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.black.opacity(0.72), in: Circle())
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var infoView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(video.title)
                .font(NullFeedTheme.titleSmall)
                .foregroundStyle(NullFeedTheme.textPrimary)
                .lineLimit(2)

            HStack(spacing: 8) {
                if let channelAvatarUrl {
                    AsyncImageView(url: api.mediaURL(channelAvatarUrl), cornerRadius: 12)
                        .frame(width: 24, height: 24)
                }
                Text(channelName)
                    .font(NullFeedTheme.caption)
                    .foregroundStyle(NullFeedTheme.textMuted)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 2)
    }

    private var thumbnailUrl: String? {
        api.mediaURL(video.thumbnailUrl)
    }
}
