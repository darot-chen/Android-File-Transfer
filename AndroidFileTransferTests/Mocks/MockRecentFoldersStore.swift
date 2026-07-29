@testable import AndroidFileTransfer

final class MockRecentFoldersStore: RecentFoldersStoring, @unchecked Sendable {
    private var stored: [RecentFolder]
    private(set) var saveCallCount = 0

    init(initial: [RecentFolder] = []) {
        self.stored = initial
    }

    func load() -> [RecentFolder] {
        stored
    }

    func save(_ recentFolders: [RecentFolder]) {
        stored = recentFolders
        saveCallCount += 1
    }
}
