import Foundation
@testable import MouseMover

final class MockSoftAPJoiner: SoftAPJoinerProtocol {
    var joinResults: [String: Result<Void, Error>] = [:]
    private(set) var joinCalls: [(ssid: String, password: String?)] = []

    func join(ssid: String, password: String?) async throws {
        joinCalls.append((ssid, password))
        if let result = joinResults[ssid] {
            try result.get()
            return
        }
        if let result = joinResults["*"] {
            try result.get()
            return
        }
    }
}
