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

    private var files: [RemoteFile] { libraryViewModel.files(for: category) }

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
        .navigationTitle(category.displayName)
    }

    private var toolbar: some View {
        HStack {
            Text("\(files.count) items")
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
        List(files) { file in
            HStack {
                RemoteThumbnailView(file: file, serial: serial, transferService: transferService)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text(file.name)
                Spacer()
            }
            .contentShape(Rectangle())
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
                    .contentShape(Rectangle())
                    .contextMenu { contextMenuItems(for: file) }
                    .draggable(RemoteFileTransferable(remoteFile: file, serial: serial, transferService: transferService))
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func contextMenuItems(for file: RemoteFile) -> some View {
        Button("Quick Look") {
            Task { await preview(file) }
        }
        Button("Download…") {
            if let destination = FilePanelPresenter.chooseSaveLocation(suggestedName: file.name) {
                transferQueue.enqueueDownload(remotePath: file.path, localURL: destination, serial: serial)
            }
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
