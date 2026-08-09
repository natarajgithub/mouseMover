import Foundation

enum DeviceEndpointResolver {
    /// Strips IPv4/IPv6 zone/interface suffixes (e.g. `192.168.2.161%en0` → `192.168.2.161`).
    static func sanitizeHost(_ host: String) -> String {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let percent = trimmed.firstIndex(of: "%") else { return trimmed }
        return String(trimmed[..<percent])
    }

    /// Candidate base URLs in preference order: mDNS host first, then STA IP.
    static func endpointURLs(mdnsHost: String, staIP: String?) -> [URL] {
        var urls: [URL] = []
        if let mdnsURL = baseURL(from: mdnsHost) {
            urls.append(mdnsURL)
        }
        if let staIP, let ipURL = baseURL(from: staIP), !urls.contains(ipURL) {
            urls.append(ipURL)
        }
        return urls
    }

    static func baseURL(from host: String) -> URL? {
        let trimmed = sanitizeHost(host)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            var urlString = trimmed
            if !urlString.hasSuffix("/") {
                urlString += "/"
            }
            return URL(string: urlString)
        }

        // Bracket IPv6 literals when building a URL.
        let hostPart: String
        if trimmed.contains(":"), !trimmed.hasPrefix("["), !trimmed.lowercased().hasSuffix(".local") {
            hostPart = "[\(trimmed)]"
        } else {
            hostPart = trimmed
        }

        return URL(string: "http://\(hostPart)/")
    }

    static func baseURL(host: String, port: Int) -> URL? {
        let trimmed = sanitizeHost(host)
        guard !trimmed.isEmpty else { return nil }
        if port == 80 {
            return baseURL(from: trimmed)
        }
        let hostPart: String
        if trimmed.contains(":"), !trimmed.hasPrefix("["), !trimmed.lowercased().hasSuffix(".local") {
            hostPart = "[\(trimmed)]"
        } else {
            hostPart = trimmed
        }
        return URL(string: "http://\(hostPart):\(port)/")
    }
}
