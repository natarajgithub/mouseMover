import XCTest
@testable import MouseMover

final class DeviceAPIClientTests: XCTestCase {
    func testDecodeDeviceStatusStubJSON() throws {
        let json = """
        {
          "ok": true,
          "name": "usb-hid-s3",
          "version": "0.4.0",
          "device_id": "a1b2c3d4",
          "jiggle": false,
          "jiggle_interval_ms": 10000,
          "sta_ip": "192.168.2.161",
          "mdns": "hid-helper-a1b2.local",
          "auth_required": false
        }
        """.data(using: .utf8)!

        let status = try JSONDecoder().decode(DeviceStatus.self, from: json)

        XCTAssertTrue(status.ok)
        XCTAssertEqual(status.name, "usb-hid-s3")
        XCTAssertEqual(status.version, "0.4.0")
        XCTAssertEqual(status.deviceId, "a1b2c3d4")
        XCTAssertFalse(status.jiggle)
        XCTAssertEqual(status.jiggleIntervalMs, 10_000)
        XCTAssertEqual(status.staIp, "192.168.2.161")
        XCTAssertEqual(status.mdns, "hid-helper-a1b2.local")
        XCTAssertFalse(status.authRequired)
    }
}
