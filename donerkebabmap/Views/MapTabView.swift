//
//  MapTabView.swift
//  donerkebabmap
//

import Combine
import MapKit
import SwiftUI

struct MapTabView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var placesViewModel: PlacesViewModel

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedPlace: DonerPlace?
    @State private var hasFocusedOnUser = false
    /// Last settled camera region; updated when a pan/zoom ends, not per frame.
    @State private var visibleRegion: MKCoordinateRegion?
    /// Pins actually rendered: only those inside the visible region, capped.
    @State private var visiblePlaces: [DonerPlace] = []

    /// Rendering hundreds of annotations made zooming stutter; keep it bounded.
    private static let maxVisiblePins = 60
    /// Show name labels only when zoomed in enough for them not to pile up.
    private static let labelMaxLatitudeDelta = 0.03

    /// Area shown when the map opens (~1 km around the user).
    /// The search radius stays 20 km; this is only the visual zoom.
    private let initialZoomMeters: Double = 1_000

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position) {
                UserAnnotation()

                ForEach(visiblePlaces) { place in
                    Annotation("", coordinate: place.coordinate, anchor: .bottom) {
                        PlaceMapPin(name: place.name, showsLabel: showsLabels) {
                            selectedPlace = place
                        }
                    }
                }
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
                updateVisiblePlaces()
            }
            .onChange(of: placesViewModel.places.count) {
                updateVisiblePlaces()
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .tint(.blue) // keep the user location dot standard blue (not the brand tint)
            .mapControls {
                MapUserLocationButton()
            }

        }
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
        .sheet(item: $selectedPlace) { place in
            PlaceDetailCard(place: place)
        }
        .onAppear {
            if let coordinate = locationManager.userLocation {
                focusMapIfNeeded(on: coordinate)
            }
        }
        .onReceive(locationManager.$userLocation) { coordinate in
            guard let coordinate else { return }
            focusMapIfNeeded(on: coordinate)
        }
    }

    private var showsLabels: Bool {
        (visibleRegion?.span.latitudeDelta ?? 0) < Self.labelMaxLatitudeDelta
    }

    /// Keeps only places inside the visible region (with a small margin),
    /// nearest to the map center first, capped at `maxVisiblePins`.
    private func updateVisiblePlaces() {
        let places = placesViewModel.places
        guard let region = visibleRegion else {
            visiblePlaces = Array(places.prefix(Self.maxVisiblePins))
            return
        }

        let center = region.center
        let latitudeHalf = region.span.latitudeDelta * 0.6
        let longitudeHalf = region.span.longitudeDelta * 0.6

        func squaredDistanceToCenter(_ place: DonerPlace) -> Double {
            let dLat = place.coordinate.latitude - center.latitude
            let dLon = place.coordinate.longitude - center.longitude
            return dLat * dLat + dLon * dLon
        }

        let inView = places.filter {
            abs($0.coordinate.latitude - center.latitude) <= latitudeHalf &&
            abs($0.coordinate.longitude - center.longitude) <= longitudeHalf
        }
        visiblePlaces = Array(
            inView
                .sorted { squaredDistanceToCenter($0) < squaredDistanceToCenter($1) }
                .prefix(Self.maxVisiblePins)
        )
    }

    private var isLocationDenied: Bool {
        locationManager.authorizationStatus == .denied ||
        locationManager.authorizationStatus == .restricted
    }

    private func retrySearch() {
        guard let coordinate = locationManager.userLocation else { return }
        Task { await placesViewModel.refresh(around: coordinate) }
    }

    private func focusMapIfNeeded(on coordinate: CLLocationCoordinate2D) {
        guard !hasFocusedOnUser else { return }
        hasFocusedOnUser = true
        position = .region(
            MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: initialZoomMeters,
                longitudinalMeters: initialZoomMeters
            )
        )
    }
}

private struct PlaceMapPin: View {
    let name: String
    let showsLabel: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                if showsLabel {
                    // Solid background instead of a material: a live blur per
                    // pin was the most expensive part of redrawing while zooming.
                    Text(name)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: 130)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemBackground).opacity(0.92), in: Capsule())
                        .overlay(
                            Capsule().strokeBorder(AppTheme.primary.opacity(0.25), lineWidth: 0.5)
                        )
                }

                Image(uiImage: PinArtwork.image)
                    // The image is padded so its shadow isn't clipped; pull the
                    // padding back in so the pointer tip sits on the coordinate.
                    .padding(.bottom, -PinArtwork.shadowPadding)
            }
        }
        .buttonStyle(.plain)
    }
}

/// The marker is rendered once into a bitmap and reused by every pin, so the
/// map draws a cheap image instead of a live gradient + glyph + shadows per pin.
@MainActor
private enum PinArtwork {
    static let shadowPadding: CGFloat = 6

    static let image: UIImage = {
        let renderer = ImageRenderer(content: MarkerArtwork().padding(shadowPadding))
        renderer.scale = 3
        return renderer.uiImage ?? UIImage()
    }()
}

private struct MarkerArtwork: View {
    var body: some View {
        VStack(spacing: 0) {
            DonerGlyph(meat: Color.white, spit: .white)
                .frame(width: 20, height: 26)
                .frame(width: 34, height: 34)
                .background(AppTheme.brandGradient, in: Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))

            PinPointer()
                .fill(AppTheme.primary)
                .frame(width: 14, height: 9)
                .offset(y: -1)
        }
        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
    }
}

/// Downward tip under the pin that marks the exact location.
private struct PinPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    MapTabView()
        .environmentObject(LocationManager())
        .environmentObject(PlacesViewModel())
        .environmentObject(FavoriteStore())
}
