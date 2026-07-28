import SwiftUI

struct LibraryCategoriesView: View {
    let libraryViewModel: LibraryViewModel
    @Binding var selection: BrowseDestination?

    var body: some View {
        List(selection: $selection) {
            Section {
                Label("All Files", systemImage: "folder")
                    .tag(BrowseDestination.files)
            }
            Section("Library") {
                ForEach(FileCategory.allCases) { category in
                    HStack {
                        Label(category.displayName, systemImage: category.systemImage)
                        Spacer()
                        Text("\(libraryViewModel.count(for: category))")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .tag(BrowseDestination.category(category))
                }
            }
        }
        .navigationTitle("Browse")
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await libraryViewModel.scan() }
                } label: {
                    if libraryViewModel.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .help("Rescan Library")
                .disabled(libraryViewModel.isScanning)
            }
        }
        .task {
            await libraryViewModel.scanIfNeeded()
        }
        .overlay(alignment: .bottom) {
            if let errorMessage = libraryViewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(.regularMaterial)
            }
        }
    }
}
