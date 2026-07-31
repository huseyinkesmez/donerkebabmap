//
//  DonerPlace.swift
//  donerkebabmap
//

import CoreLocation
import MapKit

struct DonerPlace: Identifiable, Equatable {
    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D
    let address: String
    /// Kullanıcıya mesafe. Konum bilinmiyorsa (ör. profildeki favori) nil olur.
    let distanceInMeters: Double?
    /// Yer puanı (ör. 4.3). MapKit bu veriyi sağlamıyor; şimdilik nil.
    /// İleride Google Places entegrasyonuyla doldurulacak.
    let rating: Double?
    let mapItem: MKMapItem

    /// Mesafe biçimi ("4.3 km"); mesafe bilinmiyorsa nil.
    var formattedDistance: String? {
        guard let distanceInMeters else { return nil }
        return String(format: "%.1f km", distanceInMeters / 1000)
    }

    /// Aranabilir telefon numarası (varsa).
    var phoneNumber: String? {
        guard let phone = mapItem.phoneNumber, !phone.isEmpty else { return nil }
        return phone
    }

    /// İşletmenin web sitesi (varsa).
    var website: URL? {
        mapItem.url
    }

    /// POI kategorisinin okunabilir/çevrilebilir adı (varsa).
    var categoryName: LocalizedStringResource? {
        switch mapItem.pointOfInterestCategory {
        case .restaurant: "Restaurant"
        case .foodMarket: "Food Market"
        case .bakery: "Bakery"
        case .cafe: "Café"
        default: nil
        }
    }

    /// Paylaşım için Apple Haritalar bağlantısı.
    var shareURL: URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "q", value: name),
            URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)")
        ]
        return components?.url
    }

    static func == (lhs: DonerPlace, rhs: DonerPlace) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.address == rhs.address &&
        lhs.distanceInMeters == rhs.distanceInMeters &&
        lhs.rating == rhs.rating &&
        lhs.mapItem.name == rhs.mapItem.name &&
        lhs.mapItem.placemark.coordinate.latitude == rhs.mapItem.placemark.coordinate.latitude &&
        lhs.mapItem.placemark.coordinate.longitude == rhs.mapItem.placemark.coordinate.longitude
    }
}

extension DonerPlace {
    /// Kaydedilmiş bir favoriden `DonerPlace` üretir. Mesafe, kullanıcı konumu
    /// verilmişse hesaplanır; yoksa nil kalır (mesafe satırı gizlenir).
    init(favorite: FavoritePlace, userLocation: CLLocationCoordinate2D?) {
        let coordinate = CLLocationCoordinate2D(
            latitude: favorite.latitude,
            longitude: favorite.longitude
        )

        let distance: Double?
        if let userLocation {
            let user = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            let place = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            distance = user.distance(from: place)
        } else {
            distance = nil
        }

        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = favorite.name

        self.init(
            id: UUID(),
            name: favorite.name,
            coordinate: coordinate,
            address: favorite.address,
            distanceInMeters: distance,
            rating: nil,
            mapItem: mapItem
        )
    }
}
