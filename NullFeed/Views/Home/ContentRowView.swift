import SwiftUI

struct ContentRowView<Content: View>: View {
    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(NullFeedTheme.headlineSmall)
                .foregroundStyle(NullFeedTheme.textPrimary)
                .padding(.horizontal, NullFeedTheme.contentPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 30) {
                    content()
                }
                .padding(.horizontal, NullFeedTheme.contentPadding)
                .padding(.vertical, 22)
            }
            .scrollClipDisabled()
        }
        .focusSection()
    }
}
