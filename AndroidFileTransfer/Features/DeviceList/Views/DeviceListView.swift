import SwiftUI

struct DeviceListView: View {
    let viewModel: DeviceListViewModel
    let favorites: FavoritesViewModel
    let recentFolders: RecentFoldersViewModel
    let onSelectFavorite: (Favorite) -> Void
    let onSelectRecentFolder: (RecentFolder) -> Void
    @Binding var selection: String?

    var body: some View {
        VStack(spacing: 0) {
            if let selection, let device = viewModel.devices.first(where: { $0.id == selection }) {
                DeviceInfoHeader(device: device, details: viewModel.detailsBySerial[selection])
                Divider()
            }

            List(selection: $selection) {
                FavoritesView(viewModel: favorites, onSelect: onSelectFavorite)
                RecentFoldersView(viewModel: recentFolders, onSelect: onSelectRecentFolder)

                Section("Devices") {
                    ForEach(viewModel.devices) { device in
                        DeviceRow(device: device)
                            .tag(device.id)
                    }
                }
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
        }
        .task {
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
        .onChange(of: selection) { _, newSerial in
            if let newSerial {
                Task { await viewModel.refreshDetails(for: newSerial) }
            }
        }
    }
}

private struct DeviceInfoHeader: View {
    let device: Device
    let details: DeviceDetails?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "iphone")
                Text(device.model ?? device.serial)
                    .font(.headline)
            }
            if let version = details?.androidVersion {
                Text("Android \(version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let storage = details?.storage {
                ProgressView(value: usedFraction(storage))
                    .controlSize(.small)
                Text("\(Self.format(storage.freeBytes)) free of \(Self.format(storage.totalBytes))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func usedFraction(_ storage: DeviceStorage) -> Double {
        guard storage.totalBytes > 0 else { return 0 }
        return Double(storage.totalBytes - storage.freeBytes) / Double(storage.totalBytes)
    }

    private static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
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
