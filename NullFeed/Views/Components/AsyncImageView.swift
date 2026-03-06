import SwiftUI

struct AsyncImageView: View {
    let url: String?
    var cornerRadius: CGFloat = NullFeedTheme.cardRadius

    private var imageURL: URL? {
        guard let url, !url.isEmpty else { return nil }
        return URL(string: url)
    }

    var body: some View {
        AsyncImage(url: imageURL) { phase in
            switch phase {
            case .empty:
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(NullFeedTheme.surface)

            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .transition(.opacity.animation(.easeIn(duration: 0.3)))

            case .failure:
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(NullFeedTheme.surface)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(NullFeedTheme.textMuted)
                    )

            @unknown default:
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(NullFeedTheme.surface)
            }
        }
    }
}
