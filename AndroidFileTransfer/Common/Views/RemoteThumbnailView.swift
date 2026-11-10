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
/// pulling the whole file — kept in check two ways: `PullLimiter.videos`
/// stops several huge pulls from fighting over the same USB connection at
/// once (which was making each one slower than sequential), and videos
/// larger than `maxFullPullSize` just show the icon rather than pulling
/// hundreds of MB–1GB+ for a thumbnail.
struct RemoteThumbnailView: View {
    enum Style {
        /// Fills and crops to the frame — for small row icons.
        case icon
        /// Fits inside the frame at the media's real aspect ratio, so
        /// portrait vs landscape is visible at a glance — for grid tiles.
        case tile
    }

    let file: RemoteFile
    let serial: String
    let transferService: TransferServiceProtocol
    var style: Style = .icon

    /// Beyond this, pulling the whole file just to thumbnail it isn't worth
    /// the wait — a real device video can run past 1GB. Raised from an
    /// initial 150MB per user preference, trading a longer worst-case wait
    /// (~500MB at this device's measured ~36 MB/s single-stream pull speed
    /// is ~14s) for covering more real videos with an actual thumbnail.
    private static let maxFullPullVideoSize: Int64 = 500 * 1024 * 1024

    @State private var thumbnailImage: NSImage?
    @State private var loadFailed = false

    var body: some View {
        Group {
            switch style {
            case .icon: iconContent
            case .tile: tileContent
            }
        }
        .task(id: file.path) {
            await loadIfNeeded()
        }
    }

    @ViewBuilder
    private var iconContent: some View {
        if let thumbnailImage {
            Image(nsImage: thumbnailImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            placeholderIcon
        }
    }

    @ViewBuilder
    private var tileContent: some View {
        if let thumbnailImage {
            let shape = RoundedRectangle(cornerRadius: 6)
            let orientation = MediaOrientation(size: thumbnailImage.size)
            Image(nsImage: thumbnailImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(shape)
                // Keeps the edge visible for very dark media (e.g. dark-mode
                // screenshots) so the shape still reads against the background.
                .overlay(shape.strokeBorder(.separator, lineWidth: 1))
                .overlay(alignment: .bottomLeading) {
                    if isVideo {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(.black.opacity(0.55), in: Circle())
                            .padding(5)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .help(orientation.map { "\($0.displayName) \(isVideo ? "video" : "image")" } ?? "")
                .accessibilityLabel(orientation.map { "\($0.displayName) \(isVideo ? "video" : "image")" } ?? file.name)
        } else {
            placeholderIcon
                .font(.system(size: 36))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: iconName)
            .foregroundStyle(file.isDirectory ? .blue : .secondary)
    }

    private var isVideo: Bool {
        FileCategory.category(forFileName: file.name) == .videos
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
            await showThumbnail(from: cacheURL)
            return
        }

        let limiter = category == .images ? PullLimiter.images : PullLimiter.videos
        guard await limiter.acquire() else { return }
        defer { Task { await limiter.release() } }
        if Task.isCancelled { return }

        if category == .images {
            await loadImageThumbnail(cacheURL: cacheURL)
        } else {
            await loadVideoThumbnail(cacheURL: cacheURL)
        }
    }

    /// Decodes off the main thread: shrinking a multi-MB camera photo takes
    /// long enough that doing it for every visible cell made scrolling stutter.
    private func showThumbnail(from url: URL) async {
        let cgImage = await Task.detached(priority: .userInitiated) {
            Self.downsampled(url)
        }.value
        guard !Task.isCancelled, let cgImage else { return }
        thumbnailImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    private func loadImageThumbnail(cacheURL: URL) async {
        // Pulls to a temp file and only moves it into the cache once the pull
        // fully succeeds. Pulling straight into the cache left a truncated file
        // behind whenever a cell scrolled away mid-pull, and that partial file
        // was then treated as a finished thumbnail (a mostly gray image).
        let partialURL = cacheURL.appendingPathExtension("partial-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: partialURL) }
        do {
            for try await _ in transferService.pull(remotePath: file.path, localURL: partialURL, on: serial) {
                if Task.isCancelled { return }
            }
            if Task.isCancelled { return }
            try? FileManager.default.removeItem(at: cacheURL)
            try FileManager.default.moveItem(at: partialURL, to: cacheURL)
            await showThumbnail(from: cacheURL)
        } catch {
            if !Task.isCancelled { loadFailed = true }
        }
    }

    private func loadVideoThumbnail(cacheURL: URL) async {
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
            try? frameData.write(to: cacheURL, options: .atomic)
            if Task.isCancelled { return }
            await showThumbnail(from: cacheURL)
        } catch {
            if !Task.isCancelled { loadFailed = true }
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

    nonisolated private static func downsampled(_ url: URL, maxPixelSize: CGFloat = 240) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
