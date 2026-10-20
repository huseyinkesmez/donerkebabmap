//
//  PlacesSearchService.swift
//  donerkebabmap
//

import CoreLocation
import MapKit

/// Thrown when every keyword search fails (e.g. no internet connection).
struct SearchFailedError: Error {}

final class PlacesSearchService {
    private let searchKeywords = [
        "döner",
        "kebab",
        "kebap",
        "gyro",
        "dönerci",
        "döner salonu",
        "döner kebap",
        "döner kebab",
        "şavarma",
        "shawarma",
        "dürüm",
        "kebapçı",
        "kebap salonu",
        "doner",
        "iskender",
        "adana kebap",
        "tantuni",
        "kebab shop",
        "kebab house",
        "doner kebab",
        "döner imbiss",
        "kebab restaurant",
        "gyros",
        "shoarma",
        "kebab takeaway",
        "rotisserie kebab",
        "kebab stand"
    ]
    /// Two results with the same name count as one place only within this distance.
    /// Farther apart, they are different branches of the same chain and are kept.
    private let sameNameDistanceThreshold: Double = 250
    /// Two results this close are treated as the same POI even if the names differ
    /// (the same shop may be spelled slightly differently across keywords).
    private let sameSpotDistanceThreshold: Double = 25

    func search(
        around coordinate: CLLocationCoordinate2D,
        radiusInMeters: Double = 20_000
    ) async throws -> [DonerPlace] {
        let authorizationStatus = CLLocationManager().authorizationStatus
        switch authorizationStatus {
        case .denied, .restricted:
            print("[PlacesSearchService] No location permission: \(authorizationStatus.rawValue)")
            return []
        default:
            break
        }

        guard CLLocationCoordinate2DIsValid(coordinate) else {
            print("[PlacesSearchService] Invalid coordinate: \(coordinate)")
            return []
        }

        let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: radiusInMeters * 2,
            longitudinalMeters: radiusInMeters * 2
        )

        var mapItems: [MKMapItem] = []
        var anySucceeded = false

        await withTaskGroup(of: [MKMapItem]?.self) { group in
            for keyword in searchKeywords {
                group.addTask {
                    await self.performSearch(keyword: keyword, region: region)
                }
            }

            for await items in group {
                guard let items else { continue } // nil = this search failed
                anySucceeded = true
                mapItems.append(contentsOf: items)
            }
        }

        // If no search succeeded (e.g. no internet), propagate the error.
        guard anySucceeded else { throw SearchFailedError() }

        let uniqueItems = deduplicate(mapItems)
        let places = uniqueItems.compactMap { mapItem -> DonerPlace? in
            let placeCoordinate = mapItem.placemark.coordinate
            guard CLLocationCoordinate2DIsValid(placeCoordinate) else { return nil }

            let placeLocation = CLLocation(
                latitude: placeCoordinate.latitude,
                longitude: placeCoordinate.longitude
            )
            let distance = userLocation.distance(from: placeLocation)
            guard distance <= radiusInMeters else { return nil }

            return DonerPlace(
                id: UUID(),
                name: mapItem.name ?? String(localized: "Unknown"),
                coordinate: placeCoordinate,
                address: formattedAddress(from: mapItem),
                distanceInMeters: distance,
                rating: nil,
                mapItem: mapItem
            )
        }

        return places.sorted {
            ($0.distanceInMeters ?? .greatestFiniteMagnitude) < ($1.distanceInMeters ?? .greatestFiniteMagnitude)
        }
    }

    /// A single keyword search. Returns `nil` on failure (empty array =
    /// succeeded with no results; nil = the search failed, e.g. a network error).
    private func performSearch(keyword: String, region: MKCoordinateRegion) async -> [MKMapItem]? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = keyword
        request.region = region
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.restaurant, .foodMarket])

        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            return response.mapItems
        } catch let error as MKError where error.code == .placemarkNotFound {
            // Connected, but no results for this keyword: success with no items.
            return []
        } catch {
            // A real error (e.g. no internet): failure.
            print("[PlacesSearchService] '\(keyword)' search failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func deduplicate(_ mapItems: [MKMapItem]) -> [MKMapItem] {
        // Compute each location once and carry it along; otherwise a new
        // CLLocation was created on every comparison.
        var unique: [(item: MKMapItem, name: String, location: CLLocation)] = []

        for mapItem in mapItems {
            let coordinate = mapItem.placemark.coordinate
            let candidate = (
                item: mapItem,
                name: normalizedName(mapItem.name),
                location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            )

            let isDuplicate = unique.contains { existing in
                isSamePlace(candidate, existing)
            }

            if !isDuplicate {
                unique.append(candidate)
            }
        }

        return unique.map(\.item)
    }

    private func isSamePlace(
        _ lhs: (item: MKMapItem, name: String, location: CLLocation),
        _ rhs: (item: MKMapItem, name: String, location: CLLocation)
    ) -> Bool {
        let distance = lhs.location.distance(from: rhs.location)

        // The same name ALONE is not enough: different branches can share a name.
        if !lhs.name.isEmpty, lhs.name == rhs.name {
            return distance < sameNameDistanceThreshold
        }

        return distance < sameSpotDistanceThreshold
    }

    private func normalizedName(_ name: String?) -> String {
        name?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private func formattedAddress(from mapItem: MKMapItem) -> String {
        let placemark = mapItem.placemark

        if let title = placemark.title, !title.isEmpty {
            return title
        }

        return [
            placemark.thoroughfare,
            placemark.subThoroughfare,
            placemark.locality
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }
}
