import SwiftUI

struct ViewModePicker: View {
    @Binding var mode: BrowserViewMode

    var body: some View {
        Picker("View", selection: $mode) {
            Image(systemName: "list.bullet").tag(BrowserViewMode.list)
            Image(systemName: "square.grid.2x2").tag(BrowserViewMode.grid)
        }
        .pickerStyle(.segmented)
        .frame(width: 80)
        .labelsHidden()
    }
}
