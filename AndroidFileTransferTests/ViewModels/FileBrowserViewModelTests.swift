import Foundation
import Testing
@testable import AndroidFileTransfer

@MainActor
@Suite
struct FileBrowserViewModelTests {
    private func makeFile(_ name: String, isDirectory: Bool = false, parent: String = "/sdcard") -> RemoteFile {
        RemoteFile(
            name: name,
            path: "\(parent)/\(name)",
            isDirectory: isDirectory,
            isSymlink: false,
            symlinkTarget: nil,
            size: 0,
            modifiedAt: nil,
            permissions: isDirectory ? "drwxrwx--x" : "-rw-rw----"
        )
    }

    private func makeViewModel(
        fileSystemService: FileSystemServiceProtocol = MockFileSystemService(listingResult: .success([])),
        transferService: TransferServiceProtocol = MockTransferService(),
        transferQueue: TransferQueueViewModel? = nil,
        favorites: FavoritesViewModel? = nil,
        recentFolders: RecentFoldersViewModel? = nil,
        serial: String = "SERIAL",
        initialPath: String = "/sdcard"
    ) -> FileBrowserViewModel {
        let ephemeralDefaults = UserDefaults(suiteName: "FileBrowserViewModelTests-\(UUID().uuidString)")!
        return FileBrowserViewModel(
            fileSystemService: fileSystemService,
            transferService: transferService,
            transferQueue: transferQueue ?? TransferQueueViewModel(
                transferService: transferService,
                historyStore: MockTransferHistoryStore()
            ),
            favorites: favorites ?? FavoritesViewModel(store: MockFavoritesStore()),
            recentFolders: recentFolders ?? RecentFoldersViewModel(store: MockRecentFoldersStore()),
            settings: SettingsViewModel(defaults: ephemeralDefaults),
            logStore: LogStore(),
            serial: serial,
            initialPath: initialPath
        )
    }

    @Test
    func loadSortsDirectoriesBeforeFilesAlphabetically() async {
        let files = [makeFile("zebra.txt"), makeFile("Apps", isDirectory: true), makeFile("apple.txt")]
        let viewModel = makeViewModel(fileSystemService: MockFileSystemService(listingResult: .success(files)))

        await viewModel.load()

        #expect(viewModel.entries.map(\.name) == ["Apps", "apple.txt", "zebra.txt"])
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func loadHidesDotfilesAndDotDirectories() async {
        let files = [
            makeFile("notes.txt"),
            makeFile(".nomedia"),
            makeFile(".thumbnails", isDirectory: true),
            makeFile("Pictures", isDirectory: true),
        ]
        let viewModel = makeViewModel(fileSystemService: MockFileSystemService(listingResult: .success(files)))

        await viewModel.load()

        #expect(viewModel.entries.map(\.name) == ["Pictures", "notes.txt"])
    }

    @Test
    func loadRecordsAVisitToRecentFolders() async {
        let recentFolders = RecentFoldersViewModel(store: MockRecentFoldersStore())
        let viewModel = makeViewModel(recentFolders: recentFolders, initialPath: "/sdcard/DCIM")

        await viewModel.load()

        #expect(recentFolders.recentFolders.map(\.path) == ["/sdcard/DCIM"])
        #expect(recentFolders.recentFolders[0].serial == "SERIAL")
    }

    @Test
    func loadSurfacesErrorMessage() async {
        struct SomeError: Error {}
        let viewModel = makeViewModel(fileSystemService: MockFileSystemService(listingResult: .failure(SomeError())))

        await viewModel.load()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.entries.isEmpty)
    }

    @Test
    func navigateIntoDirectoryUpdatesCurrentPath() async {
        let viewModel = makeViewModel()

        await viewModel.navigate(to: makeFile("Download", isDirectory: true))

        #expect(viewModel.currentPath == "/sdcard/Download")
    }

    @Test
    func navigateIntoRegularFileDoesNothing() async {
        let viewModel = makeViewModel()

        await viewModel.navigate(to: makeFile("notes.txt"))

        #expect(viewModel.currentPath == "/sdcard")
    }

    @Test
    func navigateUpTrimsLastPathComponent() async {
        let viewModel = makeViewModel(initialPath: "/sdcard/Download")

        await viewModel.navigateUp()

        #expect(viewModel.currentPath == "/sdcard")
    }

    @Test
    func breadcrumbsHandleDeeplyNestedPaths() {
        let deepPath = "/sdcard/" + (0..<50).map { "folder\($0)" }.joined(separator: "/")
        let viewModel = makeViewModel(initialPath: deepPath)

        let breadcrumbs = viewModel.breadcrumbs

        #expect(breadcrumbs.count == 52) // root + "sdcard" + 50 folders
        #expect(breadcrumbs.first?.path == "/")
        #expect(breadcrumbs.last?.path == deepPath)
    }

    @Test
    func deleteCallsServiceAndReloads() async {
        let service = MockFileSystemService(listingResult: .success([]))
        let viewModel = makeViewModel(fileSystemService: service)

        await viewModel.delete(makeFile("old.txt"))

        let calls = await service.deleteCalls
        #expect(calls == [DeleteCall(path: "/sdcard/old.txt", serial: "SERIAL")])
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func deleteSurfacesErrorWithoutCrashing() async {
        struct SomeError: Error {}
        let service = MockFileSystemService(listingResult: .success([]))
        await service.setDeleteError(SomeError())
        let viewModel = makeViewModel(fileSystemService: service)

        await viewModel.delete(makeFile("old.txt"))

        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func renameBuildsNewPathFromCurrentFolder() async {
        let service = MockFileSystemService(listingResult: .success([]))
        let viewModel = makeViewModel(fileSystemService: service)

        await viewModel.rename(makeFile("old.txt"), to: "new.txt")

        let calls = await service.renameCalls
        #expect(calls == [RenameCall(from: "/sdcard/old.txt", to: "/sdcard/new.txt", serial: "SERIAL")])
    }

    @Test
    func renameToSameNameIsANoOp() async {
        let service = MockFileSystemService(listingResult: .success([]))
        let viewModel = makeViewModel(fileSystemService: service)

        await viewModel.rename(makeFile("old.txt"), to: "old.txt")

        let calls = await service.renameCalls
        #expect(calls.isEmpty)
    }

    @Test
    func createFolderBuildsPathFromCurrentFolder() async {
        let service = MockFileSystemService(listingResult: .success([]))
        let viewModel = makeViewModel(fileSystemService: service)

        await viewModel.createFolder(named: "NewFolder")

        let calls = await service.createFolderCalls
        #expect(calls == [CreateFolderCall(path: "/sdcard/NewFolder", serial: "SERIAL")])
    }

    @Test
    func downloadEnqueuesIntoTheSharedTransferQueue() {
        let transferQueue = TransferQueueViewModel(transferService: MockTransferService(), historyStore: MockTransferHistoryStore())
        let viewModel = makeViewModel(transferQueue: transferQueue)

        viewModel.download(makeFile("notes.txt"), to: URL(fileURLWithPath: "/tmp/notes.txt"))

        #expect(transferQueue.items.count == 1)
        #expect(transferQueue.items[0].direction == .download)
        #expect(transferQueue.items[0].remotePath == "/sdcard/notes.txt")
    }

    @Test
    func uploadEnqueuesWithRemotePathInCurrentFolder() {
        let transferQueue = TransferQueueViewModel(transferService: MockTransferService(), historyStore: MockTransferHistoryStore())
        let viewModel = makeViewModel(transferQueue: transferQueue)

        viewModel.upload(from: URL(fileURLWithPath: "/tmp/photo.jpg"))

        #expect(transferQueue.items.count == 1)
        #expect(transferQueue.items[0].direction == .upload)
        #expect(transferQueue.items[0].remotePath == "/sdcard/photo.jpg")
    }

    @Test
    func transferableForDragOutCarriesTheRightFileAndSerial() {
        let viewModel = makeViewModel(serial: "R58N70ABCDE")
        let file = makeFile("photo.jpg")

        let transferable = viewModel.transferable(for: file)

        #expect(transferable.remoteFile == file)
        #expect(transferable.serial == "R58N70ABCDE")
    }

    @Test
    func previewPullsToPreviewCacheAndReturnsItsURL() async {
        let transferService = MockTransferService(pullProgress: [TransferProgress(percent: 100)])
        let viewModel = makeViewModel(transferService: transferService)
        let file = makeFile("photo.jpg")

        let url = await viewModel.preview(file)

        #expect(url == PreviewCache.localURL(for: "photo.jpg"))
        let calls = await transferService.pullCalls
        #expect(calls == [PullCall(remotePath: "/sdcard/photo.jpg", localURL: PreviewCache.localURL(for: "photo.jpg"), serial: "SERIAL")])
    }

    @Test
    func previewOfDirectoryReturnsNil() async {
        let viewModel = makeViewModel()

        let url = await viewModel.preview(makeFile("Download", isDirectory: true))

        #expect(url == nil)
    }

    @Test
    func toggleFavoriteAddsThenRemovesCurrentFolder() {
        let favorites = FavoritesViewModel(store: MockFavoritesStore())
        let viewModel = makeViewModel(favorites: favorites, serial: "SERIAL", initialPath: "/sdcard/DCIM")

        #expect(viewModel.isCurrentFolderFavorite == false)

        viewModel.toggleFavoriteCurrentFolder()
        #expect(viewModel.isCurrentFolderFavorite == true)
        #expect(favorites.favorites.count == 1)

        viewModel.toggleFavoriteCurrentFolder()
        #expect(viewModel.isCurrentFolderFavorite == false)
        #expect(favorites.favorites.isEmpty)
    }

    @Test
    func recursiveSearchPopulatesResults() async throws {
        let fileSystemService = MockFileSystemService(searchResult: .success(["/sdcard/DCIM/a.jpg", "/sdcard/DCIM/b.jpg"]))
        let viewModel = makeViewModel(fileSystemService: fileSystemService)

        viewModel.performRecursiveSearch(query: "jpg")
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.searchResults == ["/sdcard/DCIM/a.jpg", "/sdcard/DCIM/b.jpg"])
        #expect(viewModel.isSearching == false)
    }

    @Test
    func recursiveSearchHidesDotfiles() async throws {
        let fileSystemService = MockFileSystemService(searchResult: .success([
            "/sdcard/DCIM/a.jpg", "/sdcard/DCIM/.thumbnails/cache.jpg",
        ]))
        let viewModel = makeViewModel(fileSystemService: fileSystemService)

        viewModel.performRecursiveSearch(query: "jpg")
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.searchResults == ["/sdcard/DCIM/a.jpg"])
    }

    @Test
    func emptyQueryClearsResultsWithoutSearching() {
        let viewModel = makeViewModel()

        viewModel.performRecursiveSearch(query: "")

        #expect(viewModel.searchResults.isEmpty)
        #expect(viewModel.isSearching == false)
    }

    @Test
    func navigateToSearchResultGoesToParentFolder() async {
        let viewModel = makeViewModel()

        await viewModel.navigateToSearchResult("/sdcard/DCIM/photo.jpg")

        #expect(viewModel.currentPath == "/sdcard/DCIM")
    }
}
