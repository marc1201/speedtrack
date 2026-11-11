import CoreLocation
import SwiftUI

// What Apple's map and the MapLibre map share on screen.

extension GeoPoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// A short note at the top of the map.
struct MapCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
            .padding(8)
    }
}

/// Shown once the user has moved the map, to make it follow the position again.
struct FollowButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "location.fill")
                .padding(10)
                .background(.thinMaterial, in: Circle())
        }
        .padding(8)
        .accessibilityLabel("Follow my position")
    }
}
