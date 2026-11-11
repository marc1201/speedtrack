import MapKit
import SwiftUI

/// The map under the speed. It follows the position and zooms with the speed, as `MapZoom`
/// describes. Dragging or pinching the map stops the following, and the button brings it back.
/// Without internet Apple's map shows only areas it loaded before, so the map then draws the
/// built-in overview on top.
struct PositionMap: View {
    /// The newest fix, and its speed in metres per second if it has one.
    let location: CLLocation?
    let speed: Double?

    /// The map has room for a few names only, so only the most important places get one.
    private static let placeLimit = 12
    /// How much more than the screen the overview covers, so its lines are there before they
    /// scroll in.
    private static let overviewMargin = 1.5

    @StateObject private var connectivity = Connectivity()
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var zoom = MapZoom()
    /// Where the map looks. Only the overview needs it, so a change must not redraw the view: a
    /// redraw while the map moves can take the map from the user's fingers.
    @State private var visible = VisibleArea()
    @State private var overviewLines: [OverviewMap.Line] = []
    @State private var overviewPlaces: [OverviewMap.Place] = []

    var body: some View {
        // Panning and zooming only: a map that cannot turn keeps north up.
        Map(position: $camera, interactionModes: [.pan, .zoom]) {
            UserAnnotation()
            ForEach(overviewLines) { line in
                MapPolyline(coordinates: line.points.map(\.coordinate))
                    .stroke(line.kind.color, style: line.kind.stroke)
            }
            ForEach(overviewPlaces) { place in
                Annotation(place.name, coordinate: place.point.coordinate) {
                    Circle()
                        .fill(.secondary)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .onMapCameraChange { context in
            let center = context.region.center
            visible.box = .around(
                GeoPoint(latitude: center.latitude, longitude: center.longitude),
                latitudeSpan: context.region.span.latitudeDelta * Self.overviewMargin,
                longitudeSpan: context.region.span.longitudeDelta * Self.overviewMargin
            )
            showOverview()
        }
        .onChange(of: location, initial: true) { follow() }
        .onChange(of: connectivity.isOffline) {
            follow()
            showOverview()
        }
        // The map's bottom corners hold Apple's logo and legal link, which must stay visible.
        .overlay(alignment: .topLeading) {
            if connectivity.isOffline {
                Text("No internet: built-in map")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                    .padding(8)
            }
        }
        .overlay(alignment: .topTrailing) {
            if camera.positionedByUser {
                Button {
                    camera = .userLocation(fallback: .automatic)
                    follow()
                } label: {
                    Image(systemName: "location.fill")
                        .padding(10)
                        .background(.thinMaterial, in: Circle())
                }
                .padding(8)
                .accessibilityLabel("Follow my position")
            }
        }
        .task {
            // Read the overview now, so a lost signal does not wait for it.
            await Task.detached(priority: .utility) { _ = OverviewMap.bundled }.value
        }
    }

    private func follow() {
        guard !camera.positionedByUser, let location else { return }
        let span = zoom.span(
            speed: speed,
            accuracy: location.horizontalAccuracy,
            offline: connectivity.isOffline
        )
        withAnimation {
            camera = .region(MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: span,
                longitudinalMeters: span
            ))
        }
    }

    /// Online, Apple's map is better than the overview, whose lines would sit beside Apple's. The
    /// lists change only when they must, since every change redraws the map.
    private func showOverview() {
        guard connectivity.isOffline, let box = visible.box else {
            if !overviewLines.isEmpty { overviewLines = [] }
            if !overviewPlaces.isEmpty { overviewPlaces = [] }
            return
        }
        overviewLines = OverviewMap.bundled.lines(in: box)
        overviewPlaces = OverviewMap.bundled.places(in: box, limit: Self.placeLimit)
    }
}

/// Held by reference, so that setting it does not redraw the view.
private final class VisibleArea {
    var box: GeoBox?
}

private extension GeoPoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension OverviewMap.Kind {
    var color: Color {
        switch self {
        case .coastline, .lake: .blue
        case .border: .purple
        case .railway: .brown
        case .road: .orange
        }
    }

    var stroke: StrokeStyle {
        switch self {
        case .coastline, .lake: StrokeStyle(lineWidth: 1.5)
        case .border: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
        case .railway: StrokeStyle(lineWidth: 2, dash: [2, 3])
        case .road: StrokeStyle(lineWidth: 2)
        }
    }
}
