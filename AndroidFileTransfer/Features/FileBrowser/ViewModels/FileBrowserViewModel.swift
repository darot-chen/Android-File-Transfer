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

    private(set) var isPreviewing = false
    private(set) var searchResults: [String] = []
    private(set) var isSearching = false
    private var searchTask: Task<Void, Never>?
    var viewMode: BrowserViewMode = .list

    private let fileSystemService: FileSystemServiceProtocol
    let transferService: TransferServiceProtocol
    let transferQueue: TransferQueueViewModel
    private let favorites: FavoritesViewModel
    private let recentFolders: RecentFoldersViewModel
    private let settings: SettingsViewModel
    private let logStore: LogStore
    let serial: String

    init(
        fileSystemService: FileSystemServiceProtocol,
        transferService: TransferServiceProtocol,
        transferQueue: TransferQueueViewModel,
        favorites: FavoritesViewModel,
        recentFolders: RecentFoldersViewModel,
        settings: SettingsViewModel,
        logStore: LogStore,
        serial: String,
        initialPath: String = "/sdcard"
    ) {
        self.fileSystemService = fileSystemService
        self.transferService = transferService
        self.transferQueue = transferQueue
        self.favorites = favorites
        self.recentFolders = recentFolders
        self.settings = settings
        self.logStore = logStore
        self.serial = serial
        self.currentPath = initialPath
    }

    var defaultDownloadDirectory: String {
        settings.defaultDownloadDirectory
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
            entries = listing
                .filter { !$0.name.hasPrefix(".") }
                .sorted { lhs, rhs in
                    if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
            let name = (currentPath as NSString).lastPathComponent
            recentFolders.recordVisit(serial: serial, path: currentPath, name: name.isEmpty ? "/" : name)
        } catch {
            errorMessage = String(describing: error)
            logStore.log(.error, category: "FileBrowser", "Failed to list \(currentPath): \(error)")
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
            logStore.log(.error, category: "FileBrowser", "Failed to delete \(file.path): \(error)")
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
            logStore.log(.error, category: "FileBrowser", "Failed to rename \(file.path): \(error)")
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
            logStore.log(.error, category: "FileBrowser", "Failed to create folder \(newPath): \(error)")
        }
    }

    func download(_ file: RemoteFile, to destination: URL) {
        transferQueue.enqueueDownload(remotePath: file.path, localURL: destination, serial: serial, sizeBytes: file.size)
    }

    func upload(from localURL: URL, into directoryPath: String? = nil) {
        let targetDirectory = directoryPath ?? currentPath
        let remotePath = (targetDirectory as NSString).appendingPathComponent(localURL.lastPathComponent)
        transferQueue.enqueueUpload(localURL: localURL, remotePath: remotePath, serial: serial)
    }

    /// Cancels a still-running previous preview before starting a new one —
    /// otherwise rapid successive preview requests (e.g. spacebar-ing
    /// through several files quickly) race, and whichever pull happens to
    /// finish last wins even if it's no longer the file being looked at.
    private var previewTask: Task<URL?, Never>?

    func preview(_ file: RemoteFile) async -> URL? {
        guard !file.isDirectory else { return nil }
        previewTask?.cancel()

        let destination = PreviewCache.localURL(for: file.path)
        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }

        isPreviewing = true
        defer { isPreviewing = false }

        let task = Task<URL?, Never> { [transferService, serial] in
            do {
                for try await _ in transferService.pull(remotePath: file.path, localURL: destination, on: serial) {
                    if Task.isCancelled { return nil }
                }
                return Task.isCancelled ? nil : destination
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = String(describing: error)
                }
                return nil
            }
        }
        previewTask = task
        return await task.value
    }

    var isCurrentFolderFavorite: Bool {
        favorites.isFavorite(serial: serial, path: currentPath)
    }

    func toggleFavoriteCurrentFolder() {
        favorites.toggle(serial: serial, path: currentPath, name: (currentPath as NSString).lastPathComponent.isEmpty ? "/" : (currentPath as NSString).lastPathComponent)
    }

    func performRecursiveSearch(query: String) {
        searchTask?.cancel()
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        searchResults = []
        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let results = try await fileSystemService.search(query: query, in: currentPath, on: serial)
                if !Task.isCancelled {
                    self.searchResults = results.filter { !PathVisibility.isHidden($0) }
                }
            } catch is CancellationError {
                // Superseded by a newer search or explicitly cancelled; leave results as-is.
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = String(describing: error)
                }
            }
            if !Task.isCancelled {
                self.isSearching = false
            }
        }
    }

    func cancelSearch() {
        searchTask?.cancel()
        isSearching = false
        searchResults = []
    }

    func navigateToSearchResult(_ path: String) async {
        let parent = (path as NSString).deletingLastPathComponent
        currentPath = parent.isEmpty ? "/" : parent
        await load()
    }
}
