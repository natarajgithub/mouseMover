import Foundation
@testable import MouseMover

final class MockBonjourBrowser: BonjourBrowserProtocol {
    var onUpdate: (([DiscoveredService]) -> Void)?
    private(set) var isBrowsing = false
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func startBrowsing() {
        isBrowsing = true
        startCount += 1
    }

    func stopBrowsing() {
        isBrowsing = false
        stopCount += 1
    }

    func emit(_ services: [DiscoveredService]) {
        onUpdate?(services)
    }
}
