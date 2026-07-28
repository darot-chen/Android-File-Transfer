import Foundation
import Testing
@testable import AndroidFileTransfer

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
