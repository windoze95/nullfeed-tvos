import SwiftUI

struct ChannelCardView: View {
    let channel: Channel

    var body: some View {
        ZStack(alignment: .bottom) {
            AsyncImageView(
                url: channel.bannerUrl ?? channel.avatarUrl,
                cornerRadius: NullFeedTheme.cardRadius
            )
            .frame(width: AppConstants.channelCardWidth, height: AppConstants.channelCardWidth / AppConstants.cardAspectRatio)

            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)
            .clipShape(
                UnevenRoundedRectangle(
                    bottomLeadingRadius: NullFeedTheme.cardRadius,
                    bottomTrailingRadius: NullFeedTheme.cardRadius
                )
            )

            Text(channel.name)
                .font(NullFeedTheme.titleSmall)
                .foregroundStyle(NullFeedTheme.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .frame(width: AppConstants.channelCardWidth)
        .clipShape(RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
    }
}
