/// Caps how many video thumbnails pull their full file at once. Scrolling a
/// grid of videos fires every visible cell's thumbnail load concurrently;
/// without this, several multi-hundred-MB pulls fight over the same USB/adb
/// connection and every one of them ends up slower than if they'd just run
/// one after another.
actor VideoThumbnailPullLimiter {
    static let shared = VideoThumbnailPullLimiter(maxConcurrent: 2)

    private let maxConcurrent: Int
    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(maxConcurrent: Int) {
        self.maxConcurrent = maxConcurrent
        self.available = maxConcurrent
    }

    func acquire() async {
        if available > 0 {
            available -= 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        if !waiters.isEmpty {
            waiters.removeFirst().resume()
        } else {
            available += 1
        }
    }
}
