import Testing
@testable import AndroidFileTransfer

@Suite
struct DeviceAvailabilityTests {
    private let ready = Device(serial: "READY", state: .device, model: "Pixel_9_Pro")
    private let unauthorized = Device(serial: "LOCKED", state: .unauthorized, model: nil)
    private let offline = Device(serial: "OFF", state: .offline, model: nil)

    @Test
    func noDevicesWinsEvenWithAStaleSelection() {
        #expect(DeviceAvailability.resolve(devices: [], selectedSerial: "GONE") == .noDevices)
    }

    @Test
    func selectionOfADisconnectedDeviceIsNoSelection() {
        #expect(DeviceAvailability.resolve(devices: [ready], selectedSerial: "GONE") == .noSelection)
        #expect(DeviceAvailability.resolve(devices: [ready], selectedSerial: nil) == .noSelection)
    }

    @Test
    func mapsDeviceStates() {
        #expect(DeviceAvailability.resolve(devices: [ready], selectedSerial: "READY") == .ready(ready))
        #expect(DeviceAvailability.resolve(devices: [unauthorized], selectedSerial: "LOCKED") == .unauthorized(unauthorized))
        #expect(DeviceAvailability.resolve(devices: [offline], selectedSerial: "OFF") == .unavailable(offline))
    }

    @Test
    func readyDeviceIsOnlySetWhenReady() {
        #expect(DeviceAvailability.ready(ready).readyDevice == ready)
        #expect(DeviceAvailability.unauthorized(unauthorized).readyDevice == nil)
        #expect(DeviceAvailability.noDevices.readyDevice == nil)
    }

    @Test
    func reconciledSelectionKeepsAStillAttachedDevice() {
        let selection = DeviceAvailability.reconciledSelection(current: "LOCKED", devices: [ready, unauthorized])
        #expect(selection == "LOCKED")
    }

    @Test
    func reconciledSelectionFallsBackToFirstReadyDevice() {
        #expect(DeviceAvailability.reconciledSelection(current: nil, devices: [unauthorized, ready]) == "READY")
        #expect(DeviceAvailability.reconciledSelection(current: "GONE", devices: [ready]) == "READY")
    }

    @Test
    func reconciledSelectionClearsWhenNothingIsReady() {
        #expect(DeviceAvailability.reconciledSelection(current: "GONE", devices: []) == nil)
        #expect(DeviceAvailability.reconciledSelection(current: nil, devices: [unauthorized]) == nil)
    }

    @Test
    func displayNameReplacesUnderscoresAndFallsBackToSerial() {
        #expect(ready.displayName == "Pixel 9 Pro")
        #expect(unauthorized.displayName == "LOCKED")
    }
}
