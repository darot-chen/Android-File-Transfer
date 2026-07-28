import Testing
@testable import AndroidFileTransfer

@Suite
struct DeviceServiceTests {
    @Test
    func observeDevicesParsesEachSnapshotInOrder() async throws {
        let streaming = MockADBDeviceStreaming(snapshots: [
            "",
            "R58N70ABCDE\tdevice product:beyond1lte model:SM_G973F device:beyond1 transport_id:3",
        ])
        let service = DeviceService(streaming: streaming)

        var received: [[Device]] = []
        for try await snapshot in service.observeDevices() {
            received.append(snapshot)
        }

        #expect(received == [
            [],
            [Device(serial: "R58N70ABCDE", state: .device, model: "SM_G973F")],
        ])
    }

    @Test
    func observeDevicesPropagatesStreamFailure() async {
        struct StreamingFailure: Error, Equatable {}
        let streaming = MockADBDeviceStreaming(snapshots: [""], failure: StreamingFailure())
        let service = DeviceService(streaming: streaming)

        await #expect(throws: StreamingFailure.self) {
            for try await _ in service.observeDevices() {}
        }
    }
}
