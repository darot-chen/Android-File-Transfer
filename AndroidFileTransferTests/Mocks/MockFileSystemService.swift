@testable import AndroidFileTransfer

struct DeleteCall: Sendable, Equatable {
    let path: String
    let serial: String
}

struct RenameCall: Sendable, Equatable {
    let from: String
    let to: String
    let serial: String
}

struct CreateFolderCall: Sendable, Equatable {
    let path: String
    let serial: String
}

actor MockFileSystemService: FileSystemServiceProtocol {
    private var listingResult: Result<[RemoteFile], Error>
    private var searchResult: Result<[String], Error>
    var deleteError: Error?
    var renameError: Error?
    var createFolderError: Error?

    private(set) var deleteCalls: [DeleteCall] = []
    private(set) var renameCalls: [RenameCall] = []
    private(set) var createFolderCalls: [CreateFolderCall] = []

    init(listingResult: Result<[RemoteFile], Error> = .success([]), searchResult: Result<[String], Error> = .success([])) {
        self.listingResult = listingResult
        self.searchResult = searchResult
    }

    func setListingResult(_ result: Result<[RemoteFile], Error>) {
        listingResult = result
    }

    func setDeleteError(_ error: Error?) {
        deleteError = error
    }

    func listDirectory(path: String, on serial: String) async throws -> [RemoteFile] {
        try listingResult.get()
    }

    func delete(path: String, on serial: String) async throws {
        deleteCalls.append(DeleteCall(path: path, serial: serial))
        if let deleteError { throw deleteError }
    }

    func rename(from oldPath: String, to newPath: String, on serial: String) async throws {
        renameCalls.append(RenameCall(from: oldPath, to: newPath, serial: serial))
        if let renameError { throw renameError }
    }

    func createFolder(path: String, on serial: String) async throws {
        createFolderCalls.append(CreateFolderCall(path: path, serial: serial))
        if let createFolderError { throw createFolderError }
    }

    func search(query: String, in path: String, on serial: String) async throws -> [String] {
        try searchResult.get()
    }
}
