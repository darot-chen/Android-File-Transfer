import Foundation
import Testing
@testable import AndroidFileTransfer

@MainActor
@Suite
struct LibraryViewModelTests {
    private func makeFile(_ path: String, size: Int64 = 0, modifiedAt: Date? = nil) -> RemoteFile {
        RemoteFile(
            name: (path as NSString).lastPathComponent, path: path, isDirectory: false, isSymlink: false,
            symlinkTarget: nil, size: size, modifiedAt: modifiedAt, permissions: ""
        )
    }

    @Test
    func scanGroupsFilesByCategory() async {
        let files = [
            makeFile("/sdcard/DCIM/vacation.jpg"),
            makeFile("/sdcard/DCIM/clip.mp4"),
            makeFile("/sdcard/Music/song.mp3"),
            makeFile("/sdcard/Download/report.pdf"),
            makeFile("/sdcard/data.bin"), // unrecognized extension, should be dropped
        ]
        let fileSystemService = MockFileSystemService(scanResult: .success(files))
        let viewModel = LibraryViewModel(fileSystemService: fileSystemService, serial: "SERIAL")

        await viewModel.scan()

        #expect(viewModel.count(for: .images) == 1)
        #expect(viewModel.count(for: .videos) == 1)
        #expect(viewModel.count(for: .audio) == 1)
        #expect(viewModel.count(for: .documents) == 1)
        #expect(viewModel.count(for: .archives) == 0)
        #expect(viewModel.files(for: .images).map(\.name) == ["vacation.jpg"])
        #expect(viewModel.files(for: .images)[0].path == "/sdcard/DCIM/vacation.jpg")
    }

    @Test
    func scanCarriesRealSizeAndModifiedDate() async {
        let modifiedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let files = [makeFile("/sdcard/DCIM/vacation.jpg", size: 12345, modifiedAt: modifiedAt)]
        let fileSystemService = MockFileSystemService(scanResult: .success(files))
        let viewModel = LibraryViewModel(fileSystemService: fileSystemService, serial: "SERIAL")

        await viewModel.scan()

        #expect(viewModel.files(for: .images)[0].size == 12345)
        #expect(viewModel.files(for: .images)[0].modifiedAt == modifiedAt)
    }

    @Test
    func scanHidesDotfiles() async {
        let files = [
            makeFile("/sdcard/DCIM/vacation.jpg"),
            makeFile("/sdcard/DCIM/.thumbnails/cache.jpg"),
            makeFile("/sdcard/.nomedia"),
        ]
        let fileSystemService = MockFileSystemService(scanResult: .success(files))
        let viewModel = LibraryViewModel(fileSystemService: fileSystemService, serial: "SERIAL")

        await viewModel.scan()

        #expect(viewModel.files(for: .images).map(\.name) == ["vacation.jpg"])
    }

    @Test
    func scanSortsFilesWithinACategory() async {
        let files = [makeFile("/sdcard/z.jpg"), makeFile("/sdcard/a.jpg"), makeFile("/sdcard/m.jpg")]
        let fileSystemService = MockFileSystemService(scanResult: .success(files))
        let viewModel = LibraryViewModel(fileSystemService: fileSystemService, serial: "SERIAL")

        await viewModel.scan()

        #expect(viewModel.files(for: .images).map(\.name) == ["a.jpg", "m.jpg", "z.jpg"])
    }

    @Test
    func scanIfNeededOnlyScansOnce() async {
        let fileSystemService = MockFileSystemService(scanResult: .success([makeFile("/sdcard/a.jpg")]))
        let viewModel = LibraryViewModel(fileSystemService: fileSystemService, serial: "SERIAL")

        await viewModel.scanIfNeeded()
        await viewModel.scanIfNeeded()

        #expect(viewModel.count(for: .images) == 1)
        // A second scanIfNeeded() shouldn't re-scan; hasScanned gates it.
        #expect(viewModel.hasScanned)
    }

    @Test
    func explicitScanAlwaysRescans() async {
        let fileSystemService = MockFileSystemService(scanResult: .success([makeFile("/sdcard/a.jpg")]))
        let viewModel = LibraryViewModel(fileSystemService: fileSystemService, serial: "SERIAL")

        await viewModel.scan()
        await fileSystemService.setScanResult(.success([makeFile("/sdcard/a.jpg"), makeFile("/sdcard/b.jpg")]))
        await viewModel.scan()

        #expect(viewModel.count(for: .images) == 2)
    }

    @Test
    func scanSurfacesErrorMessage() async {
        struct SomeError: Error {}
        let fileSystemService = MockFileSystemService(scanResult: .failure(SomeError()))
        let viewModel = LibraryViewModel(fileSystemService: fileSystemService, serial: "SERIAL")

        await viewModel.scan()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.count(for: .images) == 0)
    }

    @Test
    func countForUnscannedCategoryIsZero() {
        let fileSystemService = MockFileSystemService(scanResult: .success([]))
        let viewModel = LibraryViewModel(fileSystemService: fileSystemService, serial: "SERIAL")

        #expect(viewModel.count(for: .apks) == 0)
        #expect(viewModel.files(for: .apks).isEmpty)
    }
}
