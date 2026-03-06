import SwiftUI

struct RecommendationCardView: View {
    let recommendation: Recommendation
    let onSubscribe: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Banner / Avatar
            ZStack(alignment: .bottomLeading) {
                AsyncImageView(
                    url: recommendation.bannerUrl ?? recommendation.avatarUrl,
                    cornerRadius: 0
                )
                .frame(height: 140)
                .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 70)

                Text(recommendation.channelName)
                    .font(NullFeedTheme.titleSmall)
                    .foregroundStyle(NullFeedTheme.textPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }

            // Reasoning
            Text(recommendation.reasoning)
                .font(NullFeedTheme.bodySmall)
                .foregroundStyle(NullFeedTheme.textSecondary)
                .lineLimit(3)
                .padding(.horizontal, 12)

            // Actions
            HStack(spacing: 16) {
                Button(action: onSubscribe) {
                    Label("Subscribe", systemImage: "plus.circle.fill")
                        .font(NullFeedTheme.caption)
                }
                .tint(NullFeedTheme.primary)

                Button(action: onDismiss) {
                    Label("Dismiss", systemImage: "xmark.circle")
                        .font(NullFeedTheme.caption)
                }
                .tint(NullFeedTheme.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(NullFeedTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
    }
}
