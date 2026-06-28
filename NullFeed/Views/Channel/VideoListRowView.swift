import SwiftUI

struct VideoListRowView: View {
    let video: Video
    /// Live download progress (0...1) while the video is downloading; nil when
    /// there's no active download to show.
    var downloadProgress: Double?

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
                    statusBadge

                    if video.isWatched {
                        Label("Watched", systemImage: "checkmark.circle.fill")
                            .font(NullFeedTheme.caption)
                            .foregroundStyle(NullFeedTheme.success)
                    }
                }

                if video.status == .downloading {
                    ProgressBarView(progress: downloadProgress ?? 0, height: 4)
                        .frame(maxWidth: 200)
                } else if video.watchProgress > 0 && !video.isWatched {
                    ProgressBarView(progress: video.watchProgress, height: 4)
                        .frame(maxWidth: 200)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(NullFeedTheme.card, in: RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch video.status {
        case .complete:
            Label("Stream", systemImage: "play.circle")
                .font(NullFeedTheme.caption)
                .foregroundStyle(NullFeedTheme.accent)
        case .downloading:
            Label(downloadingLabel, systemImage: "arrow.down.circle")
                .font(NullFeedTheme.caption)
                .foregroundStyle(NullFeedTheme.accent)
        case .pending:
            Label("Pending", systemImage: "clock")
                .font(NullFeedTheme.caption)
                .foregroundStyle(NullFeedTheme.textMuted)
        case .failed:
            Label("Failed", systemImage: "exclamationmark.triangle")
                .font(NullFeedTheme.caption)
                .foregroundStyle(NullFeedTheme.error)
        case .cataloged:
            Label("Not Downloaded", systemImage: "icloud.and.arrow.down")
                .font(NullFeedTheme.caption)
                .foregroundStyle(NullFeedTheme.textMuted)
        }
    }

    private var downloadingLabel: String {
        if let downloadProgress {
            return "Downloading \(Int(downloadProgress * 100))%"
        }
        return "Downloading"
    }
}
