# App Review Information — Notes

App Store Connect → App Review Information → Notes alanına yapıştırılacak metin.
Guideline 2.1 (Information Needed) yanıtı. Her yeni gönderimde de aynı metin kalmalı.

---

Thank you for reviewing Doner Kebab Map. Below is the information requested.

**DEMO ACCOUNT: Not required.** The app has no accounts, no login, no paid
content, no subscriptions, and no user-generated content. All features are
immediately available after launch.

**IMPORTANT NOTE FOR TESTING:** The app finds doner/kebab restaurants near the
device's current location using Apple MapKit. Results therefore depend on the
reviewer's physical location. In an area with few kebab/doner restaurants, few
or no pins may appear — this is expected behavior, not a bug. To see the app
working with a full result set, please test in or simulate a major city
(for example Berlin, London, or Istanbul), where such restaurants are common.
The app searches within a 20 km radius of the device location.

---

**1. SCREEN RECORDING**

A screen recording captured on a physical device is attached to this reply. It
shows app launch, the location permission prompt, the map with results, the
place detail sheet, the list view, adding a favorite, and the directions flow.

**2. DEVICES AND OS VERSIONS TESTED**

- iPhone 13, iOS 27.0 (physical device)
- Additionally tested on the iOS Simulator (iPhone 17 / iPhone 16 Pro, iOS 26.2)

The app supports iOS 17.0 and later, on iPhone and iPad.

**3. APP FUNCTION AND TARGET AUDIENCE**

Doner Kebab Map helps users quickly find doner, kebab, and gyro restaurants
near their current location.

Problem it solves: general map applications list all restaurants together,
which makes it slow to find this specific type of food, especially for people
who are travelling or in an unfamiliar city.

Value it provides: a single, focused map of nearby doner/kebab places, each
showing the distance from the user, estimated driving and walking time, the
address, and a one-tap route in Apple Maps or Google Maps. Users can save
places as favorites for later.

Target audience: general public (rated 4+). No age-restricted, sensitive, or
regulated content. The app is free, contains no advertising, no in-app
purchases, and no account system.

**4. SETUP AND ACCESS INSTRUCTIONS**

No credentials, sample files, or configuration are required.

1. Launch the app. A brief splash screen appears, then the Map tab opens.
2. The system location permission prompt appears. Choose "Allow While Using
   App". (The app only requests When-In-Use location.)
3. The map centers on your location and nearby doner/kebab places load
   automatically as pins within a 20 km radius.
4. Tap any pin to open the detail sheet: name, distance, driving/walking ETA,
   address, phone number and website when available, a heart button to save
   the place to favorites, "Get Directions", and a share button.
5. "Get Directions" offers Apple Maps or Google Maps and hands off to that app.
6. The List tab shows the same places sorted by distance.
7. The More tab shows saved favorites (swipe to delete), an appearance setting
   (System / Light / Dark), the app version, and a contact option.

If location permission is denied, the app still launches normally and simply
shows no results; permission can be granted later in iOS Settings.

**5. EXTERNAL SERVICES, TOOLS, AND PLATFORMS**

The app uses only Apple's own frameworks. There is no backend server of our
own, no authentication service, no payment processor, no advertising network,
no analytics or tracking SDK, and no AI service.

- Apple MapKit (MKLocalSearch): searching for nearby places — the app's only
  data provider.
- Apple MapKit (MKDirections): estimated travel time for driving and walking.
- Apple Core Location: obtaining the device's location (When In Use only).
- Apple MessageUI: opens the system mail composer only when the user taps
  "Contact".
- Apple Maps / Google Maps: opened externally as the destination for turn-by-
  turn directions, at the user's explicit choice. Google Maps is opened via
  its URL scheme, or its website if the app is not installed. No data is sent
  other than the destination coordinates in the URL.

All user data (favorites and the appearance preference) is stored locally on
the device in UserDefaults. No personal data is collected, transmitted to us,
or shared with third parties. The app does not track users. This is declared
in the included privacy manifest (PrivacyInfo.xcprivacy) and in the privacy
policy linked from App Store Connect.

**6. REGIONAL DIFFERENCES**

The app functions consistently across all regions. There are no region-locked
features, no regionally different content, and no geographic restrictions.

The user interface is localized in English (default), German, and French; only
the display language differs, the functionality is identical. The single
natural variation is the number of search results, which depends on Apple Maps
point-of-interest coverage in the user's area.

**7. REGULATED INDUSTRY / PROTECTED THIRD-PARTY MATERIAL**

Not applicable. The app does not operate in a regulated industry and does not
include protected third-party material.

All place data is provided by Apple MapKit through Apple's public APIs. The app
icon, logo, and all in-app artwork are original work created for this app. The
restaurant names shown come directly from the Apple Maps database and are not
reproduced from any other source.
