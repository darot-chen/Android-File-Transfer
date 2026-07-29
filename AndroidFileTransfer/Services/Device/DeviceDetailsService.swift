import Foundation

struct DeviceStorage: Sendable, Equatable {
    let totalBytes: Int64
    let freeBytes: Int64
}

struct DeviceDetails: Sendable, Equatable {
    let androidVersion: String?
    let storage: DeviceStorage?
}

protocol DeviceDetailsServiceProtocol: Sendable {
    func fetchDetails(serial: String) async -> DeviceDetails
}

struct DeviceDetailsService: DeviceDetailsServiceProtocol {
    private let runner: ADBProcessRunning

    init(runner: ADBProcessRunning) {
        self.runner = runner
    }

    // Best-effort: a device that's mid-disconnect or briefly unauthorized
    // shouldn't surface an error, just omit the details that couldn't be read.
    func fetchDetails(serial: String) async -> DeviceDetails {
        async let versionResult = runner.run(arguments: ["-s", serial, "shell", "getprop ro.build.version.release"])
        async let storageResult = runner.run(arguments: ["-s", serial, "shell", "df /sdcard"])

        let version = (try? await versionResult).flatMap(Self.parseVersion)
        let storage = (try? await storageResult).flatMap(Self.parseStorage)
        return DeviceDetails(androidVersion: version, storage: storage)
    }

    private static func parseVersion(_ result: ADBProcessResult) -> String? {
        guard result.exitCode == 0 else { return nil }
        let trimmed = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // toybox `df` output:
    //   Filesystem     1K-blocks      Used Available Use% Mounted on
    //   /dev/fuse      476403680 151452328 324414484  32% /storage/emulated
    private static func parseStorage(_ result: ADBProcessResult) -> DeviceStorage? {
        guard result.exitCode == 0 else { return nil }
        let lines = result.standardOutput.split(separator: "\n").map(String.init)
        guard lines.count >= 2 else { return nil }
        let fields = lines[1].split(whereSeparator: \.isWhitespace).map(String.init)
        guard fields.count >= 4, let totalKB = Int64(fields[1]), let availableKB = Int64(fields[3]) else {
            return nil
        }
        return DeviceStorage(totalBytes: totalKB * 1024, freeBytes: availableKB * 1024)
    }
}
