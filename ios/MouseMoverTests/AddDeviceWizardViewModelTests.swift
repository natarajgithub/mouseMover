import SwiftData
import XCTest
@testable import MouseMover

@MainActor
final class AddDeviceWizardViewModelTests: XCTestCase {
    private var mockBrowser: MockBonjourBrowser!
    private var mockAPI: MockAPIClient!
    private var mockJoiner: MockSoftAPJoiner!
    private var viewModel: AddDeviceWizardViewModel!

    private let softAPURL = AddDeviceWizardViewModel.softAPBaseURL

    override func setUp() {
        super.setUp()
        mockBrowser = MockBonjourBrowser()
        mockAPI = MockAPIClient()
        mockJoiner = MockSoftAPJoiner()
        viewModel = AddDeviceWizardViewModel(
            browser: mockBrowser,
            apiClient: mockAPI,
            softAPJoiner: mockJoiner
        )
    }

    override func tearDown() {
        viewModel = nil
        mockJoiner = nil
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
        mockAPI.statusResults[baseURL] = .success(sampleStatus(deviceId: "abcd1234efgh"))

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
        mockAPI.statusResults[baseURL] = .success(sampleStatus(deviceId: "save-test-id"))
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
        let status = sampleStatus(deviceId: "abcd1234wxyz")
        XCTAssertEqual(AddDeviceWizardViewModel.defaultDisplayName(for: status), "wxyz")
    }

    // MARK: - Soft-AP path

    func testChooseSoftAPMovesToInstructions() {
        viewModel.chooseSoftAP()

        XCTAssertEqual(viewModel.step, .softAPInstructions)
        XCTAssertFalse(mockBrowser.isBrowsing)
    }

    func testSoftAPInstructionsContinueMovesToJoin() {
        viewModel.chooseSoftAP()
        viewModel.continueFromSoftAPInstructions()

        XCTAssertEqual(viewModel.step, .softAPJoin)
        XCTAssertEqual(viewModel.softAPSSID, AddDeviceWizardViewModel.softAPSSIDPrefix)
    }

    func testJoinSoftAPProbesDeviceAndMovesToHomeWifi() async {
        viewModel.chooseSoftAP()
        viewModel.continueFromSoftAPInstructions()
        viewModel.softAPSSID = "usb-hid-s3-abcd"
        mockJoiner.joinResults["*"] = .success(())
        mockAPI.getWifiResults[softAPURL] = .success(
            WifiStatus(
                ok: nil,
                mode: "ap",
                configured: false,
                ssid: "",
                staIp: nil,
                deviceId: "provision-device-id",
                apSsid: "usb-hid-s3-abcd",
                apIp: "192.168.4.1"
            )
        )

        await viewModel.joinSoftAP()

        XCTAssertEqual(viewModel.step, .softAPHomeWifi)
        XCTAssertEqual(viewModel.expectedDeviceId, "provision-device-id")
        XCTAssertEqual(mockJoiner.joinCalls.count, 1)
        XCTAssertEqual(mockJoiner.joinCalls.first?.ssid, "usb-hid-s3-abcd")
    }

    func testJoinSoftAPFailureSurfacesError() async {
        viewModel.chooseSoftAP()
        viewModel.continueFromSoftAPInstructions()
        viewModel.softAPSSID = "usb-hid-s3-fail"
        mockJoiner.joinResults["*"] = .failure(SoftAPJoinError.userDenied)

        await viewModel.joinSoftAP()

        XCTAssertEqual(viewModel.step, .softAPJoin)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testContinueWithoutJoiningProbesDevice() async {
        viewModel.chooseSoftAP()
        viewModel.continueFromSoftAPInstructions()
        mockAPI.getWifiResults[softAPURL] = .success(
            WifiStatus(
                ok: nil,
                mode: "ap",
                configured: false,
                ssid: "",
                staIp: nil,
                deviceId: "manual-probe-id",
                apSsid: "usb-hid-s3-setup",
                apIp: "192.168.4.1"
            )
        )

        await viewModel.continueWithoutJoiningSoftAP()

        XCTAssertEqual(viewModel.step, .softAPHomeWifi)
        XCTAssertEqual(viewModel.expectedDeviceId, "manual-probe-id")
        XCTAssertTrue(mockJoiner.joinCalls.isEmpty)
    }

    func testProbeDeviceOnSoftAPFailureSurfacesError() async {
        viewModel.chooseSoftAP()
        viewModel.continueFromSoftAPInstructions()
        mockAPI.getWifiResults[softAPURL] = .failure(DeviceAPIError.httpStatus(503))

        await viewModel.probeDeviceOnSoftAP()

        XCTAssertEqual(viewModel.step, .softAPJoin)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testProvisionHomeWifiMovesToReconnect() async {
        viewModel.chooseSoftAP()
        viewModel.continueFromSoftAPInstructions()
        mockAPI.getWifiResults[softAPURL] = .success(softAPWifiStatus())
        await viewModel.continueWithoutJoiningSoftAP()

        viewModel.homeWifiSSID = "HomeNet"
        viewModel.homeWifiPassword = "secret"
        mockAPI.provisionWifiResults[softAPURL] = .success(())

        await viewModel.provisionHomeWifi()

        XCTAssertEqual(viewModel.step, .softAPReconnect)
        XCTAssertEqual(mockAPI.provisionWifiCalls.count, 1)
        XCTAssertEqual(mockAPI.provisionWifiCalls.first?.1, "HomeNet")
        XCTAssertEqual(mockAPI.provisionWifiCalls.first?.2, "secret")
    }

    func testContinueAfterReconnectStartsDiscovery() {
        viewModel.chooseSoftAP()
        viewModel.continueAfterHomeWifiReconnect()

        XCTAssertEqual(viewModel.step, .softAPDiscover)
        XCTAssertTrue(mockBrowser.isBrowsing)
    }

    func testSoftAPDiscoverFiltersByExpectedDeviceId() async {
        viewModel.chooseSoftAP()
        viewModel.continueFromSoftAPInstructions()
        mockAPI.getWifiResults[softAPURL] = .success(
            WifiStatus(
                ok: nil,
                mode: "ap",
                configured: false,
                ssid: "",
                staIp: nil,
                deviceId: "target-id",
                apSsid: "usb-hid-s3-abcd",
                apIp: "192.168.4.1"
            )
        )
        await viewModel.continueWithoutJoiningSoftAP()
        viewModel.continueAfterHomeWifiReconnect()

        mockBrowser.emit([
            DiscoveredService(id: "a", deviceId: "other-id", name: "hid-helper", host: "a.local", port: 80),
            DiscoveredService(id: "b", deviceId: "target-id", name: "hid-helper", host: "b.local", port: 80)
        ])
        await Task.yield()

        XCTAssertEqual(viewModel.filteredCandidates.count, 1)
        XCTAssertEqual(viewModel.filteredCandidates.first?.deviceId, "target-id")
    }

    func testSoftAPDiscoverSelectCandidateMovesToConfirm() async {
        viewModel.chooseSoftAP()
        viewModel.continueFromSoftAPInstructions()
        mockAPI.getWifiResults[softAPURL] = .success(softAPWifiStatus(deviceId: "target-id"))
        await viewModel.continueWithoutJoiningSoftAP()
        viewModel.continueAfterHomeWifiReconnect()

        let service = DiscoveredService(
            id: "target",
            deviceId: "target-id",
            name: "hid-helper",
            host: "hid-target.local",
            port: 80
        )
        let baseURL = URL(string: "http://hid-target.local/")!
        mockAPI.statusResults[baseURL] = .success(sampleStatus(deviceId: "target-id"))

        await viewModel.selectCandidate(service)

        if case let .confirm(probed) = viewModel.step {
            XCTAssertEqual(probed.status.deviceId, "target-id")
        } else {
            XCTFail("Expected confirm step")
        }
    }

    func testSoftAPDiscoverRejectsMismatchedDeviceId() async {
        viewModel.chooseSoftAP()
        viewModel.continueFromSoftAPInstructions()
        mockAPI.getWifiResults[softAPURL] = .success(softAPWifiStatus(deviceId: "target-id"))
        await viewModel.continueWithoutJoiningSoftAP()
        viewModel.continueAfterHomeWifiReconnect()

        let service = DiscoveredService(
            id: "wrong",
            deviceId: "wrong-id",
            name: "hid-helper",
            host: "hid-wrong.local",
            port: 80
        )
        let baseURL = URL(string: "http://hid-wrong.local/")!
        mockAPI.statusResults[baseURL] = .success(sampleStatus(deviceId: "wrong-id"))

        await viewModel.selectCandidate(service)

        XCTAssertEqual(viewModel.step, .softAPDiscover)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testProbeManualAddressMovesToConfirm() async {
        viewModel.chooseSoftAP()
        viewModel.continueFromSoftAPInstructions()
        mockAPI.getWifiResults[softAPURL] = .success(softAPWifiStatus(deviceId: "manual-id"))
        await viewModel.continueWithoutJoiningSoftAP()
        viewModel.continueAfterHomeWifiReconnect()
        viewModel.softAPManualHost = "192.168.2.99"

        let baseURL = URL(string: "http://192.168.2.99/")!
        mockAPI.statusResults[baseURL] = .success(sampleStatus(deviceId: "manual-id"))

        await viewModel.probeManualAddress()

        if case let .confirm(probed) = viewModel.step {
            XCTAssertEqual(probed.candidate.host, "192.168.2.99")
            XCTAssertEqual(probed.status.deviceId, "manual-id")
        } else {
            XCTFail("Expected confirm step")
        }
    }

    func testSoftAPSaveDevicePersistsViaRepository() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StoredDevice.self, configurations: config)
        let context = ModelContext(container)

        viewModel.chooseSoftAP()
        viewModel.continueFromSoftAPInstructions()
        mockAPI.getWifiResults[softAPURL] = .success(softAPWifiStatus(deviceId: "softap-save-id"))
        await viewModel.continueWithoutJoiningSoftAP()
        viewModel.continueAfterHomeWifiReconnect()

        let service = DiscoveredService(
            id: "save",
            deviceId: "softap-save-id",
            name: "hid-helper",
            host: "hid-save.local",
            port: 80
        )
        let baseURL = URL(string: "http://hid-save.local/")!
        mockAPI.statusResults[baseURL] = .success(sampleStatus(deviceId: "softap-save-id"))
        await viewModel.selectCandidate(service)
        viewModel.displayName = "SoftAP Desk"

        try await viewModel.saveDevice(context: context)

        let stored = try context.fetch(FetchDescriptor<StoredDevice>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.deviceId, "softap-save-id")
        XCTAssertEqual(stored.first?.displayName, "SoftAP Desk")
    }

    private func sampleStatus(deviceId: String) -> DeviceStatus {
        DeviceStatus(
            ok: true,
            name: "Desk Helper",
            version: "0.4.0",
            deviceId: deviceId,
            jiggle: false,
            jiggleIntervalMs: 30_000,
            staIp: "192.168.2.50",
            mdns: "hid-helper.local",
            authRequired: false
        )
    }

    private func softAPWifiStatus(deviceId: String = "provision-device-id") -> WifiStatus {
        WifiStatus(
            ok: nil,
            mode: "ap",
            configured: false,
            ssid: "",
            staIp: nil,
            deviceId: deviceId,
            apSsid: "usb-hid-s3-abcd",
            apIp: "192.168.4.1"
        )
    }
}
