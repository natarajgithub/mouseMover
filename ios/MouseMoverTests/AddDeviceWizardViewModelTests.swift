import SwiftData
import XCTest
@testable import MouseMover

@MainActor
final class AddDeviceWizardViewModelTests: XCTestCase {
    private var mockBrowser: MockBonjourBrowser!
    private var mockAPI: MockAPIClient!
    private var viewModel: AddDeviceWizardViewModel!

    override func setUp() {
        super.setUp()
        mockBrowser = MockBonjourBrowser()
        mockAPI = MockAPIClient()
        viewModel = AddDeviceWizardViewModel(browser: mockBrowser, apiClient: mockAPI)
    }

    override func tearDown() {
        viewModel = nil
        mockAPI = nil
        mockBrowser = nil
        super.tearDown()
    }

    func testChooseScanStartsBrowsing() {
        viewModel.chooseScan()

        XCTAssertEqual(viewModel.step, .scanning)
        XCTAssertTrue(mockBrowser.isBrowsing)
        XCTAssertEqual(mockBrowser.startCount, 1)
    }

    func testBrowseUpdatePopulatesCandidates() async {
        viewModel.chooseScan()

        let service = DiscoveredService(
            id: "hid-helper._http._tcp.local.",
            deviceId: "dev-001",
            name: "hid-helper",
            host: "hid-helper.local",
            port: 80,
            txt: ["id": "dev-001"]
        )
        mockBrowser.emit([service])
        await Task.yield()

        XCTAssertEqual(viewModel.candidates.count, 1)
        XCTAssertEqual(viewModel.candidates.first?.host, "hid-helper.local")
    }

    func testSelectCandidateProbesAndMovesToConfirm() async {
        viewModel.chooseScan()

        let service = DiscoveredService(
            id: "hid-helper._http._tcp.local.",
            deviceId: "abcd1234efgh",
            name: "hid-helper",
            host: "hid-helper.local",
            port: 80
        )
        let baseURL = URL(string: "http://hid-helper.local/")!
        mockAPI.statusResults[baseURL] = .success(
            DeviceStatus(
                ok: true,
                name: "Desk Helper",
                version: "0.4.0",
                deviceId: "abcd1234efgh",
                jiggle: false,
                jiggleIntervalMs: 30_000,
                staIp: "192.168.2.50",
                mdns: "hid-helper.local",
                authRequired: false
            )
        )

        await viewModel.selectCandidate(service)

        if case let .confirm(probed) = viewModel.step {
            XCTAssertEqual(probed.status.deviceId, "abcd1234efgh")
            XCTAssertEqual(viewModel.displayName, "efgh")
        } else {
            XCTFail("Expected confirm step")
        }
    }

    func testSelectCandidateSurfacesProbeError() async {
        viewModel.chooseScan()

        let service = DiscoveredService(
            id: "hid-helper._http._tcp.local.",
            deviceId: nil,
            name: "hid-helper",
            host: "hid-helper.local",
            port: 80
        )
        let baseURL = URL(string: "http://hid-helper.local/")!
        mockAPI.statusResults[baseURL] = .failure(DeviceAPIError.httpStatus(503))

        await viewModel.selectCandidate(service)

        XCTAssertEqual(viewModel.step, .scanning)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testSaveDevicePersistsViaRepository() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StoredDevice.self, configurations: config)
        let context = ModelContext(container)

        viewModel.chooseScan()
        let service = DiscoveredService(
            id: "hid-helper._http._tcp.local.",
            deviceId: "save-test-id",
            name: "hid-helper",
            host: "hid-helper.local",
            port: 80
        )
        let baseURL = URL(string: "http://hid-helper.local/")!
        mockAPI.statusResults[baseURL] = .success(
            DeviceStatus(
                ok: true,
                name: "Desk Helper",
                version: "0.4.0",
                deviceId: "save-test-id",
                jiggle: false,
                jiggleIntervalMs: 30_000,
                staIp: "192.168.2.50",
                mdns: "hid-helper.local",
                authRequired: false
            )
        )
        await viewModel.selectCandidate(service)
        viewModel.displayName = "My Desk"

        try await viewModel.saveDevice(context: context)

        let stored = try context.fetch(FetchDescriptor<StoredDevice>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.deviceId, "save-test-id")
        XCTAssertEqual(stored.first?.displayName, "My Desk")
        XCTAssertEqual(mockBrowser.stopCount, 1)
    }

    func testCancelWizardStopsBrowsingAndResets() {
        viewModel.chooseScan()
        mockBrowser.emit([
            DiscoveredService(
                id: "one",
                deviceId: nil,
                name: "hid-helper",
                host: "hid-helper.local",
                port: 80
            )
        ])

        viewModel.cancelWizard()

        XCTAssertEqual(viewModel.step, .choosePath)
        XCTAssertTrue(viewModel.candidates.isEmpty)
        XCTAssertEqual(mockBrowser.stopCount, 1)
    }

    func testDefaultDisplayNameUsesDeviceIdSuffix() {
        let status = DeviceStatus(
            ok: true,
            name: "ignored",
            version: "0.4.0",
            deviceId: "abcd1234wxyz",
            jiggle: false,
            jiggleIntervalMs: 30_000,
            staIp: nil,
            mdns: nil,
            authRequired: false
        )

        XCTAssertEqual(AddDeviceWizardViewModel.defaultDisplayName(for: status), "wxyz")
    }
}
