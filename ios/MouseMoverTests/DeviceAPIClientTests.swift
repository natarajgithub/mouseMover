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

    func testDecodeLegacyStatusWithoutAuthRequired() throws {
        // Live 0.3.3 firmware omits auth_required and device_id.
        let json = """
        {
          "ok": true,
          "name": "usb-hid-s3",
          "version": "0.3.3",
          "uptime_s": 46836,
          "heap": 188864,
          "usb": "not-ready",
          "jiggle": true,
          "jiggle_interval_ms": 10000,
          "sta_ip": "192.168.2.161",
          "mdns": "hid-helper.local"
        }
        """.data(using: .utf8)!

        let status = try JSONDecoder().decode(DeviceStatus.self, from: json)

        XCTAssertEqual(status.version, "0.3.3")
        XCTAssertTrue(status.jiggle)
        XCTAssertNil(status.deviceId)
        XCTAssertFalse(status.authRequired)
        XCTAssertEqual(status.staIp, "192.168.2.161")
    }

    func testDecodeWifiStatusStubJSON() throws {
        let json = """
        {
          "mode": "ap",
          "configured": false,
          "ssid": "",
          "ap_ssid": "usb-hid-s3-abcd",
          "ap_ip": "192.168.4.1",
          "sta_ip": "",
          "device_id": "a1b2c3d4"
        }
        """.data(using: .utf8)!

        let wifi = try JSONDecoder().decode(WifiStatus.self, from: json)

        XCTAssertEqual(wifi.mode, "ap")
        XCTAssertEqual(wifi.configured, false)
        XCTAssertEqual(wifi.apSsid, "usb-hid-s3-abcd")
        XCTAssertEqual(wifi.apIp, "192.168.4.1")
        XCTAssertEqual(wifi.deviceId, "a1b2c3d4")
    }
}
