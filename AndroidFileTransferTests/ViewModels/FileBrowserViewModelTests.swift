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
        serial: String = "SERIAL",
        initialPath: String = "/sdcard"
    ) -> FileBrowserViewModel {
        FileBrowserViewModel(
            fileSystemService: fileSystemService,
            transferService: transferService,
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
    func downloadCallsPullWithChosenDestinationAndClearsProgressWhenDone() async throws {
        let transferService = MockTransferService(pullProgress: [TransferProgress(percent: 50), TransferProgress(percent: 100)])
        let viewModel = makeViewModel(transferService: transferService)
        let destination = URL(fileURLWithPath: "/tmp/notes.txt")

        viewModel.download(makeFile("notes.txt"), to: destination)
        try await Task.sleep(for: .milliseconds(50))

        let calls = await transferService.pullCalls
        #expect(calls == [PullCall(remotePath: "/sdcard/notes.txt", localURL: destination, serial: "SERIAL")])
        #expect(viewModel.activeTransfer == nil)
        #expect(viewModel.transferError == nil)
    }

    @Test
    func uploadCallsPushWithRemotePathInCurrentFolderAndReloads() async throws {
        let fileSystemService = MockFileSystemService(listingResult: .success([]))
        let transferService = MockTransferService(pushProgress: [TransferProgress(percent: 100)])
        let viewModel = makeViewModel(fileSystemService: fileSystemService, transferService: transferService)
        let localURL = URL(fileURLWithPath: "/tmp/photo.jpg")

        viewModel.upload(from: localURL)
        try await Task.sleep(for: .milliseconds(50))

        let calls = await transferService.pushCalls
        #expect(calls == [PushCall(localURL: localURL, remotePath: "/sdcard/photo.jpg", serial: "SERIAL")])
        #expect(viewModel.activeTransfer == nil)
    }

    @Test
    func uploadSurfacesTransferFailure() async throws {
        struct SomeError: Error {}
        let transferService = MockTransferService(pushProgress: [], pushFailure: SomeError())
        let viewModel = makeViewModel(transferService: transferService)

        viewModel.upload(from: URL(fileURLWithPath: "/tmp/photo.jpg"))
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.transferError != nil)
        #expect(viewModel.activeTransfer == nil)
    }
}
