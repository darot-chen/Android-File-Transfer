import Testing
@testable import AndroidFileTransfer

@Suite
struct ADBServiceTests {
    private static let sampleVersionOutput = """
    Android Debug Bridge version 1.0.41
    Version 35.0.2-12147458
    Installed as /Users/darot/platform-tools/adb
    Running on Darwin 24.0.0 (arm64)
    """

    @Test
    func versionParsesFromRealisticOutput() async throws {
        let runner = MockADBProcessRunner(
            result: .success(ADBProcessResult(exitCode: 0, standardOutput: Self.sampleVersionOutput, standardError: ""))
        )
        let service = ADBService(runner: runner)

        let version = try await service.version()

        #expect(version == "1.0.41")
    }

    @Test
    func versionThrowsOnUnparsableOutput() async throws {
        let runner = MockADBProcessRunner(
            result: .success(ADBProcessResult(exitCode: 0, standardOutput: "garbage", standardError: ""))
        )
        let service = ADBService(runner: runner)

        await #expect(throws: ADBServiceError.self) {
            _ = try await service.version()
        }
    }

    @Test
    func versionThrowsOnNonZeroExitCode() async throws {
        let runner = MockADBProcessRunner(
            result: .success(ADBProcessResult(exitCode: 1, standardOutput: "", standardError: "boom"))
        )
        let service = ADBService(runner: runner)

        await #expect(throws: ADBServiceError.self) {
            _ = try await service.version()
        }
    }

    @Test
    func startServerSendsExpectedArguments() async throws {
        let runner = MockADBProcessRunner(
            result: .success(ADBProcessResult(exitCode: 0, standardOutput: "", standardError: ""))
        )
        let service = ADBService(runner: runner)

        try await service.startServer()

        let recorded = await runner.recordedArguments
        #expect(recorded == [["start-server"]])
    }
}
