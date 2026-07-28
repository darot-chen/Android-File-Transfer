import Testing
@testable import AndroidFileTransfer

@Suite
struct RemoteFileTests {
    @Test
    func skipsTotalHeaderAndDotEntries() {
        let output = """
        total 48
        drwxrwx--x 6 root sdcard_rw 3488 2024-01-15 10:23 .
        drwxrwx--x 6 root sdcard_rw 3488 2024-01-15 10:23 ..
        """

        let files = RemoteFile.parseListing(output, parentPath: "/sdcard")

        #expect(files.isEmpty)
    }

    @Test
    func parsesRegularFile() {
        let line = "-rw-rw---- 1 u0_a123 sdcard_rw 1024 2024-01-15 10:20 notes.txt"

        let files = RemoteFile.parseListing(line, parentPath: "/sdcard")

        #expect(files.count == 1)
        let file = files[0]
        #expect(file.name == "notes.txt")
        #expect(file.path == "/sdcard/notes.txt")
        #expect(file.isDirectory == false)
        #expect(file.isSymlink == false)
        #expect(file.size == 1024)
        #expect(file.modifiedAt != nil)
    }

    @Test
    func parsesDirectory() {
        let line = "drwxrwx--x 2 u0_a123 sdcard_rw 3488 2024-01-15 09:00 Download"

        let files = RemoteFile.parseListing(line, parentPath: "/sdcard")

        #expect(files.count == 1)
        #expect(files[0].isDirectory == true)
        #expect(files[0].path == "/sdcard/Download")
    }

    @Test
    func parsesSymlinkWithTarget() {
        let line = "lrwxrwxrwx 1 root root 12 2024-01-15 08:00 link -> target/path"

        let files = RemoteFile.parseListing(line, parentPath: "/sdcard")

        #expect(files.count == 1)
        let file = files[0]
        #expect(file.isSymlink == true)
        #expect(file.name == "link")
        #expect(file.symlinkTarget == "target/path")
    }

    @Test
    func parsesFilenameContainingSpaces() {
        let line = "-rw-rw---- 1 u0_a123 sdcard_rw 2048 2024-01-15 10:20 My Vacation Photo.jpg"

        let files = RemoteFile.parseListing(line, parentPath: "/sdcard")

        #expect(files.count == 1)
        #expect(files[0].name == "My Vacation Photo.jpg")
    }

    @Test
    func keepsOtherDotfiles() {
        let line = "-rw-rw---- 1 u0_a123 sdcard_rw 12 2024-01-15 10:20 .nomedia"

        let files = RemoteFile.parseListing(line, parentPath: "/sdcard")

        #expect(files.count == 1)
        #expect(files[0].name == ".nomedia")
    }

    @Test
    func ignoresUnparsableLines() {
        let files = RemoteFile.parseListing("garbage output from a broken shell", parentPath: "/sdcard")

        #expect(files.isEmpty)
    }

    @Test
    func joinsPathsWithoutDoubleSlash() {
        let line = "-rw-rw---- 1 u0_a123 sdcard_rw 12 2024-01-15 10:20 file.txt"

        let files = RemoteFile.parseListing(line, parentPath: "/")

        #expect(files[0].path == "/file.txt")
    }

    // No physical device with a large directory is available to test against
    // in this environment; this exercises correctness and performance on a
    // synthetic listing of the size the roadmap calls out ("thousands of files").
    @Test
    func parsesThousandsOfEntriesCorrectlyAndQuickly() {
        let lineCount = 10_000
        var lines = ["total \(lineCount)"]
        for index in 0..<lineCount {
            lines.append("-rw-rw---- 1 u0_a123 sdcard_rw \(index) 2024-01-15 10:20 file\(index).txt")
        }
        let output = lines.joined(separator: "\n")

        let start = ContinuousClock.now
        let files = RemoteFile.parseListing(output, parentPath: "/sdcard")
        let elapsed = start.duration(to: .now)

        #expect(files.count == lineCount)
        #expect(files.first?.name == "file0.txt")
        #expect(files.last?.name == "file9999.txt")
        #expect(elapsed < .seconds(2))
    }

    @Test
    func parsesDeeplyNestedPathWithoutIssue() {
        let deepPath = "/sdcard/" + (0..<50).map { "folder\($0)" }.joined(separator: "/")
        let line = "-rw-rw---- 1 u0_a123 sdcard_rw 12 2024-01-15 10:20 file.txt"

        let files = RemoteFile.parseListing(line, parentPath: deepPath)

        #expect(files[0].path == "\(deepPath)/file.txt")
    }
}
