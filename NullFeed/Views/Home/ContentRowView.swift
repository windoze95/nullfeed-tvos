import SwiftUI

struct ContentRowView<Content: View>: View {
    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(NullFeedTheme.headlineSmall)
                .foregroundStyle(NullFeedTheme.textPrimary)
                .padding(.horizontal, NullFeedTheme.contentPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    content()
                }
                .padding(.horizontal, NullFeedTheme.contentPadding)
            }
        }
    }
}
