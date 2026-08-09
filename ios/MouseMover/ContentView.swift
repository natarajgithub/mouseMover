import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No Devices Yet",
                systemImage: "computermouse",
                description: Text("Discover hid-helper devices on your local network to get started.")
            )
            .navigationTitle("Mouse Mover")
        }
        .environmentObject(viewModel)
    }
}

#Preview {
    ContentView()
}
