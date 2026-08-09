import Foundation

struct Device: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var displayName: String
    var mdnsHost: String
    var staIP: String?
    var apiToken: String?
    var jiggleEnabled: Bool
    var lastSeen: Date?
    var firmwareVersion: String?

    init(
        id: String,
        displayName: String,
        mdnsHost: String,
        staIP: String? = nil,
        apiToken: String? = nil,
        jiggleEnabled: Bool = false,
        lastSeen: Date? = nil,
        firmwareVersion: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.mdnsHost = mdnsHost
        self.staIP = staIP
        self.apiToken = apiToken
        self.jiggleEnabled = jiggleEnabled
        self.lastSeen = lastSeen
        self.firmwareVersion = firmwareVersion
    }

    init(status: DeviceStatus, fallbackHost: String) {
        id = status.deviceId ?? fallbackHost
        displayName = status.name
        mdnsHost = status.mdns ?? fallbackHost
        staIP = status.staIp
        apiToken = nil
        jiggleEnabled = status.jiggle
        lastSeen = Date()
        firmwareVersion = status.version
    }
}

struct DeviceStatus: Codable, Equatable, Sendable {
    let ok: Bool
    let name: String
    let version: String
    let deviceId: String?
    let jiggle: Bool
    let jiggleIntervalMs: Int
    let staIp: String?
    let mdns: String?
    let authRequired: Bool

    enum CodingKeys: String, CodingKey {
        case ok
        case name
        case version
        case deviceId = "device_id"
        case jiggle
        case jiggleIntervalMs = "jiggle_interval_ms"
        case staIp = "sta_ip"
        case mdns
        case authRequired = "auth_required"
    }

    init(
        ok: Bool,
        name: String,
        version: String,
        deviceId: String? = nil,
        jiggle: Bool,
        jiggleIntervalMs: Int,
        staIp: String? = nil,
        mdns: String? = nil,
        authRequired: Bool = false
    ) {
        self.ok = ok
        self.name = name
        self.version = version
        self.deviceId = deviceId
        self.jiggle = jiggle
        self.jiggleIntervalMs = jiggleIntervalMs
        self.staIp = staIp
        self.mdns = mdns
        self.authRequired = authRequired
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = try container.decodeIfPresent(Bool.self, forKey: .ok) ?? true
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "usb-hid-s3"
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "unknown"
        deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
        jiggle = try container.decodeIfPresent(Bool.self, forKey: .jiggle) ?? false
        jiggleIntervalMs = try container.decodeIfPresent(Int.self, forKey: .jiggleIntervalMs) ?? 10000
        staIp = try container.decodeIfPresent(String.self, forKey: .staIp)
        mdns = try container.decodeIfPresent(String.self, forKey: .mdns)
        // Older firmware (e.g. 0.3.3) omits auth_required.
        authRequired = try container.decodeIfPresent(Bool.self, forKey: .authRequired) ?? false
    }
}

struct JiggleRequest: Encodable, Sendable {
    let enabled: Bool
}

struct WifiProvisionRequest: Encodable, Sendable {
    let ssid: String
    let password: String

    enum CodingKeys: String, CodingKey {
        case ssid
        case password
    }
}

struct WifiStatus: Codable, Equatable, Sendable {
    let ok: Bool?
    let mode: String?
    let configured: Bool?
    let ssid: String?
    let staIp: String?
    let deviceId: String?
    let apSsid: String?
    let apIp: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case mode
        case configured
        case ssid
        case staIp = "sta_ip"
        case deviceId = "device_id"
        case apSsid = "ap_ssid"
        case apIp = "ap_ip"
    }
}
