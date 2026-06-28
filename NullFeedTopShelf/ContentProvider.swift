@preconcurrency import TVServices
import Foundation

/// Builds the tvOS Top Shelf "Continue Watching" row from the signed-in user's
/// feed. Credentials come from the App Group suite the app mirrors into
/// (`SharedDefaults`, shared with both targets). With no stored session, or on
/// any network/decoding failure, the shelf is simply empty -- never a crash.
/// Each tile deep-links to `nullfeed://player/<id>`, which the app resolves via
/// `onOpenURL` to resume playback.
class ContentProvider: TVTopShelfContentProvider {
    override func loadTopShelfContent() async -> TVTopShelfContent? {
        guard let serverUrl = SharedDefaults.serverUrl,
              let token = SharedDefaults.sessionToken,
              !serverUrl.isEmpty, !token.isEmpty else {
            return nil
        }

        let items = await fetchContinueWatching(serverUrl: serverUrl, token: token)
        guard !items.isEmpty else { return nil }

        let section = TVTopShelfItemCollection(items: items)
        section.title = "Continue Watching"
        return TVTopShelfSectionedContent(sections: [section])
    }

    /// Fetch the Continue Watching feed and map it to Top Shelf tiles. Mirrors
    /// the app's `APIClient`: GET `/api/feed/continue-watching` with the session
    /// token in `X-User-Token` and snake_case JSON. Returns `[]` on any failure
    /// so the caller renders an empty shelf rather than a broken one.
    private func fetchContinueWatching(serverUrl: String, token: String) async -> [TVTopShelfSectionedItem] {
        guard let url = URL(string: "\(serverUrl)/api/feed/continue-watching") else { return [] }

        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "X-User-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let feed = try decoder.decode([FeedEntry].self, from: data)

            return feed.map { tile(for: $0.video, serverUrl: serverUrl) }
        } catch {
            return []
        }
    }

    /// One Top Shelf tile: a 16:9 thumbnail, the resume progress bar, and a
    /// play/display action that deep-links into the app's player.
    private func tile(for video: FeedVideo, serverUrl: String) -> TVTopShelfSectionedItem {
        let item = TVTopShelfSectionedItem(identifier: video.id)
        item.title = video.title
        item.imageShape = .hdtv

        if let imageURL = Self.mediaURL(video.thumbnailUrl, serverUrl: serverUrl) {
            item.setImageURL(imageURL, for: [.screenScale1x, .screenScale2x])
        }

        if let duration = video.durationSeconds, duration > 0,
           let position = video.watchPositionSeconds {
            item.playbackProgress = min(1, max(0, Double(position) / Double(duration)))
        }

        if let playURL = URL(string: "nullfeed://player/\(video.id)") {
            item.playAction = TVTopShelfAction(url: playURL)
            item.displayAction = TVTopShelfAction(url: playURL)
        }

        return item
    }

    /// Resolve a possibly-relative thumbnail path (e.g. "/data/thumbnails/x.jpg")
    /// against the server base, mirroring `APIClient.mediaURL`. Absolute URLs pass
    /// through unchanged; nil/empty yields nil.
    private static func mediaURL(_ path: String?, serverUrl: String) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http://") || path.hasPrefix("https://") { return URL(string: path) }
        return URL(string: "\(serverUrl)\(path)")
    }
}

// MARK: - Minimal feed shapes
//
// The extension can't import the app target, so it re-declares just the slice of
// the `/api/feed/continue-watching` response it needs (`[{video: {...}}]`). See
// the app's `FeedItem` / `Video` for the full shapes.

private struct FeedEntry: Decodable {
    let video: FeedVideo
}

private struct FeedVideo: Decodable {
    let id: String
    let title: String
    let thumbnailUrl: String?
    let durationSeconds: Int?
    let watchPositionSeconds: Int?
}
