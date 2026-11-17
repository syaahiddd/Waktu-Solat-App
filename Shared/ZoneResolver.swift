import Foundation
import CoreLocation

struct ZoneResolution {
    let zone: JakimZone
    /// Human-readable place, e.g. "Seri Iskandar, Perak".
    let placeName: String?
}

/// Turns a GPS location into a JAKIM zone:
/// 1. Reverse-geocode with Apple Maps (state + district/town).
/// 2. Match the town/district names against the zone list (longest match wins).
/// 3. If nothing matches, pick the nearest zone in that state (or in Malaysia).
enum ZoneResolver {

    static func resolve(location: CLLocation) async -> ZoneResolution? {
        let placemark = try? await CLGeocoder()
            .reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "en_MY"))
            .first

        if let pm = placemark {
            if let iso = pm.isoCountryCode, iso.uppercased() != "MY" { return nil } // outside Malaysia
            let place = [pm.locality ?? pm.subAdministrativeArea, pm.administrativeArea]
                .compactMap { $0 }
                .joined(separator: ", ")
            if let zone = match(placemark: pm, location: location) {
                return ZoneResolution(zone: zone, placeName: place.isEmpty ? nil : place)
            }
        }

        // Geocoder unavailable (e.g. offline): nearest zone, if we're in Malaysia at all.
        guard isRoughlyInMalaysia(location), let zone = nearestZone(to: location) else { return nil }
        return ZoneResolution(zone: zone, placeName: nil)
    }

    static func match(placemark pm: CLPlacemark, location: CLLocation) -> JakimZone? {
        var candidates = Zones.all
        if let area = pm.administrativeArea, let state = Zones.state(matching: TextMatch.normalize(area)) {
            candidates = Zones.all.filter { $0.state == state }
        }
        if candidates.count == 1 { return candidates[0] }

        // Most specific field first, so "Genting Highlands" beats its district "Bentong".
        let fields = [pm.name, pm.subLocality, pm.locality, pm.subAdministrativeArea, pm.administrativeArea]
            .compactMap { $0 }
            .map(TextMatch.normalize)
            .filter { !$0.isEmpty }

        for field in fields {
            var best: (zone: JakimZone, length: Int)?
            for zone in candidates {
                for keyword in zone.keywords where TextMatch.containsWords(field, keyword) {
                    if keyword.count > (best?.length ?? 0) { best = (zone, keyword.count) }
                }
            }
            if let best { return best.zone }
        }

        if candidates.count < Zones.all.count {
            return nearestZone(to: location, among: candidates)
        }
        return nil
    }

    static func nearestZone(to location: CLLocation, among zones: [JakimZone] = Zones.all) -> JakimZone? {
        zones.filter { !$0.isSpecial }
            .min { $0.location.distance(from: location) < $1.location.distance(from: location) }
    }

    static func isRoughlyInMalaysia(_ location: CLLocation) -> Bool {
        let c = location.coordinate
        return (0.8...7.6).contains(c.latitude) && (99.5...119.5).contains(c.longitude)
    }
}
