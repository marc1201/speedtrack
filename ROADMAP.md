# Roadmap

What Marc has asked for and is not built yet.

## More of the OpenStreetMap map

Built on 2026-11-11: Settings downloads Japan, South Korea, Portugal and Germany at zoom 12, about
1.35 GB in all, from `maps.1201.de` on the VPS. Open:

- **Hosting:** the VPS is "for now", in Marc's words. Cloudflare R2, with free egress and one
  write-only token in Actions, was the first plan.
- **Size:** Germany is 888 MB, mostly buildings, which the style shows only from zoom 13. Cutting
  them out of the tiles would need a tool that rewrites vector tiles.
- **More countries, fresher data:** each is one more run of `tools/extract-country-map.py` and a new
  dated entry in `App/CountryMaps.json`, which ships with a release.

## App Store release

Put off by Marc on 2026-11-10 and asked for on 2026-11-12. Version 1.0.2 (12) went to App Review on
2026-11-18. Done: the privacy policy and support page, linked from Settings, the open-source
introduction, the GPS requirement, the listing, which the store job wrote, and Marc's answers in
App Store Connect, all recorded in `APP_STORE.md`. Marc decided on 2026-11-12: the store name
"Speedtrack: What's my speed", screenshots from his iPhone, non-trader, and a Submit for Review tap
per store version. Open:

- **App Review:** Apple's verdict on 1.0.2. A rejection's reason and its fix go into `APP_STORE.md`.
- **Version 1.0.2:** the first store version, because it gives the map and the numbers the same
  height, which Marc asked for on 2026-11-18. 1.0.1 reached TestFlight on 2026-11-13 (3871a94) and
  1.0.0 on 2026-11-12 (815eb03); neither was submitted.
- **Listing key:** live since 2026-11-18, by Marc's go of 2026-11-13, "along the rules aligned with
  the assistant". He committed the store workflow (ba7a8c7) and its fix for his key's 12-character
  ID (2d0eb8e), and the 1201-assistant session matched both to the text it reviewed. The job wrote
  the listing from `store/listing.json` on 2026-11-18 (store run 44329499449).
