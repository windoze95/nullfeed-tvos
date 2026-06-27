import Foundation

struct User: Codable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let avatarUrl: String?
    let isAdmin: Bool
    let hasPin: Bool
    let createdAt: Date

    init(
        id: String,
        displayName: String,
        avatarUrl: String? = nil,
        isAdmin: Bool = false,
        hasPin: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.isAdmin = isAdmin
        self.hasPin = hasPin
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        displayName = try c.decode(String.self, forKey: .displayName)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        isAdmin = try c.decodeIfPresent(Bool.self, forKey: .isAdmin) ?? false
        hasPin = try c.decodeIfPresent(Bool.self, forKey: .hasPin) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
    }

    private enum CodingKeys: String, CodingKey {
        case id, displayName, avatarUrl, isAdmin, hasPin, createdAt
    }
}
