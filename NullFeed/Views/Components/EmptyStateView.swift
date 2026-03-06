import SwiftUI

struct EmptyStateView: View {
    let iconName: String
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: iconName)
                .font(.system(size: 64))
                .foregroundStyle(NullFeedTheme.textMuted)

            Text(title)
                .font(NullFeedTheme.headlineSmall)
                .foregroundStyle(NullFeedTheme.textSecondary)

            if let subtitle {
                Text(subtitle)
                    .font(NullFeedTheme.bodyMedium)
                    .foregroundStyle(NullFeedTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
