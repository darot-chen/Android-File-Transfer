import SwiftUI

struct SettingsView: View {
    @State var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: Binding(
                    get: { viewModel.appearance },
                    set: { viewModel.appearance = $0 }
                )) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
            }

            Section("Transfers") {
                Stepper(
                    "Concurrent transfers: \(viewModel.maxConcurrentTransfers)",
                    value: Binding(
                        get: { viewModel.maxConcurrentTransfers },
                        set: { viewModel.maxConcurrentTransfers = $0 }
                    ),
                    in: 1...8
                )

                HStack {
                    Text("Default download folder")
                    Spacer()
                    Text(viewModel.defaultDownloadDirectory.isEmpty ? "Ask each time" : viewModel.defaultDownloadDirectory)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Choose…") {
                        if let url = FilePanelPresenter.chooseDownloadDirectory() {
                            viewModel.defaultDownloadDirectory = url.path
                        }
                    }
                    if !viewModel.defaultDownloadDirectory.isEmpty {
                        Button("Reset") {
                            viewModel.defaultDownloadDirectory = ""
                        }
                    }
                }
            }

            Section("Advanced") {
                TextField("adb binary override (optional)", text: Binding(
                    get: { viewModel.adbBinaryPathOverride },
                    set: { viewModel.adbBinaryPathOverride = $0 }
                ))
                Text("Leave blank to use the bundled adb. Takes effect the next time the app connects.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 320)
    }
}
