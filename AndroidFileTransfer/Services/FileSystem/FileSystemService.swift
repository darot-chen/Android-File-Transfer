protocol FileSystemServiceProtocol: Sendable {
    func listDirectory(path: String, on serial: String) async throws -> [RemoteFile]
    func delete(path: String, on serial: String) async throws
    func rename(from oldPath: String, to newPath: String, on serial: String) async throws
    func createFolder(path: String, on serial: String) async throws
    func search(query: String, in path: String, on serial: String) async throws -> [String]
    func scanFiles(under root: String, on serial: String) async throws -> [String]
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
        let quotedPath = ShellQuoting.quote(path)
        let isoResult = try await runner.run(arguments: [
            "-s", serial, "shell", "ls -la -L --time-style=long-iso -- \(quotedPath)",
        ])
        if isoResult.exitCode == 0 {
            return RemoteFile.parseListing(isoResult.standardOutput, parentPath: path)
        }

        // Some toybox builds (seen on Android 16 / SDK 36) don't recognize
        // --time-style at all, but their -l output already defaults to the
        // same "yyyy-MM-dd HH:mm" format, so retry without the flag before
        // surfacing an error.
        let fallbackResult = try await runner.run(arguments: [
            "-s", serial, "shell", "ls -la -L -- \(quotedPath)",
        ])
        guard fallbackResult.exitCode == 0 else {
            throw FileSystemServiceError.commandFailed(exitCode: fallbackResult.exitCode, standardError: fallbackResult.standardError)
        }
        return RemoteFile.parseListing(fallbackResult.standardOutput, parentPath: path)
    }

    func delete(path: String, on serial: String) async throws {
        try await runShellCommand("rm -rf -- \(ShellQuoting.quote(path))", on: serial)
    }

    func rename(from oldPath: String, to newPath: String, on serial: String) async throws {
        try await runShellCommand("mv -- \(ShellQuoting.quote(oldPath)) \(ShellQuoting.quote(newPath))", on: serial)
    }

    func createFolder(path: String, on serial: String) async throws {
        try await runShellCommand("mkdir -- \(ShellQuoting.quote(path))", on: serial)
    }

    func search(query: String, in path: String, on serial: String) async throws -> [String] {
        // -L: same symlink-following requirement as listDirectory — without
        // it, searching from /sdcard (always a symlink) silently finds nothing.
        let command = "find -L \(ShellQuoting.quote(path)) -iname \(ShellQuoting.quote("*\(query)*"))"
        let result = try await runner.run(arguments: ["-s", serial, "shell", command])
        guard result.exitCode == 0 else {
            throw FileSystemServiceError.commandFailed(exitCode: result.exitCode, standardError: result.standardError)
        }
        return result.standardOutput.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }

    func scanFiles(under root: String, on serial: String) async throws -> [String] {
        // Prune Android/data and Android/obb: per-app sandboxed storage that
        // isn't meaningful to browse as "your files" and can be an order of
        // magnitude larger than everything else combined (measured ~130k
        // files vs ~19k on a real device), which would make an unpruned scan
        // both slow and full of noise.
        let quotedRoot = ShellQuoting.quote(root)
        let excludeData = ShellQuoting.quote("*/Android/data")
        let excludeObb = ShellQuoting.quote("*/Android/obb")
        let command = "find -L \(quotedRoot) \\( -path \(excludeData) -o -path \(excludeObb) \\) -prune -o -type f -print"
        let result = try await runner.run(arguments: ["-s", serial, "shell", command])
        guard result.exitCode == 0 else {
            throw FileSystemServiceError.commandFailed(exitCode: result.exitCode, standardError: result.standardError)
        }
        return result.standardOutput.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }

    private func runShellCommand(_ command: String, on serial: String) async throws {
        let result = try await runner.run(arguments: ["-s", serial, "shell", command])
        guard result.exitCode == 0 else {
            throw FileSystemServiceError.commandFailed(exitCode: result.exitCode, standardError: result.standardError)
        }
    }
}
