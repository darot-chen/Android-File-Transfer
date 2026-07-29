import Foundation

protocol RecentFoldersStoring: Sendable {
    func load() -> [RecentFolder]
    func save(_ recentFolders: [RecentFolder])
}

struct RecentFoldersStore: RecentFoldersStoring {
    private let fileURL: URL

    init(fileURL: URL = RecentFoldersStore.defaultFileURL()) {
        self.fileURL = fileURL
    }

    static func defaultFileURL() -> URL {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AndroidFileTransfer", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("recent-folders.json")
    }

    func load() -> [RecentFolder] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([RecentFolder].self, from: data)) ?? []
    }

    func save(_ recentFolders: [RecentFolder]) {
        guard let data = try? JSONEncoder().encode(recentFolders) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
