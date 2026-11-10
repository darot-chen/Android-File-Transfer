import Foundation

/// Caps how many thumbnail pulls run at once. Scrolling a grid fires every
/// visible cell's thumbnail load together; without a cap, dozens of pulls
/// fight over the same USB/adb connection and every one of them finishes
/// late, so nothing appears for a long time.
///
/// A cell that scrolls away while still waiting gives up its place
/// immediately (its `.task` is cancelled), so the queue only ever holds
/// cells that are still on screen.
actor PullLimiter {
    static let images = PullLimiter(maxConcurrent: 3)
    /// Video thumbnails pull the whole (often hundreds of MB) file, so fewer at once.
    static let videos = PullLimiter(maxConcurrent: 2)

    private var available: Int
    private var waiters: [(id: UUID, continuation: CheckedContinuation<Bool, Never>)] = []

    init(maxConcurrent: Int) {
        self.available = maxConcurrent
    }

    /// Waits for a free slot. Returns `false` without taking a slot if the
    /// calling task is cancelled first; only call `release()` after `true`.
    func acquire() async -> Bool {
        if Task.isCancelled { return false }
        if available > 0 {
            available -= 1
            return true
        }
        let id = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(returning: false)
                } else {
                    waiters.append((id, continuation))
                }
            }
        } onCancel: {
            Task { await self.cancelWaiter(id) }
        }
    }

    func release() {
        if waiters.isEmpty {
            available += 1
        } else {
            waiters.removeFirst().continuation.resume(returning: true)
        }
    }

    var waitingCount: Int { waiters.count }

    private func cancelWaiter(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(returning: false)
    }
}
