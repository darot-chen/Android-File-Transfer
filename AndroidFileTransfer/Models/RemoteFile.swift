import Foundation

struct RemoteFile: Identifiable, Sendable, Equatable {
    var id: String { path }
    let name: String
    let path: String
    let isDirectory: Bool
    let isSymlink: Bool
    let symlinkTarget: String?
    let size: Int64
    let modifiedAt: Date?
    let permissions: String
}

extension RemoteFile {
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    /// Just the base name, without extension — used in grid views where the
    /// extension is redundant next to the thumbnail/icon itself. Only
    /// applies to files; folder names are shown in full since a trailing
    /// ".something" in a folder name isn't a file extension to hide.
    var displayNameWithoutExtension: String {
        isDirectory ? name : (name as NSString).deletingPathExtension
    }
}

extension RemoteFile {
    // Parses `ls -la --time-style=long-iso` output. That flag pins the date
    // format to a fixed, locale-independent "yyyy-MM-dd HH:mm" so parsing
    // doesn't depend on the device's locale or toybox/busybox version quirks.
    nonisolated(unsafe) private static let lineRegex = /^(\S+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2})\s+(.+)$/

    static func parseListing(_ output: String, parentPath: String) -> [RemoteFile] {
        output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { parseLine(String($0), parentPath: parentPath) }
    }

    static func parseLine(_ line: String, parentPath: String) -> RemoteFile? {
        guard !line.hasPrefix("total "), let match = line.wholeMatch(of: lineRegex) else {
            return nil
        }

        let permissions = String(match.1)
        guard let typeChar = permissions.first else { return nil }
        let isDirectory = typeChar == "d"
        let isSymlink = typeChar == "l"

        var nameField = String(match.8)
        var symlinkTarget: String?
        if isSymlink, let arrowRange = nameField.range(of: " -> ") {
            symlinkTarget = String(nameField[arrowRange.upperBound...])
            nameField = String(nameField[..<arrowRange.lowerBound])
        }

        guard nameField != "." && nameField != ".." else { return nil }

        let size = Int64(match.5) ?? 0
        let modifiedAt = parseDate(dateString: String(match.6), timeString: String(match.7))
        let path = parentPath.hasSuffix("/") ? parentPath + nameField : parentPath + "/" + nameField

        return RemoteFile(
            name: nameField,
            path: path,
            isDirectory: isDirectory,
            isSymlink: isSymlink,
            symlinkTarget: symlinkTarget,
            size: size,
            modifiedAt: modifiedAt,
            permissions: permissions
        )
    }

    private static func parseDate(dateString: String, timeString: String) -> Date? {
        let dateParts = dateString.split(separator: "-").compactMap { Int($0) }
        let timeParts = timeString.split(separator: ":").compactMap { Int($0) }
        guard dateParts.count == 3, timeParts.count == 2 else { return nil }

        var components = DateComponents()
        components.year = dateParts[0]
        components.month = dateParts[1]
        components.day = dateParts[2]
        components.hour = timeParts[0]
        components.minute = timeParts[1]

        return Calendar(identifier: .gregorian).date(from: components)
    }
}
