import Foundation

struct Device: Identifiable, Sendable, Equatable {
    enum State: String, Sendable, Equatable {
        case device
        case offline
        case unauthorized
        case noPermissions = "no permissions"
        case unknown
    }

    var id: String { serial }
    let serial: String
    let state: State
    let model: String?

    /// adb reports models with underscores in place of spaces (e.g. "Pixel_9_Pro").
    var displayName: String {
        model.map { $0.replacingOccurrences(of: "_", with: " ") } ?? serial
    }
}

extension Device {
    static func parseSnapshot(_ payload: String) -> [Device] {
        payload
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { parseLine(String($0)) }
    }

    static func parseLine(_ line: String) -> Device? {
        let tokens = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard tokens.count >= 2 else { return nil }

        let serial = tokens[0]
        let state = State(rawValue: tokens[1]) ?? .unknown
        let model = tokens.dropFirst(2)
            .first(where: { $0.hasPrefix("model:") })
            .map { String($0.dropFirst("model:".count)) }

        return Device(serial: serial, state: state, model: model)
    }
}
