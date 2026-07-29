import AppKit
import Foundation
import ObjectiveC
import UniformTypeIdentifiers

enum RemoteFileDragProvider {
    /// Builds an NSItemProvider that lazily pulls `file` to a temp location
    /// only once a drop actually completes, promised under its real name and
    /// extension.
    ///
    /// The pull is enqueued through `transferQueue` — the same queue
    /// "Download…" uses — rather than called directly, so a drag-out shows
    /// up with real progress in the Transfers panel instead of silently
    /// pulling with no visible feedback at all.
    ///
    /// Uses the legacy `.onDrag`/NSItemProvider API instead of SwiftUI's
    /// Transferable/`.draggable(_:)`: verified live against a real device
    /// that `FileRepresentation`'s promise mechanism ignored the exported
    /// file's actual name entirely — dragged files landed in Finder named
    /// "data"/"data 2" with a generic unknown-type icon, regardless of the
    /// real filename, for every file dragged. Setting `suggestedName`
    /// explicitly on the item provider here is what actually controls the
    /// name Finder gives the dropped file.
    static func make(file: RemoteFile, serial: String, transferQueue: TransferQueueViewModel) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.suggestedName = file.name
        provider.registerFileRepresentation(forTypeIdentifier: UTType.data.identifier, visibility: .all) { completion in
            Task {
                let destination = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString, isDirectory: true)
                try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                let fileURL = destination.appendingPathComponent(file.name)
                do {
                    let itemID = await transferQueue.enqueueDownload(
                        remotePath: file.path, localURL: fileURL, serial: serial,
                        sizeBytes: file.size > 0 ? file.size : nil
                    )
                    try await transferQueue.waitForCompletion(of: itemID)
                    completion(fileURL, false, nil)
                } catch {
                    completion(nil, false, error)
                }
            }
            return nil
        }
        return provider
    }

    /// Builds an `NSDraggingItem` for a genuine multi-item AppKit drag
    /// session (`NSView.beginDraggingSession(with:event:source:)`) — needed
    /// because SwiftUI's `.onDrag`/`.draggable` only ever export a single
    /// item per gesture regardless of selection. Uses `NSFilePromiseProvider`
    /// rather than `NSItemProvider` since that's what actually conforms to
    /// `NSPasteboardWriting` for this API, with the promise's filename
    /// controlled explicitly via the delegate for the same reason `make(_:)`
    /// above sets `suggestedName`, and the same transfer-queue routing for
    /// visible progress.
    static func makeDraggingItem(file: RemoteFile, serial: String, transferQueue: TransferQueueViewModel) -> NSDraggingItem {
        let delegate = FilePromiseDelegate(file: file, serial: serial, transferQueue: transferQueue)
        let provider = NSFilePromiseProvider(fileType: UTType.data.identifier, delegate: delegate)
        // NSFilePromiseProvider.delegate is weak, and nothing else owns this
        // delegate instance — associate it with the provider itself so it
        // stays alive for as long as the drag session needs it.
        objc_setAssociatedObject(provider, &filePromiseDelegateAssociationKey, delegate, .OBJC_ASSOCIATION_RETAIN)
        let item = NSDraggingItem(pasteboardWriter: provider)
        item.setDraggingFrame(NSRect(x: 0, y: 0, width: 100, height: 100), contents: nil)
        return item
    }

    /// Builds the dragging items for a whole multi-file selection with one
    /// clean drag image (an icon + a count badge) instead of AppKit's
    /// default: leaving every item's `contents` unset makes it auto-generate
    /// a full icon-and-filename image per item and cascade them all in a
    /// diagonal stack — unreadable and slow to render past a handful of
    /// files. Only the first item gets a visible image; the rest are
    /// functionally real drag items (so all N files are still part of the
    /// drop) but rendered blank so they don't clutter the drag visually.
    static func makeDraggingItems(files: [RemoteFile], serial: String, transferQueue: TransferQueueViewModel) -> [NSDraggingItem] {
        guard !files.isEmpty else { return [] }
        let frame = NSRect(x: 0, y: 0, width: 64, height: 64)
        return files.enumerated().map { index, file in
            let item = makeDraggingItem(file: file, serial: serial, transferQueue: transferQueue)
            let image = index == 0 ? Self.multiFileDragImage(count: files.count, size: frame.size) : NSImage(size: frame.size)
            item.setDraggingFrame(frame, contents: image)
            return item
        }
    }

    private static func multiFileDragImage(count: Int, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSImage(systemSymbolName: "doc.on.doc.fill", accessibilityDescription: nil)?
            .draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 0.9)

        if count > 1 {
            let badgeDiameter: CGFloat = size.width * 0.42
            let badgeRect = NSRect(x: size.width - badgeDiameter, y: size.height - badgeDiameter, width: badgeDiameter, height: badgeDiameter)
            NSColor.controlAccentColor.setFill()
            NSBezierPath(ovalIn: badgeRect).fill()

            let text = "\(count)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: badgeDiameter * 0.5),
                .foregroundColor: NSColor.white,
            ]
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: NSPoint(x: badgeRect.midX - textSize.width / 2, y: badgeRect.midY - textSize.height / 2),
                withAttributes: attributes
            )
        }

        image.unlockFocus()
        return image
    }
}

private nonisolated(unsafe) var filePromiseDelegateAssociationKey: UInt8 = 0

private final class FilePromiseDelegate: NSObject, NSFilePromiseProviderDelegate, @unchecked Sendable {
    let file: RemoteFile
    let serial: String
    let transferQueue: TransferQueueViewModel

    init(file: RemoteFile, serial: String, transferQueue: TransferQueueViewModel) {
        self.file = file
        self.serial = serial
        self.transferQueue = transferQueue
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        file.name
    }

    // Called by AppKit on a background queue once the drop target actually
    // wants the bytes — matching the same "only pull if the user follows
    // through" laziness as the single-item NSItemProvider path.
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        // completionHandler isn't Sendable-annotated in the AppKit overlay,
        // so it can't be captured directly by a Task; box it so the compiler
        // can see the capture itself is safe (it's only ever called once).
        let box = CompletionHandlerBox(completionHandler)
        Task {
            do {
                let itemID = await transferQueue.enqueueDownload(
                    remotePath: file.path, localURL: url, serial: serial,
                    sizeBytes: file.size > 0 ? file.size : nil
                )
                try await transferQueue.waitForCompletion(of: itemID)
                box.call(nil)
            } catch {
                box.call(error)
            }
        }
    }
}

private final class CompletionHandlerBox: @unchecked Sendable {
    private let handler: (Error?) -> Void
    init(_ handler: @escaping (Error?) -> Void) { self.handler = handler }
    func call(_ error: Error?) { handler(error) }
}
