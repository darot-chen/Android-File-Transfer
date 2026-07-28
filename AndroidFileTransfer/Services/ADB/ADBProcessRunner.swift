import Foundation

// Process isn't Sendable, but it's only ever touched from run(arguments:)'s
// own scope and this box's use is confined to that; onCancel below runs
// outside actor isolation and needs a Sendable capture to call terminate().
private final class ProcessBox: @unchecked Sendable {
    let process: Process
    init(_ process: Process) { self.process = process }
}

actor ADBProcessRunner: ADBProcessRunning {
    private let binaryURL: URL?

    init(binaryURL: URL? = ADBBinaryLocator.resolve()) {
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

        let box = ProcessBox(process)

        return try await withTaskCancellationHandler {
            // Only start draining the pipes after a confirmed launch, so a failed
            // launch can't leave these waiting forever on a write end that never closes.
            async let stdoutData = Self.readAll(stdoutPipe.fileHandleForReading)
            async let stderrData = Self.readAll(stderrPipe.fileHandleForReading)

            await withCheckedContinuation { continuation in
                process.terminationHandler = { _ in continuation.resume() }
            }

            if Task.isCancelled {
                throw CancellationError()
            }

            return ADBProcessResult(
                exitCode: process.terminationStatus,
                standardOutput: String(decoding: await stdoutData, as: UTF8.self),
                standardError: String(decoding: await stderrData, as: UTF8.self)
            )
        } onCancel: {
            box.process.terminate()
        }
    }

    // Reads via a dedicated GCD thread rather than FileHandle.bytes: the latter
    // ties up Swift's small cooperative thread pool for the duration of a blocking
    // read, which can starve unrelated async work elsewhere in the app.
    private static func readAll(_ handle: FileHandle) async -> Data {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: handle.readDataToEndOfFile())
            }
        }
    }
}
