import AppKit
import Testing
@testable import AndroidFileTransfer

@Suite
struct GridSelectionTests {
    @Test
    func plainClickSelectsOnlyTheClickedItem() {
        #expect(GridSelection.applyingClick(on: "c", modifiers: [], to: ["a", "b"]) == ["c"])
    }

    @Test
    func shiftClickAddsOnlyTheClickedItemWithoutTheItemsInBetween() {
        #expect(GridSelection.applyingClick(on: "e", modifiers: .shift, to: ["a"]) == ["a", "e"])
    }

    @Test
    func shiftClickOnASelectedItemDeselectsIt() {
        #expect(GridSelection.applyingClick(on: "a", modifiers: .shift, to: ["a", "e"]) == ["e"])
    }

    @Test
    func commandClickToggles() {
        #expect(GridSelection.applyingClick(on: "b", modifiers: .command, to: ["a"]) == ["a", "b"])
        #expect(GridSelection.applyingClick(on: "a", modifiers: .command, to: ["a", "b"]) == ["b"])
    }
}
