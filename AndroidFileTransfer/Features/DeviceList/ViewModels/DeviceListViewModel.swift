import Foundation
import Observation

@MainActor
@Observable
final class DeviceListViewModel {
    private(set) var devices: [Device] = []
    private(set) var detailsBySerial: [String: DeviceDetails] = [:]

    private let deviceService: DeviceServiceProtocol
    private let detailsService: DeviceDetailsServiceProtocol
    private var observationTask: Task<Void, Never>?

    init(deviceService: DeviceServiceProtocol, detailsService: DeviceDetailsServiceProtocol) {
        self.deviceService = deviceService
        self.detailsService = detailsService
    }

    func refreshDetails(for serial: String) async {
        detailsBySerial[serial] = await detailsService.fetchDetails(serial: serial)
    }

    func startObserving() {
        guard observationTask == nil else { return }
        observationTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await snapshot in deviceService.observeDevices() {
                    self.devices = snapshot
                }
            } catch {
                AppLog.adb.error("Device tracking stopped: \(String(describing: error), privacy: .public)")
            }
        }
    }

    func stopObserving() {
        observationTask?.cancel()
        observationTask = nil
    }
}
