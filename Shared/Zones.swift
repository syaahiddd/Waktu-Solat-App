import Foundation
import CoreLocation

/// A JAKIM prayer time zone.
struct JakimZone: Identifiable, Hashable {
    let code: String
    let state: String
    /// Areas as listed by JAKIM (for display).
    let areas: String
    /// Normalised district/town names used to match a reverse-geocoded address.
    let keywords: [String]
    /// Rough reference point, only used as a fallback when address matching fails.
    let latitude: Double
    let longitude: Double
    /// Special zones (mountain peaks, small islands, enclaves) are only chosen by name, never by distance.
    let isSpecial: Bool

    var id: String { code }
    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }

    init(_ code: String, _ state: String, _ areas: String, _ lat: Double, _ lon: Double,
         extra: [String] = [], special: Bool = false) {
        self.code = code
        self.state = state
        self.areas = areas
        self.latitude = lat
        self.longitude = lon
        self.isSpecial = special
        let names = areas.split(separator: ",").map(String.init) + extra
        self.keywords = names.map(TextMatch.normalize).filter { !$0.isEmpty }
    }

    static func == (a: JakimZone, b: JakimZone) -> Bool { a.code == b.code }
    func hash(into h: inout Hasher) { h.combine(code) }
}

enum Zones {
    static func zone(for code: String) -> JakimZone? { all.first { $0.code == code } }

    static var states: [String] {
        var seen = Set<String>()
        return all.map(\.state).filter { seen.insert($0).inserted }
    }

    /// Maps the geocoder's administrativeArea to a JAKIM state name.
    static let stateAliases: [(state: String, aliases: [String])] = [
        ("Wilayah Persekutuan", ["kuala lumpur", "putrajaya", "labuan", "wilayah persekutuan", "federal territory"]),
        ("Johor", ["johor"]),
        ("Kedah", ["kedah"]),
        ("Kelantan", ["kelantan"]),
        ("Melaka", ["melaka", "malacca"]),
        ("Negeri Sembilan", ["negeri sembilan"]),
        ("Pahang", ["pahang"]),
        ("Perak", ["perak"]),
        ("Perlis", ["perlis"]),
        ("Pulau Pinang", ["pulau pinang", "penang", "pinang"]),
        ("Sabah", ["sabah"]),
        ("Sarawak", ["sarawak"]),
        ("Selangor", ["selangor"]),
        ("Terengganu", ["terengganu", "trengganu"])
    ]

    static func state(matching normalizedArea: String) -> String? {
        stateAliases.first { entry in
            entry.aliases.contains { TextMatch.containsWords(normalizedArea, TextMatch.normalize($0)) }
        }?.state
    }

    // Zone list from JAKIM e-Solat. `extra` adds common town/district names the geocoder may return.
    static let all: [JakimZone] = [
        // Johor
        JakimZone("JHR01", "Johor", "Pulau Aur dan Pulau Pemanggil", 2.45, 104.52, extra: ["Pulau Aur", "Pulau Pemanggil"], special: true),
        JakimZone("JHR02", "Johor", "Johor Bahru, Kota Tinggi, Mersing, Kulai", 1.4927, 103.7414,
                  extra: ["Johor Baharu", "Iskandar Puteri", "Pasir Gudang", "Skudai", "Senai", "Kulai Jaya"]),
        JakimZone("JHR03", "Johor", "Kluang, Pontian", 2.0251, 103.3328, extra: ["Simpang Renggam", "Kukup"]),
        JakimZone("JHR04", "Johor", "Batu Pahat, Muar, Segamat, Gemas Johor, Tangkak", 1.9500, 102.8000,
                  extra: ["Ledang", "Labis", "Yong Peng", "Gemas"]),

        // Kedah
        JakimZone("KDH01", "Kedah", "Kota Setar, Kubang Pasu, Pokok Sena (Daerah Kecil)", 6.1248, 100.3678,
                  extra: ["Alor Setar", "Alor Star", "Jitra", "Changlun", "Pokok Sena"]),
        JakimZone("KDH02", "Kedah", "Kuala Muda, Yan, Pendang", 5.6470, 100.4877, extra: ["Sungai Petani", "Sungai Patani", "Gurun"]),
        JakimZone("KDH03", "Kedah", "Padang Terap, Sik", 6.2500, 100.6100, extra: ["Kuala Nerang"]),
        JakimZone("KDH04", "Kedah", "Baling", 5.6766, 100.9167),
        JakimZone("KDH05", "Kedah", "Bandar Baharu, Kulim", 5.3650, 100.5616),
        JakimZone("KDH06", "Kedah", "Langkawi", 6.3500, 99.8000, extra: ["Kuah"]),
        JakimZone("KDH07", "Kedah", "Puncak Gunung Jerai", 5.7900, 100.4300, extra: ["Gunung Jerai"], special: true),

        // Kelantan
        JakimZone("KTN01", "Kelantan", "Bachok, Kota Bharu, Machang, Pasir Mas, Pasir Puteh, Tanah Merah, Tumpat, Kuala Krai, Mukim Chiku",
                  6.1254, 102.2381, extra: ["Kota Baharu", "Chiku"]),
        JakimZone("KTN02", "Kelantan", "Gua Musang (Daerah Galas Dan Bertam), Jeli, Jajahan Kecil Lojing", 4.8823, 101.9644,
                  extra: ["Gua Musang", "Lojing", "Galas", "Bertam"]),

        // Melaka
        JakimZone("MLK01", "Melaka", "Seluruh Negeri Melaka", 2.1896, 102.2501, extra: ["Melaka", "Malacca", "Alor Gajah", "Jasin"]),

        // Negeri Sembilan
        JakimZone("NGS01", "Negeri Sembilan", "Tampin, Jempol", 2.4701, 102.2302, extra: ["Bahau", "Gemas"]),
        JakimZone("NGS02", "Negeri Sembilan", "Jelebu, Kuala Pilah, Rembau", 2.7389, 102.2487, extra: ["Kuala Klawang"]),
        JakimZone("NGS03", "Negeri Sembilan", "Port Dickson, Seremban", 2.7297, 101.9381, extra: ["Nilai", "Senawang"]),

        // Pahang
        JakimZone("PHG01", "Pahang", "Pulau Tioman", 2.7900, 104.1700, extra: ["Tioman"], special: true),
        JakimZone("PHG02", "Pahang", "Kuantan, Pekan, Rompin, Muadzam Shah", 3.8077, 103.3260, extra: ["Gambang"]),
        JakimZone("PHG03", "Pahang", "Jerantut, Temerloh, Maran, Bera, Chenor, Jengka", 3.4500, 102.4176, extra: ["Mentakab", "Triang"]),
        JakimZone("PHG04", "Pahang", "Bentong, Lipis, Raub", 3.7921, 101.8574, extra: ["Kuala Lipis"]),
        JakimZone("PHG05", "Pahang", "Genting Sempah, Janda Baik, Bukit Tinggi", 3.3500, 101.8200, special: true),
        JakimZone("PHG06", "Pahang", "Cameron Highlands, Genting Higlands, Bukit Fraser", 4.4718, 101.3767,
                  extra: ["Genting Highlands", "Fraser's Hill", "Fraser Hill", "Tanah Rata", "Brinchang", "Ringlet"]),

        // Perlis & Pulau Pinang
        JakimZone("PLS01", "Perlis", "Seluruh Negeri Perlis", 6.4414, 100.1986, extra: ["Perlis", "Kangar", "Arau", "Padang Besar"]),
        JakimZone("PNG01", "Pulau Pinang", "Seluruh Negeri Pulau Pinang", 5.4141, 100.3288,
                  extra: ["Penang", "George Town", "Butterworth", "Bukit Mertajam", "Bayan Lepas", "Seberang Perai"]),

        // Perak
        JakimZone("PRK01", "Perak", "Tapah, Slim River, Tanjung Malim", 4.1980, 101.2610,
                  extra: ["Batang Padang", "Muallim", "Bidor", "Sungkai"]),
        JakimZone("PRK02", "Perak", "Kuala Kangsar, Sg. Siput, Ipoh, Batu Gajah, Kampar", 4.5975, 101.0901,
                  extra: ["Sungai Siput", "Kinta", "Gopeng", "Chemor"]),
        JakimZone("PRK03", "Perak", "Lenggong, Pengkalan Hulu, Grik", 5.4290, 101.1290, extra: ["Gerik", "Hulu Perak"]),
        JakimZone("PRK04", "Perak", "Temengor, Belum", 5.5500, 101.3500, special: true),
        JakimZone("PRK05", "Perak", "Kg Gajah, Teluk Intan, Bagan Datuk, Seri Iskandar, Beruas, Parit, Lumut, Sitiawan, Pulau Pangkor",
                  4.3600, 100.9800,
                  extra: ["Kampung Gajah", "Bandar Seri Iskandar", "Bagan Datoh", "Pangkor", "Manjung", "Perak Tengah", "Hilir Perak"]),
        JakimZone("PRK06", "Perak", "Selama, Taiping, Bagan Serai, Parit Buntar", 4.8500, 100.7333,
                  extra: ["Kerian", "Larut", "Matang", "Kamunting"]),
        JakimZone("PRK07", "Perak", "Bukit Larut", 4.8600, 100.7900, extra: ["Maxwell Hill"], special: true),

        // Sabah
        JakimZone("SBH01", "Sabah", "Bahagian Sandakan (Timur), Bukit Garam, Semawang, Temanggong, Tambisan, Bandar Sandakan, Sukau",
                  5.8402, 118.1179, extra: ["Sandakan"]),
        JakimZone("SBH02", "Sabah", "Beluran, Telupid, Pinangah, Terusan, Kuamut, Bahagian Sandakan (Barat)", 5.8900, 117.5500,
                  extra: ["Tongod"]),
        JakimZone("SBH03", "Sabah", "Lahad Datu, Silabukan, Kunak, Sahabat, Semporna, Tungku, Bahagian Tawau (Timur)", 5.0268, 118.3270),
        JakimZone("SBH04", "Sabah", "Bandar Tawau, Balong, Merotai, Kalabakan, Bahagian Tawau (Barat)", 4.2448, 117.8912, extra: ["Tawau"]),
        JakimZone("SBH05", "Sabah", "Kudat, Kota Marudu, Pitas, Pulau Banggi, Bahagian Kudat", 6.8837, 116.8477, extra: ["Banggi"]),
        JakimZone("SBH06", "Sabah", "Gunung Kinabalu", 6.0750, 116.5580, extra: ["Mount Kinabalu"], special: true),
        JakimZone("SBH07", "Sabah", "Kota Kinabalu, Ranau, Kota Belud, Tuaran, Penampang, Papar, Putatan, Bahagian Pantai Barat",
                  5.9804, 116.0735, extra: ["Kundasang"]),
        JakimZone("SBH08", "Sabah", "Pensiangan, Keningau, Tambunan, Nabawan, Bahagian Pendalaman (Atas)", 5.3378, 116.1602),
        JakimZone("SBH09", "Sabah", "Beaufort, Kuala Penyu, Sipitang, Tenom, Long Pasia, Membakut, Weston, Bahagian Pendalaman (Bawah)",
                  5.3473, 115.7455, extra: ["Long Pa Sia"]),

        // Sarawak
        JakimZone("SWK01", "Sarawak", "Limbang, Lawas, Sundar, Trusan", 4.7500, 115.0000),
        JakimZone("SWK02", "Sarawak", "Miri, Niah, Bekenu, Sibuti, Marudi", 4.3995, 113.9914),
        JakimZone("SWK03", "Sarawak", "Pandan, Belaga, Suai, Tatau, Sebauh, Bintulu", 3.1700, 113.0300),
        JakimZone("SWK04", "Sarawak", "Sibu, Mukah, Dalat, Song, Igan, Oya, Balingian, Kanowit, Kapit", 2.2870, 111.8305,
                  extra: ["Selangau"]),
        JakimZone("SWK05", "Sarawak", "Sarikei, Matu, Julau, Rajang, Daro, Bintangor, Belawai", 2.1271, 111.5182, extra: ["Meradong"]),
        JakimZone("SWK06", "Sarawak", "Lubok Antu, Sri Aman, Roban, Debak, Kabong, Lingga, Engkelili, Betong, Spaoh, Pusa, Saratok",
                  1.2370, 111.4621, extra: ["Simanggang", "Engkilili"]),
        JakimZone("SWK07", "Sarawak", "Serian, Simunjan, Samarahan, Sebuyau, Meludam", 1.4598, 110.4883,
                  extra: ["Kota Samarahan", "Asajaya"]),
        JakimZone("SWK08", "Sarawak", "Kuching, Bau, Lundu, Sematan", 1.5533, 110.3592, extra: ["Padawan", "Petra Jaya"]),
        JakimZone("SWK09", "Sarawak", "Zon Khas (Kampung Patarikan)", 4.9600, 115.4000, extra: ["Patarikan"], special: true),

        // Selangor
        JakimZone("SGR01", "Selangor", "Gombak, Petaling, Sepang, Hulu Langat, Hulu Selangor, Shah Alam", 3.0738, 101.5183,
                  extra: ["Ulu Langat", "Petaling Jaya", "Subang Jaya", "Puchong", "Kajang", "Bangi", "Ampang", "Selayang",
                          "Rawang", "Cyberjaya", "Kuala Kubu Bharu", "Batu Caves", "Sungai Buloh", "Cheras", "Semenyih",
                          "Seri Kembangan", "Serdang", "Damansara", "Dengkil", "Salak Tinggi"]),
        JakimZone("SGR02", "Selangor", "Kuala Selangor, Sabak Bernam", 3.3400, 101.2500,
                  extra: ["Tanjung Karang", "Sekinchan", "Bestari Jaya", "Puncak Alam"]),
        JakimZone("SGR03", "Selangor", "Klang, Kuala Langat", 3.0449, 101.4456,
                  extra: ["Banting", "Port Klang", "Pelabuhan Klang", "Jenjarom", "Morib", "Pulau Indah", "Kapar", "Meru"]),

        // Terengganu
        JakimZone("TRG01", "Terengganu", "Kuala Terengganu, Marang, Kuala Nerus", 5.3302, 103.1408),
        JakimZone("TRG02", "Terengganu", "Besut, Setiu", 5.7400, 102.4900, extra: ["Jerteh", "Kuala Besut"]),
        JakimZone("TRG03", "Terengganu", "Hulu Terengganu", 5.0700, 103.0100, extra: ["Kuala Berang"]),
        JakimZone("TRG04", "Terengganu", "Dungun, Kemaman", 4.5000, 103.4200, extra: ["Chukai", "Kerteh", "Kijal", "Paka"]),

        // Wilayah Persekutuan
        JakimZone("WLY01", "Wilayah Persekutuan", "Kuala Lumpur, Putrajaya", 3.1390, 101.6869),
        JakimZone("WLY02", "Wilayah Persekutuan", "Labuan", 5.2831, 115.2308)
    ]
}

/// Lower-case, accent-free, punctuation-free text with whole-word matching.
enum TextMatch {
    static func normalize(_ s: String) -> String {
        let folded = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        let cleaned = String(folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " })
        return cleaned.split(separator: " ").joined(separator: " ")
    }

    static func containsWords(_ text: String, _ phrase: String) -> Bool {
        guard !phrase.isEmpty else { return false }
        return (" " + text + " ").contains(" " + phrase + " ")
    }
}
