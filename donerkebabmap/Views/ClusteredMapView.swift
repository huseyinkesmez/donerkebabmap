//
//  ClusteredMapView.swift
//  donerkebabmap
//

import MapKit
import SwiftUI
import UIKit

/// `MKMapView` wrapped for SwiftUI. SwiftUI's `Map` has no annotation
/// clustering, so this uses UIKit's map: nearby pins merge into a count bubble
/// when zoomed out, and annotation views are reused, which keeps hundreds of
/// places smooth while zooming.
struct ClusteredMapView: UIViewRepresentable {
    let places: [DonerPlace]
    /// The map centers here once, the first time it becomes non-nil.
    let focusCoordinate: CLLocationCoordinate2D?
    let initialZoomMeters: CLLocationDistance
    /// The place whose detail sheet is open; its pin stays highlighted.
    let selectedPlaceID: UUID?
    let onSelect: (DonerPlace) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsUserTrackingButton = true
        // Keep the user location dot standard blue, not the brand tint.
        mapView.tintColor = .systemBlue

        let configuration = MKStandardMapConfiguration()
        configuration.pointOfInterestFilter = .excludingAll
        mapView.preferredConfiguration = configuration

        mapView.register(
            PlaceAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: PlaceAnnotationView.reuseIdentifier
        )
        mapView.register(
            PlaceClusterView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier
        )
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onSelect = onSelect
        coordinator.sync(places, on: mapView)
        coordinator.syncSelection(selectedPlaceID, on: mapView)

        if !coordinator.hasFocused, let focusCoordinate {
            coordinator.hasFocused = true
            mapView.setRegion(
                MKCoordinateRegion(
                    center: focusCoordinate,
                    latitudinalMeters: initialZoomMeters,
                    longitudinalMeters: initialZoomMeters
                ),
                animated: false
            )
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        /// Below this span (~3 km tall) the map is "zoomed in": every pin and its
        /// name is shown and nothing clusters. Above it, pins cluster and names hide.
        private static let zoomedInMaxLatitudeDelta = 0.03

        var onSelect: (DonerPlace) -> Void
        var hasFocused = false
        private var annotationsByID: [UUID: PlaceAnnotation] = [:]
        private var isZoomedIn = true
        private var selectedID: UUID?
        /// True while we select a pin from code, so it isn't treated as a tap.
        private var isSelectingProgrammatically = false

        init(onSelect: @escaping (DonerPlace) -> Void) {
            self.onSelect = onSelect
        }

        /// Adds/removes only what changed, so SwiftUI updates don't reset the map.
        func sync(_ places: [DonerPlace], on mapView: MKMapView) {
            let newIDs = Set(places.map(\.id))
            guard newIDs != Set(annotationsByID.keys) else { return }

            let stale = annotationsByID.filter { !newIDs.contains($0.key) }
            mapView.removeAnnotations(Array(stale.values))
            stale.keys.forEach { annotationsByID[$0] = nil }

            let added = places
                .filter { annotationsByID[$0.id] == nil }
                .map(PlaceAnnotation.init)
            added.forEach { annotationsByID[$0.place.id] = $0 }
            mapView.addAnnotations(added)
        }

        /// Mirrors the SwiftUI selection onto the map: highlight the pin while its
        /// sheet is open, and clear the highlight once the sheet is dismissed.
        func syncSelection(_ selectedID: UUID?, on mapView: MKMapView) {
            self.selectedID = selectedID
            let selectedPlaces = mapView.selectedAnnotations.compactMap { $0 as? PlaceAnnotation }
            guard let selectedID else {
                selectedPlaces.forEach { mapView.deselectAnnotation($0, animated: true) }
                return
            }
            guard !selectedPlaces.contains(where: { $0.place.id == selectedID }),
                  let annotation = annotationsByID[selectedID] else { return }
            selectProgrammatically(annotation, on: mapView)
        }

        private func selectProgrammatically(_ annotation: PlaceAnnotation, on mapView: MKMapView) {
            isSelectingProgrammatically = true
            mapView.selectAnnotation(annotation, animated: true)
            isSelectingProgrammatically = false
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            switch annotation {
            case let cluster as MKClusterAnnotation:
                return mapView.dequeueReusableAnnotationView(
                    withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier,
                    for: cluster
                )
            case let place as PlaceAnnotation:
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: PlaceAnnotationView.reuseIdentifier,
                    for: place
                )
                (view as? PlaceAnnotationView)?.configure(zoomedIn: isZoomedIn)
                return view
            default:
                return nil // user location: system blue dot
            }
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            if let cluster = annotation as? MKClusterAnnotation {
                mapView.deselectAnnotation(cluster, animated: false)
                // Zoom in until the cluster's members fit on screen.
                mapView.showAnnotations(cluster.memberAnnotations, animated: true)
            } else if let place = annotation as? PlaceAnnotation {
                guard !isSelectingProgrammatically else { return }
                // Stay selected (highlighted) until the detail sheet is closed.
                revealAboveSheet(place.coordinate, on: mapView)
                onSelect(place.place)
            }
        }

        /// The detail sheet covers the lower ~55% of the screen. Pan the map so
        /// the selected pin lands in the upper part, where it stays visible.
        private func revealAboveSheet(_ coordinate: CLLocationCoordinate2D, on mapView: MKMapView) {
            let bounds = mapView.bounds
            let pin = mapView.convert(coordinate, toPointTo: mapView)
            let targetY = bounds.height * 0.25
            let newCenterPoint = CGPoint(x: pin.x, y: pin.y + bounds.midY - targetY)
            let newCenter = mapView.convert(newCenterPoint, toCoordinateFrom: mapView)
            mapView.setCenter(newCenter, animated: true)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let zoomedIn = mapView.region.span.latitudeDelta < Self.zoomedInMaxLatitudeDelta
            guard zoomedIn != isZoomedIn else { return }
            isZoomedIn = zoomedIn

            // Pins hidden inside a cluster have no view to update, so re-add them:
            // every pin gets a fresh view configured for the new zoom mode.
            let annotations = Array(annotationsByID.values)
            mapView.removeAnnotations(annotations)
            mapView.addAnnotations(annotations)
            if let selectedID, let selected = annotationsByID[selectedID] {
                selectProgrammatically(selected, on: mapView)
            }
        }
    }
}

// MARK: - Annotations

final class PlaceAnnotation: NSObject, MKAnnotation {
    let place: DonerPlace

    init(_ place: DonerPlace) {
        self.place = place
    }

    var coordinate: CLLocationCoordinate2D { place.coordinate }
    var title: String? { place.name }
}

/// A single place: the pre-rendered marker plus an optional name label.
final class PlaceAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "place"
    private static let maxLabelWidth: CGFloat = 130

    private let label = CapsuleLabel()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        applyClusteringSettings()
        applyMarkerImage()

        // The label sits outside the view's bounds so it doesn't count toward
        // collisions; only the marker decides when pins cluster.
        clipsToBounds = false
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()
        // MapKit can reset these when it reuses a view (seen on iOS 27: a reused
        // view came back with a nil clusteringIdentifier and required priority,
        // so it stopped clustering). Re-apply them before every display.
        applyClusteringSettings()
        label.text = annotation?.title ?? nil
        accessibilityLabel = label.text
        setNeedsLayout()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        applyClusteringSettings()
        applyMarkerImage()
        updateLabelVisibility()

        guard animated, selected else { return }
        // A short "pop" so the tapped pin is easy to spot.
        transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.5,
            initialSpringVelocity: 0.8
        ) {
            self.transform = .identity
        }
    }

    /// False when zoomed in: every pin is shown on its own, nothing clusters.
    private var clusteringEnabled = true

    func configure(zoomedIn: Bool) {
        clusteringEnabled = !zoomedIn
        labelAllowedByZoom = zoomedIn
        applyClusteringSettings()
        updateLabelVisibility()
    }

    private func applyClusteringSettings() {
        // Show the pin on its own (no clustering, never hidden by collisions) when
        // zoomed in or selected; a selected pin is also drawn on top.
        let standsAlone = isSelected || !clusteringEnabled
        clusteringIdentifier = standsAlone ? nil : "place"
        collisionMode = .circle
        displayPriority = standsAlone ? .required : .defaultHigh
        zPriority = isSelected ? .max : .defaultUnselected
    }

    private func applyMarkerImage() {
        let image = isSelected ? PinArtwork.selectedImage : PinArtwork.image
        self.image = image
        // Put the pointer tip, not the image center, on the coordinate.
        centerOffset = CGPoint(x: 0, y: -(image.size.height / 2 - PinArtwork.shadowPadding))
        setNeedsLayout()
    }

    private var labelAllowedByZoom = true

    /// The selected pin always shows its name, whatever the zoom level.
    private func updateLabelVisibility() {
        label.isHidden = !(labelAllowedByZoom || isSelected)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let fitting = label.sizeThatFits(CGSize(width: Self.maxLabelWidth, height: .greatestFiniteMagnitude))
        let width = min(fitting.width, Self.maxLabelWidth)
        label.frame = CGRect(
            x: (bounds.width - width) / 2,
            y: PinArtwork.shadowPadding - 3 - fitting.height,
            width: width,
            height: fitting.height
        )
    }
}

/// A group of nearby places shown as one bubble with the count.
final class PlaceClusterView: MKAnnotationView {
    private static var imageCache: [Int: UIImage] = [:]

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .circle
        displayPriority = .defaultHigh
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()
        collisionMode = .circle
        displayPriority = .defaultHigh
        guard let cluster = annotation as? MKClusterAnnotation else { return }
        let count = cluster.memberAnnotations.count
        image = Self.image(for: count)
        accessibilityLabel = String(localized: "\(count) places")
    }

    private static func image(for count: Int) -> UIImage {
        if let cached = imageCache[count] { return cached }

        let diameter: CGFloat = count < 10 ? 38 : (count < 100 ? 44 : 50)
        let padding: CGFloat = 5
        let size = CGSize(width: diameter + padding * 2, height: diameter + padding * 2)
        let circle = CGRect(x: padding, y: padding, width: diameter, height: diameter)
        let top = UIColor(AppTheme.secondary)
        let bottom = UIColor(AppTheme.primary)

        let image = UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext

            // Shadow under a solid circle, then the gradient on top.
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.3).cgColor)
            bottom.setFill()
            cg.fillEllipse(in: circle)
            cg.restoreGState()

            cg.saveGState()
            cg.addEllipse(in: circle)
            cg.clip()
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [top.cgColor, bottom.cgColor] as CFArray,
                locations: [0, 1]
            ) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: circle.midX, y: circle.minY),
                    end: CGPoint(x: circle.midX, y: circle.maxY),
                    options: []
                )
            }
            cg.restoreGState()

            UIColor.white.setStroke()
            let ring = UIBezierPath(ovalIn: circle.insetBy(dx: 1.25, dy: 1.25))
            ring.lineWidth = 2.5
            ring.stroke()

            let text = "\(count)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: count < 100 ? 15 : 14, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(x: circle.midX - textSize.width / 2, y: circle.midY - textSize.height / 2),
                withAttributes: attributes
            )
        }

        imageCache[count] = image
        return image
    }
}

/// Name label with padding and a capsule background.
private final class CapsuleLabel: UILabel {
    private let insets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)

    override init(frame: CGRect) {
        super.init(frame: frame)
        font = .systemFont(ofSize: UIFont.preferredFont(forTextStyle: .caption2).pointSize, weight: .semibold)
        textColor = .label
        lineBreakMode = .byTruncatingTail
        numberOfLines = 1
        textAlignment = .center
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.92)
        layer.borderWidth = 0.5
        layer.borderColor = UIColor(AppTheme.primary).withAlphaComponent(0.25).cgColor
        layer.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let horizontal = insets.left + insets.right
        let vertical = insets.top + insets.bottom
        let fitting = super.sizeThatFits(CGSize(width: size.width - horizontal, height: size.height))
        return CGSize(width: fitting.width + horizontal, height: fitting.height + vertical)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}

// MARK: - Marker artwork

/// The marker is rendered once into a bitmap and reused by every pin, so the
/// map draws a cheap image instead of a live gradient + glyph + shadows per pin.
@MainActor
enum PinArtwork {
    static let shadowPadding: CGFloat = 6

    static let image = render(MarkerArtwork(isSelected: false))
    static let selectedImage = render(MarkerArtwork(isSelected: true))

    private static func render(_ marker: MarkerArtwork) -> UIImage {
        let renderer = ImageRenderer(content: marker.padding(shadowPadding))
        renderer.scale = 3
        return renderer.uiImage ?? UIImage()
    }
}

/// Normal: brand gradient with a white glyph. Selected: larger, with inverted
/// colors (white fill, brand glyph and ring) so it stands out from other pins.
private struct MarkerArtwork: View {
    let isSelected: Bool

    var body: some View {
        let circle: CGFloat = isSelected ? 44 : 34
        VStack(spacing: 0) {
            Group {
                if isSelected {
                    DonerGlyph(meat: AppTheme.primary, spit: AppTheme.primary)
                        .frame(width: 26, height: 34)
                        .frame(width: circle, height: circle)
                        .background(Color.white, in: Circle())
                        .overlay(Circle().strokeBorder(AppTheme.primary, lineWidth: 3))
                } else {
                    DonerGlyph(meat: Color.white, spit: .white)
                        .frame(width: 20, height: 26)
                        .frame(width: circle, height: circle)
                        .background(AppTheme.brandGradient, in: Circle())
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                }
            }

            PinPointer()
                .fill(AppTheme.primary)
                .frame(width: isSelected ? 16 : 14, height: isSelected ? 10 : 9)
                .offset(y: -1)
        }
        .shadow(color: .black.opacity(isSelected ? 0.4 : 0.3), radius: isSelected ? 5 : 3, y: 2)
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
