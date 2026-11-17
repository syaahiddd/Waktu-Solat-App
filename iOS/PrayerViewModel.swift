import Foundation
import WidgetKit

@MainActor
final class PrayerViewModel: ObservableObject {
    @Published private(set) var schedule: PrayerSchedule?
    @Published private(set) var zone: JakimZone?
    @Published private(set) var placeName: String?
    @Published private(set) var autoLocate: Bool
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let store = PrayerStore.shared
    private let locationProvider = LocationProvider()

    init() {
        let store = PrayerStore.shared
        _schedule = Published(initialValue: store.schedule)
        _autoLocate = Published(initialValue: store.autoLocate)
        _zone = Published(initialValue: store.zoneCode.flatMap(Zones.zone(for:)))
    }

    /// Detects the zone (if GPS mode is on) and downloads times from JAKIM when needed.
    func refresh(force: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if autoLocate {
            do {
                let location = try await locationProvider.currentLocation()
                if let result = await ZoneResolver.resolve(location: location) {
                    zone = result.zone
                    placeName = result.placeName
                    store.zoneCode = result.zone.code
                } else {
                    errorMessage = "You seem to be outside Malaysia. Pick a JAKIM zone manually."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        guard let zone else {
            if errorMessage == nil { errorMessage = "Choose a zone to see prayer times." }
            return
        }

        if !force, let cached = schedule, cached.zoneCode == zone.code, cached.covers(Date()) {
            publish(cached)
            return
        }

        do {
            let fresh = try await JakimAPI.fetchSchedule(zone: zone.code)
            store.schedule = fresh
            publish(fresh)
        } catch {
            errorMessage = "Couldn't reach JAKIM e-Solat. \(error.localizedDescription)"
        }
    }

    func selectZone(_ newZone: JakimZone) {
        autoLocate = false
        store.autoLocate = false
        zone = newZone
        placeName = nil
        store.zoneCode = newZone.code
        Task { await refresh() }
    }

    func useGPS() {
        autoLocate = true
        store.autoLocate = true
        Task { await refresh() }
    }

    private func publish(_ s: PrayerSchedule) {
        schedule = s
        PhoneConnectivity.shared.send(schedule: s)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
