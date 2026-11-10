import AppKit
import SwiftUI

struct CategoryBrowserView: View {
    let category: FileCategory
    let libraryViewModel: LibraryViewModel
    let transferQueue: TransferQueueViewModel
    let transferService: TransferServiceProtocol
    let logStore: LogStore
    let serial: String

    @State private var viewMode: BrowserViewMode = .grid
    @State private var previewURL: URL?
    @State private var previewTask: Task<URL?, Never>?
    @State private var isLoadingPreview = false
    @State private var selection: Set<String> = []
    @State private var sortField: FileSortField = .dateModified
    @State private var sortAscending = false
    @FocusState private var isContentFocused: Bool

    private var files: [RemoteFile] { libraryViewModel.files(for: category) }
    private var sortedFiles: [RemoteFile] { FileSortField.sorted(files, by: sortField, ascending: sortAscending, directoriesFirst: false) }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        // See FileBrowserView's identical modifier for why this is needed:
        // .onKeyPress only fires once something is actually focused, and a
        // single click's selection change doesn't reliably grant that.
        .focusable()
        .focusEffectDisabled()
        .focused($isContentFocused)
        .background {
            QuickLookHost(urlToPreview: $previewURL)
                .frame(width: 1, height: 1)
        }
        .overlay {
            if isLoadingPreview {
                PreviewLoadingOverlay()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoadingPreview)
        .navigationTitle(category.displayName)
        .task {
            isContentFocused = true
        }
        .onChange(of: selection) {
            isContentFocused = true
        }
        .onKeyPress(.space) {
            guard let file = files.first(where: { selection.contains($0.id) }) else { return .ignored }
            Task { await preview(file) }
            return .handled
        }
    }

    private var toolbar: some View {
        HStack {
            Text(selection.count > 1 ? "\(selection.count) selected" : "\(files.count) items")
                .foregroundStyle(.secondary)
            Spacer()
            ViewModePicker(mode: $viewMode)
            SortMenuButton(sortField: $sortField, sortAscending: $sortAscending)
        }
        .padding(8)
    }

    @ViewBuilder
    private var content: some View {
        if libraryViewModel.isScanning, files.isEmpty {
            ProgressView("Scanning…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if files.isEmpty {
            ContentUnavailableView(
                "No \(category.displayName)",
                systemImage: category.systemImage
            )
        } else {
            switch viewMode {
            case .list:
                listContent
            case .grid:
                gridContent
            }
        }
    }

    private var listContent: some View {
        List(sortedFiles, selection: $selection) { file in
            HStack {
                RemoteThumbnailView(file: file, serial: serial, transferService: transferService)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text(file.name)
                Spacer()
                if let modifiedAt = file.modifiedAt {
                    Text(modifiedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(file.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .trailing)
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                Task { await preview(file) }
            }
            .contextMenu { contextMenuItems(for: file) }
            .onDrag { RemoteFileDragProvider.make(file: file, serial: serial, transferQueue: transferQueue) }
        }
    }

    private var gridContent: some View {
        ScrollView {
            MarqueeSelectionContainer(selection: $selection) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 12)], spacing: 16) {
                    ForEach(sortedFiles) { file in
                        VStack(spacing: 6) {
                            RemoteThumbnailView(file: file, serial: serial, transferService: transferService, style: .tile)
                                .frame(width: 100, height: 100)
                            Text(file.displayNameWithoutExtension)
                                .font(.caption)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                            Text(file.formattedSize)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(6)
                        .background(selection.contains(file.id) ? Color.accentColor.opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                        .reportingFrame(id: file.id)
                        .overlay(
                            CellInteractionOverlay(
                                itemID: file.id,
                                isPartOfMultiSelection: selection.count > 1 && selection.contains(file.id),
                                onPlainSelect: { handleGridSelectionTap(file) },
                                onModifiedSelect: { handleGridSelectionTap(file) },
                                onOpen: { Task { await preview(file) } },
                                dragItemsProvider: { dragItems(startingFrom: file) }
                            )
                        )
                        .contextMenu { contextMenuItems(for: file) }
                    }
                }
                .padding()
            }
        }
    }

    /// Only the grid needs this by hand — List(selection:) already gets
    /// Finder's list-view click semantics natively from AppKit.
    private func handleGridSelectionTap(_ file: RemoteFile) {
        selection = GridSelection.applyingClick(on: file.id, modifiers: NSEvent.modifierFlags, to: selection)
    }

    /// Drags the whole current selection if `file` is part of a
    /// multi-selection, otherwise just `file` — mirroring Finder.
    private func dragItems(startingFrom file: RemoteFile) -> [NSDraggingItem] {
        let targets: [RemoteFile]
        if selection.count > 1, selection.contains(file.id) {
            targets = files.filter { selection.contains($0.id) }
        } else {
            targets = [file]
        }
        return RemoteFileDragProvider.makeDraggingItems(files: targets, serial: serial, transferQueue: transferQueue)
    }

    @ViewBuilder
    private func contextMenuItems(for file: RemoteFile) -> some View {
        Button("Quick Look") {
            Task { await preview(file) }
        }
        if selection.count > 1, selection.contains(file.id) {
            Button("Download \(selection.count) Items…") {
                downloadSelection()
            }
        } else {
            Button("Download…") {
                if let destination = FilePanelPresenter.chooseSaveLocation(suggestedName: file.name) {
                    transferQueue.enqueueDownload(remotePath: file.path, localURL: destination, serial: serial, sizeBytes: file.size)
                }
            }
        }
    }

    private func downloadSelection() {
        guard let directory = FilePanelPresenter.chooseDownloadDirectory() else { return }
        for file in files where selection.contains(file.id) {
            let destination = directory.appendingPathComponent(file.name)
            transferQueue.enqueueDownload(remotePath: file.path, localURL: destination, serial: serial, sizeBytes: file.size)
        }
    }

    private func preview(_ file: RemoteFile) async {
        previewTask?.cancel()

        let destination = PreviewCache.localURL(for: file.path)
        if FileManager.default.fileExists(atPath: destination.path) {
            previewURL = destination
            return
        }

        isLoadingPreview = true
        defer { isLoadingPreview = false }

        let task = Task<URL?, Never> {
            do {
                for try await _ in transferService.pull(remotePath: file.path, localURL: destination, on: serial) {
                    if Task.isCancelled { return nil }
                }
                return Task.isCancelled ? nil : destination
            } catch {
                if !Task.isCancelled {
                    logStore.log(.error, category: "Library", "Failed to preview \(file.path): \(error)")
                }
                return nil
            }
        }
        previewTask = task
        if let url = await task.value {
            previewURL = url
        }
    }
}
