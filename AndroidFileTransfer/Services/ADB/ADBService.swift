import Foundation

protocol ADBServiceProtocol: Sendable {
    func version() async throws -> String
    func startServer() async throws
}

enum ADBServiceError: Error, Sendable, Equatable {
    case commandFailed(arguments: [String], exitCode: Int32, standardError: String)
    case unparsableVersion(output: String)
}

struct ADBService: ADBServiceProtocol {
    private let runner: ADBProcessRunning

    init(runner: ADBProcessRunning) {
        self.runner = runner
    }

    func version() async throws -> String {
        let result = try await runner.run(arguments: ["version"])
        try Self.checkSuccess(arguments: ["version"], result: result)
        return try Self.parseVersion(result.standardOutput)
    }

    func startServer() async throws {
        let result = try await runner.run(arguments: ["start-server"])
        try Self.checkSuccess(arguments: ["start-server"], result: result)
    }

    private static func checkSuccess(arguments: [String], result: ADBProcessResult) throws {
        guard result.exitCode == 0 else {
            throw ADBServiceError.commandFailed(
                arguments: arguments,
                exitCode: result.exitCode,
                standardError: result.standardError
            )
        }
    }

    static func parseVersion(_ output: String) throws -> String {
        guard
            let line = output.split(separator: "\n").first(where: { $0.contains("Android Debug Bridge version") }),
            let range = line.range(of: "version ")
        else {
            throw ADBServiceError.unparsableVersion(output: output)
        }
        return String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
    }
}
