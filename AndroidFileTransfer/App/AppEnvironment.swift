import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let adbService: ADBServiceProtocol
    let deviceService: DeviceServiceProtocol
    let fileSystemService: FileSystemServiceProtocol
    let transferService: TransferServiceProtocol
    let transferQueue: TransferQueueViewModel
    let favorites: FavoritesViewModel

    init(
        adbService: ADBServiceProtocol = ADBService(runner: ADBProcessRunner()),
        deviceService: DeviceServiceProtocol = DeviceService(streaming: ADBTrackDevicesStreamer()),
        fileSystemService: FileSystemServiceProtocol = FileSystemService(runner: ADBProcessRunner()),
        transferService: TransferServiceProtocol = TransferService(),
        historyStore: TransferHistoryStoring = TransferHistoryStore(),
        favoritesStore: FavoritesStoring = FavoritesStore()
    ) {
        self.adbService = adbService
        self.deviceService = deviceService
        self.fileSystemService = fileSystemService
        self.transferService = transferService
        self.transferQueue = TransferQueueViewModel(transferService: transferService, historyStore: historyStore)
        self.favorites = FavoritesViewModel(store: favoritesStore)
    }

    func bootstrapADB() async {
        PreviewCache.clear()
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
