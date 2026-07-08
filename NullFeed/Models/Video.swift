import Foundation

enum VideoStatus: String, Codable, Sendable {
    case cataloged = "CATALOGED"
    case pending = "PENDING"
    case downloading = "DOWNLOADING"
    case complete = "COMPLETE"
    case failed = "FAILED"
}

struct Video: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let youtubeVideoId: String
    let channelId: String
    let title: String
    var durationSeconds: Int
    let uploadedAt: Date?
    let filePath: String?
    let fileSizeBytes: Int?
    var status: VideoStatus
    var watchPositionSeconds: Int
    var isWatched: Bool
    let previewStatus: String?
    /// Why YouTube refuses this video (raw wire value, see UnplayableReason);
    /// nil = playable as far as the server knows.
    let unplayableReason: String?
    /// What kind of media this is (raw wire value, see ContentType); nil = regular.
    let contentType: String?
    let thumbnailUrl: String?
    let description: String?
    var channelName: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        youtubeVideoId = try c.decode(String.self, forKey: .youtubeVideoId)
        channelId = try c.decode(String.self, forKey: .channelId)
        title = try c.decode(String.self, forKey: .title)
        durationSeconds = try c.decodeIfPresent(Int.self, forKey: .durationSeconds) ?? 0
        uploadedAt = try c.decodeIfPresent(Date.self, forKey: .uploadedAt)
        filePath = try c.decodeIfPresent(String.self, forKey: .filePath)
        fileSizeBytes = try c.decodeIfPresent(Int.self, forKey: .fileSizeBytes)
        status = try c.decodeIfPresent(VideoStatus.self, forKey: .status) ?? .cataloged
        watchPositionSeconds = try c.decodeIfPresent(Int.self, forKey: .watchPositionSeconds) ?? 0
        isWatched = try c.decodeIfPresent(Bool.self, forKey: .isWatched) ?? false
        previewStatus = try c.decodeIfPresent(String.self, forKey: .previewStatus)
        unplayableReason = try c.decodeIfPresent(String.self, forKey: .unplayableReason)
        contentType = try c.decodeIfPresent(String.self, forKey: .contentType)
        thumbnailUrl = try c.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        channelName = try c.decodeIfPresent(String.self, forKey: .channelName) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case id, youtubeVideoId, channelId, title, durationSeconds
        case uploadedAt, filePath, fileSizeBytes, status
        case watchPositionSeconds, isWatched, previewStatus, unplayableReason
        case contentType, thumbnailUrl, description, channelName
    }
}

extension Video {
    var isPlayable: Bool {
        status == .complete || previewStatus == "READY"
    }

    /// The unplayable reason worth showing. A video the server already holds a
    /// playable file for (HQ or preview) plays regardless of a stale label, so
    /// no banner.
    var activeUnplayableReason: UnplayableReason? {
        guard !isPlayable, let raw = unplayableReason else { return nil }
        return UnplayableReason(wireValue: raw)
    }

    /// The content type worth badging, or nil. Regular/unknown aren't badged,
    /// and the unplayable banner already covers members/premium/age when it's
    /// showing — so the two never stack.
    var badgeContentType: ContentType? {
        if activeUnplayableReason != nil { return nil }
        guard let raw = contentType else { return nil }
        let type = ContentType(wireValue: raw)
        return (type == .regular || type == .unknown) ? nil : type
    }

    var hasPreviewReady: Bool {
        previewStatus == "READY"
    }

    var isPreviewOnly: Bool {
        previewStatus == "READY" && status != .complete
    }

    var watchProgress: Double {
        guard durationSeconds > 0 else { return 0 }
        return Double(watchPositionSeconds) / Double(durationSeconds)
    }

    var formattedDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        let seconds = durationSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
