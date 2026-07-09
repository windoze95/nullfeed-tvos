import SwiftUI

enum NullFeedTheme {
    // MARK: - Colors
    static let background = Color(hex: 0x09090D)
    static let surface = Color(hex: 0x13131A)
    static let card = Color(hex: 0x1B1B24)
    static let cardHover = Color(hex: 0x292936)
    static let primary = Color(hex: 0x7C4DFF)
    static let accent = Color(hex: 0xB388FF)
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0xB3B3B3)
    // Matches the current iOS contrast pass; the old gray disappeared from a
    // normal couch distance against the dark card surface.
    static let textMuted = Color(hex: 0x858585)
    static let divider = Color(hex: 0x30303B)
    static let error = Color(hex: 0xCF6679)
    static let success = Color(hex: 0x4CAF50)
    static let progressBackground = Color(hex: 0x333333)
    static let progressForeground = Color(hex: 0x7C4DFF)

    // MARK: - Layout
    static let cardRadius: CGFloat = 16
    static let focusScale: CGFloat = 1.06
    static let focusBorderWidth: CGFloat = 3
    static let contentPadding: CGFloat = 60

    // MARK: - Typography (10-foot)
    static let headlineLarge = Font.system(size: 48, weight: .bold)
    static let headlineMedium = Font.system(size: 38, weight: .bold)
    static let headlineSmall = Font.system(size: 32, weight: .semibold)
    static let titleLarge = Font.system(size: 28, weight: .semibold)
    static let titleMedium = Font.system(size: 24, weight: .medium)
    static let titleSmall = Font.system(size: 21, weight: .medium)
    static let bodyLarge = Font.system(size: 24)
    static let bodyMedium = Font.system(size: 21)
    static let bodySmall = Font.system(size: 18)
    static let caption = Font.system(size: 16)
}

/// Ambient app chrome shared by browsing screens. The restrained brand glows
/// keep large TV areas from reading as a flat black sheet while preserving
/// contrast behind artwork and text.
struct NullFeedBackdrop: View {
    var body: some View {
        ZStack {
            NullFeedTheme.background

            RadialGradient(
                colors: [NullFeedTheme.primary.opacity(0.16), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 900
            )

            RadialGradient(
                colors: [NullFeedTheme.accent.opacity(0.07), .clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 720
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Consistent title treatment for the content area below tvOS's tab chrome.
struct ScreenHeaderView: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(NullFeedTheme.accent)
                .frame(width: 58, height: 58)
                .background(NullFeedTheme.primary.opacity(0.16), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(NullFeedTheme.headlineMedium)
                    .foregroundStyle(NullFeedTheme.textPrimary)
                Text(subtitle)
                    .font(NullFeedTheme.bodySmall)
                    .foregroundStyle(NullFeedTheme.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

enum NullFeedLayout {
    static let gridSpacing: CGFloat = 36

    static var videoGridColumns: [GridItem] {
        [GridItem(
            .adaptive(
                minimum: AppConstants.videoCardWidth,
                maximum: AppConstants.videoCardWidth
            ),
            spacing: gridSpacing
        )]
    }

    static var channelGridColumns: [GridItem] {
        [GridItem(
            .adaptive(
                minimum: AppConstants.channelCardWidth,
                maximum: AppConstants.channelCardWidth
            ),
            spacing: gridSpacing
        )]
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
