//
//  PlacesViewModel.swift
//  donerkebabmap
//

import Combine
import CoreLocation
import MapKit

@MainActor
final class PlacesViewModel: ObservableObject {
    /// Every place found so far, nearest to the user first. Searches add to
    /// this list instead of replacing it: places found around the user stay
    /// on the map after searching another area, so going back home never
    /// needs a new search (which MapKit may throttle).
    @Published private(set) var places: [DonerPlace] = []
    @Published private(set) var isLoading = false
    /// True when the last search failed (e.g. no internet connection).
    @Published private(set) var loadFailed = false

    let searchRadius: Double
    private static let minimumAreaRadius: Double = 3_000
    /// Two results with the same name count as one place within this distance
    /// (same rule as `PlacesSearchService`).
    private static let sameNameDistance: CLLocationDistance = 250

    private let searchService = PlacesSearchService()
    private var hasSearched = false
    private var runningSearches = 0

    init(searchRadius: Double = 20_000) {
        self.searchRadius = searchRadius
    }

    /// Searches once, on the first valid location; later location updates do not
    /// trigger it again.
    func loadPlacesIfNeeded(around coordinate: CLLocationCoordinate2D) {
        guard !hasSearched else { return }
        hasSearched = true
        Task { await performSearch(center: coordinate, radius: searchRadius, userLocation: coordinate, quick: false) }
    }

    /// Runs the search again, for a manual refresh.
    func refresh(around coordinate: CLLocationCoordinate2D) async {
        await performSearch(center: coordinate, radius: searchRadius, userLocation: coordinate, quick: false)
    }

    /// "Search This Area": adds the places in a circle around the visible
    /// region's center. The circle reaches the corners of the visible area but
    /// is at least `minimumAreaRadius`, so a zoomed-in map still finds the
    /// nearest places; at most `searchRadius`.
    /// Returns the places found in the circle, or nil if the search failed.
    func searchArea(_ region: MKCoordinateRegion, userLocation: CLLocationCoordinate2D?) async -> [DonerPlace]? {
        let metersPerDegree = 111_000.0
        let height = region.span.latitudeDelta * metersPerDegree
        let width = region.span.longitudeDelta * metersPerDegree * cos(region.center.latitude * .pi / 180)
        let radius = min(max(hypot(height, width) / 2, Self.minimumAreaRadius), searchRadius)
        return await performSearch(center: region.center, radius: radius, userLocation: userLocation, quick: true)
    }

    @discardableResult
    private func performSearch(
        center: CLLocationCoordinate2D,
        radius: Double,
        userLocation: CLLocationCoordinate2D?,
        quick: Bool
    ) async -> [DonerPlace]? {
        runningSearches += 1
        isLoading = true
        loadFailed = false
        defer {
            runningSearches -= 1
            isLoading = runningSearches > 0
        }

        do {
            let found = try await searchService.search(
                center: center,
                radiusInMeters: radius,
                userLocation: userLocation,
                quick: quick
            )
            return merge(found)
        } catch {
            loadFailed = true
            return nil
        }
    }

    /// Adds new places to `places` and returns `found` with places already
    /// known swapped for the existing instance, so their pins (keyed by id)
    /// stay put instead of being removed and re-added.
    private func merge(_ found: [DonerPlace]) -> [DonerPlace] {
        var all = places
        let result = found.map { place in
            if let existing = all.first(where: { isSamePlace($0, place) }) {
                return existing
            }
            all.append(place)
            return place
        }
        places = all.sorted { ($0.distanceInMeters ?? .infinity) < ($1.distanceInMeters ?? .infinity) }
        return result
    }

    private func isSamePlace(_ a: DonerPlace, _ b: DonerPlace) -> Bool {
        if #available(iOS 18.0, *),
           let idA = a.mapItem.identifier, let idB = b.mapItem.identifier {
            return idA == idB
        }
        let distance = CLLocation(latitude: a.coordinate.latitude, longitude: a.coordinate.longitude)
            .distance(from: CLLocation(latitude: b.coordinate.latitude, longitude: b.coordinate.longitude))
        return a.name == b.name && distance < Self.sameNameDistance
    }
}
