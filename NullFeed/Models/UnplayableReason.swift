import Foundation

/// Why YouTube refuses a video, as classified by the backend from yt-dlp
/// failures and playlist availability badges (`videos.unplayable_reason` on the
/// wire; absent means playable as far as the server knows). `unknown` absorbs
/// vocabulary the backend adds before this client learns it, so future reasons
/// still banner — just generically.
enum UnplayableReason: String, Sendable {
    case ageRestricted = "age_restricted"
    case membersOnly = "members_only"
    case premium
    case privateVideo = "private"
    case geoBlocked = "geo_blocked"
    case removed
    case drm
    case upcoming
    case unavailable
    case unknown

    /// Total mapping from the wire value — never fails; new values → `unknown`.
    init(wireValue: String) {
        self = UnplayableReason(rawValue: wireValue) ?? .unknown
    }

    /// Short banner text for cards and rows.
    var label: String {
        switch self {
        case .ageRestricted: "Age-restricted"
        case .membersOnly: "Members only"
        case .premium: "Premium"
        case .privateVideo: "Private"
        case .geoBlocked: "Geo-blocked"
        case .removed: "Removed"
        case .drm: "DRM-protected"
        case .upcoming: "Upcoming"
        case .unavailable, .unknown: "Unavailable"
        }
    }

    /// One-sentence explanation for the player's blocked screen.
    var message: String {
        switch self {
        case .ageRestricted:
            "YouTube age-restricts this video. It can play once the server has "
                + "working YouTube cookies from an age-verified account."
        case .membersOnly:
            "This video is exclusive to channel members on YouTube, so the "
                + "server can't fetch it."
        case .premium:
            "YouTube requires payment or a Premium subscription for this video."
        case .privateVideo:
            "The uploader made this video private."
        case .geoBlocked:
            "This video isn't available in the server's country."
        case .removed:
            "This video was removed from YouTube or its account was terminated."
        case .drm:
            "This video is DRM-protected and can't be fetched."
        case .upcoming:
            "This video hasn't premiered yet. It becomes playable once it airs."
        case .unavailable, .unknown:
            "YouTube reports this video as unavailable."
        }
    }

    var symbolName: String {
        switch self {
        case .ageRestricted: "exclamationmark.shield"
        case .membersOnly: "star.circle"
        case .premium: "crown"
        case .privateVideo: "lock"
        case .geoBlocked: "mappin.slash"
        case .removed: "xmark.circle"
        case .drm: "lock.shield"
        case .upcoming: "clock"
        case .unavailable, .unknown: "video.slash"
        }
    }
}
