import Foundation

enum FileSortField: String, CaseIterable, Equatable {
    case name = "Name"
    case dateModified = "Date Modified"
    case size = "Size"

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
