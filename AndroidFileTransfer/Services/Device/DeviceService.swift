protocol DeviceServiceProtocol: Sendable {
    /// Yields the full, live-updating device list. New arrays are emitted
    /// whenever a device connects, disconnects, or changes state.
    func observeDevices() -> AsyncThrowingStream<[Device], Error>
}

struct DeviceService: DeviceServiceProtocol {
    private let streaming: ADBDeviceStreaming

    init(streaming: ADBDeviceStreaming) {
        self.streaming = streaming
    }

    func observeDevices() -> AsyncThrowingStream<[Device], Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await snapshot in streaming.deviceListSnapshots() {
                        continuation.yield(Device.parseSnapshot(snapshot))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
