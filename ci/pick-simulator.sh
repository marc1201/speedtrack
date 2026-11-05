#!/usr/bin/env bash
# Print the id of an iPhone simulator on the newest iOS the runner image carries: device names
# change with every image, so none is hard-coded.
set -euo pipefail
xcrun simctl list devices available -j | python3 -c '
import json, sys

phones = []
for runtime, devices in json.load(sys.stdin)["devices"].items():
    if ".iOS-" not in runtime:
        continue
    version = tuple(int(part) for part in runtime.rsplit("iOS-", 1)[1].split("-"))
    phones += [(version, d["name"], d["udid"]) for d in devices if d["name"].startswith("iPhone")]
if not phones:
    sys.exit("no iPhone simulator on this runner")
print(sorted(phones)[-1][2])
'
