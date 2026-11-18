# App Store

The listing text lives in `store/listing.json`, and the store job sets it on the store version
being prepared (`CLAUDE.md`, "The store listing"). The answers below live in App Store Connect, out
of the push token's reach, so this file is their record: change it whenever the console changes.
Marc's decisions of 2026-11-12 are marked as his. The listing leads with train and plane travel,
which Marc named as the app's main use on 2026-11-12.

The store job has set the listing since 2026-11-18 (store run 44329499449). Marc committed its
workflow as ba7a8c7, then as 2d0eb8e, which allows his key's 12-character ID, and the
1201-assistant session matched both to the text it reviewed.

## Listing, English (U.S.)

What the texts in `store/listing.json` rest on:

- **Name:** Marc's choice. It starts with the Home Screen name, "Speedtrack", because guideline
  2.3.8 rejects names that don't match.
- **Keywords:** at most 100 bytes. The name and subtitle already give "speed", "train", "plane" and
  "speedometer", and the store searches all three fields, so the keywords don't repeat them.
- **Description:** it keeps the warning against use while driving, as Settings in the app do.
- **URLs:** the store job sets three and no others: the repository as the marketing URL, its
  `SUPPORT.md` as the support URL and its `PRIVACY.md` as the privacy policy URL.
- **Copyright:** the year and Eins-zwei-null-eins Portugal Unipessoal, Lda. The job accepts no other
  holder.
- **Category:** Navigation, and Utilities second, set by the store job.

## Screenshots

Marc takes them on his iPhone, by his choice. He needs at least one and may upload up to ten, as
PNG or JPEG without transparency, showing the app in use. App Store Connect requires the class
"iPhone with Dynamic Island (medium display)": 1206 x 2622 or 1179 x 2556 in portrait, the size of
an iPhone 14 Pro to 17 Pro. A Pro Max shot is 1320 x 2868, which fits the large class, and resized it
fits the required one too. If App Store Connect also asks for the large class, upload the same shots
resized to 1320 x 2868. Show nothing that suggests use while driving, so no road under a high
speed. A train ride as a passenger, the main use, shows it best, with the railway on the map; a walk
works too. The map shows where the phone is, so take them away from home. Marc's screenshots show
the speed on a flight, and he sends no screen recording. His iPhone saves 1320 x 2868 screenshots
as 16-bit PNG. On 2026-11-18 App Store Connect refused those for the iPhone slot ("File dimensions
are invalid") and took them converted to 1206 x 2622, 8-bit with the Display P3 profile kept. They
come from an earlier build, before the map got half the screen; new ones from 1.0.2 would match the
app exactly.

## App Review information

- **Sign-in required:** no.
- **Contact:** Marc, entered in the console only, with the phone number in international format.
- **Notes:** in `store/listing.json`. The store job writes only the notes, never the contact.

## Answers in App Store Connect

- **App Privacy:** "Data Not Collected", entered by Marc on 2026-11-18, as the 1201-assistant
  session recommended. The facts: the app's own downloads leave no line on the map server. Only a
  malformed request, which the app never sends, or a fault inside the web server itself could leave
  an error line with an IP address, kept until the system log rotates (see `PRIVACY.md`).
  `App/PrivacyInfo.xcprivacy` lists no collected data either. The other answer put to Marc on
  2026-11-12 was Diagnostics, Other Diagnostic Data, not linked to the user, not used for tracking,
  for App Functionality, which covers the possible fault line; the privacy manifest would then need
  the same entry, and so a new build.

  MapKit's data is Apple's to disclose, not the developer's.
- **Age rating:** 4+. Every capability is No: parental controls, age assurance, unrestricted web
  access (links open Safari), user-generated content, social media, messaging, advertising,
  gambling, loot boxes, shared location, and dating and relationships. Every content question is
  None. Not "Made for Kids". The store job sets these answers, except shared location and dating
  and relationships: Apple asks those from 2026-11-16 and has no attribute for them, so Marc answers
  them in the console. The job set the others on 2026-11-18, and Marc answered both No that day.
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
- **Version number:** a store version carries the `MARKETING_VERSION` of the build it ships, 1.0.2
  for the first. App Store Connect named the app's first version 1.0.0 itself, and Marc changed it
  to 1.0.2 on 2026-11-18, because the Build list offers only builds of the same number.
- **Version release:** Apple's default, released as soon as App Review approves it.
- **Submitting:** Marc taps Submit for Review for each store version, by his decision. See
  `CLAUDE.md`. He submitted 1.0.2 (12) on 2026-11-18, and App Review approved it at 21:43 UTC the
  same day.
