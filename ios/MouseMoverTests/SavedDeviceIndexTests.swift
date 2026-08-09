import SwiftData
import XCTest
@testable import MouseMover

final class SavedDeviceIndexTests: XCTestCase {
    func testMatchesByDeviceId() {
        let device = StoredDevice(
            deviceId: "1cdbd4862378",
            displayName: "Desk",
            mdnsHost: "hid-helper-2378.local",
            staIP: "192.168.2.161"
        )
        let index = SavedDeviceIndex(devices: [device])
        let candidate = DiscoveredService(
            id: "1",
            deviceId: "1cdbd4862378",
            name: "hid-helper-2378",
            host: "192.168.2.200",
            port: 80
        )
        XCTAssertEqual(index.match(candidate: candidate)?.displayName, "Desk")
    }

    func testMatchesByIP() {
        let device = StoredDevice(
            deviceId: "abc",
            displayName: "Lab",
            mdnsHost: "hid-helper-abcd.local",
            staIP: "192.168.2.161"
        )
        let index = SavedDeviceIndex(devices: [device])
        let candidate = DiscoveredService(
            id: "1",
            deviceId: nil,
            name: "hid-helper",
            host: "192.168.2.161%en0",
            port: 80
        )
        XCTAssertEqual(index.match(candidate: candidate)?.displayName, "Lab")
    }

    func testMatchesStatusByHost() {
        let device = StoredDevice(
            deviceId: "xyz",
            displayName: "Office",
            mdnsHost: "hid-helper-xyz.local",
            staIP: "10.0.0.5"
        )
        let index = SavedDeviceIndex(devices: [device])
        let status = DeviceStatus(
            ok: true,
            name: "usb-hid-s3",
            version: "0.4.0",
            deviceId: "other-id",
            jiggle: false,
            jiggleIntervalMs: 10000,
            staIp: "10.0.0.5",
            mdns: "hid-helper-other.local"
        )
        XCTAssertEqual(index.match(status: status, host: "ignored")?.displayName, "Office")
    }

    func testNoMatchForUnknownDevice() {
        let index = SavedDeviceIndex.empty
        let candidate = DiscoveredService(
            id: "1",
            deviceId: "new",
            name: "hid-helper-new",
            host: "192.168.1.1",
            port: 80
        )
        XCTAssertNil(index.match(candidate: candidate))
    }
}

@MainActor
final class DeviceRepositoryDuplicateTests: XCTestCase {
    func testProbeByAddressThrowsAlreadyExists() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StoredDevice.self, configurations: config)
        let context = ModelContext(container)
        context.insert(
            StoredDevice(
                deviceId: "dup-id",
                displayName: "Already Here",
                mdnsHost: "hid-helper-dup.local",
                staIP: "192.168.2.50"
            )
        )
        try context.save()

        let mockAPI = MockAPIClient()
        let baseURL = URL(string: "http://192.168.2.50/")!
        mockAPI.statusResults[baseURL] = .success(
            DeviceStatus(
                ok: true,
                name: "usb-hid-s3",
                version: "0.4.0",
                deviceId: "dup-id",
                jiggle: false,
                jiggleIntervalMs: 10000,
                staIp: "192.168.2.50",
                mdns: "hid-helper-dup.local"
            )
        )

        let repository = DeviceRepository(context: context)
        do {
            _ = try await repository.probeByAddress(host: "192.168.2.50", token: nil, api: mockAPI)
            XCTFail("Expected alreadyExists")
        } catch let error as DeviceRepositoryError {
            guard case let .alreadyExists(name) = error else {
                return XCTFail("Unexpected error \(error)")
            }
            XCTAssertEqual(name, "Already Here")
        }
    }

    func testAddFromDiscoveryThrowsAlreadyExists() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StoredDevice.self, configurations: config)
        let context = ModelContext(container)
        context.insert(
            StoredDevice(
                deviceId: "save-dup",
                displayName: "Saved",
                mdnsHost: "hid-helper-save.local"
            )
        )
        try context.save()

        let status = DeviceStatus(
            ok: true,
            name: "usb-hid-s3",
            version: "0.4.0",
            deviceId: "save-dup",
            jiggle: false,
            jiggleIntervalMs: 10000,
            mdns: "hid-helper-save.local"
        )
        let repository = DeviceRepository(context: context)
        do {
            _ = try await repository.addFromDiscovery(
                status: status,
                fallbackHost: "hid-helper-save.local",
                displayName: "New Name",
                token: nil,
                api: MockAPIClient()
            )
            XCTFail("Expected alreadyExists")
        } catch let error as DeviceRepositoryError {
            guard case .alreadyExists = error else {
                return XCTFail("Unexpected error \(error)")
            }
        }
    }
}
