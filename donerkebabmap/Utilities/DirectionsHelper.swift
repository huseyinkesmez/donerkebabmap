//
//  DirectionsHelper.swift
//  donerkebabmap
//

import MapKit
import UIKit

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
