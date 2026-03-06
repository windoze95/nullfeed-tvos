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
        channelName = try c.decodeIfPresent(String.self, forKey: .channelName) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case id, youtubeVideoId, channelId, title, durationSeconds
        case uploadedAt, filePath, fileSizeBytes, status
        case watchPositionSeconds, isWatched, previewStatus, channelName
    }
}

extension Video {
    var isPlayable: Bool {
        status == .complete || previewStatus == "READY"
    }

    var hasPreviewReady: Bool {
        previewStatus == "READY"
    }

    var isPreviewOnly: Bool {
        previewStatus == "READY" && status != .complete
    }

    var isDownloadable: Bool {
        status == .cataloged || status == .failed
    }

    var isInProgress: Bool {
        status == .pending || status == .downloading
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
