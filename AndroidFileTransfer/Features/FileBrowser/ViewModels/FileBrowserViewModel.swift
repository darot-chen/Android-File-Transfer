import Foundation
import Observation

struct Breadcrumb: Identifiable, Equatable, Sendable {
    var id: String { path }
    let name: String
    let path: String
}

@MainActor
@Observable
final class FileBrowserViewModel {
    private(set) var entries: [RemoteFile] = []
    private(set) var currentPath: String
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var searchText: String = ""

    private let fileSystemService: FileSystemServiceProtocol
    private let serial: String

    init(fileSystemService: FileSystemServiceProtocol, serial: String, initialPath: String = "/sdcard") {
        self.fileSystemService = fileSystemService
        self.serial = serial
        self.currentPath = initialPath
    }

    var filteredEntries: [RemoteFile] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var breadcrumbs: [Breadcrumb] {
        let parts = currentPath.split(separator: "/").map(String.init)
        var accumulated = ""
        var result = [Breadcrumb(name: "/", path: "/")]
        for part in parts {
            accumulated += "/" + part
            result.append(Breadcrumb(name: part, path: accumulated))
        }
        return result
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let listing = try await fileSystemService.listDirectory(path: currentPath, on: serial)
            entries = listing.sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        } catch {
            errorMessage = String(describing: error)
            AppLog.adb.error("Failed to list \(self.currentPath, privacy: .public): \(String(describing: error), privacy: .public)")
        }
        isLoading = false
    }

    func navigate(to file: RemoteFile) async {
        guard file.isDirectory else { return }
        currentPath = file.path
        await load()
    }

    func navigate(toPath path: String) async {
        guard path != currentPath else { return }
        currentPath = path
        await load()
    }

    func navigateUp() async {
        guard currentPath != "/" else { return }
        let parent = (currentPath as NSString).deletingLastPathComponent
        currentPath = parent.isEmpty ? "/" : parent
        await load()
    }

    func delete(_ file: RemoteFile) async {
        do {
            try await fileSystemService.delete(path: file.path, on: serial)
            await load()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func rename(_ file: RemoteFile, to newName: String) async {
        guard !newName.isEmpty, newName != file.name else { return }
        let newPath = (currentPath as NSString).appendingPathComponent(newName)
        do {
            try await fileSystemService.rename(from: file.path, to: newPath, on: serial)
            await load()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func createFolder(named name: String) async {
        guard !name.isEmpty else { return }
        let newPath = (currentPath as NSString).appendingPathComponent(name)
        do {
            try await fileSystemService.createFolder(path: newPath, on: serial)
            await load()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
