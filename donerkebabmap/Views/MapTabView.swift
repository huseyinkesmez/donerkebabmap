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

    /// Açılışta haritanın gösterdiği alan (kullanıcı etrafında ~1 km).
    /// Arama yarıçapı 20 km'de kalır; bu yalnızca görsel zoom.
    private let initialZoomMeters: Double = 1_000

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position) {
                UserAnnotation()

                ForEach(placesViewModel.places) { place in
                    Annotation("", coordinate: place.coordinate, anchor: .bottom) {
                        PlaceMapPin(name: place.name) {
                            selectedPlace = place
                        }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .tint(.blue) // kullanıcı konum noktası standart mavi kalsın (marka tint'i değil)
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
            } else if placesViewModel.isLoading && placesViewModel.places.isEmpty {
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
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text(name)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: 130)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(AppTheme.primary.opacity(0.25), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 1)

                marker
            }
        }
        .buttonStyle(.plain)
    }

    private var marker: some View {
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

/// Pinin altındaki, konuma denk gelen aşağı sivri uç.
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
