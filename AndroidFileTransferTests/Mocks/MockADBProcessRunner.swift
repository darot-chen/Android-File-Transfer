@testable import AndroidFileTransfer

actor MockADBProcessRunner: ADBProcessRunning {
    private let result: Result<ADBProcessResult, Error>
    private(set) var recordedArguments: [[String]] = []

    init(result: Result<ADBProcessResult, Error>) {
        self.result = result
    }

    func run(arguments: [String]) async throws -> ADBProcessResult {
        recordedArguments.append(arguments)
        return try result.get()
    }
}
