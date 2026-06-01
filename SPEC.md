# Panchang iOS App — Project Specification

> **Purpose of this document:** This is the build spec for an autonomous coding agent (Claude Code). It is self-contained — there is no separate `CLAUDE.md`; the agent operating instructions live in §3 below. The architectural and product decisions here are **settled** — do not re-litigate them. Where a choice is genuinely open, it is flagged under "Open Questions." Read §2 (Context), §3 (Working Instructions), and §4 (Non-Goals) before writing any code.

---

## 1. Goal

A native iOS app that shows the Hindu panchang (Vedic almanac) for any day and location. The "today" screen presents the current day's panchang and its religious/astrological significance; a calendar lets the user jump to any date and see the same detail. All computation happens **on-device**; the app works fully offline.

The primary audience and default tradition is **Gujarati / Western Indian** (Amanta month system, Kartikadi year), with a North Indian preset available.

---

## 2. Context & Rationale (read before building)

- **This is a local-first app, not a client/server app.** The panchang is deterministic astronomy: the five limbs (tithi, vara, nakshatra, yoga, karana) derive from Sun/Moon positions plus a sidereal correction; daily timings derive from sunrise/sunset at the user's coordinates. There is **no backend** in v1 and none is needed. Sync (later) uses CloudKit; reminders use local notifications; festival data ships bundled (with an optional static-file refresh). Do not introduce a server.

- **Ephemeris library = SwiftAA (MIT).** Do **not** use Swiss Ephemeris / pyswisseph / swephR. Swiss Ephemeris 2.x is AGPLv3, which would force open-sourcing the entire app or buying a commercial license — a licensing trap for a closed-source App Store app. SwiftAA is MIT-licensed, Meeus/AA+ based, actively maintained, SPM-installable, and provides positions plus rise/transit/set times — sufficient accuracy for panchang.

- **The panchang derivation logic is the app's core IP.** SwiftAA gives raw (tropical) astronomical data. The work is building the layer on top: ayanamsa correction, the five limbs with their end-times, lunar-month/year naming with intercalary-month handling, and muhurta windows. Build this as a standalone, UI-free, heavily-tested Swift package so it is independently verifiable.

- **Accuracy is guaranteed by golden test vectors, not by trust.** A checked-in suite of known-good (date, location) → expected-values cases, validated against an authoritative published panchang, is the acceptance gate for the engine. Treat it as the contract.

---

## 3. Agent Working Instructions

*(This section replaces a standalone CLAUDE.md. It governs how the agent executes the rest of the spec.)*

### 3.1 Operating loop

- **Build in milestone order (§11).** Do not start UI work before the engine milestone (M1) is complete and its golden vectors pass. M1 is a **hard gate**.
- **After every change to `PanchangKit`, run its tests.** Do not proceed on a red suite. After every milestone, ensure the app builds and all tests pass, then commit.
- **When blocked on a human-only input, stop and surface it** (see §3.6) — do not guess values, fabricate reference data, or work around it silently.
- **Make small, reviewable commits**, one logical change each. Commit on every green milestone.

### 3.2 Environment & commands

- macOS with Xcode 26 (current SDK). Build/run against the iOS Simulator by default.
- Add SwiftAA via Swift Package Manager (`https://github.com/onekiloparsec/SwiftAA`). No CocoaPods, no Carthage.
- Test the engine package standalone and fast: `swift test` inside `PanchangKit/`.
- Build/test the app target via `xcodebuild`, e.g.:
  `xcodebuild test -scheme PanchangApp -destination 'platform=iOS Simulator,name=iPhone 16'`
- Prefer running the engine test suite (`swift test`) for tight feedback; reserve the full `xcodebuild` run for milestone checks.

### 3.3 Test discipline

- Golden vectors (§10) must stay green; treat them as the spec's contract. **Never weaken or delete a test to make it pass** — fix the code or escalate.
- Reproduce bugs with a failing test before fixing them.
- Include the invariance test: tithi/karana must be **unchanged** if the ayanamsa value changes (see §5 computation notes); nakshatra/yoga must change. This catches the most common derivation error.
- Keep engine tests deterministic (fixed JD inputs, no `Date()` in assertions).

### 3.4 Coding conventions

- Swift 6 with strict concurrency. Engine types are value types and `Sendable`.
- `PanchangKit` has **zero** UIKit/SwiftUI imports. The app target uses SwiftUI + `@Observable`; no `ObservableObject`.
- No force-unwraps or `try!` in engine code; surface failure as typed errors or optionals.
- Services are injected via initializers/protocols (no global singletons), so they are mockable.
- Document any non-obvious astronomy with a short comment and a reference (Meeus chapter / the reference impl in §5). Future maintainers and reviewers should not have to reverse-engineer the math.

### 3.5 Source control

- Provide a `.gitignore` covering build artifacts, `DerivedData/`, `*.xcuserstate`, `xcuserdata/`, `.swiftpm/`, and the local signing config (§12).
- **Never commit** an Apple Team ID, signing certificates, `.p12`/`.mobileprovision` files, or any credential. Signing config goes in a git-ignored `Signing.xcconfig` (see §12).

### 3.6 Guardrails — do NOT

- Add a backend/web service, or any networked computation of panchang.
- Add Swiss Ephemeris or any GPL/AGPL dependency.
- Create or modify Apple accounts, accept Apple legal agreements, or enter payment information — these are the human's responsibility (§12).
- Add paid-program entitlements in v1 (push notifications, CloudKit, associated domains). v1 uses local notifications only.
- Invent festival/vrat data and present it as authoritative — ship a clearly-marked **provisional** starter set (§10, §14).
- Fabricate expected values for golden vectors — obtain them from the human / the chosen authority (§14).

### 3.7 Stop and ask the human when

- Anything requires an Apple Developer account, a Team ID, or the Xcode signing GUI.
- Golden-vector reference values are needed and not yet provided.
- The festival/vrat dataset content or regional nuance is in question.
- The app name / bundle identifier / icon must be chosen.

---

## 4. Non-Goals (v1)

- No backend / web service / custom API.
- No user accounts, login, or authentication.
- No Swiss Ephemeris or any AGPL/GPL dependency.
- No astrology features (rashi/lagna, dasha, kundli, planetary dignities) — v2.
- No full muhurta/choghadiya suite beyond the v1 subset listed in §7 — v2.
- No iCloud/CloudKit sync — v2 (but model the persistence layer so it can be added without rework).
- No home-screen widgets, Apple Watch, or App Intents — v2.
- No paid tiers / in-app purchase.

---

## 5. Tech Stack & Constraints

- **Language:** Swift 6 (strict concurrency; mark engine types `Sendable`).
- **UI:** SwiftUI, adopting the iOS 26 "Liquid Glass" look where it falls out naturally.
- **State:** `@Observable` (Observation framework) for view models — not `ObservableObject`/`@Published`.
- **Navigation:** `NavigationStack` with typed, testable paths.
- **Persistence:** SwiftData (`@Model`) for saved locations, preferences, and cached day results.
- **Deployment target:** iOS 17.0 minimum (gives SwiftData, `@Observable`, `NavigationStack`, >90% device coverage). Build and run on the current SDK (iOS 26 / Xcode 26).
- **Ephemeris:** SwiftAA via Swift Package Manager (`onekiloparsec/SwiftAA`).
- **Dependencies:** keep minimal. SwiftAA is the only required third-party package.
- **Architecture pattern:** MVVM. Pure engine package + app target. Dependency injection for all services.

### Computation notes (get these right — they are common failure points)

- **Work internally in Julian Day / UT.** Convert to the location's timezone only for display.
- **The Hindu day runs sunrise-to-sunrise.** The panchang elements "for a date" are those prevailing at that day's sunrise, each reported with its end time. Timings past midnight are expressed as >24:00 by convention (the day ends at next sunrise).
- **Ayanamsa applies only to absolute sidereal positions.** SwiftAA returns tropical (sayana) longitudes; subtract Lahiri ayanamsa to get sidereal (nirayana).
  - **Nakshatra** = sidereal Moon longitude / (13°20'). **Needs ayanamsa.**
  - **Yoga** = (sidereal Sun longitude + sidereal Moon longitude). **Needs ayanamsa.**
  - **Tithi** = (Moon longitude − Sun longitude) mod 360, / 12°. **Ayanamsa-independent** (it cancels in the difference — do NOT subtract it twice).
  - **Karana** = half-tithi (same elongation basis as tithi; ayanamsa-independent).
- **End-time solving:** sample the relevant angle at several points around sunrise and find the boundary crossing by inverse interpolation (5-point inverse Lagrange is the established approach). Same technique for tithi, nakshatra, and yoga ends.
- **Muhurta windows** are deterministic from sunrise/sunset + weekday: split daytime (sunrise→sunset) into 8 equal parts for Rahu Kalam / Yamaganda / Gulika (the part index is fixed per weekday); Abhijit is the midday muhurta; Brahma Muhurta is the window ending ~48 min before sunrise.
- **Edge cases:** high latitudes where the Sun does not rise/set on a given day (no sunrise → fall back to a defined reference and surface the condition in the UI); date-line and DST handled via the location's timezone.

### Reference implementations (for algorithm, NOT to copy code)

Use these to understand the math; implement fresh against SwiftAA. Do **not** copy GPL/AGPL source and do **not** pull in their Swiss Ephemeris dependency.
- `webresh/drik-panchanga` (Python) — primary reference for the five-limb derivation and end-time interpolation, masa/adhika-masa, samvatsara, ahargana.
- `fusionstrings/panchangam` (TypeScript) — secondary, modern API shape and ayanamsa modes.
- `naturalstupid/PyJHora` (Python) — secondary, comprehensive muhurta/timing logic.

---

## 6. Architecture & Module Layout

```
PanchangApp/                      (app target — SwiftUI)
  App/                            app entry, root navigation
  Features/
    Today/                        TodayView + TodayViewModel
    Calendar/                     MonthView, DayDetailView + view models
    Settings/                     SettingsView + view model
    Locations/                    location search + saved-locations management
  Models/                         SwiftData @Model types (SavedLocation, Preferences, CachedDay)
  Services/
    LocationService/              CoreLocation wrapper (auto-detect, permissions)
    GeocodingService/             CLGeocoder: place search -> coords + timezone
    NotificationService/          UNUserNotificationCenter local notifications
    PanchangService/              thin app-facing facade over PanchangKit
  Resources/
    Festivals/                    bundled festival/vrat rule dataset (JSON)
    Localization/                 String catalogs; month/tithi/nakshatra name tables (Devanagari + transliteration + English)

PanchangKit/                      (local Swift Package — pure, no UIKit/SwiftUI, Sendable, fully unit-tested)
  Ephemeris/                      adapter over SwiftAA: sun/moon longitude(jd), rise/set(jd, location)
  Ayanamsa/                       Lahiri ayanamsa(jd); sidereal = tropical - ayanamsa
  Engine/
    Tithi, Nakshatra, Yoga, Karana, Vara    five limbs + end-time solving
    Muhurta                       Rahu Kalam, Yamaganda, Gulika, Abhijit, Brahma Muhurta
    LunarMonth                    masa naming, paksha, adhika/kshaya masa detection
    Year                          samvatsara/Vikram Samvat per calendar config
  Calendar/
    CalendarConfig                tradition presets (see §8)
    PanchangDay                   the assembled value-type result for a (date, location)
  Festivals/                      rules engine: resolve festival rules -> dates for a given day/range
Tests/
  PanchangKitTests/               golden vectors + per-function unit tests
```

---

## 7. Functional Requirements (v1)

1. **Today view** — for current date + active location, show:
   - Five limbs: tithi (+ paksha), vara, nakshatra, yoga, karana — each with end time.
   - Lunar month (masa) with adhika/kshaya flag; ritu (season); ayana.
   - Samvatsara / Vikram Samvat year per active calendar preset (§8).
   - Sun: sunrise, sunset. Moon: moonrise, moonset.
   - Auspicious/inauspicious windows: Rahu Kalam, Yamaganda, Gulika Kalam, Abhijit Muhurta, Brahma Muhurta.
2. **Day significance** — festivals, vrats (e.g. Ekadashi, Pradosh, Purnima/Amavasya, Sankranti, major festivals), and notable observances for the day, resolved from the festival rules engine.
3. **Location**
   - Auto-detect via CoreLocation (request permission appropriately; degrade gracefully if denied).
   - Manual search via CLGeocoder; resolve to coordinates + timezone.
   - Save multiple named locations; pick an active one; persist across launches.
4. **Calendar**
   - Month grid; navigate between months and years.
   - "Jump to date" via date picker (support a wide range, e.g. 1900–2100 in v1).
   - Tap any date → full day-detail screen (same content as Today view, for that date).
   - Optionally annotate grid cells with festival/vrat markers.
5. **Settings**
   - Calendar tradition preset (default = Gujarati/Western; see §8).
   - Ayanamsa (default Lahiri; expose others as inert options now, wired in v2).
   - Language/script display (Devanagari + transliteration + English).
   - Notification preferences.
6. **Notifications** — local notifications for upcoming festivals/vrats; optional daily panchang summary. Scheduled on-device.
7. **Offline** — all of the above functions with no network. Network is used only for (optional) festival-data refresh and CLGeocoder place lookups.

---

## 8. Calendar Conventions (core domain rules)

Two orthogonal axes, exposed to the user as **named presets** (not independent toggles, to prevent invalid combinations):

| Preset | Month-end convention | Year-start anchor | Notes |
|---|---|---|---|
| **Gujarati / Western** *(default)* | Amanta (ends at Amavasya / new moon) | Kartikadi (Kartik Shukla Pratipada, day after Diwali) | Bestu Varas / Nutan Varsh |
| **North Indian** | Purnimanta (ends at Purnima / full moon) | Chaitradi (Chaitra Shukla Pratipada) | Gudi Padwa / Ugadi timing |

Rules the engine must implement:

- **Amanta vs Purnimanta is a labeling transform, not a recomputation.** Compute the tithi stream and new/full-moon instants once (Amanta is the natural output). For Purnimanta display, shift the **Krishna-paksha (dark fortnight)** month label forward by one month; the **Shukla-paksha (bright fortnight)** label is identical in both systems.
- **Year-start anchor drives the Samvat increment.** Compute the displayed Vikram Samvat year from the configured anchor — do **not** hardcode. Under Kartikadi, the year increments at Kartik Shukla 1; under Chaitradi, at Chaitra Shukla 1. Consequence to verify in tests: between Chaitra and Kartik, the Gujarati/Kartikadi year reads **one less** than the North/Chaitradi year for the same calendar date.
- **Adhika masa (intercalary leap month, "Purushottam Maas")** — detect a lunar month containing no solar sankranti and label it adhika; the following month is nija. Handle the rare **kshaya masa** (a month "lost" when two sankrantis fall in one lunar month) at least without crashing. This applies under both presets.
- **Festival rules are stored canonically** (anchored to an unambiguous reference such as tithi + paksha relative to a solar/sankranti reference), so a festival resolves to the **same calendar date** regardless of preset; only its textual month attribution changes.
- **Month-name strings are data, not logic.** Keep a localizable table so Gujarati spellings (Kartak, Magshar, Posh, Maha, Fagan, Chaitra, Vaishakh, Jeth, Ashadh, Shravan, Bhadarvo, Aaso) and Sanskrit forms can both be supported.

---

## 9. Non-Functional Requirements

1. **Accuracy** — tithi / nakshatra / yoga transition times within ~1–2 minutes, and sunrise/sunset within ~1 minute, of the chosen authoritative reference. Enforced by golden vectors.
2. **Performance** — Today view computes in < ~100 ms; a month grid (≈30–42 cells) in < ~500 ms; scrolling stays smooth. Cache computed days in SwiftData.
3. **Privacy** — location never leaves the device. No analytics SDKs that transmit PII in v1. Minimal permissions, requested with clear purpose strings.
4. **Offline-first** — no network dependency for core functionality.
5. **Localization & accessibility** — Sanskrit terms shown in Devanagari with transliteration and English gloss; Dynamic Type; VoiceOver labels on all panchang values; sufficient color contrast in both light and Liquid-Glass appearances.
6. **Robustness** — defined behavior at high latitudes, date line, DST transitions, and intercalary months.
7. **Testability / maintainability** — `PanchangKit` has zero UI dependencies and is unit-tested in isolation; services are injected and mockable; the app target stays thin.

---

## 10. Data & Source of Truth

- **Method:** Drik (computed) panchang — astronomical positions + Lahiri ayanamsa.
- **Validation authority:** an established published panchang (e.g. Drik Panchang or the Rashtriya Panchang). Pick one, document it, and validate against it consistently.
- **Golden vectors:** ≈30 (date, location) pairs spanning different months, a leap (adhika) month, multiple latitudes, and at least one Gujarat location (e.g. Ahmedabad) and one North Indian location (e.g. Varanasi). Capture expected five-limb values + end times + sunrise/sunset from the authority; assert in `PanchangKitTests`.
- **Festival dataset:** bundled JSON of festival/vrat *rules* (tithi/paksha/month anchors), resolved by the rules engine — not a hardcoded list of dates. Curation/validation of regional nuance is a human task (see §14). Ship a clearly-marked **provisional** starter set. Allow optional refresh from a static hosted file (GitHub raw / CDN); never required for core use.

---

## 11. Build Order (milestones)

- **M0 — Scaffold.** Xcode project, `PanchangKit` SPM package, SwiftAA dependency, `.gitignore`, CI that runs tests. App launches to an empty Today screen.
- **M1 — Engine (the hard part first).** Ephemeris adapter, Lahiri ayanamsa, five limbs with end-times, sunrise/sunset/moonrise/moonset, lunar month + adhika detection, samvatsara, muhurta subset. Golden-vector test suite green. **This milestone is the acceptance gate; do not move on until vectors pass.**
- **M2 — Today view.** Render a full `PanchangDay` for current date + a default location. SwiftData models + caching.
- **M3 — Calendar.** Month grid, navigation, jump-to-date, day-detail screen.
- **M4 — Location & settings.** CoreLocation auto-detect, CLGeocoder search, saved locations, calendar-tradition preset, language/script setting.
- **M5 — Festivals & notifications.** Festival rules engine + bundled dataset; grid markers; local notifications.
- **M6 — Polish & localization.** Devanagari/transliteration tables, accessibility, Liquid Glass styling, empty/error states, edge-case handling.

---

## 12. Signing, Provisioning & Distribution

**Is a paid Apple Developer account needed?**

- **Simulator:** nothing required.
- **Running on a personal device (development/testing):** a **free** Apple ID is sufficient via Xcode's "Personal Team" free provisioning. Constraints: the signing certificate **expires after 7 days** (re-sign weekly), the App ID must be **explicit** (not a wildcard) and unique, and there are device-count limits. v1 uses **local** notifications only, which work under free provisioning.
- **Distribution (TestFlight or App Store):** requires the paid **Apple Developer Program — $99/year (USD)**. There is no free public-distribution path. This becomes relevant only when shipping/beta-testing, not during the build.

**The agent must NOT** create the Apple ID, enroll in the Developer Program, accept Apple's legal agreements, or enter payment details. These are the human's responsibility.

**What the agent configures in the project:**
- Bundle identifier: reverse-DNS, explicit (e.g. `com.<owner>.panchang`).
- Automatic signing enabled, with `DEVELOPMENT_TEAM` read from a git-ignored `Signing.xcconfig` (the human fills in their Team ID there; the agent references the variable, never a literal).
- `Info.plist` usage strings: `NSLocationWhenInUseUsageDescription` (location) and any notification prompt copy.
- Local-notification registration. **No** special entitlements (no push, no CloudKit) in v1.

**What the human does manually (out of scope for the agent):**
1. Sign an Apple ID into Xcode → Settings → Accounts (creates the Personal Team).
2. In the target's Signing & Capabilities, select the team; let Xcode resolve the profile.
3. On first device install, trust the developer profile: iPhone → Settings → General → VPN & Device Management.
4. Re-run weekly when the free-provisioning certificate expires.
5. Enroll in the $99/year Apple Developer Program **only when ready to distribute**, accepting Apple's agreements and payment personally.

---

## 13. Acceptance Criteria

- `PanchangKit` golden vectors pass within the §9 accuracy tolerances for all sample cases, including the adhika-month and multi-latitude cases.
- Tithi/karana are computed from Moon−Sun elongation **without** an ayanamsa term; nakshatra/yoga **with** it. (Explicit test: tithi is invariant to ayanamsa choice; nakshatra/yoga are not.)
- Switching tradition preset changes Krishna-paksha month labels and the displayed Samvat year correctly, while festival **dates** stay fixed.
- For a Gujarat location on a date between Chaitra and Kartik, the displayed Vikram Samvat year is one less than for the North Indian preset on the same date.
- Today view and arbitrary day-detail render every §7.1 field with correct end times and timings, fully offline.
- Calendar jump-to-date and month navigation work across the supported range; tapping a date opens its detail.
- App functions with location permission denied (manual location still works) and on a device in airplane mode (core features intact).
- No Team ID, certificate, or credential is present in the repository.

---

## 14. Open Questions / Human Inputs Needed

- **Golden-vector reference values.** Confirm the canonical comparison panchang and provide the exact expected values for the ≈30 sample cases; the agent must not fabricate these.
- **Festival dataset curation.** Regional vrat/festival rules (and Gujarat-specific observances) need review by a knowledgeable person before release; the starter set ships marked provisional.
- **App name / bundle identifier / icon.** Not decided.
- **Supported date range.** 1900–2100 assumed for v1; widen if needed.

---

## 15. V2 / Fast-Follow Backlog

- Full muhurta suite: Choghadiya (day & night), Hora, Gowri Panchangam, Dur Muhurtam, Varjyam, Amrit Kalam, Tara Bala / Chandra Bala.
- Astrology layer: rashi/lagna, planetary sidereal positions, Vimshottari dasha, basic kundli.
- Additional ayanamsa modes wired live (Raman, KP, True Chitra), with a UI to compare.
- iCloud/CloudKit sync of saved locations and preferences.
- Home-screen + Lock-screen widgets, Apple Watch complication, App Intents/Siri ("what's today's tithi?").
- Additional languages/scripts (Gujarati native glyph option, Hindi, English-only, regional South Indian scripts).
- Purnimanta refinements and additional regional presets (Telugu/Amanta-Chaitradi, Tamil solar, Bengali).
- Panchang sharing/export (image card, PDF of a month).
- Optional refreshable festival dataset pipeline + admin/curation workflow.
