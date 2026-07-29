import AVFoundation
import ImageIO
import SwiftUI

/// Shows a real, lazily-loaded thumbnail for image and video files, and a
/// representative icon for everything else.
///
/// Both are loaded only when the view is actually on screen (SwiftUI cancels
/// `.task` for cells scrolled out of a LazyVGrid/List), which bounds the cost
/// to what's currently visible rather than the whole library. Images decode
/// a small downsampled version straight from the pulled file.
///
/// Videos are more expensive: this device's camera (like most Android camera
/// apps) writes the `moov` atom at the *end* of the file rather than
/// fast-start at the front — verified by inspecting a real recorded MP4's
/// atom layout — so there's no cheap partial-download trick, and a byte-range
/// AVAssetResourceLoader was tried and empirically rejected: AVFoundation
/// didn't probe incrementally the way real HTTP range streaming would, it
/// just requested the entire file in one shot regardless, which is no better
/// than pulling it directly. So thumbnailing a video really does mean
/// pulling the whole file — kept in check two ways: `VideoThumbnailPullLimiter`
/// stops several huge pulls from fighting over the same USB connection at
/// once (which was making each one slower than sequential), and videos
/// larger than `maxFullPullSize` just show the icon rather than pulling
/// hundreds of MB–1GB+ for a thumbnail.
struct RemoteThumbnailView: View {
    let file: RemoteFile
    let serial: String
    let transferService: TransferServiceProtocol

    /// Beyond this, pulling the whole file just to thumbnail it isn't worth
    /// the wait — a real device video can run past 1GB.
    private static let maxFullPullVideoSize: Int64 = 150 * 1024 * 1024

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
        guard !file.isDirectory, !loadFailed else { return }
        let category = FileCategory.category(forFileName: file.name)
        guard category == .images || category == .videos else { return }
        if category == .videos, file.size > Self.maxFullPullVideoSize { return }

        let cacheURL = ThumbnailCache.localURL(for: file.path)
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            thumbnailImage = Self.downsampled(cacheURL)
            return
        }

        if category == .images {
            await loadImageThumbnail(cacheURL: cacheURL)
        } else {
            await loadVideoThumbnail(cacheURL: cacheURL)
        }
    }

    private func loadImageThumbnail(cacheURL: URL) async {
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

    private func loadVideoThumbnail(cacheURL: URL) async {
        await VideoThumbnailPullLimiter.shared.acquire()
        defer { Task { await VideoThumbnailPullLimiter.shared.release() } }
        if Task.isCancelled { return }

        let tempVideoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AndroidFileTransferVideoThumb-\(UUID().uuidString)")
            .appendingPathExtension((file.name as NSString).pathExtension)
        defer { try? FileManager.default.removeItem(at: tempVideoURL) }

        do {
            for try await _ in transferService.pull(remotePath: file.path, localURL: tempVideoURL, on: serial) {
                if Task.isCancelled { return }
            }
            if Task.isCancelled { return }
            guard let frameData = await Self.extractVideoFrameJPEG(tempVideoURL) else {
                loadFailed = true
                return
            }
            try? frameData.write(to: cacheURL)
            if Task.isCancelled { return }
            thumbnailImage = Self.downsampled(cacheURL)
        } catch {
            loadFailed = true
        }
    }

    private static func extractVideoFrameJPEG(_ url: URL, maxPixelSize: CGFloat = 240) async -> Data? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)
        // A hair after 0s to avoid a frequently-black opening frame.
        guard let (cgImage, _) = try? await generator.image(at: CMTime(seconds: 0.3, preferredTimescale: 600)) else {
            return nil
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
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
