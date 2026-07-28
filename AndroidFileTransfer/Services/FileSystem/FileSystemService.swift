protocol FileSystemServiceProtocol: Sendable {
    func listDirectory(path: String, on serial: String) async throws -> [RemoteFile]
    func delete(path: String, on serial: String) async throws
    func rename(from oldPath: String, to newPath: String, on serial: String) async throws
    func createFolder(path: String, on serial: String) async throws
    func search(query: String, in path: String, on serial: String) async throws -> [String]
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
        // -L: without it, a symlink given as the listing target (e.g. /sdcard,
        // which is always a symlink on Android) shows as a single symlink
        // entry instead of its contents on at least some toybox builds.
        let isoResult = try await runner.run(arguments: [
            "-s", serial,
            "shell", "ls", "-la", "-L", "--time-style=long-iso", "--", path,
        ])
        if isoResult.exitCode == 0 {
            return RemoteFile.parseListing(isoResult.standardOutput, parentPath: path)
        }

        // Some toybox builds (seen on Android 16 / SDK 36) don't recognize
        // --time-style at all, but their -l output already defaults to the
        // same "yyyy-MM-dd HH:mm" format, so retry without the flag before
        // surfacing an error.
        let fallbackResult = try await runner.run(arguments: [
            "-s", serial,
            "shell", "ls", "-la", "-L", "--", path,
        ])
        guard fallbackResult.exitCode == 0 else {
            throw FileSystemServiceError.commandFailed(exitCode: fallbackResult.exitCode, standardError: fallbackResult.standardError)
        }
        return RemoteFile.parseListing(fallbackResult.standardOutput, parentPath: path)
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

    func search(query: String, in path: String, on serial: String) async throws -> [String] {
        let result = try await runner.run(arguments: [
            "-s", serial, "shell", "find", path, "-iname", "*\(query)*",
        ])
        guard result.exitCode == 0 else {
            throw FileSystemServiceError.commandFailed(exitCode: result.exitCode, standardError: result.standardError)
        }
        return result.standardOutput.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }

    private func runShellCommand(_ arguments: [String]) async throws {
        let result = try await runner.run(arguments: arguments)
        guard result.exitCode == 0 else {
            throw FileSystemServiceError.commandFailed(exitCode: result.exitCode, standardError: result.standardError)
        }
    }
}
