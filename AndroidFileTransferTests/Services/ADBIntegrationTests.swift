import Testing
@testable import AndroidFileTransfer

/// Exercises the real bundled `adb` binary (not a mock) to prove the
/// end-to-end wiring works: binary lookup, process spawn, and output parsing.
@Suite
struct ADBIntegrationTests {
    @Test
    func realBundledBinaryReportsAVersion() async throws {
        let service = ADBService(runner: ADBProcessRunner())

        let version = try await service.version()

        #expect(!version.isEmpty)
    }

    @Test
    func realBundledBinaryStartsServer() async throws {
        let service = ADBService(runner: ADBProcessRunner())

        try await service.startServer()
    }
}
