import Foundation

protocol TransferHistoryStoring: Sendable {
    func load() -> [TransferItem]
    func save(_ items: [TransferItem])
}

struct TransferHistoryStore: TransferHistoryStoring {
    private let fileURL: URL

    init(fileURL: URL = TransferHistoryStore.defaultFileURL()) {
        self.fileURL = fileURL
    }

    static func defaultFileURL() -> URL {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AndroidFileTransfer", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("transfer-history.json")
    }

    func load() -> [TransferItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([TransferItem].self, from: data)) ?? []
    }

    func save(_ items: [TransferItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
