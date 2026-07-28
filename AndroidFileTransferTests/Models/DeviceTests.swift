import Testing
@testable import AndroidFileTransfer

@Suite
struct DeviceTests {
    @Test
    func emptySnapshotYieldsNoDevices() {
        #expect(Device.parseSnapshot("") == [])
    }

    @Test
    func parsesReadyDeviceWithModel() {
        let line = "R58N70ABCDE\tdevice product:beyond1lte model:SM_G973F device:beyond1 transport_id:3"

        let devices = Device.parseSnapshot(line)

        #expect(devices == [Device(serial: "R58N70ABCDE", state: .device, model: "SM_G973F")])
    }

    @Test
    func parsesUnauthorizedDeviceWithoutModel() {
        let line = "R58N70ABCDE\tunauthorized"

        let devices = Device.parseSnapshot(line)

        #expect(devices == [Device(serial: "R58N70ABCDE", state: .unauthorized, model: nil)])
    }

    @Test
    func parsesMultipleDevicesAcrossLines() {
        let payload = """
        R58N70ABCDE\tdevice product:beyond1lte model:SM_G973F device:beyond1 transport_id:3
        emulator-5554\toffline
        """

        let devices = Device.parseSnapshot(payload)

        #expect(devices.count == 2)
        #expect(devices[0].serial == "R58N70ABCDE")
        #expect(devices[0].state == .device)
        #expect(devices[1] == Device(serial: "emulator-5554", state: .offline, model: nil))
    }

    @Test
    func unrecognizedStateFallsBackToUnknown() {
        let devices = Device.parseSnapshot("R58N70ABCDE\tsomething-new")

        #expect(devices == [Device(serial: "R58N70ABCDE", state: .unknown, model: nil)])
    }
}
