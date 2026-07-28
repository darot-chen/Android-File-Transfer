import SwiftUI

struct ContentView: View {
    let environment: AppEnvironment
    @State private var deviceListViewModel: DeviceListViewModel
    @State private var selectedDeviceID: String?
    @State private var pendingInitialPath: String?
    @State private var isShowingTransferQueue = false

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
                },
                selection: $selectedDeviceID
            )
            .navigationTitle("Devices")
        } detail: {
            if let selectedDeviceID {
                FileBrowserContainerView(
                    environment: environment,
                    serial: selectedDeviceID,
                    initialPath: pendingInitialPath ?? "/sdcard"
                )
                .id("\(selectedDeviceID)|\(pendingInitialPath ?? "")")
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
            }
        }
        .sheet(isPresented: $isShowingTransferQueue) {
            TransferQueueView(viewModel: environment.transferQueue)
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
