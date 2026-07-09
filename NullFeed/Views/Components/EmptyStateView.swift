import SwiftUI

struct EmptyStateView: View {
    let iconName: String
    let title: String
    let subtitle: String?
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        iconName: String,
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.iconName = iconName
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

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
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 720)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "plus.circle.fill")
                        .font(NullFeedTheme.titleSmall)
                }
                .buttonStyle(.borderedProminent)
                .tint(NullFeedTheme.primary)
                .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
