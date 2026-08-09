import SwiftUI

/// Runtime presence derived from reachability + device state.
/// Colors match the ESP32 WS2812 status LED (see firmware `StatusLed`).
enum DevicePresenceStatus: String, Equatable, Sendable, CaseIterable {
    case offline
    case setup
    case readyToMove
    case moving

    var title: String {
        switch self {
        case .offline: "Offline"
        case .setup: "Setup"
        case .readyToMove: "Ready to move"
        case .moving: "Moving"
        }
    }

    /// Approximate LED color shown on the board.
    var ledColor: Color {
        switch self {
        case .offline:
            // Solid red — WiFi down / unreachable
            Color(red: 0.95, green: 0.15, blue: 0.12)
        case .setup:
            // Magenta — Soft-AP setup
            Color(red: 0.95, green: 0.15, blue: 0.85)
        case .readyToMove:
            // Dim green — STA up, jiggle off
            Color(red: 0.12, green: 0.72, blue: 0.28)
        case .moving:
            // Cyan — STA up, jiggle on
            Color(red: 0.10, green: 0.78, blue: 0.82)
        }
    }

    static func resolve(isReachable: Bool, jiggleEnabled: Bool, staIP: String?) -> DevicePresenceStatus {
        guard isReachable else { return .offline }
        let hasStaIP = !(staIP?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        if !hasStaIP {
            return .setup
        }
        return jiggleEnabled ? .moving : .readyToMove
    }
}
