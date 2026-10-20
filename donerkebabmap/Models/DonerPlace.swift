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
    /// Distance to the user. Nil when the location is unknown (e.g. a favorite opened from the profile).
    let distanceInMeters: Double?
    /// Place rating (e.g. 4.3). MapKit does not provide this, so it is nil for now.
    /// To be populated later via a Google Places integration.
    let rating: Double?
    let mapItem: MKMapItem

    /// Human-readable straight-line distance; nil when the distance is unknown.
    /// The detail card shows the route distance instead when it is available.
    var formattedDistance: String? {
        guard let distanceInMeters else { return nil }
        return DistanceFormatter.string(fromMeters: distanceInMeters)
    }

    /// Callable phone number, if any.
    var phoneNumber: String? {
        guard let phone = mapItem.phoneNumber, !phone.isEmpty else { return nil }
        return phone
    }

    /// The business website, if any.
    var website: URL? {
        mapItem.url
    }

    /// Readable, localizable name of the POI category, if any.
    var categoryName: LocalizedStringResource? {
        switch mapItem.pointOfInterestCategory {
        case .restaurant: "Restaurant"
        case .foodMarket: "Food Market"
        case .bakery: "Bakery"
        case .cafe: "Café"
        default: nil
        }
    }

    /// Apple Maps link used for sharing.
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
    /// Builds a `DonerPlace` from a saved favorite. The distance is computed when
    /// a user location is given; otherwise it stays nil (the distance row is hidden).
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
