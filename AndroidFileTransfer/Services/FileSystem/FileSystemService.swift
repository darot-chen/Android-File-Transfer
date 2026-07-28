protocol FileSystemServiceProtocol: Sendable {
    func listDirectory(path: String, on serial: String) async throws -> [RemoteFile]
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
}
