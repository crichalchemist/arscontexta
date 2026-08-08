# Vocabulary Schema Coverage Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the `{vocabulary.domain}` orphan (and three sibling defects the self-review found)
by adding a real schema field, fixing the four template-side misspellings, and building a CI gate
that stops a future orphaned placeholder from shipping again.

**Architecture:** A new top-level `domain_summary:` manifest field, wired into
`skills/upgrade/SKILL.md`'s existing substitution machinery the same way `topic_map`/`topic_maps`
already alias. A new whole-tree (not diff-relative) static gate,
`reference/check-vocabulary-schema.sh`, cross-checks every `{vocabulary.X}`/`{DOMAIN:X}` used in
`skill-sources/` against the schema `skills/setup/SKILL.md` declares. `{DOMAIN:X}` folding reuses
`mechanically_compare()`'s exact existing three-step transform rather than a second definition.
`PLACEHOLDER_PAT` moves into one shared file both this gate and `check-placeholder-count.sh` source.

**Tech Stack:** POSIX-portable bash/zsh (this repo's existing convention — every script and test
runs under both shells), no new dependencies.

## Global Constraints

- Every new/modified shell script and test must pass under **both bash and zsh** — this repo's
  existing convention (`for s in bash zsh; do $s reference/test/....test.sh; done`).
- `PLACEHOLDER_PAT` must exist in exactly one place after this plan lands
  (`reference/lib/placeholder-pattern.sh`) — never redefined locally in either
  `check-placeholder-count.sh` or the new gate.
- `{DOMAIN:X}` folding in the new gate must reuse `mechanically_compare()`'s exact three-step
  transform (special-case `topic maps`/`topic map`, then generic alphanumeric/underscore) —
  never a second, independently-typed definition of the same fold.
- `domain_summary:` is a top-level manifest field, **outside** the `vocabulary:` block — never
  move or renumber the block's `# Level 5:` / `# Level 6:` / `# Level 7:` markers, which
  `resolve_canonical_name` and `mechanically_compare` grep for by exact text.
- Every new script follows this repo's existing exit-code convention: `0` clean, `1` a real
  finding, `2` cannot conclude (guards against measuring nothing — a schema/pattern that yields
  zero extracted items must never read as a clean pass).
- `LC_ALL=C` on every `sort`/`comm` pairing that must agree — this repo has already shipped a
  locale-collation bug once (the dangling-link scan) and the fix there is the standing pattern.
- No task edits `CLAUDE.md`'s prose numbers speculatively. Task 7 runs
  `reference/check-doc-claims.sh` and fixes only what it reports — this repo has repeatedly
  regressed by hand-editing those counts ahead of the gate that verifies them.

---

### Task 1: Extract the shared placeholder pattern

**Files:**
- Create: `reference/lib/placeholder-pattern.sh`
- Modify: `reference/check-placeholder-count.sh:32` (the `PLACEHOLDER_PAT=` line and its
  surrounding comment block)
- Test: `reference/test/placeholder-count.test.sh` (existing suite — this task's test is that it
  still passes identically, proving the refactor is behavior-preserving)

**Interfaces:**
- Produces: `PLACEHOLDER_PAT` (shell variable), sourced via
  `. "$HERE/lib/placeholder-pattern.sh"` where `$HERE` is the sourcing script's own directory.
  Every later task that needs the three-family placeholder regex sources this file; none
  redefines the pattern locally.

- [ ] **Step 1: Record the baseline test result**

Run: `for s in bash zsh; do $s reference/test/placeholder-count.test.sh | tail -1; done`
Expected: both report `40/40` (this repo's documented current count — confirm the actual output
before touching anything, since this is the number the refactor must not change).

- [ ] **Step 2: Create the shared pattern file**

```bash
#!/bin/bash
# placeholder-pattern.sh -- the single definition of arscontexta's three placeholder
# families: {vocabulary.X}, {config.X}, {DOMAIN:X}.
#
# Sourced by reference/check-placeholder-count.sh (count-only property: no skill-sources/
# file loses placeholders across a diff range) and reference/check-vocabulary-schema.sh
# (resolution property: every {vocabulary.X}/{DOMAIN:X} used must resolve to a declared
# schema key). One definition, not two independently-typed copies -- this repo has already
# shipped that exact divergence twice (CONTRIBUTING.md's copy vs. skill-authoring.md's;
# three spellings of the note-status enum). See
# docs/superpowers/specs/2026-08-08-vocabulary-schema-coverage-design.md.
#
# Do NOT widen to a bare {...}: that also matches ${TARGET} and ${FILE}, turning a
# shell-variable count into a placeholder count. skill-authoring.md section 2 says so.
PLACEHOLDER_PAT='{vocabulary\.[a-z_]*}\|{config\.[a-z_]*}\|{DOMAIN:[^}]*}'
```

- [ ] **Step 3: Wire `check-placeholder-count.sh` to source it**

Replace the existing `PLACEHOLDER_PAT='...'` line (currently line 32) and its preceding comment
block (lines 20–31, the "WHY THE PATTERN IS THE THREE-FAMILY ONE" explanation — keep that
explanation, it documents *why* the pattern has three families, which still matters even though
the pattern itself now lives elsewhere) with:

```bash
# The pattern itself now lives in reference/lib/placeholder-pattern.sh -- sourced, not
# redefined, so this script and check-vocabulary-schema.sh can never independently drift.
# See that file's own header for why the pattern has three families.
. "$HERE/lib/placeholder-pattern.sh"
```

placed after the existing `HERE="$(cd "$(dirname "$0")" && pwd)"` line (this script already
computes `$HERE` near its top — reuse it, don't recompute).

- [ ] **Step 4: Re-run the existing test suite and confirm identical results**

Run: `for s in bash zsh; do $s reference/test/placeholder-count.test.sh | tail -1; done`
Expected: both still report `40/40` — the exact number from Step 1. Any change means the
extraction altered behavior, which this task must not do.

- [ ] **Step 5: Commit**

```bash
git add reference/lib/placeholder-pattern.sh reference/check-placeholder-count.sh
git commit -m "Extract PLACEHOLDER_PAT into a shared file, sourced not redefined

A second caller (the vocabulary-schema-coverage gate, next task) is about
to need this exact pattern. Per this repo's own stated policy in
skills/upgrade/SKILL.md ('revisit only if a second caller appears'),
extract it now rather than typing a second independent copy -- the
divergence class this repo has already shipped twice.

reference/test/placeholder-count.test.sh: 40/40 before and after,
confirming this is behavior-preserving."
```

---

### Task 2: Add `domain_summary:` to the manifest schema template

**Files:**
- Modify: `skills/setup/SKILL.md` (near line 1146, the `dimensions:`/`domains:`/`vocabulary:`
  manifest template section — confirm exact current line numbers by reading the file, they may
  have shifted)

**Interfaces:**
- Produces: the manifest template documents `domain_summary: "[domain term]"` as a real field
  every future `/setup` run should populate. Task 4's gate reads this exact line (`grep -q
  '^domain_summary:'` against `skills/setup/SKILL.md`).

- [ ] **Step 1: Read the current template to confirm placement**

Run: `grep -n '^  dimensions:\|^  domains:\|^  vocabulary:' skills/setup/SKILL.md`

Find the line where `vocabulary:` opens (around line 1146). `domain_summary:` goes **immediately
before** that line, at the same indentation level as `vocabulary:` itself (i.e., NOT inside the
block) — it needs its own line, not nested under `vocabulary:`.

- [ ] **Step 2: Add the template line**

Insert directly before the `vocabulary:` line:

```yaml
domain_summary: "[domain term]"  # e.g., "day trading strategy research" -- one-line
                                  # description of what this vault covers; used by
                                  # reduce/SKILL.md's selectivity gate. Collected the
                                  # same way for single- and multi-domain vaults.
vocabulary:
  # Level 1: Folder names
  ...
```

- [ ] **Step 3: Verify the line is well-formed and correctly placed**

Run: `grep -n '^domain_summary:' skills/setup/SKILL.md`
Expected: exactly one match, immediately preceding the `vocabulary:` line.

Run: `grep -c '^domain_summary:' skills/setup/SKILL.md`
Expected: `1`.

- [ ] **Step 4: Confirm no existing Level marker moved**

Run: `grep -n '# Level 5: Process verbs\|# Level 6:\|# Level 7:' skills/setup/SKILL.md`
Expected: the same three lines that existed before this edit (only their line numbers may shift
by exactly the number of lines this step inserted — the marker *text* itself must be byte-identical,
since `resolve_canonical_name` and `mechanically_compare` grep for it verbatim).

- [ ] **Step 5: Commit**

```bash
git add skills/setup/SKILL.md
git commit -m "Add domain_summary: as a real manifest schema field

skill-sources/reduce/SKILL.md has used {vocabulary.domain} 12 times in
every vault it has ever generated into, and no manifest schema --
neither Levels 1-7 here nor reference/vocabulary-transforms.md --
has ever declared a domain key. Not multi-domain-specific: no vault,
single- or multi-domain, has ever had a schema slot for it.

Placed as a standalone top-level field, outside the vocabulary: block,
specifically so none of the block's Level markers move -- those are
grepped for by exact text elsewhere (resolve_canonical_name,
mechanically_compare)."
```

---

### Task 3: Fix the four template-side corrections

**Files:**
- Modify: `skill-sources/reduce/SKILL.md` (notes_collection ×1, seed ×1 at line 915)
- Modify: `skill-sources/reflect/SKILL.md` (notes_collection ×2, topic_map_plural ×13)
- Modify: `skill-sources/reweave/SKILL.md` (notes_collection ×1, topic_map_plural ×6)
- Modify: `skill-sources/stats/SKILL.md` (notes_collection ×1, topic_map_plural ×4)
- Modify: `skill-sources/verify/SKILL.md` (notes_collection ×2)
- Modify: `skill-sources/graph/SKILL.md` (topic_map_plural ×3)
- Modify: `skill-sources/refactor/SKILL.md` (topic_map_plural ×2)
- Modify: `skill-sources/rethink/SKILL.md:610` (`{DOMAIN:connect}` → `{DOMAIN:reflect}`)

**Interfaces:**
- Produces: zero occurrences of `{vocabulary.notes_collection}`, `{vocabulary.topic_map_plural}`,
  `{vocabulary.seed}`, or `{DOMAIN:connect}` anywhere in `skill-sources/`. Task 6's gate
  verifies this by finding zero undeclared keys of these four kinds.

- [ ] **Step 1: Confirm the exact current counts before editing**

```bash
grep -rc 'vocabulary\.notes_collection' skill-sources/*/SKILL.md 2>/dev/null | grep -v ':0'
grep -rc 'vocabulary\.topic_map_plural' skill-sources/*/SKILL.md 2>/dev/null | grep -v ':0'
grep -n 'vocabulary\.seed' skill-sources/reduce/SKILL.md
grep -n 'DOMAIN:connect' skill-sources/rethink/SKILL.md
```

Note the exact counts returned — Step 4 verifies against these, not the numbers in this plan
(which may have drifted since this plan was written).

- [ ] **Step 2: Replace `{vocabulary.notes_collection}` with `{vocabulary.notes}`**

In each of `reduce/SKILL.md`, `reflect/SKILL.md`, `reweave/SKILL.md`, `stats/SKILL.md`,
`verify/SKILL.md`, replace every literal occurrence of `{vocabulary.notes_collection}` with
`{vocabulary.notes}`. This is a straight string substitution — the surrounding qmd
`--collection`/`collections=[...]` syntax is unchanged, only the placeholder spelling. Confirm
by re-reading the diff for each file that no other line changed.

- [ ] **Step 3: Replace `{vocabulary.topic_map_plural}` with `{vocabulary.topic_maps}`**

In each of `graph/SKILL.md`, `refactor/SKILL.md`, `reflect/SKILL.md`, `reweave/SKILL.md`,
`stats/SKILL.md`, replace every literal occurrence of `{vocabulary.topic_map_plural}` with
`{vocabulary.topic_maps}`. Same straight substitution.

- [ ] **Step 4: Fix `{vocabulary.seed}` → literal `/seed`**

In `reduce/SKILL.md` around line 915, change:

```
`/{vocabulary.seed}` reads **width-agnostically** — three digits or more, padded or not — so both
```

to:

```
`/seed` reads **width-agnostically** — three digits or more, padded or not — so both
```

`seed` is one of the ten canonical skill names `skills/upgrade/SKILL.md` documents as never
vocabulary-transformable — it is not a substitution at all, so the fix removes the wrapper
entirely rather than pointing it at any key.

- [ ] **Step 5: Fix `{DOMAIN:connect}` → `{DOMAIN:reflect}`**

In `rethink/SKILL.md:610`, change:

```
  Run /{DOMAIN:connect} on promoted notes to find connections.
```

to:

```
  Run /{DOMAIN:reflect} on promoted notes to find connections.
```

- [ ] **Step 6: Verify zero occurrences of all four old spellings remain**

```bash
grep -rl 'vocabulary\.notes_collection\|vocabulary\.topic_map_plural\|vocabulary\.seed\|DOMAIN:connect' skill-sources/ 2>/dev/null
```

Expected: no output (exit status 1 from grep, meaning no matches).

- [ ] **Step 7: Confirm the replacement counts match what was removed**

```bash
grep -rc 'vocabulary\.notes}' skill-sources/*/SKILL.md 2>/dev/null | grep -v ':0'
grep -rc 'vocabulary\.topic_maps}' skill-sources/*/SKILL.md 2>/dev/null | grep -v ':0'
```

Each file's count here should have increased by exactly the count that file had for the old
spelling in Step 1 (some files already used the correct spelling alongside the incorrect one —
this only confirms the NEW total is consistent, not that every occurrence in the file is from
this task).

- [ ] **Step 8: Commit**

```bash
git add skill-sources/reduce/SKILL.md skill-sources/reflect/SKILL.md \
        skill-sources/reweave/SKILL.md skill-sources/stats/SKILL.md \
        skill-sources/verify/SKILL.md skill-sources/graph/SKILL.md \
        skill-sources/refactor/SKILL.md skill-sources/rethink/SKILL.md
git commit -m "Fix four template-side placeholder misspellings

None needed a new schema key -- all four are corrections to an existing,
already-declared concept spelled wrong:

- {vocabulary.notes_collection} -> {vocabulary.notes}: a duplicate
  spelling; every other qmd collection reference in skill-sources/
  already used the correct one.
- {vocabulary.topic_map_plural} -> {vocabulary.topic_maps}: already
  documented in this repo's CLAUDE.md divergences 7-9 as a naming
  mismatch against the declared key, never fixed until now.
- {vocabulary.seed} -> literal /seed: seed is one of the ten canonical
  skill names skills/upgrade/SKILL.md documents as never
  vocabulary-transformable; this was substitution syntax wrapped
  around a name that should never have been wrapped.
- {DOMAIN:connect} -> {DOMAIN:reflect}: a typo -- connect is this
  vault's own rendered word for reflect, hardcoded where the
  canonical key belongs."
```

---

### Task 4: Wire `domain_summary:` into the substitution machinery

**Files:**
- Modify: `skills/upgrade/SKILL.md` (the `mechanically_compare()` function, and the
  `render_current_template` instructions immediately above it)

**Interfaces:**
- Consumes: nothing new from earlier tasks (reads `ops/derivation-manifest.md`, a vault-side
  file, at runtime).
- Produces: `mechanically_compare()`'s pairs table now includes a `domain` → `<folded value>`
  row whenever the manifest it's given contains a `domain_summary:` line. Callers (Step 1 of
  `skills/upgrade/SKILL.md`) are unaffected — this only changes what the substitution table
  contains, not the function's external interface.

- [ ] **Step 1: Write a standalone fixture test for the new extraction, and confirm it fails first**

Create a throwaway test script (not committed — this proves the change before it exists, per
this repo's TDD convention for testing bash fences extracted from `SKILL.md` files):

```bash
cat > /tmp/domain-wiring-test.sh <<'TESTEOF'
#!/bin/bash
set -uo pipefail
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cat > "$tmpdir/manifest.md" <<'EOF'
---
vocabulary:
  notes: "nodes"
# Level 7:
domain_summary: "Day Trading Strategy Research"
EOF

# Extract the function verbatim from the current SKILL.md (before this task's edit) to
# prove it does NOT yet emit a domain row.
awk '/^mechanically_compare\(\) \{/,/^}/' skills/upgrade/SKILL.md > "$tmpdir/fn.sh"
[ -s "$tmpdir/fn.sh" ] || { echo "FAIL: could not extract mechanically_compare() from skills/upgrade/SKILL.md"; exit 1; }
. "$tmpdir/fn.sh"

cd "$tmpdir" || exit 1
cp manifest.md ops-derivation-manifest.md  # mechanically_compare reads "ops/derivation-manifest.md" relative to cwd
mkdir -p ops && mv ops-derivation-manifest.md ops/derivation-manifest.md

echo '{vocabulary.notes} {vocabulary.domain}' > canon.md
echo 'nodes day trading strategy research' > installed.md

out=$(mechanically_compare canon.md installed.md)
if [ -z "$out" ]; then
  echo "FAIL (expected before this task's fix): domain resolved when it should not have yet"
  exit 1
else
  echo "PASS (expected before this task's fix): domain is NOT yet resolved -- diff is non-empty"
  exit 0
fi
TESTEOF
bash /tmp/domain-wiring-test.sh
```

Expected: `PASS (expected before this task's fix): domain is NOT yet resolved` — confirming the
function does not yet handle `domain_summary:`, before making the change that fixes it.

- [ ] **Step 2: Add the `domain_summary:` extraction to `mechanically_compare()`**

Locate the existing block in `skills/upgrade/SKILL.md` that builds `pairs_file` (the `while IFS=
read -r line; do ... done <<EOF_VOCAB` loop and the `topic_map_val`/`topic_maps_val` aliasing
immediately after it). Insert this new block immediately after that aliasing, before the `if [ !
-s "$pairs_file" ]` emptiness check:

```bash
  # domain_summary: is a standalone top-level manifest field, deliberately outside the
  # vocabulary: block above (see docs/superpowers/specs/2026-08-08-vocabulary-schema-coverage-design.md)
  # -- extracted separately, same fold-and-append shape as the topic_map/topic_maps
  # aliasing just above, applied to a second source.
  domain_line=$(grep '^domain_summary:' "$manifest")
  if [ -n "$domain_line" ]; then
    # Captures everything between the FIRST pair of quotes, ignoring anything after --
    # the template line this parses carries a trailing "# e.g., ..." comment, and an
    # anchor on the closing quote at end-of-line would silently yield empty on any
    # manifest keeping a similar comment, dropping the key from the pairs table with
    # no error.
    domain_val=$(printf '%s\n' "$domain_line" | sed -n 's/^domain_summary: "\([^"]*\)".*/\1/p')
    domain_val=$(printf '%s' "$domain_val" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]_[:space:]' ' ' | awk '{$1=$1}1')
    [ -n "$domain_val" ] && printf 'domain\t%s\n' "$domain_val" >> "$pairs_file"
  fi
```

- [ ] **Step 3: Add the `render_current_template` instruction**

In the "Shared Step: Rendering the Canonical Template in This Vault's Vocabulary" section
(immediately above `mechanically_compare()`), in the numbered list describing how vocabulary
transformation is applied, add one sentence:

```
   For `{vocabulary.domain}` specifically, use the manifest's `domain_summary:` field rather
   than the `vocabulary:` block — it is a standalone top-level field, not part of the
   Levels 1-6 substitution table.
```

- [ ] **Step 4: Re-run the fixture test and confirm it now shows resolution**

```bash
cat > /tmp/domain-wiring-test-2.sh <<'TESTEOF'
#!/bin/bash
set -uo pipefail
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/ops"
cat > "$tmpdir/ops/derivation-manifest.md" <<'EOF'
---
vocabulary:
  notes: "nodes"
# Level 7:
domain_summary: "Day Trading Strategy Research"
EOF

awk '/^mechanically_compare\(\) \{/,/^}/' skills/upgrade/SKILL.md > "$tmpdir/fn.sh"
[ -s "$tmpdir/fn.sh" ] || { echo "FAIL: could not extract mechanically_compare() after the edit"; exit 1; }
. "$tmpdir/fn.sh"

cd "$tmpdir" || exit 1
echo '{vocabulary.notes} {vocabulary.domain}' > canon.md
echo 'nodes day trading strategy research' > installed.md

out=$(mechanically_compare canon.md installed.md)
if [ -z "$out" ]; then
  echo "PASS: domain now resolves -- mechanically_compare's diff is empty"
  exit 0
else
  echo "FAIL: domain still does not resolve"
  echo "diff output: $out"
  exit 1
fi
TESTEOF
bash /tmp/domain-wiring-test-2.sh
zsh /tmp/domain-wiring-test-2.sh
```

Expected: `PASS` under both shells.

- [ ] **Step 5: Confirm an absent `domain_summary:` still degrades gracefully**

```bash
cat > /tmp/domain-wiring-test-3.sh <<'TESTEOF'
#!/bin/bash
set -uo pipefail
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/ops"
cat > "$tmpdir/ops/derivation-manifest.md" <<'EOF'
---
vocabulary:
  notes: "nodes"
# Level 7:
EOF
awk '/^mechanically_compare\(\) \{/,/^}/' skills/upgrade/SKILL.md > "$tmpdir/fn.sh"
. "$tmpdir/fn.sh"
cd "$tmpdir" || exit 1
echo '{vocabulary.notes}' > canon.md
echo 'nodes' > installed.md
out=$(mechanically_compare canon.md installed.md)
rc=$?
if [ "$rc" -ne 0 ] && [ -z "$out" ]; then
  echo "PASS: an older manifest with no domain_summary: still evaluates cleanly for the keys it does declare"
else
  echo "unexpected: rc=$rc out=[$out]"
  exit 1
fi
TESTEOF
bash /tmp/domain-wiring-test-3.sh
```

Expected: `PASS` — an older vault's manifest, lacking `domain_summary:` entirely, is unaffected
for every key it does declare.

- [ ] **Step 6: Commit**

```bash
git add skills/upgrade/SKILL.md
git commit -m "Wire domain_summary: into mechanically_compare() and render_current_template

Same fold-and-append shape the existing topic_map/topic_maps -> MOC/MOCs
aliasing already uses, applied to a second source (domain_summary: is
outside the vocabulary: block, so it needs its own extraction, not a
wider block scan).

Verified via a standalone extraction of mechanically_compare() run
against fixture manifests: resolves when domain_summary: is present,
degrades gracefully (unaffected for every other key) when it's absent
-- an older vault without this field yet is not broken by the change."
```

---

### Task 5: Build `reference/check-vocabulary-schema.sh`

**Files:**
- Create: `reference/check-vocabulary-schema.sh`
- Create: `reference/test/vocabulary-schema.test.sh`

**Interfaces:**
- Consumes: `PLACEHOLDER_PAT` from `reference/lib/placeholder-pattern.sh` (Task 1).
- Produces: exit 0/1/2 per this repo's convention; env vars `SCAN_ROOT` (default
  `skill-sources`) and `SCHEMA_FILE` (default `skills/setup/SKILL.md`) for fixture-driven
  testing.

- [ ] **Step 1: Write the first two test assertions and confirm they fail (script doesn't exist)**

```bash
cat > reference/test/vocabulary-schema.test.sh <<'TESTEOF'
#!/bin/bash
# vocabulary-schema.test.sh -- mutation tests for reference/check-vocabulary-schema.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
GATE="$ROOT/check-vocabulary-schema.sh"
pass=0; fail=0
assert() { if [ "$1" = "$2" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $3 (expected [$2] got [$1])"; fi; }

fixture_schema() {
  cat > "$1" <<'EOF'
vocabulary:
  # Level 1: Folder names
  notes: "[domain term]"
  inbox: "[domain term]"
# Level 5: Process verbs
  reduce: "[domain term]"
# Level 6: Command names
  cmd_reduce: "[/domain-verb]"
# Level 7: Extraction categories
  extraction_categories:
EOF
}

# --- Assertion 1: positive control -- undeclared key FAILs ------------------------------
tmp1=$(mktemp -d); mkdir -p "$tmp1/scan"
fixture_schema "$tmp1/schema.md"
echo '{vocabulary.undeclared_thing}' > "$tmp1/scan/x.md"
SCAN_ROOT="$tmp1/scan" SCHEMA_FILE="$tmp1/schema.md" bash "$GATE" >/dev/null 2>&1
assert "$?" "1" "positive control: undeclared key fails"
rm -rf "$tmp1"

# --- Assertion 2: negative control -- only declared keys PASSes -------------------------
tmp2=$(mktemp -d); mkdir -p "$tmp2/scan"
fixture_schema "$tmp2/schema.md"
echo '{vocabulary.notes} {vocabulary.inbox} {vocabulary.reduce}' > "$tmp2/scan/x.md"
SCAN_ROOT="$tmp2/scan" SCHEMA_FILE="$tmp2/schema.md" bash "$GATE" >/dev/null 2>&1
assert "$?" "0" "negative control: only declared keys passes"
rm -rf "$tmp2"

echo "$pass/$((pass+fail))"
[ "$fail" -eq 0 ]
TESTEOF
bash reference/test/vocabulary-schema.test.sh
```

Expected: fails with a "command not found" / nonzero exit from the `bash "$GATE"` calls, since
`reference/check-vocabulary-schema.sh` doesn't exist yet — confirming the tests exercise
something real before the implementation exists.

- [ ] **Step 2: Implement the gate script**

```bash
cat > reference/check-vocabulary-schema.sh <<'SCRIPTEOF'
#!/bin/bash
# check-vocabulary-schema.sh -- does every {vocabulary.X}/{DOMAIN:X} used in skill-sources/
# resolve to a key the generator's own schema declares?
#
# See docs/superpowers/specs/2026-08-08-vocabulary-schema-coverage-design.md. Short version:
# skill-sources/reduce/SKILL.md shipped {vocabulary.domain} for years with no schema key
# anywhere ever declaring `domain` -- an unresolvable placeholder in every vault it ever
# generated into. This is a whole-tree static check (not diff-relative like
# check-placeholder-count.sh): a schema key removed anywhere could silently orphan a
# placeholder in a completely unrelated, unchanged file.
#
# SCOPE: skill-sources/ only. platforms/shared/skill-blocks/ is frozen (check-portability.sh
# check 4) and cannot be edited to satisfy this gate; generators/features/*.md are
# composition blocks selected by config, not verbatim templates. Excluded for the same
# reasons check-placeholder-count.sh already excludes them.
#
# {config.X} markers are extracted (so a typo'd {vocabulary.X} spelled {config.X} is never
# silently missed) but never checked for resolution -- no schema declares config keys.
# Zero {config.X} markers exist in skill-sources/ today; currently a no-op.
#
# EXIT CODES:
#   0  every {vocabulary.X}/{DOMAIN:X} used resolves to a declared key
#   1  at least one undeclared key found
#   2  cannot conclude -- schema unparseable, or zero placeholders extracted

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT" || { echo "check-vocabulary-schema: cannot cd to repo root '$ROOT'" >&2; exit 2; }

. "$HERE/lib/placeholder-pattern.sh"

SCAN_ROOT="${SCAN_ROOT:-skill-sources}"
SCHEMA_FILE="${SCHEMA_FILE:-skills/setup/SKILL.md}"

echo "=== check-vocabulary-schema ==="
echo "property: every {vocabulary.X}/{DOMAIN:X} used in $SCAN_ROOT/ resolves to a declared schema key"
echo "scope:    $SCAN_ROOT/ only; platforms/shared/skill-blocks/ and generators/features/ are out by design"
echo "NOT checked: {config.X} resolution -- no schema declares config keys, and none exist today"
echo

die2() { printf '  CANNOT CONCLUDE: %s\n' "$1"; echo; echo "VOCABULARY SCHEMA: CANNOT CONCLUDE"; exit 2; }

[ -d "$SCAN_ROOT" ] || die2 "$SCAN_ROOT/ does not exist -- wrong root, or SCAN_ROOT is misconfigured"
[ -f "$SCHEMA_FILE" ] || die2 "$SCHEMA_FILE does not exist -- wrong root, or SCHEMA_FILE is misconfigured"

# --- declared keys: Level 1-6 from the vocabulary: block, plus domain_summary: ------------
grep -q '^vocabulary:' "$SCHEMA_FILE" || die2 "$SCHEMA_FILE has no 'vocabulary:' block -- cannot build the declared-key set"
grep -q '# Level 7:' "$SCHEMA_FILE" || die2 "$SCHEMA_FILE has no '# Level 7:' marker -- cannot bound the vocabulary: block's extraction (an unbounded range would silently absorb unrelated trailing content)"

declared_keys=$(sed -n '/^vocabulary:/,/# Level 7:/{/^  [a-zA-Z_]*: /p;}' "$SCHEMA_FILE" \
  | sed -n 's/^  \([a-zA-Z_]*\):.*/\1/p' | LC_ALL=C sort -u)

if grep -q '^domain_summary:' "$SCHEMA_FILE"; then
  declared_keys=$(printf '%s\ndomain\n' "$declared_keys" | LC_ALL=C sort -u)
fi

n_declared=$(printf '%s\n' "$declared_keys" | grep -c . || true)
[ "${n_declared:-0}" -gt 0 ] || die2 "extracted ZERO declared keys from $SCHEMA_FILE -- the parse is broken, not the schema empty"

# --- used keys: every {vocabulary.X} and {DOMAIN:X} across $SCAN_ROOT/, folded ------------
# {DOMAIN:X} folds through the SAME three-step transform mechanically_compare() uses in
# skills/upgrade/SKILL.md: the two space-containing special cases first, then the generic
# alphanumeric/underscore rule. Reusing this transform, not inventing a new one, is the
# point -- a second, subtly different definition of "how DOMAIN: folds" is exactly the
# divergence class this repo has already shipped twice.
raw_matches=$(grep -rohE "$PLACEHOLDER_PAT" "$SCAN_ROOT" 2>/dev/null || true)
[ -n "$raw_matches" ] || die2 "extracted ZERO placeholders across all of $SCAN_ROOT/ -- the pattern is stale, not the tree clean"

used_keys=$(printf '%s\n' "$raw_matches" | while IFS= read -r m; do
  case "$m" in
    '{config.'*) continue ;;
    '{DOMAIN:topic maps}') printf 'topic_maps\n' ;;
    '{DOMAIN:topic map}')  printf 'topic_map\n' ;;
    '{DOMAIN:'*'}')
      k=${m#\{DOMAIN:}; k=${k%\}}
      case "$k" in *[!a-zA-Z_]*) continue ;; esac
      printf '%s\n' "$k" ;;
    '{vocabulary.'*'}')
      k=${m#\{vocabulary.}; k=${k%\}}
      printf '%s\n' "$k" ;;
  esac
done | LC_ALL=C sort -u)

# extraction_categories is the one documented Level 7 structural exception -- a nested
# list, never a substitution pair by design. Never expected to resolve.
used_keys=$(printf '%s\n' "$used_keys" | grep -v '^extraction_categories$' || true)

# --- the check: used_keys minus declared_keys ----------------------------------------
undeclared=$(LC_ALL=C comm -23 <(printf '%s\n' "$used_keys") <(printf '%s\n' "$declared_keys"))

if [ -n "$undeclared" ]; then
  echo "  undeclared keys found:"
  printf '%s\n' "$undeclared" | while IFS= read -r k; do
    [ -n "$k" ] || continue
    echo "    $k"
    grep -rn "vocabulary\.$k}\|DOMAIN:$k}" "$SCAN_ROOT" 2>/dev/null | sed 's/^/      /'
  done
  echo
  echo "VOCABULARY SCHEMA: FAIL"
  exit 1
fi

echo "  PASS every {vocabulary.X}/{DOMAIN:X} used in $SCAN_ROOT/ resolves to a key declared in $SCHEMA_FILE"
echo
echo "VOCABULARY SCHEMA: PASS"
exit 0
SCRIPTEOF
chmod +x reference/check-vocabulary-schema.sh
```

- [ ] **Step 3: Run the two assertions and confirm they now pass**

Run: `bash reference/test/vocabulary-schema.test.sh`
Expected: `2/2`, exit 0.

Run: `zsh reference/test/vocabulary-schema.test.sh`
Expected: `2/2`, exit 0.

- [ ] **Step 4: Commit**

```bash
git add reference/check-vocabulary-schema.sh reference/test/vocabulary-schema.test.sh
git commit -m "Add check-vocabulary-schema.sh: does every placeholder used resolve?

Whole-tree static check, not diff-relative like check-placeholder-count.sh
-- a schema key removed anywhere could silently orphan a placeholder in
a completely unrelated file, so this runs on every push unconditionally.

{DOMAIN:X} folding reuses mechanically_compare()'s exact three-step
transform rather than a second, independently-typed definition of the
same fold. Sources PLACEHOLDER_PAT from reference/lib/placeholder-pattern.sh
(Task 1) instead of redefining it.

2/2 in reference/test/vocabulary-schema.test.sh under both shells (positive
and negative controls only -- the remaining assertions are the next task)."
```

---

### Task 6: Complete the test suite and wire into CI

**Files:**
- Modify: `reference/test/vocabulary-schema.test.sh` (add the remaining assertions)
- Modify: `.github/workflows/checks.yml`

**Interfaces:**
- Consumes: `reference/check-vocabulary-schema.sh` (Task 5).

- [ ] **Step 1: Add the remaining assertions to the test file**

Insert before the `echo "$pass/$((pass+fail))"` line at the end of
`reference/test/vocabulary-schema.test.sh`:

```bash
# --- Assertion 3: the Level 7 exception is never flagged --------------------------------
tmp3=$(mktemp -d); mkdir -p "$tmp3/scan"
fixture_schema "$tmp3/schema.md"
echo '{DOMAIN:extraction_categories}' > "$tmp3/scan/x.md"
SCAN_ROOT="$tmp3/scan" SCHEMA_FILE="$tmp3/schema.md" bash "$GATE" >/dev/null 2>&1
assert "$?" "0" "Level 7 exception (extraction_categories) is not flagged"
rm -rf "$tmp3"

# --- Assertion 4: mutating the exception out of the gate turns it red -------------------
tmp4=$(mktemp -d); mkdir -p "$tmp4/scan"
fixture_schema "$tmp4/schema.md"
echo '{DOMAIN:extraction_categories}' > "$tmp4/scan/x.md"
sed "s/extraction_categories/DUMMY_EXCEPTION_NAME/" "$GATE" > "$tmp4/mutated_gate.sh"
chmod +x "$tmp4/mutated_gate.sh"
SCAN_ROOT="$tmp4/scan" SCHEMA_FILE="$tmp4/schema.md" bash "$tmp4/mutated_gate.sh" >/dev/null 2>&1
assert "$?" "1" "mutating away the exception makes extraction_categories flag (proves assertion 3 isn't vacuous)"
rm -rf "$tmp4"

# --- Assertion 5: the two special-cased space-containing DOMAIN: spellings resolve ------
tmp5=$(mktemp -d); mkdir -p "$tmp5/scan"
fixture_schema "$tmp5/schema.md"
cat >> "$tmp5/schema.md" <<'EOF'
# Level 4: Navigation terms
  topic_map: "[domain term]"
  topic_maps: "[domain term]"
EOF
printf '{DOMAIN:topic map} {DOMAIN:topic maps}\n' > "$tmp5/scan/x.md"
SCAN_ROOT="$tmp5/scan" SCHEMA_FILE="$tmp5/schema.md" bash "$GATE" >/dev/null 2>&1
assert "$?" "0" "space-containing DOMAIN: spellings resolve via the same fold mechanically_compare uses"
rm -rf "$tmp5"

# --- Assertion 6: {config.X} is extracted but never flagged for resolution --------------
tmp6=$(mktemp -d); mkdir -p "$tmp6/scan"
fixture_schema "$tmp6/schema.md"
echo '{config.something_no_schema_declares}' > "$tmp6/scan/x.md"
SCAN_ROOT="$tmp6/scan" SCHEMA_FILE="$tmp6/schema.md" bash "$GATE" >/dev/null 2>&1
assert "$?" "0" "{config.X} markers are never checked for resolution"
rm -rf "$tmp6"

# --- Assertion 7: zero-extraction guard -------------------------------------------------
tmp7=$(mktemp -d); mkdir -p "$tmp7/scan"
fixture_schema "$tmp7/schema.md"
echo 'no placeholders in this file at all' > "$tmp7/scan/x.md"
SCAN_ROOT="$tmp7/scan" SCHEMA_FILE="$tmp7/schema.md" bash "$GATE" >/dev/null 2>&1
assert "$?" "2" "zero placeholders extracted -> cannot conclude, never a false-clean pass"
rm -rf "$tmp7"

# --- Assertion 8: schema file missing -> cannot conclude --------------------------------
tmp8=$(mktemp -d); mkdir -p "$tmp8/scan"
echo '{vocabulary.notes}' > "$tmp8/scan/x.md"
SCAN_ROOT="$tmp8/scan" SCHEMA_FILE="$tmp8/does-not-exist.md" bash "$GATE" >/dev/null 2>&1
assert "$?" "2" "missing schema file -> cannot conclude"
rm -rf "$tmp8"

# --- Assertion 9: schema missing the # Level 7: marker -> cannot conclude ---------------
tmp9=$(mktemp -d); mkdir -p "$tmp9/scan"
cat > "$tmp9/schema.md" <<'EOF'
vocabulary:
  notes: "[domain term]"
EOF
echo '{vocabulary.notes}' > "$tmp9/scan/x.md"
SCAN_ROOT="$tmp9/scan" SCHEMA_FILE="$tmp9/schema.md" bash "$GATE" >/dev/null 2>&1
assert "$?" "2" "schema with no bounding '# Level 7:' marker -> cannot conclude (unbounded range would silently absorb trailing content)"
rm -rf "$tmp9"

# --- Assertion 10: PLACEHOLDER_PAT exists in exactly one place -------------------------
n_defs=$(grep -rl "^PLACEHOLDER_PAT=" "$ROOT/check-placeholder-count.sh" "$ROOT/check-vocabulary-schema.sh" "$ROOT/lib/placeholder-pattern.sh" 2>/dev/null | wc -l | tr -d ' ')
assert "$n_defs" "1" "PLACEHOLDER_PAT is defined in exactly one file (lib/placeholder-pattern.sh), never redefined locally"
```

- [ ] **Step 2: Run the full suite under both shells**

Run: `for s in bash zsh; do $s reference/test/vocabulary-schema.test.sh; done`
Expected: both report `10/10`, exit 0.

- [ ] **Step 3: Run the gate against the real tree**

Run: `bash reference/check-vocabulary-schema.sh`
Expected: `VOCABULARY SCHEMA: PASS`, exit 0 — Tasks 2 and 3 must have already landed for this to
be true. If it fails, that means either an undeclared key survived Task 3's corrections or
Task 2's schema addition, and this task should not proceed until it's clean.

- [ ] **Step 4: Wire into CI**

In `.github/workflows/checks.yml`, add new steps alongside the other `check-*.sh` gates
(following the existing pattern for `check-placeholder-count.sh`'s step and the `for s in bash
zsh` loop pattern used for the `.test.sh` suites):

```yaml
      - name: vocabulary schema coverage
        run: bash reference/check-vocabulary-schema.sh
      - name: vocabulary schema coverage tests (bash)
        run: bash reference/test/vocabulary-schema.test.sh
      - name: vocabulary schema coverage tests (zsh)
        run: zsh reference/test/vocabulary-schema.test.sh
```

- [ ] **Step 5: Commit**

```bash
git add reference/test/vocabulary-schema.test.sh .github/workflows/checks.yml
git commit -m "Complete vocabulary-schema.test.sh (10/10) and wire into CI

Assertions cover: positive/negative controls, the Level 7 exception
(with a mutation proving it isn't vacuous), the two special-cased
space-containing DOMAIN: spellings, {config.X} exclusion, both
cannot-conclude guards (zero extraction, unparseable schema), and a
single-source assertion for PLACEHOLDER_PAT.

reference/check-vocabulary-schema.sh now PASSes against the real
skill-sources/ tree, confirming Tasks 2-3's fixes actually close every
finding the self-review surfaced -- not just domain."
```

---

### Task 7: Reconcile `check-doc-claims.sh` and update documentation counts

**Files:**
- Modify: `CLAUDE.md` (only what `check-doc-claims.sh` reports as stale — do not hand-edit ahead
  of running it)
- Modify: `CONTRIBUTING.md` (same)

**Interfaces:**
- Consumes: `reference/check-doc-claims.sh` (existing script, unmodified).

- [ ] **Step 1: Run the doc-claims gate**

Run: `bash reference/check-doc-claims.sh`

- [ ] **Step 2: Fix exactly what it reports**

If it reports `DOC CLAIMS: PASS`, this task is done — no edit needed, skip to Step 3. If it
reports a stale count or claim, fix only the specific line(s) it names, re-run, and repeat until
`DOC CLAIMS: PASS`. This repo has repeatedly regressed by hand-editing these numbers speculatively
instead of letting this gate drive the edit — do not guess at a new count.

- [ ] **Step 3: Commit (only if Step 2 made changes)**

```bash
git add CLAUDE.md CONTRIBUTING.md
git commit -m "Reconcile verification counts after adding check-vocabulary-schema.sh

Per reference/check-doc-claims.sh's own output -- not hand-guessed."
```

If Step 2 made no changes, skip this commit entirely.

---

### Task 8: Bump the plugin version to 0.9.6

**Files:**
- Modify: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (via
  `scripts/bump-version.sh`)
- Modify: `README.md` (version badge, matching this session's established manual-update
  precedent — `bump-version.sh` does not manage markdown text substitution)

**Interfaces:**
- Consumes: `scripts/bump-version.sh` (existing script, unmodified).

- [ ] **Step 1: Run the bump**

Run: `scripts/bump-version.sh 0.9.6`

- [ ] **Step 2: Handle any audit-flagged stragglers**

The script runs an audit for the old version string across the repo after bumping declared
files. Read its output. For each straggler it names, follow the established pattern from this
session's prior version bump (commit `e32623a`): a live claim (like `README.md`'s version badge)
gets manually updated; a historical/illustrative mention (like `check-prose-paths.sh`'s own
version-comparison anecdote, already in `.version-bump.json`'s `audit.exclude`) needs no change.
Update `README.md`'s version badge to `0.9.6` if the audit flags it.

- [ ] **Step 3: Verify**

Run: `scripts/bump-version.sh --check`
Expected: confirms all declared sites agree at `0.9.6`.

- [ ] **Step 4: Commit**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json README.md
git commit -m "Bump version 0.9.5 -> 0.9.6

Completes the vocabulary-schema-coverage-gate plan."
```

---

## Self-Review

**Spec coverage:** Section 1 (schema change) → Task 2. Section 1b (four template corrections) →
Task 3. Section 2 (substitution wiring) → Task 4. Section 3 (the gate: two-source extraction,
`{DOMAIN:X}` folding reusing `mechanically_compare`'s transform, `{config.X}` exclusion, scope
exclusions, shared pattern, invocation interface, exit codes) → Tasks 1 and 5. Section 4
(testing: all ten enumerated assertions) → Tasks 5–6. "Deliberately not in scope" items are not
implemented, correctly — no task touches vault repair, Level renumbering, a richer domain
schema, or a `{config.X}` resolution gate. Success criteria: gate exits 0 (Task 6 Step 3), test
suite passes both shells (Task 6 Step 2), shared pattern file exists and is single-sourced (Task
1, Task 6 assertion 10), fresh-vault manual criterion is explicitly out of CI scope (not
assigned a task, correctly, since the spec itself marks it manual-only). The user's mid-brainstorm
instruction (bump to 0.9.6 on completion) → Task 8, last.

**Placeholder scan:** No TBD/TODO found. Every code step contains real, complete code — the
`mechanically_compare()` fixture tests in Task 4 extract the actual function from
`skills/upgrade/SKILL.md` rather than describing what a test "should" do.

**Type consistency:** `SCAN_ROOT`/`SCHEMA_FILE` env var names are identical across the spec,
Task 5's script, and Task 6's test fixtures. `PLACEHOLDER_PAT` is sourced (never redefined) in
both Task 1's edit to `check-placeholder-count.sh` and Task 5's new script. `mechanically_compare`
and `render_current_template` names match the spec and the existing `skills/upgrade/SKILL.md`
text exactly.

---

## Deferrals

Per CLAUDE.md divergence 10: everything found during implementation or the final whole-branch
review that was not fixed, and where each landed. Everything else the reviews found was fixed
in a task's own fix round or the final review's fix wave — see `git log` for those; this section
is only for what remains genuinely open.

- **An independently-typed copy of the same regex value, spelled `PAT=` (not `PLACEHOLDER_PAT=`),
  in `reference/skill-authoring.md:62`** (inert — inside a ` ```text ` fence, never executes, and
  its different variable name means a tree-wide `grep PLACEHOLDER_PAT` would not even find it).
  Task 1's own scope was `check-placeholder-count.sh` and the new gate only; this third copy
  predates this plan and was deliberately left untouched. Recorded here, and in
  `reference/test/vocabulary-schema.test.sh`'s assertion 10 comment (this repo), which states
  the assertion's three-file scope is deliberate, not exhaustive. Not recorded in any commit
  message — none of this plan's commits actually names this file.
- **A behavioral asymmetry between `check-vocabulary-schema.sh`'s `{DOMAIN:X}` fold and
  `mechanically_compare()`'s own transform**, for a non-identifier `X` (e.g. containing a
  hyphen): the gate silently skips it (guarded against emptying `used_keys` entirely by the
  `n_used` check, added during Task 5's own fix round; test assertion 11 covering it is what
  the final review's fix wave added), while
  `mechanically_compare()` instead leaves it as literal text, which fails to match installed
  text and reads as a loud `MODIFIED`. Not triggered by anything currently in `skill-sources/`
  — every real `{DOMAIN:X}` there is a clean identifier or one of the two special-cased
  spellings. Landed as a code comment at `reference/check-vocabulary-schema.sh`'s `{DOMAIN:X}`
  fold (the `case "$k" in *[!a-zA-Z_]*)` branch).

---

**Plan complete and saved to `docs/superpowers/plans/2026-08-08-vocabulary-schema-coverage.md`.**
Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between
tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution
with checkpoints.

**Which approach?**
