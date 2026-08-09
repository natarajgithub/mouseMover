import SwiftData
import SwiftUI

struct DeviceDetailView: View {
    @Bindable var device: StoredDevice
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: HomeViewModel

    @State private var displayName: String = ""
    @State private var apiToken: String = ""
    @State private var showDeleteConfirmation = false

    var body: some View {
        Form {
            Section("Display Name") {
                TextField("Name", text: $displayName)
                    .onSubmit { saveDisplayName() }
            }

            Section("Device") {
                LabeledContent("Device ID", value: device.deviceId)
                if let version = device.firmwareVersion {
                    LabeledContent("Firmware", value: version)
                }
                LabeledContent("mDNS", value: device.mdnsHost)
                if let staIP = device.staIP {
                    LabeledContent("STA IP", value: staIP)
                }
                if let lastSeen = device.lastSeen {
                    LabeledContent("Last Seen") {
                        Text(lastSeen, style: .relative)
                    }
                }
            }

            Section("Auth") {
                TextField("API Token (optional)", text: $apiToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { saveApiToken() }
            }

            Section("Jiggle") {
                Toggle("Enable jiggle", isOn: jiggleBinding)
            }

            Section {
                Button("Delete Device", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
        .navigationTitle(displayName.isEmpty ? device.displayName : displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            displayName = device.displayName
            apiToken = device.apiToken ?? ""
        }
        .onDisappear {
            saveDisplayName()
            saveApiToken()
        }
        .confirmationDialog(
            "Delete this device?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteDevice()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the device from your saved list.")
        }
    }

    private var jiggleBinding: Binding<Bool> {
        Binding(
            get: { device.jiggleEnabled },
            set: { newValue in
                Task {
                    await viewModel.setJiggle(device: device, enabled: newValue, context: modelContext)
                }
            }
        )
    }

    private func saveDisplayName() {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != device.displayName else { return }
        let repository = DeviceRepository(context: modelContext)
        try? repository.rename(device, name: trimmed)
    }

    private func saveApiToken() {
        let repository = DeviceRepository(context: modelContext)
        let trimmed = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let newToken = trimmed.isEmpty ? nil : trimmed
        guard newToken != device.apiToken else { return }
        try? repository.updateApiToken(device, token: newToken)
    }

    private func deleteDevice() {
        let repository = DeviceRepository(context: modelContext)
        try? repository.delete(device)
        dismiss()
    }
}
