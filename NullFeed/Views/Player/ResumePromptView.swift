import SwiftUI

/// Pre-playback choice shown when a video has a saved watch position to return
/// to -- typically because it was partly watched on another device. Offers a
/// focusable "Resume at <time>" or "Start Over" so playback never silently jumps
/// into the middle. Videos with no saved position (or already finished) skip
/// this and play from the top.
struct ResumePromptView: View {
    let title: String
    let positionSeconds: Int
    let onResume: () -> Void
    let onStartOver: () -> Void

    @Namespace private var promptFocus

    var body: some View {
        VStack(spacing: 50) {
            VStack(spacing: 12) {
                Text("Resume Watching?")
                    .font(NullFeedTheme.headlineMedium)
                    .foregroundStyle(NullFeedTheme.textPrimary)

                Text(title)
                    .font(NullFeedTheme.titleMedium)
                    .foregroundStyle(NullFeedTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 900)
            }

            HStack(spacing: 30) {
                // Resume takes default focus so a single click picks up where the
                // viewer left off.
                promptButton("Resume at \(positionSeconds.formattedDuration)", systemImage: "play.fill", action: onResume)
                    .prefersDefaultFocus(true, in: promptFocus)

                promptButton("Start Over", systemImage: "gobackward", prominent: false, action: onStartOver)
            }
            .focusScope(promptFocus)
        }
        .padding(80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func promptButton(
        _ title: String,
        systemImage: String,
        prominent: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(NullFeedTheme.titleMedium)
                .padding(.vertical, 8)
                .padding(.horizontal, 24)
        }
        .buttonStyle(.borderedProminent)
        .tint(prominent ? NullFeedTheme.primary : NullFeedTheme.card)
    }
}
