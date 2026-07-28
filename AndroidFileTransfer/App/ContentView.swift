import SwiftUI

struct ContentView: View {
    let environment: AppEnvironment
    @State private var deviceListViewModel: DeviceListViewModel
    @State private var selectedDeviceID: String?
    @State private var isShowingTransferQueue = false

    init(environment: AppEnvironment) {
        self.environment = environment
        _deviceListViewModel = State(initialValue: DeviceListViewModel(deviceService: environment.deviceService))
    }

    var body: some View {
        NavigationSplitView {
            DeviceListView(viewModel: deviceListViewModel, selection: $selectedDeviceID)
                .navigationTitle("Devices")
        } detail: {
            if let selectedDeviceID {
                FileBrowserContainerView(environment: environment, serial: selectedDeviceID)
                    .id(selectedDeviceID)
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

    init(environment: AppEnvironment, serial: String) {
        _viewModel = State(initialValue: FileBrowserViewModel(
            fileSystemService: environment.fileSystemService,
            transferQueue: environment.transferQueue,
            serial: serial
        ))
    }

    var body: some View {
        FileBrowserView(viewModel: viewModel)
    }
}

#Preview {
    ContentView(environment: AppEnvironment())
}
