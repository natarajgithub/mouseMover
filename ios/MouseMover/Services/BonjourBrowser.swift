import Foundation

struct DiscoveredService: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let host: String
    let port: Int
}

protocol BonjourBrowserProtocol: AnyObject {
    var onUpdate: (([DiscoveredService]) -> Void)? { get set }
    func startBrowsing()
    func stopBrowsing()
}

/// Stub for NWBrowser-based mDNS discovery of `_http._tcp.` services.
final class BonjourBrowser: BonjourBrowserProtocol {
    var onUpdate: (([DiscoveredService]) -> Void)?

    func startBrowsing() {
        // Phase 2: implement with Network.framework NWBrowser.
    }

    func stopBrowsing() {
        // Phase 2: tear down browser.
    }
}
