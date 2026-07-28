import Foundation

struct ADBProcessResult: Sendable, Equatable {
    let exitCode: Int32
    let standardOutput: String
    let standardError: String
}

enum ADBProcessError: Error, Sendable, Equatable {
    case binaryNotFound
    case launchFailed(String)
}

protocol ADBProcessRunning: Sendable {
    func run(arguments: [String]) async throws -> ADBProcessResult
}
