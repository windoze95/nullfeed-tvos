import SwiftUI

struct VideoListRowView: View {
    let video: Video

    @Environment(APIClient.self) private var api

    var body: some View {
        HStack(spacing: 24) {
            // Thumbnail
            ZStack(alignment: .bottomTrailing) {
                AsyncImageView(
                    url: api.mediaURL(video.thumbnailUrl),
                    cornerRadius: 12
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

                HStack(spacing: 12) {
                    if let uploadedAt = video.uploadedAt {
                        Text(uploadedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(NullFeedTheme.bodySmall)
                            .foregroundStyle(NullFeedTheme.textMuted)
                    }

                    if video.durationSeconds > 0 {
                        Text(video.formattedDuration)
                            .font(NullFeedTheme.bodySmall)
                            .foregroundStyle(NullFeedTheme.textMuted)
                    }
                }

                HStack(spacing: 12) {
                    // Every episode plays on selection (cached, or started via
                    // instant-stream) — caching is invisible, so the row shows a
                    // uniform Play affordance rather than a download status. A
                    // video YouTube refuses swaps it for the reason instead.
                    if let reason = video.activeUnplayableReason {
                        Label(reason.label, systemImage: reason.symbolName)
                            .font(NullFeedTheme.caption)
                            .foregroundStyle(reason.accentColor)
                    } else if let type = video.badgeContentType {
                        Label(type.label, systemImage: type.symbolName)
                            .font(NullFeedTheme.caption)
                            .foregroundStyle(type.accentColor)
                    } else {
                        Label("Play", systemImage: "play.circle")
                            .font(NullFeedTheme.caption)
                            .foregroundStyle(NullFeedTheme.accent)
                    }

                    if video.isWatched {
                        Label("Watched", systemImage: "checkmark.circle.fill")
                            .font(NullFeedTheme.caption)
                            .foregroundStyle(NullFeedTheme.success)
                    }
                }

                if video.watchProgress > 0 && !video.isWatched {
                    ProgressBarView(progress: video.watchProgress, height: 4)
                        .frame(maxWidth: 360)
                }
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(NullFeedTheme.accent)
                .padding(.trailing, 8)
        }
        .padding(18)
        .background(NullFeedTheme.card, in: RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        }
    }
}
