import Foundation
import Observation

struct TransferMetrics: Sendable, Equatable {
    let bytesTransferred: Int64
    let totalBytes: Int64?
    let bytesPerSecond: Double?
    fileprivate let sampledAt: Date
}

@MainActor
@Observable
final class TransferQueueViewModel {
    private(set) var items: [TransferItem] = []
    private(set) var transferMetrics: [UUID: TransferMetrics] = [:]

    private let transferService: TransferServiceProtocol
    private let historyStore: TransferHistoryStoring
    private var maxConcurrent: Int
    private var runningTasks: [UUID: Task<Void, Never>] = [:]

    init(transferService: TransferServiceProtocol, historyStore: TransferHistoryStoring, maxConcurrent: Int = 2) {
        self.transferService = transferService
        self.historyStore = historyStore
        self.maxConcurrent = maxConcurrent
        self.items = historyStore.load().map { item in
            // A prior run may have exited mid-transfer; nothing is actually
            // still running now, so surface those as failed rather than
            // silently stuck "in progress" forever.
            guard case .inProgress = item.status else { return item }
            var resumed = item
            resumed.status = .failed(message: "Interrupted")
            return resumed
        }
    }

    func enqueueUpload(localURL: URL, remotePath: String, serial: String) {
        enqueue(TransferItem(
            id: UUID(), direction: .upload, serial: serial,
            localURL: localURL, remotePath: remotePath, status: .queued, createdAt: Date()
        ))
    }

    func enqueueDownload(remotePath: String, localURL: URL, serial: String, sizeBytes: Int64? = nil) {
        enqueue(TransferItem(
            id: UUID(), direction: .download, serial: serial,
            localURL: localURL, remotePath: remotePath, status: .queued, createdAt: Date(),
            sizeBytes: sizeBytes
        ))
    }

    func retry(_ item: TransferItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].status = .queued
        persist()
        processQueue()
    }

    func cancel(_ item: TransferItem) {
        runningTasks[item.id]?.cancel()
    }

    func updateMaxConcurrent(_ newValue: Int) {
        maxConcurrent = newValue
        processQueue()
    }

    func clearCompleted() {
        items.removeAll { item in
            switch item.status {
            case .completed, .cancelled: true
            default: false
            }
        }
        persist()
    }

    private func enqueue(_ item: TransferItem) {
        items.append(item)
        persist()
        processQueue()
    }

    private var runningCount: Int {
        items.reduce(into: 0) { count, item in
            if case .inProgress = item.status { count += 1 }
        }
    }

    private func processQueue() {
        while runningCount < maxConcurrent,
              let index = items.firstIndex(where: { if case .queued = $0.status { return true } else { return false } }) {
            start(at: index)
        }
    }

    private func start(at index: Int) {
        let item = items[index]
        items[index].status = .inProgress(percent: 0)
        persist()

        let stream: AsyncThrowingStream<TransferProgress, Error> = switch item.direction {
        case .upload:
            transferService.push(localURL: item.localURL, remotePath: item.remotePath, on: item.serial)
        case .download:
            transferService.pull(remotePath: item.remotePath, localURL: item.localURL, on: item.serial, expectedSize: item.sizeBytes)
        }

        runningTasks[item.id] = Task { [weak self] in
            guard let self else { return }
            do {
                for try await progress in stream {
                    if Task.isCancelled { break }
                    self.recordMetrics(itemID: item.id, progress: progress)
                    self.update(itemID: item.id) { $0.status = .inProgress(percent: progress.percent) }
                }
                self.update(itemID: item.id) { $0.status = Task.isCancelled ? .cancelled : .completed }
            } catch {
                self.update(itemID: item.id) { $0.status = Task.isCancelled ? .cancelled : .failed(message: String(describing: error)) }
            }
            self.transferMetrics[item.id] = nil
            self.runningTasks[item.id] = nil
            self.persist()
            self.processQueue()
        }
    }

    // Speed is derived session-side from consecutive byte samples (adb itself
    // never reports throughput mid-transfer — see TransferService), smoothed
    // with a simple exponential moving average so brief stalls in the
    // underlying `stat`/file-size poll don't make the displayed rate jump around.
    private func recordMetrics(itemID: UUID, progress: TransferProgress) {
        let now = Date()
        var bytesPerSecond: Double?
        if let previous = transferMetrics[itemID] {
            let deltaBytes = progress.bytesTransferred - previous.bytesTransferred
            let deltaTime = now.timeIntervalSince(previous.sampledAt)
            if deltaTime > 0.05, deltaBytes >= 0 {
                let instantaneous = Double(deltaBytes) / deltaTime
                bytesPerSecond = previous.bytesPerSecond.map { $0 * 0.6 + instantaneous * 0.4 } ?? instantaneous
            } else {
                bytesPerSecond = previous.bytesPerSecond
            }
        }
        transferMetrics[itemID] = TransferMetrics(
            bytesTransferred: progress.bytesTransferred,
            totalBytes: progress.totalBytes,
            bytesPerSecond: bytesPerSecond,
            sampledAt: now
        )
    }

    private func update(itemID: UUID, _ mutate: (inout TransferItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        mutate(&items[index])
    }

    private func persist() {
        historyStore.save(items)
    }
}
