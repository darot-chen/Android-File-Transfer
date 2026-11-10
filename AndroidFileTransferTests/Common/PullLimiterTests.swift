import Testing
@testable import AndroidFileTransfer

@Suite
struct PullLimiterTests {
    @Test
    func grantsUpToCapacityThenQueues() async throws {
        let limiter = PullLimiter(maxConcurrent: 2)
        #expect(await limiter.acquire())
        #expect(await limiter.acquire())

        let third = Task { await limiter.acquire() }
        try await waitUntil { await limiter.waitingCount == 1 }

        await limiter.release()
        #expect(await third.value)
        #expect(await limiter.waitingCount == 0)
    }

    @Test
    func cancelledWaiterLeavesTheQueueWithoutTakingASlot() async throws {
        let limiter = PullLimiter(maxConcurrent: 1)
        #expect(await limiter.acquire())

        let scrolledAway = Task { await limiter.acquire() }
        try await waitUntil { await limiter.waitingCount == 1 }
        scrolledAway.cancel()

        #expect(await scrolledAway.value == false)
        try await waitUntil { await limiter.waitingCount == 0 }

        // The slot is still only held once, so releasing frees it for the next caller.
        await limiter.release()
        #expect(await limiter.acquire())
    }

    @Test
    func alreadyCancelledTaskDoesNotTakeASlot() async {
        let limiter = PullLimiter(maxConcurrent: 1)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await limiter.acquire()
        }
        #expect(await task.value == false)
        #expect(await limiter.acquire())
    }

    private func waitUntil(_ condition: () async -> Bool) async throws {
        for _ in 0..<200 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Timed out waiting for condition")
    }
}
