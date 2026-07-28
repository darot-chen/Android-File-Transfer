import SwiftUI

struct ContentView: View {
    let environment: AppEnvironment
    @State private var deviceListViewModel: DeviceListViewModel

    init(environment: AppEnvironment) {
        self.environment = environment
        _deviceListViewModel = State(initialValue: DeviceListViewModel(deviceService: environment.deviceService))
    }

    var body: some View {
        NavigationSplitView {
            DeviceListView(viewModel: deviceListViewModel)
                .navigationTitle("Devices")
        } detail: {
            Text("Select a device")
                .foregroundStyle(.secondary)
                .frame(minWidth: 480, minHeight: 320)
        }
        .task {
            await environment.bootstrapADB()
        }
    }
}

#Preview {
    ContentView(environment: AppEnvironment())
}
