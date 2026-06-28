import SwiftUI

/// Couch-friendly action sheet shown when a non-playable video row is selected
/// (issue #16). A blank player used to be pushed for CATALOGED / PENDING /
/// FAILED videos, stranding the user; this presents the download-lifecycle
/// actions available for the video's current status instead. The same actions
/// are also reachable via each row's `.contextMenu`.
struct VideoActionsSheet: View {
    let video: Video
    let thumbnailURL: String?
    let onDownload: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 50) {
            HStack(spacing: 30) {
                AsyncImageView(url: thumbnailURL, cornerRadius: 12)
                    .frame(width: 320, height: 180)
                    .clipped()

                VStack(alignment: .leading, spacing: 12) {
                    Text(video.title)
                        .font(NullFeedTheme.titleLarge)
                        .foregroundStyle(NullFeedTheme.textPrimary)
                        .lineLimit(3)

                    Text(statusDescription)
                        .font(NullFeedTheme.bodyMedium)
                        .foregroundStyle(NullFeedTheme.textSecondary)
                }

                Spacer()
            }

            VStack(spacing: 20) {
                if video.isDownloadable {
                    actionButton(
                        video.status == .failed ? "Retry Download" : "Download",
                        systemImage: "arrow.down.circle.fill"
                    ) { perform(onDownload) }
                }
                if video.isInProgress {
                    actionButton("Cancel Download", systemImage: "xmark.circle.fill", role: .destructive) {
                        perform(onCancel)
                    }
                }
                if video.status == .complete {
                    actionButton("Delete Download", systemImage: "trash.fill", role: .destructive) {
                        perform(onDelete)
                    }
                }

                actionButton("Close", systemImage: "chevron.down", prominent: false) { dismiss() }
            }
            .frame(maxWidth: 600)
        }
        .padding(80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NullFeedTheme.background.ignoresSafeArea())
    }

    private var statusDescription: String {
        switch video.status {
        case .cataloged: "Not downloaded yet."
        case .pending: "Queued for download."
        case .downloading: "Downloading now."
        case .failed: "The last download failed."
        case .complete: "Downloaded and ready to watch."
        }
    }

    /// Dismiss first so the row is visible as it updates, then run the action.
    private func perform(_ action: @escaping () -> Void) {
        dismiss()
        action()
    }

    @ViewBuilder
    private func actionButton(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        prominent: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .font(NullFeedTheme.titleMedium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(prominent ? (role == .destructive ? NullFeedTheme.error : NullFeedTheme.primary) : NullFeedTheme.card)
    }
}
