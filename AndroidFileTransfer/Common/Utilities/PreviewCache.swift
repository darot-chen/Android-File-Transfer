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

    /// Keyed by the full remote path (not just filename) so files with the
    /// same name in different folders don't collide, and so a file already
    /// previewed this session can be recognized and shown instantly instead
    /// of re-pulling it. Nested under a per-path subdirectory (rather than
    /// flattening the path into the filename itself, like ThumbnailCache
    /// does) so the file Quick Look actually opens keeps its real name —
    /// that's what shows in the preview panel's title.
    static func localURL(for remotePath: String) -> URL {
        let safeDirName = remotePath.replacingOccurrences(of: "/", with: "_")
        let fileDirectory = directory.appendingPathComponent(safeDirName, isDirectory: true)
        try? FileManager.default.createDirectory(at: fileDirectory, withIntermediateDirectories: true)
        return fileDirectory.appendingPathComponent((remotePath as NSString).lastPathComponent)
    }
}
