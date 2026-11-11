import CoreLocation
import MapLibre
import SwiftUI

/// The outlines and OpenStreetMap maps, which MapLibre draws from data on the phone alone. Like
/// Apple's map in `PositionMap`, it follows the position and zooms with the speed, as `MapZoom`
/// describes. Dragging or pinching the map stops the following, and the button brings it back.
struct LibreMap: View {
    /// The newest fix, and its speed in metres per second if it has one.
    let location: CLLocation?
    let speed: Double?
    /// The downloaded countries to draw over the outlines, or nil for the outlines alone.
    let countries: [URL]?

    @State private var following = true

    var body: some View {
        LibreMapView(
            location: location,
            speed: speed,
            countries: countries ?? [],
            outlinesOnly: countries == nil,
            following: $following
        )
        // MapLibre's (i) button in the bottom right lists every credit. OpenStreetMap's licence also
        // asks for one that can be seen on the map itself.
        .overlay(alignment: .bottomLeading) {
            if countries?.isEmpty == false {
                Link("© OpenStreetMap", destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.thinMaterial, in: Capsule())
                    .padding(6)
            }
        }
        .overlay(alignment: .topLeading) {
            if countries?.isEmpty == true {
                MapCaption(text: "No country downloaded: see Settings")
            }
        }
        .overlay(alignment: .topTrailing) {
            if !following {
                FollowButton { following = true }
            }
        }
        .task {
            // Read the outlines now, so the first view of the map does not wait for them.
            await Task.detached(priority: .utility) { _ = OverviewMap.bundled }.value
        }
    }
}

private struct LibreMapView: UIViewRepresentable {
    let location: CLLocation?
    let speed: Double?
    let countries: [URL]
    let outlinesOnly: Bool
    @Binding var following: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MLNMapView {
        let view = MLNMapView(frame: .zero, styleURL: context.coordinator.style(for: countries))
        view.delegate = context.coordinator
        // A map that cannot turn keeps north up, like Apple's.
        view.allowsRotating = false
        view.allowsTilting = false
        view.compassView.isHidden = true
        view.logoView.isHidden = true
        return view
    }

    func updateUIView(_ view: MLNMapView, context: Context) {
        context.coordinator.following = $following
        context.coordinator.update(
            view,
            location: location,
            speed: speed,
            countries: countries,
            outlinesOnly: outlinesOnly,
            following: following
        )
    }

    @MainActor
    final class Coordinator: NSObject, MLNMapViewDelegate {
        var following: Binding<Bool> = .constant(true)
        private var zoom = MapZoom()
        private var countries: [URL] = []
        private var styleFile: URL?
        private var location: CLLocation?
        private var speed: Double?
        private var outlinesOnly = true
        private var shownPosition: CLLocation?
        /// The fix the camera last moved to. Nil while the map does not follow, so it moves at once
        /// when it follows again.
        private var followed: CLLocation?

        /// The label font: the app's glyph files, wherever the build put them in the app.
        private static let glyphs: String = {
            let folder = Bundle.main.url(forResource: "NotoSans-0-255", withExtension: "pbf")?
                .deletingLastPathComponent() ?? Bundle.main.bundleURL
            return folder.absoluteString + "NotoSans-{range}.pbf"
        }()

        /// MapLibre takes a style from a file, so this writes one for these countries.
        func style(for countries: [URL]) -> URL {
            self.countries = countries
            if let styleFile {
                try? FileManager.default.removeItem(at: styleFile)
            }
            let file = FileManager.default.temporaryDirectory.appending(path: "map-style-\(UUID().uuidString).json")
            let json = LibreStyle.json(glyphs: Self.glyphs, countries: countries)
            try? JSONSerialization.data(withJSONObject: json).write(to: file)
            styleFile = file
            return file
        }

        func update(
            _ view: MLNMapView,
            location: CLLocation?,
            speed: Double?,
            countries: [URL],
            outlinesOnly: Bool,
            following: Bool
        ) {
            if countries != self.countries {
                view.styleURL = style(for: countries)
            }
            self.location = location
            self.speed = speed
            self.outlinesOnly = outlinesOnly
            showPosition(in: view)
            guard following else {
                followed = nil
                return
            }
            follow(in: view)
        }

        /// Moves the map to a fix it has not shown yet. A map not laid out yet has no size to fit the
        /// span to, so it waits: MapLibre reports the first layout as a change of region.
        private func follow(in view: MLNMapView) {
            let side = Double(min(view.bounds.width, view.bounds.height))
            guard following.wrappedValue, let location, location !== followed, side > 0 else { return }
            followed = location
            // The outlines are drawn for wide views, as they are on Apple's map without internet.
            let span = zoom.span(speed: speed, accuracy: location.horizontalAccuracy, offline: outlinesOnly)
            let level = MapZoom.zoomLevel(span: span, latitude: location.coordinate.latitude, points: side)
            view.setCenter(location.coordinate, zoomLevel: level, animated: true)
        }

        private func showPosition(in view: MLNMapView) {
            guard location !== shownPosition,
                  let source = view.style?.source(withIdentifier: LibreStyle.positionSource) as? MLNShapeSource
            else { return }
            shownPosition = location
            guard let location else {
                source.shape = nil
                return
            }
            let point = MLNPointFeature()
            point.coordinate = location.coordinate
            source.shape = point
        }

        /// The outlines in and around the view, as Apple's map draws them without internet.
        private func showOutlines(in view: MLNMapView) {
            guard let style = view.style,
                  let lines = style.source(withIdentifier: LibreStyle.outlineSource) as? MLNShapeSource,
                  let places = style.source(withIdentifier: LibreStyle.outlinePlaceSource) as? MLNShapeSource
            else { return }
            let bounds = view.visibleCoordinateBounds
            let longitudeSpan = bounds.ne.longitude - bounds.sw.longitude
            let box = GeoBox.around(
                GeoPoint(latitude: view.centerCoordinate.latitude, longitude: view.centerCoordinate.longitude),
                latitudeSpan: (bounds.ne.latitude - bounds.sw.latitude) * OverviewMap.margin,
                longitudeSpan: (longitudeSpan < 0 ? longitudeSpan + 360 : longitudeSpan) * OverviewMap.margin
            )
            let overview = OverviewMap.bundled
            let lineFeatures: [MLNShape & MLNFeature] = overview.lines(in: box, limit: .max).map { line in
                let coordinates = line.points.map(\.coordinate)
                let feature = MLNPolylineFeature(coordinates: coordinates, count: UInt(coordinates.count))
                feature.attributes = ["kind": Int(line.kind.rawValue)]
                return feature
            }
            lines.shape = MLNShapeCollectionFeature(shapes: lineFeatures)
            let placeFeatures: [MLNShape & MLNFeature] = overview.places(in: box, limit: OverviewMap.placeLimit).map { place in
                let feature = MLNPointFeature()
                feature.coordinate = place.point.coordinate
                feature.attributes = ["name": place.name]
                return feature
            }
            places.shape = MLNShapeCollectionFeature(shapes: placeFeatures)
        }

        nonisolated func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            MainActor.assumeIsolated {
                shownPosition = nil
                showPosition(in: mapView)
                showOutlines(in: mapView)
            }
        }

        nonisolated func mapView(_ mapView: MLNMapView, regionWillChangeWith reason: MLNCameraChangeReason, animated: Bool) {
            let gestures: MLNCameraChangeReason = [
                .gesturePan, .gesturePinch, .gestureRotate, .gestureZoomIn, .gestureZoomOut,
                .gestureOneFingerZoom, .gestureTilt,
            ]
            guard !reason.isDisjoint(with: gestures) else { return }
            MainActor.assumeIsolated {
                following.wrappedValue = false
            }
        }

        nonisolated func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            MainActor.assumeIsolated {
                showOutlines(in: mapView)
                // Outside this callback, which can come from inside a layout pass.
                if followed == nil {
                    DispatchQueue.main.async { [weak self, weak mapView] in
                        MainActor.assumeIsolated {
                            guard let self, let mapView else { return }
                            self.follow(in: mapView)
                        }
                    }
                }
            }
        }
    }
}
