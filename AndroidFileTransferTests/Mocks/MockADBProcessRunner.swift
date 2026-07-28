@testable import AndroidFileTransfer

actor MockADBProcessRunner: ADBProcessRunning {
    private var results: [Result<ADBProcessResult, Error>]
    private(set) var recordedArguments: [[String]] = []

    init(result: Result<ADBProcessResult, Error>) {
        self.results = [result]
    }

    /// Returns each result in order for successive calls, then keeps
    /// returning the last one — for testing retry/fallback sequences.
    init(results: [Result<ADBProcessResult, Error>]) {
        self.results = results
    }

    func run(arguments: [String]) async throws -> ADBProcessResult {
        recordedArguments.append(arguments)
        let result = results.count > 1 ? results.removeFirst() : results[0]
        return try result.get()
    }
}
