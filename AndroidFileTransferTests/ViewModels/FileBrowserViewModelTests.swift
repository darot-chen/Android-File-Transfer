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

    @Test
    func loadSortsDirectoriesBeforeFilesAlphabetically() async {
        let files = [makeFile("zebra.txt"), makeFile("Apps", isDirectory: true), makeFile("apple.txt")]
        let service = MockFileSystemService(listingResult: .success(files))
        let viewModel = FileBrowserViewModel(fileSystemService: service, serial: "SERIAL")

        await viewModel.load()

        #expect(viewModel.entries.map(\.name) == ["Apps", "apple.txt", "zebra.txt"])
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func loadSurfacesErrorMessage() async {
        struct SomeError: Error {}
        let service = MockFileSystemService(listingResult: .failure(SomeError()))
        let viewModel = FileBrowserViewModel(fileSystemService: service, serial: "SERIAL")

        await viewModel.load()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.entries.isEmpty)
    }

    @Test
    func navigateIntoDirectoryUpdatesCurrentPath() async {
        let service = MockFileSystemService(listingResult: .success([]))
        let viewModel = FileBrowserViewModel(fileSystemService: service, serial: "SERIAL", initialPath: "/sdcard")

        await viewModel.navigate(to: makeFile("Download", isDirectory: true))

        #expect(viewModel.currentPath == "/sdcard/Download")
    }

    @Test
    func navigateIntoRegularFileDoesNothing() async {
        let service = MockFileSystemService(listingResult: .success([]))
        let viewModel = FileBrowserViewModel(fileSystemService: service, serial: "SERIAL", initialPath: "/sdcard")

        await viewModel.navigate(to: makeFile("notes.txt"))

        #expect(viewModel.currentPath == "/sdcard")
    }

    @Test
    func navigateUpTrimsLastPathComponent() async {
        let service = MockFileSystemService(listingResult: .success([]))
        let viewModel = FileBrowserViewModel(fileSystemService: service, serial: "SERIAL", initialPath: "/sdcard/Download")

        await viewModel.navigateUp()

        #expect(viewModel.currentPath == "/sdcard")
    }

    @Test
    func deleteCallsServiceAndReloads() async {
        let service = MockFileSystemService(listingResult: .success([]))
        let viewModel = FileBrowserViewModel(fileSystemService: service, serial: "SERIAL", initialPath: "/sdcard")

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
        let viewModel = FileBrowserViewModel(fileSystemService: service, serial: "SERIAL", initialPath: "/sdcard")

        await viewModel.delete(makeFile("old.txt"))

        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func renameBuildsNewPathFromCurrentFolder() async {
        let service = MockFileSystemService(listingResult: .success([]))
        let viewModel = FileBrowserViewModel(fileSystemService: service, serial: "SERIAL", initialPath: "/sdcard")

        await viewModel.rename(makeFile("old.txt"), to: "new.txt")

        let calls = await service.renameCalls
        #expect(calls == [RenameCall(from: "/sdcard/old.txt", to: "/sdcard/new.txt", serial: "SERIAL")])
    }

    @Test
    func renameToSameNameIsANoOp() async {
        let service = MockFileSystemService(listingResult: .success([]))
        let viewModel = FileBrowserViewModel(fileSystemService: service, serial: "SERIAL", initialPath: "/sdcard")

        await viewModel.rename(makeFile("old.txt"), to: "old.txt")

        let calls = await service.renameCalls
        #expect(calls.isEmpty)
    }

    @Test
    func createFolderBuildsPathFromCurrentFolder() async {
        let service = MockFileSystemService(listingResult: .success([]))
        let viewModel = FileBrowserViewModel(fileSystemService: service, serial: "SERIAL", initialPath: "/sdcard")

        await viewModel.createFolder(named: "NewFolder")

        let calls = await service.createFolderCalls
        #expect(calls == [CreateFolderCall(path: "/sdcard/NewFolder", serial: "SERIAL")])
    }
}
