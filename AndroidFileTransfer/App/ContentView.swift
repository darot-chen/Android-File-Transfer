import SwiftUI

struct ContentView: View {
    let environment: AppEnvironment
    @State private var deviceListViewModel: DeviceListViewModel
    @State private var selectedDeviceID: String?
    @State private var pendingInitialPath: String?
    @State private var selectedDestination: BrowseDestination? = .files
    @State private var libraryViewModel: LibraryViewModel?
    @State private var isShowingTransferQueue = false
    @State private var isShowingSettings = false
    @State private var isShowingLogs = false

    init(environment: AppEnvironment) {
        self.environment = environment
        _deviceListViewModel = State(initialValue: DeviceListViewModel(deviceService: environment.deviceService))
    }

    var body: some View {
        NavigationSplitView {
            DeviceListView(
                viewModel: deviceListViewModel,
                favorites: environment.favorites,
                onSelectFavorite: { favorite in
                    selectedDeviceID = favorite.serial
                    pendingInitialPath = favorite.path
                    selectedDestination = .files
                },
                selection: $selectedDeviceID
            )
            .navigationTitle("Devices")
        } content: {
            if let libraryViewModel {
                LibraryCategoriesView(libraryViewModel: libraryViewModel, selection: $selectedDestination)
            } else {
                Text("Select a device")
                    .foregroundStyle(.secondary)
            }
        } detail: {
            if let selectedDeviceID {
                switch selectedDestination {
                case .category(let category):
                    if let libraryViewModel {
                        CategoryBrowserView(
                            category: category,
                            libraryViewModel: libraryViewModel,
                            transferQueue: environment.transferQueue,
                            transferService: environment.transferService,
                            logStore: environment.logStore,
                            serial: selectedDeviceID
                        )
                        .id("\(selectedDeviceID)|\(category.rawValue)")
                    }
                case .files, .none:
                    FileBrowserContainerView(
                        environment: environment,
                        serial: selectedDeviceID,
                        initialPath: pendingInitialPath ?? "/sdcard"
                    )
                    .id("\(selectedDeviceID)|\(pendingInitialPath ?? "")")
                }
            } else {
                Text("Select a device")
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 480, minHeight: 320)
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    isShowingTransferQueue = true
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
                .help("Transfers")
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
            ToolbarItem {
                Button {
                    isShowingLogs = true
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                }
                .help("Logs")
            }
            ToolbarItem {
                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        .sheet(isPresented: $isShowingTransferQueue) {
            TransferQueueView(viewModel: environment.transferQueue)
        }
        .sheet(isPresented: $isShowingLogs) {
            LogsView(logStore: environment.logStore)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(viewModel: environment.settings)
        }
        .preferredColorScheme(environment.settings.appearance.colorScheme)
        .onChange(of: selectedDeviceID) { _, newSerial in
            selectedDestination = .files
            if let newSerial {
                libraryViewModel = LibraryViewModel(fileSystemService: environment.fileSystemService, serial: newSerial)
            } else {
                libraryViewModel = nil
            }
        }
        .task {
            await environment.bootstrapADB()
        }
    }
}

private struct FileBrowserContainerView: View {
    @State private var viewModel: FileBrowserViewModel

    init(environment: AppEnvironment, serial: String, initialPath: String) {
        _viewModel = State(initialValue: FileBrowserViewModel(
            fileSystemService: environment.fileSystemService,
            transferService: environment.transferService,
            transferQueue: environment.transferQueue,
            favorites: environment.favorites,
            settings: environment.settings,
            logStore: environment.logStore,
            serial: serial,
            initialPath: initialPath
        ))
    }

    var body: some View {
        FileBrowserView(viewModel: viewModel)
    }
}

#Preview {
    ContentView(environment: AppEnvironment())
}
