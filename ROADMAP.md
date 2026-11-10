# Roadmap

What Marc has asked for and is not built yet.

## A country map for offline use

Asked for on 2026-11-10. Today the map is Apple's. Without internet the app draws its built-in
overview from Natural Earth: coastlines, borders, lakes, the larger railways and roads, and places,
but no streets. A downloaded map of a country would show streets offline too.

Research of 2026-11-10:

- **Not Apple's map:** the offline maps a user downloads in Apple Maps are not available to other
  apps, and Apple's licence lets an app cache Apple's map data only temporarily.
- **OpenStreetMap:** its own tile server forbids offline use, so the data has to come from an
  extract. A Protomaps basemap is under the ODbL and must credit "© OpenStreetMap". Sizes:

  | Country | Regional detail (zoom 10) | Street level (zoom 14) |
  |---|---|---|
  | Portugal | about 15 MB | about 345 MB |
  | Germany | about 157 MB | about 3.5 GB |

- **Hosting:** Apple can host the downloads as Background Assets, which arrived with WWDC25 and come
  with 200 GB of hosting in the developer membership. Otherwise we host them.
- **Drawing:** MapLibre Native (BSD licence, about 9 MB, a third-party dependency), or MapKit tile
  overlays with tiles we render ourselves. Tile overlays need MKMapView in place of SwiftUI's Map.

Marc decides the data source and its hosting, whether to add a dependency, and how large a download
may be.

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
