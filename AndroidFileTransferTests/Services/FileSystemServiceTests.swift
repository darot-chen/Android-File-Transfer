import Testing
@testable import AndroidFileTransfer

@Suite
struct FileSystemServiceTests {
    @Test
    func listDirectoryParsesResultAndUsesExpectedArguments() async throws {
        let output = "-rw-rw---- 1 u0_a123 sdcard_rw 1024 2024-01-15 10:20 notes.txt"
        let runner = MockADBProcessRunner(
            result: .success(ADBProcessResult(exitCode: 0, standardOutput: output, standardError: ""))
        )
        let service = FileSystemService(runner: runner)

        let files = try await service.listDirectory(path: "/sdcard", on: "R58N70ABCDE")

        #expect(files == RemoteFile.parseListing(output, parentPath: "/sdcard"))

        let recorded = await runner.recordedArguments
        #expect(recorded == [["-s", "R58N70ABCDE", "shell", "ls", "-la", "--time-style=long-iso", "--", "/sdcard"]])
    }

    @Test
    func listDirectoryThrowsOnNonZeroExitCode() async {
        let runner = MockADBProcessRunner(
            result: .success(ADBProcessResult(exitCode: 1, standardOutput: "", standardError: "no such file or directory"))
        )
        let service = FileSystemService(runner: runner)

        await #expect(throws: FileSystemServiceError.self) {
            _ = try await service.listDirectory(path: "/missing", on: "R58N70ABCDE")
        }
    }

    @Test
    func deleteUsesExpectedArguments() async throws {
        let runner = MockADBProcessRunner(result: .success(ADBProcessResult(exitCode: 0, standardOutput: "", standardError: "")))
        let service = FileSystemService(runner: runner)

        try await service.delete(path: "/sdcard/old.txt", on: "R58N70ABCDE")

        let recorded = await runner.recordedArguments
        #expect(recorded == [["-s", "R58N70ABCDE", "shell", "rm", "-rf", "--", "/sdcard/old.txt"]])
    }

    @Test
    func renameUsesExpectedArguments() async throws {
        let runner = MockADBProcessRunner(result: .success(ADBProcessResult(exitCode: 0, standardOutput: "", standardError: "")))
        let service = FileSystemService(runner: runner)

        try await service.rename(from: "/sdcard/a.txt", to: "/sdcard/b.txt", on: "R58N70ABCDE")

        let recorded = await runner.recordedArguments
        #expect(recorded == [["-s", "R58N70ABCDE", "shell", "mv", "--", "/sdcard/a.txt", "/sdcard/b.txt"]])
    }

    @Test
    func createFolderUsesExpectedArguments() async throws {
        let runner = MockADBProcessRunner(result: .success(ADBProcessResult(exitCode: 0, standardOutput: "", standardError: "")))
        let service = FileSystemService(runner: runner)

        try await service.createFolder(path: "/sdcard/NewFolder", on: "R58N70ABCDE")

        let recorded = await runner.recordedArguments
        #expect(recorded == [["-s", "R58N70ABCDE", "shell", "mkdir", "--", "/sdcard/NewFolder"]])
    }

    @Test
    func mutatingOperationsThrowOnNonZeroExitCode() async {
        let runner = MockADBProcessRunner(
            result: .success(ADBProcessResult(exitCode: 1, standardOutput: "", standardError: "permission denied"))
        )
        let service = FileSystemService(runner: runner)

        await #expect(throws: FileSystemServiceError.self) {
            try await service.delete(path: "/sdcard/x", on: "R58N70ABCDE")
        }
    }
}
