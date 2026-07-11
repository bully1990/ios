import CoreLocation
import Foundation

@MainActor
final class LocationProvider: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var latestLocation: CLLocation?

    private let manager = CLLocationManager()
    private struct LocationWaiter {
        let minimumTimestamp: Date?
        let continuation: CheckedContinuation<CLLocation?, Never>
    }

    private var locationWaiters: [UUID: LocationWaiter] = [:]

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

        return await requestLocation(timeout: seconds, minimumTimestamp: nil)
    }

    func recentLocation(maxAge seconds: TimeInterval = 60) -> CLLocation? {
        guard let latestLocation,
              latestLocation.horizontalAccuracy >= 0,
              abs(latestLocation.timestamp.timeIntervalSinceNow) <= seconds else {
            return nil
        }
        return latestLocation
    }

    func freshLocation(
        timeout seconds: TimeInterval = 6,
        desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyHundredMeters
    ) async -> CLLocation? {
        let previousAccuracy = manager.desiredAccuracy
        manager.desiredAccuracy = desiredAccuracy
        manager.startUpdatingLocation()
        let location = await requestLocation(
            timeout: seconds,
            minimumTimestamp: Date().addingTimeInterval(-1)
        )
        manager.desiredAccuracy = previousAccuracy
        return location
    }

    private func requestLocation(timeout seconds: TimeInterval, minimumTimestamp: Date?) async -> CLLocation? {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("Warning: location has not been authorized; saving coordinates as 0.0.")
            return nil
        }

        let waiterID = UUID()

        return await withCheckedContinuation { continuation in
            locationWaiters[waiterID] = LocationWaiter(
                minimumTimestamp: minimumTimestamp,
                continuation: continuation
            )
            manager.requestLocation()

            Task {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                await MainActor.run {
                    guard let waiter = self.locationWaiters.removeValue(forKey: waiterID) else {
                        return
                    }

                    let fallback = self.latestLocation.flatMap { location in
                        location.horizontalAccuracy >= 0
                            && abs(location.timestamp.timeIntervalSinceNow) <= 60 ? location : nil
                    }
                    print("Warning: fresh location was not available before timeout; using recent location if possible.")
                    waiter.continuation.resume(returning: fallback)
                }
            }
        }
    }

    private func resolveWaiters(with location: CLLocation) {
        guard location.horizontalAccuracy >= 0 else { return }

        let readyIDs = locationWaiters.compactMap { id, waiter in
            guard let minimumTimestamp = waiter.minimumTimestamp else { return id }
            return location.timestamp >= minimumTimestamp ? id : nil
        }
        for id in readyIDs {
            locationWaiters.removeValue(forKey: id)?.continuation.resume(returning: location)
        }
    }

    private func failWaiters() {
        let waiters = locationWaiters.values
        locationWaiters.removeAll()
        waiters.forEach { $0.continuation.resume(returning: nil) }
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
            guard let location = locations.last, location.horizontalAccuracy >= 0 else {
                return
            }
            latestLocation = location
            resolveWaiters(with: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("Warning: location update failed: \(error.localizedDescription)")
            if let locationError = error as? CLError, locationError.code == .locationUnknown {
                return
            }
            failWaiters()
        }
    }
}
