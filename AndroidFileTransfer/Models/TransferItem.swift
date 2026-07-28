import Foundation

struct TransferItem: Identifiable, Sendable, Equatable, Codable {
    enum Direction: String, Sendable, Codable {
        case upload
        case download
    }

    enum Status: Sendable, Equatable, Codable {
        case queued
        case inProgress(percent: Int)
        case completed
        case failed(message: String)
        case cancelled
    }

    let id: UUID
    let direction: Direction
    let serial: String
    let localURL: URL
    let remotePath: String
    var status: Status
    let createdAt: Date

    var displayName: String {
        direction == .upload ? localURL.lastPathComponent : (remotePath as NSString).lastPathComponent
    }
}
