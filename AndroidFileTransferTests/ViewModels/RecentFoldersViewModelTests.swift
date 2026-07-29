import Foundation
import Testing
@testable import AndroidFileTransfer

@MainActor
@Suite
struct RecentFoldersViewModelTests {
    @Test
    func recordVisitInsertsMostRecentFirst() {
        let viewModel = RecentFoldersViewModel(store: MockRecentFoldersStore())

        viewModel.recordVisit(serial: "SERIAL", path: "/sdcard/DCIM", name: "DCIM")
        viewModel.recordVisit(serial: "SERIAL", path: "/sdcard/Download", name: "Download")

        #expect(viewModel.recentFolders.map(\.name) == ["Download", "DCIM"])
    }

    @Test
    func revisitingAFolderMovesItToFrontWithoutDuplicating() {
        let viewModel = RecentFoldersViewModel(store: MockRecentFoldersStore())

        viewModel.recordVisit(serial: "SERIAL", path: "/sdcard/DCIM", name: "DCIM")
        viewModel.recordVisit(serial: "SERIAL", path: "/sdcard/Download", name: "Download")
        viewModel.recordVisit(serial: "SERIAL", path: "/sdcard/DCIM", name: "DCIM")

        #expect(viewModel.recentFolders.map(\.name) == ["DCIM", "Download"])
    }

    @Test
    func sameNameDifferentSerialAreDistinctEntries() {
        let viewModel = RecentFoldersViewModel(store: MockRecentFoldersStore())

        viewModel.recordVisit(serial: "SERIAL-A", path: "/sdcard/DCIM", name: "DCIM")
        viewModel.recordVisit(serial: "SERIAL-B", path: "/sdcard/DCIM", name: "DCIM")

        #expect(viewModel.recentFolders.count == 2)
    }

    @Test
    func exceedingLimitDropsOldestEntries() {
        let viewModel = RecentFoldersViewModel(store: MockRecentFoldersStore(), limit: 3)

        for index in 0..<5 {
            viewModel.recordVisit(serial: "SERIAL", path: "/sdcard/folder\(index)", name: "folder\(index)")
        }

        #expect(viewModel.recentFolders.count == 3)
        #expect(viewModel.recentFolders.map(\.name) == ["folder4", "folder3", "folder2"])
    }

    @Test
    func removeDeletesOnlyTheGivenEntry() {
        let viewModel = RecentFoldersViewModel(store: MockRecentFoldersStore())
        viewModel.recordVisit(serial: "SERIAL", path: "/sdcard/DCIM", name: "DCIM")
        viewModel.recordVisit(serial: "SERIAL", path: "/sdcard/Download", name: "Download")

        viewModel.remove(viewModel.recentFolders[0])

        #expect(viewModel.recentFolders.map(\.name) == ["DCIM"])
    }

    @Test
    func clearRemovesEverything() {
        let viewModel = RecentFoldersViewModel(store: MockRecentFoldersStore())
        viewModel.recordVisit(serial: "SERIAL", path: "/sdcard/DCIM", name: "DCIM")

        viewModel.clear()

        #expect(viewModel.recentFolders.isEmpty)
    }

    @Test
    func loadsPersistedFoldersOnInit() {
        let existing = [RecentFolder(id: UUID(), serial: "SERIAL", path: "/sdcard/DCIM", name: "DCIM", visitedAt: Date())]
        let viewModel = RecentFoldersViewModel(store: MockRecentFoldersStore(initial: existing))

        #expect(viewModel.recentFolders == existing)
    }
}
