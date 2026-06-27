import SwiftUI

/// The one shared 10-foot focus treatment for selectable cards: scales the card
/// up, draws a purple border, and lifts it with a shadow so the focused card is
/// unmistakable from across the room (issue #4).
///
/// Use `cardFocusStyle(isFocused:)` when you already have a focus signal (e.g. a
/// card with several inner buttons), or `CardButtonStyle` to drop the treatment
/// onto any `Button` / `NavigationLink` that is itself the focusable element.
extension View {
    func cardFocusStyle(isFocused: Bool, cornerRadius: CGFloat = NullFeedTheme.cardRadius) -> some View {
        self
            .scaleEffect(isFocused ? NullFeedTheme.focusScale : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        NullFeedTheme.primary,
                        lineWidth: isFocused ? NullFeedTheme.focusBorderWidth : 0
                    )
            )
            .shadow(
                color: isFocused ? NullFeedTheme.primary.opacity(0.5) : .clear,
                radius: 15
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

/// Applies `cardFocusStyle` to any button-like view. Both `Button` and
/// `NavigationLink` honour button styles, and `\.isFocused` inside a button
/// style reliably reflects remote focus, so this works everywhere a card is
/// selectable.
struct CardButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = NullFeedTheme.cardRadius

    func makeBody(configuration: Configuration) -> some View {
        FocusableCard(configuration: configuration, cornerRadius: cornerRadius)
    }

    private struct FocusableCard: View {
        let configuration: Configuration
        let cornerRadius: CGFloat
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            configuration.label
                .cardFocusStyle(isFocused: isFocused, cornerRadius: cornerRadius)
        }
    }
}
