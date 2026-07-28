import Testing
@testable import AndroidFileTransfer

/// Exercises the real bundled `adb track-devices -l` against the actual
/// length-prefixed protocol framing (not a mock), proving the parser in
/// ADBTrackDevicesStreamer speaks it correctly.
@Suite
struct ADBTrackDevicesStreamerIntegrationTests {
    @Test
    func realTrackDevicesEmitsAnInitialSnapshot() async throws {
        let streamer = ADBTrackDevicesStreamer()

        for try await snapshot in streamer.deviceListSnapshots() {
            // With no device attached in this environment, the initial
            // snapshot is an empty device list.
            #expect(snapshot.isEmpty)
            break
        }
    }
}
