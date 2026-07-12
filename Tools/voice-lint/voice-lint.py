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

def _voice_layer_fields(voice: dict, prefix: str) -> list[tuple[str, str]]:
    """
    Return (field_path, text) pairs for the text fields of a single VoiceLayers-shaped
    object (either the entry's base `voice` or a variant's full `voice` override).
    Covers: advance.text, advance2.text, eve.text, morning.text, offsets.*.text,
    deepDive.*, food.note.
    """
    found = []

    for layer in ("advance", "advance2", "eve", "morning"):
        layer_obj = voice.get(layer)
        if isinstance(layer_obj, dict):
            text = layer_obj.get("text", "")
            if text:
                found.append((f"{prefix}.{layer}.text", text))

    offsets = voice.get("offsets")
    if isinstance(offsets, dict):
        for label, layer_obj in offsets.items():
            if isinstance(layer_obj, dict):
                text = layer_obj.get("text", "")
                if text:
                    found.append((f"{prefix}.offsets.{label}.text", text))

    deep_dive = voice.get("deepDive", {})
    if isinstance(deep_dive, dict):
        for field in DEEP_DIVE_FIELDS:
            text = deep_dive.get(field, "")
            if text:
                found.append((f"{prefix}.deepDive.{field}", text))

    food = voice.get("food", {})
    if isinstance(food, dict):
        note = food.get("note", "")
        if note:
            found.append((f"{prefix}.food.note", note))

    return found


def get_voice_text_fields(entry: dict) -> list[tuple[str, str]]:
    """
    Return (field_path, text) pairs for every voice-adjacent text field in an entry,
    including the blind spots A5 found: variants[].voice.* (full variant voice
    overrides), variants[].morningOverride.text, and the entry's tagline.
    Taglines are included here (N-rule checks only) but are noun phrases, not prose —
    check_a2/check_a3 do not consult this function for tagline text.
    """
    results = []

    voice = entry.get("voice", {})
    if isinstance(voice, dict):
        results.extend(_voice_layer_fields(voice, "voice"))

    tagline = entry.get("tagline")
    if isinstance(tagline, str) and tagline:
        results.append(("tagline", tagline))

    for variant in entry.get("variants", []) or []:
        if not isinstance(variant, dict):
            continue
        vid = variant.get("id", "<unknown>")

        variant_voice = variant.get("voice")
        if isinstance(variant_voice, dict):
            results.extend(_voice_layer_fields(variant_voice, f"variants.{vid}.voice"))

        morning_override = variant.get("morningOverride")
        if isinstance(morning_override, dict):
            text = morning_override.get("text", "")
            if text:
                results.append((f"variants.{vid}.morningOverride.text", text))

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


# Gita-verbatim texts that intentionally trip a Never rule by the source material's own
# phrasing. Mirrors A3_ALLOWED's principle (spec: "the Gita text is the spec") but keyed
# by (entryId, field, ruleId) since Never rules, unlike A3, have no severity to downgrade.
NEVER_RULE_ALLOWED = {
    # "...is one of the most moving things in the Hindu calendar" — verbatim visarjan text.
    ("ganesh_chaturthi", "voice.offsets.visarjan.text", "N7"),
}


def check_never_rules(entry: dict) -> list[dict]:
    findings = []
    entry_id = entry.get("id", "<unknown>")
    for field_path, text in get_voice_text_fields(entry):
        for rule_id, pattern in NEVER_RULES:
            if (entry_id, field_path, rule_id) in NEVER_RULE_ALLOWED:
                print(f"{rule_id}: skipping allowed exception for {entry_id}.{field_path} (Gita-verbatim text)")
                continue
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


# A5: Gita-verbatim texts that intentionally end in a question. check_a3 skips these
# (entryId, field) pairs rather than flagging them — do not "fix" the text to dodge lint.
A3_ALLOWED = {
    # Gita Part Three ends this text with a question by design.
    ("paksha_transition", "variants.krishna_to_shukla.morningOverride.text"),
}


def _morning_text_fields(entry: dict) -> list[tuple[str, str]]:
    """
    Return (field_path, text) pairs for every "morning" surface A3 governs: the base
    voice.morning.text, each variant's morningOverride.text, and each variant's own
    voice.morning.text (when a variant supplies a full voice override). Before A5 this
    only looked at voice.morning.text, which is why the paksha_transition.krishna_to_shukla
    morningOverride question ending went uncaught.
    """
    fields = []

    morning = entry.get("voice", {}).get("morning")
    if isinstance(morning, dict):
        text = morning.get("text", "").strip()
        if text:
            fields.append(("voice.morning.text", text))

    for variant in entry.get("variants", []) or []:
        if not isinstance(variant, dict):
            continue
        vid = variant.get("id", "<unknown>")

        morning_override = variant.get("morningOverride")
        if isinstance(morning_override, dict):
            text = morning_override.get("text", "").strip()
            if text:
                fields.append((f"variants.{vid}.morningOverride.text", text))

        variant_voice = variant.get("voice")
        if isinstance(variant_voice, dict):
            variant_morning = variant_voice.get("morning")
            if isinstance(variant_morning, dict):
                text = variant_morning.get("text", "").strip()
                if text:
                    fields.append((f"variants.{vid}.voice.morning.text", text))

    return fields


def check_a3(entry: dict, strict: bool) -> list[dict]:
    """
    Every "morning" surface (base voice.morning.text, each variant's morningOverride.text,
    and any variant's own voice.morning.text) — last sentence must not end with '?' and
    must not be a bullet/list item (starts with '-', '*', or a digit+dot).
    Warning normally, error in --strict. Pairs in A3_ALLOWED are skipped with a printed
    notice instead of being flagged.
    """
    entry_id = entry.get("id", "<unknown>")
    findings = []

    for field_path, text in _morning_text_fields(entry):
        if (entry_id, field_path) in A3_ALLOWED:
            print(f"A3: skipping allowed exception for {entry_id}.{field_path} (Gita-verbatim question ending)")
            continue
        if not text:
            continue

        # Split into sentences (naive: split on '.', '!', '?')
        sentences = [s.strip() for s in re.split(r'(?<=[.!?])\s+', text) if s.strip()]
        if not sentences:
            continue
        last = sentences[-1]

        problems = []
        if last.endswith("?"):
            problems.append("last sentence ends with '?'")
        if re.match(r'^[-*]|\d+\.', last):
            problems.append("last sentence looks like a list item")

        if problems:
            findings.append({
                "severity": "error" if strict else "warning",
                "rule": "A3",
                "entryId": entry_id,
                "field": field_path,
                "match": "; ".join(problems),
            })
    return findings


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


KNOWN_TOKENS = {"masa", "vsYear"}
TOKEN_PATTERN = re.compile(r"\{\{([a-zA-Z]+)\}\}")


def check_a7(entry: dict) -> list[dict]:
    """
    A3 (template tokens): any `{{token}}` placeholder in any text field must be one of
    KNOWN_TOKENS ({"masa", "vsYear"}) — error otherwise (catches typos like {{masaa}}).
    None of the N-rule regexes match token braces, so this doesn't overlap with N-checks.
    """
    entry_id = entry.get("id", "<unknown>")
    findings = []
    for field_path, text in get_voice_text_fields(entry):
        for match in TOKEN_PATTERN.finditer(text):
            token = match.group(1)
            if token not in KNOWN_TOKENS:
                findings.append({
                    "severity": "error",
                    "rule": "A7",
                    "entryId": entry_id,
                    "field": field_path,
                    "match": match.group(0),
                })
    return findings


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
        findings.extend(check_a7(entry))

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


def run_field_coverage_tests() -> None:
    """
    A5: get_voice_text_fields must scan variants[].voice.*, variants[].morningOverride.text,
    advance2.text, offsets.*.text, and tagline — the fields it used to miss entirely.
    """
    entry = {
        "id": "field_coverage_probe",
        "tagline": "a testing tagline",
        "voice": {
            "advance2": {"text": "Advance2 probe text that is long enough to matter.", "daysBefore": 3},
            "offsets": {
                "someLabel": {"text": "Offset probe text long enough to matter."},
            },
            "morning": {"text": "Base morning probe text."},
            "deepDive": {},
            "food": {"note": ""},
        },
        "variants": [
            {
                "id": "variant_probe",
                "voice": {
                    "morning": {"text": "Variant voice morning probe text."},
                },
                "morningOverride": {"text": "Variant morning override probe text."},
            },
        ],
    }
    field_paths = {path for path, _ in get_voice_text_fields(entry)}
    expected = {
        "voice.advance2.text",
        "voice.offsets.someLabel.text",
        "voice.morning.text",
        "tagline",
        "variants.variant_probe.voice.morning.text",
        "variants.variant_probe.morningOverride.text",
    }
    missing = expected - field_paths
    assert not missing, f"get_voice_text_fields is missing expected field paths: {missing}"
    print("PASS: get_voice_text_fields covers variants/offsets/advance2/tagline (A5)")


def run_a3_allowed_tests() -> None:
    """
    A5: check_a3 must scan variants[].morningOverride.text (previously invisible), skip the
    documented A3_ALLOWED exception, and still catch question-ending morning text elsewhere.
    """
    allowed_entry = {
        "id": "paksha_transition",
        "voice": {"morning": {"text": "A normal statement."}},
        "variants": [
            {
                "id": "krishna_to_shukla",
                "morningOverride": {"text": "Is this allowed to end in a question?"},
            },
        ],
    }
    findings = check_a3(allowed_entry, strict=False)
    assert not findings, f"A3_ALLOWED exception should suppress this finding, got: {findings}"
    print("PASS: A3_ALLOWED exception suppresses the documented Gita-verbatim question ending")

    unallowed_entry = {
        "id": "some_other_entry",
        "voice": {"morning": {"text": "A normal statement."}},
        "variants": [
            {
                "id": "some_variant",
                "morningOverride": {"text": "Is this a problem?"},
            },
        ],
    }
    findings = check_a3(unallowed_entry, strict=False)
    assert findings, "A3 should flag a question-ending variant morningOverride.text outside A3_ALLOWED"
    assert findings[0]["field"] == "variants.some_variant.morningOverride.text"
    print("PASS: A3 catches question-ending variant morningOverride.text outside A3_ALLOWED")


def run_never_rule_allowed_tests() -> None:
    """NEVER_RULE_ALLOWED must suppress the one documented Gita-verbatim N7 hit and
    still catch the same phrase anywhere else."""
    allowed_entry = {
        "id": "ganesh_chaturthi",
        "voice": {"offsets": {"visarjan": {"text": "...is one of the most moving things in the Hindu calendar."}}},
    }
    findings = check_never_rules(allowed_entry)
    assert not findings, f"NEVER_RULE_ALLOWED exception should suppress this finding, got: {findings}"
    print("PASS: NEVER_RULE_ALLOWED suppresses the documented Gita-verbatim N7 hit")

    unallowed_entry = {
        "id": "some_other_entry",
        "voice": {"morning": {"text": "This is one of the most sacred days."}},
    }
    findings = check_never_rules(unallowed_entry)
    assert any(f["rule"] == "N7" for f in findings), "N7 should still fire outside the documented exception"
    print("PASS: N7 still fires outside the documented exception")


def run_a7_tests() -> None:
    """A3 engine: check_a7 must flag unknown {{token}} placeholders and allow known ones."""
    bad_entry = {
        "id": "token_probe_bad",
        "voice": {
            "morning": {"text": "This has an {{unknownToken}} in it."},
            "deepDive": {},
            "food": {"note": ""},
        },
    }
    findings = check_a7(bad_entry)
    assert any(f["rule"] == "A7" for f in findings), "check_a7 should flag an unknown token"
    print("PASS: check_a7 flags unknown {{token}} placeholders")

    good_entry = {
        "id": "token_probe_good",
        "voice": {
            "morning": {"text": "This one is {{masa}} Purnima. Vikram Samvat {{vsYear}} begins now."},
            "deepDive": {},
            "food": {"note": ""},
        },
    }
    findings = check_a7(good_entry)
    assert not findings, f"check_a7 should not flag known tokens, got: {findings}"
    print("PASS: check_a7 allows known {{masa}}/{{vsYear}} tokens")


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

    print("\nRunning A5/A7 targeted test cases...\n")
    run_field_coverage_tests()
    run_a3_allowed_tests()
    run_never_rule_allowed_tests()
    run_a7_tests()
    print("\nAll targeted test cases passed.")


if __name__ == "__main__":
    if len(sys.argv) == 1:
        # No args: run inline test
        run_tests()
    else:
        sys.exit(main(sys.argv))
