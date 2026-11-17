import Foundation
import WatchConnectivity

/// Sends the prayer schedule from iPhone to Apple Watch.
final class PhoneConnectivity: NSObject, WCSessionDelegate {
    static let shared = PhoneConnectivity()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(schedule: PrayerSchedule) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled,
              let data = try? JSONEncoder().encode(schedule) else { return }

        // Latest state; delivered even if the watch app isn't running.
        try? session.updateApplicationContext(["schedule": data, "sentAt": Date().timeIntervalSince1970])

        // Higher-priority delivery when a complication is on the watch face.
        if session.isComplicationEnabled {
            session.transferCurrentComplicationUserInfo(["schedule": data])
        }
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated, let schedule = PrayerStore.shared.schedule {
            send(schedule: schedule)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate() // e.g. after switching to another watch
    }

    /// The watch can ask for the latest schedule when it opens.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        if let schedule = PrayerStore.shared.schedule, let data = try? JSONEncoder().encode(schedule) {
            replyHandler(["schedule": data])
        } else {
            replyHandler([:])
        }
    }
}
