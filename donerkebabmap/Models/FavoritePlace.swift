//
//  FavoritePlace.swift
//  donerkebabmap
//

import Foundation

/// A favorite place stored as JSON in UserDefaults. MKMapItems have no stable
/// id, so matching is done by name + coordinate.
struct FavoritePlace: Codable, Identifiable, Equatable {
    var id = UUID()
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String
}
