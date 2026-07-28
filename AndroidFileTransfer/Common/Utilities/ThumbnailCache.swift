import Foundation

enum ThumbnailCache {
    static let directory: URL = {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("AndroidFileTransferThumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func clear() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Keyed by the full remote path (not just filename) so files with the
    /// same name in different folders don't collide.
    static func localURL(for remotePath: String) -> URL {
        let safeName = remotePath.replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent(safeName)
    }
}
