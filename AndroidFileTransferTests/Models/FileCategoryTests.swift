import Testing
@testable import AndroidFileTransfer

@Suite
struct FileCategoryTests {
    @Test(arguments: [
        ("photo.jpg", FileCategory.images),
        ("photo.JPEG", .images),
        ("shot.heic", .images),
        ("clip.mp4", .videos),
        ("movie.MOV", .videos),
        ("song.mp3", .audio),
        ("track.flac", .audio),
        ("report.pdf", .documents),
        ("notes.docx", .documents),
        ("archive.zip", .archives),
        ("backup.tar.gz", .archives),
        ("app.apk", .apks),
    ])
    func classifiesKnownExtensions(fileName: String, expected: FileCategory) {
        #expect(FileCategory.category(forFileName: fileName) == expected)
    }

    @Test
    func unknownExtensionReturnsNil() {
        #expect(FileCategory.category(forFileName: "data.bin") == nil)
    }

    @Test
    func noExtensionReturnsNil() {
        #expect(FileCategory.category(forFileName: "README") == nil)
    }

    @Test
    func categoriesHaveDistinctDisplayNamesAndIcons() {
        let names = Set(FileCategory.allCases.map(\.displayName))
        let icons = Set(FileCategory.allCases.map(\.systemImage))
        #expect(names.count == FileCategory.allCases.count)
        #expect(icons.count == FileCategory.allCases.count)
    }
}
