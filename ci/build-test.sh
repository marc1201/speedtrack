#!/usr/bin/env bash
# Compile the app and run the unit tests on a simulator. Needs no Apple account and no secret.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodebuild -version


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
