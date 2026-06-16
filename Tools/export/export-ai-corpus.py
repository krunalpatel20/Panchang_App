#!/usr/bin/env python3
"""
export-ai-corpus.py — emit a JSONL few-shot corpus from content.json

Usage:
    python3 export-ai-corpus.py <content.json> [<content-regional.json>] --output <corpus.jsonl>
"""

import argparse
import json
import sys
from pathlib import Path


PLACEHOLDER_MIN_CHARS = 80

SYSTEM_CONTENT = """\
You are writing content for a Hindu lunar calendar app for the Indian diaspora.

The voice is a wise friend who loves this world and wants you to feel at home in it — \
never a priest testing devotion, never a professor explaining a textbook. \
Warm, specific, grounded, occasionally poetic. Never vague. Never preachy.

Five writing rules:
1. Earn the unfamiliar word. Sanskrit and Hindi terms arrive through image, not definition.
2. Specific beats vague, always.
3. The emotional beat comes last — it lands in the body, not the brain.
4. Bridge the ancient and the observable without overclaiming science or dismissing tradition.
5. Always end at human scale: a specific action, a person to call, a thing to make.

Never write:
- "On this auspicious occasion"
- "Seek blessings" without saying whose and why
- "It is believed that" — state what the tradition says and let the reader decide
- "Whether or not you believe in..." — don't be defensive about belief
- Sanskrit terms in parenthetical definitions — earn them with the next phrase
- Passive constructions that distance the reader ("the goddess is worshipped")
- Unearned superlatives ("the most sacred", "one of the most important")
- "Special significance", "auspicious occasion", or similar filler

Always:
- End at human scale: a specific action, a person to call, a thing to make
- Assume the reader is intelligent and curious, not ignorant and needing correction
- Write mythology as story, not doctrine
- Acknowledge regional variation — the tradition is not monolithic
- Include a food note in every entry

Deep dive structure (5 paragraphs, always in this order):
1. What it actually is — stripped of assumption, for someone who has never heard of it
2. The mythology — the story, told as story not doctrine
3. The history — how it has traveled and changed
4. The regional variation — where it looks different and why
5. What to do today — wherever you are, whatever your level of observance
"""


def load_json(path: str) -> dict | None:
    p = Path(path)
    if not p.exists():
        print(f"Warning: file not found: {path}", file=sys.stderr)
        return None
    try:
        with p.open(encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        print(f"Warning: could not parse {path}: {e}", file=sys.stderr)
        return None


def merge_entries(main: list, regional: list) -> list:
    by_id = {e["id"]: e for e in main}
    for entry in regional:
        by_id[entry["id"]] = entry
    return list(by_id.values())


def is_placeholder(text: str) -> bool:
    return len(text.strip()) < PLACEHOLDER_MIN_CHARS


def deep_dive_complete(deep_dive: dict) -> tuple[bool, list[str]]:
    fields = ["whatItIs", "mythology", "history", "regional", "whatToDo"]
    short = [f for f in fields if is_placeholder(deep_dive.get(f, ""))]
    return (len(short) == 0), short


def display_name(entry_id: str) -> str:
    return entry_id.replace("_", " ").replace("-", " ").title()


def emit_line(obj: dict) -> str:
    return json.dumps(obj, ensure_ascii=False)


def examples_for_entry(entry: dict) -> tuple[list[str], str | None]:
    """
    Returns (list_of_jsonl_lines, warning_or_None).
    Skips the deep dive examples if deepDive is placeholder.
    Always emits notification examples if they exist.
    """
    entry_id = entry.get("id", "unknown")
    name = display_name(entry_id)
    voice = entry.get("voice", {})
    deep_dive = voice.get("deepDive", {})
    food = voice.get("food", {})

    lines = []
    complete, short_fields = deep_dive_complete(deep_dive)

    # --- Notification layers (emit regardless of deep dive completeness) ---
    morning_text = voice.get("morning", {}).get("text", "")
    if morning_text:
        lines.append(emit_line({
            "role": "user",
            "content": f"Write the morning notification text for {name}."
        }))
        lines.append(emit_line({
            "role": "assistant",
            "content": morning_text
        }))

    eve = voice.get("eve")
    if eve and eve.get("text"):
        lines.append(emit_line({
            "role": "user",
            "content": f"Write the eve (night-before) notification text for {name}."
        }))
        lines.append(emit_line({
            "role": "assistant",
            "content": eve["text"]
        }))

    advance = voice.get("advance")
    if advance and advance.get("text"):
        days = advance.get("daysBefore", "")
        days_str = f" ({days} days before)" if days else ""
        lines.append(emit_line({
            "role": "user",
            "content": f"Write the advance notification text for {name}{days_str}."
        }))
        lines.append(emit_line({
            "role": "assistant",
            "content": advance["text"]
        }))

    # --- Deep dive (skip if placeholder) ---
    if not complete:
        warn = (
            f"Skipping deep dive for '{entry_id}': fields too short "
            f"(< {PLACEHOLDER_MIN_CHARS} chars): {', '.join(short_fields)}"
        )
        return lines, warn

    field_prompts = {
        "whatItIs":  "Write the 'What it is' paragraph",
        "mythology": "Write the 'Mythology' paragraph",
        "history":   "Write the 'History' paragraph",
        "regional":  "Write the 'Regional variation' paragraph",
        "whatToDo":  "Write the 'What to do today' paragraph",
    }

    for field, prompt_prefix in field_prompts.items():
        text = deep_dive.get(field, "")
        if text:
            lines.append(emit_line({
                "role": "user",
                "content": f"{prompt_prefix} for {name}'s deep dive."
            }))
            lines.append(emit_line({
                "role": "assistant",
                "content": text
            }))

    # --- Food note ---
    if food.get("note"):
        lines.append(emit_line({
            "role": "user",
            "content": f"Write the food note for {name}."
        }))
        lines.append(emit_line({
            "role": "assistant",
            "content": food["note"]
        }))

    return lines, None


def build_corpus(entries: list) -> tuple[list[str], list[str]]:
    all_lines = []
    warnings = []

    # One system message at the top
    all_lines.append(emit_line({"role": "system", "content": SYSTEM_CONTENT}))

    # Sort by tier, then id — deterministic output
    sorted_entries = sorted(entries, key=lambda e: (e.get("tier", 5), e.get("id", "")))

    for entry in sorted_entries:
        entry_lines, warn = examples_for_entry(entry)
        if warn:
            warnings.append(warn)
        all_lines.extend(entry_lines)

    return all_lines, warnings


def main():
    parser = argparse.ArgumentParser(description="Export content.json to a JSONL AI corpus.")
    parser.add_argument("content", help="Path to content.json")
    parser.add_argument("regional", nargs="?", help="Optional path to content-regional.json")
    parser.add_argument("--output", required=True, help="Output path for corpus.jsonl")
    args = parser.parse_args()

    main_data = load_json(args.content)
    if main_data is None:
        print("Warning: main content file missing or unreadable — nothing to export.", file=sys.stderr)
        sys.exit(0)

    entries = main_data.get("entries", [])
    if not entries:
        print("Warning: no entries found in content file.", file=sys.stderr)
        sys.exit(0)

    if args.regional:
        regional_data = load_json(args.regional)
        if regional_data:
            regional_entries = regional_data.get("entries", [])
            entries = merge_entries(entries, regional_entries)

    corpus_lines, warnings = build_corpus(entries)

    for w in warnings:
        print(f"Warning: {w}", file=sys.stderr)

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(corpus_lines) + "\n", encoding="utf-8")

    # Subtract 1 for the system message, divide by 2 for user/assistant pairs
    example_pairs = (len(corpus_lines) - 1) // 2
    print(
        f"Corpus written to {args.output} "
        f"({example_pairs} few-shot pairs, {len(warnings)} deep-dive blocks skipped)."
    )


if __name__ == "__main__":
    main()
