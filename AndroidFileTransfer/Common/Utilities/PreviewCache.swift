import Foundation

enum PreviewCache {
    static let directory: URL = {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("AndroidFileTransferPreview", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func clear() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static func localURL(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }
}
