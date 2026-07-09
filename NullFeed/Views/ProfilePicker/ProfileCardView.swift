import SwiftUI

struct ProfileCardView: View {
    let user: User
    let onSelect: () -> Void
    @Environment(APIClient.self) private var api

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 16) {
                if let avatarUrl = user.avatarUrl, !avatarUrl.isEmpty {
                    AsyncImageView(url: api.mediaURL(avatarUrl))
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    initialsView
                }

                Text(user.displayName)
                    .font(NullFeedTheme.titleMedium)
                    .foregroundStyle(NullFeedTheme.textPrimary)
                    .lineLimit(1)

                if user.hasPin {
                    Label("PIN", systemImage: "lock.fill")
                        .font(NullFeedTheme.caption)
                        .foregroundStyle(NullFeedTheme.textMuted)
                }
            }
            .padding(24)
            .background(NullFeedTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(CardButtonStyle())
    }

    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(NullFeedTheme.primary)
                .frame(width: 120, height: 120)

            Text(initials)
                .font(NullFeedTheme.headlineMedium)
                .foregroundStyle(NullFeedTheme.textPrimary)
        }
    }

    private var initials: String {
        let parts = user.displayName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}
