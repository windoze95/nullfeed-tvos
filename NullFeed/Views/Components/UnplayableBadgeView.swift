import SwiftUI

extension UnplayableReason {
    /// Per-reason accent; the badge keeps the shared black background so it
    /// reads like the other thumbnail badges, with the icon color-coding it.
    var accentColor: Color {
        switch self {
        case .ageRestricted: NullFeedTheme.error
        case .membersOnly: Color(hex: 0xFFB74D)
        case .premium: NullFeedTheme.primary
        case .geoBlocked: Color(hex: 0x64B5F6)
        case .upcoming: Color(hex: 0x4DB6AC)
        case .privateVideo, .removed, .drm, .unavailable, .unknown:
            NullFeedTheme.textMuted
        }
    }
}

/// Thumbnail banner explaining why a video can't be played (age-restricted,
/// members-only, …). Sits in a card/row thumbnail ZStack, styled after the
/// duration badge.
struct UnplayableBadgeView: View {
    let reason: UnplayableReason

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: reason.symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(reason.accentColor)
            Text(reason.label)
                .font(NullFeedTheme.caption)
                .foregroundStyle(NullFeedTheme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
