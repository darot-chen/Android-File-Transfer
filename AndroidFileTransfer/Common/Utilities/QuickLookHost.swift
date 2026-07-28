import AppKit
import Quartz
import SwiftUI

/// Bridges SwiftUI to AppKit's QLPreviewPanel, which has no SwiftUI-native
/// equivalent on macOS. The panel asks the responder chain's first responder
/// whether it wants control; this view becomes first responder and supplies
/// itself as data source/delegate for the duration of the preview.
final class QuickLookCoordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    var previewItems: [URL] = []

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewItems.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        previewItems[index] as NSURL
    }
}

final class QuickLookHostView: NSView {
    let coordinator = QuickLookCoordinator()

    override var acceptsFirstResponder: Bool { true }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = coordinator
        panel.delegate = coordinator
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
    }

    func preview(url: URL) {
        coordinator.previewItems = [url]
        window?.makeFirstResponder(self)
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }
}

struct QuickLookHost: NSViewRepresentable {
    @Binding var urlToPreview: URL?

    func makeNSView(context: Context) -> QuickLookHostView {
        QuickLookHostView()
    }

    func updateNSView(_ nsView: QuickLookHostView, context: Context) {
        guard let url = urlToPreview else { return }
        nsView.preview(url: url)
        DispatchQueue.main.async { urlToPreview = nil }
    }
}
