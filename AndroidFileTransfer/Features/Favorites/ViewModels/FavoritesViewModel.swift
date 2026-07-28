import Foundation
import Observation

@MainActor
@Observable
final class FavoritesViewModel {
    private(set) var favorites: [Favorite] = []
    private let store: FavoritesStoring

    init(store: FavoritesStoring) {
        self.store = store
        self.favorites = store.load()
    }

    func isFavorite(serial: String, path: String) -> Bool {
        favorites.contains { $0.serial == serial && $0.path == path }
    }

    func toggle(serial: String, path: String, name: String) {
        if let index = favorites.firstIndex(where: { $0.serial == serial && $0.path == path }) {
            favorites.remove(at: index)
        } else {
            favorites.append(Favorite(id: UUID(), serial: serial, path: path, name: name))
        }
        store.save(favorites)
    }

    func remove(_ favorite: Favorite) {
        favorites.removeAll { $0.id == favorite.id }
        store.save(favorites)
    }
}
