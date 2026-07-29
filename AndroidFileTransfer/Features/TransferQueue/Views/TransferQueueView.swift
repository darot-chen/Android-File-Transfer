import SwiftUI

struct TransferQueueView: View {
    let viewModel: TransferQueueViewModel
    var onClose: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Transfers")
                    .font(.headline)
                if !viewModel.items.isEmpty {
                    Text("\(viewModel.items.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Clear Completed") {
                    viewModel.clearCompleted()
                }
                .disabled(!hasCompletedOrCancelled)
                if let onClose {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Hide Transfers")
                }
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

    private var metrics: TransferMetrics? { viewModel.transferMetrics[item.id] }

    var body: some View {
        HStack {
            Image(systemName: item.direction == .upload ? "arrow.up.circle" : "arrow.down.circle")
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                if case .inProgress(let percent) = item.status, let metrics, let totalBytes = metrics.totalBytes {
                    ProgressView(value: Double(percent), total: 100)
                        .frame(maxWidth: 160)
                    Text(progressDetailText(metrics: metrics, totalBytes: totalBytes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if case .inProgress = item.status {
                    ProgressView()
                        .controlSize(.small)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

    private func progressDetailText(metrics: TransferMetrics, totalBytes: Int64) -> String {
        let transferred = Self.byteFormatter.string(fromByteCount: metrics.bytesTransferred)
        let total = Self.byteFormatter.string(fromByteCount: totalBytes)
        var parts = ["\(transferred) of \(total)"]
        if let bytesPerSecond = metrics.bytesPerSecond, bytesPerSecond > 0 {
            parts.append("\(Self.byteFormatter.string(fromByteCount: Int64(bytesPerSecond)))/s")
            let remainingBytes = totalBytes - metrics.bytesTransferred
            if remainingBytes > 0 {
                let etaSeconds = Double(remainingBytes) / bytesPerSecond
                if let eta = Self.durationFormatter.string(from: etaSeconds) {
                    parts.append("\(eta) remaining")
                }
            }
        }
        return parts.joined(separator: " · ")
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter
    }()

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
