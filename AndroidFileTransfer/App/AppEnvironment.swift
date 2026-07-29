import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let adbService: ADBServiceProtocol
    let deviceService: DeviceServiceProtocol
    let deviceDetailsService: DeviceDetailsServiceProtocol
    let fileSystemService: FileSystemServiceProtocol
    let transferService: TransferServiceProtocol
    let transferQueue: TransferQueueViewModel
    let favorites: FavoritesViewModel
    let recentFolders: RecentFoldersViewModel
    let settings: SettingsViewModel
    let logStore: LogStore

    init(
        adbService: ADBServiceProtocol = ADBService(runner: ADBProcessRunner()),
        deviceService: DeviceServiceProtocol = DeviceService(streaming: ADBTrackDevicesStreamer()),
        deviceDetailsService: DeviceDetailsServiceProtocol = DeviceDetailsService(runner: ADBProcessRunner()),
        fileSystemService: FileSystemServiceProtocol = FileSystemService(runner: ADBProcessRunner()),
        transferService: TransferServiceProtocol = TransferService(),
        historyStore: TransferHistoryStoring = TransferHistoryStore(),
        favoritesStore: FavoritesStoring = FavoritesStore(),
        recentFoldersStore: RecentFoldersStoring = RecentFoldersStore(),
        settingsDefaults: UserDefaults = .standard
    ) {
        self.adbService = adbService
        self.deviceService = deviceService
        self.deviceDetailsService = deviceDetailsService
        self.fileSystemService = fileSystemService
        self.transferService = transferService
        self.favorites = FavoritesViewModel(store: favoritesStore)
        self.recentFolders = RecentFoldersViewModel(store: recentFoldersStore)
        self.logStore = LogStore()

        let settings = SettingsViewModel(defaults: settingsDefaults)
        self.settings = settings

        let transferQueue = TransferQueueViewModel(
            transferService: transferService,
            historyStore: historyStore,
            maxConcurrent: settings.maxConcurrentTransfers
        )
        self.transferQueue = transferQueue
        settings.onMaxConcurrentTransfersChanged = { [weak transferQueue] newValue in
            transferQueue?.updateMaxConcurrent(newValue)
        }
    }

    func bootstrapADB() async {
        PreviewCache.clear()
        ThumbnailCache.clear()
        do {
            let version = try await adbService.version()
            logStore.log(.info, category: "ADB", "Bundled adb version: \(version)")
            try await adbService.startServer()
            logStore.log(.info, category: "ADB", "adb server started")
        } catch {
            logStore.log(.error, category: "ADB", "Bootstrap failed: \(String(describing: error))")
        }
    }
}
