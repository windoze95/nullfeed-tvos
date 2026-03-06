import Foundation

struct User: Codable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let avatarUrl: String?
    let isAdmin: Bool
    let createdAt: Date

    init(id: String, displayName: String, avatarUrl: String? = nil, isAdmin: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.isAdmin = isAdmin
        self.createdAt = createdAt
    }
}
