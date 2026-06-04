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
- **Choghadiya** — 8 day segments (sunrise→sunset) + 8 night segments (sunset→next sunrise), each ~90 min. The seven Choghadiya names form a fixed repeating cycle (Udveg, Char, Labh, Amrit, Kaal, Shubh, Rog); a weekday-keyed **starting index** selects which name begins the day half, and a separate index begins the night half. The eighth segment of each half wraps the cycle. The weekday→start-index table is **sourced reference data** (see §5), like the existing Rahu-Kalam part table — do not invent it.
- **Hora** — 24 planetary hours (~1 h each) cycling from the day's ruling planet (Sunday=Sun, Monday=Moon, …). Each hora is 1/12 of the daytime or nighttime span.
- **Dur Muhurtam** — inauspicious windows derived from the Vara; 2 fixed windows per weekday (classical table — **sourced reference data**, see §5).
- **Varjyam** — inauspicious window; classically a fixed fraction of the **nakshatra's own span, measured from the nakshatra's start time** (per-nakshatra ghati offsets — **sourced reference data**, see §5). It is **not** an offset from moonrise (moonrise is `nil` ~once a month and would leave the window undefined). The engine already solves nakshatra start/end times — reuse them.
- **Amrit Kalam** — auspicious window; same basis as Varjyam (a fixed per-nakshatra fraction of the nakshatra span, measured from its start time).
- **Tara Bala** — birth-nakshatra-relative counting; requires user's janma nakshatra input.
- **Chandra Bala** — Moon's rashi relative to user's janma rashi; requires user's janma rashi input.

**Data types:**
```swift
public struct Choghadiya: Sendable {
    public enum Quality: Sendable { case good, bad, neutral }   // green / red / yellow
    public struct Segment: Sendable, Identifiable {
        public let id: Int
        public let name: String
        public let quality: Quality   // three classes — the UI shows three colours, so a Bool can't model "neutral"
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
- Choghadiya's 16 segments cover the full sunrise→next-sunrise interval with no gaps or overlaps. (That interval is ~24 h ± a few minutes — **not** exactly 24 h; do not assert `== 24h`.)
- Hora segments are equal-duration within each day/night half (12 + 12 = 24).
- Dur Muhurtam, Varjyam, and Amrit Kalam match the chosen authority within tolerance (Dur Muhurtam ±5 min; Varjyam / Amrit Kalam ±10 min) — **requires the new reference vectors named in §5; do not fabricate them.**

---

### M2 — Astrology Layer

**Scope:** Sidereal planetary positions, Vimshottari dasha, and a basic kundli (birth chart) screen. All computation in `PanchangKit`.

**Engine additions:**
- **Planetary positions** — sidereal (Lahiri) longitudes for Sun, Moon, Mars, Mercury, Jupiter, Venus, Saturn, Rahu, Ketu at a given JD. SwiftAA provides geocentric apparent ecliptic longitudes for the planets and `Moon.longitudeOfMeanAscendingNode` for Rahu/Ketu (mean node; Ketu = Rahu + 180°). Apply ayanamsa to convert tropical → sidereal. **This requires expanding the `Ephemeris` protocol** — today it exposes only `sunLongitude`/`moonLongitude` — with planet + node + sidereal-time accessors, and updating every synthetic test double that conforms to it. `isRetrograde` is not a SwiftAA property: derive it by sampling longitude over a small Δt and checking the sign of motion.
- **Rashi** — sidereal longitude / 30°, giving zodiac sign 0…11 (Aries…Pisces).
- **Lagna (Ascendant)** — requires latitude + local sidereal time. SwiftAA exposes both (`JulianDay.meanLocalSiderealTime` / `apparentGreenwichSiderealTime`). Compute the tropical ascendant via the standard oblique-ascension formula, then apply ayanamsa.
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
- `KPAyanamsa` — Krishnamurti Paddhati. Approximately Lahiri with a small offset, but the sign and magnitude vary by KP variant (KP-Old / KP-New / straight-line) — **source the exact constant from a published KP table**, do not hardcode a guess.
- `RamanAyanamsa` — B.V. Raman's ayanamsa formula.
- `TrueCitraAyanamsa` — pins Chitra (Spica) at exactly 180°. **SwiftAA ships no fixed-star catalog**, so Spica's position is not available out of the box: either add a Spica entry (J2000 RA/Dec + proper motion, precessed to the epoch) or implement the published True-Chitra formula. Resolve this dependency before starting M3.
- Update `Ayanamsa` protocol so all four modes (including existing `LahiriAyanamsa`) are hot-swappable.

**UI additions:**
- Settings: "Ayanamsa" picker with four options.
- In Day Detail, a small "ⓘ" info row showing the current ayanamsa value in degrees.

**Acceptance criteria:**
- All four ayanamsa values match published tables within ±0°01' for J2000.0 (requires the published per-mode reference values named in §5).
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
- Use `WidgetKit`. **Link `PanchangKit` directly into the widget extension and compute the `PanchangDay` inside the timeline provider.** The engine is pure, offline, and <100 ms, so the old "cache to a shared AppGroup, never recompute in the extension" approach is an unnecessary self-limitation — it leaves the widget showing yesterday's tithi until the app is next opened. Computing in the timeline provider lets the widget refresh correctly at midnight without the app running. An AppGroup is then only needed to share user preferences / active location with the extension (small, read-only), not the computed day.

**Apple Watch:**
- Complication showing tithi + paksha. Updates daily via `WKExtensionDelegate`.
- Companion Watch app (optional stretch): Today screen in watchOS SwiftUI.

**App Intents (Siri / Spotlight):**
- `TodayTithiIntent` — "What's today's tithi?" → spoken + visual response.
- `FestivalsIntent` — "What festivals are this week?" → list response.
- `MuhurtaIntent` — "When is Rahu Kalam today?" → time range response.
- Donate intents on app launch so Siri learns usage patterns.

**Project setup (human-in-Xcode — see §5):**
- The Widget, App-Intents, and (optional) Watch targets — plus their App Group and embed-extension wiring — should be created in the Xcode GUI. The project is currently a single target with a hand-maintained `project.pbxproj`; hand-editing it for multi-target extension wiring is the highest build-breakage risk in V2.

**Acceptance criteria:**
- Widget updates within 15 minutes of midnight (standard WidgetKit policy).
- All three Siri intents return correct spoken responses for today's date on device.
- Widget renders correctly at all iOS supported sizes.

---

### M5 — iCloud Sync

> **POSTPONED (2026-06-03).** Deferred while the app stays single-device / local-only. This shelves the paid Developer Program enrollment, the CloudKit container-ID confirmation, and the CloudKit-safe `AppModels` migration until cross-device sync is actually needed. M4/M6/M7/M8 do not depend on M5 (M4's widget computes in its own timeline provider, per the M4 note), so the build order simply skips M5 for now.

**Scope:** Sync saved locations, preferences, and birth profiles across the user's devices via CloudKit. No user account — uses the device's signed-in Apple ID.

**Architecture:**
- Use **two `ModelConfiguration`s in one `ModelContainer`**: one CloudKit-backed (`cloudKitDatabase: .private("iCloud.com.<owner>.panchang")`) holding the synced models (`SavedLocation`, `Preferences`, `BirthProfile`), and one **local-only** configuration holding `CachedDay`. A single configuration syncs *all* its models, so excluding `CachedDay` requires this split — you cannot just "swap" the one existing configuration.
- **CloudKit imposes model constraints SwiftData does not enforce locally:** every non-optional attribute must have a default value (or be made optional), `@Attribute(.unique)` is disallowed, and all relationships must be optional. The current models (`AppModels.swift`) declare non-optional, default-less stored properties — migrate them (add inline defaults / make optional) before enabling CloudKit, or the store will fail to initialise.
- Requires paid Developer Program + CloudKit capability (human-configured; see entitlements below).
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
- **Gujarati script** — parallel name tables in Gujarati (`ગુજરાતી`) for all five limbs, masa, vara, ritu. Note: `ScriptRenderer` lives in the **app layer** (`PanchangApp/Services/ScriptRenderer`) and keys off raw indices; the name *tables* (`PanchangNames`) live in `PanchangKit`. Add a `"gujarati"` mode to the renderer and the parallel tables to `PanchangNames`.
- Wire the existing `"devanagari"` mode throughout — audit all views for hardcoded strings that bypass `ScriptRenderer`.

**Calendar traditions:**
- **Telugu / Amanta-Chaitradi** — same *lunar* month system as the existing presets but Amanta months + Chaitradi anchor; expressible as a new `CalendarConfig` preset (a new `MonthEndConvention` + `YearAnchor` combination). Low risk.
- **Tamil solar** and **Bengali** are **solar calendars and need a new engine code path**, not a preset. The current engine labels a single *lunar* tithi stream (Amanta/Purnimanta); solar calendars have sankranti-based month boundaries and a solar new-year that do not fit the `MonthEndConvention` + `YearAnchor` model at all. Scope these as a separate `SolarCalendar` computation (solar longitude / 30° → rashi month) with its own month-name tables and new-year rule.
- **Solar festivals don't fit the current festival model.** `FestivalAnchor` is tithi/masa/vara-only; solar-date festivals (Pongal, Tamil/Bengali Sankranti) cannot be expressed. Either extend `FestivalAnchor` with a solar-date case or ship these traditions label-only (no solar festivals) for now — decide before building.

**Gowri Panchangam:**
- Five-element daily grid used in South Indian tradition (Rogam, Kalam, Labham, etc.), derived from vara + tithi using a fixed lookup table.
- Shown in Day Detail for South Indian presets.

**Acceptance criteria:**
- All Gujarati script names render correctly in the UI without truncation at standard font sizes.
- Tamil month names match drikpanchang.com for three test dates.
- Tradition switching does not affect *lunar* festival dates (only labelling). Solar-festival support, if added, is tested separately (see the festival-model note above).

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
- **Harden the loader first.** Today `FestivalService.shared` uses `try!` + force-unwraps, and the DTO's `toRule()` silently degrades unknown anchors to a default — it crashes on malformed JSON and does no real validation. Before adding refresh, rewrite it to: decode defensively (no `try!`/`!`), validate the schema + a `version` field, and **fall back to the bundled baseline on any failure**. This is the prerequisite that makes the "corrupt JSON silently rejected" criterion achievable.
- On app launch (when online), check a versioned URL (GitHub raw or CDN) for a newer dataset version. If newer: download, validate schema, store in the app's `Documents` directory. On next launch, prefer the downloaded file over the bundle (only if it passed validation).
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

**Reference data (hard prerequisites — the agent must not fabricate these; see SPEC.md §3.6):**
- **Golden vectors are currently mostly corrupt** — only the Washington-DC worked example and the San Jose Janmashtami case are trustworthy. Re-capture the ~30 clean cases from the chosen authority before relying on any "matches drikpanchang" criterion. This blocks the accuracy gates across V2.
- **Each new domain needs its own reference vectors**, captured from the authority before its milestone can pass: Choghadiya / Hora / Dur-Muhurtam / Varjyam / Amrit-Kalam windows and the Choghadiya weekday start-index + per-nakshatra Varjyam/Amrit offset tables (M1); planetary longitudes + Lagna + Vimshottari boundaries (M2); per-mode ayanamsa values at J2000.0 (M3); Gujarati name tables, Tamil/Bengali month names, and the Gowri-Panchangam lookup (M6).

**Project setup (human-in-Xcode, like signing):**
- **M4 extension targets** — create the Widget / App-Intents / Watch targets (and their App Group + embed-extension wiring) in the Xcode GUI. The project is a single target today with a hand-maintained `project.pbxproj`; multi-target surgery by hand is the highest build-breakage risk in V2.
- **CI** — `.github/workflows/ci.yml` pins Xcode 16.3 (spec assumes Xcode 26) and the app-build step ends with `| xcpretty || true`, which swallows build failures. Fix both and add the new targets to CI before trusting it to guard V2.

**Product decisions:**
- **Kundli chart style preference** — North Indian square or South Indian grid (or both selectable)?
- **Birth profile data** — How many profiles? Just self, or family members too?
- **CloudKit container identifier** — Confirm the bundle ID / iCloud container ID before M5. *(Deferred — M5 postponed 2026-06-03.)*
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
| M2 Astrology second | Heavy engine work; front-loaded so later milestones (Kundli transits, Day-Detail planetary rows) can reuse the planetary layer. Note: M1's Hora does *not* depend on planetary positions — it cycles planet names by weekday/hour — so M2 is not a prerequisite for M1. |
| M3 Ayanamsa third | Small engine change; must come before M4/M5 so widgets and sync use the right mode. |
| M4 Widgets fourth | Requires a stable engine + data model. With the widget computing in its own timeline provider (see M4), it no longer hard-depends on a shared container — but doing M4 before M5 still lets any AppGroup-shared preferences settle before CloudKit is layered on. |
| M5 Sync fifth — **POSTPONED** | Requires paid Developer Program + stable data model. Deferred 2026-06-03 while the app stays local-only; build order skips it (M6/M7/M8 don't depend on it). |
| M6 Scripts sixth | Pure data/UI work; no engine dependency. Can be parallelised with M5 by a second agent if desired. |
| M7 Sharing seventh | Requires stable UI (all screens finalized) so the card design doesn't need to change. |
| M8 Festival refresh last | Infrastructure; lowest risk if deferred. Depends on human curation completing first. |

---

## 7. Model & Effort Allocation

Match the model tier and thinking effort to the *kind* of work, not the milestone number. The governing rule: **correctness-critical astronomy and anything behind a golden-vector / reference gate gets the strongest model at high effort; mechanical UI, data-table, and boilerplate work gets a cheaper tier at low effort.** "Effort" = the agent's reasoning/thinking budget (low / medium / high / max). Tiers below are generic (Opus = strongest, then Sonnet, then Haiku) — use the strongest available build of each.

| Milestone | Model | Effort | Why |
|---|---|---|---|
| **M1 — Muhurta suite** | Opus | High | Correctness-critical astronomy behind a golden gate. The Varjyam/Amrit-from-nakshatra-span derivation, Choghadiya cycle indexing, and Hora division are easy to get subtly wrong. |
| **M2 — Astrology layer** | Opus | Max | Heaviest reasoning in V2 — Vimshottari dasha date math, Lagna oblique ascension, Navamsha, and the `Ephemeris` protocol expansion. The milestone most likely to ship wrong if under-resourced. |
| **M3 — Ayanamsa modes** | Opus | High | Small surface but real precession math, the TrueCitra/Spica gap, and the four-mode tithi/karana invariance test that must stay green. |
| **M4 — Widgets & integrations** | Sonnet | Medium | Mostly integration glue (WidgetKit, App Intents, timeline provider). Light algorithmic reasoning; the risk is fiddly target wiring. Bump to Opus only if the agent (not a human) must do the multi-target `project.pbxproj` surgery. |
| **M5 — iCloud sync** | Opus | Medium | Tiny code surface but architecturally subtle — dual `ModelConfiguration` split and the CloudKit model constraints are silent-failure traps that reward careful reasoning. |
| **M6 — Scripts (Gujarati, Gowri)** | Haiku → Sonnet | Low | Mechanical name-table and lookup-table data entry; verify rendering. |
| **M6 — Tamil/Bengali solar calendar** | Opus | High | This sub-part is a *new engine code path* (sankranti month boundaries, solar new-year) — same class of work as M2, not data entry. Do not let the "M6 is easy" framing apply here. |
| **M7 — Sharing & export** | Sonnet | Low–Medium | SwiftUI `ImageRenderer` + `PDFKit` rendering; no astronomy, no concurrency traps. |
| **M8 — Festival refresh** | Sonnet | Medium | Defensive loader rewrite, schema/version validation, networking with bundle fallback. Moderate care; no heavy reasoning. |

**Cross-cutting:**
- **Tests are part of the gate.** Author engine tests (M1–M3, M6-solar) at the *same* model/effort as the implementation — a weaker model writing weak tests defeats the golden-vector contract.
- **Verification is cheap.** Routine build / `swift test` / simulator-screenshot runs can be Haiku at low effort regardless of which tier wrote the code.
- **Escalate on red.** If a milestone's golden/reference vectors are still failing after two honest attempts, bump one model tier and one effort level before changing the approach — never weaken a test to pass (SPEC.md §3.3).
- **Reference-data capture and curation sign-off are human tasks**, not a model assignment (see §5).
