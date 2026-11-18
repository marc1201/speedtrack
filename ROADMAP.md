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
