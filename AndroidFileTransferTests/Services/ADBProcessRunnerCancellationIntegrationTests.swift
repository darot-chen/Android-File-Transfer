import Testing
@testable import AndroidFileTransfer

/// Exercises real process cancellation: `adb wait-for-device` blocks
/// indefinitely with no device attached, so if Task cancellation didn't
/// actually terminate the underlying process, this test would hang forever.
@Suite
struct ADBProcessRunnerCancellationIntegrationTests {
    @Test
    func cancellingATaskTerminatesTheUnderlyingProcess() async throws {
        let runner = ADBProcessRunner()

        let task = Task {
            try await runner.run(arguments: ["wait-for-device"])
        }

        try await Task.sleep(for: .milliseconds(200))
        task.cancel()

        await #expect(throws: (any Error).self) {
            _ = try await task.value
        }
    }
}
