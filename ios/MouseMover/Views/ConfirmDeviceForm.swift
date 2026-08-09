import SwiftUI

/// Shared confirm UI for scan and add-by-address flows.
struct ConfirmDeviceForm: View {
    let probed: ProbedDevice
    @Binding var displayName: String
    @Binding var apiToken: String
    var showsAuthTokenField: Bool

    var body: some View {
        Form {
            Section("Device") {
                LabeledContent("Name", value: probed.status.name)
                LabeledContent("Version", value: probed.status.version)
                if let deviceId = probed.status.deviceId {
                    LabeledContent("Device ID", value: deviceId)
                }
                ForEach(addressRows, id: \.label) { row in
                    LabeledContent(row.label, value: row.value)
                }
            }

            Section("Friendly name") {
                TextField("Name", text: $displayName)
            }

            if showsAuthTokenField {
                Section {
                    TextField("API Token", text: $apiToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("This device requires an API token for control.")
                }
            }
        }
    }

    private struct AddressRow: Equatable {
        let label: String
        let value: String
    }

    private var addressRows: [AddressRow] {
        let ip = probed.status.staIp.map(DeviceEndpointResolver.sanitizeHost)
        let candidateHost = DeviceEndpointResolver.sanitizeHost(probed.candidate.host)
        let mdns = probed.status.mdns.map(DeviceEndpointResolver.sanitizeHost)

        var rows: [AddressRow] = []
        var seen = Set<String>()

        func append(label: String, value: String?) {
            guard let value, !value.isEmpty else { return }
            let key = value.lowercased()
            guard !seen.contains(key) else { return }
            seen.insert(key)
            rows.append(AddressRow(label: label, value: value))
        }

        if let ip {
            append(label: "IP", value: ip)
        }
        append(label: "Hostname", value: mdns)
        if Self.ipv4Literal(candidateHost) == nil {
            append(label: "Hostname", value: candidateHost)
        } else if ip == nil {
            append(label: "IP", value: candidateHost)
        }
        return rows
    }

    private static func ipv4Literal(_ host: String) -> String? {
        let parts = host.split(separator: ".")
        guard parts.count == 4, parts.allSatisfy({ UInt8($0) != nil }) else { return nil }
        return host
    }
}
