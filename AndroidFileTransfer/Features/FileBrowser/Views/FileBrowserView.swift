import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FileBrowserView: View {
    @State var viewModel: FileBrowserViewModel
    @State private var fileToDelete: RemoteFile?
    @State private var isConfirmingBatchDelete = false
    @State private var fileToRename: RemoteFile?
    @State private var renameText = ""
    @State private var isCreatingFolder = false
    @State private var newFolderName = ""
    @State private var isDropTargeted = false
    @State private var previewURL: URL?
    @State private var isShowingSearch = false
    @State private var deviceSearchQuery = ""
    @State private var selection: Set<String> = []
    @State private var fileForProperties: RemoteFile?
    @State private var sortField: FileSortField = .name
    @State private var sortAscending = true
    @State private var lastSelectedID: String?

    static let dateColumnWidth: CGFloat = 140
    static let sizeColumnWidth: CGFloat = 90

    private var sortedEntries: [RemoteFile] {
        FileSortField.sorted(viewModel.filteredEntries, by: sortField, ascending: sortAscending)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .background {
            // A truly zero-size view can be skipped by SwiftUI's layout pass
            // and never actually attached to the window, which silently
            // breaks the Quick Look panel's makeFirstResponder call.
            QuickLookHost(urlToPreview: $previewURL)
                .frame(width: 1, height: 1)
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in
                        viewModel.upload(from: url)
                    }
                }
            }
            return true
        }
        .searchable(
            text: Binding(get: { viewModel.searchText }, set: { viewModel.searchText = $0 }),
            prompt: "Filter this folder"
        )
        .task {
            if viewModel.entries.isEmpty {
                await viewModel.load()
            }
        }
        .onChange(of: viewModel.currentPath) {
            selection.removeAll()
        }
        .onKeyPress(.space) {
            guard let file = sortedEntries.first(where: { selection.contains($0.id) }), !file.isDirectory else {
                return .ignored
            }
            Task {
                if let url = await viewModel.preview(file) {
                    previewURL = url
                }
            }
            return .handled
        }
        .confirmationDialog(
            "Delete “\(fileToDelete?.name ?? "")”?",
            isPresented: Binding(get: { fileToDelete != nil }, set: { if !$0 { fileToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let file = fileToDelete {
                    Task { await viewModel.delete(file) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .confirmationDialog(
            "Delete \(selection.count) items?",
            isPresented: $isConfirmingBatchDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await deleteSelection() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .alert(
            "Rename",
            isPresented: Binding(get: { fileToRename != nil }, set: { if !$0 { fileToRename = nil } })
        ) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let file = fileToRename {
                    Task { await viewModel.rename(file, to: renameText) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("New Folder", isPresented: $isCreatingFolder) {
            TextField("Name", text: $newFolderName)
            Button("Create") {
                Task { await viewModel.createFolder(named: newFolderName) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $isShowingSearch) {
            DeviceSearchView(viewModel: viewModel, query: $deviceSearchQuery) { path in
                isShowingSearch = false
                Task { await viewModel.navigateToSearchResult(path) }
            }
        }
        .sheet(item: $fileForProperties) { file in
            FilePropertiesView(file: file)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                Task { await viewModel.navigateUp() }
            } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(viewModel.currentPath == "/")
            .help("Go to enclosing folder")
            .keyboardShortcut(.upArrow, modifiers: .command)

            Button {
                Task { await viewModel.load() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Reload")
            .keyboardShortcut("r", modifiers: .command)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(viewModel.breadcrumbs) { crumb in
                        Button(crumb.name) {
                            Task { await viewModel.navigate(toPath: crumb.path) }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(crumb.path == viewModel.currentPath ? .primary : .secondary)

                        if crumb.id != viewModel.breadcrumbs.last?.id {
                            Text("/").foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            if viewModel.isLoading || viewModel.isPreviewing {
                ProgressView()
                    .controlSize(.small)
                    .help(viewModel.isPreviewing ? "Downloading preview…" : "Loading…")
            }

            ViewModePicker(mode: Binding(get: { viewModel.viewMode }, set: { viewModel.viewMode = $0 }))

            SortMenuButton(sortField: $sortField, sortAscending: $sortAscending)

            Button {
                viewModel.toggleFavoriteCurrentFolder()
            } label: {
                Image(systemName: viewModel.isCurrentFolderFavorite ? "star.fill" : "star")
            }
            .help(viewModel.isCurrentFolderFavorite ? "Remove from Favorites" : "Add to Favorites")

            Button {
                deviceSearchQuery = ""
                isShowingSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .help("Search Device…")
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Button {
                newFolderName = ""
                isCreatingFolder = true
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .help("New Folder")
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button {
                uploadFilePicker()
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .help("Upload File…")
        }
        .padding(8)
    }

    private func uploadFilePicker(into directoryPath: String? = nil) {
        if let url = FilePanelPresenter.chooseFileToUpload() {
            viewModel.upload(from: url, into: directoryPath)
        }
    }

    private func copyPathToPasteboard(_ path: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(path, forType: .string)
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage = viewModel.errorMessage {
            ContentUnavailableView(
                "Can't Load Folder",
                systemImage: "exclamationmark.triangle",
                description: Text(errorMessage)
            )
        } else if viewModel.filteredEntries.isEmpty, !viewModel.isLoading {
            ContentUnavailableView(
                "No Files",
                systemImage: "folder",
                description: Text("This folder is empty.")
            )
        } else {
            switch viewModel.viewMode {
            case .list:
                listContent
            case .grid:
                gridContent
            }
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 8) {
            SortHeaderButton(title: "Name", field: .name, sortField: $sortField, sortAscending: $sortAscending)
                .frame(maxWidth: .infinity, alignment: .leading)
            SortHeaderButton(title: "Date Modified", field: .dateModified, sortField: $sortField, sortAscending: $sortAscending)
                .frame(width: Self.dateColumnWidth, alignment: .leading)
            SortHeaderButton(title: "Size", field: .size, sortField: $sortField, sortAscending: $sortAscending)
                .frame(width: Self.sizeColumnWidth, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var listContent: some View {
        VStack(spacing: 0) {
            columnHeader
            Divider()
            List(sortedEntries, selection: $selection) { entry in
                FileRow(entry: entry, serial: viewModel.serial, transferService: viewModel.transferService)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        Task { await viewModel.navigate(to: entry) }
                    }
                    .modifier(DraggableIfFile(entry: entry, viewModel: viewModel))
                    .contextMenu { contextMenuItems(for: entry) }
            }
            .contextMenu {
                backgroundContextMenuItems
            }
        }
    }

    private var gridContent: some View {
        ScrollView {
            MarqueeSelectionContainer(selection: $selection) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 12)], spacing: 16) {
                    ForEach(sortedEntries) { entry in
                        VStack(spacing: 6) {
                            RemoteThumbnailView(file: entry, serial: viewModel.serial, transferService: viewModel.transferService)
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text(entry.name)
                                .font(.caption)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .padding(6)
                        .background(selection.contains(entry.id) ? Color.accentColor.opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                        .reportingFrame(id: entry.id)
                        .overlay(
                            CellInteractionOverlay(
                                itemID: entry.id,
                                isPartOfMultiSelection: selection.count > 1 && selection.contains(entry.id),
                                onPlainSelect: { handleGridSelectionTap(entry) },
                                onModifiedSelect: { handleGridSelectionTap(entry) },
                                onOpen: { Task { await viewModel.navigate(to: entry) } },
                                dragItemsProvider: { dragItems(startingFrom: entry) }
                            )
                        )
                        .contextMenu { contextMenuItems(for: entry) }
                    }
                }
                .padding()
            }
            .contextMenu {
                backgroundContextMenuItems
            }
        }
    }

    /// Mirrors Finder's click/⌘-click/⇧-click semantics. Only the grid needs
    /// this by hand — List(selection:) already gets it natively from AppKit.
    private func handleGridSelectionTap(_ entry: RemoteFile) {
        let modifiers = NSEvent.modifierFlags
        if modifiers.contains(.command) {
            if selection.contains(entry.id) {
                selection.remove(entry.id)
            } else {
                selection.insert(entry.id)
            }
        } else if modifiers.contains(.shift),
                  let lastSelectedID,
                  let lastIndex = sortedEntries.firstIndex(where: { $0.id == lastSelectedID }),
                  let currentIndex = sortedEntries.firstIndex(where: { $0.id == entry.id }) {
            let range = lastIndex < currentIndex ? lastIndex...currentIndex : currentIndex...lastIndex
            for index in range { selection.insert(sortedEntries[index].id) }
        } else {
            selection = [entry.id]
        }
        lastSelectedID = entry.id
    }

    /// Drags the whole current selection if `entry` is part of a
    /// multi-selection, otherwise just `entry` — mirroring Finder. Folders
    /// aren't draggable out to Finder, so they're excluded either way.
    private func dragItems(startingFrom entry: RemoteFile) -> [NSDraggingItem] {
        let targets: [RemoteFile]
        if selection.count > 1, selection.contains(entry.id) {
            targets = sortedEntries.filter { selection.contains($0.id) && !$0.isDirectory }
        } else {
            targets = entry.isDirectory ? [] : [entry]
        }
        return targets.map { file in
            RemoteFileDragProvider.makeDraggingItem(file: file, serial: viewModel.serial, transferService: viewModel.transferService)
        }
    }

    private func downloadSelection() {
        guard let directory = FilePanelPresenter.chooseDownloadDirectory() else { return }
        for entry in sortedEntries where selection.contains(entry.id) && !entry.isDirectory {
            let destination = directory.appendingPathComponent(entry.name)
            viewModel.download(entry, to: destination)
        }
    }

    private func deleteSelection() async {
        for entry in sortedEntries where selection.contains(entry.id) {
            await viewModel.delete(entry)
        }
    }

    @ViewBuilder
    private var backgroundContextMenuItems: some View {
        Button("Upload Here…") {
            uploadFilePicker()
        }
        Button("New Folder…") {
            newFolderName = ""
            isCreatingFolder = true
        }
    }

    @ViewBuilder
    private func contextMenuItems(for entry: RemoteFile) -> some View {
        if selection.count > 1, selection.contains(entry.id) {
            Button("Download \(selection.count) Items…") {
                downloadSelection()
            }
            Button("Delete \(selection.count) Items", role: .destructive) {
                isConfirmingBatchDelete = true
            }
            Divider()
        }
        Button("Open") {
            if entry.isDirectory {
                Task { await viewModel.navigate(to: entry) }
            } else {
                Task {
                    if let url = await viewModel.preview(entry) {
                        previewURL = url
                    }
                }
            }
        }
        if !entry.isDirectory {
            Button("Quick Look") {
                Task {
                    if let url = await viewModel.preview(entry) {
                        previewURL = url
                    }
                }
            }
            Button("Download…") {
                if let destination = FilePanelPresenter.chooseSaveLocation(
                    suggestedName: entry.name,
                    defaultDirectory: viewModel.defaultDownloadDirectory
                ) {
                    viewModel.download(entry, to: destination)
                }
            }
        } else {
            Button("Upload Here…") {
                uploadFilePicker(into: entry.path)
            }
        }
        Divider()
        Button("Rename…") {
            renameText = entry.name
            fileToRename = entry
        }
        Button("Copy Path") {
            copyPathToPasteboard(entry.path)
        }
        Divider()
        Button("Delete", role: .destructive) {
            fileToDelete = entry
        }
        Divider()
        Button("Get Info") {
            fileForProperties = entry
        }
    }
}

private struct SortHeaderButton: View {
    let title: String
    let field: FileSortField
    @Binding var sortField: FileSortField
    @Binding var sortAscending: Bool

    var body: some View {
        Button {
            if sortField == field {
                sortAscending.toggle()
            } else {
                sortField = field
                sortAscending = true
            }
        } label: {
            HStack(spacing: 2) {
                Text(title)
                if sortField == field {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
            }
        }
        .buttonStyle(.plain)
        .font(.caption.bold())
        .foregroundStyle(.secondary)
    }
}

/// Applies the drag-out promise only to non-directory rows/cells — factored
/// out since both list and grid layouts need the identical conditional.
private struct DraggableIfFile: ViewModifier {
    let entry: RemoteFile
    let viewModel: FileBrowserViewModel

    func body(content: Content) -> some View {
        if entry.isDirectory {
            content
        } else {
            content.onDrag {
                RemoteFileDragProvider.make(file: entry, serial: viewModel.serial, transferService: viewModel.transferService)
            }
        }
    }
}

private struct FileRow: View {
    let entry: RemoteFile
    let serial: String
    let transferService: TransferServiceProtocol

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                RemoteThumbnailView(file: entry, serial: serial, transferService: transferService)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                Text(entry.name)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(entry.modifiedAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "--")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: FileBrowserView.dateColumnWidth, alignment: .leading)

            Text(entry.isDirectory ? "--" : entry.formattedSize)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: FileBrowserView.sizeColumnWidth, alignment: .trailing)
        }
    }
}

private struct FilePropertiesView: View {
    let file: RemoteFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(file.name)
                    .font(.title3.bold())
                    .lineLimit(2)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Kind", value: file.isDirectory ? "Folder" : "File")
                LabeledContent("Path", value: file.path)
                if !file.isDirectory {
                    LabeledContent("Size", value: file.formattedSize)
                }
                if let modifiedAt = file.modifiedAt {
                    LabeledContent("Modified", value: modifiedAt.formatted(date: .abbreviated, time: .shortened))
                }
                LabeledContent("Permissions", value: file.permissions)
                if file.isSymlink, let target = file.symlinkTarget {
                    LabeledContent("Symlink Target", value: target)
                }
            }
            .font(.callout)
            Spacer()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 380)
    }
}

private struct DeviceSearchView: View {
    let viewModel: FileBrowserViewModel
    @Binding var query: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search \(viewModel.currentPath)…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        viewModel.performRecursiveSearch(query: query)
                    }
                if viewModel.isSearching {
                    ProgressView().controlSize(.small)
                }
            }
            .padding()

            Divider()

            if viewModel.searchResults.isEmpty, !viewModel.isSearching {
                ContentUnavailableView.search
            } else {
                List(viewModel.searchResults, id: \.self) { path in
                    Button(path) {
                        onSelect(path)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 360)
        .onDisappear {
            viewModel.cancelSearch()
        }
    }
}
