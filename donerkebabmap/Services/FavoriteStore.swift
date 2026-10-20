//
//  FavoriteStore.swift
//  donerkebabmap
//

import Combine
import CoreLocation
import Foundation

/// Shared store that keeps favorite places in UserDefaults (as JSON). Saves
/// automatically on every change and loads on init. No backend.
@MainActor
final class FavoriteStore: ObservableObject {
    @Published private(set) var favorites: [FavoritePlace] = []

    private let defaultsKey = "favorite_places"
    /// Match tolerance, since coordinates can drift slightly between searches.
    private let matchThresholdMeters: CLLocationDistance = 30

    init() {
        load()
    }

    func isFavorite(_ place: DonerPlace) -> Bool {
        favorites.contains { matches($0, place) }
    }

    /// Toggles the favorite state (add/remove).
    func toggle(_ place: DonerPlace) {
        if let index = favorites.firstIndex(where: { matches($0, place) }) {
            favorites.remove(at: index)
        } else {
            favorites.append(
                FavoritePlace(
                    name: place.name,
                    latitude: place.coordinate.latitude,
                    longitude: place.coordinate.longitude,
                    address: place.address
                )
            )
        }
        save()
    }

    func remove(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where favorites.indices.contains(index) {
            favorites.remove(at: index)
        }
        save()
    }

    // MARK: - Matching

    private func matches(_ favorite: FavoritePlace, _ place: DonerPlace) -> Bool {
        guard favorite.name == place.name else { return false }
        let a = CLLocation(latitude: favorite.latitude, longitude: favorite.longitude)
        let b = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        return a.distance(from: b) < matchThresholdMeters
    }

    // MARK: - Persistence

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode([FavoritePlace].self, from: data)
        else {
            return
        }
        favorites = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
