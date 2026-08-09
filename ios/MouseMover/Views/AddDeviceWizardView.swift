import SwiftData
import SwiftUI

struct AddDeviceWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var storedDevices: [StoredDevice]
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
                case .softAPInstructions:
                    softAPInstructionsStep
                case .softAPJoin:
                    softAPJoinStep
                case .softAPHomeWifi:
                    softAPHomeWifiStep
                case .softAPReconnect:
                    softAPReconnectStep
                case .softAPDiscover:
                    softAPDiscoverStep
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { wizardToolbar }
            .alert("Notice", isPresented: errorAlertBinding) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .interactiveDismissDisabled(viewModel.isProbing || viewModel.isSaving || viewModel.isJoining || viewModel.isProvisioning)
            .onAppear { viewModel.updateKnownDevices(storedDevices) }
            .onChange(of: storedDevices.map(\.deviceId)) { _, _ in
                viewModel.updateKnownDevices(storedDevices)
            }
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
        case .softAPInstructions, .softAPJoin, .softAPHomeWifi, .softAPReconnect, .softAPDiscover:
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
            .disabled(viewModel.isProbing || viewModel.isSaving || viewModel.isJoining || viewModel.isProvisioning)
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
                            Text("Find Mouse Helper in your Network")
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
                            Text("Set Up New Device")
                                .foregroundStyle(.primary)
                            Text("Join the device setup network and provision Wi‑Fi.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "wifi.router")
                    }
                }
            } footer: {
                Text("Scanning uses Bonjour to find Mouse Helpers in your network")
            }
        }
    }

    private var scanningStep: some View {
        discoveryList(
            candidates: viewModel.newCandidates,
            emptyTitle: viewModel.hasHiddenKnownCandidates ? "Already Added" : "Scanning…",
            emptyDescription: viewModel.hasHiddenKnownCandidates
                ? "All Mouse Helpers found on the network are already in your device list."
                : "Looking for Mouse Helpers on your local network."
        )
    }

    private var softAPInstructionsStep: some View {
        List {
            Section {
                Label("Power on the HID helper.", systemImage: "power")
                Label("Wait for the magenta setup LED.", systemImage: "light.max")
                Label("The device broadcasts a setup Wi‑Fi network named like `usb-hid-s3-XXXX`.", systemImage: "wifi")
            } header: {
                Text("Before You Start")
            }

            Section {
                Button("Continue") {
                    viewModel.continueFromSoftAPInstructions()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("Back") {
                    viewModel.backToChoosePath()
                }
            }
        }
    }

    private var softAPJoinStep: some View {
        Form {
            Section {
                TextField("Setup network (SSID)", text: $viewModel.softAPSSID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password (optional for open networks)", text: $viewModel.softAPPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text("Join the device Soft‑AP, then we'll connect to it at 192.168.4.1.")
            }

            Section {
                Button {
                    Task { await viewModel.joinSoftAP() }
                } label: {
                    if viewModel.isJoining {
                        HStack {
                            ProgressView()
                            Text("Joining…")
                        }
                    } else {
                        Text("Join Setup Network")
                    }
                }
                .disabled(viewModel.isJoining || viewModel.isProbing)

                Button("Continue") {
                    Task { await viewModel.continueWithoutJoiningSoftAP() }
                }
                .disabled(viewModel.isJoining || viewModel.isProbing)
            } footer: {
                Text("Or connect in iOS Settings, then Continue.")
            }
        }
        .overlay {
            if viewModel.isProbing {
                ProgressView("Connecting to device…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("Back") {
                    viewModel.backFromSoftAPJoin()
                }
                .disabled(viewModel.isJoining || viewModel.isProbing)
            }
        }
    }

    private var softAPHomeWifiStep: some View {
        Form {
            if let wifi = viewModel.probedWifiStatus {
                Section("Device") {
                    if let apSSID = wifi.apSsid {
                        LabeledContent("Setup network", value: apSSID)
                    }
                    if let deviceId = wifi.deviceId {
                        LabeledContent("Device ID", value: deviceId)
                    }
                    if let mode = wifi.mode {
                        LabeledContent("Mode", value: mode)
                    }
                }
            }

            Section {
                TextField("Home Wi‑Fi name (SSID)", text: $viewModel.homeWifiSSID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Home Wi‑Fi password", text: $viewModel.homeWifiPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text("Credentials are sent to the device over the setup network only.")
            }

            Section {
                Button {
                    Task { await viewModel.provisionHomeWifi() }
                } label: {
                    if viewModel.isProvisioning {
                        HStack {
                            ProgressView()
                            Text("Provisioning…")
                        }
                    } else {
                        Text("Save & Connect Device")
                    }
                }
                .disabled(viewModel.isProvisioning)
            }
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("Back") {
                    viewModel.backFromSoftAPHomeWifi()
                }
                .disabled(viewModel.isProvisioning)
            }
        }
    }

    private var softAPReconnectStep: some View {
        List {
            Section {
                Label("Reconnect this iPhone to your home Wi‑Fi.", systemImage: "iphone.gen3")
                Label("The HID helper will join the same network.", systemImage: "wifi")
            } header: {
                Text("Almost Done")
            }

            Section {
                Button("Continue") {
                    viewModel.continueAfterHomeWifiReconnect()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("Back") {
                    viewModel.backFromSoftAPReconnect()
                }
            }
        }
    }

    private var softAPDiscoverStep: some View {
        VStack(spacing: 0) {
            discoveryList(
                candidates: viewModel.filteredCandidates,
                emptyTitle: "Looking for device…",
                emptyDescription: "Searching your home network for the provisioned HID helper."
            )

            Form {
                Section {
                    TextField("Host or IP", text: $viewModel.softAPManualHost, prompt: Text("hid-helper.local"))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button("Probe Address") {
                        Task { await viewModel.probeManualAddress() }
                    }
                    .disabled(viewModel.isProbing || viewModel.softAPManualHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    Text("Enter Address")
                } footer: {
                    Text("Use this if Bonjour discovery does not list your device yet.")
                }
            }
            .frame(maxHeight: 180)
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("Back") {
                    viewModel.backFromSoftAPDiscover()
                }
                .disabled(viewModel.isProbing)
            }
        }
    }

    @ViewBuilder
    private func discoveryList(
        candidates: [DiscoveredService],
        emptyTitle: String,
        emptyDescription: String
    ) -> some View {
        Group {
            if candidates.isEmpty {
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: "antenna.radiowaves.left.and.right")
                } description: {
                    Text(emptyDescription)
                }
            } else {
                List(candidates) { candidate in
                    Button {
                        Task { await viewModel.selectCandidate(candidate) }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(DeviceEndpointResolver.sanitizeHost(candidate.host))
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
            ConfirmDeviceForm(
                probed: probed,
                displayName: $viewModel.displayName,
                apiToken: $viewModel.apiToken,
                showsAuthTokenField: viewModel.showsAuthTokenField
            )
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
