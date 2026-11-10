import AppKit

/// Click-selection rules for icon grids, matching Finder's icon view:
/// a plain click selects only that item, and ⌘- or ⇧-click toggles just the
/// clicked item without touching anything else. Range selection is left to
/// list views, where rows have a clear linear order; in a 2D grid it picks
/// up items the user never pointed at.
enum GridSelection {
    static func applyingClick(on id: String, modifiers: NSEvent.ModifierFlags, to selection: Set<String>) -> Set<String> {
        guard modifiers.contains(.command) || modifiers.contains(.shift) else {
            return [id]
        }
        var updated = selection
        if updated.contains(id) {
            updated.remove(id)
        } else {
            updated.insert(id)
        }
        return updated
    }
}
