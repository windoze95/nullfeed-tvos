import Foundation

/// A sponsor/ad segment (in seconds) the player seeks past during playback.
struct AdSegment: Decodable, Equatable, Sendable {
    let start: Double
    let end: Double
}

/// Response of `GET /api/videos/{id}/ad-segments`. `segments` is empty while
/// detection is pending or when no ads were found.
struct AdSegmentsResponse: Decodable, Sendable {
    let status: String
    let segments: [AdSegment]
}
