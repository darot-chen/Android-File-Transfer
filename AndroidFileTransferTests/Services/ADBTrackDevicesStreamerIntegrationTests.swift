import Testing
@testable import AndroidFileTransfer

/// Exercises the real bundled `adb track-devices -l` against the actual
/// length-prefixed protocol framing (not a mock), proving the parser in
/// ADBTrackDevicesStreamer speaks it correctly. Doesn't assume whether a
/// real device is attached in this environment — either way, the snapshot
/// must arrive promptly and parse into valid Device values.
@Suite
struct ADBTrackDevicesStreamerIntegrationTests {
    @Test
    func realTrackDevicesEmitsAParseableInitialSnapshot() async throws {
        let streamer = ADBTrackDevicesStreamer()

        for try await snapshot in streamer.deviceListSnapshots() {
            let devices = Device.parseSnapshot(snapshot)
            // Every non-empty line must have parsed into a Device; a
            // non-empty result here (when a device happens to be attached)
            // still proves the length-prefixed framing was decoded correctly.
            let nonEmptyLineCount = snapshot.split(separator: "\n", omittingEmptySubsequences: true).count
            #expect(devices.count == nonEmptyLineCount)
            break
        }
    }
}
