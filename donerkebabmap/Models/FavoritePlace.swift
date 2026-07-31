//
//  FavoritePlace.swift
//  donerkebabmap
//

import Foundation

/// UserDefaults'a JSON olarak kaydedilen favori yer. MKMapItem'ların kalıcı
/// id'si olmadığı için eşleştirme isim + koordinat üzerinden yapılır.
struct FavoritePlace: Codable, Identifiable, Equatable {
    var id = UUID()
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String
}
