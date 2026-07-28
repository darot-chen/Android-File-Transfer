@testable import AndroidFileTransfer

final class MockTransferHistoryStore: TransferHistoryStoring, @unchecked Sendable {
    private var stored: [TransferItem]
    private(set) var saveCallCount = 0

    init(initial: [TransferItem] = []) {
        self.stored = initial
    }

    func load() -> [TransferItem] {
        stored
    }

    func save(_ items: [TransferItem]) {
        stored = items
        saveCallCount += 1
    }
}
