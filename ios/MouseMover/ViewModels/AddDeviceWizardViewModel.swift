import Foundation
import SwiftData

enum AddDeviceWizardStep: Equatable {
    case choosePath
    case scanning
    case confirm(ProbedDevice)
    case softAPPlaceholder
}

struct ProbedDevice: Equatable {
    let candidate: DiscoveredService
    let status: DeviceStatus
    let baseURL: URL
}

@MainActor
final class AddDeviceWizardViewModel: ObservableObject {
    @Published private(set) var step: AddDeviceWizardStep = .choosePath
    @Published private(set) var candidates: [DiscoveredService] = []
    @Published private(set) var isProbing = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?
    @Published var displayName = ""
    @Published var apiToken = ""

    private let browser: any BonjourBrowserProtocol
    private let apiClient: any DeviceAPIClientProtocol

    init(
        browser: any BonjourBrowserProtocol = BonjourBrowser(),
        apiClient: any DeviceAPIClientProtocol = DeviceAPIClient()
    ) {
        self.browser = browser
        self.apiClient = apiClient
    }

    var probedDevice: ProbedDevice? {
        if case let .confirm(device) = step {
            return device
        }
        return nil
    }

    var showsAuthTokenField: Bool {
        probedDevice?.status.authRequired == true
    }

    func chooseScan() {
        errorMessage = nil
        step = .scanning
        browser.onUpdate = { [weak self] services in
            Task { @MainActor in
                self?.candidates = services
            }
        }
        browser.startBrowsing()
    }

    func chooseSoftAP() {
        browser.stopBrowsing()
        step = .softAPPlaceholder
    }

    func backToChoosePath() {
        browser.stopBrowsing()
        step = .choosePath
        candidates = []
        errorMessage = nil
    }

    func backFromConfirm() {
        errorMessage = nil
        step = .scanning
    }

    func cancelWizard() {
        browser.stopBrowsing()
        step = .choosePath
        candidates = []
        errorMessage = nil
        displayName = ""
        apiToken = ""
    }

    func selectCandidate(_ candidate: DiscoveredService) async {
        isProbing = true
        errorMessage = nil
        defer { isProbing = false }

        guard let baseURL = Self.baseURL(for: candidate) else {
            errorMessage = "Could not build a URL for this device."
            return
        }

        do {
            let status = try await apiClient.status(baseURL: baseURL, token: nil)
            displayName = Self.defaultDisplayName(for: status)
            apiToken = ""
            step = .confirm(ProbedDevice(candidate: candidate, status: status, baseURL: baseURL))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveDevice(context: ModelContext) async throws {
        guard case let .confirm(probed) = step else { return }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Display name is required."
            return
        }

        let trimmedToken = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = trimmedToken.isEmpty ? nil : trimmedToken

        if probed.status.authRequired && token == nil {
            errorMessage = "This device requires an API token."
            return
        }

        let repository = DeviceRepository(context: context)
        _ = try await repository.addFromDiscovery(
            status: probed.status,
            fallbackHost: probed.candidate.host,
            displayName: trimmedName,
            token: token,
            api: apiClient
        )

        browser.stopBrowsing()
    }

    static func baseURL(for candidate: DiscoveredService) -> URL? {
        if candidate.port == 80 {
            return DeviceEndpointResolver.baseURL(from: candidate.host)
        }
        return URL(string: "http://\(candidate.host):\(candidate.port)/")
    }

    static func defaultDisplayName(for status: DeviceStatus) -> String {
        if let deviceId = status.deviceId, deviceId.count >= 4 {
            return String(deviceId.suffix(4))
        }
        if !status.name.isEmpty {
            return status.name
        }
        return "HID Helper"
    }
}
