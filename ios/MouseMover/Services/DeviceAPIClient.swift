import Foundation

enum DeviceAPIError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case decodingFailed
}

protocol DeviceAPIClientProtocol: Sendable {
    func status(baseURL: URL, token: String?) async throws -> DeviceStatus
    func setJiggle(baseURL: URL, enabled: Bool, token: String?) async throws
    func getWifi(baseURL: URL, token: String?) async throws -> WifiStatus
    func provisionWifi(baseURL: URL, ssid: String, password: String, token: String?) async throws
}

struct DeviceAPIClient: DeviceAPIClientProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func status(baseURL: URL, token: String?) async throws -> DeviceStatus {
        let url = baseURL.appendingPathComponent("api/status")
        let request = authorizedRequest(url: url, method: "GET", token: token)
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        do {
            return try decoder.decode(DeviceStatus.self, from: data)
        } catch {
            throw DeviceAPIError.decodingFailed
        }
    }

    func setJiggle(baseURL: URL, enabled: Bool, token: String?) async throws {
        let url = baseURL.appendingPathComponent("api/jiggle")
        var request = authorizedRequest(url: url, method: "POST", token: token)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(JiggleRequest(enabled: enabled))
        let (_, response) = try await session.data(for: request)
        try validate(response: response)
    }

    func getWifi(baseURL: URL, token: String?) async throws -> WifiStatus {
        let url = baseURL.appendingPathComponent("api/wifi")
        let request = authorizedRequest(url: url, method: "GET", token: token)
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        do {
            return try decoder.decode(WifiStatus.self, from: data)
        } catch {
            throw DeviceAPIError.decodingFailed
        }
    }

    func provisionWifi(baseURL: URL, ssid: String, password: String, token: String?) async throws {
        let url = baseURL.appendingPathComponent("api/wifi")
        var request = authorizedRequest(url: url, method: "POST", token: token)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(WifiProvisionRequest(ssid: ssid, password: password))
        let (_, response) = try await session.data(for: request)
        try validate(response: response)
    }

    private func authorizedRequest(url: URL, method: String, token: String?) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token, !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "X-API-Token")
        }
        return request
    }

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw DeviceAPIError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw DeviceAPIError.httpStatus(http.statusCode)
        }
    }
}
