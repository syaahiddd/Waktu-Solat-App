import Foundation
import WatchConnectivity
import WidgetKit

/// Receives the schedule from the iPhone, and can also download directly from JAKIM.
final class WatchModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published var schedule: PrayerSchedule?
    @Published var isRefreshing = false

    private let store = PrayerStore.shared

    override init() {
        _schedule = Published(initialValue: PrayerStore.shared.schedule)
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    @MainActor
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        // Ask the iPhone for its latest data (works when the phone is nearby).
        let session = WCSession.default
        if session.activationState == .activated, session.isReachable {
            session.sendMessage(["request": "schedule"], replyHandler: { [weak self] reply in
                if let data = reply["schedule"] as? Data { self?.apply(data) }
            }, errorHandler: nil)
        }

        // Otherwise top up straight from JAKIM using the zone the phone last sent.
        if let fresh = await store.ensureFreshSchedule(), fresh != schedule {
            schedule = fresh
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func apply(_ data: Data) {
        guard let received = try? JSONDecoder().decode(PrayerSchedule.self, from: data) else { return }
        store.schedule = received
        store.zoneCode = received.zoneCode
        WidgetCenter.shared.reloadAllTimelines()
        DispatchQueue.main.async { self.schedule = received }
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let data = session.receivedApplicationContext["schedule"] as? Data { apply(data) }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let data = applicationContext["schedule"] as? Data { apply(data) }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        if let data = userInfo["schedule"] as? Data { apply(data) }
    }
}
