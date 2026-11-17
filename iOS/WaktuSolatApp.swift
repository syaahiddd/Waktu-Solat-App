import SwiftUI
import UserNotifications

@main
struct WaktuSolatApp: App {
    @StateObject private var model = PrayerViewModel()

    init() {
        PhoneConnectivity.shared.activate()
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .tint(.teal)
        }
    }
}
