import Foundation
import SwiftData

@MainActor
final class HomeViewModel: ObservableObject {
    static let presencePollNanoseconds: UInt64 = 15_000_000_000

    @Published private(set) var isRefreshing = false
    @Published private(set) var offlineDeviceIds: Set<String> = []
    @Published var errorMessage: String?

    private let apiClient: any DeviceAPIClientProtocol
    private var refreshInFlight = false

    init(apiClient: any DeviceAPIClientProtocol = DeviceAPIClient()) {
        self.apiClient = apiClient
    }

    /// Pull-to-refresh: may drive `isRefreshing` for UI that observes it.
    func refreshAll(devices: [StoredDevice], context: ModelContext) async {
        await refreshAll(devices: devices, context: context, showIndicator: true)
    }

    /// Auto/resume poll: updates presence without toggling the refresh indicator.
    func refreshQuietly(devices: [StoredDevice], context: ModelContext) async {
        await refreshAll(devices: devices, context: context, showIndicator: false)
    }

    /// Probe a single device and merge into `offlineDeviceIds` (does not wipe others).
    func refreshDevice(_ device: StoredDevice, context: ModelContext) async {
        let repository = DeviceRepository(context: context)
        let failed = await repository.refreshAll(devices: [device], api: apiClient)
        if failed.contains(device.deviceId) {
            offlineDeviceIds.insert(device.deviceId)
        } else {
            offlineDeviceIds.remove(device.deviceId)
        }
    }

    private func refreshAll(
        devices: [StoredDevice],
        context: ModelContext,
        showIndicator: Bool
    ) async {
        guard !devices.isEmpty else {
            offlineDeviceIds = []
            return
        }
        guard !refreshInFlight else { return }
        refreshInFlight = true
        if showIndicator { isRefreshing = true }
        errorMessage = nil
        defer {
            refreshInFlight = false
            if showIndicator { isRefreshing = false }
        }

        let repository = DeviceRepository(context: context)
        offlineDeviceIds = await repository.refreshAll(devices: devices, api: apiClient)
    }

    func setJiggle(device: StoredDevice, enabled: Bool, context: ModelContext) async {
        let previous = device.jiggleEnabled
        device.jiggleEnabled = enabled

        let repository = DeviceRepository(context: context)
        do {
            try await repository.setJiggle(device, enabled: enabled, api: apiClient)
            offlineDeviceIds.remove(device.deviceId)
        } catch {
            device.jiggleEnabled = previous
            offlineDeviceIds.insert(device.deviceId)
            errorMessage = error.localizedDescription
        }
    }
}
