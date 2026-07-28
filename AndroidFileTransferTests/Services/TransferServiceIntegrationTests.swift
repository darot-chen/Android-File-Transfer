import Foundation
import Testing
@testable import AndroidFileTransfer

/// Exercises the real bundled adb binary end to end. No device is attached
/// in this environment, so a real ~1GB-transfer round trip can't be
/// verified here — this proves push fails gracefully (not hanging or
/// crashing) rather than exercising an actual transfer.
@Suite
struct TransferServiceIntegrationTests {
    @Test
    func pushFailsGracefullyWithNoDeviceAttached() async throws {
        let service = TransferService()
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("hello".utf8).write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        await #expect(throws: (any Error).self) {
            for try await _ in service.push(localURL: tempFile, remotePath: "/sdcard/test.txt", on: "nonexistent-serial") {}
        }
    }
}
