#!/usr/bin/env bash
# Archive, sign in the cloud with the App Store Connect API key, upload to TestFlight.
# The key exists only in this job, as a repository secret; it is never on the VPS.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${ASC_KEY_ID:?repository secret ASC_KEY_ID is missing}"
: "${ASC_ISSUER_ID:?repository secret ASC_ISSUER_ID is missing}"
: "${ASC_KEY_P8:?repository secret ASC_KEY_P8 is missing}"
: "${APPLE_TEAM_ID:?repository variable APPLE_TEAM_ID is missing}"

xcodebuild -version
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate --quiet

work="${RUNNER_TEMP:?}"
key="$work/AuthKey_$ASC_KEY_ID.p8"
trap 'rm -f "$key"' EXIT
(umask 077; printf '%s\n' "$ASC_KEY_P8" > "$key")

auth=(
  -allowProvisioningUpdates
  -authenticationKeyPath "$key"
  -authenticationKeyID "$ASC_KEY_ID"
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
)

archive="$work/SpeedTrack.xcarchive"
xcodebuild archive -quiet \
  -project SpeedTrack.xcodeproj \
  -scheme SpeedTrack \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$archive" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  CURRENT_PROJECT_VERSION="${GITHUB_RUN_NUMBER:-1}" \
  "${auth[@]}"

sed "s/__TEAM__/$APPLE_TEAM_ID/" ci/ExportOptions.plist > "$work/ExportOptions.plist"
xcodebuild -exportArchive \
  -archivePath "$archive" \
  -exportPath "$work/export" \
  -exportOptionsPlist "$work/ExportOptions.plist" \
  "${auth[@]}"
