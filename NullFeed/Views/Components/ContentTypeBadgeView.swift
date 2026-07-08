import SwiftUI

extension ContentType {
    /// Per-type accent; the badge keeps the shared black background so it reads
    /// like the other thumbnail badges, with the icon color-coding it. Reuses the
    /// unplayable-badge colors where the types overlap.
    var accentColor: Color {
        switch self {
        case .short: NullFeedTheme.primary
        case .live: NullFeedTheme.error
        case .premiere: Color(hex: 0x4DB6AC)
        case .ageRestricted: NullFeedTheme.error
        case .membersOnly: Color(hex: 0xFFB74D)
        case .premium: NullFeedTheme.primary
        case .regular, .unknown: NullFeedTheme.textMuted
        }
    }
}

/// Thumbnail pill marking a video's content type (Short, Live, Premiere, …).
/// Sits in a card thumbnail ZStack, styled after the duration badge. Never shows
/// alongside `UnplayableBadgeView` — see `Video.badgeContentType`.
struct ContentTypeBadgeView: View {
    let type: ContentType

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: type.symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(type.accentColor)
            Text(type.label)
                .font(NullFeedTheme.caption)
                .foregroundStyle(NullFeedTheme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
