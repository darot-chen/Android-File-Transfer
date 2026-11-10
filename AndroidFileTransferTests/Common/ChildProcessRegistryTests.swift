import Foundation
import Testing
@testable import AndroidFileTransfer

@Suite
struct ChildProcessRegistryTests {
    @Test
    func terminateAllStopsRegisteredProcesses() throws {
        let registry = ChildProcessRegistry()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["30"]
        try process.run()

        registry.register(process)
        #expect(registry.count == 1)

        registry.terminateAll()
        process.waitUntilExit()

        #expect(!process.isRunning)
        #expect(registry.count == 0)
    }

    @Test
    func unregisterRemovesAProcess() throws {
        let registry = ChildProcessRegistry()
        let process = Process()
        registry.register(process)
        registry.unregister(process)
        #expect(registry.count == 0)
    }
}
