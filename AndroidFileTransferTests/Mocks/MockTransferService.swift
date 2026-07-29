import Foundation
@testable import AndroidFileTransfer

struct PushCall: Sendable, Equatable {
    let localURL: URL
    let remotePath: String
    let serial: String
}

struct PullCall: Sendable, Equatable {
    let remotePath: String
    let localURL: URL
    let serial: String
}

actor MockTransferService: TransferServiceProtocol {
    private var pushProgress: [TransferProgress]
    private var pushFailure: Error?
    private var pullProgress: [TransferProgress]
    private var pullFailure: Error?
    private var delay: Duration

    private(set) var pushCalls: [PushCall] = []
    private(set) var pullCalls: [PullCall] = []

    init(
        pushProgress: [TransferProgress] = [TransferProgress(percent: 100)],
        pushFailure: Error? = nil,
        pullProgress: [TransferProgress] = [TransferProgress(percent: 100)],
        pullFailure: Error? = nil,
        delay: Duration = .zero
    ) {
        self.pushProgress = pushProgress
        self.pushFailure = pushFailure
        self.pullProgress = pullProgress
        self.pullFailure = pullFailure
        self.delay = delay
    }

    nonisolated func push(localURL: URL, remotePath: String, on serial: String) -> AsyncThrowingStream<TransferProgress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self.recordPush(localURL: localURL, remotePath: remotePath, serial: serial)
                let (progress, failure, delay) = await (self.pushProgress, self.pushFailure, self.delay)
                if delay > .zero { try? await Task.sleep(for: delay) }
                for update in progress {
                    continuation.yield(update)
                }
                if let failure {
                    continuation.finish(throwing: failure)
                } else {
                    continuation.finish()
                }
            }
        }
    }

    nonisolated func pull(remotePath: String, localURL: URL, on serial: String, expectedSize: Int64?) -> AsyncThrowingStream<TransferProgress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self.recordPull(remotePath: remotePath, localURL: localURL, serial: serial)
                let (progress, failure, delay) = await (self.pullProgress, self.pullFailure, self.delay)
                if delay > .zero { try? await Task.sleep(for: delay) }
                for update in progress {
                    continuation.yield(update)
                }
                if let failure {
                    continuation.finish(throwing: failure)
                } else {
                    continuation.finish()
                }
            }
        }
    }

    private func recordPush(localURL: URL, remotePath: String, serial: String) {
        pushCalls.append(PushCall(localURL: localURL, remotePath: remotePath, serial: serial))
    }

    private func recordPull(remotePath: String, localURL: URL, serial: String) {
        pullCalls.append(PullCall(remotePath: remotePath, localURL: localURL, serial: serial))
    }
}
