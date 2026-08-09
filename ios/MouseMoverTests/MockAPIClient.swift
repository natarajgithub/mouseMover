import Foundation
@testable import MouseMover

final class MockAPIClient: DeviceAPIClientProtocol, @unchecked Sendable {
    var statusResults: [URL: Result<DeviceStatus, Error>] = [:]
    var setJiggleResults: [URL: Result<Void, Error>] = [:]
    var getWifiResults: [URL: Result<WifiStatus, Error>] = [:]
    var provisionWifiResults: [URL: Result<Void, Error>] = [:]
    private(set) var setJiggleCalls: [(URL, Bool, String?)] = []
    private(set) var provisionWifiCalls: [(URL, String, String, String?)] = []

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
        if let result = getWifiResults[baseURL] {
            return try result.get()
        }
        throw DeviceAPIError.invalidResponse
    }

    func provisionWifi(baseURL: URL, ssid: String, password: String, token: String?) async throws {
        provisionWifiCalls.append((baseURL, ssid, password, token))
        if let result = provisionWifiResults[baseURL] {
            try result.get()
            return
        }
    }
}
