import SwiftUI

struct SortMenuButton: View {
    @Binding var sortField: FileSortField
    @Binding var sortAscending: Bool

    var body: some View {
        Menu {
            ForEach(FileSortField.allCases, id: \.self) { field in
                Button {
                    if sortField == field {
                        sortAscending.toggle()
                    } else {
                        sortField = field
                        sortAscending = field.naturalDefaultAscending
                    }
                } label: {
                    HStack {
                        Text(field.rawValue)
                        if sortField == field {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .menuIndicator(.hidden)
        .help("Sort by \(sortField.rawValue), \(sortAscending ? "ascending" : "descending")")
    }
}
