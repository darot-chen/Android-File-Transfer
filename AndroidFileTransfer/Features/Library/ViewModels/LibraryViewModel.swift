import Foundation
import Observation

@MainActor
@Observable
final class LibraryViewModel {
    private(set) var filesByCategory: [FileCategory: [RemoteFile]] = [:]
    private(set) var isScanning = false
    private(set) var errorMessage: String?
    private(set) var hasScanned = false

    private let fileSystemService: FileSystemServiceProtocol
    private let serial: String
    private let root: String

    init(fileSystemService: FileSystemServiceProtocol, serial: String, root: String = "/sdcard") {
        self.fileSystemService = fileSystemService
        self.serial = serial
        self.root = root
    }

    func scanIfNeeded() async {
        guard !hasScanned, !isScanning else { return }
        await scan()
    }

    func scan() async {
        isScanning = true
        errorMessage = nil
        do {
            let paths = try await fileSystemService.scanFiles(under: root, on: serial)
            var grouped: [FileCategory: [RemoteFile]] = [:]
            for path in paths {
                guard !PathVisibility.isHidden(path) else { continue }
                let name = (path as NSString).lastPathComponent
                guard let category = FileCategory.category(forFileName: name) else { continue }
                let file = RemoteFile(
                    name: name, path: path, isDirectory: false, isSymlink: false,
                    symlinkTarget: nil, size: 0, modifiedAt: nil, permissions: ""
                )
                grouped[category, default: []].append(file)
            }
            for key in grouped.keys {
                grouped[key]?.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            }
            filesByCategory = grouped
            hasScanned = true
        } catch {
            errorMessage = String(describing: error)
        }
        isScanning = false
    }

    func files(for category: FileCategory) -> [RemoteFile] {
        filesByCategory[category] ?? []
    }

    func count(for category: FileCategory) -> Int {
        filesByCategory[category]?.count ?? 0
    }
}
