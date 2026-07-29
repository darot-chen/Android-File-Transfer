import Testing
@testable import AndroidFileTransfer

@MainActor
@Suite
struct DeviceListViewModelTests {
    @Test
    func startObservingAppliesEachSnapshotInOrder() async throws {
        let streaming = MockADBDeviceStreaming(snapshots: [
            "",
            "R58N70ABCDE\tdevice product:beyond1lte model:SM_G973F device:beyond1 transport_id:3",
        ])
        let viewModel = DeviceListViewModel(deviceService: DeviceService(streaming: streaming), detailsService: MockDeviceDetailsService())

        viewModel.startObserving()
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.devices == [Device(serial: "R58N70ABCDE", state: .device, model: "SM_G973F")])
    }

    @Test
    func startObservingIsIdempotent() async throws {
        let streaming = MockADBDeviceStreaming(snapshots: [
            "R58N70ABCDE\tdevice product:beyond1lte model:SM_G973F device:beyond1 transport_id:3",
        ])
        let viewModel = DeviceListViewModel(deviceService: DeviceService(streaming: streaming), detailsService: MockDeviceDetailsService())

        viewModel.startObserving()
        viewModel.startObserving()
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.devices.count == 1)
    }

    @Test
    func stopObservingDoesNotCrashWhenCalledBeforeStart() {
        let viewModel = DeviceListViewModel(deviceService: DeviceService(streaming: MockADBDeviceStreaming(snapshots: [])), detailsService: MockDeviceDetailsService())

        viewModel.stopObserving()

        #expect(viewModel.devices.isEmpty)
    }

    @Test
    func streamFailureDoesNotCrashAndLeavesLastKnownDevices() async throws {
        struct SomeError: Error {}
        let streaming = MockADBDeviceStreaming(
            snapshots: ["R58N70ABCDE\tdevice product:beyond1lte model:SM_G973F device:beyond1 transport_id:3"],
            failure: SomeError()
        )
        let viewModel = DeviceListViewModel(deviceService: DeviceService(streaming: streaming), detailsService: MockDeviceDetailsService())

        viewModel.startObserving()
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.devices.count == 1)
    }
}
