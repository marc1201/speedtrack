#!/usr/bin/env bash
# Compile the app, run the unit tests on a simulator and archive the Release device build, which the
# tests never compile. Needs no Apple account and no secret.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodebuild -version

# Xcode Cloud takes packages only as the committed Package.resolved pins them, and so does every
# command here.
xcodebuild -resolvePackageDependencies -project SpeedTrack.xcodeproj -scheme SpeedTrack \
  -disableAutomaticPackageResolution

# Xcode Cloud finds the products it can build with this same command.
xcodebuild -project SpeedTrack.xcodeproj -describeAllArchivableProducts -json \
  -disableAutomaticPackageResolution

simulator="$(ci/pick-simulator.sh)"
results="${RUNNER_TEMP:?}/SpeedTrack.xcresult"
xcodebuild test -quiet \
  -project SpeedTrack.xcodeproj \
  -scheme SpeedTrack \
  -destination "id=$simulator" \
  -resultBundlePath "$results" \
  -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=NO

# -quiet hides the test count, and the qa gate needs it from the log.
xcrun xcresulttool get test-results summary --path "$results"

archive="${RUNNER_TEMP:?}/SpeedTrack.xcarchive"
xcodebuild archive -quiet \
  -project SpeedTrack.xcodeproj \
  -scheme SpeedTrack \
  -destination generic/platform=iOS \
  -archivePath "$archive" \
  -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=NO
app="$archive/Products/Applications/SpeedTrack.app"

# Without this file in the app, App Store Connect can refuse the build for using UserDefaults.
test -f "$app/PrivacyInfo.xcprivacy"

# Without these files a map would be empty or have no names, and the app would not say so: the
# outlines, the list of countries, MapLibre itself and its label font.
test -f "$app/OverviewMap.dat"
test -f "$app/CountryMaps.json"
test -x "$app/Frameworks/MapLibre.framework/MapLibre"
test -n "$(find "$app" -name 'NotoSans-0-255.pbf' -print -quit)"
