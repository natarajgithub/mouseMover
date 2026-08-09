import Foundation
import NetworkExtension

enum SoftAPJoinError: Error, LocalizedError, Equatable {
    case notSupported
    case invalidSSID
    case userDenied
    case joinFailed(String)

    var errorDescription: String? {
        switch self {
        case .notSupported:
            "Joining Wi‑Fi networks is not supported in the simulator. Connect manually in Settings, then tap Continue."
        case .invalidSSID:
            "Enter the device setup network name."
        case .userDenied:
            "Wi‑Fi join was cancelled."
        case let .joinFailed(message):
            message
        }
    }
}

protocol SoftAPJoinerProtocol: AnyObject {
    func join(ssid: String, password: String?) async throws
}

/// Joins the firmware Soft-AP during Wi‑Fi provisioning via NEHotspotConfiguration.
final class SoftAPJoiner: SoftAPJoinerProtocol {
    func join(ssid: String, password: String?) async throws {
        #if targetEnvironment(simulator)
        throw SoftAPJoinError.notSupported
        #else
        let trimmed = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SoftAPJoinError.invalidSSID
        }

        let configuration: NEHotspotConfiguration
        if let password, !password.isEmpty {
            configuration = NEHotspotConfiguration(ssid: trimmed, passphrase: password, isWEP: false)
        } else {
            configuration = NEHotspotConfiguration(ssid: trimmed)
        }
        configuration.joinOnce = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NEHotspotConfigurationManager.shared.apply(configuration) { error in
                if let error = error as NSError? {
                    if error.domain == NEHotspotConfigurationErrorDomain,
                       error.code == NEHotspotConfigurationError.alreadyAssociated.rawValue {
                        continuation.resume()
                        return
                    }
                    if error.domain == NEHotspotConfigurationErrorDomain,
                       error.code == NEHotspotConfigurationError.userDenied.rawValue {
                        continuation.resume(throwing: SoftAPJoinError.userDenied)
                        return
                    }
                    continuation.resume(throwing: SoftAPJoinError.joinFailed(error.localizedDescription))
                    return
                }
                continuation.resume()
            }
        }
        #endif
    }
}
