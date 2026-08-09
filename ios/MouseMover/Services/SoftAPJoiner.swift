import Foundation

enum SoftAPJoinError: Error, Equatable {
    case notSupported
    case joinFailed
}

protocol SoftAPJoinerProtocol: AnyObject {
    func joinSetupNetwork(ssid: String) async throws
    func leaveSetupNetwork() async
}

/// Stub for joining the firmware Soft-AP (`usb-hid-s3-setup`) during WiFi provisioning.
final class SoftAPJoiner: SoftAPJoinerProtocol {
    func joinSetupNetwork(ssid: String) async throws {
        throw SoftAPJoinError.notSupported
    }

    func leaveSetupNetwork() async {
        // Phase 4: restore prior WiFi association.
    }
}
