import Foundation
import UniformTypeIdentifiers

enum RemoteFileDragProvider {
    /// Builds an NSItemProvider that lazily pulls `file` to a temp location
    /// only once a drop actually completes, promised under its real name and
    /// extension.
    ///
    /// Uses the legacy `.onDrag`/NSItemProvider API instead of SwiftUI's
    /// Transferable/`.draggable(_:)`: verified live against a real device
    /// that `FileRepresentation`'s promise mechanism ignored the exported
    /// file's actual name entirely — dragged files landed in Finder named
    /// "data"/"data 2" with a generic unknown-type icon, regardless of the
    /// real filename, for every file dragged. Setting `suggestedName`
    /// explicitly on the item provider here is what actually controls the
    /// name Finder gives the dropped file.
    static func make(file: RemoteFile, serial: String, transferService: TransferServiceProtocol) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.suggestedName = file.name
        provider.registerFileRepresentation(forTypeIdentifier: UTType.data.identifier, visibility: .all) { completion in
            Task {
                let destination = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString, isDirectory: true)
                try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                let fileURL = destination.appendingPathComponent(file.name)
                do {
                    for try await _ in transferService.pull(remotePath: file.path, localURL: fileURL, on: serial) {}
                    completion(fileURL, false, nil)
                } catch {
                    completion(nil, false, error)
                }
            }
            return nil
        }
        return provider
    }
}
