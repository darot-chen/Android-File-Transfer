import AppKit
import SwiftUI

private struct ItemFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] { [:] }
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Publishes this view's frame (in the "marqueeSelection" named
    /// coordinate space) under `id`, for an enclosing
    /// `MarqueeSelectionContainer` to hit-test against while the user drags
    /// out a selection box.
    func reportingFrame(id: String) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ItemFramePreferenceKey.self,
                    value: [id: proxy.frame(in: .named("marqueeSelection"))]
                )
            }
        )
    }
}

/// Finder-icon-view-style interaction for a custom (non-List) grid: drag from
/// empty space to sweep out a selection rectangle, or click empty space to
/// clear the selection. Individual cells keep their own tap/drag gestures —
/// this only ever receives events that land in the gaps between/around them,
/// since AppKit hit-tests the foreground `content` (rendered on top) first.
struct MarqueeSelectionContainer<Content: View>: View {
    @Binding var selection: Set<String>
    @ViewBuilder var content: Content

    @State private var itemFrames: [String: CGRect] = [:]
    @State private var marqueeRect: CGRect?

    var body: some View {
        ZStack(alignment: .topLeading) {
            MarqueeInteractionLayer(itemFrames: $itemFrames, selection: $selection, marqueeRect: $marqueeRect)
            content
            if let marqueeRect {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.15))
                    .overlay(Rectangle().stroke(Color.accentColor, lineWidth: 1))
                    .frame(width: marqueeRect.width, height: marqueeRect.height)
                    .offset(x: marqueeRect.minX, y: marqueeRect.minY)
                    .allowsHitTesting(false)
            }
        }
        .coordinateSpace(name: "marqueeSelection")
        .onPreferenceChange(ItemFramePreferenceKey.self) { itemFrames = $0 }
    }
}

/// Direct AppKit mouse handling for the marquee background, instead of a
/// SwiftUI `DragGesture`, specifically to get `NSView.autoscroll(with:)` —
/// the standard AppKit mechanism that makes an enclosing NSScrollView (what
/// SwiftUI's `ScrollView` is backed by) scroll automatically while a drag
/// point is near or past its visible edge. SwiftUI's gesture system has no
/// equivalent, so a plain `DragGesture` marquee never scrolls to reveal more
/// content while selecting.
private struct MarqueeInteractionLayer: NSViewRepresentable {
    @Binding var itemFrames: [String: CGRect]
    @Binding var selection: Set<String>
    @Binding var marqueeRect: CGRect?

    func makeNSView(context: Context) -> InteractionView {
        InteractionView()
    }

    func updateNSView(_ nsView: InteractionView, context: Context) {
        nsView.itemFrames = itemFrames
        nsView.selectionBinding = $selection
        nsView.marqueeRectBinding = $marqueeRect
    }

    final class InteractionView: NSView {
        var itemFrames: [String: CGRect] = [:]
        var selectionBinding: Binding<Set<String>>?
        var marqueeRectBinding: Binding<CGRect?>?

        private var dragStart: NSPoint = .zero
        private var didDrag = false

        // SwiftUI's GeometryReader-reported frames (used for `itemFrames`)
        // are top-left-origin/y-down; matching that here is what keeps the
        // marquee rect's intersection math correct.
        override var isFlipped: Bool { true }

        override func mouseDown(with event: NSEvent) {
            dragStart = convert(event.locationInWindow, from: nil)
            didDrag = false
        }

        override func mouseDragged(with event: NSEvent) {
            autoscroll(with: event)

            let current = convert(event.locationInWindow, from: nil)
            let distance = hypot(current.x - dragStart.x, current.y - dragStart.y)
            guard distance > 2 else { return }
            didDrag = true

            let rect = CGRect(
                x: min(dragStart.x, current.x),
                y: min(dragStart.y, current.y),
                width: abs(current.x - dragStart.x),
                height: abs(current.y - dragStart.y)
            )
            marqueeRectBinding?.wrappedValue = rect
            selectionBinding?.wrappedValue = Set(itemFrames.filter { $0.value.intersects(rect) }.map(\.key))
        }

        override func mouseUp(with event: NSEvent) {
            if !didDrag {
                selectionBinding?.wrappedValue = []
            }
            marqueeRectBinding?.wrappedValue = nil
            didDrag = false
        }
    }
}
