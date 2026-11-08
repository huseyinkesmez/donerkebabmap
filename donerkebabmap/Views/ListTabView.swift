//
//  ListTabView.swift
//  donerkebabmap
//

import CoreLocation
import SwiftUI

private enum ListFilter: CaseIterable, Identifiable {
    case nearby, favorites

    var id: Self { self }

    var titleKey: LocalizedStringKey {
        switch self {
        case .nearby: "Nearby"
        case .favorites: "Favorites"
        }
    }
}

struct ListTabView: View {
    @EnvironmentObject private var placesViewModel: PlacesViewModel
    @EnvironmentObject private var favoriteStore: FavoriteStore
    @EnvironmentObject private var locationManager: LocationManager

    @State private var selectedPlace: DonerPlace?
    @State private var filter: ListFilter = .nearby
    @State private var searchText = ""

    /// "Nearby" keeps to the distance of the search around the user, so areas
    /// searched with "Search This Area" don't mix into it.
    private var filteredPlaces: [DonerPlace] {
        let places: [DonerPlace]
        switch filter {
        case .nearby:
            places = placesViewModel.places.filter {
                ($0.distanceInMeters ?? 0) <= placesViewModel.searchRadius
            }
        case .favorites:
            places = favoriteStore.places(
                matching: placesViewModel.places,
                userLocation: locationManager.userLocation
            )
        }

        let query = Self.searchable(searchText.trimmingCharacters(in: .whitespaces))
        guard !query.isEmpty else { return places }
        return places.filter {
            Self.searchable($0.name).contains(query) || Self.searchable($0.address).contains(query)
        }
    }

    /// Lets people type without Turkish characters: "tadim" finds "Tadım".
    private static func searchable(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: "ı", with: "i")
    }

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
                    filteredContent
                }
            }
            .navigationTitle("Places")
            .toolbar {
                if !placesViewModel.places.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 5) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.caption2.weight(.bold))
                            Text("\(filteredPlaces.count)")
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

    private var filteredContent: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $filter) {
                ForEach(ListFilter.allCases) { filter in
                    Text(filter.titleKey).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if filteredPlaces.isEmpty {
                noResults
                    .frame(maxHeight: .infinity)
            } else {
                placesList
            }
        }
        .background(Color(.systemGroupedBackground))
        .searchable(text: $searchText, prompt: "Search places")
    }

    @ViewBuilder
    private var noResults: some View {
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else if filter == .favorites {
            ContentUnavailableView(
                "No Favorites",
                systemImage: "heart",
                description: Text("You haven't added any favorites yet.")
            )
        } else {
            ContentUnavailableView(
                "No Places Found",
                systemImage: "fork.knife",
                description: Text("No doner or kebab places were found nearby.")
            )
        }
    }

    private var placesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredPlaces) { place in
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)

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
                if let distance = place.formattedDistance {
                    Text(distance)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemFill), in: Capsule())
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
