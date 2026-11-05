# Speedtrack

A small native iOS app that shows how fast the device is moving, using SwiftUI and CoreLocation.

## Build

The Xcode project is generated from `project.yml`:

    brew install xcodegen
    xcodegen generate
    open SpeedTrack.xcodeproj

Every push to main compiles the app and runs its tests on GitHub Actions.

## TestFlight, set up once

1. In Certificates, Identifiers & Profiles, register the App ID `vc.1201.speedtrack`.
2. In App Store Connect, under Apps, create a new iOS app with that bundle id.
3. In App Store Connect, under Users and Access, then Integrations, generate a team API key with
   the Admin role and download the `.p8` file.
4. In this repository's Actions settings, add the secrets `ASC_KEY_ID`, `ASC_ISSUER_ID` and
   `ASC_KEY_P8` (the file's contents), and the variable `APPLE_TEAM_ID`.

Then Actions, ios, Run workflow builds, signs and uploads one build.
