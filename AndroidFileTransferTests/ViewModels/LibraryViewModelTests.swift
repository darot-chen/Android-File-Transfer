import Testing
@testable import AndroidFileTransfer

@MainActor
@Suite
struct LibraryViewModelTests {
    @Test
    func scanGroupsFilesByCategory() async {
        let paths = [
            "/sdcard/DCIM/vacation.jpg",
            "/sdcard/DCIM/clip.mp4",
            "/sdcard/Music/song.mp3",
            "/sdcard/Download/report.pdf",
            "/sdcard/data.bin", // unrecognized extension, should be dropped
        ]
        let fileSystemService = MockFileSystemService(scanResult: .success(paths))
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
    func scanHidesDotfiles() async {
        let paths = ["/sdcard/DCIM/vacation.jpg", "/sdcard/DCIM/.thumbnails/cache.jpg", "/sdcard/.nomedia"]
        let fileSystemService = MockFileSystemService(scanResult: .success(paths))
        let viewModel = LibraryViewModel(fileSystemService: fileSystemService, serial: "SERIAL")

        await viewModel.scan()

        #expect(viewModel.files(for: .images).map(\.name) == ["vacation.jpg"])
    }

    @Test
    func scanSortsFilesWithinACategory() async {
        let paths = ["/sdcard/z.jpg", "/sdcard/a.jpg", "/sdcard/m.jpg"]
        let fileSystemService = MockFileSystemService(scanResult: .success(paths))
        let viewModel = LibraryViewModel(fileSystemService: fileSystemService, serial: "SERIAL")

        await viewModel.scan()

        #expect(viewModel.files(for: .images).map(\.name) == ["a.jpg", "m.jpg", "z.jpg"])
    }

    @Test
    func scanIfNeededOnlyScansOnce() async {
        let fileSystemService = MockFileSystemService(scanResult: .success(["/sdcard/a.jpg"]))
        let viewModel = LibraryViewModel(fileSystemService: fileSystemService, serial: "SERIAL")

        await viewModel.scanIfNeeded()
        await viewModel.scanIfNeeded()

        #expect(viewModel.count(for: .images) == 1)
        // A second scanIfNeeded() shouldn't re-scan; hasScanned gates it.
        #expect(viewModel.hasScanned)
    }

    @Test
    func explicitScanAlwaysRescans() async {
        let fileSystemService = MockFileSystemService(scanResult: .success(["/sdcard/a.jpg"]))
        let viewModel = LibraryViewModel(fileSystemService: fileSystemService, serial: "SERIAL")

        await viewModel.scan()
        await fileSystemService.setScanResult(.success(["/sdcard/a.jpg", "/sdcard/b.jpg"]))
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
