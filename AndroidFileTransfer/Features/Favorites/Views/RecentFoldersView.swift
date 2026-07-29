import SwiftUI

struct RecentFoldersView: View {
    let viewModel: RecentFoldersViewModel
    let onSelect: (RecentFolder) -> Void

    var body: some View {
        if !viewModel.recentFolders.isEmpty {
            Section("Recent") {
                ForEach(viewModel.recentFolders) { recentFolder in
                    Button {
                        onSelect(recentFolder)
                    } label: {
                        Label(recentFolder.name, systemImage: "clock")
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Remove from Recent") {
                            viewModel.remove(recentFolder)
                        }
                    }
                }
                Button("Clear Recent", role: .destructive) {
                    viewModel.clear()
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
        }
    }
}
