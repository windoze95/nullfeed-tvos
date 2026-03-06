@preconcurrency import TVServices
import Foundation

class ContentProvider: TVTopShelfContentProvider {
    private let appGroup = "group.codes.julian.nullfeed"

    override func loadTopShelfContent() async -> TVTopShelfContent? {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let serverUrl = defaults.string(forKey: "server_url"),
              let token = defaults.string(forKey: "session_token") else {
            return nil
        }

        guard let items = await fetchContinueWatching(serverUrl: serverUrl, token: token),
              !items.isEmpty else {
            return nil
        }

        let section = TVTopShelfItemCollection(items: items)
        section.title = "Continue Watching"

        let content = TVTopShelfSectionedContent(sections: [section])
        return content
    }

    private func fetchContinueWatching(serverUrl: String, token: String) async -> [TVTopShelfSectionedItem]? {
        guard let url = URL(string: "\(serverUrl)/api/feed/continue-watching") else { return nil }

        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "X-User-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let feedItems = try decoder.decode([TopShelfFeedItem].self, from: data)

            return feedItems.compactMap { item -> TVTopShelfSectionedItem? in
                let topShelfItem = TVTopShelfSectionedItem(identifier: item.video.id)
                topShelfItem.title = item.video.title

                if let playURL = URL(string: "nullfeed://player/\(item.video.id)") {
                    topShelfItem.playAction = TVTopShelfAction(url: playURL)
                    topShelfItem.displayAction = TVTopShelfAction(url: playURL)
                }

                return topShelfItem
            }
        } catch {
            return nil
        }
    }
}

// Minimal decodable types for the extension (can't share code with main app easily)
private struct TopShelfFeedItem: Decodable {
    let video: TopShelfVideo
}

private struct TopShelfVideo: Decodable {
    let id: String
    let title: String
}
