//
//  PlacesSearchService.swift
//  donerkebabmap
//

import CoreLocation
import MapKit

/// Tüm anahtar kelime aramaları (ör. internet yokken) başarısız olduğunda atılır.
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
    private let dedupeDistanceThreshold: Double = 50

    func search(
        around coordinate: CLLocationCoordinate2D,
        radiusInMeters: Double = 20_000
    ) async throws -> [DonerPlace] {
        let authorizationStatus = CLLocationManager().authorizationStatus
        switch authorizationStatus {
        case .denied, .restricted:
            print("[PlacesSearchService] Konum izni yok: \(authorizationStatus.rawValue)")
            return []
        default:
            break
        }

        guard CLLocationCoordinate2DIsValid(coordinate) else {
            print("[PlacesSearchService] Geçersiz koordinat: \(coordinate)")
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
                guard let items else { continue } // nil = bu arama hata verdi
                anySucceeded = true
                mapItems.append(contentsOf: items)
            }
        }

        // Hiçbir arama başarılı olmadıysa (ör. internet yok) hatayı yukarı taşı.
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

    /// Tek bir anahtar kelime araması. Hata olursa `nil` döner (boş dizi =
    /// başarılı ama sonuç yok; nil = arama başarısız, ör. ağ hatası).
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
            // Bağlantı var ama bu kelime için sonuç yok: başarılı-ama-boş.
            return []
        } catch {
            // Gerçek hata (ör. internet yok): başarısız.
            print("[PlacesSearchService] '\(keyword)' araması başarısız: \(error.localizedDescription)")
            return nil
        }
    }

    private func deduplicate(_ mapItems: [MKMapItem]) -> [MKMapItem] {
        var uniqueItems: [MKMapItem] = []

        for mapItem in mapItems {
            let isDuplicate = uniqueItems.contains { existingItem in
                isSamePlace(mapItem, as: existingItem)
            }

            if !isDuplicate {
                uniqueItems.append(mapItem)
            }
        }

        return uniqueItems
    }

    private func isSamePlace(_ lhs: MKMapItem, as rhs: MKMapItem) -> Bool {
        let lhsName = normalizedName(lhs.name)
        let rhsName = normalizedName(rhs.name)

        if !lhsName.isEmpty, lhsName == rhsName {
            return true
        }

        let lhsLocation = CLLocation(
            latitude: lhs.placemark.coordinate.latitude,
            longitude: lhs.placemark.coordinate.longitude
        )
        let rhsLocation = CLLocation(
            latitude: rhs.placemark.coordinate.latitude,
            longitude: rhs.placemark.coordinate.longitude
        )

        return lhsLocation.distance(from: rhsLocation) < dedupeDistanceThreshold
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
