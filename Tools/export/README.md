# Tools/export

Two scripts that derive artifacts from `content.json` (the single source of truth).

## Scripts

**`export-almanac.py`** — produces a Markdown print almanac.
One section per content entry: title, match info, tier, blurb, full deep dive, food note.
Sorted by tier (1 first), then alphabetically. Skips entries where any `deepDive` paragraph
is under 80 characters (a placeholder guard).

**`export-ai-corpus.py`** — produces a JSONL few-shot corpus for AI content generation.
One system message at the top (voice rules + Never/Always guardrails), then user/assistant
pairs for every notification layer and deep dive paragraph. Skips deep dive examples for
placeholder entries but still emits notification text.

## Running

```sh
# From the repo root:
python3 Tools/export/export-almanac.py \
    PanchangApp/Resources/Content/content.json \
    --output dist/almanac.md

# With a regional override file:
python3 Tools/export/export-almanac.py \
    PanchangApp/Resources/Content/content.json \
    PanchangApp/Resources/Content/content-regional.json \
    --output dist/almanac.md

python3 Tools/export/export-ai-corpus.py \
    PanchangApp/Resources/Content/content.json \
    --output dist/corpus.jsonl
```

## Adding a new export format

1. Create `Tools/export/export-<format>.py` with a `#!/usr/bin/env python3` shebang.
2. Accept `<content.json> [<content-regional.json>] --output <file>` as CLI args.
3. Call `load_json()` and handle missing files gracefully (warn + `sys.exit(0)`).
4. Use the same `PLACEHOLDER_MIN_CHARS = 80` guard before emitting deep dive content.
