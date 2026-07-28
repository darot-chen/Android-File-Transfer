import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let adbService: ADBServiceProtocol
    let deviceService: DeviceServiceProtocol
    let fileSystemService: FileSystemServiceProtocol
    let transferService: TransferServiceProtocol

    init(
        adbService: ADBServiceProtocol = ADBService(runner: ADBProcessRunner()),
        deviceService: DeviceServiceProtocol = DeviceService(streaming: ADBTrackDevicesStreamer()),
        fileSystemService: FileSystemServiceProtocol = FileSystemService(runner: ADBProcessRunner()),
        transferService: TransferServiceProtocol = TransferService()
    ) {
        self.adbService = adbService
        self.deviceService = deviceService
        self.fileSystemService = fileSystemService
        self.transferService = transferService
    }

    func bootstrapADB() async {
        do {
            let version = try await adbService.version()
            AppLog.adb.info("Bundled adb version: \(version, privacy: .public)")
            try await adbService.startServer()
            AppLog.adb.info("adb server started")
        } catch {
            AppLog.adb.error("ADB bootstrap failed: \(String(describing: error), privacy: .public)")
        }
    }
}
