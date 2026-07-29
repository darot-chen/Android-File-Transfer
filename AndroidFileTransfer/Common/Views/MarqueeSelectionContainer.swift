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
/// since SwiftUI hit-tests the foreground `content` first.
struct MarqueeSelectionContainer<Content: View>: View {
    @Binding var selection: Set<String>
    @ViewBuilder var content: Content

    @State private var itemFrames: [String: CGRect] = [:]
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?

    private var marqueeRect: CGRect? {
        guard let dragStart, let dragCurrent else { return nil }
        return CGRect(
            x: min(dragStart.x, dragCurrent.x),
            y: min(dragStart.y, dragCurrent.y),
            width: abs(dragCurrent.x - dragStart.x),
            height: abs(dragCurrent.y - dragStart.y)
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            backgroundInteractionLayer
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

    private var backgroundInteractionLayer: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .named("marqueeSelection"))
                    .onChanged { value in
                        if dragStart == nil { dragStart = value.startLocation }
                        dragCurrent = value.location
                        if let marqueeRect {
                            selection = Set(itemFrames.filter { $0.value.intersects(marqueeRect) }.map(\.key))
                        }
                    }
                    .onEnded { _ in
                        dragStart = nil
                        dragCurrent = nil
                    }
            )
            .onTapGesture {
                selection.removeAll()
            }
    }
}
