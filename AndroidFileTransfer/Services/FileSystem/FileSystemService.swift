protocol FileSystemServiceProtocol: Sendable {
    func listDirectory(path: String, on serial: String) async throws -> [RemoteFile]
    func delete(path: String, on serial: String) async throws
    func rename(from oldPath: String, to newPath: String, on serial: String) async throws
    func createFolder(path: String, on serial: String) async throws
}

enum FileSystemServiceError: Error, Sendable, Equatable {
    case commandFailed(exitCode: Int32, standardError: String)
}

struct FileSystemService: FileSystemServiceProtocol {
    private let runner: ADBProcessRunning

    init(runner: ADBProcessRunning) {
        self.runner = runner
    }

    func listDirectory(path: String, on serial: String) async throws -> [RemoteFile] {
        let result = try await runner.run(arguments: [
            "-s", serial,
            "shell", "ls", "-la", "--time-style=long-iso", "--", path,
        ])
        guard result.exitCode == 0 else {
            throw FileSystemServiceError.commandFailed(exitCode: result.exitCode, standardError: result.standardError)
        }
        return RemoteFile.parseListing(result.standardOutput, parentPath: path)
    }

    func delete(path: String, on serial: String) async throws {
        try await runShellCommand(["-s", serial, "shell", "rm", "-rf", "--", path])
    }

    func rename(from oldPath: String, to newPath: String, on serial: String) async throws {
        try await runShellCommand(["-s", serial, "shell", "mv", "--", oldPath, newPath])
    }

    func createFolder(path: String, on serial: String) async throws {
        try await runShellCommand(["-s", serial, "shell", "mkdir", "--", path])
    }

    private func runShellCommand(_ arguments: [String]) async throws {
        let result = try await runner.run(arguments: arguments)
        guard result.exitCode == 0 else {
            throw FileSystemServiceError.commandFailed(exitCode: result.exitCode, standardError: result.standardError)
        }
    }
}
