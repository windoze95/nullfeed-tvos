import SwiftUI

struct VideoListRowView: View {
    let video: Video

    @Environment(APIClient.self) private var api

    var body: some View {
        HStack(spacing: 20) {
            // Thumbnail
            ZStack(alignment: .bottomTrailing) {
                AsyncImageView(
                    url: api.mediaURL(video.thumbnailUrl),
                    cornerRadius: 8
                )
                .frame(width: 240, height: 135)
                .clipped()

                if video.durationSeconds > 0 {
                    Text(video.durationSeconds.formattedDuration)
                        .font(NullFeedTheme.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                }
            }
            .frame(width: 240, height: 135)

            // Info
            VStack(alignment: .leading, spacing: 8) {
                Text(video.title)
                    .font(NullFeedTheme.titleMedium)
                    .foregroundStyle(NullFeedTheme.textPrimary)
                    .lineLimit(2)

                if !video.channelName.isEmpty {
                    Text(video.channelName)
                        .font(NullFeedTheme.bodySmall)
                        .foregroundStyle(NullFeedTheme.textSecondary)
                }

                HStack(spacing: 12) {
                    // Every episode plays on selection (cached, or started via
                    // instant-stream) — caching is invisible, so the row shows a
                    // uniform Play affordance rather than a download status.
                    Label("Play", systemImage: "play.circle")
                        .font(NullFeedTheme.caption)
                        .foregroundStyle(NullFeedTheme.accent)

                    if video.isWatched {
                        Label("Watched", systemImage: "checkmark.circle.fill")
                            .font(NullFeedTheme.caption)
                            .foregroundStyle(NullFeedTheme.success)
                    }
                }

                if video.watchProgress > 0 && !video.isWatched {
                    ProgressBarView(progress: video.watchProgress, height: 4)
                        .frame(maxWidth: 200)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(NullFeedTheme.card, in: RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
    }
}
