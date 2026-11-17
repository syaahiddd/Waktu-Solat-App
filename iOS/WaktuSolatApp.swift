import SwiftUI

@main
struct WaktuSolatApp: App {
    @StateObject private var model = PrayerViewModel()

    init() {
        PhoneConnectivity.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .tint(.teal)
        }
    }
}
