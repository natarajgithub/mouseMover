import XCTest
@testable import MouseMover

final class BonjourDiscoveryFilterTests: XCTestCase {
    func testAcceptsTxtIdKey() {
        XCTAssertTrue(
            BonjourDiscoveryFilter.isCandidate(
                serviceName: "printer",
                host: "office.local",
                txt: ["id": "abc123"]
            )
        )
    }

    func testAcceptsHidHelperInServiceName() {
        XCTAssertTrue(
            BonjourDiscoveryFilter.isCandidate(
                serviceName: "hid-helper-a1b2",
                host: "esp32.local",
                txt: ["path": "/api/status"]
            )
        )
    }

    func testAcceptsHidHelperInHost() {
        XCTAssertTrue(
            BonjourDiscoveryFilter.isCandidate(
                serviceName: "http",
                host: "hid-helper.local",
                txt: [:]
            )
        )
    }

    func testRejectsUnrelatedService() {
        XCTAssertFalse(
            BonjourDiscoveryFilter.isCandidate(
                serviceName: "homeassistant",
                host: "hass.local",
                txt: ["path": "/"]
            )
        )
    }

    func testHidHelperMatchIsCaseInsensitive() {
        XCTAssertTrue(
            BonjourDiscoveryFilter.isCandidate(
                serviceName: "HID-HELPER",
                host: "other.local",
                txt: [:]
            )
        )
    }

    func testDeduplicatesSameIP() {
        let a = DiscoveredService(
            id: "1",
            deviceId: nil,
            name: "hid-helper",
            host: "192.168.2.161",
            port: 80
        )
        let b = DiscoveredService(
            id: "2",
            deviceId: "1cdbd4862378",
            name: "hid-helper-2378",
            host: "192.168.2.161",
            port: 80,
            txt: ["id": "1cdbd4862378"]
        )
        let result = BonjourDiscoveryFilter.deduplicate([a, b])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "hid-helper-2378")
        XCTAssertEqual(result[0].deviceId, "1cdbd4862378")
        XCTAssertEqual(result[0].host, "192.168.2.161")
    }

    func testDeduplicatesLegacyBareNameWithVersioned() {
        let legacy = DiscoveredService(
            id: "legacy",
            deviceId: nil,
            name: "hid-helper",
            host: "hid-helper.local",
            port: 80
        )
        let current = DiscoveredService(
            id: "current",
            deviceId: "1cdbd4862378",
            name: "hid-helper-2378",
            host: "hid-helper-2378.local",
            port: 80,
            txt: ["id": "1cdbd4862378"]
        )
        let result = BonjourDiscoveryFilter.deduplicate([legacy, current])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "hid-helper-2378")
    }

    func testKeepsDistinctDevices() {
        let a = DiscoveredService(
            id: "1",
            deviceId: "aaa",
            name: "hid-helper-aaaa",
            host: "192.168.2.10",
            port: 80
        )
        let b = DiscoveredService(
            id: "2",
            deviceId: "bbb",
            name: "hid-helper-bbbb",
            host: "192.168.2.20",
            port: 80
        )
        let result = BonjourDiscoveryFilter.deduplicate([a, b])
        XCTAssertEqual(result.count, 2)
    }
}
