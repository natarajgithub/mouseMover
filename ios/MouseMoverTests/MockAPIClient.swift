import Foundation
@testable import MouseMover

final class MockAPIClient: DeviceAPIClientProtocol, @unchecked Sendable {
    var statusResults: [URL: Result<DeviceStatus, Error>] = [:]
    var setJiggleResults: [URL: Result<Void, Error>] = [:]
    private(set) var setJiggleCalls: [(URL, Bool, String?)] = []

    func status(baseURL: URL, token: String?) async throws -> DeviceStatus {
        if let result = statusResults[baseURL] {
            return try result.get()
        }
        throw DeviceAPIError.invalidResponse
    }

    func setJiggle(baseURL: URL, enabled: Bool, token: String?) async throws {
        setJiggleCalls.append((baseURL, enabled, token))
        if let result = setJiggleResults[baseURL] {
            try result.get()
            return
        }
        throw DeviceAPIError.invalidResponse
    }

    func getWifi(baseURL: URL, token: String?) async throws -> WifiStatus {
        WifiStatus(ok: true, mode: nil, configured: nil, ssid: nil, staIp: nil)
    }

    func provisionWifi(baseURL: URL, ssid: String, password: String, token: String?) async throws {}
}
