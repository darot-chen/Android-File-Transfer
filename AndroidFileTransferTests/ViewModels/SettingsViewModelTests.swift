import Foundation
import Testing
@testable import AndroidFileTransfer

@MainActor
@Suite
struct SettingsViewModelTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "SettingsViewModelTests-\(UUID().uuidString)")!
    }

    @Test
    func defaultsToSensibleValuesWhenNothingStored() {
        let viewModel = SettingsViewModel(defaults: makeDefaults())

        #expect(viewModel.adbBinaryPathOverride == "")
        #expect(viewModel.defaultDownloadDirectory == "")
        #expect(viewModel.maxConcurrentTransfers == 2)
        #expect(viewModel.appearance == .system)
    }

    @Test
    func changesPersistToUserDefaults() {
        let defaults = makeDefaults()
        let viewModel = SettingsViewModel(defaults: defaults)

        viewModel.adbBinaryPathOverride = "/usr/local/bin/adb"
        viewModel.maxConcurrentTransfers = 5
        viewModel.appearance = .dark

        #expect(defaults.string(forKey: SettingsKeys.adbBinaryPathOverride) == "/usr/local/bin/adb")
        #expect(defaults.integer(forKey: SettingsKeys.maxConcurrentTransfers) == 5)
        #expect(defaults.string(forKey: SettingsKeys.appearance) == "dark")
    }

    @Test
    func reloadsPersistedValuesOnNextInit() {
        let defaults = makeDefaults()
        let first = SettingsViewModel(defaults: defaults)
        first.maxConcurrentTransfers = 6

        let second = SettingsViewModel(defaults: defaults)

        #expect(second.maxConcurrentTransfers == 6)
    }

    @Test
    func changingMaxConcurrentTransfersInvokesCallback() {
        let viewModel = SettingsViewModel(defaults: makeDefaults())
        var observedValue: Int?
        viewModel.onMaxConcurrentTransfersChanged = { observedValue = $0 }

        viewModel.maxConcurrentTransfers = 4

        #expect(observedValue == 4)
    }
}
