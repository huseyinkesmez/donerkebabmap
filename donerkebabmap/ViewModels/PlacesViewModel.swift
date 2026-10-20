//
//  PlacesViewModel.swift
//  donerkebabmap
//

import CoreLocation
import Combine

@MainActor
final class PlacesViewModel: ObservableObject {
    @Published private(set) var places: [DonerPlace] = []
    @Published private(set) var isLoading = false
    /// Son arama (ör. internet yokken) başarısız olduysa true.
    @Published private(set) var loadFailed = false

    let searchRadius: Double

    private let searchService = PlacesSearchService()
    private var hasSearched = false

    init(searchRadius: Double = 20_000) {
        self.searchRadius = searchRadius
    }

    /// İlk geçerli konumda bir kez arama yapar; sonraki konum güncellemelerinde
    /// tekrar tetiklenmez..
    func loadPlacesIfNeeded(around coordinate: CLLocationCoordinate2D) {
        guard !hasSearched else { return }
        hasSearched = true
        Task { await performSearch(around: coordinate) }
    }

    /// Kullanıcının elle yenilemesi için aramayı yeniden çalıştırır.
    func refresh(around coordinate: CLLocationCoordinate2D) async {
        await performSearch(around: coordinate)
    }

    private func performSearch(around coordinate: CLLocationCoordinate2D) async {
        isLoading = true
        loadFailed = false
        do {
            places = try await searchService.search(
                around: coordinate,
                radiusInMeters: searchRadius
            )
        } catch {
            loadFailed = true
        }
        isLoading = false
    }
}
