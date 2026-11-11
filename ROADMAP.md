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

Put off by Marc on 2026-11-10, and researched on 2026-11-08. Listing a free app costs nothing beyond
the membership. What it needs:

- **Xcode Cloud:** Marc switches the archive in App Store Connect from "TestFlight (Internal Testing
  Only)" to "TestFlight and App Store". Builds made before the switch cannot go to the App Store.
- **Privacy pages:** a privacy policy link inside the app, and a public privacy policy and support
  page. The support page must give the company's address, email and phone.
- **Listing:** a store name that matches the Home Screen name, a description and keywords, and
  screenshots from a real ride. Review notes explain that the speed needs GPS and movement.
- **Marc's one-time steps in App Store Connect:**
  - EU trader status under the Digital Services Act, which shows the company's address, phone and
    email on the EU store.
  - The latest developer agreement.
  - App Privacy "Data Not Collected", which Apple's map does not change.
  - Age rating 4+, category Navigation, and price Free.
- **Open decision:** every App Store version needs a "Submit for Review" click in App Store
  Connect. The alternative is an API key with the App Manager role.
