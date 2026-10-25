//
//  PlacesSearchService.swift
//  donerkebabmap
//

import CoreLocation
import MapKit

/// Thrown when every keyword search fails (e.g. no internet connection).
struct SearchFailedError: Error {}

/// One keyword search result and its position in that search's results.
private struct SearchHit {
    let item: MKMapItem
    let keyword: String
    let rank: Int
}

/// A deduplicated place and the best rank per keyword that returned it.
private struct Candidate {
    let item: MKMapItem
    /// MapKit's stable place identifier (iOS 18+), when available.
    let identifier: String?
    let name: String
    let location: CLLocation
    var keywordRanks: [String: Int]
}

final class PlacesSearchService {
    /// Each MapKit search returns at most 25 results, so variety matters more than
    /// synonyms: near-duplicates ("doner"/"döner", "kebab"/"kebab restaurant") just
    /// return the same 25 places. This set was picked by measuring which keywords
    /// add places no other keyword finds (Istanbul + Berlin, 100% coverage of the
    /// original 27 keywords); fewer requests also means less MapKit throttling.
    private let searchKeywords = [
        "kebab",
        "dönerci",
        "tantuni",
        "dürüm",
        "kebap salonu",
        "döner salonu",
        "iskender",
        "döner",
        "adana kebap",
        "döner imbiss",
        "kebab takeaway",
        "şavarma",
        "kebapçı",
        "döner kebap",
        "shawarma",
        "kebab house",
        "gyros",
        "kebap",
        "döner kebab",
        "kebab shop"
    ]
    /// Used by "Search This Area". MapKit throttles an app at roughly 50
    /// requests a minute, and the full list is 20 requests per search, so
    /// repeated area searches got throttled and came back empty or partial.
    /// The list above is ordered by how many new places each keyword adds, so
    /// its first keywords find most places.
    private let quickKeywordCount = 8

    /// Keywords whose results alone don't prove a place serves doner. Where real
    /// matches are scarce (e.g. "shawarma" in Turkey, "gyros" near Greek
    /// tavernas), MapKit pads these with unrelated nearby restaurants.
    private let weakKeywords: Set<String> = ["gyro", "gyros", "şavarma", "shawarma", "shoarma"]
    /// A name containing one of these (case/diacritic-folded) is a doner/kebab place.
    private let strongNameTerms = [
        "doner", "kebab", "kebap", "durum", "gyro", "shawarma", "schawarma", "shoarma",
        "savarma", "iskender", "tantuni", "adana", "ocakbas"
    ]
    /// Names that hint at a kebab shop but need at least some keyword support.
    private let weakNameTerms = ["imbiss", "grill"]
    /// A place returned by a single trusted keyword is kept only if ranked this high.
    private let maxSingleKeywordRank = 5

    /// Two results with the same name count as one place only within this distance.
    /// Farther apart, they are different branches of the same chain and are kept.
    private let sameNameDistanceThreshold: Double = 250
    /// Without a MapKit identifier, results with different names count as the same
    /// POI only at (almost) the same coordinate. This used to be 25 m, which merged
    /// neighboring shops on the same street and dropped one of them at random.
    private let sameSpotDistanceThreshold: Double = 3

    /// Searches a circle around `center`. Distances shown to the user are measured
    /// from `userLocation` (which differs from `center` for "Search This Area");
    /// without a user location they stay nil.
    func search(
        center coordinate: CLLocationCoordinate2D,
        radiusInMeters: Double = 20_000,
        userLocation userCoordinate: CLLocationCoordinate2D?,
        quick: Bool = false
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

        let centerLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let userLocation = userCoordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: radiusInMeters * 2,
            longitudinalMeters: radiusInMeters * 2
        )

        let keywords = quick ? Array(searchKeywords.prefix(quickKeywordCount)) : searchKeywords
        var hits: [SearchHit] = []
        var failedCount = 0

        await withTaskGroup(of: (String, [MKMapItem]?).self) { group in
            for keyword in keywords {
                group.addTask {
                    (keyword, await self.performSearch(keyword: keyword, region: region))
                }
            }

            for await (keyword, items) in group {
                guard let items else { // nil = this search failed
                    failedCount += 1
                    continue
                }
                for (index, item) in items.enumerated() {
                    hits.append(SearchHit(item: item, keyword: keyword, rank: index + 1))
                }
            }
        }

        // Only a total failure (no internet, or fully throttled) is an error.
        // Partial results are still useful: they add to the places already found.
        guard failedCount < keywords.count else { throw SearchFailedError() }

        let relevant = deduplicate(hits).filter(isRelevant)
        let places = relevant.compactMap { candidate -> (place: DonerPlace, centerDistance: Double)? in
            let mapItem = candidate.item
            let placeCoordinate = mapItem.placemark.coordinate
            guard CLLocationCoordinate2DIsValid(placeCoordinate) else { return nil }

            let placeLocation = CLLocation(
                latitude: placeCoordinate.latitude,
                longitude: placeCoordinate.longitude
            )
            let centerDistance = centerLocation.distance(from: placeLocation)
            guard centerDistance <= radiusInMeters else { return nil }

            let place = DonerPlace(
                id: UUID(),
                name: mapItem.name ?? String(localized: "Unknown"),
                coordinate: placeCoordinate,
                address: formattedAddress(from: mapItem),
                distanceInMeters: userLocation?.distance(from: placeLocation),
                rating: nil,
                mapItem: mapItem
            )
            return (place, centerDistance)
        }

        // Nearest to the user first; without a user location, nearest to the center.
        return places
            .sorted { ($0.place.distanceInMeters ?? $0.centerDistance) < ($1.place.distanceInMeters ?? $1.centerDistance) }
            .map(\.place)
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

    /// Merges results that are the same place, keeping every keyword (and its
    /// best rank) that returned it — that history is what `isRelevant` scores.
    private func deduplicate(_ hits: [SearchHit]) -> [Candidate] {
        var unique: [Candidate] = []

        for hit in hits {
            let coordinate = hit.item.placemark.coordinate
            let name = normalizedName(hit.item.name)
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let identifier = Self.identifier(of: hit.item)

            if let index = unique.firstIndex(where: { isSamePlace(identifier, name, location, $0) }) {
                let best = min(unique[index].keywordRanks[hit.keyword] ?? .max, hit.rank)
                unique[index].keywordRanks[hit.keyword] = best
            } else {
                unique.append(Candidate(
                    item: hit.item,
                    identifier: identifier,
                    name: name,
                    location: location,
                    keywordRanks: [hit.keyword: hit.rank]
                ))
            }
        }

        return unique
    }

    private func isSamePlace(
        _ identifier: String?,
        _ name: String,
        _ location: CLLocation,
        _ other: Candidate
    ) -> Bool {
        // MapKit's stable place identifier (iOS 18+) settles it when both have one.
        if let identifier, let otherIdentifier = other.identifier {
            return identifier == otherIdentifier
        }

        let distance = location.distance(from: other.location)

        // The same name ALONE is not enough: different branches can share a name.
        if !name.isEmpty, name == other.name {
            return distance < sameNameDistanceThreshold
        }

        return distance < sameSpotDistanceThreshold
    }

    /// MapKit fills sparse keyword searches with nearby restaurants that have
    /// nothing to do with doner (lounges, hotels, çiğköfte...). Keep a place only
    /// when the evidence says it serves doner/kebab:
    /// - its name says so, or
    /// - at least two trusted keywords returned it, or
    /// - one trusted keyword returned it near the top, or
    /// - its name hints at it ("imbiss", "grill") and a trusted keyword returned it.
    /// Weak keywords (shawarma/gyro families) never count on their own.
    private func isRelevant(_ candidate: Candidate) -> Bool {
        // Folding also matches decomposed Unicode (MapKit sometimes returns "ö"
        // as "o" + a combining mark) and treats "döner" and "doner" alike.
        let name = (candidate.item.name ?? "")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        if strongNameTerms.contains(where: name.contains) { return true }

        let trustedRanks = candidate.keywordRanks
            .filter { !weakKeywords.contains($0.key) }
            .map(\.value)
        guard let bestRank = trustedRanks.min() else { return false }

        return trustedRanks.count >= 2
            || bestRank <= maxSingleKeywordRank
            || weakNameTerms.contains(where: name.contains)
    }

    private static func identifier(of item: MKMapItem) -> String? {
        if #available(iOS 18.0, *) {
            return item.identifier?.rawValue
        }
        return nil
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
