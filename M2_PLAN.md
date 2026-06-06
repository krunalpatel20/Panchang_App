# M2 — Astrology Layer: Execution Plan

> **Model / Effort:** Opus / Max for all engine + test authoring (SPEC2 §7).
> Cheaper tier acceptable for chart-layout UI and routine build/test runs.
> Do not begin until M1 `swift test` is fully green and committed.

---

## 0. Where M1 left us

- `swift test` green: 16 tests / 5 suites / 17 parametrised clean golden cases.
- Ritu/ayana tropical fix + 19-case strict gate in commit `8ef32b4`.
- Existing architecture M2 builds on:
  - `Ephemeris`/`Ayanamsa` DI protocols — `Panchang.swift:10`
  - Sidereal conversion already correct — `FiveLimbs.swift:59`
  - Rashi-from-longitude — `FiveLimbs.swift:145`
  - Bisection root-finder — `AngleMath.swift`
  - Janma pickers + `TaraBala`/`ChandraBala` — M1 output, M2 auto-derives from birth profile

---

## 1. Prerequisites — capture these before writing gated tests

### 1.1 Human captures (do NOT fabricate — SPEC §3.6)

| Gate | What to capture | Source | Tolerance |
|---|---|---|---|
| **Planetary longitudes** | Sidereal (Lahiri) lon of Sun, Moon, Mars, Mercury, Jupiter, Venus, Saturn, Rahu, Ketu + retrograde flag for **3 dates** | **Swiss Ephemeris** (pyswisseph, SIDM_LAHIRI) — already computed and in fixture | ±0°05′ |
| **Lagna** | Sidereal ascendant for ≥1 known birth (exact date, local time, lat/lon/tz) | **Swiss Ephemeris** — already computed for the same 3 dates | ±1° |
| **Vimshottari boundaries** | For same birth: start lord, balance, all 9 mahadasha start dates, current antardasha sub-boundaries | **drikpanchang.com** — still needs human capture | ±1 day |

**Planets and Lagna are already captured** via pyswisseph (SIDM_LAHIRI) for 3 San Jose dates that overlap the existing golden vectors — the fixture `m2_astrology_vectors.json` has real values. Dates chosen for retrograde coverage: Mercury ℞ (2024-08-26), Mars ℞ + Jupiter ℞ (2024-12-21), Venus ℞ (2025-03-09).

**Only the `dasha` section still needs human input** — provide a real birth date/time/location to drikpanchang.com and fill in the `TODO` fields.

**Fixture file:** `PanchangKit/Tests/PanchangKitTests/Fixtures/m2_astrology_vectors.json` — planetary section complete; dasha section awaiting your capture.

**Register in Package.swift** (add alongside existing fixture declarations):
```swift
.copy("Fixtures/m2_astrology_vectors.json"),
```

### 1.2 Fix CI before trusting it (SPEC2 §5)

File: `.github/workflows/ci.yml`

Two problems to fix in the same commit before M2 engine work:

1. **Xcode pin** — currently `Xcode_16.3`; update to the version actually on the runner (Xcode 26 / the spec's assumed SDK). If Xcode 26 is not yet on `macos-15` runners, pin the closest available and document the delta.
2. **Swallowed build failures** — the app-build step ends with `| xcpretty || true`. Remove `|| true` and add `set -o pipefail` (or switch to `xcodebuild … 2>&1 | xcpretty; exit ${PIPESTATUS[0]}`) so a broken app build actually fails CI.

---

## 2. Engine changes — `PanchangKit`

### 2.1 Expand `Ephemeris` protocol

File: `PanchangKit/Sources/PanchangKit/Ephemeris/Ephemeris.swift`

Add a `Graha` enum and four new protocol members. Keep all existing members intact — the limb engine is untouched, zero regression risk.

```swift
public enum Graha: String, Sendable, CaseIterable {
    case sun, moon, mars, mercury, jupiter, venus, saturn
}

public protocol Ephemeris: Sendable {
    // Existing — do not change:
    func sunLongitude(julianDay: Double) -> Double
    func moonLongitude(julianDay: Double) -> Double
    func riseTransitSet(body: Body, anchorJulianDay: Double, location: GeoLocation) -> RiseSet

    // M2 additions:
    /// Tropical geocentric apparent ecliptic longitude of a graha, degrees [0, 360).
    func longitude(of graha: Graha, julianDay: Double) -> Double
    /// Tropical longitude of the Moon's MEAN ascending node (Rahu), degrees [0, 360).
    /// Ketu = normalize360(rahuLon + 180).
    func lunarNodeLongitude(julianDay: Double) -> Double
    /// Apparent Greenwich sidereal time in degrees [0, 360). Used to compute Lagna.
    func greenwichApparentSiderealTime(julianDay: Double) -> Double
    /// True obliquity of the ecliptic in degrees. Used to compute Lagna.
    func obliquityOfEcliptic(julianDay: Double) -> Double
}
```

### 2.2 Update every conformer (exactly two)

**`SwiftAAEphemeris.swift`**

SwiftAA API notes (verified in the checkout):
- Sun/Moon: use `.apparentEclipticCoordinates.celestialLongitude.value` (already done).
- **Planets** (`Mars`, `Mercury`, `Jupiter`, `Venus`, `Saturn`): use
  `Planet(julianDay:).equatorialCoordinates.makeEclipticCoordinates().celestialLongitude.value`
  (`heliocentricEclipticCoordinates` is heliocentric — wrong for geocentric positions).
- **Rahu**: `Moon(julianDay:).longitudeOfMeanAscendingNode.value` (mean node, matches drikpanchang default).
- **Sidereal time**: `JulianDay(jd).apparentGreenwichSiderealTime().inDegrees.value` — multiply by 15 if the API returns Hours.
- **Obliquity**: derive from SwiftAA's Earth/nutation mean obliquity + nutation-in-obliquity (true obliquity). Check `Earth` / nutation APIs in the checkout for the exact call.

**`StructuralTests.swift` — `LinearEphemeris`**

Only one test double exists. Update it with synthetic linear/constant values so it compiles:

```swift
func longitude(of graha: Graha, julianDay: Double) -> Double {
    // Use a distinct constant per graha so tests can distinguish them.
    AngleMath.normalize360(Double(graha.hashValue) * 30 + 0.5 * (julianDay - jd0))
}
func lunarNodeLongitude(julianDay: Double) -> Double { 120.0 }   // constant; always retrograde
func greenwichApparentSiderealTime(julianDay: Double) -> Double { 45.0 }
func obliquityOfEcliptic(julianDay: Double) -> Double { 23.45 }
```

### 2.3 New engine files

Create directory: `PanchangKit/Sources/PanchangKit/Astrology/`

```
Astrology/
  PlanetaryPositions.swift    — PlanetaryPositions struct + Planet; computePositions()
  Lagna.swift                 — pure oblique-ascension trig (unit-testable, no SwiftAA)
  VimshottariDasha.swift      — lord table, balance, mahadasha + antardasha date math
  Navamsha.swift              — D9 sign (continuous formula)
  Astrology.swift             — facade: Astrology(ephemeris:ayanamsa:)
```

#### `PlanetaryPositions.swift`

```swift
public struct PlanetaryPositions: Sendable {
    public struct Planet: Sendable, Identifiable {
        public let id: String          // "sun", "moon", "mars", …, "rahu", "ketu"
        public let name: String
        public let longitude: Double   // sidereal, 0…360
        public let rashi: Int          // 0…11
        public let rashiName: String
        public let nakshatra: Int      // 0…26 (add; chart and Vimshottari need it)
        public let navamshaRashi: Int  // 0…11 (D9)
        public let isRetrograde: Bool
    }
    public let planets: [Planet]       // 7 grahas + Rahu + Ketu = 9 entries
    public let lagna: Planet           // ascendant; isRetrograde always false
    public let julianDay: Double
}
```

**Retrograde derivation:**
```
Δ = AngleMath.normalize180(lon(jd + 0.5) − lon(jd))
isRetrograde = Δ < 0
```
Special cases: Sun and Moon are **never** retrograde → `false`. Rahu and Ketu are **always** retrograde (mean node regresses) → `true`.

#### `Lagna.swift`

```swift
// Pure function — no ephemeris dependency. Testable without SwiftAA.
enum Lagna {
    /// Tropical ascendant from astronomical inputs (Meeus ch. 47).
    /// - lstDeg: local apparent sidereal time in degrees [0, 360) (RAMC for this longitude).
    /// - latitude: geographic latitude in degrees.
    /// - obliquity: true obliquity of the ecliptic in degrees.
    /// Returns tropical ecliptic longitude of the ascendant, degrees [0, 360).
    static func tropicalAscendant(lstDeg: Double, latitude: Double, obliquity: Double) -> Double {
        let θ = lstDeg.toRadians
        let φ = latitude.toRadians
        let ε = obliquity.toRadians
        // Oblique-ascension ascendant (Meeus). NOTE the sign convention:
        //   atan2(cos θ, -(sin θ·cos ε + tan φ·sin ε))
        // The "obvious" atan2(-cos θ, …) yields the DESCENDANT — exactly 180° off.
        // Validated against Swiss Ephemeris swe.houses_ex() to <0.01° incl. 59°N / 33°S.
        let λ = atan2(cos(θ), -(sin(θ) * cos(ε) + tan(φ) * sin(ε)))
        return AngleMath.normalize360(λ.toDegrees)
    }
}
```

Compute LST from the ephemeris: `GAST_deg + location.longitude` (normalize to [0,360)).
Sidereal ascendant: `normalize360(tropicalAscendant − ayanamsa(jd))`.

> **Why the fixture Lagna comes from `swe.houses_ex()` and not this formula:** seeding the
> reference with the same formula under test is circular — a sign bug hides in both and the
> test passes green. The fixture values were independently generated by SE's house engine;
> this formula was then verified against them. (2026-06-05: the first draft of this formula
> had the descendant bug; the independent check caught it.)

#### `VimshottariDasha.swift`

Lord cycle (fixed order, starting at Ketu):
```swift
static let lords: [(Graha, years: Double)] = [
    (.ketu, 7), (.venus, 20), (.sun, 6), (.moon, 10), (.mars, 7),
    (.rahu, 18), (.jupiter, 16), (.saturn, 19), (.mercury, 17)
]  // Σ = 120
```

Nakshatra → starting lord index: `nakshatraIndex % 9` (Ashwini/Magha/Mula → Ketu = index 0).

Balance of first dasha:
```swift
let fraction = 1.0 − (siderealMoonLon.truncatingRemainder(dividingBy: nakshatraArc)) / nakshatraArc
```

**Year constant: 365.25 days** — confirmed by measuring drikpanchang's interval between consecutive mahadasha dates (e.g. Rahu→Jupiter = exactly 18 calendar years = 6574 days ≈ 18 × 365.25).

**⚠️ Ayanamsa divergence — absolute date gate is NOT achievable against drikpanchang.** Investigation (2026-06-05) found that drikpanchang's Lahiri constant differs from SE/SwiftAA `SIDM_LAHIRI` by ~0.142°, shifting the computed Moon longitude at birth by that amount. Over an 18-year Rahu dasha this produces ~5-day offsets in mahadasha starts. Accumulated drift also shifts antardasha boundaries by ~18 days. The SPEC2 ±1-day gate cannot be met against drikpanchang for absolute dates. **Revised test strategy: structural gate only** (see Phase D/C below).

Do all arithmetic in JD; convert to `Date` at `Period` boundaries only (avoids DST ambiguity — obs 162 in session memory).

```swift
public struct VimshottariDasha: Sendable {
    public struct Period: Sendable, Identifiable {
        public let id: String
        public let planet: String
        public let start: Date
        public let end: Date
        public let isCurrent: Bool
    }
    public let mahadashas: [Period]           // all 9
    public let currentAntardashas: [Period]   // sub-periods of the current mahadasha
}
```

#### `Navamsha.swift`

```swift
// Continuous formula (equivalent to the classical movable/fixed/dual rule):
static func navamshaRashi(siderealLon: Double) -> Int {
    let nakshatraPada = floor(siderealLon / (10.0 / 3.0))  // each pada = 3°20′
    return Int(nakshatraPada.truncatingRemainder(dividingBy: 12))
}
```

Hand-check anchors: Aries 0° → 0 (Mesha) ✓; Taurus 30° → 9 (Makara) ✓; Gemini 60° → 6 (Tula) ✓.

#### `Astrology.swift`

```swift
public struct Astrology: Sendable {
    private let ephemeris: Ephemeris
    private let ayanamsa: Ayanamsa

    public init(ephemeris: Ephemeris = SwiftAAEphemeris(), ayanamsa: Ayanamsa = LahiriAyanamsa()) {
        self.ephemeris = ephemeris
        self.ayanamsa = ayanamsa
    }

    public func positions(julianDay: Double, location: GeoLocation) -> PlanetaryPositions { … }
    public func dasha(birthJulianDay: Double, birthMoonLon: Double) -> VimshottariDasha { … }
}
```

---

## 3. Name tables

File: `PanchangKit/Sources/PanchangKit/Names/PanchangNames.swift`

`rashi` (12 signs) already exists at line 28 — reuse it. Add:

```swift
/// 9 graha (planet) names in Sanskrit transliteration, matching drikpanchang labels.
/// Index order matches VimshottariDasha lord cycle starting at Ketu.
public static let graha: [String] = [
    "Ketu", "Venus", "Sun", "Moon", "Mars", "Rahu", "Jupiter", "Saturn", "Mercury"
]

/// Vimshottari dasha years per lord, in lord-cycle order (Ketu first).
public static let dashaYears: [Double] = [7, 20, 6, 10, 7, 18, 16, 19, 17]

/// Nakshatra-to-starting-lord mapping: nakshatra index mod 9 = lord cycle index.
/// (Ashwini/Magha/Mula → 0 = Ketu; Bharani/Purva Phalguni/Purva Ashadha → 1 = Venus; …)
```

---

## 4. App-layer changes

### 4.1 `AppModels.swift` — add `BirthProfile`

```swift
@Model final class BirthProfile {
    var name: String
    var birthInstant: Date          // UTC; do not store wall-clock decomposed (DST trap)
    var latitude: Double
    var longitude: Double
    var timeZoneIdentifier: String
    var isPrimary: Bool
    var createdAt: Date

    init(name: String, birthInstant: Date, latitude: Double, longitude: Double,
         timeZoneIdentifier: String, isPrimary: Bool = false) { … }
}
```

Register in `PanchangApp.swift`:
```swift
let schema = Schema([SavedLocation.self, Preferences.self, CachedDay.self, BirthProfile.self])
```

Add to `Preferences`:
```swift
var kundliStyle: String = "north"    // "north" | "south"
```

**When a profile is marked primary:** auto-derive `Preferences.janmaNakshatra`/`janmaRashi`
from the Moon's sidereal nakshatra/rashi at birth — fills M1's Tara/Chandra Bala inputs without asking the user twice.

> M5 note (CloudKit, postponed): when M5 returns, every attribute in `BirthProfile` needs
> a default value or must be optional per CloudKit's model constraints (SPEC2 §M5).

### 4.2 New Kundli tab — `PanchangApp/Features/Kundli/`

```
Kundli/
  KundliView.swift            — tab root; profile picker or empty-state prompt
  BirthProfileFormView.swift  — add/edit a birth profile (name, DatePicker, location reuse)
  ChartView.swift             — SwiftUI Canvas/Path chart (N or S layout per kundliStyle)
  PlanetTableView.swift       — planet | rashi | degrees | nakshatra | ℞ flag
  DashaTimelineView.swift     — mahadashas list; current highlighted; tap → antardashas
  KundliViewModel.swift       — @Observable; loads Astrology().positions + .dasha
```

Register in `PanchangApp.swift` `TabView`:
```swift
KundliView()
    .tabItem { Label("Kundli", systemImage: "circle.grid.3x3") }
```

### 4.3 Day Detail transit row

Add a "Planetary Positions" section to `DayDetailView.swift`.
Uses `Astrology().positions(julianDay: day.timings.sunrise ?? …, location: day.location)`.
No birth profile needed — transit reading.

### 4.4 Settings additions

In `SettingsView.swift`, add:
- Kundli-style picker: `"North Indian"` / `"South Indian"`.
- "Birth Profiles" → `NavigationLink` to profile list.
- The existing `janmaSection` can become read-only / derived once a primary profile exists (show derived value, not a picker).

---

## 5. Phased execution — each phase must be green before the next

Run `swift test` in `PanchangKit/` after every engine change. Never proceed on red.
Commit at each green phase. Short imperative messages; no Co-Authored-By.

| Phase | Work | Gate |
|---|---|---|
| **A** | Expand `Ephemeris`; update `SwiftAAEphemeris` + `LinearEphemeris`; implement `PlanetaryPositions` (sidereal, rashi, retrograde, navamsha) | Structural invariants: indices in range; sidereal = tropical − ayanamsa; Rahu/Ketu always ℞ & 180° apart; Sun/Moon never ℞ |
| **B** | `Lagna.tropicalAscendant` (pure fn); sidereal ascendant in `Astrology`; add to `PlanetaryPositions.lagna` | Ascendant sweeps ≈360° over 24h; navamsha hand-check anchors; ayanamsa-shift unit test |
| **C** | `VimshottariDasha`: lord table, balance, all 9 mahadashas, antardasha sub-periods | Mahadashas Σ≈120 yr; order correct; balance ∈ (0,1]; antardashas sum to mahadasha span; exactly one `isCurrent`; deterministic from fixed birth JD |
| **D** | `m2_astrology_vectors.json` is **complete** (planetary + lagna from SE; dasha from drikpanchang); write parametrised reference tests | Planetary lons ±0°05′ (SE→SwiftAA, same VSOP87+Lahiri); Lagna ±1°; **dasha: structural gate only** — lord order correct, Σ≈120 yr, sub-period durations match classical formula ±2 days, exactly one `isCurrent`. Absolute dasha dates NOT gated vs drikpanchang (ayanamsa divergence ~0.142° → ~5-day offset, outside ±1 day — documented in fixture). |
| **E** | Extend `InvarianceTests.swift` for M2 | Tithi/karana unchanged when ayanamsa swapped (existing); every sidereal position shifts by the same Δ; retrograde flags unchanged |
| **F** | `BirthProfile` SwiftData model; `PanchangApp.swift` schema; `Kundli/` tab (form, chart N+S, planet table, dasha timeline); Day-Detail transit row; Settings additions | `xcodebuild build` green; simulator screenshot of Kundli tab with chart, table, dasha |
| **G** | Full milestone gate + CI fix | `swift test` + `xcodebuild test` green; all V1 golden vectors still green; CI Xcode pin fixed + `|| true` removed; commit |

---

## 6. Acceptance criteria (SPEC2 M2 + V2 §4)

| Criterion | Tolerance | Verified by |
|---|---|---|
| Sidereal planetary longitudes (SE as reference, 3 dates × 9 bodies) | ±0°05′ | Phase D |
| Lagna (SE as reference, 3 dates) | ±1° | Phase D |
| Vimshottari **lord order** correct (Ketu cycle, start lord from nakshatra) | exact | Phase C + D |
| Vimshottari **Σ mahadashas** ≈ 120 years | < 1 day | Phase C |
| Vimshottari **sub-period durations** match classical formula | ±2 days each | Phase D |
| Exactly one mahadasha `isCurrent` at any query date | exact | Phase C |
| Absolute mahadasha/antardasha dates vs drikpanchang | ⚠️ **not gated** — ~5-day systematic offset from ayanamsa divergence; fixture values are informational | — |
| Tithi/karana ayanamsa-invariant | exact | Phase E |
| Sidereal positions shift uniformly with ayanamsa | — | Phase E |
| All V1 golden vectors still green | per SPEC §9 | every phase |

---

## 7. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Reference-data capture stalls Phases D–G | Start Phases A–C and E day one (no reference needed); hand human the capture checklist immediately |
| Planet geocentric longitude — using heliocentric by mistake | Single tested helper; SwiftAA route: `equatorialCoordinates → makeEclipticCoordinates()`; ±0°05′ gate catches error |
| Vimshottari year-length constant | **Resolved: 365.25** (confirmed by measuring drikpanchang's Rahu→Jupiter interval = 18 × 365.25 days) |
| drikpanchang ayanamsa divergence (~0.142°) → ~5-day dasha offset | **Known, documented.** Test gates only structure (lord order, durations, isCurrent), not absolute dates vs drikpanchang. Absolute dates in fixture are informational only. |
| Lagna quadrant/sign error (silent ±180°) | Pure unit-testable `Lagna.tropicalAscendant`; ±1° gate; cross-check Meeus ch. 47 + PyJHora |
| DST in dasha date arithmetic | All arithmetic in JD; `Date` only at `Period` boundaries (avoids `Calendar.date(from:)` ambiguity, obs 162) |
| `LinearEphemeris` breaks on protocol expansion | Only one test double; update in same commit as protocol |
| Mean vs true node divergence | Use mean node (matches drik default); document explicitly |

---

## 8. Reference vector fixture — status

File: `PanchangKit/Tests/PanchangKitTests/Fixtures/m2_astrology_vectors.json`

**Fixture is complete.** No more human input required for M2 to start.

| Section | Status | Source |
|---|---|---|
| Planetary longitudes (3 dates × 9 bodies) | ✅ Real values | pyswisseph 2.10.3 (SIDM_LAHIRI) |
| Lagna (3 dates, San Jose) | ✅ Real values | pyswisseph 2.10.3 (SIDM_LAHIRI) |
| Vimshottari dasha (birth 1986-02-20, Vadodara) | ✅ Real values | drikpanchang.com |

**Dates chosen** (all San Jose, overlapping existing golden vectors for Sun/Moon cross-check):
- `sanjose-2024-08-26` — Mercury ℞, Saturn ℞
- `sanjose-2024-12-21` — Mars ℞, Jupiter ℞ (winter solstice)
- `sanjose-2025-03-09` — Venus ℞

**Still needed before running tests:**
Register the fixture in `Package.swift`:
```swift
.copy("Fixtures/m2_astrology_vectors.json"),
```

---

## 9. Open product decisions (defaults used unless you say otherwise)

| Question | Default applied |
|---|---|
| Kundli chart style | **Both selectable** (N Indian default); `Preferences.kundliStyle` |
| Birth profiles | **Multiple** (self + family); one marked primary |

---

## 10. Definition of done

- `swift test` green; all V1 golden vectors still passing.
- Planetary longitudes ±0°05′ vs Swiss Ephemeris reference (3 dates × 9 bodies). Phase D.
- Lagna ±1° vs Swiss Ephemeris reference (3 dates). Phase D.
- Vimshottari structure gates green: lord order, Σ≈120 yr, sub-period durations ±2 days, exactly one `isCurrent`. Phase C + D.
- Ayanamsa-invariance extended for M2 (positions shift, tithi/karana unchanged). Phase E.
- `xcodebuild build` green; Kundli tab renders chart (N + S modes), planet table, and dasha timeline on simulator. Phase F.
- `BirthProfile` persists and auto-derives `janmaNakshatra`/`janmaRashi` from primary profile. Phase F.
- CI Xcode pin updated; `xcpretty || true` removed. Phase G.
- `m2_astrology_vectors.json` registered in `Package.swift`. Before Phase D.
