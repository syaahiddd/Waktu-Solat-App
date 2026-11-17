import Foundation
import UserNotifications

/// Schedules local notifications at each prayer time (and optionally a reminder before it).
/// Notifications fire even when the app is closed, and are mirrored to a paired Apple Watch.
enum PrayerNotifications {
    private static let center = UNUserNotificationCenter.current()
    private static let idPrefix = "prayer."
    /// iOS keeps at most 64 pending notifications per app; stay under that.
    private static let maxPending = 60

    static func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func isAuthorized() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    /// Replaces every pending prayer notification using the cached schedule.
    static func reschedule(schedule: PrayerSchedule?, enabled: Bool, reminderMinutes: Int, now: Date = Date()) async {
        let old = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: old)

        guard enabled, let schedule, await isAuthorized() else { return }

        var requests: [UNNotificationRequest] = []
        for day in schedule.days {
            for prayer in Prayer.fard {
                let time = day.time(prayer)

                if reminderMinutes > 0 {
                    let early = time.addingTimeInterval(TimeInterval(-reminderMinutes * 60))
                    if early > now {
                        requests.append(request(
                            id: "\(idPrefix)\(prayer.rawValue).\(Int(time.timeIntervalSince1970)).early",
                            title: "\(prayer.name) in \(reminderMinutes) min",
                            body: "\(prayer.name) is at \(timeText(time)) · \(schedule.zoneCode)",
                            at: early))
                    }
                }

                if time > now {
                    requests.append(request(
                        id: "\(idPrefix)\(prayer.rawValue).\(Int(time.timeIntervalSince1970))",
                        title: "Waktu \(prayer.name)",
                        body: "It's now time for \(prayer.name) · \(schedule.zoneCode)",
                        at: time))
                }
            }
        }

        for r in requests.prefix(maxPending) {
            try? await center.add(r)
        }
    }

    private static func request(id: String, title: String, body: String, at date: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "prayer-times"
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    private static func timeText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

/// Shows prayer notifications as banners even while the app is open.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
