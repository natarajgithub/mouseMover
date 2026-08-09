import Foundation

enum DeviceEndpointResolver {
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
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            var urlString = trimmed
            if !urlString.hasSuffix("/") {
                urlString += "/"
            }
            return URL(string: urlString)
        }

        return URL(string: "http://\(trimmed)/")
    }
}
