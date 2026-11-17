import WidgetKit
import Foundation

struct PrayerEntry: TimelineEntry {
    let date: Date
    let zoneCode: String?
    let day: DayPrayerTimes?
    let next: PrayerMoment?
    let current: PrayerMoment?

    static func make(at date: Date, schedule: PrayerSchedule?) -> PrayerEntry {
        PrayerEntry(date: date,
                    zoneCode: schedule?.zoneCode,
                    day: schedule?.day(for: date),
                    next: schedule?.next(after: date),
                    current: schedule?.current(at: date))
    }

    /// Fake data for the widget gallery / placeholders.
    static var sample: PrayerEntry {
        let cal = Calendar.malaysia
        let today = cal.startOfDay(for: Date())
        func t(_ h: Int, _ m: Int) -> Date { cal.date(bySettingHour: h, minute: m, second: 0, of: today) ?? today }
        let day = DayPrayerTimes(date: today, hijri: "1448-05-26",
                                 imsak: t(5, 40), subuh: t(5, 50), syuruk: t(7, 2), zohor: t(13, 5),
                                 asar: t(16, 27), maghrib: t(19, 4), isyak: t(20, 17))
        let schedule = PrayerSchedule(zoneCode: "PRK05", days: [day], fetchedAt: Date())
        let now = Date()
        return PrayerEntry(date: now, zoneCode: "PRK05", day: day,
                           next: schedule.next(after: now) ?? PrayerMoment(prayer: .subuh, time: now.addingTimeInterval(3600)),
                           current: schedule.current(at: now))
    }
}

struct PrayerTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> PrayerEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        if context.isPreview {
            completion(.sample)
            return
        }
        let entry = PrayerEntry.make(at: Date(), schedule: PrayerStore.shared.schedule)
        completion(entry.next == nil ? .sample : entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        Task {
            let now = Date()
            // Downloads from JAKIM by itself if the cache is running out.
            let schedule = await PrayerStore.shared.ensureFreshSchedule(now: now)
            completion(Self.timeline(from: schedule, now: now))
        }
    }

    /// One entry now, then one at every prayer time and midnight for the next 48 hours,
    /// so "next prayer" flips over exactly on time without the app running.
    static func timeline(from schedule: PrayerSchedule?, now: Date) -> Timeline<PrayerEntry> {
        guard let schedule, schedule.next(after: now) != nil else {
            let empty = PrayerEntry.make(at: now, schedule: schedule)
            return Timeline(entries: [empty], policy: .after(now.addingTimeInterval(30 * 60)))
        }

        let horizon = now.addingTimeInterval(48 * 3600)
        var changePoints: Set<Date> = [now]
        for day in schedule.days {
            for prayer in Prayer.allCases {
                let t = day.time(prayer)
                if t > now && t <= horizon { changePoints.insert(t) }
            }
            if let midnight = Calendar.malaysia.date(byAdding: .day, value: 1, to: day.date),
               midnight > now && midnight <= horizon {
                changePoints.insert(midnight)
            }
        }

        let entries = changePoints.sorted().map { PrayerEntry.make(at: $0, schedule: schedule) }
        return Timeline(entries: entries, policy: .atEnd)
    }
}
