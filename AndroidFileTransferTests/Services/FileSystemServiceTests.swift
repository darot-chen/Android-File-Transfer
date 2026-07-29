import Foundation
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
        #expect(recorded == [["-s", "R58N70ABCDE", "shell", "ls -la -L --time-style=long-iso -- '/sdcard'"]])
    }

    @Test
    func listDirectoryFallsBackWhenTimeStyleFlagIsUnsupported() async throws {
        // Some toybox builds (seen in the wild on Android 16) reject
        // --time-style outright but default to the same ISO date format.
        let output = "-rw-rw---- 1 u0_a123 sdcard_rw 1024 2024-01-15 10:20 notes.txt"
        let runner = MockADBProcessRunner(results: [
            .success(ADBProcessResult(exitCode: 1, standardOutput: "", standardError: "ls: Unknown option 'time-style=long-iso'")),
            .success(ADBProcessResult(exitCode: 0, standardOutput: output, standardError: "")),
        ])
        let service = FileSystemService(runner: runner)

        let files = try await service.listDirectory(path: "/sdcard", on: "R58N70ABCDE")

        #expect(files == RemoteFile.parseListing(output, parentPath: "/sdcard"))

        let recorded = await runner.recordedArguments
        #expect(recorded == [
            ["-s", "R58N70ABCDE", "shell", "ls -la -L --time-style=long-iso -- '/sdcard'"],
            ["-s", "R58N70ABCDE", "shell", "ls -la -L -- '/sdcard'"],
        ])
    }

    @Test
    func listDirectoryThrowsWhenBothAttemptsFail() async {
        let runner = MockADBProcessRunner(
            result: .success(ADBProcessResult(exitCode: 1, standardOutput: "", standardError: "no such file or directory"))
        )
        let service = FileSystemService(runner: runner)

        await #expect(throws: FileSystemServiceError.self) {
            _ = try await service.listDirectory(path: "/missing", on: "R58N70ABCDE")
        }

        let recorded = await runner.recordedArguments
        #expect(recorded.count == 2)
    }

    @Test
    func listDirectoryQuotesPathWithShellMetacharacters() async throws {
        let runner = MockADBProcessRunner(
            result: .success(ADBProcessResult(exitCode: 0, standardOutput: "", standardError: ""))
        )
        let service = FileSystemService(runner: runner)

        _ = try await service.listDirectory(path: "/sdcard/a; rm -rf /", on: "R58N70ABCDE")

        let recorded = await runner.recordedArguments
        #expect(recorded[0][3] == "ls -la -L --time-style=long-iso -- '/sdcard/a; rm -rf /'")
    }

    @Test
    func deleteUsesExpectedArguments() async throws {
        let runner = MockADBProcessRunner(result: .success(ADBProcessResult(exitCode: 0, standardOutput: "", standardError: "")))
        let service = FileSystemService(runner: runner)

        try await service.delete(path: "/sdcard/old.txt", on: "R58N70ABCDE")

        let recorded = await runner.recordedArguments
        #expect(recorded == [["-s", "R58N70ABCDE", "shell", "rm -rf -- '/sdcard/old.txt'"]])
    }

    @Test
    func deleteQuotesPathWithShellMetacharacters() async throws {
        let runner = MockADBProcessRunner(result: .success(ADBProcessResult(exitCode: 0, standardOutput: "", standardError: "")))
        let service = FileSystemService(runner: runner)

        try await service.delete(path: "/sdcard/b; echo INJECTED", on: "R58N70ABCDE")

        let recorded = await runner.recordedArguments
        #expect(recorded == [["-s", "R58N70ABCDE", "shell", "rm -rf -- '/sdcard/b; echo INJECTED'"]])
    }

    @Test
    func renameUsesExpectedArguments() async throws {
        let runner = MockADBProcessRunner(result: .success(ADBProcessResult(exitCode: 0, standardOutput: "", standardError: "")))
        let service = FileSystemService(runner: runner)

        try await service.rename(from: "/sdcard/a.txt", to: "/sdcard/b.txt", on: "R58N70ABCDE")

        let recorded = await runner.recordedArguments
        #expect(recorded == [["-s", "R58N70ABCDE", "shell", "mv -- '/sdcard/a.txt' '/sdcard/b.txt'"]])
    }

    @Test
    func renameQuotesDestinationWithShellMetacharacters() async throws {
        // This is the exact real-world injection this app shipped with:
        // renaming to a name containing ";" used to execute the rest of the
        // string as a second command on the device.
        let runner = MockADBProcessRunner(result: .success(ADBProcessResult(exitCode: 0, standardOutput: "", standardError: "")))
        let service = FileSystemService(runner: runner)

        try await service.rename(from: "/sdcard/a", to: "/sdcard/b; echo INJECTED > /sdcard/PROOF.txt", on: "R58N70ABCDE")

        let recorded = await runner.recordedArguments
        #expect(recorded == [
            ["-s", "R58N70ABCDE", "shell", "mv -- '/sdcard/a' '/sdcard/b; echo INJECTED > /sdcard/PROOF.txt'"],
        ])
    }

    @Test
    func createFolderUsesExpectedArguments() async throws {
        let runner = MockADBProcessRunner(result: .success(ADBProcessResult(exitCode: 0, standardOutput: "", standardError: "")))
        let service = FileSystemService(runner: runner)

        try await service.createFolder(path: "/sdcard/NewFolder", on: "R58N70ABCDE")

        let recorded = await runner.recordedArguments
        #expect(recorded == [["-s", "R58N70ABCDE", "shell", "mkdir -- '/sdcard/NewFolder'"]])
    }

    @Test
    func searchUsesExpectedArguments() async throws {
        let runner = MockADBProcessRunner(
            result: .success(ADBProcessResult(exitCode: 0, standardOutput: "/sdcard/DCIM/a.jpg\n", standardError: ""))
        )
        let service = FileSystemService(runner: runner)

        let results = try await service.search(query: "vacation", in: "/sdcard", on: "R58N70ABCDE")

        #expect(results == ["/sdcard/DCIM/a.jpg"])
        let recorded = await runner.recordedArguments
        #expect(recorded == [["-s", "R58N70ABCDE", "shell", "find -L '/sdcard' -iname '*vacation*'"]])
    }

    @Test
    func searchQuotesQueryWithShellMetacharacters() async throws {
        let runner = MockADBProcessRunner(
            result: .success(ADBProcessResult(exitCode: 0, standardOutput: "", standardError: ""))
        )
        let service = FileSystemService(runner: runner)

        _ = try await service.search(query: "a' ; rm -rf /", in: "/sdcard", on: "R58N70ABCDE")

        let recorded = await runner.recordedArguments
        #expect(recorded == [["-s", "R58N70ABCDE", "shell", "find -L '/sdcard' -iname '*a'\\'' ; rm -rf /*'"]])
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

    @Test
    func scanFilesUsesExpectedArgumentsAndParsesPathsSizeAndDate() async throws {
        let output = "12345 1700000000.5 /sdcard/DCIM/a.jpg\n67 1700000100.0 /sdcard/Download/b.pdf\n"
        let runner = MockADBProcessRunner(
            result: .success(ADBProcessResult(exitCode: 0, standardOutput: output, standardError: ""))
        )
        let service = FileSystemService(runner: runner)

        let files = try await service.scanFiles(under: "/sdcard", on: "R58N70ABCDE")

        #expect(files.map(\.path) == ["/sdcard/DCIM/a.jpg", "/sdcard/Download/b.pdf"])
        #expect(files.map(\.name) == ["a.jpg", "b.pdf"])
        #expect(files.map(\.size) == [12345, 67])
        #expect(files[0].modifiedAt == Date(timeIntervalSince1970: 1_700_000_000.5))
        #expect(files.allSatisfy { !$0.isDirectory })
        let recorded = await runner.recordedArguments
        #expect(recorded == [[
            "-s", "R58N70ABCDE", "shell",
            "find -L '/sdcard' \\( -path '*/Android/data' -o -path '*/Android/obb' \\) -prune -o -type f -printf '%s %T@ %p\\n'",
        ]])
    }

    @Test
    func scanFilesThrowsOnNonZeroExitCode() async {
        let runner = MockADBProcessRunner(
            result: .success(ADBProcessResult(exitCode: 1, standardOutput: "", standardError: "no such file or directory"))
        )
        let service = FileSystemService(runner: runner)

        await #expect(throws: FileSystemServiceError.self) {
            _ = try await service.scanFiles(under: "/missing", on: "R58N70ABCDE")
        }
    }
}
