import SwiftUI

struct VideoCardView: View {
    let feedItem: FeedItem
    var onSelect: (() -> Void)?

    @FocusState private var isFocused: Bool

    private var video: Video { feedItem.video }
    private var channel: Channel { feedItem.channel }

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
            .overlay(
                RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius)
                    .stroke(isFocused ? NullFeedTheme.primary : .clear, lineWidth: NullFeedTheme.focusBorderWidth)
            )
            .scaleEffect(isFocused ? NullFeedTheme.focusScale : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
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

            Text(channel.name)
                .font(NullFeedTheme.caption)
                .foregroundStyle(NullFeedTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private var thumbnailUrl: String {
        if let avatarUrl = channel.avatarUrl, !avatarUrl.isEmpty {
            return avatarUrl
        }
        return ""
    }
}
