import SwiftUI

struct RecommendationCardView: View {
    let recommendation: Recommendation
    let onSubscribe: () -> Void
    let onDismiss: () -> Void

    @Environment(APIClient.self) private var api

    private enum Action: Hashable { case subscribe, dismiss }
    @FocusState private var focusedAction: Action?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Banner / Avatar
            ZStack(alignment: .bottomLeading) {
                CinematicBannerView(
                    url: api.mediaURL(recommendation.bannerUrl),
                    showSharpArtwork: false
                )
                .overlay {
                    if recommendation.bannerUrl?.isEmpty != false {
                        AsyncImageView(url: api.mediaURL(recommendation.avatarUrl), cornerRadius: 44)
                            .frame(width: 88, height: 88)
                            .overlay {
                                if recommendation.avatarUrl?.isEmpty != false {
                                    Text(recommendation.channelName.prefix(1).uppercased())
                                        .font(NullFeedTheme.headlineSmall)
                                        .foregroundStyle(NullFeedTheme.accent)
                                }
                            }
                    }
                }
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
            Text(reasonText)
                .font(NullFeedTheme.bodySmall)
                .foregroundStyle(NullFeedTheme.textSecondary)
                .lineLimit(3)
                .padding(.horizontal, 14)

            Spacer(minLength: 0)

            // Actions
            HStack(spacing: 16) {
                Button(action: onSubscribe) {
                    Label("Subscribe", systemImage: "plus.circle.fill")
                        .font(NullFeedTheme.caption)
                }
                .tint(NullFeedTheme.primary)
                .disabled(recommendation.youtubeChannelId == nil)
                .focused($focusedAction, equals: .subscribe)

                Button(action: onDismiss) {
                    Label("Dismiss", systemImage: "xmark.circle")
                        .font(NullFeedTheme.caption)
                }
                .tint(NullFeedTheme.textMuted)
                .focused($focusedAction, equals: .dismiss)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .frame(width: AppConstants.channelCardWidth, height: 340, alignment: .top)
        .background(NullFeedTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        // Lift the whole card when either action is focused, so it's clear which
        // recommendation the remote is on from across the room (issue #4).
        .cardFocusStyle(isFocused: focusedAction != nil)
    }

    private var reasonText: String {
        guard let reason = recommendation.reason, !reason.isEmpty else {
            return "Recommended from the channels you watch."
        }
        return reason
    }
}
