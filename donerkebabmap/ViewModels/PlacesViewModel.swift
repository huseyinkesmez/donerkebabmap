//
//  PlacesViewModel.swift
//  donerkebabmap
//

import Combine
import CoreLocation
import MapKit

@MainActor
final class PlacesViewModel: ObservableObject {
    @Published private(set) var places: [DonerPlace] = []
    @Published private(set) var isLoading = false
    /// True when the last search failed (e.g. no internet connection).
    @Published private(set) var loadFailed = false

    let searchRadius: Double

    private let searchService = PlacesSearchService()
    private var hasSearched = false

    init(searchRadius: Double = 20_000) {
        self.searchRadius = searchRadius
    }

    /// Searches once, on the first valid location; later location updates do not
    /// trigger it again.
    func loadPlacesIfNeeded(around coordinate: CLLocationCoordinate2D) {
        guard !hasSearched else { return }
        hasSearched = true
        Task { await performSearch(center: coordinate, radius: searchRadius, userLocation: coordinate) }
    }

    /// Runs the search again, for a manual refresh.
    func refresh(around coordinate: CLLocationCoordinate2D) async {
        await performSearch(center: coordinate, radius: searchRadius, userLocation: coordinate)
    }

    /// "Search This Area": replaces the results with places in the visible region.
    /// The radius reaches the corners of the visible area, clamped to 1 km...`searchRadius`.
    func searchArea(_ region: MKCoordinateRegion, userLocation: CLLocationCoordinate2D?) async {
        let metersPerDegree = 111_000.0
        let height = region.span.latitudeDelta * metersPerDegree
        let width = region.span.longitudeDelta * metersPerDegree * cos(region.center.latitude * .pi / 180)
        let radius = min(max(hypot(height, width) / 2, 1_000), searchRadius)
        await performSearch(center: region.center, radius: radius, userLocation: userLocation)
    }

    private func performSearch(
        center: CLLocationCoordinate2D,
        radius: Double,
        userLocation: CLLocationCoordinate2D?
    ) async {
        isLoading = true
        loadFailed = false
        do {
            places = try await searchService.search(
                center: center,
                radiusInMeters: radius,
                userLocation: userLocation
            )
        } catch {
            loadFailed = true
        }
        isLoading = false
    }
}
