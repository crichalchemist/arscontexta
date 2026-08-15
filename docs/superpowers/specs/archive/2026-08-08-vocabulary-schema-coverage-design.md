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
| `{vocabulary.domain}` | 12 | reduce only | **No** — no `domain` key exists in this manifest, or in `skills/setup/SKILL.md`'s own manifest template, at all |
| `{DOMAIN:extraction_categories}` | 1 | reduce | N/A — already documented in `skills/upgrade/SKILL.md` as a Level 7 nested list, never a substitution pair by design |

The `notes`/`inbox` cases are ordinary unsubstituted markers — a real value exists, generation
just missed applying it. The `domain` case is categorically different: `reduce/SKILL.md` uses
`{vocabulary.domain}` 12 times, and neither `skills/setup/SKILL.md`'s manifest template (Levels
1–7) nor `reference/vocabulary-transforms.md`'s Universal → Domain Mapping table declares `domain`
as a real vocabulary concept anywhere. This is not multi-domain-specific — no vault, single- or
multi-domain, has ever had a schema slot for it. `reduce/SKILL.md` has been shipping an
unresolvable placeholder in every vault it has ever generated into.

**A fresh-eyes self-review (see "Self-review findings" below) then swept the rest of
`skill-sources/` for the same class of defect** rather than trusting that `domain` was the only
instance, and found three more — none of which, on inspection, actually need a new schema key:

| Marker | Count | Where | What it actually is |
|---|---|---|---|
| `{vocabulary.notes_collection}` | 10, 5 files | reduce, reflect, reweave, stats, verify | A duplicate spelling of the already-declared `{vocabulary.notes}` — every other qmd `--collection`/`collections=[...]` use in `skill-sources/` (graph, next, reflect, reweave, stats) already spells it `{vocabulary.notes}` |
| `{vocabulary.topic_map_plural}` | 28, 5 files | graph, refactor, reflect, reweave, stats | **Already documented** — CLAUDE.md's divergences 7–9 record this exact spelling as "a pre-existing naming mismatch [that] does not match the manifest's declared key `topic_maps`… will not substitute" |
| `{vocabulary.seed}` | 1 | reduce, line 915 | `seed` is one of the ten canonical skill names `skills/upgrade/SKILL.md` explicitly documents as **never** vocabulary-transformable — it should be the literal text `/seed`, not wrapped in substitution syntax at all |
| `{DOMAIN:connect}` | 1 | rethink, line 610 | Not a schema gap — `connect` is this vault's own *rendered* word for `reflect` (`reflect: "connect"` in its manifest), hardcoded into `{DOMAIN:}` syntax where the canonical key `reflect` belongs. Reads as a typo for `{DOMAIN:reflect}` |

This closes the whole discoverable class: `domain` is the only marker that needs a new schema
field; the other three are template-side corrections (three renames, one typo fix), verified
against how the same concepts are already spelled correctly elsewhere in `skill-sources/`.

**Explicitly deferred, not part of this spec:** repairing vaults that already exist (like
`second-brain`, which still has 29 unsubstituted markers after this ships). That is `/upgrade`'s
job — a separate repair capability, scoped in a follow-up spec once this one gives it something
correct to repair to.

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

`skill-sources/reduce/SKILL.md` needs **no wording changes** — its 12 `{vocabulary.domain}` uses
stay exactly as they are. Only the substitution source changes.

**No other key in this design gets a new schema field.** `notes_collection`, `topic_map_plural`,
`seed`, and `connect` are all template-side corrections (section 1b) — adding schema entries for
them would be declaring a concept the vault already has a name for under a different spelling.

### 1b. Template corrections

Four fixes, none touching the schema:

- **`{vocabulary.notes_collection}` → `{vocabulary.notes}`** in `reduce/SKILL.md` (1 use),
  `reflect/SKILL.md` (2 uses), `reweave/SKILL.md` (1 use), `stats/SKILL.md` (1 use),
  `verify/SKILL.md` (2 uses) — 7 line-level edits across 5 files. Mechanical string replacement;
  the surrounding qmd calls are unchanged, only the placeholder spelling.
- **`{vocabulary.topic_map_plural}` → `{vocabulary.topic_maps}`** in `graph/SKILL.md`,
  `refactor/SKILL.md`, `reflect/SKILL.md`, `reweave/SKILL.md`, `stats/SKILL.md` (28 occurrences
  total across the 5 files). Same mechanical replacement; closes the divergence CLAUDE.md's
  divergences 7–9 already named but didn't fix.
- **`{vocabulary.seed}` → `/seed`** in `reduce/SKILL.md:915`. Not a placeholder substitution at
  all — `seed` is a canonical, non-transformable skill name per `skills/upgrade/SKILL.md`'s own
  documented table (`graph`, `next`, `pipeline`, `ralph`, `refactor`, `remember`, `seed`, `stats`,
  `tasks`, `learn` all keep their canonical name in every generated vault, unconditionally). The
  fix removes the `{vocabulary.…}` wrapper entirely rather than pointing it at a schema key.
- **`{DOMAIN:connect}` → `{DOMAIN:reflect}`** in `rethink/SKILL.md:610`. `connect` is not a
  canonical vocabulary key in any manifest; `reflect` is. Reads as a straightforward typo.

Each is verified by grepping for the old spelling after the edit (expect zero matches in
`skill-sources/`) and confirming the gate (section 3) reports it resolved.

### 2. Wiring into the existing substitution machinery

`skills/upgrade/SKILL.md`'s `mechanically_compare()` currently builds its substitution table from
one source: the `vocabulary:` block (`sed -n '/^vocabulary:/,/# Level 7:/p'`). Add one more
extraction step, separate from that block scan since `domain_summary:` lives outside it — inserted
after the existing `vocabulary:` block extraction, before the pairs_file emptiness check:

```bash
domain_line=$(grep '^domain_summary:' "$manifest")
if [ -n "$domain_line" ]; then
  # Captures everything between the FIRST pair of quotes, ignoring anything after --
  # the template line this parses carries a trailing "# e.g., ..." comment (section 1),
  # and an anchor on the closing quote at end-of-line would silently yield empty on any
  # manifest that keeps a similar comment, dropping the key from the pairs table with no
  # error. That is the same silent-empty failure mode this repo's CLAUDE.md warns about
  # throughout; the non-greedy capture avoids it structurally instead of relying on
  # manifests staying comment-free on this one line.
  domain_val=$(printf '%s\n' "$domain_line" | sed -n 's/^domain_summary: "\([^"]*\)".*/\1/p')
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
`check-placeholder-count.sh` — every `{vocabulary.X}` used must resolve to a key declared in one
of two places: the `vocabulary:` block in `skills/setup/SKILL.md`'s manifest template (Levels 1–6
only — Level 7 is a nested list, handled separately below), or the standalone top-level
`domain_summary:` line (mapped to bare key `domain`) added by section 1. **These are two distinct
extraction sources, not one** — `domain_summary:` is deliberately outside the `vocabulary:` block
(section 1), so a parser that only scans the block's sed range will not find it; the script must
extract both, the same two-source shape section 2's substitution table uses.

**`{DOMAIN:X}` resolution reuses `mechanically_compare`'s existing unification logic exactly,
rather than inventing new semantics for this gate.** That function already handles three cases in
order: `{DOMAIN:topic maps}` → `topic_maps`, `{DOMAIN:topic map}` → `topic_map` (both special-cased
ahead of the generic rule because the source spelling contains a space), then
`{DOMAIN:\([a-zA-Z_]*\)}` → the bare key, for every other alphanumeric/underscore spelling. This
gate's `{DOMAIN:X}` handling must apply the identical three-step transform before checking
membership — not a fresh regex, to avoid a second, subtly different definition of "how DOMAIN:
folds to a vocabulary key" existing in the same repo. `{DOMAIN:extraction_categories}` is the one
documented Level 7 exception and is excluded from the fold entirely (never expected to resolve).

**`{config.X}` markers are out of scope for this gate.** The shared `PLACEHOLDER_PAT` (below)
matches three families — `{vocabulary.X}`, `{config.X}`, `{DOMAIN:X}` — because it's shared with
`check-placeholder-count.sh`, whose count-only property needs all three. This gate's *resolution*
question only makes sense for the two vocabulary-shaped families: a config key is never something
`skills/setup/SKILL.md`'s vocabulary schema could declare. The script extracts with the full
pattern (so it doesn't silently miss a future `{config.X}`-shaped mistake that's actually a typo'd
`{vocabulary.X}`) but explicitly skips any `{config.X}` match before the resolution check, and says
so in a comment. Zero `{config.X}` markers exist in `skill-sources/` today, so this is currently a
no-op — stated so the next reader doesn't have to work it out from the code.

**Source of truth:** `skills/setup/SKILL.md`'s own manifest template — the generator's existing
single declared schema. No new schema file; nothing new to keep in sync beyond what already exists.
The Level 1–6 keys are extracted with the identical sed range `mechanically_compare` already uses
(`/^vocabulary:/,/# Level 7:/`) scoped to key names only (the `key: "value"` pattern's left-hand
side), matching the parse this gate must stay consistent with. **Unparseable, for the rc-2 guard,
means:** the `vocabulary:` line is absent from `skills/setup/SKILL.md`, or the closing `# Level 7:`
marker is absent (an unbounded range would silently absorb unrelated trailing content — the exact
hazard `mechanically_compare`'s own header comment already names for this same sed range).

**Why not diff-scoped:** a schema change (a key removed from setup's template) could silently
orphan a placeholder in a completely unrelated, unchanged file. This runs on every push, not gated
on whether the push touches `skill-sources/`.

**Scope of the scan is `skill-sources/`, and only `skill-sources/`** — the exclusions below explain
why the scan isn't wider, the same way `check-placeholder-count.sh`'s own header explains its
identical two exclusions; they are not a second scan root:
- `platforms/shared/skill-blocks/` — frozen by `check-portability.sh` check 4, cannot be edited to
  satisfy a gate, so scanning it would produce unfixable noise, not signal.
- `generators/features/*.md` — composition blocks selected by configuration, not verbatim
  templates; changing what they emit is a design decision, not a defect this gate should flag.

**Invocation interface**, needed for the test fixtures in section 4 to exist at all: the script
takes no required arguments — default scan root is `skill-sources/` (repo-root-relative) and
default schema file is `skills/setup/SKILL.md`. Both are overridable via environment variables
(`SCAN_ROOT`, `SCHEMA_FILE`) so tests can point at fixture directories without needing a full clone
of the real templates. Mirrors `check-placeholder-count.sh`'s own single positional-argument
pattern (a base ref, defaulted to `main`) for the same reason: a gate that can't be pointed at a
fixture can't be mutation-tested.

**Pattern is a single definition, not two copies to keep in sync.** `check-placeholder-count.sh`
already defines `PLACEHOLDER_PAT`; per this repo's own stated policy in `skills/upgrade/SKILL.md`
("a new shared library... revisit only if a second caller appears" — one has now appeared), this
extracts the one-line constant into `reference/lib/placeholder-pattern.sh`, sourced by both
scripts. This isn't a new library in the `link-extraction.sh`/`frontmatter.sh` sense (no version
constant, no `ops/lib/` vault-side copy needed — this pattern is generator-repo-internal, never
runs inside a vault) — a single sourced file, nothing more. Removes the divergence risk this repo
has already shipped twice (CONTRIBUTING.md's copy vs. `skill-authoring.md`'s; three spellings of
the note-status enum) by construction, rather than by an assertion that two copies still happen to
agree.

**Report shape and exit codes**, matching this repo's existing convention: name each undeclared key
and every file/line it appears in.
- `0` — clean, every placeholder used resolves to a declared key.
- `1` — a real undeclared key found.
- `2` — cannot conclude (schema section in `setup/SKILL.md` unreadable/unparseable per the
  definition above, or the extractor matched zero placeholders across all of `skill-sources/` —
  the same measuring-nothing guard every other check here already has).

### 4. Testing

Follows the sibling pattern `check-placeholder-count.sh` already has
(`reference/test/placeholder-count.test.sh`) — a new `reference/test/vocabulary-schema.test.sh`,
mutation-tested under both bash and zsh, wired into CI.

- **Positive control:** a fixture `skill-sources/` file (via `SCAN_ROOT`) using an undeclared key →
  gate FAILs and names it.
- **Negative control:** a fixture using only declared keys → gate PASSes.
- **The Level 7 exception:** `{DOMAIN:extraction_categories}` isn't flagged. Mutate it out of the
  exception list and confirm the gate then *does* flag it.
- **The two special-cased `{DOMAIN:X}` spellings:** a fixture using `{DOMAIN:topic map}` and
  `{DOMAIN:topic maps}` resolves cleanly (proves the gate's fold reuses `mechanically_compare`'s
  exact transform, not a naive per-word match that would flag the space-containing spelling).
- **`{config.X}` is skipped, not flagged:** a fixture containing `{config.something}` with no
  corresponding declaration still PASSes — proves the exclusion in section 3 is real, not aspirational.
- **`domain_summary:` resolves:** once section 1/2's addition lands, `{vocabulary.domain}` in
  `reduce/SKILL.md` is no longer flagged.
- **The four template corrections (section 1b) each clear the gate once fixed:** re-run against the
  real `reduce`/`reflect`/`reweave`/`stats`/`verify`/`graph`/`refactor`/`rethink` files after each
  fix and confirm the specific key/marker it targeted no longer appears in the FAIL report.
- **Zero-extraction guard:** empty out `PLACEHOLDER_PAT` (via the shared
  `reference/lib/placeholder-pattern.sh`) → rc 2, never a false-clean PASS.
- **Schema-unreadable guard:** point `SCHEMA_FILE` at a missing file, and separately at a fixture
  missing the `# Level 7:` closing marker → both rc 2, per the "unparseable" definition in section 3.
- **Pattern single-source:** `check-placeholder-count.sh` and this gate both import from
  `reference/lib/placeholder-pattern.sh` — a test asserting neither script defines `PLACEHOLDER_PAT`
  locally (i.e., the constant only exists once in the tree) makes a reintroduced duplicate copy fail
  loudly instead of silently drifting.

## Deliberately not in scope

- **Retroactively repairing existing vaults.** `second-brain` still has 29 unsubstituted markers
  after this ships — that's `/upgrade`'s job, deferred to a follow-up spec. 16 of the 29
  (`notes`/`inbox`) are already straightforwardly mechanical; the `domain` ×12 need that follow-up
  to either backfill `domain_summary:` into old manifests or explain its absence and offer a value
  once the user supplies one. The `extraction_categories` ×1 stays as documented (never expected to
  substitute).
- **Renumbering the `vocabulary:` block's Levels.** `domain_summary:` lives outside the block
  entirely, specifically to avoid moving `# Level 5:` / `# Level 6:` / `# Level 7:` — markers
  `resolve_canonical_name` and `mechanically_compare` already grep for by exact text.
- **A richer domain schema** (e.g. per-domain descriptions for multi-domain vaults, beyond the one
  `domain_summary:` string). One phrase is what `reduce/SKILL.md`'s 12 uses actually need; a
  per-domain structure would be speculative scope this spec doesn't need.
- **A general `{config.X}` schema-coverage gate.** Zero instances exist today; building resolution
  semantics for a placeholder family with no live example would be speculative. Revisit if one ever
  appears.

## Success criteria

- `reference/check-vocabulary-schema.sh` exists, runs in CI unconditionally, and exits **0** on
  this repo's current `skill-sources/` tree once section 1's schema field and section 1b's four
  template corrections have all landed — not "once the domain orphan is closed" alone, since the
  self-review found three more instances that would otherwise leave the gate red on day one.
- `reference/test/vocabulary-schema.test.sh` passes under both bash and zsh, wired into CI.
- `reference/lib/placeholder-pattern.sh` exists; both `check-placeholder-count.sh` and the new gate
  source it; the pattern-single-source test (section 4) passes.
- A freshly generated vault's `ops/derivation-manifest.md` contains `domain_summary:`, and a fresh
  `reduce` skill instance has no unsubstituted `{vocabulary.domain}` markers. (Manual verification —
  requires a full derivation conversation; not CI-checkable the way the other three criteria are.)

## Self-review findings

A model-diverse self-review (Fable) caught that the first draft of this spec undercounted the
defect class it closes — it verified only `domain`'s absence from the schema and extrapolated that
as the whole gap, without sweeping the rest of `skill-sources/` for other undeclared keys. That
sweep found three more (`notes_collection`, `topic_map_plural`, `seed`) plus one unrelated typo
(`{DOMAIN:connect}`), all now folded into this spec (Background section, section 1b). It also
caught: a genuine mechanism contradiction between "cross-reference by comment" and "two copies to
compare" (resolved by extracting a single shared constant instead of either); an ambiguous
`{DOMAIN:X}` resolution rule that would have changed the gate's findings by dozens depending on
reading (resolved by reusing `mechanically_compare`'s exact existing transform); an unstated
`{config.X}` handling gap; an undefined script invocation interface the test plan depends on; and a
sed anchor in section 2 that would have silently dropped `domain_summary:` from the substitution
table on any manifest line carrying a trailing comment (the exact silent-empty failure class this
repo's own CLAUDE.md catalogs repeatedly). All addressed above, not deferred.
