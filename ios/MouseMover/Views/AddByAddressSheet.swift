import SwiftUI

struct AddByAddressSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var viewModel: HomeViewModel

    @State private var host = ""
    @State private var token = ""
    @State private var isAdding = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
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
                    Text("Probes /api/status on the host and saves the device if found.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Add by Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await addDevice() }
                    }
                    .disabled(host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAdding)
                }
            }
            .interactiveDismissDisabled(isAdding)
        }
    }

    private func addDevice() async {
        isAdding = true
        errorMessage = nil
        defer { isAdding = false }

        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await viewModel.addByAddress(
                host: trimmedHost,
                token: trimmedToken.isEmpty ? nil : trimmedToken,
                context: modelContext
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AddDevicePlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Add Device Wizard",
            systemImage: "plus.circle",
            description: Text("Guided setup for new HID helpers is coming soon.")
        )
        .navigationTitle("Add Device")
        .navigationBarTitleDisplayMode(.inline)
    }
}
