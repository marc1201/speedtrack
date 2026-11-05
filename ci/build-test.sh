#!/usr/bin/env bash
# Compile the app, run the unit tests on a simulator and archive the Release device build, which the
# tests never compile. Needs no Apple account and no secret.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodebuild -version

# Xcode Cloud finds the products it can build with this same command.
xcodebuild -project SpeedTrack.xcodeproj -describeAllArchivableProducts -json

simulator="$(ci/pick-simulator.sh)"
results="${RUNNER_TEMP:?}/SpeedTrack.xcresult"
xcodebuild test -quiet \
  -project SpeedTrack.xcodeproj \
  -scheme SpeedTrack \
  -destination "id=$simulator" \
  -resultBundlePath "$results" \
  CODE_SIGNING_ALLOWED=NO

# -quiet hides the test count, and the qa gate needs it from the log.
xcrun xcresulttool get test-results summary --path "$results"

archive="${RUNNER_TEMP:?}/SpeedTrack.xcarchive"
xcodebuild archive -quiet \
  -project SpeedTrack.xcodeproj \
  -scheme SpeedTrack \
  -destination generic/platform=iOS \
  -archivePath "$archive" \
  CODE_SIGNING_ALLOWED=NO

# Without this file in the app, App Store Connect can refuse the build for using UserDefaults.
test -f "$archive/Products/Applications/SpeedTrack.app/PrivacyInfo.xcprivacy"
