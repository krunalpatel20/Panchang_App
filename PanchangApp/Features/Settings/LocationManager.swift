import Foundation
import CoreLocation
import Observation

@Observable
@MainActor
final class LocationManager: NSObject {
    enum Status: Equatable {
        case notDetermined
        case denied
        case locating
        case located(CLLocation)
        case failed(String)
    }

    var status: Status = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            status = .locating
            manager.requestLocation()
        case .denied, .restricted:
            status = .denied
        @unknown default:
            status = .denied
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        Task { @MainActor in self.status = .located(loc) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.status = .failed(error.localizedDescription) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let auth = manager.authorizationStatus
        Task { @MainActor in
            switch auth {
            case .authorizedWhenInUse, .authorizedAlways:
                self.status = .locating
                self.manager.requestLocation()
            case .denied, .restricted:
                self.status = .denied
            default:
                break
            }
        }
    }
}
