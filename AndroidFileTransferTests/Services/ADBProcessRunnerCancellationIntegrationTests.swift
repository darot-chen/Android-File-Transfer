import Testing
@testable import AndroidFileTransfer

/// Exercises real process cancellation. Targets a serial that can't possibly
/// exist so `adb wait-for-device` blocks indefinitely regardless of whether
/// a real device happens to be attached in this environment — if Task
/// cancellation didn't actually terminate the underlying process, this test
/// would hang forever.
@Suite
struct ADBProcessRunnerCancellationIntegrationTests {
    @Test
    func cancellingATaskTerminatesTheUnderlyingProcess() async throws {
        let runner = ADBProcessRunner()

        let task = Task {
            try await runner.run(arguments: ["-s", "nonexistent-serial-for-cancellation-test", "wait-for-device"])
        }

        try await Task.sleep(for: .milliseconds(200))
        task.cancel()

        await #expect(throws: (any Error).self) {
            _ = try await task.value
        }
    }
}
