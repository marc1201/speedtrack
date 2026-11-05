#!/usr/bin/env bash
# Compile the app and run the unit tests on a simulator. Needs no Apple account and no secret.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodebuild -version
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate --quiet

simulator="$(ci/pick-simulator.sh)"
xcodebuild test -quiet \
  -project SpeedTrack.xcodeproj \
  -scheme SpeedTrack \
  -destination "id=$simulator" \
  CODE_SIGNING_ALLOWED=NO
