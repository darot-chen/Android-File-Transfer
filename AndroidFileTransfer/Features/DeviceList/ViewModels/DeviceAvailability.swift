import Foundation

/// What the main window can show for the current device selection. Anything
/// other than `.ready` means no adb command should be sent to the device —
/// the UI shows guidance instead of browsing (and failing against) it.
enum DeviceAvailability: Equatable, Sendable {
    case noDevices
    case noSelection
    case unauthorized(Device)
    case unavailable(Device)
    case ready(Device)

    static func resolve(devices: [Device], selectedSerial: String?) -> DeviceAvailability {
        guard !devices.isEmpty else { return .noDevices }
        guard let selectedSerial, let device = devices.first(where: { $0.serial == selectedSerial }) else {
            return .noSelection
        }
        switch device.state {
        case .device: return .ready(device)
        case .unauthorized: return .unauthorized(device)
        case .offline, .noPermissions, .unknown: return .unavailable(device)
        }
    }

    /// Keeps the current selection while that device is still attached;
    /// otherwise falls back to the first device that's ready to browse, so
    /// plugging a phone in shows its files without an extra click and
    /// unplugging it doesn't leave a stale selection pointing at nothing.
    static func reconciledSelection(current: String?, devices: [Device]) -> String? {
        if let current, devices.contains(where: { $0.serial == current }) {
            return current
        }
        return devices.first(where: { $0.state == .device })?.serial
    }

    var readyDevice: Device? {
        if case .ready(let device) = self { device } else { nil }
    }
}
