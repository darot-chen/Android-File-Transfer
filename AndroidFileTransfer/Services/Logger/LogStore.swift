import Foundation
import Observation

@MainActor
@Observable
final class LogStore {
    private(set) var entries: [LogEntry] = []
    private let maxEntries: Int

    init(maxEntries: Int = 500) {
        self.maxEntries = maxEntries
    }

    func log(_ level: LogLevel, category: String, _ message: String) {
        entries.append(LogEntry(id: UUID(), timestamp: Date(), level: level, category: category, message: message))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }

        switch level {
        case .debug: AppLog.adb.debug("[\(category, privacy: .public)] \(message, privacy: .public)")
        case .info: AppLog.adb.info("[\(category, privacy: .public)] \(message, privacy: .public)")
        case .warning: AppLog.adb.warning("[\(category, privacy: .public)] \(message, privacy: .public)")
        case .error: AppLog.adb.error("[\(category, privacy: .public)] \(message, privacy: .public)")
        }
    }

    func clear() {
        entries.removeAll()
    }

    func exportText() -> String {
        let formatter = ISO8601DateFormatter()
        return entries
            .map { "\(formatter.string(from: $0.timestamp)) [\($0.level.rawValue.uppercased())] \($0.category): \($0.message)" }
            .joined(separator: "\n")
    }
}
