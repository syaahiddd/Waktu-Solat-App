import Foundation

/// Shared storage (App Group) so the app, widgets and complications see the same data.
final class PrayerStore {
    static let shared = PrayerStore()

    private let defaults: UserDefaults
    private enum Key {
        static let schedule = "schedule"
        static let zoneCode = "zoneCode"
        static let autoLocate = "autoLocate"
    }

    init(defaults: UserDefaults? = UserDefaults(suiteName: AppConfig.appGroupID)) {
        self.defaults = defaults ?? .standard
    }

    var schedule: PrayerSchedule? {
        get {
            guard let data = defaults.data(forKey: Key.schedule) else { return nil }
            return try? JSONDecoder().decode(PrayerSchedule.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.schedule)
            } else {
                defaults.removeObject(forKey: Key.schedule)
            }
        }
    }

    var zoneCode: String? {
        get { defaults.string(forKey: Key.zoneCode) }
        set { defaults.set(newValue, forKey: Key.zoneCode) }
    }

    /// true = detect zone from GPS, false = user picked a zone manually.
    var autoLocate: Bool {
        get { defaults.object(forKey: Key.autoLocate) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.autoLocate) }
    }

    /// Returns the cached schedule if it covers today and tomorrow; otherwise downloads from JAKIM.
    /// Used by widgets/complications so they stay current even if the app isn't opened.
    func ensureFreshSchedule(now: Date = Date()) async -> PrayerSchedule? {
        let cached = schedule
        guard let zone = zoneCode ?? cached?.zoneCode else { return cached }
        if let cached, cached.zoneCode == zone, cached.covers(now) { return cached }
        if let fresh = try? await JakimAPI.fetchSchedule(zone: zone, from: now) {
            schedule = fresh
            return fresh
        }
        return cached
    }
}
