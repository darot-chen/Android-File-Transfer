import Foundation

enum FileCategory: String, CaseIterable, Identifiable, Sendable {
    case images
    case videos
    case audio
    case documents
    case archives
    case apks

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .images: "Images"
        case .videos: "Videos"
        case .audio: "Audio"
        case .documents: "Documents"
        case .archives: "Archives"
        case .apks: "APKs"
        }
    }

    var systemImage: String {
        switch self {
        case .images: "photo"
        case .videos: "film"
        case .audio: "waveform"
        case .documents: "doc.text"
        case .archives: "doc.zipper"
        case .apks: "shippingbox"
        }
    }

    private static let extensionsByCategory: [FileCategory: Set<String>] = [
        .images: ["jpg", "jpeg", "png", "gif", "bmp", "webp", "heic", "heif", "tiff", "tif", "svg"],
        .videos: ["mp4", "mkv", "mov", "avi", "3gp", "3gpp", "webm", "flv", "m4v", "wmv", "mpg", "mpeg", "ts"],
        .audio: ["mp3", "wav", "aac", "flac", "ogg", "m4a", "wma", "opus", "amr", "mid", "midi"],
        .documents: ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "csv", "odt", "epub"],
        .archives: ["zip", "rar", "7z", "tar", "gz", "bz2", "xz"],
        .apks: ["apk", "apks", "xapk"],
    ]

    static func category(forFileName fileName: String) -> FileCategory? {
        let ext = (fileName as NSString).pathExtension.lowercased()
        guard !ext.isEmpty else { return nil }
        return allCases.first { extensionsByCategory[$0]?.contains(ext) == true }
    }
}
