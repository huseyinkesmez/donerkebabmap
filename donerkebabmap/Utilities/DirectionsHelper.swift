//
//  DirectionsHelper.swift
//  donerkebabmap
//

import MapKit
import SwiftUI
import UIKit

/// The app "Get Directions" opens. Persisted with `@AppStorage`.
enum PreferredMapsApp: String, CaseIterable, Identifiable {
    case ask
    case apple
    case google

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .ask: "Ask Every Time"
        case .apple: "Apple Maps"
        case .google: "Google Maps"
        }
    }
}

enum DirectionsHelper {
    static func openInAppleMaps(place: DonerPlace, mode: TransportMode = .driving) {
        place.mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: mode.appleMapsMode
        ])
    }

    static func openInGoogleMaps(place: DonerPlace, mode: TransportMode = .driving) {
        let latitude = place.coordinate.latitude
        let longitude = place.coordinate.longitude

        guard
            let appURL = URL(string: "comgooglemaps://?daddr=\(latitude),\(longitude)&directionsmode=\(mode.googleMapsMode)"),
            let webURL = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(latitude),\(longitude)&travelmode=\(mode.googleMapsMode)")
        else {
            return
        }

        if UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else {
            UIApplication.shared.open(webURL)
        }
    }
}
