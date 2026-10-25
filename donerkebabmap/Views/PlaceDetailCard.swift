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
    @State private var detent: PresentationDetent = .fraction(0.55)

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
        .presentationDetents(detents, selection: $detent)
        .presentationDragIndicator(.visible)
        // At the medium height, keep the content behind usable and undimmed, so
        // the highlighted pin stays visible and another pin can be tapped.
        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.55)))
        // Without an explicit background the sheet stays translucent and
        // blends with the map behind it; use the opaque system background.
        .presentationBackground(Color(.systemBackground))
        .onAppear { detent = defaultDetent }
        .task(id: place.id) {
            await loadTravelTimes()
        }
        // While the sheet is open, tapping another pin swaps the place in the
        // same sheet. Reset per-place state so nothing from the previous place
        // lingers, and go back to the medium height.
        .onChange(of: place.id) {
            drivingEstimate = nil
            walkingEstimate = nil
            detent = defaultDetent
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

    /// On iPad (regular width) the sheet is a fixed-size centered box, so a
    /// fractional detent squashes the content; use full height there.
    private var detents: Set<PresentationDetent> {
        isRegularWidth ? [.large] : [.fraction(0.55), .large]
    }

    private var defaultDetent: PresentationDetent {
        isRegularWidth ? .large : .fraction(0.55)
    }

    // MARK: - Sections

    private var mapPreview: some View {
        RoutePreviewMap(
            place: place,
            route: selectedEstimate?.route,
            isWalking: transportMode == .walking
        )
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .allowsHitTesting(false)
        // Start every place from its own camera instead of animating from the last one.
        .id(place.id)
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
                // A segmented picker only renders Text/Image/Label content;
                // wrappers such as ViewThatFits break the segments.
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
                // Size the button itself: sizing the inner frame added up with
                // the .bordered style's own padding and made it bulky.
                .frame(width: 48, height: 50)
                .tint(isFavorite ? .red : .gray)
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")

                Button {
                    showDirectionsOptions = true
                } label: {
                    // On narrow screens / long translations, drop the icon first
                    // and shrink the text if needed, instead of wrapping.
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

    /// Show the route distance when available: the straight-line distance
    /// is noticeably shorter than the real walking/driving distance.
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

        guard let route = try? await MKDirections(request: request).calculate().routes.first else {
            return nil
        }
        return TravelEstimate(
            travelTime: route.expectedTravelTime,
            distanceInMeters: route.distance,
            arrivalDate: Date().addingTimeInterval(route.expectedTravelTime),
            route: route
        )
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: max(interval, 60)) ?? ""
    }
}

/// Values kept from the `calculate()` response: the travel time, the real route
/// distance, the expected arrival time and the route line for the mini map.
private struct TravelEstimate {
    let travelTime: TimeInterval
    let distanceInMeters: CLLocationDistance
    let arrivalDate: Date
    let route: MKRoute
}

/// The small map at the top of the card: the place pin and, once it is known,
/// the route from the user to it (dashed when walking).
private struct RoutePreviewMap: View {
    let place: DonerPlace
    let route: MKRoute?
    let isWalking: Bool

    @State private var position: MapCameraPosition

    init(place: DonerPlace, route: MKRoute?, isWalking: Bool) {
        self.place = place
        self.route = route
        self.isWalking = isWalking
        _position = State(initialValue: Self.cameraPosition(place: place, route: route))
    }

    var body: some View {
        Map(position: $position, interactionModes: []) {
            UserAnnotation()

            if let route {
                MapPolyline(route.polyline)
                    .stroke(
                        AppTheme.primary,
                        style: StrokeStyle(
                            lineWidth: 4,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: isWalking ? [1, 7] : []
                        )
                    )
            }

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
        .tint(.blue)
        .onChange(of: route) {
            withAnimation { position = Self.cameraPosition(place: place, route: route) }
        }
    }

    /// Fits the whole route with some padding (room for the pins); without a
    /// route, a close-up around the place.
    private static func cameraPosition(place: DonerPlace, route: MKRoute?) -> MapCameraPosition {
        guard let route else {
            return .region(MKCoordinateRegion(
                center: place.coordinate,
                latitudinalMeters: 400,
                longitudinalMeters: 400
            ))
        }
        let rect = route.polyline.boundingMapRect
        // Very short routes would zoom in too far; show at least ~300 m.
        let minSize = 300 * MKMapPointsPerMeterAtLatitude(place.coordinate.latitude)
        let padding = max(max(rect.width, rect.height) * 0.25, (minSize - max(rect.width, rect.height)) / 2)
        return .rect(rect.insetBy(dx: -padding, dy: -padding * 1.5))
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
