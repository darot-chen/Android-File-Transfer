import SwiftUI

struct TransferQueueView: View {
    let viewModel: TransferQueueViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Transfers")
                    .font(.headline)
                Spacer()
                Button("Clear Completed") {
                    viewModel.clearCompleted()
                }
                .disabled(!hasCompletedOrCancelled)
            }
            .padding()

            Divider()

            if viewModel.items.isEmpty {
                ContentUnavailableView(
                    "No Transfers",
                    systemImage: "arrow.up.arrow.down",
                    description: Text("Uploads and downloads appear here.")
                )
            } else {
                List(viewModel.items.reversed()) { item in
                    TransferRow(item: item, viewModel: viewModel)
                }
            }
        }
        .frame(minWidth: 360, minHeight: 320)
    }

    private var hasCompletedOrCancelled: Bool {
        viewModel.items.contains {
            switch $0.status {
            case .completed, .cancelled: true
            default: false
            }
        }
    }
}

private struct TransferRow: View {
    let item: TransferItem
    let viewModel: TransferQueueViewModel

    var body: some View {
        HStack {
            Image(systemName: item.direction == .upload ? "arrow.up.circle" : "arrow.down.circle")
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            switch item.status {
            case .inProgress:
                Button("Cancel") { viewModel.cancel(item) }
                    .buttonStyle(.plain)
                    .font(.caption)
            case .failed, .cancelled:
                Button("Retry") { viewModel.retry(item) }
                    .buttonStyle(.plain)
                    .font(.caption)
            default:
                EmptyView()
            }
        }
    }

    private var iconColor: Color {
        switch item.status {
        case .completed: .green
        case .failed: .red
        case .cancelled: .gray
        case .inProgress, .queued: .blue
        }
    }

    private var statusText: String {
        switch item.status {
        case .queued: "Waiting…"
        case .inProgress(let percent): "\(percent)%"
        case .completed: "Done"
        case .failed(let message): "Failed: \(message)"
        case .cancelled: "Cancelled"
        }
    }
}
