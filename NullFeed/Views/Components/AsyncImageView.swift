import SwiftUI
import UIKit

struct AsyncImageView: View {
    let url: String?
    var cornerRadius: CGFloat = NullFeedTheme.cardRadius

    @State private var image: UIImage?
    @State private var didFail = false

    private var imageURL: URL? {
        guard let url, !url.isEmpty else { return nil }
        return URL(string: url)
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
            } else if didFail {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(NullFeedTheme.surface)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(NullFeedTheme.textMuted)
                    )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(NullFeedTheme.surface)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: url) {
            image = nil
            didFail = false
            guard let imageURL else { return }

            let loaded = await ImageLoader.shared.load(from: imageURL.absoluteString)
            guard !Task.isCancelled else { return }
            image = loaded
            didFail = loaded == nil
        }
    }
}
