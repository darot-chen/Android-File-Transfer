import Testing

@Suite
struct SmokeTests {
    @Test
    func testTargetIsWiredUp() {
        #expect(true)
    }
}
