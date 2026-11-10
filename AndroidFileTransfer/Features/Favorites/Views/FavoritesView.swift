import SwiftUI

struct FavoritesView: View {
    let viewModel: FavoritesViewModel
    let connectedSerials: Set<String>
    let onSelect: (Favorite) -> Void

    var body: some View {
        let visible = viewModel.favorites(on: connectedSerials)
        if !visible.isEmpty {
            Section("Favorites") {
                ForEach(visible) { favorite in
                    Button {
                        onSelect(favorite)
                    } label: {
                        Label(favorite.name, systemImage: "star.fill")
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Remove Favorite", role: .destructive) {
                            viewModel.remove(favorite)
                        }
                    }
                }
            }
        }
    }
}
