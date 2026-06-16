#!/usr/bin/env python3
"""
voice-lint.py — Validates Panchang content JSON files against voice style rules.

Usage:
    python3 voice-lint.py [--strict] <path-to-content-file.json>

Exit codes:
    0 = clean
    1 = errors/warnings found
    2 = schema validation failed
"""

import json
import re
import sys
from typing import Any

# ---------------------------------------------------------------------------
# Schema validation
# ---------------------------------------------------------------------------

REQUIRED_TOP_LEVEL = {"schemaVersion", "entries"}
REQUIRED_ENTRY_FIELDS = {"id", "kind", "tier", "match", "voice", "triggers", "regions"}
REQUIRED_VOICE_FIELDS = {"morning", "deepDive", "food"}
DEEP_DIVE_FIELDS = {"whatItIs", "mythology", "history", "regional", "whatToDo"}


def validate_schema(data: Any) -> list[str]:
    """Return a list of schema errors. Empty list = valid."""
    errors = []

    if not isinstance(data, dict):
        errors.append("Root must be a JSON object")
        return errors

    missing_top = REQUIRED_TOP_LEVEL - data.keys()
    if missing_top:
        errors.append(f"Missing top-level fields: {missing_top}")
        return errors

    if data.get("schemaVersion") != "1.0":
        errors.append(f"schemaVersion must be '1.0', got {data.get('schemaVersion')!r}")

    if not isinstance(data.get("entries"), list):
        errors.append("'entries' must be an array")
        return errors

    for i, entry in enumerate(data["entries"]):
        prefix = f"entries[{i}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix}: must be an object")
            continue

        missing_entry = REQUIRED_ENTRY_FIELDS - entry.keys()
        if missing_entry:
            errors.append(f"{prefix}: missing fields {missing_entry}")

        voice = entry.get("voice")
        if not isinstance(voice, dict):
            errors.append(f"{prefix}.voice: must be an object")
        else:
            missing_voice = REQUIRED_VOICE_FIELDS - voice.keys()
            if missing_voice:
                errors.append(f"{prefix}.voice: missing fields {missing_voice}")

    return errors


# ---------------------------------------------------------------------------
# Text field extraction
# ---------------------------------------------------------------------------

def get_voice_text_fields(entry: dict) -> list[tuple[str, str]]:
    """
    Return (field_path, text) pairs for all voice text fields in an entry.
    Covers: advance.text, eve.text, morning.text, deepDive.*, food.note
    """
    results = []
    voice = entry.get("voice", {})

    for layer in ("advance", "eve", "morning"):
        layer_obj = voice.get(layer)
        if isinstance(layer_obj, dict):
            text = layer_obj.get("text", "")
            if text:
                results.append((f"voice.{layer}.text", text))

    deep_dive = voice.get("deepDive", {})
    if isinstance(deep_dive, dict):
        for field in DEEP_DIVE_FIELDS:
            text = deep_dive.get(field, "")
            if text:
                results.append((f"voice.deepDive.{field}", text))

    food = voice.get("food", {})
    if isinstance(food, dict):
        note = food.get("note", "")
        if note:
            results.append(("voice.food.note", note))

    return results


# ---------------------------------------------------------------------------
# Never rules (N1–N10)
# ---------------------------------------------------------------------------

NEVER_RULES = [
    ("N1", re.compile(r"\bit is believed that\b", re.IGNORECASE)),
    ("N2", re.compile(r"\(the \d+(?:st|nd|rd|th) lunar day\)", re.IGNORECASE)),
    ("N3", re.compile(r"\bauspicious occasion\b", re.IGNORECASE)),
    ("N4", re.compile(r"\bseek (?:blessings|the blessings)\b", re.IGNORECASE)),
    ("N5", re.compile(r"\bis worshipped\b", re.IGNORECASE)),
    ("N6", re.compile(r"\bmost (?:sacred|holy|important|auspicious)\b", re.IGNORECASE)),
    ("N7", re.compile(r"\bone of the most\b", re.IGNORECASE)),
    ("N8", re.compile(r"\bspecial significance\b", re.IGNORECASE)),
    ("N9", re.compile(r"\((?:fasting day|festival of lights|new moon|full moon)\)", re.IGNORECASE)),
    # N10: "the devotees" without a qualifier immediately before "devotees"
    # Banned: "the devotees"
    # Allowed: "Vaishnava devotees", "women devotees", etc. (adjective before devotees)
    ("N10", re.compile(r"\bthe devotees\b", re.IGNORECASE)),
]


def check_never_rules(entry: dict) -> list[dict]:
    findings = []
    entry_id = entry.get("id", "<unknown>")
    for field_path, text in get_voice_text_fields(entry):
        for rule_id, pattern in NEVER_RULES:
            for match in pattern.finditer(text):
                findings.append({
                    "severity": "error",
                    "rule": rule_id,
                    "entryId": entry_id,
                    "field": field_path,
                    "match": match.group(0),
                })
    return findings


# ---------------------------------------------------------------------------
# Always rules (A1–A6)
# ---------------------------------------------------------------------------

def check_a1(entry: dict) -> list[dict]:
    """food.note must be a non-empty string."""
    entry_id = entry.get("id", "<unknown>")
    food = entry.get("voice", {}).get("food", {})
    note = food.get("note", "") if isinstance(food, dict) else ""
    if not isinstance(note, str) or not note.strip():
        return [{
            "severity": "error",
            "rule": "A1",
            "entryId": entry_id,
            "field": "voice.food.note",
            "match": repr(note),
        }]
    return []


def check_a2(entry: dict) -> list[dict]:
    """All 5 deepDive paragraphs must be present and each >= 80 characters."""
    entry_id = entry.get("id", "<unknown>")
    findings = []
    deep_dive = entry.get("voice", {}).get("deepDive", {})
    if not isinstance(deep_dive, dict):
        return [{
            "severity": "error",
            "rule": "A2",
            "entryId": entry_id,
            "field": "voice.deepDive",
            "match": "deepDive is missing or not an object",
        }]
    for field in DEEP_DIVE_FIELDS:
        text = deep_dive.get(field, "")
        if not isinstance(text, str) or not text.strip():
            findings.append({
                "severity": "error",
                "rule": "A2",
                "entryId": entry_id,
                "field": f"voice.deepDive.{field}",
                "match": "paragraph missing or empty",
            })
        elif len(text.strip()) < 80:
            findings.append({
                "severity": "error",
                "rule": "A2",
                "entryId": entry_id,
                "field": f"voice.deepDive.{field}",
                "match": f"paragraph too short ({len(text.strip())} chars, min 80)",
            })
    return findings


def check_a3(entry: dict, strict: bool) -> list[dict]:
    """
    voice.morning.text — last sentence must not end with '?' and must not be
    a bullet/list item (starts with '-', '*', or a digit+dot).
    Warning normally, error in --strict.
    """
    entry_id = entry.get("id", "<unknown>")
    morning = entry.get("voice", {}).get("morning", {})
    if not isinstance(morning, dict):
        return []
    text = morning.get("text", "").strip()
    if not text:
        return []

    # Split into sentences (naive: split on '.', '!', '?')
    sentences = [s.strip() for s in re.split(r'(?<=[.!?])\s+', text) if s.strip()]
    if not sentences:
        return []
    last = sentences[-1]

    problems = []
    if last.endswith("?"):
        problems.append("last sentence ends with '?'")
    if re.match(r'^[-*]|\d+\.', last):
        problems.append("last sentence looks like a list item")

    if problems:
        return [{
            "severity": "error" if strict else "warning",
            "rule": "A3",
            "entryId": entry_id,
            "field": "voice.morning.text",
            "match": "; ".join(problems),
        }]
    return []


def check_a4(entry: dict, strict: bool) -> list[dict]:
    """Tier <= 2 entries must have advance or eve voice layer."""
    entry_id = entry.get("id", "<unknown>")
    tier = entry.get("tier")
    if not isinstance(tier, int) or tier > 2:
        return []
    voice = entry.get("voice", {})
    has_advance = isinstance(voice.get("advance"), dict)
    has_eve = isinstance(voice.get("eve"), dict)
    if not has_advance and not has_eve:
        return [{
            "severity": "error" if strict else "warning",
            "rule": "A4",
            "entryId": entry_id,
            "field": "voice",
            "match": f"tier {tier} entry has neither advance nor eve layer",
        }]
    return []


KNOWN_CYCLE_IDS = {"ekadashi", "purnima", "amavasya", "paksha_transition"}


def check_a5(entry: dict, all_ids: set[str]) -> list[dict]:
    """
    Warn if the entry id doesn't look like a known cycle id and isn't in
    the broader id set. For now: flag if it looks suspiciously like a
    duplicate with minor typo differences (fuzzy check is hard in stdlib;
    we do a simple check for ids that differ by one character from another id).
    The prompt says: duplicate check only; A6 covers exact dups.
    We flag near-duplicates (edit distance == 1) as potential typos.
    """
    entry_id = entry.get("id", "<unknown>")
    findings = []

    # Check near-duplicates against other ids (simple transposition/substitution check)
    for other_id in all_ids:
        if other_id == entry_id:
            continue
        if _edit_distance_one(entry_id, other_id):
            findings.append({
                "severity": "warning",
                "rule": "A5",
                "entryId": entry_id,
                "field": "id",
                "match": f"possible typo: '{entry_id}' is 1 edit away from '{other_id}'",
            })
            break  # Only report first near-match

    return findings


def _edit_distance_one(a: str, b: str) -> bool:
    """Return True if strings differ by exactly one edit (insert/delete/substitute)."""
    if abs(len(a) - len(b)) > 1:
        return False
    if len(a) == len(b):
        # substitution
        diffs = sum(x != y for x, y in zip(a, b))
        return diffs == 1
    # insertion / deletion
    shorter, longer = (a, b) if len(a) < len(b) else (b, a)
    i = j = diffs = 0
    while i < len(shorter) and j < len(longer):
        if shorter[i] != longer[j]:
            diffs += 1
            j += 1
        else:
            i += 1
            j += 1
    return diffs <= 1


def check_a6(entries: list[dict]) -> list[dict]:
    """No duplicate id values across all entries."""
    seen: dict[str, int] = {}
    findings = []
    for entry in entries:
        entry_id = entry.get("id", "<unknown>")
        if entry_id in seen:
            findings.append({
                "severity": "error",
                "rule": "A6",
                "entryId": entry_id,
                "field": "id",
                "match": f"duplicate id (first seen at entry index {seen[entry_id]})",
            })
        else:
            seen[entry_id] = entries.index(entry)
    return findings


# ---------------------------------------------------------------------------
# Main lint runner
# ---------------------------------------------------------------------------

def lint(data: dict, strict: bool) -> list[dict]:
    findings = []
    entries = data.get("entries", [])
    all_ids = {e.get("id") for e in entries if isinstance(e, dict) and "id" in e}

    # A6 runs across all entries first
    findings.extend(check_a6(entries))

    for entry in entries:
        if not isinstance(entry, dict):
            continue
        findings.extend(check_never_rules(entry))
        findings.extend(check_a1(entry))
        findings.extend(check_a2(entry))
        findings.extend(check_a3(entry, strict))
        findings.extend(check_a4(entry, strict))
        findings.extend(check_a5(entry, all_ids))

    return findings


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main(argv: list[str]) -> int:
    strict = False
    args = [a for a in argv[1:] if a != "--strict"]
    if "--strict" in argv:
        strict = True

    if len(args) != 1:
        print("Usage: voice-lint.py [--strict] <path-to-content-file.json>", file=sys.stderr)
        return 2

    path = args[0]
    try:
        with open(path, encoding="utf-8") as f:
            raw = f.read()
    except OSError as e:
        print(f"Cannot read file: {e}", file=sys.stderr)
        return 2

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"Invalid JSON: {e}", file=sys.stderr)
        return 2

    schema_errors = validate_schema(data)
    if schema_errors:
        for err in schema_errors:
            print(f"Schema error: {err}", file=sys.stderr)
        return 2

    findings = lint(data, strict)

    if findings:
        print(json.dumps(findings, indent=2, ensure_ascii=False))
        # Exit 1 if there are any errors; warnings alone are exit 0 in normal mode
        has_errors = any(f["severity"] == "error" for f in findings)
        return 1 if has_errors else 0

    return 0


# ---------------------------------------------------------------------------
# Inline test fixture (used when content.json doesn't exist yet)
# ---------------------------------------------------------------------------

TEST_FIXTURE = {
    "schemaVersion": "1.0",
    "entries": [
        {
            "id": "ekadashi",
            "kind": "cycle",
            "tier": 1,
            "match": {"anchor": "tithi", "tithi": 11, "paksha": "both", "masaIndex": None},
            "variants": [],
            "voice": {
                "advance": {"text": "Ekadashi is three days away. Plan your fast now.", "daysBefore": 3},
                "eve": {"text": "Tomorrow is Ekadashi. Prepare your mind and kitchen tonight."},
                "morning": {"text": "Today is Ekadashi. The fast runs from sunrise to the next sunrise."},
                "deepDive": {
                    "whatItIs": "Ekadashi falls on the eleventh lunar day of each paksha, occurring twice monthly. It is one of the most widely observed fasts in the Vaishnava calendar, anchored in the belief that the digestive system benefits from a periodic rest.",
                    "mythology": "The Padma Purana tells of a demon named Mura who terrorized the devas. Vishnu, exhausted from battle, rested in a cave. A power emerged from his sleeping body and slew Mura. Vishnu named this power Ekadashi and granted her a boon: devotees who fast on her day would reach Vaikuntha.",
                    "history": "Records of Ekadashi fasting appear in the Bhagavata Purana and the Vishnu Purana, placing its systematic observance at least in the early medieval period. Regional almanacs from the 10th century CE already standardize the tithi calculation method still used today.",
                    "regional": "In Gujarat the fast often breaks with sabudana khichdi at dusk. Bengali households favor fruits and milk. South Indian Vaishnavas in the Iyengar tradition abstain from all grains and some vegetables, following a stricter niyama than most.",
                    "whatToDo": "Wake before sunrise and bathe. Offer tulsi leaves and water to the Vishnu murti if you keep one. Avoid rice, wheat, and all grains until parana—the break-fast window—on the following morning. Read the Ekadashi Mahatmya or any chapter of the Bhagavata.",
                },
                "food": {
                    "note": "On Ekadashi avoid grains entirely. Eat fruit, milk, sabudana, and root vegetables like sweet potato. Break the fast within the parana window the next morning with light rice and ghee.",
                    "recipeLink": None,
                },
            },
            "triggers": [{"type": "morning", "time": {"hour": 6, "minute": 0}}],
            "action": None,
            "regions": [],
        },
        {
            # Entry designed to trigger N1, N3, N6, N8, N10, A3 (question ending)
            "id": "purnima",
            "kind": "cycle",
            "tier": 2,
            "match": {"anchor": "tithi", "tithi": 15, "paksha": "shukla", "masaIndex": None},
            "variants": [],
            "voice": {
                "morning": {
                    "text": "It is believed that fasting today brings merit. This is an auspicious occasion where the devotees gather. Is this the most sacred day?"
                },
                "deepDive": {
                    "whatItIs": "Short.",  # Too short — A2
                    "mythology": "Purnima mythology is rich with stories of lunar cycles and their connection to the divine feminine, water, and agricultural rhythms in ancient India.",
                    "history": "Historical records of Purnima observance stretch back to the Vedic period, with lunar calendar calculations appearing in the Jyotisha Vedanga, the earliest known astronomical text of the Indian tradition.",
                    "regional": "In Maharashtra the Kojagari Purnima in Ashwin is celebrated with milk boiled under the full moon. Bengal marks Lakshmi Puja on this same night. Tamil Nadu observes Karthigai in Kartika.",
                    "whatToDo": "Bathe early and offer white flowers and rice to the moon in the evening. Light a lamp by the tulsi plant. This day has special significance for river pilgrimages across north India.",
                },
                "food": {
                    "note": "",  # Empty — A1 error
                    "recipeLink": None,
                },
            },
            "triggers": [{"type": "morning", "time": {"hour": 6, "minute": 0}}],
            "action": None,
            "regions": [],
        },
    ],
}


def run_tests() -> None:
    """Run against the inline fixture and print results."""
    print("Running against inline test fixture...\n")
    schema_errors = validate_schema(TEST_FIXTURE)
    if schema_errors:
        print("SCHEMA ERRORS:", schema_errors)
        return
    findings = lint(TEST_FIXTURE, strict=False)
    if findings:
        print(json.dumps(findings, indent=2, ensure_ascii=False))
        print(f"\n{len(findings)} finding(s) found.")
    else:
        print("No findings.")


if __name__ == "__main__":
    if len(sys.argv) == 1:
        # No args: run inline test
        run_tests()
    else:
        sys.exit(main(sys.argv))
