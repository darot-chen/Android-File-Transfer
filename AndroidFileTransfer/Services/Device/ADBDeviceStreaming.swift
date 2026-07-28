protocol ADBDeviceStreaming: Sendable {
    /// Yields the raw, de-framed payload of each `adb track-devices -l` update:
    /// a snapshot of the full device list as text, one device per line.
    func deviceListSnapshots() -> AsyncThrowingStream<String, Error>
}
