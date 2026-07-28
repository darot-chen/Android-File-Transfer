import AppKit
import SwiftUI

struct LogsView: View {
    let logStore: LogStore
    @State private var levelFilter: LogLevel?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Logs")
                    .font(.headline)
                Spacer()
                Picker("Level", selection: $levelFilter) {
                    Text("All").tag(LogLevel?.none)
                    ForEach(LogLevel.allCases) { level in
                        Text(level.rawValue.capitalized).tag(LogLevel?.some(level))
                    }
                }
                .frame(width: 140)
                Button("Clear") {
                    logStore.clear()
                }
                Button("Export…") {
                    exportLogs()
                }
            }
            .padding()

            Divider()

            List(filteredEntries) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(entry.level.rawValue.uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(color(for: entry.level))
                        Text(entry.category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(entry.timestamp, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.message)
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
        .frame(minWidth: 520, minHeight: 400)
    }

    private var filteredEntries: [LogEntry] {
        guard let levelFilter else { return logStore.entries }
        return logStore.entries.filter { $0.level == levelFilter }
    }

    private func color(for level: LogLevel) -> Color {
        switch level {
        case .debug: .secondary
        case .info: .blue
        case .warning: .orange
        case .error: .red
        }
    }

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "AndroidFileTransfer.log"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? logStore.exportText().write(to: url, atomically: true, encoding: .utf8)
    }
}
