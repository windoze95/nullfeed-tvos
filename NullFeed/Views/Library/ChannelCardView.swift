import SwiftUI

struct ChannelCardView: View {
    let channel: Channel
    @Environment(APIClient.self) private var api

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let bannerUrl = channel.bannerUrl {
                AsyncImageView(
                    url: api.mediaURL(bannerUrl),
                    cornerRadius: NullFeedTheme.cardRadius
                )
            } else {
                LinearGradient(
                    colors: [NullFeedTheme.cardHover, NullFeedTheme.surface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)

            HStack(spacing: 14) {
                AsyncImageView(url: api.mediaURL(channel.avatarUrl), cornerRadius: 26)
                    .frame(width: 52, height: 52)
                    .overlay {
                        if channel.avatarUrl?.isEmpty != false {
                            Text(channel.name.prefix(1).uppercased())
                                .font(NullFeedTheme.titleSmall)
                                .foregroundStyle(NullFeedTheme.accent)
                        }
                    }

                Text(channel.name)
                    .font(NullFeedTheme.titleSmall)
                    .foregroundStyle(NullFeedTheme.textPrimary)
                    .lineLimit(2)
            }
            .padding(16)
        }
        .frame(
            width: AppConstants.channelCardWidth,
            height: AppConstants.channelCardWidth / AppConstants.cardAspectRatio
        )
        .clipShape(RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }
}
