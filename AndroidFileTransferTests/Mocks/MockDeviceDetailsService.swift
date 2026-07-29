@testable import AndroidFileTransfer

struct MockDeviceDetailsService: DeviceDetailsServiceProtocol {
    var details: DeviceDetails = DeviceDetails(androidVersion: nil, storage: nil)

    func fetchDetails(serial: String) async -> DeviceDetails {
        details
    }
}
