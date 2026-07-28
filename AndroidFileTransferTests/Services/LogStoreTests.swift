import Testing
@testable import AndroidFileTransfer

@MainActor
@Suite
struct LogStoreTests {
    @Test
    func logAppendsEntry() {
        let store = LogStore()

        store.log(.info, category: "Test", "hello")

        #expect(store.entries.count == 1)
        #expect(store.entries[0].message == "hello")
        #expect(store.entries[0].level == .info)
    }

    @Test
    func trimsToMaxEntries() {
        let store = LogStore(maxEntries: 3)

        for index in 0..<5 {
            store.log(.debug, category: "Test", "message \(index)")
        }

        #expect(store.entries.count == 3)
        #expect(store.entries.map(\.message) == ["message 2", "message 3", "message 4"])
    }

    @Test
    func clearRemovesAllEntries() {
        let store = LogStore()
        store.log(.error, category: "Test", "boom")

        store.clear()

        #expect(store.entries.isEmpty)
    }

    @Test
    func exportTextIncludesLevelCategoryAndMessage() {
        let store = LogStore()
        store.log(.warning, category: "ADB", "low disk space")

        let text = store.exportText()

        #expect(text.contains("[WARNING]"))
        #expect(text.contains("ADB"))
        #expect(text.contains("low disk space"))
    }
}
