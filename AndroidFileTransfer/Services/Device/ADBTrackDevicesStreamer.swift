import Foundation

/// Speaks the raw adb host protocol framing used by `adb track-devices -l`:
/// each update is a 4-byte ASCII hex length prefix followed by that many
/// bytes of payload (a full device-list snapshot, one device per line).
final class ADBTrackDevicesStreamer: ADBDeviceStreaming, Sendable {
    private let binaryURL: URL?

    init(binaryURL: URL? = ADBBinaryLocator.resolve()) {
        self.binaryURL = binaryURL
    }

    func deviceListSnapshots() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            guard let binaryURL else {
                continuation.finish(throwing: ADBProcessError.binaryNotFound)
                return
            }

            let process = Process()
            process.executableURL = binaryURL
            process.arguments = ["track-devices", "-l"]

            let stdoutPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = Pipe()

            do {
                try process.run()
            } catch {
                continuation.finish(throwing: ADBProcessError.launchFailed(error.localizedDescription))
                return
            }
            ChildProcessRegistry.shared.register(process)

            // Reads on a dedicated GCD thread rather than FileHandle.bytes: this
            // stream runs indefinitely (adb never closes it on its own), and a
            // blocking read via the cooperative thread pool would starve it for
            // the app's entire lifetime, stalling unrelated async work.
            let handle = stdoutPipe.fileHandleForReading
            DispatchQueue.global(qos: .utility).async {
                var buffer = Data()
                while true {
                    let chunk = handle.availableData
                    if chunk.isEmpty {
                        ChildProcessRegistry.shared.unregister(process)
                        continuation.finish()
                        return
                    }
                    buffer.append(chunk)
                    while let frame = Self.extractFrame(from: &buffer) {
                        continuation.yield(frame)
                    }
                }
            }

            continuation.onTermination = { _ in
                process.terminate()
            }
        }
    }

    private static func extractFrame(from buffer: inout Data) -> String? {
        guard buffer.count >= 4 else { return nil }

        let lengthBytes = buffer.prefix(4)
        guard
            let lengthString = String(bytes: lengthBytes, encoding: .ascii),
            let length = Int(lengthString, radix: 16)
        else {
            // Unexpected byte in the length prefix; drop it and try to resynchronize.
            buffer.removeFirst()
            return nil
        }

        guard buffer.count >= 4 + length else { return nil }

        let payloadStart = buffer.index(buffer.startIndex, offsetBy: 4)
        let payloadEnd = buffer.index(payloadStart, offsetBy: length)
        let payload = String(bytes: buffer[payloadStart..<payloadEnd], encoding: .utf8) ?? ""
        buffer.removeSubrange(buffer.startIndex..<payloadEnd)
        return payload
    }
}
