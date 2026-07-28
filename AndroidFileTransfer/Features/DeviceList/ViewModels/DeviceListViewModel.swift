import Foundation
import Observation

@MainActor
@Observable
final class DeviceListViewModel {
    private(set) var devices: [Device] = []

    private let deviceService: DeviceServiceProtocol
    private var observationTask: Task<Void, Never>?

    init(deviceService: DeviceServiceProtocol) {
        self.deviceService = deviceService
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
