import SwiftUI

struct DeviceListView: View {
    let viewModel: DeviceListViewModel

    var body: some View {
        List(viewModel.devices) { device in
            DeviceRow(device: device)
        }
        .overlay {
            if viewModel.devices.isEmpty {
                ContentUnavailableView(
                    "No Devices",
                    systemImage: "cable.connector",
                    description: Text("Connect an Android device via USB and enable USB debugging.")
                )
            }
        }
        .task {
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }
}

private struct DeviceRow: View {
    let device: Device

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading) {
                Text(device.model ?? device.serial)
                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var color: Color {
        switch device.state {
        case .device: .green
        case .unauthorized: .orange
        case .offline, .noPermissions, .unknown: .gray
        }
    }

    private var statusText: String {
        switch device.state {
        case .device: ""
        case .unauthorized: "Unauthorized — check your phone"
        case .offline: "Offline"
        case .noPermissions: "No permissions"
        case .unknown: "Unknown state"
        }
    }
}
