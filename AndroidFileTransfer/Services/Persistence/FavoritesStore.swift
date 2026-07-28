import Foundation

protocol FavoritesStoring: Sendable {
    func load() -> [Favorite]
    func save(_ favorites: [Favorite])
}

struct FavoritesStore: FavoritesStoring {
    private let fileURL: URL

    init(fileURL: URL = FavoritesStore.defaultFileURL()) {
        self.fileURL = fileURL
    }

    static func defaultFileURL() -> URL {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AndroidFileTransfer", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("favorites.json")
    }

    func load() -> [Favorite] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Favorite].self, from: data)) ?? []
    }

    func save(_ favorites: [Favorite]) {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
