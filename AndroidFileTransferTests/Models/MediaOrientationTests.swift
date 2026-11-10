import CoreGraphics
import Testing
@testable import AndroidFileTransfer

@Suite
struct MediaOrientationTests {
    @Test
    func classifiesWideAndTallMedia() {
        #expect(MediaOrientation(size: CGSize(width: 1920, height: 1080)) == .landscape)
        #expect(MediaOrientation(size: CGSize(width: 1080, height: 1920)) == .portrait)
    }

    @Test
    func nearEqualSidesAreSquare() {
        #expect(MediaOrientation(size: CGSize(width: 1080, height: 1080)) == .square)
        #expect(MediaOrientation(size: CGSize(width: 1100, height: 1080)) == .square)
        #expect(MediaOrientation(size: CGSize(width: 1080, height: 1100)) == .square)
    }

    @Test
    func emptySizeHasNoOrientation() {
        #expect(MediaOrientation(size: .zero) == nil)
        #expect(MediaOrientation(size: CGSize(width: 100, height: 0)) == nil)
    }
}
