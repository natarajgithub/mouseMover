import Foundation
import SwiftData

@Model
final class StoredDevice {
    @Attribute(.unique) var deviceId: String
    var displayName: String
    var mdnsHost: String
    var staIP: String?
    var apiToken: String?
    var jiggleEnabled: Bool
    var lastSeen: Date?
    var firmwareVersion: String?

    init(
        deviceId: String,
        displayName: String,
        mdnsHost: String,
        staIP: String? = nil,
        apiToken: String? = nil,
        jiggleEnabled: Bool = false,
        lastSeen: Date? = nil,
        firmwareVersion: String? = nil
    ) {
        self.deviceId = deviceId
        self.displayName = displayName
        self.mdnsHost = mdnsHost
        self.staIP = staIP
        self.apiToken = apiToken
        self.jiggleEnabled = jiggleEnabled
        self.lastSeen = lastSeen
        self.firmwareVersion = firmwareVersion
    }

    convenience init(device: Device) {
        self.init(
            deviceId: device.id,
            displayName: device.displayName,
            mdnsHost: device.mdnsHost,
            staIP: device.staIP,
            apiToken: device.apiToken,
            jiggleEnabled: device.jiggleEnabled,
            lastSeen: device.lastSeen,
            firmwareVersion: device.firmwareVersion
        )
    }

    func asDevice() -> Device {
        Device(
            id: deviceId,
            displayName: displayName,
            mdnsHost: mdnsHost,
            staIP: staIP,
            apiToken: apiToken,
            jiggleEnabled: jiggleEnabled,
            lastSeen: lastSeen,
            firmwareVersion: firmwareVersion
        )
    }
}

enum DeviceStore {
    static func upsert(_ device: Device, in context: ModelContext) throws {
        let deviceId = device.id
        var descriptor = FetchDescriptor<StoredDevice>(
            predicate: #Predicate { $0.deviceId == deviceId }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.displayName = device.displayName
            existing.mdnsHost = device.mdnsHost
            existing.staIP = device.staIP
            existing.apiToken = device.apiToken
            existing.jiggleEnabled = device.jiggleEnabled
            existing.lastSeen = device.lastSeen
            existing.firmwareVersion = device.firmwareVersion
        } else {
            context.insert(StoredDevice(device: device))
        }
        try context.save()
    }
}
