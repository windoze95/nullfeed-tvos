import SwiftUI
import UIKit

/// Keeps ultra-wide channel art crisp and correctly proportioned. A soft,
/// edge-to-edge copy supplies ambient color while the foreground image remains
/// aspect-fit instead of being stretched or aggressively cropped.
struct CinematicBannerView: View {
    let url: String?
    var showSharpArtwork = true
    var scrim = true

    @State private var image: UIImage?

    nonisolated static func highResolutionURL(_ value: String?) -> String? {
        guard let value, !value.isEmpty,
              let host = URL(string: value)?.host?.lowercased() else {
            return value
        }

        let youtubeImageHosts = ["ggpht.com", "googleusercontent.com"]
        guard youtubeImageHosts.contains(where: {
            host == $0 || host.hasSuffix(".\($0)")
        }) else {
            return value
        }

        return value
            .replacingOccurrences(
                of: #"=w\d+"#,
                with: "=w2560",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"=s\d+"#,
                with: "=s2560",
                options: .regularExpression
            )
    }

    private var imageURL: String? {
        Self.highResolutionURL(url)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    NullFeedTheme.cardHover,
                    NullFeedTheme.card,
                    NullFeedTheme.surface
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(1.12)
                    .blur(radius: 18)

                Color.black.opacity(0.28)

                if showSharpArtwork {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 12)
                }
            }

            if scrim {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.04),
                        Color.black.opacity(0.13),
                        Color.black.opacity(0.88)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .clipped()
        .task(id: imageURL) {
            image = nil
            guard let imageURL else { return }
            let loadedImage = await ImageLoader.shared.load(from: imageURL)
            guard !Task.isCancelled else { return }
            image = loadedImage
        }
    }
}
