import Foundation

/// What kind of media a video is, classified by the backend at catalog time
/// (`videos.content_type` on the wire; absent means a plain upload). A stable
/// label — unlike `UnplayableReason`, it doesn't clear once playable. `unknown`
/// absorbs vocabulary the backend adds before this client learns it.
enum ContentType: String, Sendable, Hashable {
    case regular
    case short
    case live
    case premiere
    case ageRestricted = "age_restricted"
    case membersOnly = "members_only"
    case premium
    case unknown

    /// Total mapping from the wire value — never fails; new values → `unknown`.
    init(wireValue: String) {
        self = ContentType(rawValue: wireValue) ?? .unknown
    }

    /// Short thumbnail-badge text (singular). Empty for types that aren't badged.
    var label: String {
        switch self {
        case .short: "Short"
        case .live: "Live"
        case .premiere: "Premiere"
        case .ageRestricted: "Age-restricted"
        case .membersOnly: "Members only"
        case .premium: "Premium"
        case .regular, .unknown: ""
        }
    }

    /// Filter-menu label (plural where natural).
    var menuLabel: String {
        switch self {
        case .regular: "Videos"
        case .short: "Shorts"
        case .live: "Live"
        case .premiere: "Premieres"
        case .ageRestricted: "Age-restricted"
        case .membersOnly: "Members only"
        case .premium: "Premium"
        case .unknown: "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .short: "play.rectangle.on.rectangle"
        case .live: "dot.radiowaves.left.and.right"
        case .premiere: "clock"
        case .ageRestricted: "exclamationmark.shield"
        case .membersOnly: "star.circle"
        case .premium: "crown"
        case .regular, .unknown: "video"
        }
    }
}
