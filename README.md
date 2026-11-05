# Speedtrack

A small native iOS app that shows how fast the device is moving, using SwiftUI, CoreLocation and
CoreMotion.

## Build

Open `SpeedTrack.xcodeproj` in Xcode 16 or later. Every push to main compiles the app, runs its
tests and archives the Release device build on GitHub Actions.

## TestFlight

Xcode Cloud builds, signs and uploads, with no key on our side. A commit to `main` that changes
`release/testflight` starts a release. `CLAUDE.md` has the details.
