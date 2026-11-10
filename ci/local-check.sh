#!/usr/bin/env bash
# The fast loop on the VPS, before a push spends a compile on Actions. A Linux Swift toolchain
# cannot see SwiftUI, CoreLocation or CoreMotion, so this parses every Swift file and runs the tests
# of the pure logic only. Actions stays the compiler that counts. Run it capped (see CLAUDE.md).
set -euo pipefail
cd "$(dirname "$0")/.."

swift_home="$HOME/.local/share/swift"
bin="$swift_home/swift-6.4.2-RELEASE-ubuntu26.04/usr/bin"
[ -x "$bin/swiftc" ] || { echo "no Swift toolchain in $swift_home" >&2; exit 1; }

for file in App/*.swift Tests/*.swift; do
  "$bin/swiftc" -frontend -parse "$file"
done

package="$(mktemp -d)"
trap 'rm -rf "$package"' EXIT
mkdir -p "$package/Sources/SpeedTrack" "$package/Tests/SpeedTrackTests"
cp App/LocationAccess.swift App/MapZoom.swift App/OverviewMap.swift App/SpeedReading.swift \
  App/StillnessDetector.swift "$package/Sources/SpeedTrack/"
cp Tests/*.swift "$package/Tests/SpeedTrackTests/"
cat > "$package/Package.swift" <<'EOF'
// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "SpeedTrack",
    targets: [
        .target(name: "SpeedTrack"),
        .testTarget(name: "SpeedTrackTests", dependencies: ["SpeedTrack"]),
    ]
)
EOF

# The box has no gcc or ld: $swift_home/bin wraps the toolchain's lld, gcc-runtime is libgcc-15-dev
# unpacked without root, and only the native build system passes this environment on to clang.
cd "$package"
PATH="$swift_home/bin:$bin:$PATH" \
  CCC_OVERRIDE_OPTIONS="+--gcc-install-dir=$swift_home/gcc-runtime/usr/lib/gcc/x86_64-linux-gnu/15" \
  CCC_QUIET=1 \
  "$bin/swift" test --build-system native
