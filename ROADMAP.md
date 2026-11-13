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

Put off by Marc on 2026-11-10 and asked for on 2026-11-12. The repo part is done: the privacy policy
and support page, linked from Settings, the open-source introduction, the GPS requirement, and the
listing in `APP_STORE.md`. Marc decided on 2026-11-12: the store name "Speedtrack: What's my speed",
screenshots from his iPhone, non-trader, and a Submit for Review tap per store version. Open:

- **Xcode Cloud:** done on 2026-11-12. Marc set the archive's Distribution Preparation to "App Store
  Connect". Builds made before that can never go to the App Store.
- **Version 1.0.1:** the first store version, because its Settings name train and plane travel as
  the main use, by Marc's word of 2026-11-12. 1.0.0 reached TestFlight on 2026-11-12 (815eb03) with
  the older text and is not submitted.
- **Listing key:** Marc said go on 2026-11-13, "along the rules aligned with the assistant".
  `store/listing.json` holds the listing, and the store job's reviewed text waits in
  `store/store.yml`. Next: the 1201-assistant session reviews it, Marc commits it as
  `.github/workflows/store.yml` and then creates the key, and the listing goes from mode off to
  check to write. Then `store/store.yml` goes, and `ci/check-store.sh` reads the workflow file.
- **Screenshots:** Marc took them on a flight. He uploads them himself, because the Marketing role
  cannot.
- **Marc's one-time steps in App Store Connect:** the rest of `APP_STORE.md`, then the screenshots,
  and a tap on Submit for Review.
- **App Privacy:** open with Marc: "Data Not Collected" or Other Diagnostic Data, with the facts in
  `APP_STORE.md`. He chose on 2026-11-12 to build nothing on the map server.
