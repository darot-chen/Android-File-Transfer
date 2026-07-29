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
    @State private var selection: Set<String> = []
    @State private var lastSelectedID: String?

    private var files: [RemoteFile] { libraryViewModel.files(for: category) }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .background {
            QuickLookHost(urlToPreview: $previewURL)
                .frame(width: 1, height: 1)
        }
        .navigationTitle(category.displayName)
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
        List(files, selection: $selection) { file in
            HStack {
                RemoteThumbnailView(file: file, serial: serial, transferService: transferService)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text(file.name)
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                Task { await preview(file) }
            }
            .contextMenu { contextMenuItems(for: file) }
            .draggable(RemoteFileTransferable(remoteFile: file, serial: serial, transferService: transferService))
        }
    }

    private var gridContent: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 12)], spacing: 16) {
                ForEach(files) { file in
                    VStack(spacing: 6) {
                        RemoteThumbnailView(file: file, serial: serial, transferService: transferService)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Text(file.name)
                            .font(.caption)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .padding(6)
                    .background(selection.contains(file.id) ? Color.accentColor.opacity(0.2) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                    .onTapGesture(count: 1) {
                        handleGridSelectionTap(file)
                    }
                    .onTapGesture(count: 2) {
                        Task { await preview(file) }
                    }
                    .contextMenu { contextMenuItems(for: file) }
                    .draggable(RemoteFileTransferable(remoteFile: file, serial: serial, transferService: transferService))
                }
            }
            .padding()
        }
    }

    /// Mirrors Finder's click/⌘-click/⇧-click semantics. Only the grid needs
    /// this by hand — List(selection:) already gets it natively from AppKit.
    private func handleGridSelectionTap(_ file: RemoteFile) {
        let modifiers = NSEvent.modifierFlags
        if modifiers.contains(.command) {
            if selection.contains(file.id) {
                selection.remove(file.id)
            } else {
                selection.insert(file.id)
            }
        } else if modifiers.contains(.shift),
                  let lastSelectedID,
                  let lastIndex = files.firstIndex(where: { $0.id == lastSelectedID }),
                  let currentIndex = files.firstIndex(where: { $0.id == file.id }) {
            let range = lastIndex < currentIndex ? lastIndex...currentIndex : currentIndex...lastIndex
            for index in range { selection.insert(files[index].id) }
        } else {
            selection = [file.id]
        }
        lastSelectedID = file.id
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
                    transferQueue.enqueueDownload(remotePath: file.path, localURL: destination, serial: serial, sizeBytes: file.size > 0 ? file.size : nil)
                }
            }
        }
    }

    private func downloadSelection() {
        guard let directory = FilePanelPresenter.chooseDownloadDirectory() else { return }
        for file in files where selection.contains(file.id) {
            let destination = directory.appendingPathComponent(file.name)
            transferQueue.enqueueDownload(remotePath: file.path, localURL: destination, serial: serial, sizeBytes: file.size > 0 ? file.size : nil)
        }
    }

    private func preview(_ file: RemoteFile) async {
        let destination = PreviewCache.localURL(for: file.name)
        do {
            for try await _ in transferService.pull(remotePath: file.path, localURL: destination, on: serial) {}
            previewURL = destination
        } catch {
            logStore.log(.error, category: "Library", "Failed to preview \(file.path): \(error)")
        }
    }
}
