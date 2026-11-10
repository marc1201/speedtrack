#!/usr/bin/env python3
"""Builds App/OverviewMap.dat, the built-in map the app draws when Apple's map has no internet.

The data is Natural Earth 5.1.2, which is in the public domain (https://www.naturalearthdata.com),
taken from the GeoJSON files of its official repository. Download them into an empty directory of
their own, then run this script from the repository root. Run it isolated (-I), because the
downloads are untrusted data:

    base=https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson
    for f in ne_10m_coastline ne_10m_admin_0_boundary_lines_land ne_10m_lakes \\
             ne_10m_railroads ne_10m_roads ne_10m_populated_places_simple; do
        curl -fsSL -o "$dir/$f.geojson" "$base/$f.geojson"
    done
    python3 -I -B tools/build-overview-map.py "$dir" App/OverviewMap.dat

Each file must match its SHA-256 below, so the input never changes unnoticed. The script runs only
by hand on the VPS, never in CI or on Apple's machines: the app ships its output as plain data.

File format, version 1. Integers are little-endian. Coordinates are in units of 1/10,000 degree,
about 11 m, which is far finer than the data. Lines come sorted by kind, so the app can cap how many
it draws and keep the more important ones.

    "SPOM", version: UInt8 = 1
    lineCount: UInt32, then for each line:
        kind: UInt8 (1 coastline, 2 border, 3 lake, 4 railway, 5 road)
        pointCount: UInt16, at least 2
        first point: latitude Int32, longitude Int32
        each further point: its change in latitude and longitude from the point before, Int16 each
    placeCount: UInt32, then for each place, the most important first:
        rank: UInt8, 0 for the most important
        latitude Int32, longitude Int32
        nameLength: UInt8, then the name in UTF-8
"""

import hashlib
import json
import math
import struct
import sys
import unicodedata
from pathlib import Path

SOURCES = {
    "ne_10m_coastline": "6f75ae0e0de157b14946e2255eb1f5486d9a13819032e26d4610852d296788f6",
    "ne_10m_admin_0_boundary_lines_land": "74d9c16229c095fde65943a9919e337682f044bcebccb120764f38edf3b70f4a",
    "ne_10m_lakes": "2d036f53dedec578001c5c30c2959ee7d4eebc1306900fa4367c49929ec8f2d9",
    "ne_10m_railroads": "a0962d7866060ae3e24df255f6d662389ac9ba7e0df40cf329c2281190b861e6",
    "ne_10m_roads": "66a0c7b438e92fd124822cc5921cfa11042f48c294ade5e0f03f2c6640fd0248",
    "ne_10m_populated_places_simple": "fd3fa867a320cbd5c5b6bb5bc550afeec2939fb2cef688e508007282a55ac42f",
}

# The app shows the overview at 64 km across or more, where 300 m is about two points on screen.
TOLERANCE_METRES = 300
# Long lines are cut into pieces, so the app can leave out the pieces that are off screen.
MAX_POINTS = 128
UNITS_PER_DEGREE = 10_000
MAX_STEP = 32_767  # the most an Int16 change can hold
METRES_PER_DEGREE = 111_320

# Kind, source file, and which of its features to keep. Railways and roads keep only the larger
# ones: Natural Earth's smaller ones would crowd a map meant for 100 to 900 km/h.
LAYERS = [
    (1, "ne_10m_coastline", lambda p: p.get("featurecla") == "Coastline"),
    (2, "ne_10m_admin_0_boundary_lines_land", lambda p: True),
    (3, "ne_10m_lakes", lambda p: True),
    (4, "ne_10m_railroads", lambda p: p.get("featurecla") == "Railroad" and p.get("scalerank", 99) <= 8),
    (5, "ne_10m_roads", lambda p: p.get("type") in ("Major Highway", "Secondary Highway", "Beltway", "Bypass")),
]
LAKE = 3
PLACES = "ne_10m_populated_places_simple"


def load(directory, name):
    raw = (directory / f"{name}.geojson").read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    if digest != SOURCES[name]:
        sys.exit(f"{name}.geojson has SHA-256 {digest}, not the pinned {SOURCES[name]}")
    return json.loads(raw)["features"]


def parts(geometry):
    """The lines of a feature. A polygon's rings become lines: only outlines are drawn."""
    if not geometry:
        return []
    kind, coordinates = geometry["type"], geometry["coordinates"]
    if kind == "LineString":
        return [coordinates]
    if kind in ("MultiLineString", "Polygon"):
        return coordinates
    if kind == "MultiPolygon":
        return [ring for polygon in coordinates for ring in polygon]
    return []


def join(lines):
    """Joins lines whose ends meet. Natural Earth cuts borders, railways and roads into many short
    lines, and the app draws only so many lines at once."""
    lines = [[tuple(point) for point in line] for line in lines]
    joined = True
    while joined:
        joined = False
        ends = {}
        for index, line in enumerate(lines):
            ends.setdefault(line[0], []).append(index)
            ends.setdefault(line[-1], []).append(index)
        used, result = set(), []
        for index, line in enumerate(lines):
            if index in used:
                continue
            used.add(index)
            while True:
                following = next((other for other in ends.get(line[-1], []) if other not in used), None)
                if following is None:
                    break
                used.add(following)
                other = lines[following]
                line = line + (other[1:] if other[0] == line[-1] else other[-2::-1])
                joined = True
            result.append(line)
        lines = result
    return lines


def simplify(points, tolerance):
    """Douglas-Peucker in metres, on a flat projection around the line's mean latitude."""
    if len(points) < 3:
        return points
    scale = math.cos(math.radians(sum(p[1] for p in points) / len(points)))
    xy = [(p[0] * scale * METRES_PER_DEGREE, p[1] * METRES_PER_DEGREE) for p in points]
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        first, last = stack.pop()
        ax, ay = xy[first]
        dx, dy = xy[last][0] - ax, xy[last][1] - ay
        length = math.hypot(dx, dy)
        farthest, index = -1.0, -1
        for i in range(first + 1, last):
            px, py = xy[i][0] - ax, xy[i][1] - ay
            distance = abs(dy * px - dx * py) / length if length else math.hypot(px, py)
            if distance > farthest:
                farthest, index = distance, i
        if farthest > tolerance:
            keep[index] = True
            stack += [(first, index), (index, last)]
    return [p for p, kept in zip(points, keep) if kept]


def quantize(points):
    """(latitude, longitude) in whole units, without repeats."""
    result = []
    for longitude, latitude in points:
        point = (round(latitude * UNITS_PER_DEGREE), round(longitude * UNITS_PER_DEGREE))
        if not result or result[-1] != point:
            result.append(point)
    return result


def bridge(points):
    """Adds points wherever one step is too long for an Int16 change."""
    result = points[:1]
    for latitude, longitude in points[1:]:
        last_latitude, last_longitude = result[-1]
        steps = math.ceil(max(abs(latitude - last_latitude), abs(longitude - last_longitude)) / MAX_STEP)
        for step in range(1, steps):
            result.append((last_latitude + (latitude - last_latitude) * step // steps,
                           last_longitude + (longitude - last_longitude) * step // steps))
        result.append((latitude, longitude))
    return result


def pieces(points):
    """Cuts a line into pieces of at most MAX_POINTS that share their end points."""
    return [points[start:start + MAX_POINTS] for start in range(0, len(points) - 1, MAX_POINTS - 1)]


def build(directory):
    lines = []
    for kind, name, keep in LAYERS:
        found = [part for feature in load(directory, name) if keep(feature["properties"])
                 for part in parts(feature["geometry"]) if len(part) >= 2]
        # A lake is a closed ring of its own, so only the other kinds are joined.
        for part in found if kind == LAKE else join(found):
            points = bridge(quantize(simplify(part, TOLERANCE_METRES)))
            if len(points) >= 2:
                lines += [(kind, piece) for piece in pieces(points)]
    places = []
    for feature in load(directory, PLACES):
        properties = feature["properties"]
        name = unicodedata.normalize("NFC", properties.get("name") or "").encode()
        if not name or len(name) > 255:
            continue
        longitude, latitude = feature["geometry"]["coordinates"]
        places.append((properties["scalerank"], -(properties.get("pop_max") or 0), name,
                       round(latitude * UNITS_PER_DEGREE), round(longitude * UNITS_PER_DEGREE)))
    places.sort()
    return lines, places


def encode(lines, places):
    out = bytearray(b"SPOM") + struct.pack("<BI", 1, len(lines))
    for kind, points in lines:
        out += struct.pack("<BHii", kind, len(points), *points[0])
        for (latitude, longitude), (next_latitude, next_longitude) in zip(points, points[1:]):
            out += struct.pack("<hh", next_latitude - latitude, next_longitude - longitude)
    out += struct.pack("<I", len(places))
    for rank, _, name, latitude, longitude in places:
        out += struct.pack("<BiiB", rank, latitude, longitude, len(name)) + name
    return bytes(out)


def decode(data):
    """Reads the file back, so a writer bug fails here and not on a phone."""
    assert data[:5] == b"SPOM\x01"
    (count,) = struct.unpack_from("<I", data, 5)
    offset, lines = 9, []
    for _ in range(count):
        kind, length, latitude, longitude = struct.unpack_from("<BHii", data, offset)
        offset += 11
        points = [(latitude, longitude)]
        for _ in range(length - 1):
            step_latitude, step_longitude = struct.unpack_from("<hh", data, offset)
            offset += 4
            latitude, longitude = latitude + step_latitude, longitude + step_longitude
            points.append((latitude, longitude))
        lines.append((kind, points))
    (count,) = struct.unpack_from("<I", data, offset)
    offset += 4
    places = []
    for _ in range(count):
        rank, latitude, longitude, length = struct.unpack_from("<BiiB", data, offset)
        offset += 10
        places.append((rank, data[offset:offset + length], latitude, longitude))
        offset += length
    assert offset == len(data)
    return lines, places


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: build-overview-map.py <directory with the GeoJSON files> <output file>")
    lines, places = build(Path(sys.argv[1]))
    data = encode(lines, places)
    read_lines, read_places = decode(data)
    assert read_lines == lines
    assert read_places == [(rank, name, latitude, longitude) for rank, _, name, latitude, longitude in places]
    Path(sys.argv[2]).write_bytes(data)
    for kind, name, _ in LAYERS:
        chosen = [points for line_kind, points in lines if line_kind == kind]
        print(f"{name}: {len(chosen)} lines, {sum(map(len, chosen))} points")
    print(f"{PLACES}: {len(places)} places")
    print(f"{sys.argv[2]}: {len(data)} bytes")


if __name__ == "__main__":
    main()
