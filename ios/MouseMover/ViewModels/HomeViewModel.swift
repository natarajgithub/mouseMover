import Foundation
import SwiftData

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var isRefreshing = false
    @Published private(set) var offlineDeviceIds: Set<String> = []
    @Published var errorMessage: String?

    private let apiClient: any DeviceAPIClientProtocol

    init(apiClient: any DeviceAPIClientProtocol = DeviceAPIClient()) {
        self.apiClient = apiClient
    }

    func refreshAll(devices: [StoredDevice], context: ModelContext) async {
        guard !devices.isEmpty else {
            offlineDeviceIds = []
            return
        }

        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

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
            errorMessage = error.localizedDescription
        }
    }

    func addByAddress(host: String, token: String?, context: ModelContext) async throws {
        let repository = DeviceRepository(context: context)
        _ = try await repository.addByAddress(host: host, token: token, api: apiClient)
        errorMessage = nil
    }

    #if DEBUG
    func addSampleDevice(context: ModelContext) throws {
        let sample = StoredDevice(
            deviceId: "debug-sample-001",
            displayName: "Sample HID Helper",
            mdnsHost: "hid-helper-debug.local",
            staIP: "192.168.2.161",
            jiggleEnabled: false,
            firmwareVersion: "0.4.0"
        )
        context.insert(sample)
        try context.save()
    }
    #endif
}
