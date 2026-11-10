import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        ChildProcessRegistry.shared.terminateAll()
    }
}
