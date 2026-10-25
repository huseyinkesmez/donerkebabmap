# Doner Kebab Map — Project Context

## About
iOS app (Swift + SwiftUI, MVVM) that shows doner/kebab/gyro places near the
user on a map. **v1.0.1 is live on the App Store** (build 6, git tag `v1.0.1`);
**v1.1 (build 7, tag `v1.1`) was uploaded for review on 2026-10-25.**

The developer is a QA engineer with limited software background: explain step
by step, simply and clearly.

## Language
- **Talk to the user in Turkish.**
- **Everything written to files is English**: code, comments, doc comments,
  log messages, commit messages, docs, CLAUDE.md, skills. No Turkish in the repo.
- User-facing app text: English source + DE/FR translations (see below).

## Rules
- In app text write **"doner"**, never "döner" (no Turkish characters). Only the
  search keywords in `PlacesSearchService` intentionally keep "döner".
- Default language is English; German (informal "du") and French (formal "vous")
  live in `Localizable.xcstrings`. Add DE/FR whenever you add a new string.
- Colors live in `AppTheme`: `primary` for fills/buttons, `primaryAccent` for
  text/icons on tinted backgrounds (readable in light and dark). Logo is amber.
- Never wrap segmented `Picker` content in `ViewThatFits` or similar — it breaks.
- Don't put tinted backgrounds on toolbar items (looks like a smudge on device).
- Logos: `DonerConeLogo` for large placements (splash, profile), `DonerGlyph`
  for small marks (pins, list rows, cards).
- Map pins (`ClusteredMapView`): MapKit can reset `clusteringIdentifier` /
  `displayPriority` when it reuses an annotation view (seen on iOS 27), so
  re-apply them in `prepareForDisplay()`. Test map changes on a real device too —
  the simulator runtime can be older than the device's iOS.
- Commit/push only when asked.

## Architecture
- **No backend.** Data: Apple MapKit `MKLocalSearch` (free, no key), 20 km
  radius, multiple keywords + dedupe (same name counts as one place only < 250 m).
- Location is fetched once; if none arrives in 15 s a "Location Unavailable" screen shows.
- Favorites via `FavoriteStore` in UserDefaults (name + < 30 m coordinate match).
- `ContentView` is not mounted until onboarding finishes — otherwise taps were
  dropped on device.
- Map is `MKMapView` wrapped in `ClusteredMapView` (SwiftUI `Map` has no
  clustering). Zoomed in (< ~3 km): every pin + name, no clusters. Zoomed out:
  clusters, no names. A tapped pin stays highlighted while its sheet is open.
- MapKit does **not** provide ratings, reviews, opening hours or photos
  (`rating` is nil for now).

## Layout
- `Models/` — `DonerPlace`, `FavoritePlace`
- `ViewModels/PlacesViewModel` — shared search state
- `Services/` — `LocationManager`, `PlacesSearchService`, `FavoriteStore`
- `Utilities/` — `AppTheme`, `DonerConeLogo`, `DonerGlyph`, `DistanceFormatter`,
  `DirectionsHelper`, `TransportMode`, `AppearanceMode`, `AdaptiveText`, `MailView`
- `Views/` — `RootView` (splash + onboarding), `MapTabView`, `ClusteredMapView`, `ListTabView`,
  `PlaceDetailCard`, `ProfileTabView` ("More"), `OnboardingView`, `LoadingView`,
  error/permission screens
- `docs/` — `privacy-policy.html`, `support.html`, `app-review-notes.txt`
- `.claude/skills/release/` — `/release` skill for App Store releases

## Releasing
- Use `/release`. Next build number is **8+**; next version 1.1.1 or 1.2.
- App Review Notes: `docs/app-review-notes.txt` (< 4000 chars). Keep the
  "results depend on location, test in a big city" paragraph.
- Running in the simulator: set a simulated location first (e.g. Berlin 52.52, 13.405).

## Possible next steps
List search/filter, route line, ratings and opening hours via
Overpass / Google Places.
