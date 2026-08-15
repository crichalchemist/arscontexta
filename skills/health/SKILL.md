---
name: health
description: Run condition-based vault health diagnostics. 9 categories — schema compliance, orphan detection, link health, description quality, three-space boundaries, processing throughput, stale notes, MOC coherence, shared library integrity. 3 modes — quick (schema+orphans+links+library), full (all 9), three-space (boundary violations only). Returns actionable FAIL/WARN/PASS report with specific fixes ranked by impact. Triggers on "/health", "check vault health", "maintenance report", "what needs fixing".
version: "1.0"
generated_from: "arscontexta-v1.6"
allowed-tools: Read, Grep, Glob, Bash, mcp__qmd__query
argument-hint: "[optional: 'quick', 'full', or 'three-space']"
---

## Runtime Configuration (Step 0 — before any processing)

Read these files to configure domain-specific behavior:

1. **`ops/derivation-manifest.md`** — vocabulary mapping, folder names, platform hints
   - Use `vocabulary.notes` for the notes folder name
   - Use `vocabulary.inbox` for the inbox folder name
   - Use `vocabulary.note` for the note type name in output
   - Use `vocabulary.topic_map` for MOC/topic map references
   - Use `vocabulary.topic_maps` for plural form

2. **`ops/config.yaml`** — processing depth, thresholds

3. **Three-space reference** — `${CLAUDE_PLUGIN_ROOT}/reference/three-spaces.md` for boundary rules (load only for full and three-space modes)

4. **Templates** — read template files to understand required schema fields for validation

If these files don't exist (pre-init invocation or standalone use), use universal defaults:
- notes folder: `notes/`
- inbox folder: `inbox/`
- topic map: topic maps in notes/

---

## EXECUTE NOW

**Target: $ARGUMENTS**

Parse the invocation mode immediately:

| Input | Mode | Categories Run |
|-------|------|---------------|
| empty or `quick` | Quick | 1 (Schema), 2 (Orphans), 3 (Links), 9 (Shared Libraries) |
| `full` | Full | All 9 categories |
| `three-space` | Three-Space | 5 (Three-Space Boundaries) only |

**Execute these steps:**

1. **Detect mode** from arguments
2. **Scan the vault** — inventory all note files, {vocabulary.topic_map} files, inbox items, ops files
3. **Run each applicable diagnostic category** in order (1-9)
4. **Classify each result** as PASS, WARN, or FAIL using the thresholds below
5. **Surface condition-based maintenance signals** (check against threshold table)
6. **Generate the health report** with specific file paths, counts, and recommended actions
7. **Write report to** `ops/health/YYYY-MM-DD-report.md`

**START NOW.** Reference below explains each diagnostic category in detail.

### Platform Adaptation

Checks adapt to what the platform supports:
- If semantic search (qmd) is not configured, skip semantic-dependent checks and note their absence
- If hooks are not available, note that validation is convention-only (no automated enforcement)
- If self/ directory does not exist (disabled by config), skip self-space checks but verify ops/ absorbs self-space content correctly

**Report what CAN be checked, not what the platform lacks.**

---

## The 9 Diagnostic Categories

### Category 1: Schema Compliance (quick, full)

**What it checks:** Every {vocabulary.note} in {vocabulary.notes}/ and self/memory/ (if self/ is enabled) has valid YAML frontmatter with required fields.

**How to check:**

```bash
# Find all note files (exclude topic maps)
for f in {vocabulary.notes}/*.md; do
  [[ -f "$f" ]] || continue
  # Check: YAML frontmatter exists
  head -1 "$f" | grep -q '^---$' || echo "FAIL: $f — no YAML frontmatter"
  # Check: description field present
  rg -q '^description:' "$f" || echo "WARN: $f — missing description field"
  # Check: topics field present and links to at least one topic map
  rg -q '^topics:' "$f" || echo "WARN: $f — missing topics field"
done
```

**Enum value check** — the threshold table below has always promised "Any invalid enum value →
WARN"; this is that check, implemented against the note `type:` field specifically. (Other
enum-like fields, e.g. `status`, vary too much by domain to check generically here — see
`generators/features/schema.md`'s own note that a template's `_schema` block is the single source
of truth, one per vault, not one per field.)

```bash
# Sourced, never re-implemented — convention, not a gate. See reference/lib/frontmatter.sh.
FM_LIB="ops/lib/frontmatter.sh"
if [ -r "$FM_LIB" ]; then
  . "$FM_LIB"
else
  echo "error: frontmatter library not found at '$FM_LIB'" >&2
  echo "       run /arscontexta:upgrade to restore it" >&2
  exit 1
fi

# The declared enum lives in a template's _schema block (`enums: { type: [a, b, c] }`), not in
# frontmatter — frontmatter_field() does not apply to it. A plain -E grep for the bracketed
# `type:` line is deliberately used instead of a full YAML parse: the line shape is distinctive
# enough (a note's own `type: insight` is a scalar, never a bracket) that this does not need one.
SCHEMA_TEMPLATE=$(grep -lE '^[[:space:]]*type:[[:space:]]*\[.*\]' templates/*.md 2>/dev/null | head -1)
if [ -z "$SCHEMA_TEMPLATE" ]; then
  echo "WARN: no template declares a type: enum in its _schema block — cannot check enum values"
else
  # tr -d '[:space:]' here would strip the newlines tr ',' '\n' just introduced (newline IS
  # whitespace), collapsing the whole list into one unbroken line — the exact-match check
  # below would then never match ANY value, valid or not. Strip only leading/trailing
  # whitespace PER LINE instead.
  TYPE_ENUM=$(grep -E '^[[:space:]]*type:[[:space:]]*\[.*\]' "$SCHEMA_TEMPLATE" | head -1 \
    | sed -E 's/^[^][]*\[([^]]*)\].*/\1/' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  for f in {vocabulary.notes}/*.md; do
    [[ -f "$f" ]] || continue
    # A note with no type: field is valid (the schema's own default, e.g. "insight") — nothing
    # to check against the enum, so this is not itself a defect.
    note_type=$(frontmatter_field "$f" type) || continue
    [ -n "$note_type" ] || continue
    printf '%s\n' "$TYPE_ENUM" | grep -qxF "$note_type" \
      || echo "WARN: $f — type: $note_type is not in the declared enum ($(printf '%s' "$TYPE_ENUM" | tr '\n' ',' | sed 's/,$//'))"
  done
fi
```

**Additional checks:**
- `description` field is non-empty (not just present)
- `topics` field contains at least one wiki link

**If `validate-kernel.sh` exists** in `${CLAUDE_PLUGIN_ROOT}/reference/`, run it and include results.

**Thresholds:**

| Condition | Level |
|-----------|-------|
| Any note missing YAML frontmatter | FAIL |
| Any note missing `description` field | WARN |
| Any note missing `topics` field | WARN |
| Any invalid enum value | WARN |
| All notes pass all checks | PASS |

**Output format:**
```
[1] Schema Compliance ............ WARN
    2 notes missing description:
      - notes/example-note.md
      - notes/another-note.md
    1 note missing topics:
      - notes/orphaned-claim.md
    12/15 notes fully compliant
```

### Category 2: Orphan Detection (quick, full)

**What it checks:** Every {vocabulary.note} has at least one incoming wiki link from another file.

**How to check:**

```bash
VAULT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LINK_LIB="$VAULT_ROOT/ops/lib/link-extraction.sh"
if [ -r "$LINK_LIB" ]; then
  . "$LINK_LIB"
else
  echo "error: link-extraction library not found at '$LINK_LIB'" >&2
  echo "       run /arscontexta:upgrade to restore it" >&2
  exit 1
fi
: "${LINK_EXTRACTION_VERSION:=0}"
if [ "$LINK_EXTRACTION_VERSION" -lt 3 ]; then
  echo "error: link-extraction library is version $LINK_EXTRACTION_VERSION; this skill needs >= 3" >&2
  echo "       run /arscontexta:upgrade to refresh it" >&2
  exit 1
fi

# Scope: notes from {vocabulary.notes}, links from WHOLE VAULT
# Compose from primitives: a link from anywhere rescues a note
[ -d "{vocabulary.notes}" ] || {
  echo "error: notes directory not found at {vocabulary.notes}" >&2
  exit 1
}

idx=$(mktemp) || exit 1
tgts=$(mktemp) || { rm -f "$idx"; exit 1; }
edges=$(mktemp) || { rm -f "$idx" "$tgts"; exit 1; }
tmp_awk=$(mktemp) || { rm -f "$idx" "$tgts" "$edges"; exit 1; }

existing_note_index "{vocabulary.notes}" > "$edges" \
  || { rm -f "$idx" "$tgts" "$edges" "$tmp_awk"; exit 1; }
LC_ALL=C sort -u < "$edges" > "$idx" \
  || { rm -f "$idx" "$tgts" "$edges" "$tmp_awk"; exit 1; }

link_edge_map_recursive "$VAULT_ROOT" > "$edges" \
  || { rm -f "$idx" "$tgts" "$edges" "$tmp_awk"; exit 1; }
LC_ALL=C awk -F'\t' '$1 != $2 { print $2 }' "$edges" > "$tmp_awk" \
  && LC_ALL=C sort -u "$tmp_awk" > "$tgts" \
  || { rm -f "$idx" "$tgts" "$edges" "$tmp_awk"; exit 1; }

LC_ALL=C comm -23 "$idx" "$tgts" | while IFS= read -r n; do
  echo "WARN: $n — no incoming links (orphan)"
done
rm -f "$idx" "$tgts" "$edges" "$tmp_awk"
```

**Nuance:** Orphans are not automatically failures. A note created today that hasn't been through /{vocabulary.cmd_reflect} yet is expected to be orphaned temporarily. Check file age:

| Condition | Level |
|-----------|-------|
| Orphan note created < 24 hours ago | INFO (expected — awaiting reflect phase) |
| Orphan note created 1-7 days ago | WARN |
| Orphan note older than 7 days | FAIL (persistent orphan needs attention) |
| No orphans detected | PASS |

**Output format:**
```
[2] Orphan Detection ............. WARN
    3 orphan notes detected:
      - notes/new-claim.md (created 2h ago — awaiting reflect) [INFO]
      - notes/old-observation.md (created 5d ago) [WARN]
      - notes/forgotten-insight.md (created 14d ago) [FAIL]
    Recommendation: run /reflect on forgotten-insight.md and old-observation.md
```

### Category 3: Link Health (quick, full)

**What it checks:** Every wiki link `[[target]]` in `{vocabulary.notes}` resolves to an existing file.

Scope: wiki links within {vocabulary.notes}. Links in other spaces
({vocabulary.inbox}, self/) are not checked, and links pointing outside
{vocabulary.notes} will report dangling.

**How to check:**

```bash
# Source link-extraction library (folds both sides, strips fences, terminates at | #).
# Vault root: same mechanism as hooks/scripts/read_config.sh:20, and the same
# expression Category 9 uses — the two must agree, or Category 9 can report PASS
# on a library this category never managed to load.
# The VAULT copy is loaded, not the plugin's: CLAUDE_PLUGIN_ROOT is unset in a
# shell, so "${CLAUDE_PLUGIN_ROOT:-}/reference/..." resolves to an absolute
# /reference/... that is never readable, and this category exited 1 on every
# vault in every state.
# Precondition: the working directory is the vault root — already assumed by
# vaultguard.sh ([ -f ".arscontexta" ]) and read_config.sh.
VAULT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LINK_LIB="$VAULT_ROOT/ops/lib/link-extraction.sh"
if [ -r "$LINK_LIB" ]; then
  . "$LINK_LIB"
else
  echo "error: link-extraction library not found at '$LINK_LIB'" >&2
  echo "       run /arscontexta:upgrade to restore it" >&2
  exit 1
fi

: "${LINK_EXTRACTION_VERSION:=0}"
if [ "$LINK_EXTRACTION_VERSION" -lt 1 ]; then
  echo "error: link-extraction library is version $LINK_EXTRACTION_VERSION; this skill needs >= 1" >&2
  echo " run /arscontexta:upgrade to refresh it" >&2
  exit 1
fi

# Build folded index of all existing notes (recursive for vault with subdirs)
NOTE_INDEX=$(existing_note_index_recursive "{vocabulary.notes}") || {
  echo "error: note index build failed; refusing to report link health" >&2
  exit 1
}

# Extract all wiki links from all markdown files (folded both sides, fences stripped).
# Captured and CHECKED BEFORE the loop: piping extraction into `while` yields the
# loop's status, so a failed extraction would render as a PASS on link health.
LINK_TARGETS=$(extract_link_targets_recursive "{vocabulary.notes}") || {
  echo "error: link extraction failed; refusing to report link health" >&2
  exit 1
}
printf '%s\n' "$LINK_TARGETS" | while read -r target; do
  # Compare against index — both sides already folded by library
  if [ -n "$target" ] && ! printf '%s\n' "$NOTE_INDEX" | grep -qxF "$target"; then
    echo "FAIL: dangling link [[${target}]] — no file found"
  fi
done
```

**Thresholds:**

| Condition | Level |
|-----------|-------|
| Any dangling link (target does not exist) | FAIL |
| All links resolve | PASS |

**Why FAIL not WARN:** Dangling links are broken promises. Every `[[link]]` a reader follows that leads nowhere erodes trust in the graph. Fix these immediately.

**Output format:**
```
[3] Link Health .................. FAIL
    2 dangling links found:
      - [[nonexistent-note]] referenced in:
        - notes/some-claim.md (line 14)
        - notes/another-claim.md (line 8)
      - [[removed-topic]] referenced in:
        - notes/old-note.md (line 22)
    Recommendation: create missing notes or remove broken links
```

### Category 4: Description Quality (full only)

**What it checks:** Every {vocabulary.note}'s description adds genuine information beyond the title — not just a restatement.

**How to check:**

For each {vocabulary.note}:
1. Read the title (filename without extension)
2. Read the `description` field from YAML frontmatter
3. Evaluate: does the description add scope, mechanism, or implication that the title does not cover?

**Quality heuristics:**

| Check | Threshold |
|-------|-----------|
| Description length | 50-200 chars ideal. < 30 chars = too terse. > 250 chars = too verbose |
| Restatement detection | If description uses >70% of the same words as the title = restatement |
| Information added | Description should mention mechanism, scope, or implication not in title |

**Thresholds:**

| Condition | Level |
|-----------|-------|
| Description is a clear restatement of the title | WARN |
| Description is < 30 characters | WARN |
| Description is missing entirely | WARN (also caught by Category 1) |
| Description adds genuine new information | PASS |

**This check requires judgment.** Use semantic understanding, not just string matching. A description that uses different words but says the same thing as the title is still a restatement.

**Output format:**
```
[4] Description Quality .......... WARN
    2 descriptions are restatements:
      - notes/quality-matters.md
        Title: "quality matters more than quantity"
        Description: "quality is more important than quantity in knowledge work"
        Issue: restates title without adding mechanism or implication
      - notes/structure-helps.md
        Title: "structure without processing provides no value"
        Description: "having structure without processing it is not valuable"
        Issue: exact restatement
    Recommendation: rewrite descriptions to add scope, mechanism, or implication
```

### Category 5: Three-Space Boundary Check (full, three-space)

**What it checks:** Content respects the boundaries between self/, {vocabulary.notes}/, and ops/. Each space has a purpose — conflating them degrades search quality, navigation, and trust.

**Before running this check:** Read `${CLAUDE_PLUGIN_ROOT}/reference/three-spaces.md` for the full boundary specification.

**Six conflation patterns to detect:**

#### 5a. Ops into Notes (Infrastructure Creep)

Queue state, health metrics, task files, or processing artifacts appearing in {vocabulary.notes}/ directory.

**Detection:**
```bash
# Check for ops-pattern YAML fields in notes
rg '^(current_phase|completed_phases|batch|source_task|queue_id):' {vocabulary.notes}/ --glob '*.md'
# Check for task file patterns in notes
rg '## (Create|Reflect|Reweave|Verify|Enrich)$' {vocabulary.notes}/ --glob '*.md'
```

| Found | Level |
|-------|-------|
| Any ops-pattern content in {vocabulary.notes}/ | WARN |

#### 5b. Self into Notes (Identity Pollution)

Agent identity or methodology content mixed into user's knowledge graph. Agent's operational observations appearing in user's {vocabulary.notes}/ space.

**Detection:**
```bash
# Check for agent-reflection patterns in notes (methodology observations, workflow assessments)
rg -i '(my methodology|I observed that|agent reflection|session learning|I learned)' {vocabulary.notes}/ --glob '*.md'
```

| Found | Level |
|-------|-------|
| Any agent-reflection content in {vocabulary.notes}/ | WARN |

#### 5c. Notes into Ops (Trapped Knowledge)

Genuine insights trapped in session logs, observations, or ops files that should be promoted to {vocabulary.notes}/.

**Detection:**
```bash
# Check for claim-like content in ops that could be notes
# Look for files with description fields in ops/observations/ or ops/methodology/
rg '^description:' ops/observations/*.md ops/methodology/*.md 2>/dev/null
```

| Found | Level |
|-------|-------|
| Content in ops/ with note-like schema (description + topics) | INFO (may be intentional, flag for review) |

#### 5d. Self into Ops / Ops into Self

Temporal state stored in self/ (should be in ops/), or identity content stored in ops/ (should be in self/).

**Detection:**
```bash
# Check for temporal/queue content in self/
rg '^(current_phase|status|queue):' self/ --glob '*.md' 2>/dev/null
# Check for identity content in ops/
rg -i '(my identity|I am|who I am|my personality)' ops/ --glob '*.md' 2>/dev/null
```

#### 5e. Notes into Self

Domain knowledge stored in self/ instead of {vocabulary.notes}/.

**Detection:**
```bash
# Check self/memory/ for notes that have topics linking to notes-space topic maps
rg '^topics:.*\[\[' self/memory/*.md 2>/dev/null | grep -v 'identity\|methodology\|goals\|relationships'
```

#### 5f. Self Space Absence Effects (when self/ is disabled)

When self/ is disabled, verify ops/ absorbs self-space content correctly. Check that goals and handoffs are in ops/, not floating in {vocabulary.notes}/.

**Detection:**
```bash
# If self/ doesn't exist, check that goals/handoffs are in ops/
if [[ ! -d "self/" ]]; then
  # Check for goals or handoff content in notes/
  rg -i '(my goals|current goals|handoff|session handoff)' {vocabulary.notes}/ --glob '*.md'
fi
```

**Thresholds:**

| Condition | Level |
|-----------|-------|
| Any boundary violation (5a, 5b, 5d, 5e) | WARN |
| Trapped knowledge in ops (5c) | INFO |
| Self-absence effects (5f) | WARN |
| All boundaries intact | PASS |

**Output format:**
```
[5] Three-Space Boundaries ....... WARN
    1 boundary violation detected:
      Ops into Notes (infrastructure creep):
        - notes/task-tracking.md contains queue state fields (current_phase, batch)
        - Should be in ops/queue/ not notes/
    1 potential trapped knowledge:
      - ops/observations/interesting-pattern.md has note-like schema
        Consider promoting to notes/ via /reduce or direct creation
    Recommendation: move task-tracking.md to ops/queue/
```

### Category 6: Processing Throughput (full only)

**What it checks:** The inbox-to-knowledge ratio. High ratios indicate collector's fallacy — capturing more than processing.

**How to check:**

```bash
# A missing directory must not render as a 0% ratio — that is indistinguishable from a
# healthy empty inbox. Name the directory that is absent, and the remedy: this message
# is the only thing the user sees.
NOTES_DIR="{vocabulary.notes}"
INBOX_DIR="{vocabulary.inbox}"
for d in "$INBOX_DIR" "$NOTES_DIR"; do
  if [ ! -d "$d" ]; then
    echo "error: directory '$d' does not exist; run /arscontexta:setup" >&2
    exit 1
  fi
done

# Count items in each space
INBOX_COUNT=$(find {vocabulary.inbox}/ -name '*.md' -not -path '*/archive/*' 2>/dev/null | wc -l | tr -d ' ')
NOTES_COUNT=$(find {vocabulary.notes}/ -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
QUEUE_COUNT=$(find ops/queue/ -name '*.md' -not -path '*/archive/*' 2>/dev/null | wc -l | tr -d ' ')

# Calculate ratio
if [[ $((INBOX_COUNT + NOTES_COUNT)) -gt 0 ]]; then
  RATIO=$((INBOX_COUNT * 100 / (INBOX_COUNT + NOTES_COUNT)))
else
  RATIO=0
fi

echo "Inbox: $INBOX_COUNT | Notes: $NOTES_COUNT | In-progress: $QUEUE_COUNT | Ratio: ${RATIO}%"
```

**Thresholds:**

| Condition | Level |
|-----------|-------|
| Inbox-to-total ratio > 75% (3:1 inbox to notes) | FAIL |
| Inbox-to-total ratio > 50% | WARN |
| Inbox items > 20 | WARN (regardless of ratio) |
| Inbox-to-total ratio <= 50% AND inbox <= 20 | PASS |

**Output format:**
```
[6] Processing Throughput ........ WARN
    inbox: 12 | notes: 8 | in-progress: 3 | ratio: 60%
    Inbox items outnumber processed notes — collector's fallacy risk
    Recommendation: run /reduce on oldest inbox items or /pipeline for end-to-end processing
```

### Category 7: Stale Note Detection (full only)

**What it checks:** Notes not modified recently AND with low link density. Staleness is condition-based (low link density + no activity since N new notes were added), not purely calendar-based.

**How to check:**

For each {vocabulary.note}:
1. Check last modified date (`stat` or `git log`)
2. Count incoming links (same as orphan detection, but counting instead of boolean)
3. Flag notes with: modified > 30 days ago AND < 2 incoming links

```bash
VAULT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LINK_LIB="$VAULT_ROOT/ops/lib/link-extraction.sh"
if [ -r "$LINK_LIB" ]; then
  . "$LINK_LIB"
else
  echo "error: link-extraction library not found at '$LINK_LIB'" >&2
  echo "       run /arscontexta:upgrade to restore it" >&2
  exit 1
fi
: "${LINK_EXTRACTION_VERSION:=0}"
if [ "$LINK_EXTRACTION_VERSION" -lt 3 ]; then
  echo "error: link-extraction library is version $LINK_EXTRACTION_VERSION; this skill needs >= 3" >&2
  echo "       run /arscontexta:upgrade to refresh it" >&2
  exit 1
fi

[ -d "{vocabulary.notes}" ] || {
  echo "error: notes directory not found at {vocabulary.notes}" >&2
  exit 1
}

COUNTS=$(mktemp) || exit 1
backlink_counts_recursive "$VAULT_ROOT" > "$COUNTS" || { rm -f "$COUNTS"; exit 1; }

for f in {vocabulary.notes}/*.md; do
  [ -e "$f" ] || continue
  basename=$(basename "$f" .md | _fold_lower)

  # Last modified (days ago). GNU `-c` first, BSD `-f` second — the order is
  # load-bearing. GNU reads `-f` as "filesystem status" and treats `%m` as a
  # filename, so `stat -f %m FILE` prints Namelen/Type and EXITS 0; a `-f`-first
  # chain never falls through, it feeds filesystem text into this arithmetic.
  mod_days=$(( ($(date +%s) - $(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null)) / 86400 ))

  # Incoming link count (from pre-computed table, excluding self-links)
  incoming=$(LC_ALL=C awk -F'\t' -v n="$basename" '$1==n{print $2}' "$COUNTS")
  incoming=${incoming:-0}

  if [[ $mod_days -gt 30 ]] && [[ $incoming -lt 2 ]]; then
    echo "STALE: $f — $mod_days days old, $incoming incoming links"
  fi
done
rm -f "$COUNTS"
```

**Thresholds:**

| Condition | Level |
|-----------|-------|
| Any note > 30 days old with < 2 incoming links | WARN |
| Any note > 90 days old with 0 incoming links | FAIL |
| All notes either recent or well-connected | PASS |

**Prioritization:** Sort stale notes by:
1. Age (oldest first)
2. Link density (least connected first)
3. Topic relevance (notes in active topic areas are higher priority)

**Output format:**
```
[7] Stale Notes .................. WARN
    4 stale notes detected (>30d old, <2 incoming links):
      - notes/old-observation.md (92d, 0 links) [FAIL — consider archiving or reweaving]
      - notes/early-claim.md (45d, 1 link) [WARN]
      - notes/setupial-thought.md (38d, 1 link) [WARN]
      - notes/first-draft.md (31d, 0 links) [WARN]
    Recommendation: run /reweave on these notes to find connections, or archive if no longer relevant
```

### Category 8: {vocabulary.topic_map} Coherence (full only)

**What it checks:** Each {vocabulary.topic_map} has a healthy number of linked notes, and notes in the same topic area are actually linked.

**How to check:**

For each {vocabulary.topic_map} file:
1. Count notes that link TO this {vocabulary.topic_map} (notes with this in their `topics` footer/field)
2. Check if there are notes in the same topic area NOT linked to the {vocabulary.topic_map} (coverage gaps)
3. Verify context phrases exist on Core Ideas links (not bare links)

```bash
VAULT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LINK_LIB="$VAULT_ROOT/ops/lib/link-extraction.sh"
if [ -r "$LINK_LIB" ]; then
  . "$LINK_LIB"
else
  echo "error: link-extraction library not found at '$LINK_LIB'" >&2
  echo "       run /arscontexta:upgrade to restore it" >&2
  exit 1
fi
: "${LINK_EXTRACTION_VERSION:=0}"
if [ "$LINK_EXTRACTION_VERSION" -lt 3 ]; then
  echo "error: link-extraction library is version $LINK_EXTRACTION_VERSION; this skill needs >= 3" >&2
  echo "       run /arscontexta:upgrade to refresh it" >&2
  exit 1
fi

[ -d "{vocabulary.notes}" ] || {
  echo "error: notes directory not found at {vocabulary.notes}" >&2
  exit 1
}

COUNTS=$(mktemp) || exit 1
backlink_counts "{vocabulary.notes}" > "$COUNTS" || { rm -f "$COUNTS"; exit 1; }

# For each topic map
for moc in {vocabulary.notes}/*.md; do
  [ -e "$moc" ] || continue
  # Check if this is a topic map (has type: moc in frontmatter)
  rg -q '^type: moc' "$moc" || continue

  moc_name=$(basename "$moc" .md | _fold_lower)

  # Count notes linking to this topic map
  note_count=$(LC_ALL=C awk -F'\t' -v n="$moc_name" '$1==n{print $2}' "$COUNTS")
  note_count=${note_count:-0}

  echo "$moc_name: $note_count notes"
done
rm -f "$COUNTS"
```

**Thresholds:**

| Condition | Level |
|-----------|-------|
| {vocabulary.topic_map} with < 5 notes | WARN (underdeveloped — consider merging into parent) |
| {vocabulary.topic_map} with > 50 notes | WARN (oversized — consider splitting into sub-{vocabulary.topic_maps}) |
| {vocabulary.topic_map} with > 40 notes | INFO (approaching threshold) |
| Notes exist in topic area but not linked to {vocabulary.topic_map} | WARN (coverage gap) |
| All {vocabulary.topic_maps} in 5-50 range with good coverage | PASS |

**Context phrase check:**

```bash
# Check for bare links in topic map Core Ideas (links without context phrases)
for moc in {vocabulary.notes}/*.md; do
  rg -q '^type: moc' "$moc" || continue
  # Look for "- [[note]]" without " — " context
  rg '^\s*- \[\[' "$moc" | grep -v ' — ' | grep -v '^\s*- \[\[[^]]*\]\].*—'  # portability-exempt: shape matcher
done
```

Bare links without context phrases are address book entries, not navigation. Every link in a {vocabulary.topic_map} should explain WHY to follow it.

**Output format:**
```
[8] MOC Coherence ................ WARN
    3 topic maps checked:
      - knowledge-work: 28 notes [PASS]
      - graph-structure: 52 notes [WARN — oversized, consider splitting]
        3 bare links without context phrases
      - agent-cognition: 3 notes [WARN — underdeveloped, consider merging]
    Recommendation: split graph-structure into sub-topic-maps; add context phrases to bare links
```

---

### Category 9: Shared Library Integrity (quick, full)

**What it checks:** The vault's own copies of **all three** shared libraries exist and are new enough for the skills that source them.

**Why it runs in quick mode:** `/stats` and `/graph` source `ops/lib/link-extraction.sh`; `/next`, `/rethink` and `/stats` source `ops/lib/frontmatter.sh`; and `/next`, `/verify`, `/reduce`, `/reflect` and `/reweave` source `ops/lib/queue-edit.sh` for every queue write. Each exits 1 when its library is missing or too old. This check reports that condition directly instead of leaving the user to discover it the next time they run a command. These are the *vault* copies — the same files those skills load — not the plugin's.

**All three are checked, and `frontmatter.sh` in particular because this category's own numbers
depend on it.** `/health` sources `frontmatter.sh` to produce its observation and tension counts. A
check that skipped it would report the shared library healthy in exactly the vault where /health's
own condition counts could not be taken — a report vouching for the thing it was unable to use.

**How to check:**

```bash
# Vault root: same expression the consuming skills use, so a FAIL here means
# exactly what a FAIL in /stats means.
VAULT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Report, never exit: health is a report generator, and exiting here would
# suppress every category that follows. Each library is reported on its own line;
# one missing file must not mask the state of the other.
check_lib() {                # check_lib <path> <version-var-name> <label>
  if [ ! -r "$1" ]; then
    echo "FAIL: $3 library missing or unreadable at '$1'"
    echo "      run /arscontexta:upgrade to restore it"
    return 0
  fi
  # Sourced in the SAME fence as the guard above — state does not cross fences.
  . "$1"
  # eval, because the version constant differs per library and its NAME is the
  # argument. Unset or non-numeric folds to 0, which FAILs — the direction that
  # reports a problem rather than hiding one.
  eval "v=\${$2:-0}"
  case "$v" in ''|*[!0-9]*) v=0 ;; esac
  # THE FLOOR IS 1 AND STAYS 1 — a decision, recorded because a review asked for
  # one rather than for a particular answer. The floor exists to catch ABSENT or
  # unparseable, which is a broken vault. It is deliberately NOT raised to track
  # the current version: doing so would FAIL every vault that has not run
  # /upgrade, for libraries whose later versions fix real but narrow defects
  # (frontmatter v2 added a directory-readability guard, v3 symlink traversal and
  # a find-rc check — a v1 copy is wrong only on trees it cannot fully scan).
  # Turning a whole fleet red for that is a worse trade than a stale-but-working
  # copy. What was NOT acceptable is the previous silence: `PASS: library v1`
  # said nothing about being behind, so a vault carrying a version this repo had
  # just documented as defective read as healthy. The PASS line now names the
  # remedy without asserting a failure.
  if [ "$v" -lt 1 ]; then
    echo "FAIL: $3 library is version $v; skills need >= 1"
    echo "      run /arscontexta:upgrade to refresh it"
  else
    echo "PASS: $3 library v$v (run /arscontexta:upgrade to check for a newer one)"
  fi
}

check_lib "$VAULT_ROOT/ops/lib/link-extraction.sh" LINK_EXTRACTION_VERSION link-extraction
check_lib "$VAULT_ROOT/ops/lib/frontmatter.sh"     FRONTMATTER_VERSION     frontmatter
check_lib "$VAULT_ROOT/ops/lib/queue-edit.sh"      QUEUE_EDIT_VERSION      queue-edit
```

**Thresholds:**

Applied to **each** library independently; the category FAILs if any row FAILs.

| Condition | Result |
|-----------|--------|
| File present, readable, version >= 1 | PASS |
| File present, version < 1 or unset | FAIL |
| File missing or unreadable | FAIL |

There is no WARN band. A library is a precondition, not a quality measure: the skills that source it either run or do not.

**Ranking:** when this category FAILs, place `run /arscontexta:upgrade` **first** in Recommended Actions. Every vault generated before a library shipped will report that library's FAIL at its next session-start quick check, through no fault of the user — `queue-edit.sh` is the newest of the three, so on most existing vaults it is the queue-edit row that fires, missing rather than merely outdated. Ranked below three other items it reads as noise; ranked first it reads as what it is — broken commands with a one-command fix.

**Example output:**

```
[9] Shared Libraries ............. FAIL
    ops/lib/link-extraction.sh v2
    ops/lib/frontmatter.sh missing
    ops/lib/queue-edit.sh v1
    /next, /rethink and /stats will exit 1 until restored
    Recommendation: run /arscontexta:upgrade
```

---

## Condition-Based Maintenance Signals

After running all applicable diagnostic categories, check these condition-based triggers. These are NOT the 9 categories above — they are cross-cutting signals that suggest specific skill invocations.

| Condition | Threshold | Recommendation |
|-----------|-----------|---------------|
| Pending observations | >= 10 files in ops/observations/ | Consider running /rethink |
| Open tensions | >= 5 files in ops/tensions/ | Consider running /rethink |
| Inbox items | >= 3 items | Consider /reduce or /pipeline |
| Unprocessed sessions | >= 5 files in ops/sessions/ | Consider /remember --mine-sessions |
| Orphan notes | Any persistent (> 7d) | Run /reflect on orphaned notes |
| Dangling links | Any | Fix broken references immediately |
| Stale notes | Low links + old | Consider /reweave |
| {vocabulary.topic_map} oversized | > 40 notes | Consider splitting |
| Queue stalled | Tasks pending > 2 sessions without progress | Surface as blocked |
| Trigger coverage gap | Known maintenance condition has no configured trigger | Flag gap itself |

**How to check condition counts:**

```bash
# Pending observations. Filter by status — counting every file reports resolved and
# archived items as pending, so the condition stays fired no matter how much triage
# happens. Accept both spellings: vaults write `status: open`, older templates write
# `status: pending`, and matching one alone reads 0 on half the vaults in existence.
#
# The FIELD is read from frontmatter, not matched line-anchored anywhere in the file.
# The `grep -rl '^status: pending'` spelling this replaced also matched a `status:`
# line in the BODY, including inside a fenced block — so an observation that quoted a
# schema example counted itself as pending, and the condition stayed fired.
# Sourced, never re-implemented — convention, not a gate. See reference/lib/frontmatter.sh.
VAULT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
FM_LIB="$VAULT_ROOT/ops/lib/frontmatter.sh"
if [ -r "$FM_LIB" ]; then
  . "$FM_LIB"
else
  echo "error: frontmatter library not found at '$FM_LIB'" >&2
  echo "       run /arscontexta:upgrade to restore it" >&2
  exit 1
fi

# A directory that does not exist means that feature is not active — valid state, count 0.
# A scan that FAILS over a directory that DOES exist must not fold to 0: this number
# crosses a threshold, and a silent 0 reports a healthy vault that was never measured.
count_open_items() {                       # count_open_items <dir>
  [ -d "$1" ] || { printf '0'; return 0; }
  count_notes_by_field "$1" status pending open
}

OBS_COUNT=$(count_open_items ops/observations) || {
  echo "error: observation scan failed; refusing to report a count" >&2
  exit 1
}

# Open tensions
TENSION_COUNT=$(count_open_items ops/tensions) || {
  echo "error: tension scan failed; refusing to report a count" >&2
  exit 1
}

# Inbox items
INBOX_COUNT=$(find {vocabulary.inbox}/ -name '*.md' -not -path '*/archive/*' 2>/dev/null | wc -l | tr -d ' ')

# Unprocessed sessions
SESSION_COUNT=$(find ops/sessions/ -name '*.md' 2>/dev/null | wc -l | tr -d ' ')

# Queue stalled
PENDING_TASKS=$(jq '[.tasks[] | select(.status=="pending")] | length' ops/queue/queue.json 2>/dev/null || echo 0)
```

**The meta-trigger:** Include a "trigger coverage" check. Compare known maintenance conditions against what is actually being checked. If a maintenance condition has no corresponding check or trigger configured, that gap itself is a finding. This prevents the failure mode where maintenance debt accumulates undetected.

---

## Output Format

The complete health report follows this structure. Every report, regardless of mode, uses this format.

```
=== HEALTH REPORT ===
Mode: [quick | full | three-space]
Date: YYYY-MM-DD
Notes scanned: N | Topic maps: N | Inbox items: N

Summary: N FAIL, N WARN, N PASS

FAIL:
- [Category N]: [brief description of failure]
  [specific files and details]

WARN:
- [Category N]: [brief description of warning]
  [specific files and details]

PASS:
- [Category N]: [confirmation]

---

[1] Schema Compliance ............ PASS | WARN | FAIL
    [details — specific files, specific issues]

[2] Orphan Detection ............. PASS | WARN | FAIL
    [details — specific files, age, link count]

[3] Link Health .................. PASS | WARN | FAIL
    [details — specific dangling links, where referenced]

[4] Description Quality .......... PASS | WARN | FAIL  (full mode only)
    [details — specific files, title vs description comparison]

[5] Three-Space Boundaries ....... PASS | WARN | FAIL  (full/three-space mode)
    [details — specific boundary violations by type]

[6] Processing Throughput ........ PASS | WARN | FAIL  (full mode only)
    inbox: N | notes: N | in-progress: N | ratio: N%

[7] Stale Notes .................. PASS | WARN | FAIL  (full mode only)
    [N notes older than 30d with <2 incoming links, sorted by priority]

[8] MOC Coherence ................ PASS | WARN | FAIL  (full mode only)
    [details — note count per topic map, coverage gaps, bare links]

[9] Shared Libraries ............. PASS | FAIL
    [ops/lib/link-extraction.sh, ops/lib/frontmatter.sh and ops/lib/queue-edit.sh — presence and version, one line each]

---

Maintenance Signals:
    [condition-based triggers from table above, if any thresholds met]
    - observations: N pending (threshold: 10) [TRIGGERED | OK]
    - tensions: N pending (threshold: 5) [TRIGGERED | OK]
    - inbox: N items (threshold: 3) [TRIGGERED | OK]
    - sessions: N unprocessed (threshold: 5) [TRIGGERED | OK]

---

Recommended Actions (top 3, ranked by impact):
1. [Most impactful action — specific command + specific file]
2. [Second priority — specific command + specific file]
3. [Third priority — specific command + specific file]
=== END REPORT ===
```

### Report Storage

Write every health report to `ops/health/YYYY-MM-DD-report.md`. If multiple reports are run on the same day, append a counter: `YYYY-MM-DD-report-2.md`.

This creates a health history that /architect can reference when proposing evolution. Trends across reports reveal systemic patterns that individual reports miss.

---

## Quality Standards

### Be Specific

Every finding MUST name the specific file(s) involved.

Bad: "some notes lack descriptions"
Good: "notes/example-note.md and notes/another-note.md are missing the description field"

Bad: "there are dangling links"
Good: "[[nonexistent-claim]] is referenced in notes/old-note.md (line 14) and notes/related.md (line 22) but no file with that name exists"

### Prioritize by Impact

Not all issues are equal. The recommended actions section ranks by impact:

| Impact Tier | Examples | Why |
|------------|---------|-----|
| Highest | Dangling links, persistent orphans | Broken promises in the graph — readers hit dead ends |
| High | Schema violations, boundary violations | Structural integrity — compounds into larger problems |
| Medium | Description quality, stale notes | Retrieval quality — degraded but not broken |
| Low | {vocabulary.topic_map} size warnings, throughput ratio | Maintenance debt — matters at scale |

### Don't Overwhelm

- Focus on the top 5-10 issues in the recommended actions
- Group related issues (3 notes missing descriptions = 1 finding, not 3)
- For large vaults, cap per-category detail at 10 specific files, then summarize: "...and 15 more"

### Distinguish FAIL from WARN

| Level | Meaning | Action Required |
|-------|---------|----------------|
| FAIL | Structural issue — something is broken | Fix before it compounds |
| WARN | Improvement opportunity — something is suboptimal | Address when convenient |
| PASS | Category is healthy | No action needed |
| INFO | Noteworthy but not actionable | Context for understanding |

**FAIL is reserved for:** Dangling links (broken graph), persistent orphans (> 7 days), severe schema violations (missing frontmatter entirely), critical boundary violations.

**WARN is for everything else** that is suboptimal but not broken.

---

## Mode-Specific Behavior

### Quick Mode (default)

Runs categories 1-3 and 9: Schema, Orphans, Links, Shared Libraries.

**Use when:**
- Session start health check
- Quick pulse on vault integrity
- After a batch of note creation

**Runtime:** Should complete in < 30 seconds for vaults up to 200 notes.

### Full Mode

Runs all 9 categories plus maintenance signals.

**Use when:**
- Periodic comprehensive health review
- After significant vault changes (large batch processing, restructuring)
- When something "feels wrong" about the vault
- Before a /architect or /reseed session

**Runtime:** May take 1-3 minutes for larger vaults due to description quality analysis and {vocabulary.topic_map} coherence checks.

### Three-Space Mode

Runs category 5 only: boundary violation checks.

**Use when:**
- After /reseed to verify boundaries are intact
- When search results seem contaminated (ops content in knowledge queries)
- When self/ is being enabled or disabled
- Debugging "why does my search return weird results?"

**Runtime:** Should complete in < 30 seconds.

---

## Edge Cases

### Empty Vault

A vault with 0 notes is not unhealthy — it is new. Report:
```
Notes scanned: 0 | Topic maps: 0 | Inbox items: N
All categories PASS (no notes to check)
Maintenance Signal: inbox has N items — consider /reduce to start building knowledge
```

### Self Space Disabled

When self/ does not exist:
- Skip self-space boundary checks (5b, 5d, 5e inbound)
- But DO check that ops/ correctly absorbs self-space content (5f)
- Note in the report: "self/ is disabled — boundary checks adapted accordingly"

### No Semantic Search

When qmd/MCP tools are unavailable:
- Skip any checks that depend on semantic search
- Note in the report: "Semantic search unavailable — some checks skipped"
- All file-based checks (schema, orphans, links, boundaries) still run

### Large Vaults (500+ notes)

- Cap per-category file listings at 10, then summarize
- Consider running checks in batches if performance degrades
- Focus recommended actions on highest-impact items

---

## Integration with Other Skills

Health report findings feed into other skills:

| Finding | Feeds Into | How |
|---------|-----------|-----|
| Orphan notes | /reflect | Run reflect to find connections for orphaned notes |
| Stale notes | /reweave | Run reweave to update old notes with new connections |
| Description quality issues | /verify or manual rewrite | Fix descriptions to improve retrieval |
| Schema violations | /validate | Run validation to fix specific schema issues |
| Boundary violations | Manual restructuring | Move files to correct space |
| Processing throughput | /reduce or /pipeline | Process inbox items to improve ratio |
| {vocabulary.topic_map} oversized | Manual split or /architect | Split oversized {vocabulary.topic_maps} into sub-{vocabulary.topic_maps} |
| Accumulated observations | /rethink | Review and triage observations |
| Accumulated tensions | /rethink | Resolve or dissolve tensions |

**The health-to-action loop:**
```
/health (diagnose) -> specific findings -> specific skill invocation -> /health (verify fix)
```

Health is diagnostic only — it measures state without prescribing changes. /architect reads health reports and proposes changes with research backing. The separation matters: health tells you WHAT is wrong, architect tells you WHY and HOW to fix it.
