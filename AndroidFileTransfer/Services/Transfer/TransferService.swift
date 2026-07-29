import Foundation

struct TransferProgress: Sendable, Equatable {
    let percent: Int
    let bytesTransferred: Int64
    let totalBytes: Int64?

    init(percent: Int, bytesTransferred: Int64 = 0, totalBytes: Int64? = nil) {
        self.percent = percent
        self.bytesTransferred = bytesTransferred
        self.totalBytes = totalBytes
    }
}

enum TransferError: Error, Sendable, Equatable {
    case commandFailed(exitCode: Int32, standardError: String)
}

protocol TransferServiceProtocol: Sendable {
    func push(localURL: URL, remotePath: String, on serial: String) -> AsyncThrowingStream<TransferProgress, Error>
    func pull(remotePath: String, localURL: URL, on serial: String, expectedSize: Int64?) -> AsyncThrowingStream<TransferProgress, Error>
}

extension TransferServiceProtocol {
    /// Convenience for callers (Quick Look preview, drag-out) that don't know
    /// the remote file's size upfront and just want the bytes on disk when done.
    func pull(remotePath: String, localURL: URL, on serial: String) -> AsyncThrowingStream<TransferProgress, Error> {
        pull(remotePath: remotePath, localURL: localURL, on: serial, expectedSize: nil)
    }
}

final class TransferService: TransferServiceProtocol, Sendable {
    private let binaryURL: URL?
    private let runner: ADBProcessRunning

    init(binaryURL: URL? = ADBBinaryLocator.resolve(), runner: ADBProcessRunning = ADBProcessRunner()) {
        self.binaryURL = binaryURL
        self.runner = runner
    }

    func push(localURL: URL, remotePath: String, on serial: String) -> AsyncThrowingStream<TransferProgress, Error> {
        let totalBytes = (try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64) ?? nil
        let runner = runner
        return run(
            arguments: ["-s", serial, "push", "--", localURL.path, remotePath],
            totalBytes: totalBytes,
            pollInterval: .milliseconds(400),
            probeBytesTransferred: {
                let quotedPath = ShellQuoting.quote(remotePath)
                guard let result = try? await runner.run(arguments: ["-s", serial, "shell", "stat -c%s -- \(quotedPath)"]),
                      result.exitCode == 0,
                      let value = Int64(result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines))
                else { return nil }
                return value
            }
        )
    }

    func pull(remotePath: String, localURL: URL, on serial: String, expectedSize: Int64?) -> AsyncThrowingStream<TransferProgress, Error> {
        run(
            arguments: ["-s", serial, "pull", "--", remotePath, localURL.path],
            totalBytes: expectedSize,
            pollInterval: .milliseconds(250),
            probeBytesTransferred: {
                (try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64) ?? nil
            }
        )
    }

    // adb's own "[ XX%]" progress output is written with \r, but only when
    // stdout is a tty. A Process pipe is never a tty, so in practice adb
    // suppresses it entirely and only emits one final summary line — verified
    // against the real bundled binary (a 300MB push produced zero incremental
    // stdout, just the closing "... 35.0 MB/s (314572800 bytes in 8.565s)").
    // Real incremental progress instead comes from polling how many bytes have
    // actually landed: a remote `stat` for push, the growing local file size
    // on disk for pull.
    private func run(
        arguments: [String],
        totalBytes: Int64?,
        pollInterval: Duration,
        probeBytesTransferred: @escaping @Sendable () async -> Int64?
    ) -> AsyncThrowingStream<TransferProgress, Error> {
        AsyncThrowingStream { continuation in
            guard let binaryURL else {
                continuation.finish(throwing: ADBProcessError.binaryNotFound)
                return
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
                continuation.finish(throwing: ADBProcessError.launchFailed(error.localizedDescription))
                return
            }

            let pollTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: pollInterval)
                    if Task.isCancelled { break }
                    guard let bytes = await probeBytesTransferred() else { continue }
                    continuation.yield(TransferProgress(
                        percent: Self.percent(bytes: bytes, total: totalBytes),
                        bytesTransferred: bytes,
                        totalBytes: totalBytes
                    ))
                }
            }

            // Drains stdout so the pipe never fills and blocks the process,
            // then waits for exit and reads stderr for the error path. Doing
            // this on one dedicated GCD thread (not the Swift concurrency
            // cooperative pool) avoids starving it on long-lived reads.
            DispatchQueue.global(qos: .utility).async {
                let stdoutHandle = stdoutPipe.fileHandleForReading
                while !stdoutHandle.availableData.isEmpty {}

                process.waitUntilExit()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                pollTask.cancel()

                if process.terminationStatus == 0 {
                    let finalBytes = totalBytes ?? 0
                    continuation.yield(TransferProgress(percent: 100, bytesTransferred: finalBytes, totalBytes: totalBytes))
                    continuation.finish()
                } else {
                    continuation.finish(throwing: TransferError.commandFailed(
                        exitCode: process.terminationStatus,
                        standardError: String(decoding: stderrData, as: UTF8.self)
                    ))
                }
            }

            continuation.onTermination = { _ in
                pollTask.cancel()
                process.terminate()
            }
        }
    }

    private static func percent(bytes: Int64, total: Int64?) -> Int {
        guard let total, total > 0 else { return 0 }
        return Int(min(100, max(0, (bytes * 100) / total)))
    }
}
