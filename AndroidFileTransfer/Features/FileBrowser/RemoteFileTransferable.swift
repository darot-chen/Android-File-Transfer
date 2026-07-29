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
        // .data is the correct generic "arbitrary file bytes" type here —
        // it's concrete/exportable (unlike .item, which is too abstract for
        // NSItemProvider to treat as real exportable content and silently
        // produced *no* drag at all when tried). The actual filename/
        // extension on disk comes from `destination` below, independent of
        // this declared UTType.
        FileRepresentation(exportedContentType: .data) { item in
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent(item.remoteFile.name)
            for try await _ in item.transferService.pull(remotePath: item.remoteFile.path, localURL: destination, on: item.serial) {}
            return SentTransferredFile(destination)
        }
    }
}
