---
name: seed
description: Add a source file to the processing queue. Checks for duplicates, creates archive folder, moves source from inbox, creates extract task, and updates queue. Triggers on "/seed", "/seed [file]", "queue this for processing".
version: "1.0"
generated_from: "arscontexta-0.10.0"
user-invocable: true
context: fork
model: sonnet
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
argument-hint: "[file] — path to source file to seed for processing"
---

## EXECUTE NOW

**Target: $ARGUMENTS**

The target MUST be a file path. If no target provided, list {DOMAIN:inbox}/ contents and ask which to seed.

### Step 0: Read Vocabulary

Read `ops/derivation-manifest.md` (or fall back to `ops/derivation.md`) for domain vocabulary mapping. All output must use domain-native terms. If neither file exists, use universal terms.

**START NOW.** Seed the source file into the processing queue.

---

## Step 1: Validate Source

Confirm the target file exists. If it does not, check common locations:
- `{DOMAIN:inbox}/{filename}`
- Subdirectories of {DOMAIN:inbox}/

If the file cannot be found, report error and stop:
```
ERROR: Source file not found: {path}
Checked: {locations checked}
```

Read the file to understand:
- **Content type**: what kind of material is this? (research article, documentation, transcript, etc.)
- **Size**: line count (affects chunking decisions in /reduce)
- **Format**: markdown, plain text, structured data

## Step 2: Duplicate Detection

Check if this source has already been processed. Two levels of detection:

### 2a. Filename Match

Search the queue file and archive folders for matching source names:

```bash
# Fences are separate shell invocations, so every fence that uses the target path must
# establish it. Reading $FILE from an earlier fence expands to empty and the block then
# runs against "" — which is how this failed silently. `${ARGUMENTS:-}` rather than
# `$ARGUMENTS`: an unguarded read of an unset name aborts under `set -u`, which would
# relocate the defect rather than remove it.
FILE="${ARGUMENTS:-}"
if [ -z "$FILE" ]; then
  echo "error: no source file given; pass the source path as the argument" >&2
  exit 1
fi
SOURCE_NAME=$(basename "$FILE" .md | tr ' ' '-' | tr '[:upper:]' '[:lower:]')

# Check queue for existing entry
# Search in ops/queue.yaml, ops/queue/queue.yaml, or ops/queue/queue.json
grep -l "$SOURCE_NAME" ops/queue*.yaml ops/queue/*.yaml ops/queue/*.json 2>/dev/null

# Check archive folders
ls -d ops/queue/archive/*-${SOURCE_NAME}* 2>/dev/null
```

### 2b. Content Similarity (if semantic search available)

If semantic search is available (qmd MCP tools or CLI), check for content overlap:

```
mcp__qmd__query searches=[{type:"lex", query:"claims from {source filename}"}] rerank=false limit=5
```

Or via keyword search in the {DOMAIN:notes}/ directory:
```bash
grep -rl "{key terms from source title}" {DOMAIN:notes}/ 2>/dev/null | head -5
```

### 2c. Report Duplicates

If either check finds a match:
- Show what was found (filename match or content overlap)
- Ask: "This source may have been processed before. Proceed anyway? (y/n)"
- If the user declines, stop cleanly
- If the user confirms (or no duplicate found), continue

## Step 3: Create Archive Structure

Create the archive folder. The date-prefixed folder name ensures uniqueness.

```bash
# Separate shell invocation: establish the target path here too (see Step 2).
FILE="${ARGUMENTS:-}"
if [ -z "$FILE" ]; then
  echo "error: no source file given; pass the source path as the argument" >&2
  exit 1
fi
DATE=$(date -u +"%Y-%m-%d")
SOURCE_BASENAME=$(basename "$FILE" .md | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
ARCHIVE_DIR="ops/queue/archive/${DATE}-${SOURCE_BASENAME}"
mkdir -p "$ARCHIVE_DIR"
```

The archive folder serves two purposes:
1. Permanent home for the source file (moved from {DOMAIN:inbox})
2. Destination for task files after batch completion (/archive-batch moves them here)

## Step 4: Move Source to Archive

Move the source file from its current location to the archive folder. This is the **claiming step** — once moved, the source is owned by this processing batch.

**{DOMAIN:inbox} sources get moved:**
```bash
# Separate shell invocation: establish the target path here too (see Step 2). $ARCHIVE_DIR
# is re-derived by the identical rule Step 3 used, and re-created with the same idempotent
# mkdir -p, so this fence stands alone rather than inheriting either name. (A UTC-midnight
# rollover between Step 3 and here would derive tomorrow's folder; accepted, and preferred
# to inheriting a variable across a shell boundary where it silently expands to empty.)
FILE="${ARGUMENTS:-}"
if [ -z "$FILE" ]; then
  echo "error: no source file given; pass the source path as the argument" >&2
  exit 1
fi
DATE=$(date -u +"%Y-%m-%d")
SOURCE_BASENAME=$(basename "$FILE" .md | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
ARCHIVE_DIR="ops/queue/archive/${DATE}-${SOURCE_BASENAME}"
mkdir -p "$ARCHIVE_DIR"
if [[ "$FILE" == *"{DOMAIN:inbox}"* ]] || [[ "$FILE" == *"inbox"* ]]; then
  # Checked: an unchecked mv leaves $FINAL_SOURCE pointing at a path that was never
  # created, and every downstream reference then resolves to nothing — the claiming
  # step reporting success while claiming nothing.
  if ! mv "$FILE" "$ARCHIVE_DIR/"; then
    echo "error: could not move '$FILE' into '$ARCHIVE_DIR'" >&2
    exit 1
  fi
  FINAL_SOURCE="$ARCHIVE_DIR/$(basename "$FILE")"
fi
```

**Sources outside {DOMAIN:inbox} stay in place:**
```bash
# Living docs (like configuration files) stay where they are
# Archive folder is still created for task files
# Separate shell invocation: establish the target path here too (see Step 2).
FILE="${ARGUMENTS:-}"
if [ -z "$FILE" ]; then
  echo "error: no source file given; pass the source path as the argument" >&2
  exit 1
fi
FINAL_SOURCE="$FILE"
```

Use `$FINAL_SOURCE` in the task file — this is the path all downstream phases reference.

**Why move immediately:** All references (task files, {DOMAIN:note_plural}' Source footers) use the final archived path from the start. No path updates needed later. If it is in {DOMAIN:inbox}, it is unclaimed. Claimed sources live in archive.

## Step 5: Determine Claim Numbering

Find the highest existing claim number across the queue and archive to ensure globally unique claim IDs.

```bash
# RECURSIVE, AND ops/queue ALONE. /archive-batch moves task files to
# a dated per-source subdirectory of ops/queue/archive, which is DEPTH 2 — a `-maxdepth 1` scan cannot
# see the layout this skill itself creates, so every vault that has completed one
# batch reads as having no claims at all. Passing both ops/queue and its own child
# also double-counts every archived file, which is a wrong number inside an error
# message. One recursive walk of the parent covers both and counts each file once.
#
# ENRICHMENTS DRAW ON THE SAME COUNTER. reduce documents "claims 010-015,
# enrichments start at 016", and enrichment files carry a type of enrichment with no
# `claim:` key. A filter that recognises only claims makes the maximum go backwards
# by however many enrichments the last batch issued — the same defect this scan was
# rewritten to remove, in the other direction. Extract task files carry
# `type: extract` and were never issued a number, so they stay out.
#
# The heading alternative is `# [Cc]laim[ -]`: reduce writes `# Claim NNN:` with a
# capital C and a space, so an exact `^# claim-` branch matches nothing it produces.
issued_files() {
  find "$@" -type f -name '*.md' 2>/dev/null \
    | while IFS= read -r f; do
        grep -qE '^claim: |^type: enrichment|^# [Cc]laim[ -][0-9]+|^# Enrichment [0-9]+' \
          "$f" 2>/dev/null && printf '%s\n' "$f"
      done
}
highest_in() { grep -oE -- '-[0-9]{3,}\.md$' | grep -oE '[0-9]{3,}' | sort -n | tail -1; }

ISSUED_FILES=$(issued_files ops/queue)
FILE_MAX=$(printf '%s\n' "$ISSUED_FILES" | highest_in)

# THE QUEUE IS A RECORD OF ISSUED NUMBERS INDEPENDENT OF THE FILES. reduce writes
# per-claim "file" entries there. Reading only the filesystem restarts
# numbering at 1 against a queue that already records 021 whenever the task files
# have been consumed or cleaned — which is exactly the silent reissue this scan
# exists to prevent.
QUEUE_MAX=$(find ops -maxdepth 2 \( -name 'queue*.yaml' -o -name 'queue*.json' \) \
  -exec grep -ohE -- '-[0-9]{3,}\.md' {} + 2>/dev/null | grep -oE '[0-9]{3,}' | sort -n | tail -1)

# RESERVED BUT UNEXTRACTED RANGES ARE STILL A BLIND SPOT WITHOUT THIS. An extract
# task carries `next_claim_start: NNN` the moment /seed creates it, but issues no
# claim files and no per-claim queue entries until /reduce actually runs — invisible
# to both FILE_MAX and QUEUE_MAX above. A second /seed run on a different source,
# started before the first source's /reduce has fired, sees neither scan reflect the
# first run's reservation and computes the SAME NEXT_CLAIM_START: a collision
# confirmed in practice (a 16-source batch had to be started at a manually-chosen
# 500 to clear two such pending reservations).
#
# THE RESERVATION NEEDS A WIDTH, NOT JUST A FLOOR. Taking next_claim_start itself as
# a floor is not enough: if a pending task reserved 403 and a concurrent run set its
# own start at 404, it would collide with the pending task's own claims (404, 405,
# …) the moment that task is actually extracted. A single dispatch caps near 20
# claims in practice — reserve 50 past every pending start as a heuristic margin,
# not a guarantee: an unusually large single-source batch could still exceed it.
# Matches both `next_claim_start: NNN` (YAML) and `"next_claim_start": NNN` (JSON).
# Scans ALL occurrences, not just pending ones — an already-extracted task's old
# reservation is a harmless, monotonically-safe extra floor, and grep cannot tell
# pending from done without parsing structure this scan deliberately avoids.
RESERVED_MAX=$(find ops -maxdepth 2 \( -name 'queue*.yaml' -o -name 'queue*.json' \) \
  -exec grep -ohE -- 'next_claim_start["'"'"']?[[:space:]]*:[[:space:]]*[0-9]+' {} + 2>/dev/null \
  | grep -oE '[0-9]+$' | sort -n | tail -1)

# BASE 10, EXPLICITLY. Zero-padded numbers are OCTAL to shell arithmetic:
# $((0000010)) is 8, and $((0000019)) is a fatal "value too great for base". With a
# seven-digit pad every claim number hits this. `10#` forces base 10.
FILE_MAX=$((10#${FILE_MAX:-0}))
QUEUE_MAX=$((10#${QUEUE_MAX:-0}))
RESERVED_MAX=$((10#${RESERVED_MAX:-0}))
[ "$RESERVED_MAX" -gt 0 ] && RESERVED_MAX=$((RESERVED_MAX + 50))

# THE GUARD USES THE SCANNER'S OWN DETECTOR. A previous version detected claims by
# filename glob while the scan detected them by content, so the two disagreed about
# what a claim is: it refused to run on a vault whose only file was an extract task
# named `arxiv-2501-12345.md`, and stayed silent on the queue-record case its own
# message describes. Same detector, so it can only fire when the scan genuinely
# failed on files it genuinely recognised.
ISSUED_COUNT=$(printf '%s\n' "$ISSUED_FILES" | grep -c . || true)
if [ "${ISSUED_COUNT:-0}" -gt 0 ] && [ "$FILE_MAX" -eq 0 ] && [ "$QUEUE_MAX" -eq 0 ]; then
  printf 'error: %s numbered files exist but no number could be read — refusing to restart at 1\n' \
    "$ISSUED_COUNT" >&2
  exit 1
fi

# NO "UNCLASSIFIABLE FILE" REFUSAL, DELIBERATELY. A guard that refused on any
# numbered file lacking a marker was written and removed: it fired on a timestamped
# capture sitting in the archive, which is normal vault content, and refusing there
# reproduces exactly the bricking this scan was rewritten to fix. The residual hole
# is a claim file that lost its frontmatter — a corrupt state reduce cannot produce —
# and the queue record above still carries its number, so the counter does not
# restart over it.
# Next claim starts after the highest number seen anywhere — disk, queue record, or a
# pending reservation (with its margin) still awaiting extraction.
CONSUMED_MAX=$((FILE_MAX > QUEUE_MAX ? FILE_MAX : QUEUE_MAX))
NEXT_CLAIM_START=$((CONSUMED_MAX > RESERVED_MAX ? CONSUMED_MAX + 1 : RESERVED_MAX + 1))
```

Claim numbers are globally unique and never reused across batches. This ensures every claim file name (`{source}-{NNN}.md`) is unique vault-wide.

## Step 6: Create Extract Task File

Write the task file to `ops/queue/${SOURCE_BASENAME}.md`:

```markdown
---
id: {SOURCE_BASENAME}
type: extract
source: {FINAL_SOURCE}
original_path: {original file path before move}
archive_folder: {ARCHIVE_DIR}
created: {UTC timestamp}
next_claim_start: {NEXT_CLAIM_START}
---

# Extract {DOMAIN:note_plural} from {source filename}

## Source
Original: {original file path}
Archived: {FINAL_SOURCE}
Size: {line count} lines
Content type: {detected type}

## Scope
{scope guidance if provided via --scope, otherwise: "Full document"}

## Acceptance Criteria
- Extract claims, implementation ideas, tensions, and testable hypotheses
- Duplicate check against {DOMAIN:notes}/ during extraction
- Near-duplicates create enrichment tasks (do not skip)
- Each output type gets appropriate handling

## Execution Notes
(filled by /reduce)

## Outputs
(filled by /reduce)
```

## Step 7: Update Queue

Add the extract task entry to the queue file.

**For YAML queues (ops/queue.yaml):**
```yaml
- id: {SOURCE_BASENAME}
  type: extract
  status: pending
  source: "{FINAL_SOURCE}"
  file: "{SOURCE_BASENAME}.md"
  created: "{UTC timestamp}"
  next_claim_start: {NEXT_CLAIM_START}
```

**For JSON queues (ops/queue/queue.json):**
```json
{
  "id": "{SOURCE_BASENAME}",
  "type": "extract",
  "status": "pending",
  "source": "{FINAL_SOURCE}",
  "file": "{SOURCE_BASENAME}.md",
  "created": "{UTC timestamp}",
  "next_claim_start": {NEXT_CLAIM_START}
}
```

**If no queue file exists:** Create one with the appropriate schema header (phase_order definitions) and this first task entry.

## Step 8: Report

```
--=={ seed }==--

Seeded: {SOURCE_BASENAME}
Source: {original path} -> {FINAL_SOURCE}
Archive folder: {ARCHIVE_DIR}
Size: {line count} lines
Content type: {detected type}

Task file: ops/queue/{SOURCE_BASENAME}.md
Claims will start at: {NEXT_CLAIM_START}
Claim files will be: {SOURCE_BASENAME}-{NNN}.md (unique across vault)
Queue: updated with extract task

Next steps:
  /ralph 1 --batch {SOURCE_BASENAME}     (extract claims)
  /pipeline will handle this automatically
```

---

## Why This Skill Exists

Manual queue management is error-prone. This skill:
- Ensures consistent task file format across batches
- Handles claim numbering automatically (globally unique)
- Checks for duplicates before creating unnecessary work
- Moves sources to their permanent archive location immediately
- Provides clear next steps for the user

## Naming Convention

Task files use the source basename for human readability:
- Task file: `{source-basename}.md`
- Claim files: `{source-basename}-{NNN}.md`
- Summary: `{source-basename}-summary.md`
- Archive folder: `{date}-{source-basename}/`

Claim numbers (NNN) are globally unique across all batches, ensuring every filename is unique vault-wide. This is required because wiki links resolve by filename, not path.

## Source Handling Patterns

**{DOMAIN:inbox} source (most common):**
```
{DOMAIN:inbox}/research/article.md
    | /seed
    v
ops/queue/archive/2026-01-30-article/article.md  <- source moved here
ops/queue/article.md                               <- task file created
```

**Living doc (outside {DOMAIN:inbox}):**
```
CLAUDE.md -> stays as CLAUDE.md (no move)
ops/queue/archive/2026-01-30-claude-md/           <- folder still created
ops/queue/claude-md.md                             <- task file created
```

When /archive-batch runs later, it moves task files into the existing archive folder and generates a summary.

---

## Edge Cases

**Source outside {DOMAIN:inbox}:** Works — source stays in place, archive folder is created for task files only.

**No queue file:** Create `ops/queue/queue.yaml` (or `.json`) with schema header and this first entry.

**Large source (2500+ lines):** Note in output: "Large source ({N} lines) -- /reduce will chunk automatically."

**Source is a URL or non-file:** Report error: "/seed requires a file path."

**No ops/derivation-manifest.md:** Use universal vocabulary for all output.

---

## Critical Constraints

**never:**
- Skip duplicate detection (prevents wasted processing)
- Move a source that is not in {DOMAIN:inbox} (living docs stay in place)
- Reuse claim numbers from previous batches (globally unique is required)
- Create a task file without updating the queue (both must happen together)

**always:**
- Ask before proceeding when duplicates are detected
- Create the archive folder even for living docs (task files need it)
- Use the archived path (not original) in the task file for {DOMAIN:inbox} sources
- Report next steps clearly so the user knows what to do next
- Compute next_claim_start from both queue AND archive (not just one)
