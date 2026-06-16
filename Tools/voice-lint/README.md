# voice-lint

Validates Panchang content JSON files against the voice style rules in `SPEC.md`.

## Usage

```
python3 Tools/voice-lint/voice-lint.py [--strict] <path-to-content-file.json>
```

| Exit code | Meaning |
|-----------|---------|
| 0 | Clean (or warnings only in normal mode) |
| 1 | Errors found — JSON array printed to stdout |
| 2 | File is malformed / fails schema validation |

Add `--strict` to promote A3 and A4 warnings to errors.

## Rules

| ID | Severity | What it checks |
|----|----------|----------------|
| N1 | error | Bans "it is believed that" |
| N2 | error | Bans parenthetical lunar-day glosses like "(the 11th lunar day)" |
| N3 | error | Bans "auspicious occasion" |
| N4 | error | Bans "seek blessings / seek the blessings" |
| N5 | error | Bans passive "is worshipped" |
| N6 | error | Bans unearned superlatives "most sacred/holy/important/auspicious" |
| N7 | error | Bans throat-clearing "one of the most" |
| N8 | error | Bans meaningless filler "special significance" |
| N9 | error | Bans parenthetical definition glosses "(fasting day)", "(full moon)" etc. |
| N10 | error | Bans vague "the devotees" — name the group instead |
| A1 | error | `food.note` must be a non-empty string |
| A2 | error | All 5 `deepDive` paragraphs must be present and ≥ 80 characters each |
| A3 | warning / error in `--strict` | `voice.morning.text` must not end with a question or bullet item |
| A4 | warning / error in `--strict` | Tier ≤ 2 entries must have an `advance` or `eve` voice layer |
| A5 | warning | Flags entry `id` values that look like near-typos of another id |
| A6 | error | No duplicate `id` values across entries |

## Adding a new rule

1. Document it in `SPEC.md` under the N or A table.
2. For a **Never** pattern: add a `(rule_id, re.compile(...))` tuple to `NEVER_RULES` in `voice-lint.py`.
3. For an **Always** check: add a `check_<rule_id>(entry, ...)` function and call it inside `lint()`.
