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
    /// True after the user pans or zooms; shows "Search This Area".
    @State private var mapMovedSinceSearch = false
    @State private var isSearchingArea = false
    @State private var toastMessage: LocalizedStringKey?
    /// Set to zoom the map to area results that are all off screen.
    @State private var zoomTarget: ClusteredMapView.ZoomTarget?
    @State private var mapReader = ClusteredMapView.MapReader()
    /// Changes on every pin or cluster tap to play a haptic.
    @State private var pinTapCount = 0
    /// Center of the last area search, to ignore the map settling right there.
    @State private var lastSearchCenter: CLLocationCoordinate2D?

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
            onReturnToUser: returnToUser,
            onPinTap: { pinTapCount += 1 },
            zoomTarget: zoomTarget,
            reader: mapReader
        )
        .ignoresSafeArea()
        .sensoryFeedback(.impact(weight: .medium), trigger: pinTapCount)
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
        if let toastMessage {
            Text(toastMessage)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                .padding(.horizontal, 24)
                .transition(.move(edge: .top).combined(with: .opacity))
        } else if isSearchingArea || (mapMovedSinceSearch && !isLocationDenied && !showsSeveralPins) {
            Button(action: searchVisibleArea) {
                HStack(spacing: 8) {
                    if isSearchingArea {
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
            .disabled(isSearchingArea)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// With several pins already on screen there is enough to look at, so the
    /// search button stays hidden.
    private var showsSeveralPins: Bool {
        guard let visibleRegion else { return false }
        return placesViewModel.places.lazy.filter { visibleRegion.contains($0.coordinate) }.prefix(2).count >= 2
    }

    /// Any pan or zoom by the user offers a new search; moves made in code
    /// (initial focus, revealing a pin, zooming to results) don't.
    private func handleRegionChange(_ region: MKCoordinateRegion, userInitiated: Bool) {
        visibleRegion = region
        guard userInitiated else { return }
        // The swipe that ended right where we just searched isn't a new move.
        if let lastSearchCenter,
           abs(region.center.latitude - lastSearchCenter.latitude) < region.span.latitudeDelta * 0.05,
           abs(region.center.longitude - lastSearchCenter.longitude) < region.span.longitudeDelta * 0.05 {
            return
        }
        withAnimation { mapMovedSinceSearch = true }
    }

    /// Searches a circle around the center of the visible map and replaces
    /// the results with what is inside it.
    private func searchVisibleArea() {
        // Read the live region: after a quick swipe the map may still be gliding
        // and the last settled region would be the old place.
        guard !isSearchingArea, let region = mapReader.stopAndReadRegion() ?? visibleRegion else { return }
        lastSearchCenter = region.center
        withAnimation {
            mapMovedSinceSearch = false
            isSearchingArea = true
        }
        Task {
            let found = await placesViewModel.searchArea(region, userLocation: locationManager.userLocation)
            withAnimation { isSearchingArea = false }

            guard let found else {
                mapMovedSinceSearch = true
                await showToast("Couldn't search this area. Try again in a moment.")
                return
            }
            if found.isEmpty {
                await showToast("No doner places in this area")
            } else {
                showIfOffScreen(found, around: region)
            }
        }
    }

    private func showToast(_ message: LocalizedStringKey) async {
        withAnimation { toastMessage = message }
        try? await Task.sleep(for: .seconds(2.5))
        withAnimation { toastMessage = nil }
    }

    /// The search circle is larger than a zoomed-in screen, so all results can
    /// be off screen. Then zoom out just enough to show the nearest few.
    private func showIfOffScreen(_ places: [DonerPlace], around region: MKCoordinateRegion) {
        guard !places.contains(where: { region.contains($0.coordinate) }) else { return }
        let center = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        let nearest = places
            .sorted {
                center.distance(from: CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude))
                    < center.distance(from: CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude))
            }
            .prefix(3)
        zoomTarget = .init(coordinates: [region.center] + nearest.map(\.coordinate))
    }

    /// The location button brings the map back to the user, whose nearby
    /// places are still loaded, so no new search is needed there.
    private func returnToUser() {
        withAnimation { mapMovedSinceSearch = false }
        lastSearchCenter = nil
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

private extension MKCoordinateRegion {
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        abs(coordinate.latitude - center.latitude) <= span.latitudeDelta / 2
            && abs(coordinate.longitude - center.longitude) <= span.longitudeDelta / 2
    }
}

#Preview {
    MapTabView()
        .environmentObject(LocationManager())
        .environmentObject(PlacesViewModel())
        .environmentObject(FavoriteStore())
}
