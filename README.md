# Speedtrack

A small native iOS app that shows how fast the device is moving, using SwiftUI, CoreLocation and
CoreMotion.

## Build

Open `SpeedTrack.xcodeproj` in Xcode 16 or later. Every push to main compiles the app and runs its
tests on GitHub Actions.

## TestFlight

1. In Certificates, Identifiers & Profiles, register the App ID `vc.1201.speedtrack`.
2. In App Store Connect, under Apps, create a new iOS app with that bundle id.

Signing and upload are still being settled. The route must not use an Admin-role API key.
