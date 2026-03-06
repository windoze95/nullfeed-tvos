import SwiftUI

struct FocusableCard<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            content()
                .background(
                    RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius)
                        .fill(NullFeedTheme.card)
                )
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .scaleEffect(isFocused ? NullFeedTheme.focusScale : 1.0)
        .overlay(
            RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius)
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
