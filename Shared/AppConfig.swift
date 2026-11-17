import Foundation

enum AppConfig {
    /// Must match the App Group in project.yml (all four targets use the same one).
    static let appGroupID = "group.com.syaahid.waktusolat"

    /// JAKIM publishes times in Malaysia local time.
    static let malaysiaTimeZone = TimeZone(identifier: "Asia/Kuala_Lumpur")!
}

extension Calendar {
    /// Gregorian calendar fixed to Malaysia time, used for all day/prayer calculations.
    static let malaysia: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = AppConfig.malaysiaTimeZone
        cal.locale = Locale(identifier: "en_MY")
        return cal
    }()
}
