@testable import AndroidFileTransfer

struct MockADBDeviceStreaming: ADBDeviceStreaming {
    let snapshots: [String]
    let failure: Error?

    init(snapshots: [String], failure: Error? = nil) {
        self.snapshots = snapshots
        self.failure = failure
    }

    func deviceListSnapshots() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for snapshot in snapshots {
                continuation.yield(snapshot)
            }
            if let failure {
                continuation.finish(throwing: failure)
            } else {
                continuation.finish()
            }
        }
    }
}
