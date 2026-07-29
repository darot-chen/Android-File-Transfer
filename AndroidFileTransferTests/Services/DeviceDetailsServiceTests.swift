import Testing
@testable import AndroidFileTransfer

private struct StubADBProcessRunner: ADBProcessRunning {
    let handler: @Sendable ([String]) async throws -> ADBProcessResult

    func run(arguments: [String]) async throws -> ADBProcessResult {
        try await handler(arguments)
    }
}

@Suite
struct DeviceDetailsServiceTests {
    @Test
    func fetchDetailsParsesVersionAndStorage() async {
        let runner = StubADBProcessRunner { arguments in
            let command = arguments.last ?? ""
            if command.contains("getprop") {
                return ADBProcessResult(exitCode: 0, standardOutput: "16\n", standardError: "")
            }
            if command.contains("df") {
                return ADBProcessResult(
                    exitCode: 0,
                    standardOutput: """
                    Filesystem     1K-blocks      Used Available Use% Mounted on
                    /dev/fuse      476403680 151452328 324414484  32% /storage/emulated

                    """,
                    standardError: ""
                )
            }
            return ADBProcessResult(exitCode: 1, standardOutput: "", standardError: "unexpected command")
        }
        let service = DeviceDetailsService(runner: runner)

        let details = await service.fetchDetails(serial: "SERIAL")

        #expect(details.androidVersion == "16")
        #expect(details.storage == DeviceStorage(totalBytes: 476_403_680 * 1024, freeBytes: 324_414_484 * 1024))
    }

    @Test
    func fetchDetailsOmitsFieldsWhenCommandsFail() async {
        let runner = StubADBProcessRunner { _ in
            ADBProcessResult(exitCode: 1, standardOutput: "", standardError: "device offline")
        }
        let service = DeviceDetailsService(runner: runner)

        let details = await service.fetchDetails(serial: "SERIAL")

        #expect(details.androidVersion == nil)
        #expect(details.storage == nil)
    }
}
