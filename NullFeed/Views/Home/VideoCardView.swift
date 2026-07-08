import SwiftUI

struct VideoCardView: View {
    private let video: Video
    private let channelName: String
    var onSelect: (() -> Void)?

    @Environment(APIClient.self) private var api

    /// Build from a feed row, which carries its own channel object.
    init(feedItem: FeedItem, onSelect: (() -> Void)? = nil) {
        self.video = feedItem.video
        self.channelName = feedItem.channel.name
        self.onSelect = onSelect
    }

    /// Build from a bare video (e.g. search results), reading the channel name
    /// off the video itself since no separate channel object is available.
    init(video: Video, onSelect: (() -> Void)? = nil) {
        self.video = video
        self.channelName = video.channelName
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
            .background(NullFeedTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
        }
        .buttonStyle(CardButtonStyle())
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

            if video.watchProgress > 0 {
                VStack {
                    Spacer()
                    ProgressBarView(progress: video.watchProgress)
                }
            }
        }
    }

    private var infoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(video.title)
                .font(NullFeedTheme.titleSmall)
                .foregroundStyle(NullFeedTheme.textPrimary)
                .lineLimit(2)

            Text(channelName)
                .font(NullFeedTheme.caption)
                .foregroundStyle(NullFeedTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private var thumbnailUrl: String? {
        api.mediaURL(video.thumbnailUrl)
    }
}
