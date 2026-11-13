# Speedtrack

A small native iOS app that shows how fast the device is moving and where it is on a map, using
SwiftUI, CoreLocation, CoreMotion, MapKit and [MapLibre Native](https://maplibre.org). Settings
chooses the map: Apple's, built-in outlines made from [Natural Earth](https://www.naturalearthdata.com)
data, which is in the public domain, or OpenStreetMap for countries downloaded once and used
offline. The OpenStreetMap data is © OpenStreetMap contributors, prepared by
[Protomaps](https://protomaps.com). The label font is Noto Sans, under the SIL Open Font License.

## Privacy and support

The app has no account, ads, analytics or tracking, and sends your location nowhere, as its
[privacy policy](PRIVACY.md) explains. Questions and problems go to the [support page](SUPPORT.md).

## Build

Open `SpeedTrack.xcodeproj` in Xcode 16 or later. Every push to main compiles the app, runs its
tests and archives the Release device build on GitHub Actions.

## TestFlight

Xcode Cloud builds, signs and uploads, with no build or signing key on our side. One App Store
Connect key with the Marketing role sets the listing text from `store/listing.json`. A commit to
`main` that changes `release/testflight` starts a release. `CLAUDE.md` has the details.
