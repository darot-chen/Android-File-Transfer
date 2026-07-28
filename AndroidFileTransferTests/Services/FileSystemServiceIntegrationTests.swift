import Testing
@testable import AndroidFileTransfer

/// Exercises the real bundled adb binary end to end. No device is attached
/// in this environment, so this proves the command is spawned correctly and
/// fails gracefully (rather than hanging or crashing) when there's no device.
@Suite
struct FileSystemServiceIntegrationTests {
    @Test
    func listDirectoryFailsGracefullyWithNoDeviceAttached() async throws {
        let service = FileSystemService(runner: ADBProcessRunner())

        await #expect(throws: FileSystemServiceError.self) {
            _ = try await service.listDirectory(path: "/sdcard", on: "nonexistent-serial")
        }
    }
}
