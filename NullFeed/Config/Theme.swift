import SwiftUI

enum NullFeedTheme {
    // MARK: - Colors
    static let background = Color(hex: 0x0A0A0A)
    static let surface = Color(hex: 0x121212)
    static let card = Color(hex: 0x1E1E1E)
    static let cardHover = Color(hex: 0x2A2A2A)
    static let primary = Color(hex: 0x7C4DFF)
    static let accent = Color(hex: 0xB388FF)
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0xB3B3B3)
    static let textMuted = Color(hex: 0x666666)
    static let divider = Color(hex: 0x2A2A2A)
    static let error = Color(hex: 0xCF6679)
    static let success = Color(hex: 0x4CAF50)
    static let progressBackground = Color(hex: 0x333333)
    static let progressForeground = Color(hex: 0x7C4DFF)

    // MARK: - Layout
    static let cardRadius: CGFloat = 12
    static let focusScale: CGFloat = 1.05
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
