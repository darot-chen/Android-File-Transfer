import SwiftUI

struct FavoritesView: View {
    let viewModel: FavoritesViewModel
    let onSelect: (Favorite) -> Void

    var body: some View {
        if !viewModel.favorites.isEmpty {
            Section("Favorites") {
                ForEach(viewModel.favorites) { favorite in
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
