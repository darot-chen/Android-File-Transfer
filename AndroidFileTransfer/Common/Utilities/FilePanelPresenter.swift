import AppKit

@MainActor
enum FilePanelPresenter {
    static func chooseSaveLocation(suggestedName: String, defaultDirectory: String = "") -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        if !defaultDirectory.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: defaultDirectory)
        }
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseFileToUpload() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseDownloadDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}
