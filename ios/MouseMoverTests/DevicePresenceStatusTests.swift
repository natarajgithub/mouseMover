import XCTest
@testable import MouseMover

final class DevicePresenceStatusTests: XCTestCase {
    func testOfflineWhenUnreachable() {
        let status = DevicePresenceStatus.resolve(
            isReachable: false,
            jiggleEnabled: true,
            staIP: "192.168.2.161"
        )
        XCTAssertEqual(status, .offline)
        XCTAssertEqual(status.title, "Offline")
    }

    func testReadyToMoveWhenOnlineAndJiggleOff() {
        let status = DevicePresenceStatus.resolve(
            isReachable: true,
            jiggleEnabled: false,
            staIP: "192.168.2.161"
        )
        XCTAssertEqual(status, .readyToMove)
        XCTAssertEqual(status.title, "Ready to move")
    }

    func testMovingWhenOnlineAndJiggleOn() {
        let status = DevicePresenceStatus.resolve(
            isReachable: true,
            jiggleEnabled: true,
            staIP: "192.168.2.161"
        )
        XCTAssertEqual(status, .moving)
        XCTAssertEqual(status.title, "Moving")
    }

    func testSetupWhenReachableWithoutStaIP() {
        let status = DevicePresenceStatus.resolve(
            isReachable: true,
            jiggleEnabled: false,
            staIP: nil
        )
        XCTAssertEqual(status, .setup)
        XCTAssertEqual(status.title, "Setup")
    }

    func testSetupWhenStaIPEmpty() {
        let status = DevicePresenceStatus.resolve(
            isReachable: true,
            jiggleEnabled: false,
            staIP: "  "
        )
        XCTAssertEqual(status, .setup)
    }
}
