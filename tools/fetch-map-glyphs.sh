#!/usr/bin/env bash
# Fetches the label font of the MapLibre map into App/MapGlyphs: Noto Sans Regular as MapLibre glyph
# files, from Protomaps' basemaps-assets at a pinned commit, each checked against its SHA-256. The
# font is under the SIL Open Font License, whose text ships beside it. Only Latin, Greek, Cyrillic
# and punctuation are kept: MapLibre draws Chinese, Japanese and Korean with the phone's own font.
# Run it by hand from the repository root.
set -euo pipefail

commit=028c18f713baecad011301ff7a69acc39bcc2ae7
base="https://raw.githubusercontent.com/protomaps/basemaps-assets/$commit/fonts"
files=(
  "Noto%20Sans%20Regular/0-255.pbf NotoSans-0-255.pbf 62c6d49b15fa836eb6aa45e259c7ca6762f44b011b09e47776efbe4a6db1b397"
  "Noto%20Sans%20Regular/256-511.pbf NotoSans-256-511.pbf 2eca7561f9f566bcacfda5dd04fb5880baec1328ec0f5484678289a13994de8a"
  "Noto%20Sans%20Regular/512-767.pbf NotoSans-512-767.pbf 6abc80badad0e823e228ab739515be257c8b33bc68bb077dd873030e9b2d143a"
  "Noto%20Sans%20Regular/768-1023.pbf NotoSans-768-1023.pbf 537ccbee79180f4f8b3f6d2bdd27df979260ce1a0358c40d7aa7db505d9b03aa"
  "Noto%20Sans%20Regular/1024-1279.pbf NotoSans-1024-1279.pbf 302231023f7048d9694a7b3f3b737c8bc378f5af0175aed5bb4f2f3b6188919a"
  "Noto%20Sans%20Regular/8192-8447.pbf NotoSans-8192-8447.pbf 8ea977a587352fe31b4159ffdbc9a40be79056f2472017c742ea1e4a931864b9"
  "OFL.txt OFL.txt 7713cfc8e3c36d5ec4aa3d6cffe7500a1b3310f8a86d914b8ea09c2a9dee7c2d"
)

download="$(mktemp -d)"
trap 'rm -rf "$download"' EXIT
for entry in "${files[@]}"; do
  read -r source name sha256 <<<"$entry"
  curl -fsSL -o "$download/$name" "$base/$source"
  echo "$sha256  $download/$name" | sha256sum --check --quiet
done
mkdir -p App/MapGlyphs
cp "$download"/* App/MapGlyphs/
