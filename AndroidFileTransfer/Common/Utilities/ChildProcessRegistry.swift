import Foundation
import Synchronization

/// Tracks every adb process the app launches so they can all be stopped when
/// the app quits. Without this, long-running ones (notably the
/// `adb track-devices` device watcher, which never exits on its own) were
/// left running in the background after every quit.
///
/// This doesn't stop the adb *server* daemon, which adb itself keeps running
/// between sessions by design.
final class ChildProcessRegistry: Sendable {
    static let shared = ChildProcessRegistry()

    private let processes = Mutex<[ObjectIdentifier: Process]>([:])

    func register(_ process: Process) {
        processes.withLock { $0[ObjectIdentifier(process)] = process }
    }

    func unregister(_ process: Process) {
        processes.withLock { _ = $0.removeValue(forKey: ObjectIdentifier(process)) }
    }

    var count: Int {
        processes.withLock { $0.count }
    }

    func terminateAll() {
        processes.withLock { running in
            for process in running.values where process.isRunning {
                process.terminate()
            }
            running.removeAll()
        }
    }
}
