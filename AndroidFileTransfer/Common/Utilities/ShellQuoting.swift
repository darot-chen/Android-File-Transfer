enum ShellQuoting {
    /// Wraps a string in POSIX single quotes so it's safe to interpolate into
    /// a remote shell command line, regardless of what it contains.
    ///
    /// `adb shell` does not reliably escape multiple argv elements when
    /// reconstructing the command it sends to the device's shell — passing
    /// path components as separate `Process` arguments (as one naturally
    /// would, since that's exactly how `Process` itself is safe against
    /// *local* shell injection) is not actually safe here, because adb
    /// rejoins them into a single string on the device side. Every value
    /// interpolated into a remote `shell` command must go through this.
    static func quote(_ argument: String) -> String {
        "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
