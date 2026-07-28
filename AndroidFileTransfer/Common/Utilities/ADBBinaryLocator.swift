import Foundation

enum ADBBinaryLocator {
    static func resolve() -> URL? {
        let override = UserDefaults.standard.string(forKey: SettingsKeys.adbBinaryPathOverride) ?? ""
        if !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        return Bundle.main.url(forResource: "adb", withExtension: nil)
    }
}
