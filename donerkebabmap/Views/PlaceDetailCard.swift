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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showDirectionsOptions = false
    @State private var transportMode: TransportMode = .driving
    @State private var drivingEstimate: TravelEstimate?
    @State private var walkingEstimate: TravelEstimate?

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
        .frame(
            minWidth: isRegularWidth ? 540 : nil,
            minHeight: isRegularWidth ? 720 : nil
        )
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
        // Acik arka plan verilmezse sheet yari saydam kalip altindaki
        // haritayla karisiyor; opak sistem zemini kullan.
        .presentationBackground(Color(.systemBackground))
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

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    /// iPad'de (regular genişlik) sheet ortada sabit boyutlu bir kutu olarak
    /// açıldığı için kesirli detent içeriği eziyor; orada tam yükseklik kullan.
    private var detents: Set<PresentationDetent> {
        isRegularWidth ? [.large] : [.fraction(0.55), .large]
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
                        .foregroundStyle(AppTheme.primaryAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.primaryAccent.opacity(0.12), in: Capsule())
                }
            }
        }
    }

    private var transportPicker: some View {
        Picker("Transport mode", selection: $transportMode) {
            ForEach(TransportMode.allCases) { mode in
                // Segmented picker yalnizca Text/Image/Label icerigini render
                // eder; ViewThatFits gibi sarmalayicilar segmentleri bozuyor.
                Label(mode.titleKey, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if displayedDistance != nil || selectedEstimate != nil {
                InfoRow(icon: "location.fill") {
                    HStack(spacing: 8) {
                        if let displayedDistance {
                            Text(displayedDistance)
                        }
                        if let estimate = selectedEstimate {
                            if displayedDistance != nil {
                                Text("•").foregroundStyle(.secondary)
                            }
                            Label(formattedDuration(estimate.travelTime), systemImage: transportMode.icon)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let estimate = selectedEstimate {
                InfoRow(icon: "clock.fill") {
                    Text("Arrive by \(estimate.arrivalDate.formatted(date: .omitted, time: .shortened))")
                        .foregroundStyle(.secondary)
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                // Genisligi butonun kendisine veriyoruz: ic cerceveye vermek
                // .bordered stilinin kendi dolgusuyla toplanip sisiriyordu.
                .frame(width: 48, height: 50)
                .tint(isFavorite ? .red : .gray)
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")

                Button {
                    showDirectionsOptions = true
                } label: {
                    // Dar ekranda/uzun çeviride satır kırmak yerine önce ikonu
                    // bırakır, gerekirse metni küçültür.
                    ViewThatFits(in: .horizontal) {
                        Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        Text("Get Directions")
                    }
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(AppTheme.primary)

                if let shareURL = place.shareURL {
                    ShareLink(item: shareURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(width: 48, height: 50)
                    .tint(AppTheme.primaryAccent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.bar)
    }

    // MARK: - Helpers

    private var selectedEstimate: TravelEstimate? {
        switch transportMode {
        case .driving: drivingEstimate
        case .walking: walkingEstimate
        }
    }

    /// Rota mesafesi alinabildiyse onu goster: kus ucusu mesafe gercek
    /// yuruyus/surus mesafesinden belirgin sekilde kisa cikiyor.
    private var displayedDistance: String? {
        if let meters = selectedEstimate?.distanceInMeters {
            return DistanceFormatter.string(fromMeters: meters)
        }
        return place.formattedDistance
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
        async let driving = estimate(for: .automobile)
        async let walking = estimate(for: .walking)
        drivingEstimate = await driving
        walkingEstimate = await walking
    }

    private func estimate(for type: MKDirectionsTransportType) async -> TravelEstimate? {
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = place.mapItem
        request.transportType = type

        guard let response = try? await MKDirections(request: request).calculateETA() else {
            return nil
        }
        return TravelEstimate(
            travelTime: response.expectedTravelTime,
            distanceInMeters: response.distance,
            arrivalDate: response.expectedArrivalDate
        )
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: max(interval, 60)) ?? ""
    }
}

/// `calculateETA()` yanıtından tutulan bilgiler. Aynı çağrı hem süreyi hem
/// gerçek rota mesafesini hem de tahmini varış saatini döndürüyor.
private struct TravelEstimate {
    let travelTime: TimeInterval
    let distanceInMeters: CLLocationDistance
    let arrivalDate: Date
}

// MARK: - Row helpers

private struct InfoRow<Content: View>: View {
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(AppTheme.primaryAccent)
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
                    .foregroundStyle(AppTheme.primaryAccent)
                    .frame(width: 22)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.primaryAccent)
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
