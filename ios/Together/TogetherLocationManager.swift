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

    func stopUpdates() {
        manager.stopUpdatingLocation()
        statusText = "Location updates stopped."
    }
}

extension TogetherLocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            switch manager.authorizationStatus {
            case .authorizedAlways:
                statusText = "Location permission allowed."
                manager.requestLocation()
            case .authorizedWhenInUse:
                statusText = "Location allowed while Together is open."
                manager.requestLocation()
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
        let now = Date()
        guard let location = locations
            .filter({ location in
                CLLocationCoordinate2DIsValid(location.coordinate)
                    && location.horizontalAccuracy >= 0
                    && location.horizontalAccuracy <= 20_000
                    && location.timestamp <= now.addingTimeInterval(60)
                    && location.timestamp >= now.addingTimeInterval(-5 * 60)
            })
            .max(by: { $0.timestamp < $1.timestamp })
        else {
            Task { @MainActor in
                statusText = "Location reading was too old or inaccurate."
            }
            return
        }

        Task { @MainActor in
            latestLocation = location
            statusText = "Location captured with \(Int(location.horizontalAccuracy))m accuracy."
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let locationError = error as? CLError, locationError.code == .denied {
                statusText = "Location permission is blocked in Settings."
            } else {
                statusText = "We couldn't update your location right now."
            }
        }
    }
}
