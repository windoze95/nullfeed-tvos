import SwiftUI

/// Shown when a load fails and there is nothing to display, so an unreachable
/// server reads as an error the user can retry instead of looking like an empty
/// library (issue #5).
struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 64))
                .foregroundStyle(NullFeedTheme.error)

            Text("Something Went Wrong")
                .font(NullFeedTheme.headlineSmall)
                .foregroundStyle(NullFeedTheme.textPrimary)

            Text(message)
                .font(NullFeedTheme.bodyMedium)
                .foregroundStyle(NullFeedTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 700)

            Button(action: retry) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(NullFeedTheme.titleSmall)
            }
            .tint(NullFeedTheme.primary)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(NullFeedTheme.contentPadding)
    }
}
