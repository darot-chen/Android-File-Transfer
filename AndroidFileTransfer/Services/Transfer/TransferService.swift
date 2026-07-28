import Foundation

struct TransferProgress: Sendable, Equatable {
    let percent: Int
}

enum TransferError: Error, Sendable, Equatable {
    case commandFailed(exitCode: Int32, standardError: String)
}

protocol TransferServiceProtocol: Sendable {
    func push(localURL: URL, remotePath: String, on serial: String) -> AsyncThrowingStream<TransferProgress, Error>
    func pull(remotePath: String, localURL: URL, on serial: String) -> AsyncThrowingStream<TransferProgress, Error>
}

final class TransferService: TransferServiceProtocol, Sendable {
    private let binaryURL: URL?

    init(binaryURL: URL? = Bundle.main.url(forResource: "adb", withExtension: nil)) {
        self.binaryURL = binaryURL
    }

    func push(localURL: URL, remotePath: String, on serial: String) -> AsyncThrowingStream<TransferProgress, Error> {
        run(arguments: ["-s", serial, "push", "--", localURL.path, remotePath])
    }

    func pull(remotePath: String, localURL: URL, on serial: String) -> AsyncThrowingStream<TransferProgress, Error> {
        run(arguments: ["-s", serial, "pull", "--", remotePath, localURL.path])
    }

    private func run(arguments: [String]) -> AsyncThrowingStream<TransferProgress, Error> {
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

            // Everything below runs sequentially on one dedicated GCD thread
            // (not the Swift concurrency cooperative pool, per the lesson from
            // ADBTrackDevicesStreamer): drain stdout progress until EOF, wait
            // for the process to fully exit, then drain stderr. Doing this in
            // one thread avoids a race between a termination handler firing
            // and stderr still being written.
            DispatchQueue.global(qos: .utility).async {
                var buffer = Data()
                let stdoutHandle = stdoutPipe.fileHandleForReading
                while true {
                    let chunk = stdoutHandle.availableData
                    if chunk.isEmpty { break }
                    buffer.append(chunk)
                    while let lineData = Self.extractLine(from: &buffer) {
                        if let line = String(data: lineData, encoding: .utf8), let percent = Self.parsePercent(line) {
                            continuation.yield(TransferProgress(percent: percent))
                        }
                    }
                }

                process.waitUntilExit()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                if process.terminationStatus == 0 {
                    continuation.yield(TransferProgress(percent: 100))
                    continuation.finish()
                } else {
                    continuation.finish(throwing: TransferError.commandFailed(
                        exitCode: process.terminationStatus,
                        standardError: String(decoding: stderrData, as: UTF8.self)
                    ))
                }
            }

            continuation.onTermination = { _ in
                process.terminate()
            }
        }
    }

    // adb push/pull update progress in place using \r, and emit a final
    // summary line terminated by \n.
    private static func extractLine(from buffer: inout Data) -> Data? {
        guard let separatorIndex = buffer.firstIndex(where: { $0 == 0x0D || $0 == 0x0A }) else {
            return nil
        }
        let line = buffer[buffer.startIndex..<separatorIndex]
        buffer.removeSubrange(buffer.startIndex...separatorIndex)
        return line
    }

    nonisolated(unsafe) private static let percentRegex = /\[\s*(\d+)%\]/

    private static func parsePercent(_ line: String) -> Int? {
        guard let match = line.firstMatch(of: percentRegex), let percent = Int(match.1) else { return nil }
        return percent
    }
}
