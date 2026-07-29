import Foundation
import Observation

@MainActor
@Observable
final class RecentFoldersViewModel {
    private(set) var recentFolders: [RecentFolder] = []
    private let store: RecentFoldersStoring
    private let limit: Int

    init(store: RecentFoldersStoring, limit: Int = 15) {
        self.store = store
        self.limit = limit
        self.recentFolders = store.load()
    }

    func recordVisit(serial: String, path: String, name: String) {
        recentFolders.removeAll { $0.serial == serial && $0.path == path }
        recentFolders.insert(RecentFolder(id: UUID(), serial: serial, path: path, name: name, visitedAt: Date()), at: 0)
        if recentFolders.count > limit {
            recentFolders.removeLast(recentFolders.count - limit)
        }
        store.save(recentFolders)
    }

    func remove(_ recentFolder: RecentFolder) {
        recentFolders.removeAll { $0.id == recentFolder.id }
        store.save(recentFolders)
    }

    func clear() {
        recentFolders.removeAll()
        store.save(recentFolders)
    }
}
