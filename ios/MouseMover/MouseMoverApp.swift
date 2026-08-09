import SwiftUI
import SwiftData

@main
struct MouseMoverApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: StoredDevice.self)
    }
}
