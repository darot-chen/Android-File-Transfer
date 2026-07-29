import Foundation

struct RecentFolder: Identifiable, Sendable, Equatable, Codable {
    let id: UUID
    let serial: String
    let path: String
    let name: String
    let visitedAt: Date
}
