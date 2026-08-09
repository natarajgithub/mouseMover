import Foundation

/// Indexes saved devices so discovery and add-by-address can hide or reject duplicates.
struct SavedDeviceIndex: Equatable, Sendable {
    struct Entry: Equatable, Sendable {
        let deviceId: String
        let displayName: String
        let hosts: Set<String>
    }

    private let byId: [String: Entry]
    private let byHost: [String: Entry]

    static let empty = SavedDeviceIndex(entries: [])

    init(devices: [StoredDevice]) {
        self.init(entries: devices.map { device in
            var hosts = Set<String>()
            let mdns = DeviceEndpointResolver.sanitizeHost(device.mdnsHost).lowercased()
            if !mdns.isEmpty { hosts.insert(mdns) }
            if let staIP = device.staIP {
                let ip = DeviceEndpointResolver.sanitizeHost(staIP).lowercased()
                if !ip.isEmpty { hosts.insert(ip) }
            }
            return Entry(deviceId: device.deviceId, displayName: device.displayName, hosts: hosts)
        })
    }

    init(entries: [Entry]) {
        var idMap: [String: Entry] = [:]
        var hostMap: [String: Entry] = [:]
        for entry in entries {
            idMap[entry.deviceId.lowercased()] = entry
            for host in entry.hosts {
                hostMap[host] = entry
            }
        }
        byId = idMap
        byHost = hostMap
    }

    var isEmpty: Bool { byId.isEmpty }

    func match(candidate: DiscoveredService) -> Entry? {
        if let id = candidate.deviceId?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty,
           let entry = byId[id.lowercased()] {
            return entry
        }
        let host = DeviceEndpointResolver.sanitizeHost(candidate.host).lowercased()
        if !host.isEmpty, let entry = byHost[host] {
            return entry
        }
        return nil
    }

    func match(status: DeviceStatus, host: String) -> Entry? {
        if let id = status.deviceId?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty,
           let entry = byId[id.lowercased()] {
            return entry
        }
        if let mdns = status.mdns {
            let key = DeviceEndpointResolver.sanitizeHost(mdns).lowercased()
            if !key.isEmpty, let entry = byHost[key] {
                return entry
            }
        }
        if let staIP = status.staIp {
            let key = DeviceEndpointResolver.sanitizeHost(staIP).lowercased()
            if !key.isEmpty, let entry = byHost[key] {
                return entry
            }
        }
        let hostKey = DeviceEndpointResolver.sanitizeHost(host).lowercased()
        if !hostKey.isEmpty, let entry = byHost[hostKey] {
            return entry
        }
        return nil
    }

    static func alreadyExistsMessage(displayName: String) -> String {
        "“\(displayName)” is already in your device list."
    }
}
