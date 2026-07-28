import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var adbBinaryPathOverride: String {
        didSet { defaults.set(adbBinaryPathOverride, forKey: SettingsKeys.adbBinaryPathOverride) }
    }

    var defaultDownloadDirectory: String {
        didSet { defaults.set(defaultDownloadDirectory, forKey: SettingsKeys.defaultDownloadDirectory) }
    }

    var maxConcurrentTransfers: Int {
        didSet {
            defaults.set(maxConcurrentTransfers, forKey: SettingsKeys.maxConcurrentTransfers)
            onMaxConcurrentTransfersChanged?(maxConcurrentTransfers)
        }
    }

    var appearance: AppearanceMode {
        didSet { defaults.set(appearance.rawValue, forKey: SettingsKeys.appearance) }
    }

    var onMaxConcurrentTransfersChanged: ((Int) -> Void)?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        adbBinaryPathOverride = defaults.string(forKey: SettingsKeys.adbBinaryPathOverride) ?? ""
        defaultDownloadDirectory = defaults.string(forKey: SettingsKeys.defaultDownloadDirectory) ?? ""
        maxConcurrentTransfers = defaults.object(forKey: SettingsKeys.maxConcurrentTransfers) as? Int ?? 2
        appearance = AppearanceMode(rawValue: defaults.string(forKey: SettingsKeys.appearance) ?? "") ?? .system
    }
}
