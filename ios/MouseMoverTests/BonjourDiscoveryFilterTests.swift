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
}
