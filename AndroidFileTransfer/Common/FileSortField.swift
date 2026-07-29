import Foundation

enum FileSortField: String, CaseIterable, Equatable {
    case name = "Name"
    case dateModified = "Date Modified"
    case size = "Size"

    /// The direction that reads most naturally when first switching to this
    /// field — e.g. Date Modified reads best newest-first.
    var naturalDefaultAscending: Bool {
        switch self {
        case .dateModified: false
        case .name, .size: true
        }
    }

    static func sorted(_ files: [RemoteFile], by field: FileSortField, ascending: Bool, directoriesFirst: Bool = true) -> [RemoteFile] {
        files.sorted { lhs, rhs in
            if directoriesFirst, lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            let result: Bool
            switch field {
            case .name: result = lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .dateModified: result = (lhs.modifiedAt ?? .distantPast) < (rhs.modifiedAt ?? .distantPast)
            case .size: result = lhs.size < rhs.size
            }
            return ascending ? result : !result
        }
    }
}
