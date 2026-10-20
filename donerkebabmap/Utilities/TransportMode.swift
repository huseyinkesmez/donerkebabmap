//
//  TransportMode.swift
//  donerkebabmap
//

import MapKit
import SwiftUI

/// The user's chosen transport mode. Used both for the ETA calculation and
/// when handing directions off to map apps.
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

    /// Mode key for Apple Maps `launchOptions`.
    var appleMapsMode: String {
        switch self {
        case .driving: MKLaunchOptionsDirectionsModeDriving
        case .walking: MKLaunchOptionsDirectionsModeWalking
        }
    }

    /// `directionsmode` / `travelmode` value for the Google Maps URL.
    var googleMapsMode: String {
        switch self {
        case .driving: "driving"
        case .walking: "walking"
        }
    }
}
