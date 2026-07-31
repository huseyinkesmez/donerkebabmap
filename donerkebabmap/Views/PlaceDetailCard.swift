//
//  PlaceDetailCard.swift
//  donerkebabmap
//

import MapKit
import SwiftUI
import UIKit

struct PlaceDetailCard: View {
    let place: DonerPlace

    @EnvironmentObject private var favoriteStore: FavoriteStore
    @Environment(\.openURL) private var openURL
    @State private var showDirectionsOptions = false
    @State private var transportMode: TransportMode = .driving
    @State private var drivingTime: TimeInterval?
    @State private var walkingTime: TimeInterval?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    mapPreview
                    header
                    transportPicker
                    infoSection

                    if place.phoneNumber != nil || place.website != nil {
                        Divider()
                        contactSection
                    }
                }
                .padding(20)
            }

            footer
        }
        .presentationDetents([.fraction(0.55), .large])
        .presentationDragIndicator(.visible)
        .task(id: place.id) {
            await loadTravelTimes()
        }
        .confirmationDialog(
            "Get Directions",
            isPresented: $showDirectionsOptions,
            titleVisibility: .visible
        ) {
            Button("Apple Maps") {
                DirectionsHelper.openInAppleMaps(place: place, mode: transportMode)
            }
            Button("Google Maps") {
                DirectionsHelper.openInGoogleMaps(place: place, mode: transportMode)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Sections

    private var mapPreview: some View {
        Map(
            initialPosition: .region(
                MKCoordinateRegion(
                    center: place.coordinate,
                    latitudinalMeters: 400,
                    longitudinalMeters: 400
                )
            ),
            interactionModes: []
        ) {
            Annotation("", coordinate: place.coordinate) {
                DonerGlyph(meat: Color.white, spit: .white)
                    .frame(width: 18, height: 24)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.brandGradient, in: Circle())
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .allowsHitTesting(false)
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.brandGradient)
                DonerGlyph(meat: Color.white, spit: .white)
                    .frame(width: 26, height: 33)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 6) {
                Text(place.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .lineLimit(2)

                if let rating = place.rating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", rating))
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }

                if let category = place.categoryName {
                    Text(category)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.primary.opacity(0.12), in: Capsule())
                }
            }
        }
    }

    private var transportPicker: some View {
        Picker("Transport mode", selection: $transportMode) {
            ForEach(TransportMode.allCases) { mode in
                Label(mode.titleKey, systemImage: mode.icon).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if place.formattedDistance != nil || selectedTravelTime != nil {
                InfoRow(icon: "location.fill") {
                    HStack(spacing: 8) {
                        if let distance = place.formattedDistance {
                            Text(distance)
                        }
                        if let selectedTravelTime {
                            if place.formattedDistance != nil {
                                Text("•").foregroundStyle(.secondary)
                            }
                            Label(formattedDuration(selectedTravelTime), systemImage: transportMode.icon)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !place.address.isEmpty {
                InfoRow(icon: "mappin.and.ellipse") {
                    Text(place.address)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let phone = place.phoneNumber {
                ContactRow(icon: "phone.fill", text: phone) {
                    callPhone(phone)
                }
            }
            if let website = place.website {
                ContactRow(icon: "globe", text: website.host() ?? "Website") {
                    openURL(website)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                let isFavorite = favoriteStore.isFavorite(place)
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.headline)
                        .frame(width: 52, height: 50)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(isFavorite ? .red : .gray)
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")

                Button {
                    showDirectionsOptions = true
                } label: {
                    Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(AppTheme.primary)

                if let shareURL = place.shareURL {
                    ShareLink(item: shareURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.headline)
                            .frame(width: 52, height: 50)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(AppTheme.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.bar)
    }

    // MARK: - Helpers

    private var selectedTravelTime: TimeInterval? {
        switch transportMode {
        case .driving: drivingTime
        case .walking: walkingTime
        }
    }

    private func toggleFavorite() {
        favoriteStore.toggle(place)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func callPhone(_ phone: String) {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard let url = URL(string: "tel://\(digits)") else { return }
        openURL(url)
    }

    private func loadTravelTimes() async {
        async let driving = estimatedTime(for: .automobile)
        async let walking = estimatedTime(for: .walking)
        drivingTime = await driving
        walkingTime = await walking
    }

    private func estimatedTime(for type: MKDirectionsTransportType) async -> TimeInterval? {
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = place.mapItem
        request.transportType = type
        return try? await MKDirections(request: request).calculateETA().expectedTravelTime
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: max(interval, 60)) ?? ""
    }
}

// MARK: - Row helpers

private struct InfoRow<Content: View>: View {
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(AppTheme.primary)
                .frame(width: 22)
            content
                .font(.subheadline)
            Spacer(minLength: 0)
        }
    }
}

private struct ContactRow: View {
    let icon: String
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 22)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PlaceDetailCard(
        place: DonerPlace(
            id: UUID(),
            name: "Ornek Doner",
            coordinate: .init(latitude: 41.0, longitude: 29.0),
            address: "Ornek Mahalle, Istanbul",
            distanceInMeters: 1450,
            rating: 4.3,
            mapItem: MKMapItem()
        )
    )
    .environmentObject(FavoriteStore())
}
