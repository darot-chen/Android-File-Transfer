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
}
