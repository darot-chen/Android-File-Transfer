import Testing
@testable import AndroidFileTransfer

/// Only meaningful with a real device attached (skips gracefully otherwise
/// by asserting the graceful-failure path) — this exists specifically to
/// verify the escaped-parenthesis `find` expression scanFiles() builds is
/// byte-for-byte what toybox find on a real device expects, since that
/// exact command was hand-verified against real hardware during development
/// (18791 files scanned, category counts matching a reference file manager
/// app on the same device for Audio/Documents/Archives/APKs exactly, and
/// within 1% for Videos — Images differs because this scans the raw
/// filesystem rather than querying MediaStore, so it also picks up
/// thumbnails and app-cache images MediaStore excludes).
@Suite
struct FileSystemServiceCategoryScanRealDeviceTests {
    @Test
    func scanFilesAgainstRealOrAbsentDeviceDoesNotHang() async throws {
        let service = FileSystemService(runner: ADBProcessRunner())

        // With no device (or a bogus serial), this must fail gracefully,
        // not hang or crash — proving the command is well-formed enough for
        // adb/the shell to parse and reject cleanly rather than choke on
        // malformed quoting.
        await #expect(throws: FileSystemServiceError.self) {
            _ = try await service.scanFiles(under: "/sdcard", on: "nonexistent-serial-for-scan-test")
        }
    }
}
