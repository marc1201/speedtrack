#!/usr/bin/env python3
"""Cuts one country out of Protomaps' daily OpenStreetMap build, for the app's OpenStreetMap map.

Protomaps publishes a basemap of the whole planet every day as one PMTiles archive, whose data is
© OpenStreetMap contributors under the ODbL (https://docs.protomaps.com/basemaps/downloads). This
script reads the archive's directories and the tiles of one country up to zoom 12 with HTTP range
requests, and writes them as a PMTiles archive of their own. Run it isolated (-I), because the
archive is untrusted data, and capped, from the repository root:

    systemd-run --user --scope -q -p MemoryMax=300M -p MemorySwapMax=0 -- \\
        python3 -I -B tools/extract-country-map.py jp 20261110 build/maps

That writes build/maps/jp-z12-20261110.pmtiles and prints its size and SHA-256, which go into
App/CountryMaps.json. --dry-run prints the size from the directories alone. The script runs only
by hand on the VPS, never in CI or on Apple's machines. The app downloads its output as data and
checks it against the SHA-256 in App/CountryMaps.json.

The format is PMTiles version 3: https://github.com/protomaps/PMTiles/blob/main/spec/v3/spec.md
"""

import gzip
import hashlib
import http.client
import itertools
import math
import mmap
import os
import re
import struct
import sys
from bisect import bisect_right
from pathlib import Path

SOURCE_HOST = "build.protomaps.com"
MAX_ZOOM = 12

# Boxes of west, south, east and north in degrees, wide enough that no coast is cut.
COUNTRIES = {
    "jp": [(128.5, 30.0, 135.5, 36.5), (135.0, 32.4, 142.2, 41.6), (139.3, 41.3, 146.0, 45.6),
           (122.8, 24.0, 131.5, 30.0)],
    "kr": [(124.5, 33.0, 131.9, 38.7)],
    "pt": [(-9.6, 36.9, -6.1, 42.2), (-17.4, 32.3, -16.2, 33.2), (-31.4, 36.8, -24.9, 39.8)],
    "de": [(5.8, 47.2, 15.1, 55.1)],
}
# A tile of the capital at zoom 8 must name it, or the tiles were read from the wrong place.
PROBES = {
    "jp": (35.6812, 139.7671, [b"Tokyo", "東京".encode()]),
    "kr": (37.5665, 126.9780, [b"Seoul", "서울".encode()]),
    "pt": (38.7223, -9.1393, [b"Lisboa", b"Lisbon"]),
    "de": (52.5200, 13.4050, [b"Berlin"]),
}

HEADER = struct.Struct("<7sB11Q6B4iB2i")
FIELDS = ("magic version root_offset root_length metadata_offset metadata_length leaf_offset "
          "leaf_length data_offset data_length addressed_tiles tile_entries tile_contents clustered "
          "internal_compression tile_compression tile_type min_zoom max_zoom min_lon min_lat max_lon "
          "max_lat center_zoom center_lon center_lat").split()
FIRST_BYTES = 16_384  # the header and the root directory must fit in these
GZIP, MVT = 2, 1
MAX_GAP = 256 * 1024  # bytes between two tiles that are cheaper to read along than to skip
MAX_RANGE = 16 * 1024 * 1024


def tile_id(z, x, y):
    """The tile's place on the Hilbert curve, after all tiles of lower zooms."""
    n = 1 << z
    distance, s = 0, n >> 1
    while s:
        rx, ry = int(x & s > 0), int(y & s > 0)
        distance += s * s * ((3 * rx) ^ ry)
        if ry == 0:
            if rx == 1:
                x, y = n - 1 - x, n - 1 - y
            x, y = y, x
        s >>= 1
    return ((1 << 2 * z) - 1) // 3 + distance


def tile_xy(z, longitude, latitude):
    n = 1 << z
    latitude = max(min(latitude, 85.0511), -85.0511)
    x = int((longitude + 180) / 360 * n)
    y = int((1 - math.asinh(math.tan(math.radians(latitude))) / math.pi) / 2 * n)
    return min(max(x, 0), n - 1), min(max(y, 0), n - 1)


def wanted_tiles(boxes):
    tiles = set()
    for west, south, east, north in boxes:
        for z in range(MAX_ZOOM + 1):
            x0, y0 = tile_xy(z, west, north)
            x1, y1 = tile_xy(z, east, south)
            tiles.update(tile_id(z, x, y) for x in range(x0, x1 + 1) for y in range(y0, y1 + 1))
    return sorted(tiles)


def read_varint(data, position):
    value = shift = 0
    while True:
        byte = data[position]
        position += 1
        value |= (byte & 0x7F) << shift
        if byte < 0x80:
            return value, position
        shift += 7
        if shift > 63:
            raise ValueError("varint too long")


def write_varint(out, value):
    while value >= 0x80:
        out.append(value & 0x7F | 0x80)
        value >>= 7
    out.append(value)


def decode_directory(raw):
    """Entries of (tile id, offset, length, run length). A run length of 0 points to a leaf."""
    data = gzip.decompress(raw)
    count, position = read_varint(data, 0)
    columns = []
    for _ in range(4):
        column = []
        for _ in range(count):
            value, position = read_varint(data, position)
            column.append(value)
        columns.append(column)
    if position != len(data):
        raise ValueError("directory has trailing bytes")
    deltas, runs, lengths, coded = columns
    ids, offsets = list(itertools.accumulate(deltas)), []
    for i, value in enumerate(coded):
        if value == 0 and i > 0:
            offsets.append(offsets[-1] + lengths[i - 1])
        elif value > 0:
            offsets.append(value - 1)
        else:
            raise ValueError("first offset cannot continue the one before")
    return ids, offsets, lengths, runs


def encode_directory(entries):
    out = bytearray()
    write_varint(out, len(entries))
    last = 0
    for tile, _, _, _ in entries:
        write_varint(out, tile - last)
        last = tile
    for _, _, _, run in entries:
        write_varint(out, run)
    for _, _, length, _ in entries:
        write_varint(out, length)
    for i, (_, offset, _, _) in enumerate(entries):
        previous = entries[i - 1] if i else None
        write_varint(out, 0 if previous and offset == previous[1] + previous[2] else offset + 1)
    return gzip.compress(bytes(out), mtime=0)


def directories(entries, root_space):
    """The root directory, and the leaf directories it points to when it would not fit alone."""
    root = encode_directory(entries)
    leaf_size = 4096
    while len(root) > root_space:
        pointers, leaves = [], bytearray()
        for start in range(0, len(entries), leaf_size):
            chunk = encode_directory(entries[start:start + leaf_size])
            pointers.append((entries[start][0], len(leaves), len(chunk), 0))
            leaves += chunk
        root = encode_directory(pointers)
        leaf_size *= 2
        if len(root) <= root_space:
            return root, bytes(leaves)
    return root, b""


class Source:
    """The planet archive, read with range requests over one kept-alive connection."""

    def __init__(self, build):
        self.path = f"/{build}.pmtiles"
        self.connection = None
        self.bytes_read = 0

    def read(self, offset, length):
        error = None
        for _ in range(4):
            try:
                if self.connection is None:
                    self.connection = http.client.HTTPSConnection(SOURCE_HOST, timeout=60)
                self.connection.request("GET", self.path, headers={
                    "Range": f"bytes={offset}-{offset + length - 1}",
                    "User-Agent": "speedtrack-map-extract",
                })
                response = self.connection.getresponse()
                data = response.read()
                if response.status == 206 and len(data) == length:
                    self.bytes_read += length
                    return data
                error = f"HTTP {response.status} with {len(data)} of {length} bytes"
            except (OSError, http.client.HTTPException) as failure:
                error = failure
            if self.connection:
                self.connection.close()
            self.connection = None
        sys.exit(f"reading {length} bytes at {offset} failed: {error}")


def read_header(first):
    header = dict(zip(FIELDS, HEADER.unpack_from(first)))
    if header["magic"] != b"PMTiles" or header["version"] != 3:
        sys.exit("not a PMTiles version 3 archive")
    return header


def find_tiles(source, header, root, wanted):
    """(tile id, offset, length) in the source's tile data, for each wanted tile it has."""
    found, leaves = [], {}

    def lookup(directory, tile):
        ids, offsets, lengths, runs = directory
        i = bisect_right(ids, tile) - 1
        if i < 0:
            return None
        if runs[i] == 0:
            leaf = leaves.get(offsets[i])
            if leaf is None:
                if len(leaves) > 64:
                    leaves.clear()
                if offsets[i] + lengths[i] > header["leaf_length"]:
                    sys.exit("a leaf directory lies outside its section")
                leaf = decode_directory(source.read(header["leaf_offset"] + offsets[i], lengths[i]))
                leaves[offsets[i]] = leaf
            return lookup(leaf, tile)
        return (offsets[i], lengths[i]) if tile < ids[i] + runs[i] else None

    for tile in wanted:
        hit = lookup(root, tile)
        if hit:
            if hit[0] + hit[1] > header["data_length"]:
                sys.exit("a tile lies outside the tile data")
            found.append((tile, *hit))
    return found


def copy_tiles(source, header, found, out, start):
    """Writes each content once, in the order of the first tile that uses it, and returns the new
    entries. A read covers the following tiles too, where they lie close behind."""
    placed, window_start, window, entries = {}, 0, b"", []
    for index, (tile, offset, length) in enumerate(found):
        if offset not in placed:
            if not window_start <= offset or offset + length > window_start + len(window):
                end = offset + length
                for _, later, later_length in itertools.islice(found, index + 1, None):
                    if later in placed or later < offset:
                        continue
                    if later > end + MAX_GAP or later + later_length - offset > MAX_RANGE:
                        break
                    end = max(end, later + later_length)
                window_start = offset
                window = source.read(header["data_offset"] + offset, end - offset)
            placed[offset] = out.tell() - start
            out.write(window[offset - window_start:offset - window_start + length])
        entries.append((tile, placed[offset], length))
    return entries, len(placed)


def run_lengths(entries):
    merged = []
    for tile, offset, length in entries:
        last = merged[-1] if merged else None
        if last and last[0] + last[3] == tile and last[1] == offset:
            merged[-1] = (last[0], offset, length, last[3] + 1)
        else:
            merged.append((tile, offset, length, 1))
    return merged


def e7(degrees):
    return round(degrees * 10_000_000)


def write_archive(source, header, found, boxes, path):
    with open(path, "wb") as out:
        out.write(bytes(FIRST_BYTES))
        entries, contents = copy_tiles(source, header, found, out, FIRST_BYTES)
        data_length = out.tell() - FIRST_BYTES
        metadata = source.read(header["metadata_offset"], header["metadata_length"])
        metadata_offset = out.tell()
        out.write(metadata)
        merged = run_lengths(entries)
        root, leaves = directories(merged, FIRST_BYTES - HEADER.size)
        leaf_offset = out.tell()
        out.write(leaves)
        west, south, east, north = boxes[0]
        values = dict(header, root_offset=HEADER.size, root_length=len(root),
                      metadata_offset=metadata_offset, metadata_length=len(metadata),
                      leaf_offset=leaf_offset, leaf_length=len(leaves), data_offset=FIRST_BYTES,
                      data_length=data_length, addressed_tiles=len(entries), tile_entries=len(merged),
                      tile_contents=contents, clustered=1, min_zoom=0, max_zoom=MAX_ZOOM,
                      min_lon=e7(min(b[0] for b in boxes)), min_lat=e7(min(b[1] for b in boxes)),
                      max_lon=e7(max(b[2] for b in boxes)), max_lat=e7(max(b[3] for b in boxes)),
                      center_zoom=6, center_lon=e7((west + east) / 2), center_lat=e7((south + north) / 2))
        out.seek(0)
        out.write(HEADER.pack(*(values[field] for field in FIELDS)) + root)
    return {tile: (offset, length) for tile, offset, length in entries}


def check_archive(path, expected, probe):
    """Reads the archive back as the app would, so a writer bug fails here and not on a phone."""
    # Mapped, not read: the file is larger than the memory the script may use.
    with open(path, "rb") as archive, mmap.mmap(archive.fileno(), 0, access=mmap.ACCESS_READ) as data:
        check_mapped(data, expected, probe)


def check_mapped(data, expected, probe):
    header = read_header(data)
    if header["root_offset"] + header["root_length"] > FIRST_BYTES:
        sys.exit("the root directory does not fit in the first bytes")
    if header["leaf_offset"] + header["leaf_length"] != len(data):
        sys.exit("the file does not end with its leaf directories")

    def walk(directory):
        for tile, offset, length, run in zip(*directory):
            if run == 0:
                start = header["leaf_offset"] + offset
                yield from walk(decode_directory(data[start:start + length]))
            else:
                for step in range(run):
                    yield tile + step, (offset, length)

    root = data[header["root_offset"]:header["root_offset"] + header["root_length"]]
    if dict(walk(decode_directory(root))) != expected:
        sys.exit("the directories do not address the tiles that were written")
    latitude, longitude, names = probe
    hit = expected.get(tile_id(8, *tile_xy(8, longitude, latitude)))
    if hit is None:
        sys.exit("the archive has no tile for the capital")
    offset, length = hit
    tile = gzip.decompress(data[FIRST_BYTES + offset:FIRST_BYTES + offset + length])
    if not any(name in tile for name in names):
        sys.exit("the capital's tile does not name it: the tiles were read from the wrong place")


def main():
    arguments = [a for a in sys.argv[1:] if a != "--dry-run"]
    dry_run = len(arguments) < len(sys.argv) - 1
    if len(arguments) != 3 or arguments[0] not in COUNTRIES or not re.fullmatch(r"\d{8}", arguments[1]):
        sys.exit(f"usage: extract-country-map.py [--dry-run] {{{','.join(COUNTRIES)}}} <build date> <directory>")
    country, build, directory = arguments
    source = Source(build)
    first = source.read(0, FIRST_BYTES)
    header = read_header(first)
    layout = (header["internal_compression"], header["tile_compression"], header["tile_type"], header["clustered"])
    if layout != (GZIP, GZIP, MVT, 1):
        sys.exit("expected gzip directories and tiles, vector tiles and a clustered archive")
    if header["max_zoom"] < MAX_ZOOM or header["root_offset"] + header["root_length"] > FIRST_BYTES:
        sys.exit("unexpected archive layout")
    root = decode_directory(first[header["root_offset"]:header["root_offset"] + header["root_length"]])
    boxes = COUNTRIES[country]
    found = find_tiles(source, header, root, wanted_tiles(boxes))
    unique = {offset: length for _, offset, length in found}
    print(f"{country}: {len(found)} tiles, {len(unique)} contents, {sum(unique.values()) / 1e6:.0f} MB of tiles")
    if dry_run:
        return
    name = f"{country}-z{MAX_ZOOM}-{build}.pmtiles"
    path = Path(directory) / name
    part = path.with_name(name + ".part")
    path.parent.mkdir(parents=True, exist_ok=True)
    expected = write_archive(source, header, found, boxes, part)
    check_archive(part, expected, PROBES[country])
    os.replace(part, path)
    digest = hashlib.sha256()
    with open(path, "rb") as archive:
        for block in iter(lambda: archive.read(1 << 20), b""):
            digest.update(block)
    print(f"{path}: {path.stat().st_size} bytes, SHA-256 {digest.hexdigest()}, "
          f"{source.bytes_read / 1e6:.0f} MB read")


if __name__ == "__main__":
    main()
