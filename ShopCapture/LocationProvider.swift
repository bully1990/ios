import CoreLocation
import Foundation

@MainActor
final class LocationProvider: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var latestLocation: CLLocation?

    private let manager = CLLocationManager()
    private var waitContinuations: [UUID: CheckedContinuation<CLLocation?, Never>] = [:]

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
    }

    func requestWhenInUseAuthorization() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            print("Warning: location permission is not available.")
        @unknown default:
            break
        }
    }

    func currentLocation(timeout seconds: TimeInterval = 3) async -> CLLocation? {
        if let latestLocation, abs(latestLocation.timestamp.timeIntervalSinceNow) <= 10 {
            return latestLocation
        }

        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("Warning: location has not been authorized; saving coordinates as 0.0.")
            return nil
        }

        let waiterID = UUID()

        return await withCheckedContinuation { continuation in
            waitContinuations[waiterID] = continuation
            manager.requestLocation()

            Task {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                await MainActor.run {
                    guard let continuation = self.waitContinuations.removeValue(forKey: waiterID) else {
                        return
                    }

                    print("Warning: location was not available within 3 seconds; saving coordinates as 0.0.")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func resolveWaiters(with location: CLLocation?) {
        let continuations = waitContinuations
        waitContinuations.removeAll()
        continuations.values.forEach { $0.resume(returning: location) }
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus

            if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else {
                return
            }
            latestLocation = location
            resolveWaiters(with: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("Warning: location update failed: \(error.localizedDescription)")
            resolveWaiters(with: nil)
        }
    }
}
