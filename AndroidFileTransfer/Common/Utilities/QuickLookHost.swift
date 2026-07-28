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
    // QLPreviewPanelDataSource/Delegate's category methods below aren't
    // statically MainActor-isolated in the SDK (their protocol requirements
    // aren't annotated), even though QLPreviewPanel.dataSource/delegate are,
    // and AppKit only ever calls these on the main thread in practice.
    // MainActor.assumeIsolated is exactly the sanctioned escape hatch for
    // that mismatch, rather than a blanket nonisolated(unsafe).
    nonisolated(unsafe) let coordinator = QuickLookCoordinator()

    override var acceptsFirstResponder: Bool { true }

    override nonisolated func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }

    override nonisolated func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            panel.dataSource = coordinator
            panel.delegate = coordinator
        }
    }

    override nonisolated func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            panel.dataSource = nil
            panel.delegate = nil
        }
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
