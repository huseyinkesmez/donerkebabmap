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
    /// The region currently on screen, reported by the map when it settles.
    @State private var visibleRegion: MKCoordinateRegion?
    /// The region the current results belong to. "Search This Area" appears
    /// once the user moves the map far enough away from it.
    @State private var searchedRegion: MKCoordinateRegion?
    @State private var hasUserMovedMap = false
    @State private var showsNoResults = false
    /// True while the results come from "Search This Area" instead of the
    /// search around the user.
    @State private var isShowingAreaResults = false

    /// Area shown when the map opens (~1 km around the user).
    /// The search radius stays 20 km; this is only the visual zoom.
    private let initialZoomMeters: Double = 1_000

    var body: some View {
        ZStack(alignment: .top) {
            map
            searchAreaOverlay
                .padding(.top, 8)
        }
    }

    private var map: some View {
        ClusteredMapView(
            places: placesViewModel.places,
            focusCoordinate: locationManager.userLocation,
            initialZoomMeters: initialZoomMeters,
            selectedPlaceID: selectedPlace?.id,
            onSelect: { place in
                selectedPlace = place
                isShowingDetail = true
            },
            onRegionChange: handleRegionChange,
            onReturnToUser: returnToUser
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

    @ViewBuilder
    private var searchAreaOverlay: some View {
        if showsNoResults {
            Text("No doner places in this area")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                .transition(.move(edge: .top).combined(with: .opacity))
        } else if showsSearchAreaButton {
            Button(action: searchVisibleArea) {
                HStack(spacing: 8) {
                    if placesViewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                        Text("Searching…")
                    } else {
                        Image(systemName: "arrow.clockwise")
                        Text("Search This Area")
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.primary, in: Capsule())
                .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(placesViewModel.isLoading)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// Shown after the user pans away by more than a third of the screen or
    /// zooms out a lot. Zooming in never needs a new search.
    private var showsSearchAreaButton: Bool {
        guard hasUserMovedMap,
              let visibleRegion, let searchedRegion,
              !isLocationDenied else { return false }

        if placesViewModel.isLoading { return true }

        let latShift = abs(visibleRegion.center.latitude - searchedRegion.center.latitude)
        let lonShift = abs(visibleRegion.center.longitude - searchedRegion.center.longitude)
        let pannedAway = latShift > searchedRegion.span.latitudeDelta * 0.33
            || lonShift > searchedRegion.span.longitudeDelta * 0.33
        let zoomedOut = visibleRegion.span.latitudeDelta > searchedRegion.span.latitudeDelta * 2.5
        return pannedAway || zoomedOut
    }

    private func handleRegionChange(_ region: MKCoordinateRegion, userInitiated: Bool) {
        visibleRegion = region
        if userInitiated {
            hasUserMovedMap = true
        } else if !hasUserMovedMap {
            // Moves made in code before the user touches the map (the initial
            // focus on their location) define the searched area.
            searchedRegion = region
        }
    }

    private func searchVisibleArea() {
        guard let region = visibleRegion else { return }
        Task {
            await placesViewModel.searchArea(region, userLocation: locationManager.userLocation)
            guard !placesViewModel.loadFailed else { return }
            isShowingAreaResults = true
            withAnimation { searchedRegion = region }
            if placesViewModel.places.isEmpty {
                withAnimation { showsNoResults = true }
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation { showsNoResults = false }
            }
        }
    }

    /// Back at the user's location, results from another area would leave the
    /// map empty around them, so search around the user again.
    private func returnToUser() {
        // The move back to the user becomes the new searched area.
        hasUserMovedMap = false
        guard isShowingAreaResults, let coordinate = locationManager.userLocation else { return }
        isShowingAreaResults = false
        Task { await placesViewModel.refresh(around: coordinate) }
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
