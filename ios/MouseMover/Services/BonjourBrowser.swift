import Foundation
import Network

struct DiscoveredService: Identifiable, Equatable, Sendable {
    let id: String
    let deviceId: String?
    let name: String
    let host: String
    let port: Int
    let txt: [String: String]

    init(
        id: String,
        deviceId: String?,
        name: String,
        host: String,
        port: Int,
        txt: [String: String] = [:]
    ) {
        self.id = id
        self.deviceId = deviceId
        self.name = name
        self.host = host
        self.port = port
        self.txt = txt
    }
}

enum BonjourDiscoveryFilter {
    /// Returns true when TXT contains an `id` key or the service/host name includes `hid-helper`.
    static func isCandidate(serviceName: String, host: String, txt: [String: String]) -> Bool {
        if txt["id"] != nil {
            return true
        }
        let haystack = "\(serviceName) \(host)".lowercased()
        return haystack.contains("hid-helper")
    }

    /// Collapses duplicate Bonjour hits for one physical board (same TXT `id`, same IP,
    /// or legacy bare `hid-helper` alongside `hid-helper-xxxx`).
    static func deduplicate(_ services: [DiscoveredService]) -> [DiscoveredService] {
        guard services.count > 1 else { return services }

        var parent = Array(services.indices)
        func find(_ i: Int) -> Int {
            var x = i
            while parent[x] != x {
                parent[x] = parent[parent[x]]
                x = parent[x]
            }
            return x
        }
        func union(_ a: Int, _ b: Int) {
            let ra = find(a)
            let rb = find(b)
            if ra != rb { parent[rb] = ra }
        }

        for i in services.indices {
            for j in services.indices where j > i {
                if shouldMerge(services[i], services[j]) {
                    union(i, j)
                }
            }
        }

        var groups: [Int: [DiscoveredService]] = [:]
        for i in services.indices {
            groups[find(i), default: []].append(services[i])
        }

        let merged = groups.values.map { prefer($0) }
        return merged.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func shouldMerge(_ a: DiscoveredService, _ b: DiscoveredService) -> Bool {
        if let idA = normalizedDeviceId(a), let idB = normalizedDeviceId(b), idA == idB {
            return true
        }
        if let ipA = ipv4Host(a.host), let ipB = ipv4Host(b.host), ipA == ipB {
            return true
        }
        // Legacy firmware advertised bare `hid-helper`; 0.4+ uses `hid-helper-xxxx`.
        if isBareHidHelper(a), isVersionedHidHelper(b) { return true }
        if isBareHidHelper(b), isVersionedHidHelper(a) { return true }
        return false
    }

    private static func prefer(_ group: [DiscoveredService]) -> DiscoveredService {
        let best = group.max(by: { score($0) < score($1) }) ?? group[0]
        let deviceId = group.compactMap(\.deviceId).first { !$0.isEmpty } ?? best.deviceId
        let host = group.compactMap { ipv4Host($0.host) }.first
            ?? group.map(\.host).max(by: { scoreHost($0) < scoreHost($1) })
            ?? best.host
        let name = group.map(\.name).max(by: { scoreName($0) < scoreName($1) }) ?? best.name
        var txt = best.txt
        if let deviceId, txt["id"] == nil {
            txt["id"] = deviceId
        }
        return DiscoveredService(
            id: best.id,
            deviceId: deviceId,
            name: name,
            host: host,
            port: best.port,
            txt: txt
        )
    }

    private static func score(_ service: DiscoveredService) -> Int {
        var value = 0
        if service.deviceId != nil { value += 100 }
        if isVersionedHidHelper(service) { value += 50 }
        if ipv4Host(service.host) != nil { value += 20 }
        if !isBareHidHelper(service) { value += 10 }
        value += min(service.name.count, 40)
        return value
    }

    private static func scoreName(_ name: String) -> Int {
        let lower = name.lowercased()
        if lower.range(of: #"^hid-helper-[0-9a-f]+$"#, options: .regularExpression) != nil { return 100 + name.count }
        if lower == "hid-helper" { return 1 }
        return name.count
    }

    private static func scoreHost(_ host: String) -> Int {
        let sanitized = DeviceEndpointResolver.sanitizeHost(host).lowercased()
        if ipv4Host(sanitized) != nil { return 100 }
        if sanitized.range(of: #"^hid-helper-[0-9a-f]+\.local$"#, options: .regularExpression) != nil {
            return 80
        }
        if sanitized == "hid-helper.local" { return 1 }
        return 40
    }

    private static func normalizedDeviceId(_ service: DiscoveredService) -> String? {
        if let id = service.deviceId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !id.isEmpty {
            return id
        }
        if let id = service.txt["id"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !id.isEmpty {
            return id
        }
        return nil
    }

    private static func ipv4Host(_ host: String) -> String? {
        let sanitized = DeviceEndpointResolver.sanitizeHost(host)
        let parts = sanitized.split(separator: ".")
        guard parts.count == 4,
              parts.allSatisfy({ UInt8($0) != nil }) else { return nil }
        return sanitized
    }

    private static func isBareHidHelper(_ service: DiscoveredService) -> Bool {
        let name = service.name.lowercased()
        let host = DeviceEndpointResolver.sanitizeHost(service.host).lowercased()
        return name == "hid-helper" || host == "hid-helper.local"
    }

    private static func isVersionedHidHelper(_ service: DiscoveredService) -> Bool {
        let name = service.name.lowercased()
        let host = DeviceEndpointResolver.sanitizeHost(service.host).lowercased()
        let pattern = #"^hid-helper-[0-9a-f]+(\.local)?$"#
        return name.range(of: #"^hid-helper-[0-9a-f]+$"#, options: .regularExpression) != nil
            || host.range(of: pattern, options: .regularExpression) != nil
    }
}

protocol DiscoverySource: AnyObject {
    var onUpdate: (([DiscoveredService]) -> Void)? { get set }
    func startBrowsing()
    func stopBrowsing()
}

protocol BonjourBrowserProtocol: DiscoverySource {}

/// mDNS discovery of `_http._tcp` HID helper services via Network.framework.
final class BonjourBrowser: BonjourBrowserProtocol {
    var onUpdate: (([DiscoveredService]) -> Void)?

    private let queue = DispatchQueue(label: "com.mkflabs.mousemover.bonjour")
    private var browser: NWBrowser?
    private var resolveConnections: [String: NWConnection] = [:]
    private var services: [String: DiscoveredService] = [:]

    func startBrowsing() {
        stopBrowsing()

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        browser = NWBrowser(for: .bonjour(type: "_http._tcp", domain: nil), using: parameters)

        browser?.stateUpdateHandler = { [weak self] state in
            if case .failed = state {
                DispatchQueue.main.async {
                    self?.onUpdate?([])
                }
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            self?.handleBrowseResults(results)
        }

        browser?.start(queue: queue)
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        for connection in resolveConnections.values {
            connection.cancel()
        }
        resolveConnections.removeAll()
        services.removeAll()
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        let resultKeys = Set(results.map { serviceKey(for: $0) })

        for key in services.keys where !resultKeys.contains(key) {
            services.removeValue(forKey: key)
            resolveConnections[key]?.cancel()
            resolveConnections.removeValue(forKey: key)
        }

        for result in results {
            process(result)
        }

        publish()
    }

    private func process(_ result: NWBrowser.Result) {
        guard case let .service(name, _, domain, _) = result.endpoint else { return }

        let txt = txtDictionary(from: result.metadata)
        let provisionalHost = hostLabel(from: name, domain: domain)
        guard BonjourDiscoveryFilter.isCandidate(
            serviceName: name,
            host: provisionalHost,
            txt: txt
        ) else {
            return
        }

        let key = serviceKey(for: result)
        if services[key] != nil {
            return
        }

        let deviceId = txt["id"]
        let placeholder = DiscoveredService(
            id: key,
            deviceId: deviceId,
            name: name,
            host: provisionalHost,
            port: 80,
            txt: txt
        )
        services[key] = placeholder
        resolveEndpoint(result, key: key, name: name, domain: domain, txt: txt, deviceId: deviceId)
    }

    private func resolveEndpoint(
        _ result: NWBrowser.Result,
        key: String,
        name: String,
        domain: String,
        txt: [String: String],
        deviceId: String?
    ) {
        resolveConnections[key]?.cancel()

        let connection = NWConnection(to: result.endpoint, using: .tcp)
        resolveConnections[key] = connection

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                let host: String
                let port: Int
                if case let .hostPort(endpointHost, endpointPort) = connection.currentPath?.remoteEndpoint {
                    // NWEndpoint.Host string forms often include "%en0" zone IDs — strip them.
                    host = DeviceEndpointResolver.sanitizeHost(self.string(from: endpointHost))
                    port = Int(endpointPort.rawValue)
                } else {
                    host = self.hostLabel(from: name, domain: domain)
                    port = 80
                }

                let resolved = DiscoveredService(
                    id: key,
                    deviceId: deviceId,
                    name: name,
                    host: host,
                    port: port,
                    txt: txt
                )

                if BonjourDiscoveryFilter.isCandidate(serviceName: name, host: host, txt: txt) {
                    self.services[key] = resolved
                    self.publish()
                }

                connection.cancel()
                self.resolveConnections.removeValue(forKey: key)
            case .failed, .cancelled:
                connection.cancel()
                self.resolveConnections.removeValue(forKey: key)
            default:
                break
            }
        }

        connection.start(queue: queue)
    }

    private func publish() {
        let deduped = BonjourDiscoveryFilter.deduplicate(Array(services.values))
        DispatchQueue.main.async { [weak self] in
            self?.onUpdate?(deduped)
        }
    }

    private func serviceKey(for result: NWBrowser.Result) -> String {
        if case let .service(name, type, domain, _) = result.endpoint {
            return "\(name).\(type).\(domain)"
        }
        return result.endpoint.debugDescription
    }

    private func hostLabel(from name: String, domain: String) -> String {
        let trimmedDomain = domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        if trimmedDomain.isEmpty {
            return "\(name).local"
        }
        return "\(name).\(trimmedDomain)"
    }

    private func string(from host: NWEndpoint.Host) -> String {
        switch host {
        case let .name(hostname, _):
            return hostname
        case let .ipv4(address):
            return "\(address)"
        case let .ipv6(address):
            return "\(address)"
        @unknown default:
            return "\(host)"
        }
    }

    private func txtDictionary(from metadata: NWBrowser.Result.Metadata) -> [String: String] {
        guard case let .bonjour(txtRecord) = metadata else { return [:] }

        var dict: [String: String] = [:]
        for key in ["id", "path", "name"] {
            if let entry = txtRecord.getEntry(for: key) {
                dict[key] = stringValue(from: entry)
            }
        }
        return dict
    }

    private func stringValue(from entry: NWTXTRecord.Entry) -> String {
        switch entry {
        case let .string(value):
            return value
        case let .data(value):
            return String(data: value, encoding: .utf8) ?? ""
        @unknown default:
            return ""
        }
    }
}
