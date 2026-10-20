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
    /// İzin verildiği hâlde makul sürede konum alınamadıysa true olur; arayüz
    /// sonsuz "yükleniyor" yerine tekrar dene seçeneği gösterir.
    @Published private(set) var locationTimedOut = false

    private let locationManager = CLLocationManager()
    private var timeoutTask: Task<Void, Never>?
    private let locationTimeoutSeconds: UInt64 = 15

    override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        // Yakındaki dükkânları listelemek için yüz metre hassasiyet fazlasıyla
        // yeterli; en yüksek hassasiyet gereksiz pil tüketiyordu.
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestWhenInUseAuthorization()
        startUpdatingLocationIfAuthorized()
    }

    /// Konum alınamadığında kullanıcının tekrar denemesi için.
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
        // Uygulama konumu tek sefer kullanıyor (arama + haritayı ortalama);
        // sürekli takip pil tüketirdi. Haritadaki mavi nokta MapKit'in kendi
        // konum servisiyle çalışmaya devam eder.
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
            // Konum geçici olarak belirlenemedi; sistem yeniden denemeye devam eder.
            return
        }
        print("[LocationManager] Konum güncellemesi başarısız: \(error.localizedDescription)")
    }
}
