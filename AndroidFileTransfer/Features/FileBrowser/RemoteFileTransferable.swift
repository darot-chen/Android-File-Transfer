import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Drag-out promise: SwiftUI/AppKit invoke `transferRepresentation`'s closure
/// only once a drop actually completes, pulling the remote file to a temp
/// location on demand — the native equivalent of NSFilePromiseProvider.
struct RemoteFileTransferable: Transferable {
    let remoteFile: RemoteFile
    let serial: String
    let transferService: TransferServiceProtocol

    static var transferRepresentation: some TransferRepresentation {
        // .item (not .data): .data has no associated filename extension, and
        // Finder names a dropped file promise after the *declared UTType*
        // when it can't resolve one from content, not the promise URL's own
        // extension — so .data silently produced extensionless drops for
        // every file type. .item is the generic "any file system item" type
        // and lets Finder fall back to the actual exported file's name/extension.
        FileRepresentation(exportedContentType: .item) { item in
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent(item.remoteFile.name)
            for try await _ in item.transferService.pull(remotePath: item.remoteFile.path, localURL: destination, on: item.serial) {}
            return SentTransferredFile(destination)
        }
    }
}
