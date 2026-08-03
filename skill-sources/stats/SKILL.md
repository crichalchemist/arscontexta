---
name: stats
description: Show vault statistics and knowledge graph metrics. Provides a shareable snapshot of vault health, growth, and progress. Triggers on "/stats", "vault stats", "show metrics", "how big is my vault".
version: "1.0"
generated_from: "arscontexta-v1.6"
user-invocable: true
context: fork
model: sonnet
allowed-tools: Read, Grep, Glob, Bash
argument-hint: "[--share] — optional flag for compact shareable output"
---

## Runtime Configuration (Step 0 — before any processing)

Read these files to configure domain-specific behavior:

1. **`ops/derivation-manifest.md`** — vocabulary mapping
   - Use `vocabulary.notes` for the notes folder name
   - Use `vocabulary.note` / `vocabulary.note_plural` for note type references
   - Use `vocabulary.topic_map` / `vocabulary.topic_map_plural` for MOC references
   - Use `vocabulary.inbox` for the inbox folder name
   - Use `vocabulary.notes_collection` for semantic search collection name

2. **`ops/config.yaml`** — processing depth, automation settings

If no derivation file exists, use universal terms (notes, MOCs, etc.).

---

## EXECUTE NOW

**Target: $ARGUMENTS**

Parse immediately:
- If target contains `--share`: output compact shareable format after full stats
- If target is empty: output full stats display
- If target names a specific category (e.g., "health", "growth", "pipeline"): show only that category

**START NOW.** Collect metrics and present them.

---

## Philosophy

**Make the invisible visible.**

The knowledge graph grows silently. Without metrics, the user cannot tell whether their system is healthy, growing, stagnating, or fragmenting. /stats provides a snapshot that makes growth tangible — numbers that show progress, health indicators that catch problems, and trends that reveal trajectory.

The output should make the user feel informed, not overwhelmed. Metrics are evidence, not judgment. "12 orphans" is a fact. What to DO about it belongs to /graph or /{vocabulary.cmd_reflect}.

---

## Step 1: Collect Metrics

Gather all metrics. Run these checks in parallel where possible to minimize latency.

### 1a. Knowledge Graph Metrics

```bash
NOTES_DIR="{vocabulary.notes}"

# Source link-extraction library (fails loud if missing).
# Vault root: same mechanism as hooks/scripts/read_config.sh:20.
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

# Note count (excluding MOCs).
# `find`, not a glob, and recursive to match the link library below. Counting
# links over the tree while counting notes over one directory is worse than
# either scope alone: it made DENSITY (:127) read above 1, and density is
# links/possible-links, so it cannot. AVG_LINKS, COMPLIANCE, COVERAGE and
# PROCESSED_PCT all derive from these two counts and go wrong together.
# A bare glob also aborts under zsh (NOMATCH) when the vault is empty.
TOTAL_FILES=$(find "$NOTES_DIR" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
MOC_COUNT=$(find "$NOTES_DIR" -type f -name '*.md' -exec grep -l '^type: moc' {} + 2>/dev/null | wc -l | tr -d ' ')
NOTE_COUNT=$((TOTAL_FILES - MOC_COUNT))

# Connection count (all wiki links across notes/)
LINK_COUNT=$(count_links_recursive "$NOTES_DIR") || {
  echo "error: link counting failed; refusing to report a connection count" >&2
  exit 1
}

# Average connections per note
if [[ "$NOTE_COUNT" -gt 0 ]]; then
  AVG_LINKS=$(echo "scale=1; $LINK_COUNT / $NOTE_COUNT" | bc)
else
  AVG_LINKS="0"
fi

# Topic count (unique values in topics: fields).
# Trimmed and folded the same way the library folds link targets, so casing and
# stray whitespace do not inflate the count. rg's OWN status is checked — a
# pipeline's status is the last stage's, so an rg failure would otherwise render
# as a plausible 0. `find` (not a glob) distinguishes the two states the report
# must not conflate: missing directory aborts, empty directory is a legitimate 0.
TOPIC_SRC=$(mktemp) || { echo "error: mktemp failed; refusing to report a topic count" >&2; exit 1; }
find "$NOTES_DIR" -type f -name '*.md' -exec cat {} + > "$TOPIC_SRC" || {
  rm -f "$TOPIC_SRC"
  echo "error: reading '$NOTES_DIR' failed; refusing to report a topic count" >&2
  exit 1
}
TOPIC_RAW=$(rg -o -r '$1' '^\s*-\s*"\[\[([^\]|#]+)' "$TOPIC_SRC")
RG_RC=$?
rm -f "$TOPIC_SRC"
if [ "$RG_RC" -gt 1 ]; then
  echo "error: topic extraction failed (rg exit $RG_RC); refusing to report a topic count" >&2
  exit 1
fi
if [ -z "$TOPIC_RAW" ]; then
  TOPIC_COUNT=0
else
  TOPIC_COUNT=$(printf '%s\n' "$TOPIC_RAW" \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | _fold_lower \
    | sort -u | wc -l | tr -d ' ')
fi

# Link density
if [[ "$NOTE_COUNT" -gt 1 ]]; then
  POSSIBLE=$((NOTE_COUNT * (NOTE_COUNT - 1)))
  DENSITY=$(echo "scale=4; $LINK_COUNT / $POSSIBLE" | bc)
else
  DENSITY="N/A"
fi
```

### 1b. Health Metrics

```bash
# Each fenced block is a SEPARATE shell invocation: no variable and no sourced
# function survives from block 1a above. NOTES_DIR, the note counts and the
# link-extraction library must all be re-established here. Relying on 1a leaves
# $NOTES_DIR empty (so `find ""` scans nothing) and makes every library call a
# 127 "command not found", which the `||` guards below turn into a hard exit —
# so this whole section produced no counts at all on every run.
NOTES_DIR="{vocabulary.notes}"

# An EMPTY vault is a legitimate 0; a MISSING directory is a failure and must
# not render as one.
[ -d "$NOTES_DIR" ] || {
  echo "error: notes directory '$NOTES_DIR' does not exist; refusing to report health metrics" >&2
  exit 1
}

# Source link-extraction library (fails loud if missing).
# Vault root: same mechanism as hooks/scripts/read_config.sh:20.
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

# Note counts. Block 1a is the canonical copy — keep this stanza identical to
# it. COMPLIANCE divides by TOTAL_FILES and COVERAGE divides by NOTE_COUNT, and
# an empty $(( )) folds to 0, which reads as "0% compliant" rather than as an
# error.
TOTAL_FILES=$(find "$NOTES_DIR" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
MOC_COUNT=$(find "$NOTES_DIR" -type f -name '*.md' -exec grep -l '^type: moc' {} + 2>/dev/null | wc -l | tr -d ' ')
NOTE_COUNT=$((TOTAL_FILES - MOC_COUNT))

# Orphan and dangling counts both read the SAME two folded, sorted sets, built
# once here (folded on both sides — reference/lib/link-extraction.sh).
NOTE_INDEX=$(existing_note_index_recursive "$NOTES_DIR") || {
  echo "error: note index build failed; refusing to report orphan or dangling counts" >&2
  exit 1
}
# Extraction is captured and CHECKED BEFORE the loop. Piping it straight into
# `while` would yield the loop's status, not extraction's, so a failed extraction
# would render as a plausible 0 (PIPESTATUS is bash-only and cannot be used here).
LINK_TARGETS=$(extract_link_targets_recursive "$NOTES_DIR") || {
  echo "error: link extraction failed; refusing to report orphan or dangling counts" >&2
  exit 1
}

# Orphan count (non-MOC notes with zero incoming links).
# The replaced spelling was the same inlined matcher removed from /graph hubs —
# a recursive grep of the whole tree for the note's own name in brackets,
# filtered by `grep -v` on the file path. Described, not quoted, for the reason
# given at that site. It was wrong three ways: it counted links sitting inside
# ``` fences, it matched neither case-folded nor up to the `|` and `#`
# terminators, and it interpolated the name into a REGEX, so a note named `a.b`
# was also "linked" by any [[axb]]. Every one of those errors lands on the
# zero/non-zero boundary this count is made of, so an orphan could be hidden by
# a link that does not exist — and on a fixture the two spellings returned the
# SAME total (6) over DIFFERENT sets, the errors cancelling in the sum.
#
# MOCs are excluded, as before: a map that nothing links TO is not an orphan.
# The MOC index is folded through _fold_lower and sorted the same way the
# library sorts NOTE_INDEX — comm does not warn usefully on inputs collated
# differently, it just returns a wrong set.
MOC_INDEX=$(find "$NOTES_DIR" -type f -name '*.md' -exec grep -l '^type: moc' {} + 2>/dev/null \
  | while IFS= read -r f; do basename "$f" .md; done | _fold_lower | sort -u)
# Both sides are already folded and sorted, which is what makes comm valid here.
ORPHAN_ALL=$(comm -23 <(printf '%s\n' "$NOTE_INDEX") <(printf '%s\n' "$LINK_TARGETS"))
ORPHAN_COUNT=$(comm -23 <(printf '%s\n' "$ORPHAN_ALL") <(printf '%s\n' "$MOC_INDEX") \
  | grep -c . || true)

# Dangling: targets that resolve to no note. Left as a membership loop rather
# than converted to `comm -13`: it was never broken, and comm would newly make
# this count depend on both sets being collated identically.
DANGLING_COUNT=$(printf '%s\n' "$LINK_TARGETS" | while read -r NAME; do
  [ -n "$NAME" ] && ! printf '%s\n' "$NOTE_INDEX" | grep -qxF "$NAME" && echo "$NAME"
done | wc -l | tr -d ' ')

# Schema compliance (% of notes with required fields: description, topics)
MISSING_DESC=$(find "$NOTES_DIR" -type f -name '*.md' -exec grep -L '^description:' {} + 2>/dev/null | wc -l | tr -d ' ')
MISSING_TOPICS=$(find "$NOTES_DIR" -type f -name '*.md' -exec grep -L '^topics:' {} + 2>/dev/null | wc -l | tr -d ' ')
SCHEMA_ISSUES=$((MISSING_DESC + MISSING_TOPICS))
if [[ "$TOTAL_FILES" -gt 0 ]]; then
  # Notes with BOTH required fields
  COMPLIANT=$((TOTAL_FILES - MISSING_DESC))
  COMPLIANCE=$(echo "scale=0; $COMPLIANT * 100 / $TOTAL_FILES" | bc)
else
  COMPLIANCE="N/A"
fi

# MOC coverage: share of non-MOC notes linked from at least one MOC.
# The replaced form ran `xargs grep -l` with the note name inside the pattern —
# the same matcher removed from the orphan count above, merely spelled so that
# the search string divergence 6 tracked could not see it. It carried the same
# three defects, and here they bias the coverage % rather than a count: a link
# inside a ``` block counted as coverage, a MOC linking [[Zettelkasten]] did not
# cover `zettelkasten.md`, and a note named `a.b` was covered by any [[axb]].
#
# The MOC file list is still built once, outside any loop, for the reason the
# previous comment recorded: an EMPTY list left `xargs` with no file arguments,
# and GNU xargs then ran grep against the loop's own stdin and swallowed the
# `find` stream, while BSD xargs skipped the run entirely. No xargs remains, but
# the list is still built once because rebuilding it per note rescanned the
# whole vault n times.
MOC_FILES=$(find "$NOTES_DIR" -type f -name '*.md' -exec grep -l '^type: moc' {} + 2>/dev/null)

# Targets linked FROM MOCs. Extraction is inlined rather than delegated because
# the library exposes directory-scoped functions only, and nothing that answers
# "what does this particular SET of files link to" — see divergence 12.
COV_SRC=$(mktemp) || exit 1
COV_HITS=$(mktemp) || { rm -f "$COV_SRC"; exit 1; }
COVF="/tmp/stats-cov-err-$$"
rm -f "$COVF"
printf '%s\n' "$MOC_FILES" | while IFS= read -r m; do
  [ -n "$m" ] || continue
  _strip_fences "$m" >> "$COV_SRC" || touch "$COVF"
done
if [ -e "$COVF" ]; then
  rm -f "$COV_SRC" "$COV_HITS" "$COVF"
  echo "error: MOC fence-stripping failed; refusing to report a coverage figure" >&2
  exit 1
fi
# rc 1 is "no MOC links at all", a real answer; only rc >1 is a failure.
rg -o '\[\[([^\]|#]+)' -r '$1' "$COV_SRC" > "$COV_HITS"
if [ $? -gt 1 ]; then
  rm -f "$COV_SRC" "$COV_HITS" "$COVF"
  echo "error: MOC link extraction failed; refusing to report a coverage figure" >&2
  exit 1
fi
MOC_TARGETS=$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' "$COV_HITS" | _fold_lower | sort -u)
rm -f "$COV_SRC" "$COV_HITS" "$COVF"

# Denominator set is non-MOC notes, matching NOTE_COUNT, which also subtracts
# MOCs. Both operands reach comm already folded and sorted.
COVERED=$(comm -12 \
  <(comm -23 <(printf '%s\n' "$NOTE_INDEX") <(printf '%s\n' "$MOC_INDEX")) \
  <(printf '%s\n' "$MOC_TARGETS") | grep -c . || true)
if [[ "$NOTE_COUNT" -gt 0 ]]; then
  COVERAGE=$(echo "scale=0; $COVERED * 100 / $NOTE_COUNT" | bc)
else
  COVERAGE="N/A"
fi
```

### 1c. Pipeline Metrics

```bash
# Each fenced block is a SEPARATE shell invocation: NOTE_COUNT does not survive
# from block 1a. Left undefined it expands to empty, and $(( )) folds empty to
# 0 without a word of complaint — TOTAL_CONTENT then equals INBOX_COUNT alone
# and PROCESSED_PCT renders 0%, which is a plausible number and a wrong one.
NOTES_DIR="{vocabulary.notes}"

# An EMPTY vault is a legitimate 0; a MISSING directory is a failure and must
# not render as one.
[ -d "$NOTES_DIR" ] || {
  echo "error: notes directory '$NOTES_DIR' does not exist; refusing to report a processed ratio" >&2
  exit 1
}

# Note count. Block 1a is the canonical copy — keep this stanza identical to it.
TOTAL_FILES=$(find "$NOTES_DIR" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
MOC_COUNT=$(find "$NOTES_DIR" -type f -name '*.md' -exec grep -l '^type: moc' {} + 2>/dev/null | wc -l | tr -d ' ')
NOTE_COUNT=$((TOTAL_FILES - MOC_COUNT))

# Inbox items
INBOX_COUNT=$(find {vocabulary.inbox}/ -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

# Queue pending (check both YAML and JSON formats)
QUEUE_FILE=""
if [[ -f "ops/queue/queue.yaml" ]]; then
  QUEUE_FILE="ops/queue/queue.yaml"
  QUEUE_PENDING=$(grep -c 'status: pending' "$QUEUE_FILE" 2>/dev/null)
  QUEUE_DONE=$(grep -c 'status: done' "$QUEUE_FILE" 2>/dev/null)
elif [[ -f "ops/queue/queue.json" ]]; then
  QUEUE_FILE="ops/queue/queue.json"
  QUEUE_PENDING=$(grep -c '"status": "pending"' "$QUEUE_FILE" 2>/dev/null)
  QUEUE_DONE=$(grep -c '"status": "done"' "$QUEUE_FILE" 2>/dev/null)
else
  QUEUE_PENDING=0
  QUEUE_DONE=0
fi

# Processed ratio (notes vs inbox)
TOTAL_CONTENT=$((NOTE_COUNT + INBOX_COUNT))
if [[ "$TOTAL_CONTENT" -gt 0 ]]; then
  PROCESSED_PCT=$(echo "scale=0; $NOTE_COUNT * 100 / $TOTAL_CONTENT" | bc)
else
  PROCESSED_PCT="N/A"
fi
```

### 1d. Growth Metrics

```bash
# Each fenced block is a SEPARATE shell invocation: NOTES_DIR does not survive
# from block 1a. Left undefined, `find ""` scans nothing and every growth figure
# renders 0 — measured against a vault of 5 notes created this week, this block
# reported THIS_WEEK_NOTES=0 with exit 0 and a clean stderr.
NOTES_DIR="{vocabulary.notes}"

# An EMPTY vault is a legitimate 0; a MISSING directory is a failure and must
# not render as one.
[ -d "$NOTES_DIR" ] || {
  echo "error: notes directory '$NOTES_DIR' does not exist; refusing to report growth metrics" >&2
  exit 1
}

# This week's growth (notes with created: date within last 7 days)
WEEK_AGO=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d 2>/dev/null)
if [[ -n "$WEEK_AGO" ]]; then
  THIS_WEEK_NOTES=$(find "$NOTES_DIR" -type f -name '*.md' -exec grep -l "^created: " {} + 2>/dev/null | while read -r f; do
    CREATED=$(grep '^created:' "$f" | head -1 | awk '{print $2}')
    [[ "$CREATED" > "$WEEK_AGO" || "$CREATED" == "$WEEK_AGO" ]] && echo "$f"
  done | wc -l | tr -d ' ')
else
  THIS_WEEK_NOTES="?"
fi

# This week's connections (approximate — count links in recently created notes).
# The failure flag is a FILE, not a variable: the loop body runs in a subshell
# (find | while), so an assignment would be discarded at the pipe. PIPESTATUS is
# bash-only and reads empty under zsh, so it is not the fix.
# rg also runs as its own statement rather than as a pipeline stage: the loop
# feeds `wc -l`, so the whole construct reported wc's status and a broken
# RIPGREP_CONFIG_PATH — or an rg missing from PATH — rendered as 0 connections.
# rc 1 means "this file has no links" and is NORMAL; only rc >1 is a failure.
if [[ "$THIS_WEEK_NOTES" -gt 0 && -n "$WEEK_AGO" ]]; then
  TMP_STRIPPED=$(mktemp) || {
    echo "error: mktemp failed; refusing to report a weekly connection count" >&2
    exit 1
  }
  ERRF="/tmp/stats-week-links-err-$$"
  rm -f "$ERRF"
  THIS_WEEK_LINKS=$(find "$NOTES_DIR" -type f -name '*.md' -exec grep -l "^created: " {} + 2>/dev/null | while read -r f; do
    CREATED=$(grep '^created:' "$f" | head -1 | awk '{print $2}')
    [[ "$CREATED" > "$WEEK_AGO" || "$CREATED" == "$WEEK_AGO" ]] || continue
    awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$f" > "$TMP_STRIPPED" || {
      touch "$ERRF"; continue
    }
    rg -o '\[\[' "$TMP_STRIPPED"
    if [ $? -gt 1 ]; then
      touch "$ERRF"; continue
    fi
  done | wc -l | tr -d ' ')
  if [ -e "$ERRF" ]; then
    rm -f "$TMP_STRIPPED" "$ERRF"
    echo "error: link scan failed; refusing to report a weekly connection count" >&2
    exit 1
  fi
  rm -f "$TMP_STRIPPED" "$ERRF"
else
  THIS_WEEK_LINKS="?"
fi
```

### 1e. System Metrics

```bash
# Self space
if [[ -d "self/" ]]; then
  SELF_FILES=$(find self/ -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  SELF_STATUS="enabled ($SELF_FILES files)"
else
  SELF_STATUS="disabled"
fi

# Methodology notes
METHODOLOGY_COUNT=$(ls -1 ops/methodology/*.md 2>/dev/null | wc -l | tr -d ' ')

# Sourced, never re-implemented — convention, not a gate. See reference/lib/frontmatter.sh.
# The naive `grep -rl '^status: pending'` this replaced matched a line-anchored `status:`
# ANYWHERE in the file, including inside a fenced block in the body, so a note that
# documented the schema by showing `status: pending` in an example read as pending.
FM_LIB="ops/lib/frontmatter.sh"
if [ -r "$FM_LIB" ]; then
  . "$FM_LIB"
else
  echo "error: frontmatter library not found at '$FM_LIB'" >&2
  echo "       run /arscontexta:upgrade to restore it" >&2
  exit 1
fi

# A directory that does not exist means that feature is not active — valid state, count 0,
# reported as N/A above. A scan that FAILS over a directory that exists must not fold to 0.
count_open_items() {                       # count_open_items <dir>
  [ -d "$1" ] || { printf '0'; return 0; }
  count_notes_by_field "$1" status pending open
}

# Observations pending
OBS_PENDING=$(count_open_items ops/observations) || {
  echo "error: observation scan failed; refusing to report a count" >&2
  exit 1
}

# Tensions pending
TENSION_PENDING=$(count_open_items ops/tensions) || {
  echo "error: tension scan failed; refusing to report a count" >&2
  exit 1
}

# Sessions captured
SESSION_COUNT=$(ls -1 ops/sessions/*.md 2>/dev/null | wc -l | tr -d ' ')
```

Adapt all directory names to domain vocabulary. Skip checks for directories that do not exist — report "N/A" instead of errors.

---

## Step 2: Format Output

### Full Output (default)

Generate a progress bar for the Processed metric:

```
Progress bar calculation:
  filled = PROCESSED_PCT / 5 (number of = characters out of 20)
  empty = 20 - filled
  bar = [===...   ] PCT%
```

```
--=={ stats }==--

  Knowledge Graph
  ===============
  {vocabulary.note_plural}:  [NOTE_COUNT]
  Connections:               [LINK_COUNT] (avg [AVG_LINKS] per {vocabulary.note})
  {vocabulary.topic_map_plural}:   [MOC_COUNT] (covering [COVERAGE]% of {vocabulary.note_plural})
  Topics:                    [TOPIC_COUNT]

  Health
  ======
  Orphans:      [ORPHAN_COUNT]
  Dangling:     [DANGLING_COUNT]
  Schema:       [COMPLIANCE]% compliant

  Pipeline
  ========
  Processed:    [==============      ] [PROCESSED_PCT]%
  Inbox:        [INBOX_COUNT] items
  Queue:        [QUEUE_PENDING] pending tasks

  Growth
  ======
  This week:    +[THIS_WEEK_NOTES] {vocabulary.note_plural}, +[THIS_WEEK_LINKS] connections
  Graph density: [DENSITY]

  System
  ======
  Self space:      [SELF_STATUS]
  Methodology:     [METHODOLOGY_COUNT] learned patterns
  Observations:    [OBS_PENDING] pending
  Tensions:        [TENSION_PENDING] open
  Sessions:        [SESSION_COUNT] captured

  Generated by Ars Contexta v1.6
```

### Interpretation Notes

After the stats block, add brief interpretation for any notable findings:

| Condition | Note |
|-----------|------|
| ORPHAN_COUNT > 0 | "[N] orphan {vocabulary.note_plural} — run `/graph health` for details" |
| DANGLING_COUNT > 0 | "[N] dangling links — run `/graph health` to identify broken links" |
| COMPLIANCE < 90 | "Schema compliance below 90% — some {vocabulary.note_plural} missing required fields" |
| OBS_PENDING >= 10 | "[N] pending observations — consider running /{vocabulary.rethink}" |
| TENSION_PENDING >= 5 | "[N] open tensions — consider running /{vocabulary.rethink}" |
| DENSITY < 0.02 | "Graph density is low — connections are thin. Run /{vocabulary.cmd_reflect} to strengthen the network" |
| PROCESSED_PCT < 50 | "More content in inbox than in {vocabulary.notes}/ — consider processing backlog" |
| THIS_WEEK_NOTES == 0 | "No new {vocabulary.note_plural} this week" |

Only show interpretation notes when conditions are notable. A healthy vault gets just the stats, no warnings.

---

## Step 3: Shareable Format (--share flag)

If invoked with `--share`, output a compact markdown block suitable for sharing on social media or in documentation:

```markdown
## My Knowledge Graph

- **[NOTE_COUNT]** {vocabulary.note_plural} with **[LINK_COUNT]** connections (avg [AVG_LINKS] per {vocabulary.note})
- **[MOC_COUNT]** {vocabulary.topic_map_plural} covering [COVERAGE]% of {vocabulary.note_plural}
- Schema compliance: [COMPLIANCE]%
- This week: +[THIS_WEEK_NOTES] {vocabulary.note_plural}, +[THIS_WEEK_LINKS] connections
- Graph density: [DENSITY]

*Built with [Ars Contexta](https://github.com/arscontexta) v1.6*
```

The shareable format:
- Omits health warnings (positive framing for sharing)
- Omits pipeline state (internal detail)
- Omits system metrics (internal detail)
- Includes only growth-positive metrics
- Always includes the Ars Contexta attribution line

---

## Step 4: Trend Analysis (when history exists)

If previous /stats runs are logged in `ops/stats-history.yaml` (or similar), compare current metrics against the last snapshot:

```
  Trend (vs last check):
    {vocabulary.note_plural}: [N] (+[delta] since [date])
    Connections:              [N] (+[delta])
    Density:                  [N] ([up/down/stable])
    Orphans:                  [N] ([improved/worsened/stable])
```

If no history exists, skip trend analysis. Do NOT create the history file — that is /health's responsibility.

---

## Edge Cases

### Empty Vault (0 notes)

Show zeros gracefully:
```
--=={ stats }==--

  Your knowledge graph is new. Start capturing to see it grow.

  Knowledge Graph
  ===============
  {vocabulary.note_plural}:  0
  Connections:               0
  {vocabulary.topic_map_plural}:   0
  Topics:                    0

  Generated by Ars Contexta v1.6
```

Do not show health, pipeline, growth, or system sections for an empty vault — they would all be zeros or N/A.

### No Queue System

Skip the Pipeline section entirely. Do not show an error.

### No Self Space

Show "disabled" for self space line. Do not show an error.

### No ops/derivation-manifest.md

Use universal vocabulary (notes, MOCs, etc.). All metrics work identically.

### Very Large Vault (500+ notes)

The orphan and MOC coverage checks may be slow for large vaults. If {vocabulary.notes}/ has >200 files:
1. Run orphan detection with a simpler heuristic (check only for presence in any MOC, not full backlink scan)
2. Note: "Metrics approximate for large vault. Run /graph health for precise analysis."

### Platform-Specific Date Commands

macOS uses `date -v-7d`, Linux uses `date -d '7 days ago'`. The script tries both. If neither works, report "?" for growth metrics instead of failing.
