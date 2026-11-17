import Foundation

// MARK: - Prayer

enum Prayer: String, CaseIterable, Codable, Identifiable {
    case imsak, subuh, syuruk, zohor, asar, maghrib, isyak

    var id: String { rawValue }

    /// The five obligatory prayers (used for "next prayer").
    static let fard: [Prayer] = [.subuh, .zohor, .asar, .maghrib, .isyak]

    var name: String {
        switch self {
        case .imsak: return "Imsak"
        case .subuh: return "Subuh"
        case .syuruk: return "Syuruk"
        case .zohor: return "Zohor"
        case .asar: return "Asar"
        case .maghrib: return "Maghrib"
        case .isyak: return "Isyak"
        }
    }

    /// Short label for tiny complications.
    var shortName: String {
        switch self {
        case .maghrib: return "Mghrb"
        case .syuruk: return "Syrk"
        default: return name
        }
    }

    var symbol: String {
        switch self {
        case .imsak: return "moon.stars"
        case .subuh: return "sun.haze"
        case .syuruk: return "sunrise"
        case .zohor: return "sun.max"
        case .asar: return "sun.min"
        case .maghrib: return "sunset"
        case .isyak: return "moon"
        }
    }

    var isFard: Bool { Prayer.fard.contains(self) }
}

// MARK: - One day of times

struct DayPrayerTimes: Codable, Hashable, Identifiable {
    /// Start of the day (Malaysia time).
    let date: Date
    /// Hijri date as given by JAKIM, e.g. "1448-05-26".
    let hijri: String
    let imsak: Date
    let subuh: Date
    let syuruk: Date
    let zohor: Date
    let asar: Date
    let maghrib: Date
    let isyak: Date

    var id: Date { date }

    func time(_ prayer: Prayer) -> Date {
        switch prayer {
        case .imsak: return imsak
        case .subuh: return subuh
        case .syuruk: return syuruk
        case .zohor: return zohor
        case .asar: return asar
        case .maghrib: return maghrib
        case .isyak: return isyak
        }
    }

    var hijriDisplay: String { HijriFormatter.display(hijri) }
}

struct PrayerMoment: Hashable {
    let prayer: Prayer
    let time: Date
}

// MARK: - Cached schedule

struct PrayerSchedule: Codable, Equatable {
    var zoneCode: String
    var days: [DayPrayerTimes]   // sorted by date
    var fetchedAt: Date

    func day(for date: Date) -> DayPrayerTimes? {
        days.first { Calendar.malaysia.isDate($0.date, inSameDayAs: date) }
    }

    private var fardMoments: [PrayerMoment] {
        days.flatMap { day in Prayer.fard.map { PrayerMoment(prayer: $0, time: day.time($0)) } }
    }

    /// Next obligatory prayer strictly after `date`.
    func next(after date: Date) -> PrayerMoment? {
        fardMoments.first { $0.time > date }
    }

    /// Most recent obligatory prayer at or before `date` (start of the countdown ring).
    func previous(atOrBefore date: Date) -> PrayerMoment? {
        fardMoments.last { $0.time <= date }
    }

    /// The obligatory prayer whose time is currently running (nil between Syuruk and Zohor).
    func current(at date: Date) -> PrayerMoment? {
        guard let last = fardMoments.last(where: { $0.time <= date }) else { return nil }
        if last.prayer == .subuh, let day = day(for: last.time), day.syuruk <= date {
            return nil
        }
        return last
    }

    /// True if the cache has data for `date` and the following day.
    func covers(_ date: Date) -> Bool {
        guard let tomorrow = Calendar.malaysia.date(byAdding: .day, value: 1, to: date) else { return false }
        return day(for: date) != nil && day(for: tomorrow) != nil
    }
}

// MARK: - Hijri display

enum HijriFormatter {
    private static let months = [
        "Muharram", "Safar", "Rabiulawal", "Rabiulakhir", "Jamadilawal", "Jamadilakhir",
        "Rejab", "Syaaban", "Ramadan", "Syawal", "Zulkaedah", "Zulhijjah"
    ]

    /// "1448-05-26" -> "26 Jamadilawal 1448"
    static func display(_ raw: String) -> String {
        let parts = raw.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]) else { return raw }
        return "\(parts[2]) \(months[parts[1] - 1]) \(parts[0])"
    }
}
