#!/usr/bin/env bash
# Runs the store job's two jq programs, exactly as its workflow file holds them, against
# store/listing.json and against listings they must refuse. The store job cannot be tested by a
# push, because a fix to it is a workflow file that only Marc commits; this catches a bad listing
# or a bad program in the ordinary compile run first. Needs jq, which the macOS runner has.
set -euo pipefail
cd "$(dirname "$0")/.."

workflow=.github/workflows/store.yml
[ -f "$workflow" ] || workflow=store/store.yml # the reviewed draft, until Marc has committed it

# The text of the heredoc that starts with <<'MARKER' and ends at a line holding only MARKER.
extract() {
  awk -v m="$1" -v q="'" '
    index($0, "<<" q m q) { on = 1; next }
    on && NF == 1 && $1 == m { exit }
    on { print }' "$workflow"
}
# The listing links files of this repository on main, which the job names as fixed URLs. A renamed
# file would leave the store page's link dead.
pages="$(grep -ohE 'blob/main/[A-Za-z0-9._/-]+' "$workflow" | sed 's|^blob/main/||' | sort -u)"
test -n "$pages"
for page in $pages; do
  test -f "$page" || { echo "The store job links $page, which is not in the repository" >&2; exit 1; }
done

dup="$(extract DUP)"
prog="$(extract LISTING)"
test -n "$dup" && test -n "$prog"
jq --version

passes() {
  jq -en --stream "$dup" < "$1" > /dev/null 2>&1 &&
    jq -er --arg part meta "$prog" < "$1" > /dev/null 2>&1
}

t="$(mktemp -d)"
trap 'rm -rf "$t"' EXIT

# The listing itself passes, and each part comes out as the job sends it.
passes store/listing.json || { echo "store/listing.json fails the store job's checks" >&2; exit 1; }
jq -er --arg part meta "$prog" < store/listing.json | grep -Eq '^(off|check|write) [0-9]+[.][0-9]+[.][0-9]+$'
for part in version vloc iloc review; do
  jq -ec --arg part "$part" "$prog" < store/listing.json > "$t/$part"
done
jq -e 'keys == ["copyright"]' "$t/version" > /dev/null
jq -e 'keys - ["whatsNew"] == ["description", "keywords", "marketingUrl", "promotionalText", "supportUrl"]
  and .supportUrl == "https://github.com/marc1201/speedtrack/blob/main/SUPPORT.md"' "$t/vloc" > /dev/null
jq -e 'keys == ["name", "privacyPolicyUrl", "subtitle"]
  and .privacyPolicyUrl == "https://github.com/marc1201/speedtrack/blob/main/PRIVACY.md"' "$t/iloc" > /dev/null
jq -e 'keys == ["notes"]' "$t/review" > /dev/null

# A What's New is sent only when it has text, because Apple refuses one on a first version.
jq '.whatsNew = "Fixes."' store/listing.json > "$t/new.json"
jq -ec --arg part vloc "$prog" < "$t/new.json" | jq -e '.whatsNew == "Fixes."' > /dev/null

n=0
refused() {
  passes "$t/neg.json" && { echo "the store job's checks accept a listing with $1" >&2; exit 1; }
  n=$((n + 1))
}
while IFS='|' read -r what change; do
  jq "$change" store/listing.json > "$t/neg.json"
  refused "$what"
done <<'CASES'
a name over 30 characters|.name = ("x" * 31)
promotional text over 170 characters|.promotionalText = ("x" * 171)
keywords over 100 bytes|.keywords = ("ab," * 33 + "ab")
a space in the keywords|.keywords = "gps, mph"
an unknown key|. + {extra: "x"}
a missing key|del(.notes)
a number|.name = 1
a nested object|.notes = {a: "b"}
a line feed in the name|.name = "a\nb"
a line separator|.subtitle = "a\u2028b"
a zero-width space|.description += "\u200b"
a line feed after the version|.version = "1.0.1\n"
a two-part version|.version = "1.0"
an unknown mode|.mode = "yes"
another domain|.notes += " See evil.com."
a lookalike repository|.description += " github.com/marc12O1/speedtrack"
a domain after the repository's name|.description += " github.com/marc1201/speedtrack.com"
a URL scheme|.description += " https://example"
a www address|.promotionalText = "www.speedtrack"
another copyright holder|.copyright = "2026 Someone Else"
CASES

printf '{"name": "x",' > "$t/neg.json"
tail -c +2 store/listing.json >> "$t/neg.json"
refused "a duplicate key"
cat store/listing.json store/listing.json > "$t/neg.json"
refused "two objects"
: > "$t/neg.json"
refused "no content"
echo "store/listing.json passes the store job's checks, which refuse $n bad listings"
