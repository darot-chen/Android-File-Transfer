enum PathVisibility {
    /// True if any component of the path (not just the last one) starts
    /// with "." — e.g. "/sdcard/DCIM/.thumbnails/cache.jpg" is hidden even
    /// though "cache.jpg" itself isn't, because it lives inside a hidden
    /// folder.
    static func isHidden(_ path: String) -> Bool {
        path.split(separator: "/").contains { $0.hasPrefix(".") }
    }
}
