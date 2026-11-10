import CoreGraphics

/// Whether a photo or video frame is wider than tall, or the other way round.
enum MediaOrientation: Equatable, Sendable {
    case landscape
    case portrait
    case square

    /// Treats near-equal sides (within 5%) as square, so a 1080×1080-ish
    /// crop isn't arbitrarily labeled one way or the other.
    init?(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return nil }
        let ratio = size.width / size.height
        if ratio > 1.05 {
            self = .landscape
        } else if ratio < 1 / 1.05 {
            self = .portrait
        } else {
            self = .square
        }
    }

    var displayName: String {
        switch self {
        case .landscape: "Landscape"
        case .portrait: "Portrait"
        case .square: "Square"
        }
    }
}
