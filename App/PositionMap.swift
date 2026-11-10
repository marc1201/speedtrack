import MapKit
import SwiftUI

/// The map under the speed. It follows the position and zooms with the speed, as `MapZoom`
/// describes. Dragging or pinching the map stops the following, and the button brings it back.
struct PositionMap: View {
    /// The newest fix, and its speed in metres per second if it has one.
    let location: CLLocation?
    let speed: Double?

    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var zoom = MapZoom()

    var body: some View {
        // Panning and zooming only: a map that cannot turn keeps north up.
        Map(position: $camera, interactionModes: [.pan, .zoom]) {
            UserAnnotation()
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .onChange(of: location, initial: true) { follow() }
        // The map's bottom corners hold Apple's logo and legal link, which must stay visible.
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
    }

    private func follow() {
        guard !camera.positionedByUser, let location else { return }
        let span = zoom.span(speed: speed, accuracy: location.horizontalAccuracy)
        withAnimation {
            camera = .region(MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: span,
                longitudinalMeters: span
            ))
        }
    }
}
