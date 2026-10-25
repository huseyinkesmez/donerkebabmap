//
//  ListTabView.swift
//  donerkebabmap
//

import CoreLocation
import SwiftUI

struct ListTabView: View {
    @EnvironmentObject private var placesViewModel: PlacesViewModel
    @EnvironmentObject private var favoriteStore: FavoriteStore
    @EnvironmentObject private var locationManager: LocationManager

    @State private var selectedPlace: DonerPlace?

    private var isLocationDenied: Bool {
        locationManager.authorizationStatus == .denied ||
        locationManager.authorizationStatus == .restricted
    }

    var body: some View {
        NavigationStack {
            Group {
                if placesViewModel.places.isEmpty {
                    emptyState
                } else {
                    placesList
                }
            }
            .navigationTitle("Nearby")
            .toolbar {
                if !placesViewModel.places.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 5) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.caption2.weight(.bold))
                            Text("\(placesViewModel.places.count)")
                                .font(.footnote.weight(.semibold))
                                .contentTransition(.numericText())
                        }
                        // Toolbar items already sit on the system material; a tinted
                        // capsule on top looked like a blurry smudge on device.
                        // Native look: no background, neutral color.
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .sheet(item: $selectedPlace) { place in
            PlaceDetailCard(place: place)
        }
    }

    private var placesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(placesViewModel.places) { place in
                    Button {
                        selectedPlace = place
                    } label: {
                        PlaceRow(place: place, isFavorite: favoriteStore.isFavorite(place))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func retrySearch() {
        guard let coordinate = locationManager.userLocation else { return }
        Task { await placesViewModel.refresh(around: coordinate) }
    }

    @ViewBuilder
    private var emptyState: some View {
        if isLocationDenied {
            LocationPermissionView()
        } else if placesViewModel.loadFailed {
            SearchErrorView(retry: retrySearch)
        } else if locationManager.locationTimedOut, locationManager.userLocation == nil {
            LocationUnavailableView(retry: locationManager.retryLocation)
        } else if placesViewModel.isLoading || locationManager.userLocation == nil {
            LoadingView()
        } else {
            ContentUnavailableView(
                "No Places Found",
                systemImage: "fork.knife",
                description: Text("No doner or kebab places were found nearby.")
            )
        }
    }
}

private struct PlaceRow: View {
    let place: DonerPlace
    let isFavorite: Bool

    /// Color by distance: near = blue, shifting to red as it gets farther (~5 km+),
    /// passing through cyan/green/orange in between.
    static func distanceColor(forMeters meters: Double) -> Color {
        let t = min(max(meters / 5000, 0), 1) // 0 km -> 0, 5 km+ -> 1
        let hue = 0.58 * (1 - t)              // 0.58 (blue) -> 0.0 (red)
        return Color(hue: hue, saturation: 0.85, brightness: 0.80)
    }

    var body: some View {
        HStack(spacing: 14) {
            // A soft tint instead of a solid gradient, so a long list of rows
            // doesn't turn into a column of loud red tiles.
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.primaryAccent.opacity(0.12))
                DonerGlyph(meat: AppTheme.primaryAccent, spit: AppTheme.primaryAccent)
                    .frame(width: 22, height: 28)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(place.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }

                if !place.address.isEmpty {
                    Text(place.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                if let distance = place.formattedDistance, let meters = place.distanceInMeters {
                    let color = Self.distanceColor(forMeters: meters)
                    Text(distance)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.15), in: Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ListTabView()
        .environmentObject(PlacesViewModel())
        .environmentObject(FavoriteStore())
        .environmentObject(LocationManager())
}
