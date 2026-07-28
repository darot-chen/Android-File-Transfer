import ImageIO
import SwiftUI

/// Shows a real, lazily-loaded thumbnail for image files (pulled once to a
/// per-launch cache, then decoded at a small pixel size — never the full
/// bitmap in memory), and a representative icon for everything else.
///
/// Videos deliberately don't get a pulled-frame thumbnail: real device
/// videos commonly run tens to hundreds of MB, and auto-pulling one per
/// grid cell while scrolling a library of a thousand-plus videos would be
/// slow and bandwidth-heavy for no real benefit over an icon. Use Quick
/// Look (which already pulls on demand for a single file) to actually see
/// a video.
struct RemoteThumbnailView: View {
    let file: RemoteFile
    let serial: String
    let transferService: TransferServiceProtocol

    @State private var thumbnailImage: NSImage?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let thumbnailImage {
                Image(nsImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: iconName)
                    .foregroundStyle(file.isDirectory ? .blue : .secondary)
            }
        }
        .task(id: file.path) {
            await loadIfNeeded()
        }
    }

    private var iconName: String {
        if file.isSymlink { return "link" }
        if file.isDirectory { return "folder.fill" }
        switch FileCategory.category(forFileName: file.name) {
        case .videos: return "film"
        case .audio: return "waveform"
        case .archives: return "doc.zipper"
        case .apks: return "shippingbox"
        case .documents: return "doc.text"
        case .images: return "photo"
        case nil: return "doc"
        }
    }

    private func loadIfNeeded() async {
        guard !file.isDirectory, !loadFailed, FileCategory.category(forFileName: file.name) == .images else { return }

        let cacheURL = ThumbnailCache.localURL(for: file.path)
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            thumbnailImage = Self.downsampled(cacheURL)
            return
        }

        do {
            for try await _ in transferService.pull(remotePath: file.path, localURL: cacheURL, on: serial) {
                if Task.isCancelled { return }
            }
            if Task.isCancelled { return }
            thumbnailImage = Self.downsampled(cacheURL)
        } catch {
            loadFailed = true
        }
    }

    private static func downsampled(_ url: URL, maxPixelSize: CGFloat = 240) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
