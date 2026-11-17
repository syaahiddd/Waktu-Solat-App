import CoreLocation

/// One-shot GPS location with async/await.
final class LocationProvider: NSObject, CLLocationManagerDelegate {

    enum LocationError: LocalizedError {
        case denied
        case unavailable

        var errorDescription: String? {
            switch self {
            case .denied: return "Location access is off. Enable it in Settings > Waktu Solat, or choose a zone manually."
            case .unavailable: return "Couldn't get your location. Try again or choose a zone manually."
            }
        }
    }

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authContinuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer // zone-level accuracy is enough
    }

    @MainActor
    func currentLocation() async throws -> CLLocation {
        if manager.authorizationStatus == .notDetermined {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                authContinuation = c
                manager.requestWhenInUseAuthorization()
            }
        }
        switch manager.authorizationStatus {
        case .denied, .restricted:
            throw LocationError.denied
        default:
            break
        }
        return try await withCheckedThrowingContinuation { c in
            locationContinuation?.resume(throwing: LocationError.unavailable) // cancel any earlier request
            locationContinuation = c
            manager.requestLocation()
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus != .notDetermined else { return }
        authContinuation?.resume()
        authContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: LocationError.unavailable)
        locationContinuation = nil
    }
}
