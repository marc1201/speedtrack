#!/usr/bin/env bash
# Fetches what the MapLibre map ships besides code, each part pinned by SHA-256:
# - The label font, Noto Sans Regular as all 256 MapLibre glyph ranges, from Protomaps'
#   basemaps-assets at a pinned commit, into App/MapGlyphs. MapLibre stops drawing a whole tile
#   while one of its labels waits for a range it cannot load, so every range ships, though most hold
#   no glyphs. Chinese, Japanese and Korean MapLibre draws with the phone's own font. The font's
#   licence, the SIL Open Font License, ships beside it.
# - MapLibre Native's licence, whose notice must ship with the app, into App/Licences.
# Run it by hand from the repository root.
set -euo pipefail

glyphs=https://raw.githubusercontent.com/protomaps/basemaps-assets/028c18f713baecad011301ff7a69acc39bcc2ae7/fonts
# Of `sha256sum` over the 256 range files, sorted by name.
glyphs_sha256=d27cd5003c67b67e1c244f47eca95ee96ede1a02b100dcc06f8b9d00a03f5a48
ofl_sha256=7713cfc8e3c36d5ec4aa3d6cffe7500a1b3310f8a86d914b8ea09c2a9dee7c2d
licence=https://raw.githubusercontent.com/maplibre/maplibre-native/ios-v7.0.0/platform/ios/LICENSE.md
licence_sha256=88adc1c42d7b0656580d8f42d81fc0f6ec1ab12417b68c7d3a20598d9bbcea19

download="$(mktemp -d)"
trap 'rm -rf "$download"' EXIT
mkdir "$download/glyphs"
for start in $(seq 0 256 65280); do
  range="$start-$((start + 255))"
  curl -fsSL -o "$download/glyphs/NotoSans-$range.pbf" "$glyphs/Noto%20Sans%20Regular/$range.pbf"
done
actual="$(cd "$download/glyphs" && sha256sum NotoSans-*.pbf | LC_ALL=C sort -k2 | sha256sum | cut -d' ' -f1)"
[ "$actual" = "$glyphs_sha256" ] || { echo "the glyph files do not match their pin" >&2; exit 1; }
curl -fsSL -o "$download/glyphs/OFL.txt" "$glyphs/OFL.txt"
echo "$ofl_sha256  $download/glyphs/OFL.txt" | sha256sum --check --quiet
curl -fsSL -o "$download/MapLibreLicense.txt" "$licence"
echo "$licence_sha256  $download/MapLibreLicense.txt" | sha256sum --check --quiet

rm -rf App/MapGlyphs
mkdir -p App/MapGlyphs App/Licences
cp "$download"/glyphs/* App/MapGlyphs/
cp "$download/MapLibreLicense.txt" App/Licences/
