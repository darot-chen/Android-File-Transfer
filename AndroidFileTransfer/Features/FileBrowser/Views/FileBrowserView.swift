import SwiftUI
import UniformTypeIdentifiers

struct FileBrowserView: View {
    @State var viewModel: FileBrowserViewModel
    @State private var fileToDelete: RemoteFile?
    @State private var fileToRename: RemoteFile?
    @State private var renameText = ""
    @State private var isCreatingFolder = false
    @State private var newFolderName = ""
    @State private var isDropTargeted = false
    @State private var previewURL: URL?
    @State private var isShowingSearch = false
    @State private var deviceSearchQuery = ""

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .background {
            QuickLookHost(urlToPreview: $previewURL)
                .frame(width: 0, height: 0)
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
                if let url = FilePanelPresenter.chooseFileToUpload() {
                    viewModel.upload(from: url)
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .help("Upload File…")
        }
        .padding(8)
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

    private var listContent: some View {
        List(viewModel.filteredEntries) { entry in
            FileRow(entry: entry, serial: viewModel.serial, transferService: viewModel.transferService)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    Task { await viewModel.navigate(to: entry) }
                }
                .modifier(DraggableIfFile(entry: entry, viewModel: viewModel))
                .contextMenu { contextMenuItems(for: entry) }
        }
    }

    private var gridContent: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 12)], spacing: 16) {
                ForEach(viewModel.filteredEntries) { entry in
                    VStack(spacing: 6) {
                        RemoteThumbnailView(file: entry, serial: viewModel.serial, transferService: viewModel.transferService)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Text(entry.name)
                            .font(.caption)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        Task { await viewModel.navigate(to: entry) }
                    }
                    .modifier(DraggableIfFile(entry: entry, viewModel: viewModel))
                    .contextMenu { contextMenuItems(for: entry) }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func contextMenuItems(for entry: RemoteFile) -> some View {
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
        }
        Button("Rename…") {
            renameText = entry.name
            fileToRename = entry
        }
        Button("Delete", role: .destructive) {
            fileToDelete = entry
        }
    }
}

/// Applies .draggable only to non-directory rows/cells — factored out since
/// both list and grid layouts need the identical conditional.
private struct DraggableIfFile: ViewModifier {
    let entry: RemoteFile
    let viewModel: FileBrowserViewModel

    func body(content: Content) -> some View {
        if entry.isDirectory {
            content
        } else {
            content.draggable(viewModel.transferable(for: entry))
        }
    }
}

private struct FileRow: View {
    let entry: RemoteFile
    let serial: String
    let transferService: TransferServiceProtocol

    var body: some View {
        HStack {
            RemoteThumbnailView(file: entry, serial: serial, transferService: transferService)
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 3))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                if let modifiedAt = entry.modifiedAt {
                    Text(modifiedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !entry.isDirectory, entry.modifiedAt != nil {
                Text(entry.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
