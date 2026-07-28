@testable import AndroidFileTransfer

final class MockFavoritesStore: FavoritesStoring, @unchecked Sendable {
    private var stored: [Favorite]
    private(set) var saveCallCount = 0

    init(initial: [Favorite] = []) {
        self.stored = initial
    }

    func load() -> [Favorite] {
        stored
    }

    func save(_ favorites: [Favorite]) {
        stored = favorites
        saveCallCount += 1
    }
}
