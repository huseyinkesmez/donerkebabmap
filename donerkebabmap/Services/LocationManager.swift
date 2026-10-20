//
//  LocationManager.swift
//  donerkebabmap
//

import Combine
import CoreLocation

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus
    /// True when permission is granted but no location arrives in reasonable time;
    /// the UI then offers a retry instead of loading forever.
    @Published private(set) var locationTimedOut = false

    private let locationManager = CLLocationManager()
    private var timeoutTask: Task<Void, Never>?
    private let locationTimeoutSeconds: UInt64 = 15

    override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        // Hundred-meter accuracy is plenty for listing nearby shops; best
        // accuracy was draining battery for no benefit.
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestWhenInUseAuthorization()
        startUpdatingLocationIfAuthorized()
    }

    /// Lets the user retry after the location could not be determined.
    func retryLocation() {
        locationTimedOut = false
        startUpdatingLocationIfAuthorized()
    }

    private func startUpdatingLocationIfAuthorized() {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            startTimeoutCountdown()
        default:
            locationManager.stopUpdatingLocation()
            cancelTimeoutCountdown()
        }
    }

    private func startTimeoutCountdown() {
        guard userLocation == nil else { return }
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: (self?.locationTimeoutSeconds ?? 15) * 1_000_000_000)
            guard !Task.isCancelled, let self, self.userLocation == nil else { return }
            self.locationTimedOut = true
            self.locationManager.stopUpdatingLocation()
        }
    }

    private func cancelTimeoutCountdown() {
        timeoutTask?.cancel()
        timeoutTask = nil
    }

    fileprivate func handle(_ location: CLLocation) {
        userLocation = location.coordinate
        locationTimedOut = false
        cancelTimeoutCountdown()
        // The app needs the location only once (search + centering the map);
        // continuous tracking would drain battery. The blue dot on the map keeps
        // working through MapKit's own location service.
        locationManager.stopUpdatingLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            startUpdatingLocationIfAuthorized()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            handle(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError, clError.code == .locationUnknown {
            // Location temporarily unknown; the system keeps retrying.
            return
        }
        print("[LocationManager] Location update failed: \(error.localizedDescription)")
    }
}
