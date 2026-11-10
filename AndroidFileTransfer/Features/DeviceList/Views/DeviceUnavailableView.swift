import SwiftUI

/// Main-area placeholder shown whenever there's no device ready to browse.
struct DeviceUnavailableView: View {
    let availability: DeviceAvailability

    var body: some View {
        Group {
            switch availability {
            case .noDevices:
                ContentUnavailableView {
                    Label("No Device Connected", systemImage: "cable.connector")
                } description: {
                    Text("Connect an Android phone with a USB cable to browse its files.")
                } actions: {
                    SetupSteps()
                }
            case .noSelection:
                ContentUnavailableView(
                    "Select a Device",
                    systemImage: "iphone",
                    description: Text("Choose a device in the sidebar to browse its files.")
                )
            case .unauthorized(let device):
                ContentUnavailableView(
                    "Allow USB Debugging",
                    systemImage: "lock.iphone",
                    description: Text("Unlock \(device.displayName) and tap Allow on the “Allow USB debugging?” prompt.")
                )
            case .unavailable(let device):
                ContentUnavailableView(
                    "\(device.displayName) Isn’t Available",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Try unplugging the cable and connecting it again.")
                )
            case .ready:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SetupSteps: View {
    private let steps = [
        "Unlock the phone and connect it to this Mac.",
        "Turn on Developer Options and USB debugging.",
        "Tap Allow when the phone asks to trust this Mac.",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .background(.quaternary, in: Circle())
                    Text(step)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for a device…")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: 360, alignment: .leading)
    }
}
