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
        let sorted = services.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        DispatchQueue.main.async { [weak self] in
            self?.onUpdate?(sorted)
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
