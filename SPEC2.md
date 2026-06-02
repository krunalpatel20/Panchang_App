# Panchang iOS App — V2 Specification

> **Purpose:** Build spec for an autonomous coding agent (Claude Code). V1 (SPEC.md) is complete and shipped. This document covers V2 feature clusters. The same agent operating rules from SPEC.md §3 apply here — read that section before writing any code.

---

## 1. V2 Goal

Deepen the app from a panchang viewer into a full Vedic almanac and astrology companion, while adding the platform integrations (widgets, Siri, Watch) and ecosystem features (sync, sharing, festival refresh) that make it a daily-use app.

V1 acceptance gate: all V1 milestones green, app live on device (or simulator). Do not begin V2 until V1 is complete.

---

## 2. Non-Goals (V2)

- No paid backend / API — local-first remains the architecture.
- No Swiss Ephemeris (AGPLv3 licensing trap — see SPEC.md §2).
- No user accounts or authentication.
- No social/community features.
- No Android port.
- Paid Developer Program enrollment is the human's responsibility (required for CloudKit, TestFlight, App Store — see SPEC.md §12).

---

## 3. Milestones

Build in order. Each milestone is a hard gate — do not begin the next until the current builds, runs, and its acceptance criteria pass.

### M1 — Expanded Muhurta Suite

**Scope:** Add the full daily muhurta grid to `PanchangKit` and surface it in the UI.

**Engine additions (PanchangKit):**
- **Choghadiya** — 8 day segments (sunrise→sunset) + 8 night segments (sunset→next sunrise), each ~90 min. Fixed weekday-keyed offset table determines which Choghadiya name starts each day. Names: Udveg, Char, Labh, Amrit, Kaal, Shubh, Rog, Kaal (day cycle); same names, different start offset for night.
- **Hora** — 24 one-hour planetary hours cycling from the day's ruling planet (Sunday=Sun, Monday=Moon, …). Each hora is 1/12 of the daytime or nighttime span.
- **Dur Muhurtam** — inauspicious windows derived from the Vara; 2 fixed windows per weekday (classical table).
- **Varjyam** — inauspicious window derived from the nakshatra; each nakshatra has a fixed offset from moonrise.
- **Amrit Kalam** — auspicious window derived from the nakshatra; fixed offset per nakshatra from moonrise.
- **Tara Bala** — birth-nakshatra-relative counting; requires user's janma nakshatra input.
- **Chandra Bala** — Moon's rashi relative to user's janma rashi; requires user's janma rashi input.

**Data types:**
```swift
public struct Choghadiya: Sendable {
    public struct Segment: Sendable, Identifiable {
        public let id: Int
        public let name: String
        public let isAuspicious: Bool
        public let start: Double   // JD
        public let end: Double     // JD
    }
    public let day: [Segment]    // 8 segments
    public let night: [Segment]  // 8 segments
}

public struct Hora: Sendable, Identifiable {
    public let id: Int
    public let planet: String
    public let start: Double
    public let end: Double
}
```

**UI additions:**
- New "Muhurta" tab (or expanded section in Day Detail) showing Choghadiya grid (colour-coded: green=auspicious, red=inauspicious, yellow=neutral), Hora list, Dur Muhurtam, Varjyam, Amrit Kalam.
- Tara Bala / Chandra Bala shown if janma nakshatra/rashi are set in Settings.

**Settings additions:**
- Janma Nakshatra picker (for Tara Bala).
- Janma Rashi picker (for Chandra Bala).

**Acceptance criteria:**
- Choghadiya day/night segments sum to exactly 24 hours (16 segments total cover full day).
- Hora segments are equal-duration within each day/night half.
- Dur Muhurtam windows match published drikpanchang.com values ±5 min for the golden-vector dates.
- Varjyam and Amrit Kalam windows match ±10 min.

---

### M2 — Astrology Layer

**Scope:** Sidereal planetary positions, Vimshottari dasha, and a basic kundli (birth chart) screen. All computation in `PanchangKit`.

**Engine additions:**
- **Planetary positions** — sidereal (Lahiri) longitudes for Sun, Moon, Mars, Mercury, Jupiter, Venus, Saturn, Rahu, Ketu at a given JD. Use SwiftAA's planet position APIs; apply ayanamsa to convert tropical → sidereal.
- **Rashi** — sidereal longitude / 30°, giving zodiac sign 0…11 (Aries…Pisces).
- **Lagna (Ascendant)** — requires latitude + sidereal time; use the standard oblique ascension formula.
- **Vimshottari dasha** — 120-year cycle keyed to Moon's nakshatra at birth (and its fraction traversed). Compute: mahadasha sequence, start/end dates; antardasha (sub-period) within the current mahadasha.
- **Navamsha (D9)** — sidereal longitude mod 3°20' × 9 → navamsha rashi.

**Data types:**
```swift
public struct PlanetaryPositions: Sendable {
    public struct Planet: Sendable, Identifiable {
        public let id: String      // "sun", "moon", "mars", …
        public let name: String
        public let longitude: Double   // sidereal, 0…360
        public let rashi: Int          // 0…11
        public let rashiName: String
        public let isRetrograde: Bool
    }
    public let planets: [Planet]
    public let lagna: Planet          // ascendant
    public let julianDay: Double
}

public struct VimshottariDasha: Sendable {
    public struct Period: Sendable, Identifiable {
        public let id: String
        public let planet: String
        public let start: Date
        public let end: Date
        public let isCurrent: Bool
    }
    public let mahadashas: [Period]
    public let currentAntardashas: [Period]
}
```

**UI additions:**
- New "Kundli" tab: birth date/time/place input, kundli chakra diagram (North Indian square or South Indian grid — user preference), planet positions table, Vimshottari dasha timeline.
- Birth details stored in SwiftData (`BirthProfile` model).
- Planetary positions available in Day Detail (for transit reading).

**Settings additions:**
- Kundli style: North Indian / South Indian.
- Multiple birth profiles (self + family members).

**Acceptance criteria:**
- Planetary longitudes match Astro.com (with Lahiri ayanamsa) within ±0°05' for three test dates.
- Lagna matches within ±1° for a known birth time/place pair.
- Vimshottari dasha start dates match drikpanchang.com within ±1 day.

---

### M3 — Additional Ayanamsa Modes

**Scope:** Let the user choose their ayanamsa; show live comparison. Engine change only — no new UI screens, just a picker in Settings.

**Engine additions (`PanchangKit`):**
- `KPAyanamsa` — Krishnamurti Paddhati (Lahiri + 0°0'6" offset; the KP value used in practice).
- `RamanAyanamsa` — B.V. Raman's ayanamsa formula.
- `TrueCitraAyanamsa` — pins Chitra (Spica) at exactly 180°; computed from SwiftAA's Spica position.
- Update `Ayanamsa` protocol so all four modes (including existing `LahiriAyanamsa`) are hot-swappable.

**UI additions:**
- Settings: "Ayanamsa" picker with four options.
- In Day Detail, a small "ⓘ" info row showing the current ayanamsa value in degrees.

**Acceptance criteria:**
- All four ayanamsa values match published tables within ±0°01' for J2000.0.
- Tithi/karana invariance test remains green for all four modes (ayanamsa must not affect elongation-based limbs).
- Nakshatra/yoga shift correctly between modes for the same date/location.

---

### M4 — Widgets & System Integrations

**Scope:** Home-screen and Lock-screen widgets, Apple Watch complication, App Intents for Siri.

**Widgets:**
- **Small widget** — today's tithi + paksha + vara.
- **Medium widget** — tithi, vara, nakshatra, next Rahu Kalam.
- **Large widget** — full five limbs + sunrise/sunset.
- **Lock-screen widget** — tithi name + paksha dot (inline or circular accessory).
- Use `WidgetKit`. Widgets read their data from a shared `AppGroup` container (write from main app, read from extension). No recomputation in the extension — cache the `PanchangDay` JSON to the shared container on each main-app launch/refresh.

**Apple Watch:**
- Complication showing tithi + paksha. Updates daily via `WKExtensionDelegate`.
- Companion Watch app (optional stretch): Today screen in watchOS SwiftUI.

**App Intents (Siri / Spotlight):**
- `TodayTithiIntent` — "What's today's tithi?" → spoken + visual response.
- `FestivalsIntent` — "What festivals are this week?" → list response.
- `MuhurtaIntent` — "When is Rahu Kalam today?" → time range response.
- Donate intents on app launch so Siri learns usage patterns.

**Acceptance criteria:**
- Widget updates within 15 minutes of midnight (standard WidgetKit policy).
- All three Siri intents return correct spoken responses for today's date on device.
- Widget renders correctly at all iOS supported sizes.

---

### M5 — iCloud Sync

**Scope:** Sync saved locations, preferences, and birth profiles across the user's devices via CloudKit. No user account — uses the device's signed-in Apple ID.

**Architecture:**
- Swap the existing `ModelConfiguration` to use a `CloudKitContainer` identifier (requires paid Developer Program + CloudKit capability).
- SwiftData's `ModelConfiguration(cloudKitDatabase: .private("iCloud.com.<owner>.panchang"))` handles sync automatically for `@Model` types.
- `CachedDay` must be excluded from sync (device-local only, large, no value syncing).
- Add a sync status indicator in Settings.

**Entitlements needed (human configures in Xcode):**
- `com.apple.developer.icloud-services` → `CloudKit`
- `com.apple.developer.icloud-container-identifiers` → `iCloud.com.<owner>.panchang`

**Acceptance criteria:**
- A saved location added on Device A appears on Device B within 60 seconds (both online).
- Preferences (tradition, script, ayanamsa) sync correctly.
- App remains fully functional with iCloud disabled or in airplane mode (local store unaffected).
- `CachedDay` records do not appear in CloudKit dashboard.

---

### M6 — Additional Scripts & Calendar Traditions

**Scope:** Gujarati native script, additional regional calendar presets, Gowri Panchangam.

**Scripts:**
- **Gujarati script** — parallel name tables in Gujarati (`ગુજરાતી`) for all five limbs, masa, vara, ritu. Same `ScriptRenderer` architecture; add `"gujarati"` mode.
- Wire the existing `"devanagari"` mode throughout (it's in the engine; verify all views use `ScriptRenderer` — audit any hardcoded strings).

**Calendar traditions:**
- **Telugu / Amanta-Chaitradi** — same month system as North Indian but Chaitradi year anchor, different festival set.
- **Tamil solar** — Surya Siddhanta solar calendar (rashi-based months, Tamil month names). Engine: solar longitude / 30° → Tamil month.
- **Bengali** — Bengali solar calendar (similar to Tamil but different epoch).
- Each tradition is a `CalendarConfig` preset; the existing `MonthEndConvention` + `YearAnchor` enum is extended with new cases.

**Gowri Panchangam:**
- Five-element daily grid used in South Indian tradition (Rogam, Kalam, Labham, etc.), derived from vara + tithi using a fixed lookup table.
- Shown in Day Detail for South Indian presets.

**Acceptance criteria:**
- All Gujarati script names render correctly in the UI without truncation at standard font sizes.
- Tamil month names match drikpanchang.com for three test dates.
- Tradition switching does not affect festival dates (only labelling).

---

### M7 — Sharing & Export

**Scope:** Share a panchang image card; export a full month as PDF.

**Day card sharing:**
- A `PanchangCard` SwiftUI view that renders a full-day summary as a shareable image (1080×1080, suitable for Instagram/WhatsApp).
- Uses `ImageRenderer` (iOS 16+) to produce a `UIImage`.
- Share button in Day Detail triggers the standard `UIActivityViewController`.
- Card design: date, tithi, nakshatra, vara, key timings, festival if any. Branded with app name + "Provisional data" watermark.

**Monthly PDF export:**
- A "Export Month" button in Calendar view.
- Renders all 28–31 days as a table: date | tithi | nakshatra | yoga | vara | sunrise | festivals.
- Uses `UIPrintFormatter` or a custom `PDFKit` render.
- Share via `UIActivityViewController`.

**Acceptance criteria:**
- Exported image and PDF are readable at standard sizes.
- All data in the export matches what is shown on-screen for the same date.
- Export works fully offline.

---

### M8 — Festival Dataset Refresh Pipeline

**Scope:** Optional over-the-air refresh of the festival rules dataset, plus curation tooling.

**Architecture:**
- The bundled `festivals.json` (V1) is the baseline.
- On app launch (when online), check a versioned URL (GitHub raw or CDN) for a newer dataset version. If newer: download, validate schema, store in the app's `Documents` directory. On next launch, prefer the downloaded file over the bundle.
- The check is silent — no UI unless the update fails validation (show a subtle settings badge).
- The hosted file is the same JSON schema as the V1 bundle; just add new entries or correct existing ones.
- Remove the "provisional" label from `festivals.json` only after human curation review.

**Curation tooling (out of scope for agent — human task):**
- A simple web form or spreadsheet the human fills to curate/correct festival rules.
- A CI script that validates the JSON schema and publishes to the CDN.

**Acceptance criteria:**
- A festival added to the hosted JSON appears in the app within one launch after the device goes online.
- Corrupt or schema-invalid hosted JSON is silently rejected; bundled baseline continues to work.
- No network call is made in airplane mode.

---

## 4. Acceptance Criteria (V2 overall)

- All V1 acceptance criteria (SPEC.md §13) remain green.
- Choghadiya 16-segment coverage and Hora equal-duration invariants pass for all golden-vector dates.
- Planetary positions within ±0°05' of Astro.com reference for three test dates.
- Vimshottari dasha boundaries within ±1 day of drikpanchang.com reference.
- All four ayanamsa modes within ±0°01' of published tables at J2000.0.
- Tithi/karana ayanamsa-invariance test green for all four modes.
- Widgets render and update on both iPhone and iPad.
- Siri intents return correct spoken responses on-device.
- iCloud sync round-trip ≤60 seconds between two devices.

---

## 5. Open Questions / Human Inputs Needed

- **Kundli chart style preference** — North Indian square or South Indian grid (or both selectable)?
- **Birth profile data** — How many profiles? Just self, or family members too?
- **CloudKit container identifier** — Confirm the bundle ID / iCloud container ID before M5.
- **Festival curation** — Review and sign off on the provisional festival dataset before removing the "provisional" label (M8 dependency).
- **CDN / hosting for festival refresh** — GitHub raw is simplest; confirm acceptable.
- **Watch app scope** — Full watchOS companion app, or just a complication?
- **Sharing card design** — Any brand guidelines, colour palette, or logo to incorporate?
- **Telugu/Tamil/Bengali traditions** — Which takes priority? Confirm regional accuracy before shipping.

---

## 6. Milestone Order Rationale

| Order | Reason |
|-------|--------|
| M1 Muhurta first | Pure engine extension, no new dependencies, high user value, validates the existing muhurta architecture before adding more. |
| M2 Astrology second | Heavy engine work; doing it early means subsequent milestones can reuse planetary data (e.g. Hora in M1 uses it indirectly). |
| M3 Ayanamsa third | Small engine change; must come before M4/M5 so widgets and sync use the right mode. |
| M4 Widgets fourth | Requires stable engine + data model; WidgetKit needs the shared container set up before M5 CloudKit. |
| M5 Sync fifth | Requires paid Developer Program + stable data model. Comes after widgets so the shared AppGroup is already wired. |
| M6 Scripts sixth | Pure data/UI work; no engine dependency. Can be parallelised with M5 by a second agent if desired. |
| M7 Sharing seventh | Requires stable UI (all screens finalized) so the card design doesn't need to change. |
| M8 Festival refresh last | Infrastructure; lowest risk if deferred. Depends on human curation completing first. |
