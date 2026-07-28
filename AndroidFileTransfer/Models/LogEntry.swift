import Foundation

enum LogLevel: String, Sendable, Codable, CaseIterable, Identifiable {
    case debug
    case info
    case warning
    case error

    var id: String { rawValue }
}

struct LogEntry: Identifiable, Sendable, Equatable, Codable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
}
