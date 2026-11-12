# App Store

The listing and the App Store Connect answers for Speedtrack (Apple ID 6831002114). They live in
App Store Connect, out of the push token's reach, so this file is their record: change it whenever
the console changes. Marc's decisions of 2026-11-12 are marked as his.

## Listing, English (U.S.)

- **Name:** Speedtrack: What's my speed. This is Marc's choice. It starts with the Home Screen name,
  "Speedtrack", because guideline 2.3.8 rejects names that don't match. It keeps a phrase that
  another developer's "Speedometer: What's My Speed" also uses, which guideline 4.1(c) can object
  to.
- **Subtitle:** Speedometer that works offline
- **Promotional text:** See how fast you are moving in km/h, mph, m/s or pace, with a map that keeps
  working without internet. Open source, with no account, no ads and no tracking.
- **Keywords:** gps,km/h,mph,pace,velocity,bus,map,train,ferry,plane,bike,cycling,running,walking,hiking
- **Support URL:** https://github.com/marc1201/speedtrack/blob/main/SUPPORT.md
- **Marketing URL:** https://github.com/marc1201/speedtrack
- **Privacy policy URL:** https://github.com/marc1201/speedtrack/blob/main/PRIVACY.md
- **Copyright:** 2026 Eins-zwei-null-eins Portugal Unipessoal, Lda
- **Category:** Navigation, and Utilities second

**Description:**

```
Speedtrack shows how fast you are moving, in big numbers, with a map of where you are. Its maps keep working without internet.

• Speed from GPS in km/h, mph, m/s, min/km or min/mi
• Your top speed of the day
• Apple Maps, or outlines of coastlines, borders, roads, railways and towns that are built into the app and need no internet
• OpenStreetMap for the countries you download once and then use offline, so far Japan, South Korea, Portugal and Germany. Each download is checked before it is used.
• Shows 0 when your iPhone lies still, where GPS alone would drift
• The number turns grey when the speed is not current, and the line below it says why
• The screen stays on while the app is open

Made for passengers on trains, buses, ferries and planes, and for walking, running and cycling. Do not use it while driving.

No account, no ads, no analytics and no tracking. The app sends your position nowhere. Apple's map, which the app starts with, loads the area on screen from Apple; the outlines and OpenStreetMap need no connection.

Speedtrack is open source under the MIT License: github.com/marc1201/speedtrack

Map data © OpenStreetMap contributors, prepared by Protomaps. Outlines from Natural Earth.
```

## Screenshots

Marc takes them on his iPhone, by his choice. He needs at least one and may upload up to ten, as
PNG or JPEG without transparency, showing the app in use. App Store Connect requires the class
"iPhone with Dynamic Island (medium display)": 1206 x 2622 or 1179 x 2556 in portrait, the size of
an iPhone 14 Pro to 17 Pro. A Pro Max shot is 1320 x 2868, which fits the large class, and resized it
fits the required one too. If App Store Connect also asks for the large class, upload the same shots
resized to 1320 x 2868. Show no high speeds and nothing that suggests use while driving: walking,
cycling, or a train ride as a passenger. The map shows where the phone is, so take them away from
home. The walk is also the speed's first outdoor test on record, and a 30 to 60 second screen
recording of it, from "--" to a live speed, can go to App Review as an attachment.

## App Review information

- **Sign-in required:** no.
- **Contact:** Marc, entered in the console only, with the phone number in international format.
- **Notes:**

```
Speedtrack is a free GPS speedometer for passengers, walkers, runners and cyclists. Unlike most speedometers it also works without internet: GPS gives the speed, world outlines are built into the app, and OpenStreetMap countries are downloaded once and checked by SHA-256. Only Apple Maps, the default map, needs a connection. A motion check holds a phone lying still at 0 instead of GPS drift. There is no sign-in, nothing to buy and no advertising. It is open source under the MIT License. Tested through TestFlight on iPhone.

The speed is the one Core Location reports, so it needs precise location and movement. Indoors or standing still the number reads "--" or 0, and the line below it says why, for example "Looking for your location" or "Location found, no speed yet". Outdoors and moving, a speed shows within seconds. Location is used only while the app is on screen. If location is denied, everything except the speed keeps working.

The Settings tab chooses the map: Apple Maps (online), Outlines (built into the app, no internet) or OpenStreetMap. Under OpenStreetMap, Download fetches a country's map file from our server maps.1201.de, checks its SHA-256 and then draws it without internet. The countries are Japan, South Korea, Portugal and Germany; Portugal, 91 MB, is the smallest. Outside those countries the map follows your position, so pinch out and drag to the downloaded country; the location button brings the map back to you.

External services: Apple's MapKit for Apple Maps, and maps.1201.de over HTTPS for the country downloads. The links in Settings to the code on GitHub, the privacy policy, the support page and the OpenStreetMap credits open in the browser, outside the app. The app works the same in every region.
```

If a screen recording is attached, the notes end with: "A screen recording of the speed on a walk is
attached."

## Answers in App Store Connect

- **App Privacy:** open with Marc, who enters it himself. The facts: the app's own downloads leave
  no line on the map server. Only a malformed request, which the app never sends, or a fault inside
  the web server itself could leave an error line with an IP address, kept until the system log
  rotates (see `PRIVACY.md`). The two answers, which the 1201-assistant session put to Marc on
  2026-11-12:
  - "Data Not Collected", as the server works in practice. `App/PrivacyInfo.xcprivacy` lists no
    collected data either.
  - Diagnostics, Other Diagnostic Data, not linked to the user, not used for tracking, for App
    Functionality, which covers the possible fault line. The privacy manifest would then need the
    same entry.

  MapKit's data is Apple's to disclose, not the developer's.
- **Age rating:** 4+. Every capability is No: parental controls, age assurance, unrestricted web
  access (links open Safari), user-generated content, social media, messaging, advertising,
  gambling, loot boxes, shared location, and dating and relationships. Every content question is
  None. Not "Made for Kids".
- **Content rights:** the app shows third-party content (OpenStreetMap, Natural Earth, Apple Maps)
  and has the rights to it.
- **Export compliance:** answered by `ITSAppUsesNonExemptEncryption` = NO in `App/Info.plist`: the
  app's only encryption is the system's HTTPS.
- **Price:** free.
- **Availability:** every country and region except China mainland, where a map app needs a filing
  number and licences the company does not hold. Not on Apple silicon Macs or Apple Vision Pro.
- **EU Digital Services Act:** non-trader, by Marc's decision. Apple publishes no contact details
  for the app. EU product pages say the provider has not declared itself a trader, so EU consumer
  rights do not apply.
- **Submitting:** Marc taps Submit for Review for each store version, by his decision. See
  `CLAUDE.md`.
