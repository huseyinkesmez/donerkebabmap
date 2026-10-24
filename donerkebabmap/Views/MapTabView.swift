//
//  MapTabView.swift
//  donerkebabmap
//

import MapKit
import SwiftUI

struct MapTabView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var placesViewModel: PlacesViewModel

    @State private var selectedPlace: DonerPlace?
    /// Kept separate from `selectedPlace` so tapping another pin while the sheet
    /// is open swaps its content instead of dismissing and re-presenting it.
    @State private var isShowingDetail = false

    /// Area shown when the map opens (~1 km around the user).
    /// The search radius stays 20 km; this is only the visual zoom.
    private let initialZoomMeters: Double = 1_000

    var body: some View {
        ClusteredMapView(
            places: placesViewModel.places,
            focusCoordinate: locationManager.userLocation,
            initialZoomMeters: initialZoomMeters,
            selectedPlaceID: selectedPlace?.id,
            onSelect: { place in
                selectedPlace = place
                isShowingDetail = true
            }
        )
        .ignoresSafeArea()
        .overlay {
            if isLocationDenied {
                LocationPermissionView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            } else if placesViewModel.loadFailed && placesViewModel.places.isEmpty {
                SearchErrorView(retry: retrySearch)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            } else if locationManager.locationTimedOut, locationManager.userLocation == nil {
                LocationUnavailableView(retry: locationManager.retryLocation)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            } else if placesViewModel.places.isEmpty,
                      placesViewModel.isLoading || locationManager.userLocation == nil {
                LoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $isShowingDetail, onDismiss: { selectedPlace = nil }) {
            if let selectedPlace {
                PlaceDetailCard(place: selectedPlace)
            }
        }
    }

    private var isLocationDenied: Bool {
        locationManager.authorizationStatus == .denied ||
        locationManager.authorizationStatus == .restricted
    }

    private func retrySearch() {
        guard let coordinate = locationManager.userLocation else { return }
        Task { await placesViewModel.refresh(around: coordinate) }
    }
}

#Preview {
    MapTabView()
        .environmentObject(LocationManager())
        .environmentObject(PlacesViewModel())
        .environmentObject(FavoriteStore())
}
