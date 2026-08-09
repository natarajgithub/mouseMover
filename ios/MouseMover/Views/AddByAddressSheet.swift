import SwiftData
import SwiftUI

struct AddByAddressSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var storedDevices: [StoredDevice]

    @State private var step: Step = .enterAddress
    @State private var host = ""
    @State private var token = ""
    @State private var displayName = ""
    @State private var apiToken = ""
    @State private var probed: ProbedDevice?
    @State private var isWorking = false
    @State private var errorMessage: String?

    private let apiClient: any DeviceAPIClientProtocol = DeviceAPIClient()

    private enum Step: Equatable {
        case enterAddress
        case confirm
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .enterAddress:
                    enterAddressForm
                case .confirm:
                    if let probed {
                        ConfirmDeviceForm(
                            probed: probed,
                            displayName: $displayName,
                            apiToken: $apiToken,
                            showsAuthTokenField: probed.status.authRequired || !token.isEmpty
                        )
                    }
                }
            }
            .navigationTitle(step == .confirm ? "Confirm Device" : "Add by Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert("Notice", isPresented: errorAlertBinding) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .interactiveDismissDisabled(isWorking)
            .overlay {
                if isWorking {
                    ProgressView(step == .confirm ? "Saving…" : "Probing device…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var enterAddressForm: some View {
        Form {
            Section {
                TextField("Host or IP", text: $host, prompt: Text("hid-helper.local or 192.168.2.161"))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                TextField("API Token (optional)", text: $token)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text("We'll look up the device and let you confirm before saving.")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(step == .confirm ? "Back" : "Cancel") {
                if step == .confirm {
                    step = .enterAddress
                    probed = nil
                } else {
                    dismiss()
                }
            }
            .disabled(isWorking)
        }

        ToolbarItem(placement: .confirmationAction) {
            switch step {
            case .enterAddress:
                Button("Next") {
                    Task { await probeAddress() }
                }
                .disabled(host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)
            case .confirm:
                Button("Save") {
                    Task { await saveDevice() }
                }
                .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)
            }
        }
    }

    private func probeAddress() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let optionalToken = trimmedToken.isEmpty ? nil : trimmedToken

        let index = SavedDeviceIndex(devices: storedDevices)
        let provisional = DiscoveredService(
            id: "manual-\(trimmedHost)",
            deviceId: nil,
            name: trimmedHost,
            host: trimmedHost,
            port: 80
        )
        if let existing = index.match(candidate: provisional) {
            errorMessage = SavedDeviceIndex.alreadyExistsMessage(displayName: existing.displayName)
            return
        }

        do {
            let repository = DeviceRepository(context: modelContext)
            let result = try await repository.probeByAddress(
                host: trimmedHost,
                token: optionalToken,
                api: apiClient
            )
            probed = result
            displayName = AddDeviceWizardViewModel.defaultDisplayName(for: result.status)
            apiToken = optionalToken ?? ""
            step = .confirm
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveDevice() async {
        guard let probed else { return }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Friendly name is required."
            return
        }

        let trimmedToken = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokenToSave = trimmedToken.isEmpty ? nil : trimmedToken

        if probed.status.authRequired && tokenToSave == nil {
            errorMessage = "This device requires an API token."
            return
        }

        do {
            let repository = DeviceRepository(context: modelContext)
            _ = try await repository.addFromDiscovery(
                status: probed.status,
                fallbackHost: probed.candidate.host,
                displayName: trimmedName,
                token: tokenToSave,
                api: apiClient
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
