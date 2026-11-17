import SwiftUI

@main
struct WaktuSolatWatchApp: App {
    @StateObject private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(model)
                .tint(.teal)
        }
    }
}
