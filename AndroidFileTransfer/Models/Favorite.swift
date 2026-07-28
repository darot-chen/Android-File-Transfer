import Foundation

struct Favorite: Identifiable, Sendable, Equatable, Codable {
    let id: UUID
    let serial: String
    let path: String
    let name: String
}
