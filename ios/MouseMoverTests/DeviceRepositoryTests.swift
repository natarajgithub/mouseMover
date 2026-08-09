import SwiftData
import XCTest
@testable import MouseMover

@MainActor
final class DeviceRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var mockAPI: MockAPIClient!
    private var repository: DeviceRepository!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: StoredDevice.self, configurations: config)
        context = ModelContext(container)
        mockAPI = MockAPIClient()
        repository = DeviceRepository(context: context)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
        mockAPI = nil
        repository = nil
    }

    func testSetJiggleUpdatesEnabledFlag() async throws {
        let device = StoredDevice(
            deviceId: "abc123",
            displayName: "Test Device",
            mdnsHost: "hid-helper-abc123.local",
            staIP: "192.168.2.50",
            jiggleEnabled: false
        )
        context.insert(device)
        try context.save()

        let baseURL = URL(string: "http://hid-helper-abc123.local/")!
        mockAPI.setJiggleResults[baseURL] = .success(())

        try await repository.setJiggle(device, enabled: true, api: mockAPI)

        XCTAssertTrue(device.jiggleEnabled)
        XCTAssertEqual(mockAPI.setJiggleCalls.count, 1)
        XCTAssertEqual(mockAPI.setJiggleCalls.first?.1, true)
    }

    func testSetJiggleFallsBackToStaIP() async throws {
        let device = StoredDevice(
            deviceId: "abc456",
            displayName: "Fallback Device",
            mdnsHost: "missing.local",
            staIP: "192.168.2.99",
            jiggleEnabled: false
        )
        context.insert(device)
        try context.save()

        let mdnsURL = URL(string: "http://missing.local/")!
        let ipURL = URL(string: "http://192.168.2.99/")!
        mockAPI.setJiggleResults[mdnsURL] = .failure(DeviceAPIError.invalidResponse)
        mockAPI.setJiggleResults[ipURL] = .success(())

        try await repository.setJiggle(device, enabled: true, api: mockAPI)

        XCTAssertTrue(device.jiggleEnabled)
        XCTAssertEqual(mockAPI.setJiggleCalls.count, 2)
        XCTAssertEqual(mockAPI.setJiggleCalls.last?.0, ipURL)
    }

    func testRenamePersistsDisplayName() throws {
        let device = StoredDevice(
            deviceId: "rename-me",
            displayName: "Old Name",
            mdnsHost: "hid.local"
        )
        context.insert(device)
        try context.save()

        try repository.rename(device, name: "Desk Mouse")

        XCTAssertEqual(device.displayName, "Desk Mouse")
    }
}

final class DeviceEndpointResolverTests: XCTestCase {
    func testEndpointURLsPrefersMdnsThenStaIP() {
        let urls = DeviceEndpointResolver.endpointURLs(
            mdnsHost: "hid-helper-a1b2.local",
            staIP: "192.168.2.161"
        )

        XCTAssertEqual(urls.count, 2)
        XCTAssertEqual(urls[0].absoluteString, "http://hid-helper-a1b2.local/")
        XCTAssertEqual(urls[1].absoluteString, "http://192.168.2.161/")
    }

    func testBaseURLAddsSchemeAndTrailingSlash() {
        XCTAssertEqual(
            DeviceEndpointResolver.baseURL(from: "hid-helper.local")?.absoluteString,
            "http://hid-helper.local/"
        )
    }

    func testBaseURLPreservesExistingScheme() {
        XCTAssertEqual(
            DeviceEndpointResolver.baseURL(from: "http://192.168.2.161")?.absoluteString,
            "http://192.168.2.161/"
        )
    }

    func testEndpointURLsDeduplicatesSameHost() {
        let urls = DeviceEndpointResolver.endpointURLs(
            mdnsHost: "192.168.2.161",
            staIP: "192.168.2.161"
        )
        XCTAssertEqual(urls.count, 1)
    }
}
