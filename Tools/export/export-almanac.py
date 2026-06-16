#!/usr/bin/env python3
"""
export-almanac.py — emit a print almanac from content.json

Usage:
    python3 export-almanac.py <content.json> [<content-regional.json>] --output <almanac.md>
"""

import argparse
import json
import re
import sys
from pathlib import Path


PLACEHOLDER_MIN_CHARS = 80


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
    """Regional entries override main entries with the same id; extras are appended."""
    by_id = {e["id"]: e for e in main}
    for entry in regional:
        by_id[entry["id"]] = entry
    return list(by_id.values())


def first_sentence(text: str) -> str:
    """Return the first sentence of text (split on . ! ?)."""
    m = re.search(r"[^.!?]*[.!?]", text)
    return m.group(0).strip() if m else text.strip()


def blurb_for(entry: dict) -> str:
    if entry.get("almanacBlurb"):
        return entry["almanacBlurb"]
    morning_text = entry.get("voice", {}).get("morning", {}).get("text", "")
    return first_sentence(morning_text) if morning_text else ""


def match_label(match: dict) -> str:
    anchor = match.get("anchor", "")
    tithi = match.get("tithi")
    paksha = match.get("paksha", "")
    masa_index = match.get("masaIndex")

    parts = []
    if anchor == "tithi":
        if tithi:
            parts.append(f"Tithi {tithi}")
        if paksha and paksha != "both":
            parts.append(f"{paksha.capitalize()} Paksha")
        elif paksha == "both":
            parts.append("both pakshas")
    elif anchor == "masaTithi":
        if masa_index is not None:
            parts.append(f"Masa {masa_index}")
        if tithi:
            parts.append(f"Tithi {tithi}")
        if paksha and paksha != "both":
            parts.append(f"{paksha.capitalize()} Paksha")
    elif anchor == "pakshaTransition":
        parts.append("Paksha transition")
        if paksha:
            parts.append(f"({paksha})")

    return " | ".join(parts) if parts else anchor


def is_placeholder(text: str) -> bool:
    return len(text.strip()) < PLACEHOLDER_MIN_CHARS


def deep_dive_complete(deep_dive: dict) -> tuple[bool, list[str]]:
    """Returns (is_complete, list_of_short_fields)."""
    fields = ["whatItIs", "mythology", "history", "regional", "whatToDo"]
    short = [f for f in fields if is_placeholder(deep_dive.get(f, ""))]
    return (len(short) == 0), short


def format_entry(entry: dict) -> tuple[str | None, str | None]:
    """
    Returns (markdown_block, warning_message).
    If the deep dive is placeholder, returns (None, warning).
    """
    entry_id = entry.get("id", "unknown")
    tier = entry.get("tier", 5)
    voice = entry.get("voice", {})
    deep_dive = voice.get("deepDive", {})
    food = voice.get("food", {})

    complete, short_fields = deep_dive_complete(deep_dive)
    if not complete:
        warn = (
            f"Skipping '{entry_id}': deepDive fields too short "
            f"(< {PLACEHOLDER_MIN_CHARS} chars): {', '.join(short_fields)}"
        )
        return None, warn

    # Title: capitalise id, replace underscores/hyphens
    title = entry.get("id", "").replace("_", " ").replace("-", " ").title()

    blurb = blurb_for(entry)
    match_str = match_label(entry.get("match", {}))

    lines = []
    lines.append(f"## {title}")
    lines.append(f"*{match_str} | Tier {tier}*")
    lines.append("")

    if blurb:
        lines.append(f"**In brief**: {blurb}")
        lines.append("")

    if deep_dive.get("whatItIs"):
        lines.append("### What it is")
        lines.append(deep_dive["whatItIs"])
        lines.append("")

    if deep_dive.get("mythology"):
        lines.append("### The mythology")
        lines.append(deep_dive["mythology"])
        lines.append("")

    if deep_dive.get("history"):
        lines.append("### The history")
        lines.append(deep_dive["history"])
        lines.append("")

    if deep_dive.get("regional"):
        lines.append("### Regional variation")
        lines.append(deep_dive["regional"])
        lines.append("")

    if deep_dive.get("whatToDo"):
        lines.append("### What to do")
        lines.append(deep_dive["whatToDo"])
        lines.append("")

    if food.get("note"):
        lines.append("### In the kitchen")
        lines.append(food["note"])
        if food.get("recipeLink"):
            lines.append(f"\n*Recipe: {food['recipeLink']}*")
        lines.append("")

    # Advance / Eve layers if present
    advance = voice.get("advance")
    eve = voice.get("eve")
    if advance and advance.get("text"):
        lines.append("### Advance notice")
        days = advance.get("daysBefore")
        if days:
            lines.append(f"*{days} days before*")
        lines.append(advance["text"])
        lines.append("")
    if eve and eve.get("text"):
        lines.append("### Eve")
        lines.append(eve["text"])
        lines.append("")

    lines.append("---")
    return "\n".join(lines), None


def build_almanac(entries: list) -> tuple[str, list[str]]:
    # Sort: tier ascending, then id alphabetically
    sorted_entries = sorted(entries, key=lambda e: (e.get("tier", 5), e.get("id", "")))

    sections = []
    warnings = []

    for entry in sorted_entries:
        block, warn = format_entry(entry)
        if warn:
            warnings.append(warn)
        else:
            sections.append(block)

    header = "# Panchang Almanac\n\n*A guide to the lunar year — festivals, fasts, and food.*\n"
    body = "\n\n".join(sections)
    return f"{header}\n{body}\n", warnings


def main():
    parser = argparse.ArgumentParser(description="Export content.json to a print almanac.")
    parser.add_argument("content", help="Path to content.json")
    parser.add_argument("regional", nargs="?", help="Optional path to content-regional.json")
    parser.add_argument("--output", required=True, help="Output path for almanac.md")
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

    almanac_md, warnings = build_almanac(entries)

    for w in warnings:
        print(f"Warning: {w}", file=sys.stderr)

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(almanac_md, encoding="utf-8")

    skipped = len(warnings)
    exported = len([e for e in entries]) - skipped
    print(
        f"Almanac written to {args.output} "
        f"({exported} entries exported, {skipped} skipped)."
    )


if __name__ == "__main__":
    main()
