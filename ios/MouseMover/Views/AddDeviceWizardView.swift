import SwiftData
import SwiftUI

struct AddDeviceWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = AddDeviceWizardViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.step {
                case .choosePath:
                    choosePathStep
                case .scanning:
                    scanningStep
                case .confirm:
                    confirmStep
                case .softAPPlaceholder:
                    softAPPlaceholderStep
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { wizardToolbar }
            .alert("Error", isPresented: errorAlertBinding) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .interactiveDismissDisabled(viewModel.isProbing || viewModel.isSaving)
        }
    }

    private var navigationTitle: String {
        switch viewModel.step {
        case .choosePath:
            "Add Device"
        case .scanning:
            "Scan Network"
        case .confirm:
            "Confirm Device"
        case .softAPPlaceholder:
            "Set Up New Device"
        }
    }

    @ToolbarContentBuilder
    private var wizardToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                viewModel.cancelWizard()
                dismiss()
            }
            .disabled(viewModel.isProbing || viewModel.isSaving)
        }

        if case .confirm = viewModel.step {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await saveDevice() }
                }
                .disabled(viewModel.isSaving || viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var choosePathStep: some View {
        List {
            Section {
                Button {
                    viewModel.chooseScan()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scan Local Network")
                                .foregroundStyle(.primary)
                            Text("Find HID helpers already on your Wi‑Fi.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "dot.radiowaves.left.and.right")
                    }
                }

                Button {
                    viewModel.chooseSoftAP()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Set Up New Device (Soft‑AP)")
                                    .foregroundStyle(.secondary)
                                Text("Coming next")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary)
                                    .clipShape(Capsule())
                            }
                            Text("Join the device setup network and provision Wi‑Fi.")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    } icon: {
                        Image(systemName: "wifi.router")
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(true)
            } footer: {
                Text("Scanning uses Bonjour to find `_http._tcp` services advertising HID helpers on your LAN.")
            }
        }
    }

    private var scanningStep: some View {
        Group {
            if viewModel.candidates.isEmpty {
                ContentUnavailableView {
                    Label("Scanning…", systemImage: "antenna.radiowaves.left.and.right")
                } description: {
                    Text("Looking for HID helpers on your local network.")
                }
            } else {
                List(viewModel.candidates) { candidate in
                    Button {
                        Task { await viewModel.selectCandidate(candidate) }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("\(candidate.host):\(candidate.port)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let deviceId = candidate.deviceId {
                                Text(deviceId)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .disabled(viewModel.isProbing)
                }
            }
        }
        .overlay {
            if viewModel.isProbing {
                ProgressView("Probing device…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    @ViewBuilder
    private var confirmStep: some View {
        if let probed = viewModel.probedDevice {
            Form {
                Section("Device") {
                    LabeledContent("Name", value: probed.status.name)
                    LabeledContent("Version", value: probed.status.version)
                    if let deviceId = probed.status.deviceId {
                        LabeledContent("Device ID", value: deviceId)
                    }
                    if let staIP = probed.status.staIp {
                        LabeledContent("IP", value: staIP)
                    }
                    LabeledContent("Host", value: probed.candidate.host)
                }

                Section {
                    TextField("Display Name", text: $viewModel.displayName)
                } footer: {
                    Text("Shown in your device list on this iPhone.")
                }

                if viewModel.showsAuthTokenField {
                    Section {
                        TextField("API Token", text: $viewModel.apiToken)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } footer: {
                        Text("This device requires an API token for control.")
                    }
                }
            }
        }
    }

    private var softAPPlaceholderStep: some View {
        ContentUnavailableView(
            "Soft‑AP Setup",
            systemImage: "wifi.router",
            description: Text("Guided Wi‑Fi provisioning for new devices is coming in the next release.")
        )
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("Back") {
                    viewModel.backToChoosePath()
                }
            }
        }
    }

    private func saveDevice() async {
        do {
            try await viewModel.saveDevice(context: modelContext)
            dismiss()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

#Preview {
    AddDeviceWizardView()
        .modelContainer(for: StoredDevice.self, inMemory: true)
}
