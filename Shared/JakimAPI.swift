import Foundation

enum JakimAPIError: LocalizedError {
    case badResponse(Int)
    case noData

    var errorDescription: String? {
        switch self {
        case .badResponse(let code): return "JAKIM e-Solat returned an error (HTTP \(code))."
        case .noData: return "JAKIM e-Solat returned no prayer times for this zone."
        }
    }
}

/// Client for JAKIM's e-Solat API:
/// https://www.e-solat.gov.my/index.php?r=esolatApi/takwimsolat&period=<period>&zone=<ZONE>
enum JakimAPI {

    /// Fetches about a month of times starting yesterday, so widgets keep working across month boundaries.
    /// Falls back to `period=month` if the date-range request fails.
    static func fetchSchedule(zone: String, from start: Date = Date(), days: Int = 31) async throws -> PrayerSchedule {
        let cal = Calendar.malaysia
        let begin = cal.date(byAdding: .day, value: -1, to: start) ?? start
        let end = cal.date(byAdding: .day, value: days, to: start) ?? start

        if let ranged = try? await fetchDuration(zone: zone, start: begin, end: end), !ranged.isEmpty {
            return PrayerSchedule(zoneCode: zone, days: ranged, fetchedAt: Date())
        }
        let month = try await fetchPeriod(zone: zone, period: "month")
        guard !month.isEmpty else { throw JakimAPIError.noData }
        return PrayerSchedule(zoneCode: zone, days: month, fetchedAt: Date())
    }

    // MARK: - Requests

    private static func endpoint(zone: String, period: String) -> URL {
        var c = URLComponents(string: "https://www.e-solat.gov.my/index.php")!
        c.queryItems = [
            URLQueryItem(name: "r", value: "esolatApi/takwimsolat"),
            URLQueryItem(name: "period", value: period),
            URLQueryItem(name: "zone", value: zone)
        ]
        return c.url!
    }

    /// period=duration needs a POST with datestart/dateend (yyyy-MM-dd) in the form body.
    private static func fetchDuration(zone: String, start: Date, end: Date) async throws -> [DayPrayerTimes] {
        var request = URLRequest(url: endpoint(zone: zone, period: "duration"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "datestart=\(ymd(start))&dateend=\(ymd(end))".data(using: .utf8)
        return try await perform(request)
    }

    private static func fetchPeriod(zone: String, period: String) async throws -> [DayPrayerTimes] {
        try await perform(URLRequest(url: endpoint(zone: zone, period: period)))
    }

    private static func perform(_ request: URLRequest) async throws -> [DayPrayerTimes] {
        var request = request
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw JakimAPIError.badResponse(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let raw = decoded.prayerTime, !raw.isEmpty else { throw JakimAPIError.noData }
        return raw.compactMap(parse).sorted { $0.date < $1.date }
    }

    // MARK: - JSON

    private struct Response: Decodable {
        let prayerTime: [RawDay]?
        let status: String?
        let zone: String?
    }

    /// Example: {"hijri":"1441-03-14","date":"11-Nov-2019","day":"Monday","imsak":"05:26:00",
    ///           "fajr":"05:36:00","syuruk":"06:56:00","dhuhr":"12:57:00","asr":"16:18:00",
    ///           "maghrib":"18:55:00","isha":"20:07:00"}
    private struct RawDay: Decodable {
        let hijri: String?
        let date: String?
        let imsak: String?
        let fajr: String?
        let syuruk: String?
        let dhuhr: String?
        let asr: String?
        let maghrib: String?
        let isha: String?
    }

    private static func parse(_ raw: RawDay) -> DayPrayerTimes? {
        guard let dateString = raw.date, let day = parseDate(dateString),
              let fajr = time(raw.fajr, on: day),
              let syuruk = time(raw.syuruk, on: day),
              let dhuhr = time(raw.dhuhr, on: day),
              let asr = time(raw.asr, on: day),
              let maghrib = time(raw.maghrib, on: day),
              let isha = time(raw.isha, on: day)
        else { return nil }
        // Imsak is 10 minutes before Subuh if JAKIM leaves it out.
        let imsak = time(raw.imsak, on: day) ?? fajr.addingTimeInterval(-600)
        return DayPrayerTimes(date: day, hijri: raw.hijri ?? "", imsak: imsak, subuh: fajr, syuruk: syuruk,
                              zohor: dhuhr, asar: asr, maghrib: maghrib, isyak: isha)
    }

    private static let monthMap: [String: Int] = [
        "jan": 1, "feb": 2, "mar": 3, "mac": 3, "apr": 4, "may": 5, "mei": 5, "jun": 6, "jul": 7,
        "aug": 8, "ogo": 8, "ogs": 8, "sep": 9, "oct": 10, "okt": 10, "nov": 11, "dec": 12, "dis": 12
    ]

    /// Accepts "17-Nov-2026" (English or Malay month) or "2026-11-17".
    static func parseDate(_ s: String) -> Date? {
        let parts = s.split(separator: "-").map(String.init)
        guard parts.count == 3 else { return nil }
        var comps = DateComponents()
        if parts[0].count == 4 {
            comps.year = Int(parts[0]); comps.month = Int(parts[1]); comps.day = Int(parts[2])
        } else {
            comps.day = Int(parts[0]); comps.year = Int(parts[2])
            comps.month = Int(parts[1]) ?? monthMap[String(parts[1].lowercased().prefix(3))]
        }
        guard comps.year != nil, comps.month != nil, comps.day != nil else { return nil }
        return Calendar.malaysia.date(from: comps)
    }

    /// "05:36:00" on `day` (Malaysia time).
    private static func time(_ s: String?, on day: Date) -> Date? {
        guard let s else { return nil }
        let parts = s.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return Calendar.malaysia.date(bySettingHour: parts[0], minute: parts[1],
                                      second: parts.count > 2 ? parts[2] : 0, of: day)
    }

    private static func ymd(_ date: Date) -> String {
        let c = Calendar.malaysia.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
