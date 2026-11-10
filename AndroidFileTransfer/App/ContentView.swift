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
        _deviceListViewModel = State(initialValue: DeviceListViewModel(
            deviceService: environment.deviceService,
            detailsService: environment.deviceDetailsService
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            mainSplitView
            if isShowingTransferQueue {
                Divider()
                TransferQueueView(viewModel: environment.transferQueue) {
                    isShowingTransferQueue = false
                }
                .frame(height: 220)
                .transition(.move(edge: .bottom))
            }
        }
        .animation(.default, value: isShowingTransferQueue)
        .onChange(of: environment.transferQueue.items.count) { oldValue, newValue in
            if newValue > oldValue {
                isShowingTransferQueue = true
            }
        }
    }

    private var availability: DeviceAvailability {
        DeviceAvailability.resolve(devices: deviceListViewModel.devices, selectedSerial: selectedDeviceID)
    }

    /// The selected device's serial, only while adb can actually talk to it.
    /// Browsing and library scanning are keyed on this so nothing runs (and
    /// fails with "device not found") against a disconnected device.
    private var activeSerial: String? {
        availability.readyDevice?.serial
    }

    private var mainSplitView: some View {
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
            if let libraryViewModel, activeSerial != nil {
                LibraryCategoriesView(libraryViewModel: libraryViewModel, selection: $selectedDestination)
            } else {
                Color.clear
                    .navigationTitle("Browse")
            }
        } detail: {
            if let activeSerial {
                switch selectedDestination {
                case .category(let category):
                    if let libraryViewModel {
                        CategoryBrowserView(
                            category: category,
                            libraryViewModel: libraryViewModel,
                            transferQueue: environment.transferQueue,
                            transferService: environment.transferService,
                            logStore: environment.logStore,
                            serial: activeSerial
                        )
                        .id("\(activeSerial)|\(category.rawValue)")
                    }
                case .files, .none:
                    FileBrowserContainerView(
                        environment: environment,
                        serial: activeSerial,
                        initialPath: pendingInitialPath ?? "/sdcard"
                    )
                    .id("\(activeSerial)|\(pendingInitialPath ?? "")")
                }
            } else {
                DeviceUnavailableView(availability: availability)
                    .frame(minWidth: 480, minHeight: 320)
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    isShowingTransferQueue.toggle()
                } label: {
                    Image(systemName: isShowingTransferQueue ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle")
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
        .sheet(isPresented: $isShowingLogs) {
            LogsView(logStore: environment.logStore)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(viewModel: environment.settings)
        }
        .preferredColorScheme(environment.settings.appearance.colorScheme)
        .onChange(of: deviceListViewModel.devices, initial: true) { _, devices in
            let reconciled = DeviceAvailability.reconciledSelection(current: selectedDeviceID, devices: devices)
            if reconciled != selectedDeviceID {
                selectedDeviceID = reconciled
            }
        }
        .onChange(of: activeSerial) { _, newSerial in
            selectedDestination = .files
            if let newSerial {
                libraryViewModel = LibraryViewModel(fileSystemService: environment.fileSystemService, serial: newSerial)
            } else {
                libraryViewModel = nil
                pendingInitialPath = nil
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
