import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredDevice.displayName) private var storedDevices: [StoredDevice]
    @StateObject private var viewModel = HomeViewModel()

    @State private var showAddByAddress = false
    @State private var showAddWizard = false

    var body: some View {
        NavigationStack {
            Group {
                if storedDevices.isEmpty {
                    emptyState
                } else {
                    deviceList
                }
            }
            .navigationTitle("Mouse Mover")
            .toolbar { toolbarContent }
            .refreshable {
                await viewModel.refreshAll(devices: storedDevices, context: modelContext)
            }
            .alert("Error", isPresented: errorAlertBinding) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showAddByAddress) {
                AddByAddressSheet()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $showAddWizard) {
                AddDeviceWizardView()
            }
        }
        .environmentObject(viewModel)
    }

    private var deviceList: some View {
        List(storedDevices) { device in
            NavigationLink {
                DeviceDetailView(device: device)
            } label: {
                DeviceRowView(
                    device: device,
                    isOffline: viewModel.offlineDeviceIds.contains(device.deviceId),
                    jiggleBinding: jiggleBinding(for: device)
                )
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Devices Yet", systemImage: "computermouse")
        } description: {
            Text("Add a HID helper on your local network to get started.")
        }         actions: {
            Button("Add Device") {
                showAddWizard = true
            }
            .buttonStyle(.borderedProminent)

            Button("Add by Address") {
                showAddByAddress = true
            }
            .buttonStyle(.bordered)

            #if DEBUG
            Button("Add Sample Device") {
                try? viewModel.addSampleDevice(context: modelContext)
            }
            .buttonStyle(.bordered)
            #endif
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    showAddWizard = true
                } label: {
                    Label("Add Device", systemImage: "plus")
                }
                Button {
                    showAddByAddress = true
                } label: {
                    Label("Add by Address", systemImage: "network")
                }
            } label: {
                Image(systemName: "plus")
            }
        }
    }

    private func jiggleBinding(for device: StoredDevice) -> Binding<Bool> {
        Binding(
            get: { device.jiggleEnabled },
            set: { newValue in
                Task {
                    await viewModel.setJiggle(device: device, enabled: newValue, context: modelContext)
                }
            }
        )
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

private struct DeviceRowView: View {
    let device: StoredDevice
    let isOffline: Bool
    @Binding var jiggleBinding: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(device.displayName)
                        .font(.headline)
                    if isOffline {
                        Text("Offline")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("Jiggle", isOn: $jiggleBinding)
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        if !device.mdnsHost.isEmpty {
            return device.mdnsHost
        }
        return device.staIP ?? "Unknown host"
    }
}

#Preview {
    ContentView()
        .modelContainer(for: StoredDevice.self, inMemory: true)
}
