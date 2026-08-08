# Spec — vocabulary-schema coverage gate

## What this is

A generation-time contract: no `skill-sources/` template may reference a `{vocabulary.X}` /
`{DOMAIN:X}` placeholder key that the generator's own manifest schema doesn't guarantee will be
populated. Closes a defect class at its source rather than patching individual instances of it
after generation.

## Background and evidence

Motivated by a real finding in `~/second-brain` (a generated vault): `/arscontexta:upgrade`
reported "no upgrade warranted" while separately surfacing 29 unsubstituted `{vocabulary.*}`
markers on the vault's live surface (`.claude/skills/*/SKILL.md`). Investigation, not assumption:

| Marker | Count | Where | Manifest has the key? |
|---|---|---|---|
| `{vocabulary.notes}` | 14 | graph, reflect, reweave, stats | Yes — `notes: "nodes"` |
| `{vocabulary.inbox}` | 2 | graph | Yes — `inbox: "capture"` |
| `{vocabulary.domain}` | 12 | extract (reduce) only | **No** — no `domain` key exists in this manifest, or in `skills/setup/SKILL.md`'s own manifest template, at all |
| `{DOMAIN:extraction_categories}` | 1 | extract (reduce) | N/A — already documented in `skills/upgrade/SKILL.md` as a Level 7 nested list, never a substitution pair by design |

The `notes`/`inbox` cases are ordinary unsubstituted markers — a real value exists, generation
just missed applying it. The `domain` case is categorically different: `skill-sources/reduce/SKILL.md`
uses `{vocabulary.domain}` 13 times, and neither `skills/setup/SKILL.md`'s manifest template
(Levels 1–7) nor `reference/vocabulary-transforms.md`'s Universal → Domain Mapping table declares
`domain` as a real vocabulary concept anywhere. This is not multi-domain-specific — no vault, single-
or multi-domain, has ever had a schema slot for it. `reduce/SKILL.md` has been shipping an
unresolvable placeholder in every vault it has ever generated into.

This spec closes that gap generation-forward: a new schema field for `domain`, wired into the
existing substitution machinery, plus a CI gate that would have caught this before it shipped.

**Explicitly deferred, not part of this spec:** repairing vaults that already exist (like
`second-brain`, which still has 29 unsubstituted markers after this ships). That is `/upgrade`'s
job — a separate repair capability, scoped in a follow-up spec once this one's schema change gives
it something correct to repair *to*.

## Design

### 1. Manifest schema change

Add a new top-level field to `ops/derivation-manifest.md`, parallel to `dimensions:` /
`active_blocks:` / `domains:` / `vocabulary:` — **not** nested inside `vocabulary:`:

```yaml
domain_summary: "day trading strategy research"
```

Setup's derivation conversation already elicits enough to write this — it already drives hub
descriptions and note-type language. This captures the same information once more, explicitly.
Collected identically for single- and multi-domain vaults: one real, user-grounded phrase, never a
synthesized `join(domains[*].id)`.

`skills/setup/SKILL.md`'s manifest template gets one new line near the `dimensions:`/`domains:`
section:

```yaml
domain_summary: "[domain term]"        # e.g., "day trading strategy research"
```

`skill-sources/reduce/SKILL.md` needs **no wording changes** — its 13 `{vocabulary.domain}` uses
stay exactly as they are. Only the substitution source changes.

### 2. Wiring into the existing substitution machinery

`skills/upgrade/SKILL.md`'s `mechanically_compare()` currently builds its substitution table from
one source: the `vocabulary:` block (`sed -n '/^vocabulary:/,/# Level 7:/p'`). Add one more
extraction step, separate from that block scan since `domain_summary:` lives outside it — inserted
after the existing `vocabulary:` block extraction, before the pairs_file emptiness check:

```bash
domain_line=$(grep '^domain_summary:' "$manifest")
if [ -n "$domain_line" ]; then
  domain_val=$(printf '%s\n' "$domain_line" | sed -n 's/^domain_summary: "\(.*\)"$/\1/p')
  domain_val=$(printf '%s' "$domain_val" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]_[:space:]' ' ' | awk '{$1=$1}1')
  [ -n "$domain_val" ] && printf 'domain\t%s\n' "$domain_val" >> "$pairs_file"
fi
```

Same fold-and-append shape the existing `topic_map`/`topic_maps` → `MOC`/`MOCs` aliasing already
uses a few lines below — applying an established pattern to a second source, not inventing a new
one. No guard failure if `domain_summary:` is absent (an older vault won't have it yet): the key
simply isn't in the pairs table, and `{vocabulary.domain}` stays unsubstituted in the comparison —
correct, since that vault genuinely has no value for it yet.

`render_current_template`'s instructions (Step 5b, regenerating a skill) get one added sentence:
*"For `{vocabulary.domain}`, use the manifest's `domain_summary:` field rather than the
`vocabulary:` block."*

`resolve_canonical_name` is untouched — `domain` was never one of the six Level-5 process-verb keys
it resolves.

### 3. The enforcement gate

A new script, `reference/check-vocabulary-schema.sh`, alongside the other `check-*.sh` gates.

**What it checks:** for the *current* state of `skill-sources/` — not diff-relative like
`check-placeholder-count.sh` — every `{vocabulary.X}` / `{DOMAIN:X}` used must resolve to a key
declared somewhere in the schema: the `vocabulary:` block in `skills/setup/SKILL.md`'s manifest
template (Levels 1–6 plus the new `domain_summary:` line, mapped to bare key `domain`) or the one
documented Level 7 structural exception (`extraction_categories`).

**Source of truth:** `skills/setup/SKILL.md`'s own manifest template — the generator's existing
single declared schema. No new schema file; nothing new to keep in sync beyond what already exists.

**Why not diff-scoped:** a schema change (a key removed from setup's template) could silently
orphan a placeholder in a completely unrelated, unchanged file. This runs on every push, not gated
on whether the push touches `skill-sources/`.

**Scope exclusions**, matching `check-placeholder-count.sh`'s own stated reasoning rather than
inventing new ones:
- `platforms/shared/skill-blocks/` — frozen by `check-portability.sh` check 4, cannot be edited to
  satisfy a gate, so scanning it produces unfixable noise, not signal.
- `generators/features/*.md` — composition blocks selected by configuration, not verbatim
  templates; changing what they emit is a design decision, not a defect this gate should flag.

**Pattern duplication, named rather than silently repeated:** this needs the identical
`PLACEHOLDER_PAT` regex `check-placeholder-count.sh` already defines. A third independently-typed
copy is exactly the divergence class this repo has already been burned by twice (CONTRIBUTING.md's
copy vs. `skill-authoring.md`'s; three spellings of the note-status enum). Instead of redefining it,
this script's header cross-references `check-placeholder-count.sh`'s definition by comment, and
`check-portability.sh` gains one new assertion: the two literal pattern strings must stay
byte-identical. Converts "trust two authors typed the same regex" into something a gate verifies.

**Report shape and exit codes**, matching this repo's existing convention: name each undeclared key
and every file/line it appears in.
- `0` — clean, every placeholder used resolves to a declared key.
- `1` — a real undeclared key found.
- `2` — cannot conclude (schema section in `setup/SKILL.md` unreadable/unparseable, or the
  extractor matched zero placeholders across all of `skill-sources/` — the same
  measuring-nothing guard every other check here already has).

### 4. Testing

Follows the sibling pattern `check-placeholder-count.sh` already has
(`reference/test/placeholder-count.test.sh`) — a new `reference/test/vocabulary-schema.test.sh`,
mutation-tested under both bash and zsh, wired into CI.

- **Positive control:** a fixture `skill-sources/` file using an undeclared key → gate FAILs and
  names it.
- **Negative control:** a fixture using only declared keys → gate PASSes.
- **The one real exception:** `{DOMAIN:extraction_categories}` isn't flagged. Mutate it out of the
  exception list and confirm the gate then *does* flag it — proves the exception list neither
  over-fires nor under-fires.
- **`domain_summary:` resolves:** once section 1/2's addition lands, `{vocabulary.domain}` in
  `reduce/SKILL.md` is no longer flagged — validates this design's own fix, not just the gate in
  isolation.
- **Zero-extraction guard:** empty out `PLACEHOLDER_PAT` → rc 2, never a false-clean PASS.
- **Schema-unreadable guard:** point at a missing/malformed `setup/SKILL.md` → rc 2.
- **Pattern cross-reference:** mutate one of the two `PLACEHOLDER_PAT` copies without the other →
  the new `check-portability.sh` assertion catches the drift.

## Deliberately not in scope

- **Retroactively repairing existing vaults.** `second-brain` still has 29 unsubstituted markers
  after this ships — that's `/upgrade`'s job, deferred to a follow-up spec. 16 of the 29
  (`notes`/`inbox`) are already straightforwardly mechanical; the other 13 (`domain` ×12,
  `extraction_categories` ×1) need that follow-up to either backfill `domain_summary:` into old
  manifests or explain its absence and offer a value once the user supplies one.
- **Renumbering the `vocabulary:` block's Levels.** `domain_summary:` lives outside the block
  entirely, specifically to avoid moving `# Level 5:` / `# Level 6:` / `# Level 7:` — markers
  `resolve_canonical_name` and `mechanically_compare` already grep for by exact text.
- **A richer domain schema** (e.g. per-domain descriptions for multi-domain vaults, beyond the one
  `domain_summary:` string). One phrase is what `reduce/SKILL.md`'s 13 uses actually need; a
  per-domain structure would be speculative scope this spec doesn't need.

## Success criteria

- `reference/check-vocabulary-schema.sh` exists, runs in CI unconditionally, and exits 0 on this
  repo's current `skill-sources/` tree once `reduce/SKILL.md`'s `domain` orphan is closed by
  section 1–2's changes.
- `reference/test/vocabulary-schema.test.sh` passes under both bash and zsh, wired into CI.
- `check-portability.sh` gains the pattern-identity assertion and passes.
- A freshly generated vault's `ops/derivation-manifest.md` contains `domain_summary:`, and a fresh
  `extract`/`reduce` skill instance has no unsubstituted `{vocabulary.domain}` markers.
