# Panchang

An iOS app that rebuilds the Hindu lunar calendar for the diaspora household — the
paper *Atithi Toran* that used to hang on the wall, turned into an ambient layer that
shows up at the right moment and says: *today matters, here's why, here's what to do.*

Not a data instrument (that's Drik Panchang), not an astrology mirror (that's Co-Star),
not a religion app. It points outward — at time itself, at where you are in the lunar
year — and requires only curiosity.

Everything computes **on-device** from astronomy. Fully offline, no backend, no
accounts, local-only storage.

## Features

- **Today** — an editorial home screen: a moon-arc showing where the month is, the
  Gregorian and lunar dates side by side, one hero statement about what today *means*
  (festival, Ekadashi, or the plain rhythm of a waxing/waning day), and what's coming
  up. The screen's accent and background shift with the kind of day.
- **Deep dives** — every festival and observance carries five authored layers:
  what it is, the mythology, the history, the regional variation, what to do today —
  plus the food, always the food.
- **Full panchang** — the five limbs (tithi, vara, nakshatra, yoga, karana) with end
  times, sunrise/sunset/moonrise/moonset, masa and Vikram Samvat in both reckonings,
  ritu and ayana.
- **Muhurta** — Choghadiya day/night grids, 24 planetary horas, Brahma Muhurta,
  Abhijit, Rahu Kalam, Yamaganda, Gulika, Dur Muhurtam, Varjyam, Amrit Kalam, and
  Tara/Chandra Bala against your janma details.
- **Calendar** — month grid with tithis and color-coded festivals; any day opens its
  full panchang.
- **Kundli** — birth chart (North/South style), planetary positions, navamsha, and
  Vimshottari dasha timeline.
- **Notifications** — the monthly heartbeat: advance/eve/morning layers per festival,
  midnight for Janmashtami, multi-day sequences (Navratri nights, Ganesh Visarjan),
  every Ekadashi, Purnima, Amavasya, and paksha transition.
- **Traditions** — Gujarati/Western (Amanta, Kartikadi) preset by default with North
  Indian (Purnimanta, Chaitradi) available; regional content packs (Gujarati, Jain,
  Sikh); Devanagari, transliteration, or English script modes.

## Architecture

```
PanchangKit/          Swift package — the clock. Pure computation, no UI.
  Ephemeris/          SwiftAA (MIT) sun/moon positions; memoized
  Engine/             Five limbs, timings, muhurtas, Choghadiya, hora, bala
  Calendar/           Masa/samvat reckoning, presets (Amanta/Purnimanta)
  Astrology/          Lagna, navamsha, planetary positions, Vimshottari dasha
  Festivals/          Rule engine matching tithi/masa/solar anchors to days

PanchangApp/          SwiftUI app (iOS 17+, SwiftData) — the voice.
  DesignSystem/       Palette, day moods, type tokens, shared components
  Features/           Today, DeepDive, Muhurta, Calendar, Kundli, Settings,
                      Onboarding, Notifications
  Services/           ContentService (resolver), FestivalService, PanchangService,
                      ScriptRenderer
  Resources/Content/  content.json + content-regional.json — all editorial text

Tools/voice-lint/     Style linter enforcing the Content Gita's writing rules (CI)
```

Two ideas hold the codebase together:

1. **The engine is the clock, the content is the voice.** PanchangKit computes *when*;
   `content.json` says *what it means*. `ContentResolver` is the seam: it matches
   authored entries to a computed day (by tithi, masa+tithi, solar ingress, or paksha)
   and feeds both the UI and the notification scheduler. Festival calendar rules are
   derived from the same content entries — one source of truth.
2. **One product, two visual registers.** Editorial (serif, warm paper, space) for
   meaning: Today, deep dives, onboarding. Almanac (same paper and ink, tabular data,
   hairline rules) for reference: full panchang, muhurta, calendar, kundli.

## Building

Requires Xcode 15+ (iOS 17 deployment target).

```sh
open PanchangApp.xcodeproj        # scheme: PanchangApp
```

Tests:

```sh
# Engine (golden vectors, invariants, presets, astrology, muhurta grids)
cd PanchangKit && swift test

# App layer (content resolver: trigger bodies, token substitution, paksha anchor)
xcodebuild test -project PanchangApp.xcodeproj -scheme PanchangApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Authoring content

All user-facing editorial text lives in `PanchangApp/Resources/Content/` — never in
Swift. The voice is governed by [content-gita.md](content-gita.md) (the writing
rules, festival scripts, and tone guardrails) and enforced by the linter:

```sh
python3 Tools/voice-lint/voice-lint.py PanchangApp/Resources/Content/content.json
python3 Tools/voice-lint/voice-lint.py PanchangApp/Resources/Content/content-regional.json
python3 Tools/voice-lint/voice-lint.py            # linter self-tests
```

Entries support template tokens (`{{masa}}`, `{{vsYear}}`) substituted at resolve
time, per-variant overrides, and notification triggers (`advance`, `eve`, `morning`,
`midnight`, `dayOffset`). Schema: `content.schema.json`.

## Documents

| File | What it is |
|---|---|
| [SPEC.md](SPEC.md) | V1 build spec — architecture and product decisions (settled) |
| [SPEC2.md](SPEC2.md) | V2 feature clusters |
| [SPEC-conformity-theme.md](SPEC-conformity-theme.md) | Gita conformance + app-wide design system spec |
| [content-gita.md](content-gita.md) | The editorial constitution: voice, philosophy, festival scripts |
| [CONTENT_LAYER_PLAN.md](CONTENT_LAYER_PLAN.md) | How the voice layer was built |
