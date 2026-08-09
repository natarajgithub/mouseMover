import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var devices: [Device] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let apiClient: any DeviceAPIClientProtocol
    private let bonjourBrowser: any BonjourBrowserProtocol

    init(
        apiClient: any DeviceAPIClientProtocol = DeviceAPIClient(),
        bonjourBrowser: any BonjourBrowserProtocol = BonjourBrowser()
    ) {
        self.apiClient = apiClient
        self.bonjourBrowser = bonjourBrowser
    }

    func refresh(from baseURL: URL, token: String? = nil) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let status = try await apiClient.status(baseURL: baseURL, token: token)
            let host = baseURL.host ?? baseURL.absoluteString
            let device = Device(status: status, fallbackHost: host)
            if let index = devices.firstIndex(where: { $0.id == device.id }) {
                devices[index] = device
            } else {
                devices.append(device)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
