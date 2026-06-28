import Foundation

/// One page of video search results from `GET /api/videos?q=...`. `nextCursor`
/// is the opaque cursor to pass back as `?cursor=` for the following page; a nil
/// value means this was the last page.
struct VideoSearchPage: Decodable, Sendable {
    let items: [Video]
    let total: Int
    let nextCursor: String?

    private enum CodingKeys: String, CodingKey {
        case items, total, nextCursor
    }

    // Decode defensively: a missing list or total is a valid empty page rather
    // than a decode error, matching how the feed models tolerate omitted keys.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decodeIfPresent([Video].self, forKey: .items) ?? []
        total = try c.decodeIfPresent(Int.self, forKey: .total) ?? 0
        nextCursor = try c.decodeIfPresent(String.self, forKey: .nextCursor)
    }
}
