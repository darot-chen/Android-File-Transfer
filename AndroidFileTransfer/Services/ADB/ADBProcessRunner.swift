import Foundation

actor ADBProcessRunner: ADBProcessRunning {
    private let binaryURL: URL?

    init(binaryURL: URL? = Bundle.main.url(forResource: "adb", withExtension: nil)) {
        self.binaryURL = binaryURL
    }

    func run(arguments: [String]) async throws -> ADBProcessResult {
        guard let binaryURL else {
            throw ADBProcessError.binaryNotFound
        }

        let process = Process()
        process.executableURL = binaryURL
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw ADBProcessError.launchFailed(error.localizedDescription)
        }

        // Only start draining the pipes after a confirmed launch, so a failed
        // launch can't leave these waiting forever on a write end that never closes.
        async let stdoutData = Self.readAll(stdoutPipe.fileHandleForReading)
        async let stderrData = Self.readAll(stderrPipe.fileHandleForReading)

        await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in continuation.resume() }
        }

        return ADBProcessResult(
            exitCode: process.terminationStatus,
            standardOutput: String(decoding: await stdoutData, as: UTF8.self),
            standardError: String(decoding: await stderrData, as: UTF8.self)
        )
    }

    private static func readAll(_ handle: FileHandle) async -> Data {
        var data = Data()
        do {
            for try await byte in handle.bytes {
                data.append(byte)
            }
        } catch {
            // Pipe closed at EOF surfaces as a thrown error here; treat as end of stream.
        }
        return data
    }
}
