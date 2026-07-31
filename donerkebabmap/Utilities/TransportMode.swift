//
//  TransportMode.swift
//  donerkebabmap
//

import MapKit
import SwiftUI

/// Kullanıcının seçtiği ulaşım türü. Hem tahmini süre (ETA) hesabında hem de
/// harita uygulamalarına yol tarifi açarken kullanılır.
enum TransportMode: String, CaseIterable, Identifiable {
    case driving
    case walking

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .driving: "Drive"
        case .walking: "Walk"
        }
    }

    var icon: String {
        switch self {
        case .driving: "car.fill"
        case .walking: "figure.walk"
        }
    }

    var mkTransportType: MKDirectionsTransportType {
        switch self {
        case .driving: .automobile
        case .walking: .walking
        }
    }

    /// Apple Haritalar `launchOptions` için mod anahtarı.
    var appleMapsMode: String {
        switch self {
        case .driving: MKLaunchOptionsDirectionsModeDriving
        case .walking: MKLaunchOptionsDirectionsModeWalking
        }
    }

    /// Google Haritalar URL'i için `directionsmode` / `travelmode` değeri.
    var googleMapsMode: String {
        switch self {
        case .driving: "driving"
        case .walking: "walking"
        }
    }
}
