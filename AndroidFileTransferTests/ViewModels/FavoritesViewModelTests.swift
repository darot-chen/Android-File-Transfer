import Foundation
import Testing
@testable import AndroidFileTransfer

@MainActor
@Suite
struct FavoritesViewModelTests {
    @Test
    func loadsFromStoreOnInit() {
        let existing = Favorite(id: UUID(), serial: "SERIAL", path: "/sdcard/DCIM", name: "DCIM")
        let viewModel = FavoritesViewModel(store: MockFavoritesStore(initial: [existing]))

        #expect(viewModel.favorites == [existing])
    }

    @Test
    func toggleAddsThenRemovesAndPersists() {
        let store = MockFavoritesStore()
        let viewModel = FavoritesViewModel(store: store)

        viewModel.toggle(serial: "SERIAL", path: "/sdcard/DCIM", name: "DCIM")
        #expect(viewModel.isFavorite(serial: "SERIAL", path: "/sdcard/DCIM"))
        #expect(store.load().count == 1)

        viewModel.toggle(serial: "SERIAL", path: "/sdcard/DCIM", name: "DCIM")
        #expect(!viewModel.isFavorite(serial: "SERIAL", path: "/sdcard/DCIM"))
        #expect(store.load().isEmpty)
    }

    @Test
    func removeDeletesSpecificFavorite() {
        let store = MockFavoritesStore()
        let viewModel = FavoritesViewModel(store: store)
        viewModel.toggle(serial: "SERIAL", path: "/sdcard/DCIM", name: "DCIM")
        let favorite = viewModel.favorites[0]

        viewModel.remove(favorite)

        #expect(viewModel.favorites.isEmpty)
    }

    @Test
    func favoritesAreScopedPerDeviceSerial() {
        let viewModel = FavoritesViewModel(store: MockFavoritesStore())

        viewModel.toggle(serial: "DEVICE_A", path: "/sdcard/DCIM", name: "DCIM")

        #expect(viewModel.isFavorite(serial: "DEVICE_A", path: "/sdcard/DCIM"))
        #expect(!viewModel.isFavorite(serial: "DEVICE_B", path: "/sdcard/DCIM"))
    }
}
