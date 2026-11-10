import AppKit
import SwiftUI

/// Replaces SwiftUI's tap/`.onDrag` gestures for a single grid cell with
/// direct AppKit mouse handling.
///
/// SwiftUI's `.onDrag`/`.draggable` only ever export a single item per drag
/// gesture, regardless of how many items are selected — real multi-item
/// drag-out requires calling AppKit's `beginDraggingSession(with:event:source:)`
/// directly with one `NSDraggingItem` per selected file, which in turn needs
/// the actual mouse-down `NSEvent`, not just a SwiftUI gesture value. This
/// view owns mouse handling for the cell so there's exactly one system
/// deciding what a click/drag means, instead of two competing ones:
///
/// - Plain click on an unselected item: select just that item.
/// - ⌘/⇧-click: toggle that item (delegated back to the caller).
/// - Plain click on an item that's already part of a multi-selection:
///   selection is preserved (in case this turns into a drag of the whole
///   selection) and only collapses to just this item on mouse-up if no
///   drag happened — matching Finder.
/// - Drag: exports the whole current selection if the dragged item is part
///   of one, otherwise just that item.
/// - Double-click: open.
///
/// Right-clicks aren't handled here, so they fall through the responder
/// chain to SwiftUI's own `.contextMenu` on the same cell as normal.
struct CellInteractionOverlay: NSViewRepresentable {
    let itemID: String
    let isPartOfMultiSelection: Bool
    let onPlainSelect: () -> Void
    let onModifiedSelect: () -> Void
    let onOpen: () -> Void
    let dragItemsProvider: () -> [NSDraggingItem]

    func makeNSView(context: Context) -> InteractionView {
        InteractionView()
    }

    func updateNSView(_ nsView: InteractionView, context: Context) {
        nsView.itemID = itemID
        nsView.isPartOfMultiSelection = isPartOfMultiSelection
        nsView.onPlainSelect = onPlainSelect
        nsView.onModifiedSelect = onModifiedSelect
        nsView.onOpen = onOpen
        nsView.dragItemsProvider = dragItemsProvider
    }

    final class InteractionView: NSView, NSDraggingSource {
        var itemID: String = ""
        var isPartOfMultiSelection = false
        var onPlainSelect: (() -> Void)?
        var onModifiedSelect: (() -> Void)?
        var onOpen: (() -> Void)?
        var dragItemsProvider: (() -> [NSDraggingItem])?

        private var mouseDownLocation: NSPoint = .zero
        private var didStartDrag = false

        override func mouseDown(with event: NSEvent) {
            if event.clickCount >= 2 {
                onOpen?()
                return
            }

            let modifiers = event.modifierFlags
            if modifiers.contains(.command) || modifiers.contains(.shift) {
                onModifiedSelect?()
            } else if !isPartOfMultiSelection {
                onPlainSelect?()
            }
            // Plain click on an already-multi-selected item: leave the
            // selection untouched here so a drag can pick up the whole
            // selection; mouseUp collapses it if this wasn't a drag.

            mouseDownLocation = event.locationInWindow
            didStartDrag = false
        }

        override func mouseDragged(with event: NSEvent) {
            guard !didStartDrag else { return }
            let distance = hypot(event.locationInWindow.x - mouseDownLocation.x, event.locationInWindow.y - mouseDownLocation.y)
            guard distance > 3 else { return }
            didStartDrag = true

            guard let dragItems = dragItemsProvider?(), !dragItems.isEmpty else { return }
            beginDraggingSession(with: dragItems, event: event, source: self)
        }

        override func mouseUp(with event: NSEvent) {
            defer { didStartDrag = false }
            guard !didStartDrag else { return }
            let modifiers = event.modifierFlags
            guard !modifiers.contains(.command), !modifiers.contains(.shift), isPartOfMultiSelection else { return }
            onPlainSelect?()
        }

        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            .copy
        }
    }
}
