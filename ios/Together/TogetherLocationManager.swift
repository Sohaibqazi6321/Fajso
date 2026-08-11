import Combine
import CoreLocation
import Foundation

@MainActor
final class TogetherLocationManager: NSObject, ObservableObject {
    @Published private(set) var latestLocation: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var statusText = "Location not started."

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 500
        manager.pausesLocationUpdatesAutomatically = true
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestBackgroundPermission() {
        manager.requestAlwaysAuthorization()
    }

    func requestOneUpdate() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            statusText = "Requesting current location..."
            manager.requestLocation()
        case .notDetermined:
            statusText = "Location permission needed."
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            statusText = "Location permission is blocked in Settings."
        @unknown default:
            statusText = "Location permission state is unknown."
        }
    }

    func startEfficientUpdates() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            statusText = "Listening for meaningful location changes."
            manager.startMonitoringSignificantLocationChanges()
        case .notDetermined:
            statusText = "Location permission needed."
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            statusText = "Location permission is blocked in Settings."
        @unknown default:
            statusText = "Location permission state is unknown."
        }
    }

    func stopUpdates() {
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        statusText = "Location updates stopped."
    }
}

extension TogetherLocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                statusText = "Location permission allowed."
            case .denied, .restricted:
                statusText = "Location permission is blocked in Settings."
            case .notDetermined:
                statusText = "Location permission not requested yet."
            @unknown default:
                statusText = "Location permission state is unknown."
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }

        Task { @MainActor in
            latestLocation = location
            statusText = "Location captured with \(Int(location.horizontalAccuracy))m accuracy."
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            statusText = "Location failed: \(error.localizedDescription)"
        }
    }
}
