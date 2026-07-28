import SwiftUI

struct FileBrowserView: View {
    @State var viewModel: FileBrowserViewModel
    @State private var fileToDelete: RemoteFile?
    @State private var fileToRename: RemoteFile?
    @State private var renameText = ""
    @State private var isCreatingFolder = false
    @State private var newFolderName = ""

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
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

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                newFolderName = ""
                isCreatingFolder = true
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .help("New Folder")

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
            List(viewModel.filteredEntries) { entry in
                FileRow(entry: entry)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        Task { await viewModel.navigate(to: entry) }
                    }
                    .contextMenu {
                        if !entry.isDirectory {
                            Button("Download…") {
                                if let destination = FilePanelPresenter.chooseSaveLocation(suggestedName: entry.name) {
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
        }
    }
}

private struct FileRow: View {
    let entry: RemoteFile

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundStyle(entry.isDirectory ? .blue : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                if let modifiedAt = entry.modifiedAt {
                    Text(modifiedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !entry.isDirectory {
                Text(entry.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var iconName: String {
        if entry.isSymlink { return "link" }
        return entry.isDirectory ? "folder.fill" : "doc"
    }
}
