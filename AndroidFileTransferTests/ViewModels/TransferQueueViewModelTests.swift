import Foundation
import Testing
@testable import AndroidFileTransfer

/// Yields two progress samples with a real delay between them so tests can
/// observe TransferQueueViewModel's mid-flight byte/speed tracking, which
/// MockTransferService's queue-and-drain-immediately design can't exercise.
private struct SlowProgressTransferService: TransferServiceProtocol {
    func push(localURL: URL, remotePath: String, on serial: String) -> AsyncThrowingStream<TransferProgress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                continuation.yield(TransferProgress(percent: 25, bytesTransferred: 250, totalBytes: 1000))
                try? await Task.sleep(for: .milliseconds(80))
                continuation.yield(TransferProgress(percent: 75, bytesTransferred: 750, totalBytes: 1000))
                try? await Task.sleep(for: .milliseconds(80))
                continuation.yield(TransferProgress(percent: 100, bytesTransferred: 1000, totalBytes: 1000))
                continuation.finish()
            }
        }
    }

    func pull(remotePath: String, localURL: URL, on serial: String, expectedSize: Int64?) -> AsyncThrowingStream<TransferProgress, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

@MainActor
@Suite
struct TransferQueueViewModelTests {
    @Test
    func enqueueUploadAddsQueuedItem() {
        let viewModel = TransferQueueViewModel(transferService: MockTransferService(), historyStore: MockTransferHistoryStore())

        viewModel.enqueueUpload(localURL: URL(fileURLWithPath: "/tmp/a.txt"), remotePath: "/sdcard/a.txt", serial: "SERIAL")

        #expect(viewModel.items.count == 1)
        #expect(viewModel.items[0].direction == .upload)
    }

    @Test
    func queuedItemsRunToCompletionAndPersist() async throws {
        let transferService = MockTransferService(pushProgress: [TransferProgress(percent: 50), TransferProgress(percent: 100)])
        let historyStore = MockTransferHistoryStore()
        let viewModel = TransferQueueViewModel(transferService: transferService, historyStore: historyStore)

        viewModel.enqueueUpload(localURL: URL(fileURLWithPath: "/tmp/a.txt"), remotePath: "/sdcard/a.txt", serial: "SERIAL")
        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.items[0].status == .completed)
        #expect(historyStore.saveCallCount > 0)
        #expect(historyStore.load()[0].status == .completed)
    }

    @Test
    func onlyMaxConcurrentItemsRunAtOnce() async throws {
        let transferService = MockTransferService(pushProgress: [TransferProgress(percent: 100)], delay: .milliseconds(200))
        let viewModel = TransferQueueViewModel(transferService: transferService, historyStore: MockTransferHistoryStore(), maxConcurrent: 2)

        for index in 0..<5 {
            viewModel.enqueueUpload(localURL: URL(fileURLWithPath: "/tmp/\(index).txt"), remotePath: "/sdcard/\(index).txt", serial: "SERIAL")
        }
        try await Task.sleep(for: .milliseconds(50))

        let runningCount = viewModel.items.filter {
            if case .inProgress = $0.status { return true }
            return false
        }.count
        let queuedCount = viewModel.items.filter {
            if case .queued = $0.status { return true }
            return false
        }.count

        #expect(runningCount == 2)
        #expect(queuedCount == 3)
    }

    @Test
    func updateMaxConcurrentStartsMoreQueuedItemsImmediately() async throws {
        let transferService = MockTransferService(pushProgress: [TransferProgress(percent: 100)], delay: .milliseconds(200))
        let viewModel = TransferQueueViewModel(transferService: transferService, historyStore: MockTransferHistoryStore(), maxConcurrent: 1)

        for index in 0..<3 {
            viewModel.enqueueUpload(localURL: URL(fileURLWithPath: "/tmp/\(index).txt"), remotePath: "/sdcard/\(index).txt", serial: "SERIAL")
        }
        try await Task.sleep(for: .milliseconds(50))

        func runningCount() -> Int {
            viewModel.items.filter {
                if case .inProgress = $0.status { return true }
                return false
            }.count
        }

        #expect(runningCount() == 1)

        viewModel.updateMaxConcurrent(3)
        try await Task.sleep(for: .milliseconds(50))

        #expect(runningCount() == 3)
    }

    @Test
    func failedItemCanBeRetried() async throws {
        struct SomeError: Error {}
        let transferService = MockTransferService(pushProgress: [], pushFailure: SomeError())
        let viewModel = TransferQueueViewModel(transferService: transferService, historyStore: MockTransferHistoryStore())

        viewModel.enqueueUpload(localURL: URL(fileURLWithPath: "/tmp/a.txt"), remotePath: "/sdcard/a.txt", serial: "SERIAL")
        try await Task.sleep(for: .milliseconds(50))

        guard case .failed = viewModel.items[0].status else {
            Issue.record("expected item to have failed")
            return
        }

        viewModel.retry(viewModel.items[0])
        try await Task.sleep(for: .milliseconds(50))

        guard case .failed = viewModel.items[0].status else {
            Issue.record("expected retried item to fail again with the same mock")
            return
        }

        let calls = await transferService.pushCalls
        #expect(calls.count == 2)
    }

    @Test
    func clearCompletedRemovesOnlyFinishedItems() async throws {
        let transferService = MockTransferService(pushProgress: [TransferProgress(percent: 100)])
        let viewModel = TransferQueueViewModel(transferService: transferService, historyStore: MockTransferHistoryStore())

        viewModel.enqueueUpload(localURL: URL(fileURLWithPath: "/tmp/a.txt"), remotePath: "/sdcard/a.txt", serial: "SERIAL")
        try await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.items[0].status == .completed)

        viewModel.clearCompleted()

        #expect(viewModel.items.isEmpty)
    }

    @Test
    func inProgressTransferExposesByteMetricsAndSpeed() async throws {
        let viewModel = TransferQueueViewModel(transferService: SlowProgressTransferService(), historyStore: MockTransferHistoryStore())

        viewModel.enqueueUpload(localURL: URL(fileURLWithPath: "/tmp/a.txt"), remotePath: "/sdcard/a.txt", serial: "SERIAL")
        try await Task.sleep(for: .milliseconds(120))

        let itemID = viewModel.items[0].id
        let metrics = viewModel.transferMetrics[itemID]
        #expect(metrics?.bytesTransferred == 750)
        #expect(metrics?.totalBytes == 1000)
        #expect(metrics?.bytesPerSecond != nil)

        try await Task.sleep(for: .milliseconds(150))
        #expect(viewModel.items[0].status == .completed)
        // Metrics are cleared once the transfer finishes so a later retry starts fresh.
        #expect(viewModel.transferMetrics[itemID] == nil)
    }

    @Test
    func waitForCompletionResolvesOnceTheDownloadSucceeds() async throws {
        let transferService = MockTransferService(pullProgress: [TransferProgress(percent: 100)])
        let viewModel = TransferQueueViewModel(transferService: transferService, historyStore: MockTransferHistoryStore())

        let itemID = viewModel.enqueueDownload(remotePath: "/sdcard/a.jpg", localURL: URL(fileURLWithPath: "/tmp/a.jpg"), serial: "SERIAL")
        try await viewModel.waitForCompletion(of: itemID)

        #expect(viewModel.items.first { $0.id == itemID }?.status == .completed)
    }

    @Test
    func waitForCompletionThrowsWhenTheDownloadFails() async {
        struct SomeError: Error {}
        let transferService = MockTransferService(pullProgress: [], pullFailure: SomeError())
        let viewModel = TransferQueueViewModel(transferService: transferService, historyStore: MockTransferHistoryStore())

        let itemID = viewModel.enqueueDownload(remotePath: "/sdcard/a.jpg", localURL: URL(fileURLWithPath: "/tmp/a.jpg"), serial: "SERIAL")

        await #expect(throws: (any Error).self) {
            try await viewModel.waitForCompletion(of: itemID)
        }
    }

    @Test
    func waitForCompletionReturnsImmediatelyForAnAlreadyCompletedItem() async throws {
        let transferService = MockTransferService(pullProgress: [TransferProgress(percent: 100)])
        let viewModel = TransferQueueViewModel(transferService: transferService, historyStore: MockTransferHistoryStore())

        let itemID = viewModel.enqueueDownload(remotePath: "/sdcard/a.jpg", localURL: URL(fileURLWithPath: "/tmp/a.jpg"), serial: "SERIAL")
        try await viewModel.waitForCompletion(of: itemID)

        // Should resolve immediately from the already-terminal status rather
        // than hanging waiting for a task that no longer exists.
        try await viewModel.waitForCompletion(of: itemID)
    }

    @Test
    func interruptedInProgressItemsFromPriorRunLoadAsFailed() {
        let interrupted = TransferItem(
            id: UUID(), direction: .upload, serial: "SERIAL",
            localURL: URL(fileURLWithPath: "/tmp/a.txt"), remotePath: "/sdcard/a.txt",
            status: .inProgress(percent: 42), createdAt: Date()
        )
        let historyStore = MockTransferHistoryStore(initial: [interrupted])

        let viewModel = TransferQueueViewModel(transferService: MockTransferService(), historyStore: historyStore)

        guard case .failed = viewModel.items[0].status else {
            Issue.record("expected interrupted item to load as failed, got \(viewModel.items[0].status)")
            return
        }
    }
}
