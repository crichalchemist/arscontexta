---
name: graph
description: Interactive knowledge graph analysis. Routes natural language questions to graph scripts, interprets results in domain vocabulary, and suggests concrete actions. Triggers on "/graph", "/graph health", "/graph triangles", "find synthesis opportunities", "graph analysis".
version: "1.0"
generated_from: "arscontexta-v1.6"
user-invocable: true
context: fork
model: sonnet
allowed-tools: Read, Grep, Glob, Bash
argument-hint: "[operation] [target] — operations: health, triangles, bridges, clusters, hubs, siblings, forward, backward, query"
---

## Runtime Configuration (Step 0 — before any processing)

Read these files to configure domain-specific behavior:

1. **`ops/derivation-manifest.md`** — vocabulary mapping, platform hints
   - Use `vocabulary.notes` for the notes folder name
   - Use `vocabulary.note` / `vocabulary.note_plural` for note type references
   - Use `vocabulary.topic_map` / `vocabulary.topic_maps` for MOC references
   - Use `vocabulary.cmd_reflect` for connection-finding command name
   - Use `vocabulary.cmd_reweave` for backward-pass command name

2. **`ops/config.yaml`** — for graph thresholds (MOC size limits, orphan thresholds)

If no derivation file exists, use universal terms (notes, MOCs, etc.).

---

## EXECUTE NOW

**Target: $ARGUMENTS**

Parse the operation from arguments:
- If arguments match a known operation: route to that operation
- If arguments are a natural language question: map to the closest operation (see Interactive Mode)
- If no arguments: enter interactive mode

**START NOW.** Route to the appropriate operation.

---

## Philosophy

**The graph IS the knowledge. This skill makes it visible.**

Individual {vocabulary.note_plural} are valuable, but their connections create compound value. /graph reveals the structural properties of those connections — where the graph is dense, where it is sparse, where it is fragile, and where synthesis opportunities hide.

Every operation produces two things: **findings** (what the analysis reveals) and **actions** (what to do about it). Never dump raw data. Always interpret results with {vocabulary.note} descriptions and domain context. Always suggest specific next steps.

---

## Operations

### /graph health

Full graph health report: density, orphans, dangling links, coverage.

**Step 1: Collect raw metrics**

```bash
# Count total notes (excluding MOCs)
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
if [ "$LINK_EXTRACTION_VERSION" -lt 4 ]; then
  echo "error: link-extraction library is version $LINK_EXTRACTION_VERSION; this skill needs >= 4" >&2
  echo " run /arscontexta:upgrade to refresh it" >&2
  exit 1
fi

# `find`, not a glob, and recursive to match the link library below. Counting
# links over the tree while counting notes over one directory is worse than
# either scope alone: density is links/possible-links, so a recursive LINK_COUNT
# over a flat NOTE_COUNT pushes it above 1, which is impossible.
# A bare glob also aborts under zsh (NOMATCH) when the vault is empty.
TOTAL=$(find "$NOTES_DIR" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
MOC_COUNT=$(find "$NOTES_DIR" -type f -name '*.md' -exec grep -l '^type: moc' {} + 2>/dev/null | wc -l | tr -d ' ')
NOTE_COUNT=$((TOTAL - MOC_COUNT))

# Count all wiki links
LINK_COUNT=$(count_links_recursive "$NOTES_DIR") || {
  echo "error: link counting failed; refusing to report a density figure" >&2
  exit 1
}

# Calculate link density
# Density = actual_links / possible_links
# possible_links = N * (N - 1) for directed graph
echo "Density: $LINK_COUNT / ($NOTE_COUNT * ($NOTE_COUNT - 1))"

# Build both sides once. Orphans and dangling links are the two directions of the
# same comparison, so they share an index and a target set rather than each paying
# for its own scan.
NOTE_INDEX=$(existing_note_index_recursive "$NOTES_DIR") || {
  echo "error: note index build failed; refusing to report orphans or dangling links" >&2
  exit 1
}
# Captured and CHECKED BEFORE the loop: piping extraction into `while` yields the
# loop's status, so a failed extraction would read as "no dangling links".
LINK_TARGETS=$(extract_link_targets_recursive "$NOTES_DIR") || {
  echo "error: link extraction failed; refusing to report dangling links" >&2
  exit 1
}
printf '%s\n' "$LINK_TARGETS" | while read -r NAME; do
  [ -n "$NAME" ] && ! printf '%s\n' "$NOTE_INDEX" | grep -qxF "$NAME" && echo "DANGLING: $NAME"
done

# Orphans: indexed notes nothing links TO — the other direction of the comparison
# above. This replaced a per-note `grep -rl "[[$NAME]]"` loop that ran one recursive
# scan per note and carried all three defects check-portability.sh records as a
# known blind spot: it counted links inside fenced code blocks, did not case-fold,
# and matched the wrong direction. Both sides are already folded and sorted by the
# library, which is what makes comm valid.
LC_ALL=C comm -23 <(printf '%s\n' "$NOTE_INDEX") <(printf '%s\n' "$LINK_TARGETS") \
  | while read -r NAME; do [ -n "$NAME" ] && echo "ORPHAN: $NAME"; done

# MOC coverage: % of notes appearing in at least one MOC's Core Ideas.
# The replaced form ran `xargs grep -l` with the note name inside the pattern —
# the same matcher removed from the orphan comparison above, spelled so that the
# search string divergence 6 tracked could not see it. Here its three defects
# bias a PERCENTAGE rather than a count: a link inside a ``` block counted as
# coverage, a MOC linking [[Zettelkasten]] did not cover `zettelkasten.md`, and
# a note named `a.b` was covered by any [[axb]].
#
# The MOC file list is still built once, outside any loop, for the reason the
# previous comment recorded: an EMPTY list left `xargs` with no file arguments,
# and GNU xargs then ran grep against the loop's own stdin and swallowed the
# `find` stream, while BSD xargs skipped the run entirely. No xargs remains, but
# building it once still matters — per-note rebuilds rescanned the vault n times.
MOC_FILES=$(find "$NOTES_DIR" -type f -name '*.md' -exec grep -l '^type: moc' {} + 2>/dev/null)

# Folded MOC basenames, so MOCs can be removed from the denominator set the same
# way NOTE_COUNT already subtracts them from the total.
# LC_ALL=C is not decoration: this set is a comm operand below, joined against
# NOTE_INDEX and MOC_TARGETS, both of which are pinned to C collation (the
# library pins its exports; MOC_SRC/MOC_TARGETS are pinned in this fence). comm
# requires the SAME collation on both sides, not merely that each side is sorted,
# and it does not warn on a mismatch -- it returns the wrong set at exit 0.
MOC_INDEX=$(printf '%s\n' "$MOC_FILES" | while IFS= read -r m; do
  [ -n "$m" ] && basename "$m" .md
done | _fold_lower | LC_ALL=C sort -u)

# Targets linked FROM MOCs. link_edge_map_recursive emits
# source_basename<TAB>target<TAB>source_path (columns 1-2 folded). Basenames
# collide across directories under a recursive scan, so we filter by source
# PATH (column 3) against MOC_FILES rather than by folded basename — a non-MOC
# sharing a MOC's basename must not contribute to coverage.
EDGE_MAP=$(mktemp) || exit 1
link_edge_map_recursive "$NOTES_DIR" > "$EDGE_MAP" || {
  rm -f "$EDGE_MAP"
  echo "error: MOC link extraction failed; refusing to report a coverage figure" >&2
  exit 1
}
MOC_SRC=$(mktemp) || { rm -f "$EDGE_MAP"; exit 1; }
printf '%s\n' "$MOC_FILES" | grep -v '^$' | LC_ALL=C sort -u > "$MOC_SRC"
# -F'\t': the default FS splits on any whitespace, which corrupts the split when
# a note name contains a space (link_edge_map_recursive's columns are tab-separated).
MOC_TARGETS=$(awk -F'\t' 'FNR==NR {moc[$1]=1; next} $3 in moc {print $2}' "$MOC_SRC" "$EDGE_MAP" | LC_ALL=C sort -u)
rm -f "$EDGE_MAP" "$MOC_SRC"

# "Sorted" alone would NOT make this valid: comm requires the SAME collation on
# both sides, not merely that each side is independently sorted, and it does not
# warn on a mismatch -- it returns the wrong set at exit 0. All three operands
# are pinned to C: NOTE_INDEX by the library (>= v4), MOC_TARGETS above, and
# MOC_INDEX where it is built. Do not unpin any of them in isolation.
COVERED=$(LC_ALL=C comm -12 \
  <(LC_ALL=C comm -23 <(printf '%s\n' "$NOTE_INDEX") <(printf '%s\n' "$MOC_INDEX")) \
  <(printf '%s\n' "$MOC_TARGETS") | grep -c . || true)
echo "Coverage: $COVERED / $NOTE_COUNT"
```

If graph helper scripts exist in `ops/scripts/graph/`, use them instead of inline analysis:
- `ops/scripts/graph/link-density.sh` for density metrics
- `ops/scripts/graph/orphan-notes.sh` for orphan detection
- `ops/scripts/graph/dangling-links.sh` for dangling link detection

**Step 2: Interpret and present**

```
--=={ graph health }==--

  {vocabulary.note_plural}: [N] (plus [M] {vocabulary.topic_maps})
  Connections: [N] (avg [X] per {vocabulary.note})
  Graph density: [0.XX]
  {vocabulary.topic_map} coverage: [N]% of {vocabulary.note_plural} appear in at least one {vocabulary.topic_map}

  Orphans ([N]):
    - [[orphan name]] — [description from YAML]
    → Suggestion: Run {vocabulary.cmd_reflect} to find connections

  Dangling Links ([N]):
    - [[missing name]] — referenced from [[source note]]
    → Suggestion: Create the {vocabulary.note} or remove the link

  {vocabulary.topic_map} Sizes:
    - [[moc name]]: [N] {vocabulary.note_plural} [OK | WARN: approaching split threshold | WARN: consider merging]

  Overall: [HEALTHY | NEEDS ATTENTION | FRAGMENTED]
```

**Density benchmarks:**

| Density | Interpretation |
|---------|---------------|
| < 0.02 | Sparse — {vocabulary.note_plural} exist but connections are thin |
| 0.02-0.06 | Healthy — growing network with meaningful connections |
| 0.06-0.15 | Dense — well-connected, watch for over-linking |
| > 0.15 | Very dense — verify connections are genuine, not noise |

### /graph triangles

Find synthesis opportunities — open triadic closures where A links to B and A links to C, but B does not link to C.

**Step 1: Build adjacency data**

```bash
# Each fenced block is a SEPARATE shell invocation: no variable and no sourced
# function survives from the /graph health block above. NOTES_DIR and the
# link-extraction library must both be re-established here. Relying on the
# earlier block leaves $_LINK_FOLD_LOCALE empty, which is not an error — it is
# the caller's default locale, so folding silently degrades on a C-locale host.
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
if [ "$LINK_EXTRACTION_VERSION" -lt 3 ]; then
  echo "error: link-extraction library is version $LINK_EXTRACTION_VERSION; this skill needs >= 3" >&2
  echo " run /arscontexta:upgrade to refresh it" >&2
  exit 1
fi

# An EMPTY vault is a legitimate empty adjacency set; a MISSING directory is a
# failure and must not render as one. Nothing else in this block catches it:
# the library is sourced but its recursive helpers are never called here, and
# `find "$NOTES_DIR" | while` discards find's status at the pipe — measured, a
# nonexistent directory gave exit 0, zero stdout, and only a `find: ... No such
# file or directory` line on stderr that no caller reads.
[ -d "$NOTES_DIR" ] || {
  echo "error: notes directory '$NOTES_DIR' does not exist; refusing to report an empty triangle set" >&2
  exit 1
}

# Trim and fold to match the dangling-link check in /graph health, which folds
# both sides via the library. Comparing unfolded targets here against folded
# ones there makes [[Zettelkasten]] and [[zettelkasten]] two distinct nodes, so
# closure detection misses triangles rather than reporting an error.

# Extract outgoing links for each note using link_edge_map_recursive, which
# already handles fence stripping and link extraction. Output in FROM/TO format
# for triangle detection. Recursive: the original scanned all of NOTES_DIR, not
# just its top level.
EDGE_MAP=$(mktemp) || exit 1
link_edge_map_recursive "$NOTES_DIR" > "$EDGE_MAP" || {
  rm -f "$EDGE_MAP"
  echo "error: link extraction failed; refusing to report an empty triangle set" >&2
  exit 1
}
# The source column above is a folded basename (reference/lib/link-extraction.sh
# builds it via `basename ... .md | _fold_lower`). The original printed the
# UNFOLDED basename for the FROM: label — folding was applied only to targets,
# for case-insensitive matching — so triangle output shows each note's real
# title case. Build a folded -> unfolded basename index to restore that.
NAME_RAW=$(mktemp) || { rm -f "$EDGE_MAP"; exit 1; }
find "$NOTES_DIR" -type f -name '*.md' -not -path '*/.git/*' > "$NAME_RAW" || {
  rm -f "$EDGE_MAP" "$NAME_RAW"
  echo "error: link extraction failed; refusing to report an empty triangle set" >&2
  exit 1
}
NAME_INDEX=$(mktemp) || { rm -f "$EDGE_MAP" "$NAME_RAW"; exit 1; }
while IFS= read -r f; do
  NAME=$(basename "$f" .md)
  printf '%s\t%s\n' "$(printf '%s\n' "$NAME" | _fold_lower)" "$NAME"
done < "$NAME_RAW" > "$NAME_INDEX"
# Notes with zero outgoing links never appear in $1 below and so emit no FROM:
# line, unlike the original, which printed FROM:$NAME for every note regardless.
# Deliberately not restored: such a note has no B/C to form a triangle with, so
# Step 2 below cannot use the line either way.
awk -F'\t' '{print $1}' "$EDGE_MAP" | LC_ALL=C sort -u | while IFS= read -r src; do
  DISPLAY=$(awk -F'\t' -v s="$src" '$1 == s {print $2; exit}' "$NAME_INDEX")
  echo "FROM:${DISPLAY:-$src}"
  awk -F'\t' -v s="$src" '$1 == s {print $2}' "$EDGE_MAP" | LC_ALL=C sort -u | while read -r target; do
    [ -n "$target" ] && echo "  TO:$target"
  done
done
rm -f "$EDGE_MAP" "$NAME_RAW" "$NAME_INDEX"
```

If `ops/scripts/graph/find-triangles.sh` exists, use it directly.

**Step 2: Find open triangles**

For each note A with outgoing links to B and C:
1. Check if B links to C (in either direction)
2. Check if C links to B (in either direction)
3. If neither link exists: this is an open triangle (synthesis opportunity)

**Step 3: Evaluate and rank**

For each open triangle:
1. Read descriptions of BOTH unlinked {vocabulary.note_plural}
2. Assess: is there a genuine conceptual relationship that the common parent suggests?
3. Rank by potential value: how surprising and useful would the connection be?

**Step 4: Present top findings**

```
--=={ graph triangles }==--

  Found [N] synthesis opportunities — pairs of {vocabulary.note_plural} that share
  a common reference but do not reference each other:

  1. [[note B]] and [[note C]]
     Common parent: [[note A]]
     B: "[description]"
     C: "[description]"
     → These may benefit from a connection because [specific reasoning
        about WHY B and C might relate through A's lens]
     → Action: Run {vocabulary.cmd_reflect} on [[note B]] to evaluate

  2. [[note D]] and [[note E]]
     Common parent: [[note F]]
     ...

  [Show top 10. If more exist: "[N] more triangles found. Show all? (yes/no)"]
```

**Filter out trivial triangles:** Skip pairs where:
- Both are in the same {vocabulary.topic_map} (they may already be related through the MOC without direct links)
- One is a {vocabulary.topic_map} itself (MOCs link to everything, triangles with MOCs are noise)
- The descriptions suggest no conceptual overlap

### /graph bridges

Identify structurally critical {vocabulary.note_plural} whose removal would disconnect graph regions.

**Step 1: Build adjacency list**

Build a bidirectional adjacency list from all wiki links in {vocabulary.notes}/.

If `ops/scripts/graph/find-bridges.sh` exists, use it directly.

**Step 2: Find bridge nodes**

A bridge note is one where:
- Removing it (and its links) would split a connected component into two or more components
- It is the SOLE connection between clusters of {vocabulary.note_plural}

Implementation: For each note, temporarily remove it and check if the remaining graph has more connected components.

**Step 3: Present findings**

```
--=={ graph bridges }==--

  Found [N] bridge {vocabulary.note_plural} — structurally critical nodes whose
  removal would disconnect graph regions:

  1. [[bridge note]] — connects [N] {vocabulary.note_plural} on one side to [M] on the other
     Description: "[description]"
     Cluster A: [[note1]], [[note2]], ...
     Cluster B: [[note3]], [[note4]], ...
     → Risk: If this {vocabulary.note} becomes stale, [N+M] {vocabulary.note_plural}
       lose their connection path
     → Action: Consider adding parallel connections between the clusters

  [If no bridges: "No bridge notes found. The graph has redundant paths between
   all connected regions. This is healthy."]
```

### /graph clusters

Discover connected components and topic boundaries.

**Step 1: Build adjacency list**

Build a bidirectional adjacency list from all wiki links.

If `ops/scripts/graph/find-clusters.sh` exists, use it directly.

**Step 2: Find connected components**

Use BFS/DFS to find all connected components:
1. Start with any unvisited note
2. Traverse all reachable notes via wiki links (bidirectional)
3. Mark as one component
4. Repeat until all notes visited

**Step 3: Analyze clusters**

For each cluster:
- Size (number of {vocabulary.note_plural})
- Key {vocabulary.note_plural} (highest link count within cluster)
- Topic coverage (which {vocabulary.topic_maps} are represented)
- Isolation level (how many links cross cluster boundaries)

**Step 4: Present findings**

```
--=={ graph clusters }==--

  Found [N] connected components:

  Cluster 1: [size] {vocabulary.note_plural}
    Key nodes: [[note1]] (8 links), [[note2]] (6 links)
    Topics: [[topic A]], [[topic B]]
    Cross-cluster links: [N]
    → This cluster is [well-connected | isolated | a hub]

  Cluster 2: [size] {vocabulary.note_plural}
    ...

  Isolated {vocabulary.note_plural} ([N]):
    - [[isolated note]] — [description]
    → Action: Run {vocabulary.cmd_reflect} to find connections

  [If 1 cluster: "All {vocabulary.note_plural} are in one connected component.
   The graph is fully connected. This is healthy."]
```

### /graph hubs

Rank {vocabulary.note_plural} by influence — most-linked-to (authorities) and most-linking-from (hubs).

**Step 1: Count links**

```bash
# Each fenced block is a SEPARATE shell invocation: neither NOTES_DIR nor the
# link-extraction library survives from the blocks above. Left undefined,
# `find ""` scans nothing and the ranking comes back empty — which reads exactly
# like a vault with no links. Both must be re-established here.
NOTES_DIR="{vocabulary.notes}"

# An EMPTY vault is a legitimate empty ranking; a MISSING directory is a failure
# and must not render as one.
[ -d "$NOTES_DIR" ] || {
  echo "error: notes directory '$NOTES_DIR' does not exist; refusing to report an influence ranking" >&2
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
if [ "$LINK_EXTRACTION_VERSION" -lt 3 ]; then
  echo "error: link-extraction library is version $LINK_EXTRACTION_VERSION; this skill needs >= 3" >&2
  echo " run /arscontexta:upgrade to refresh it" >&2
  exit 1
fi

# Authority score: incoming links per note.
# Captured FIRST, then sorted. `done | sort | head` yields HEAD's status, so a
# failed scan rendered as an empty ranking with exit 0 — indistinguishable from
# a vault that genuinely has no links.
#
# The replaced spelling recursively grepped the whole tree for this note's own
# name wrapped in brackets, then filtered that hit list with `grep -v` on the
# file path. It was the last inlined wiki-link matcher in this tree. It is
# DESCRIBED rather than quoted: the literal spelling is the search pattern used
# to prove this class is gone from skill-sources/, so a comment reproducing it
# would answer that search with itself.
#
# Measured against a fixture, it was wrong three ways AT ONCE, and in BOTH
# directions — which is why no single number ever looked implausible enough to
# investigate:
#   - it counted a link that sat inside a ``` fence  (scored 1, truly 0)
#   - it missed [[target]] against Target.md, and missed [[Target|alias]]
#     entirely, because it matched neither case-folded nor up to the `|`
#     terminator                                     (scored 0, truly 2)
#   - it interpolated $NAME into a REGEX, so a note named `a.b` also matched a
#     link to `axb`                                  (scored 2, truly 1)
# Fences and case are the library's job; `grep -cxF` below — fixed-string and
# whole-line — is what closes the third. `grep -v "$f"` had the same regex hole
# on the exclusion side; self-links are now dropped by string comparison.
#
# Edges are built ONCE into a file and then counted per note, rather than
# re-scanning the whole tree once per note. One line per (source file, distinct
# target) pair: `grep -rl | wc -l` counted FILES, not link occurrences, and that
# is the semantics being preserved — deduped below, since link_edge_map_recursive
# emits one row per link OCCURRENCE with no dedup, and a note linking twice to
# the same target must not inflate that target's authority score.
TMP_EDGES=$(mktemp) || exit 1
# Build the edge list for authority ranking. link_edge_map_recursive returns
# source<TAB>target<TAB>source_path (source and target folded), and we extract
# targets, excluding self-loops, to count incoming links. This replaces the
# per-file extraction loop. Recursive: the original scanned all of NOTES_DIR,
# not just its top level.
link_edge_map_recursive "$NOTES_DIR" > "$TMP_EDGES" || {
  rm -f "$TMP_EDGES"
  echo "error: authority scan failed; refusing to report an influence ranking" >&2
  exit 1
}

AUTH_RAW=$(find "$NOTES_DIR" -type f -name '*.md' | while IFS= read -r f; do
  NAME=$(basename "$f" .md)
  FOLDED=$(printf '%s\n' "$NAME" | _fold_lower)
  # Count incoming links by finding rows where target equals this note, excluding
  # self-loops. Source basenames collide across directories under a recursive
  # scan, so we dedupe on the source PATH (column 3), not the folded basename —
  # two files sharing a basename are two distinct sources, per the comment above.
  INCOMING=$(awk -F'\t' -v tgt="$FOLDED" '$2 == tgt && $1 != tgt {print $3}' "$TMP_EDGES" | LC_ALL=C sort -u | wc -l | tr -d ' ')
  echo "AUTH:$INCOMING:$NAME"
done)
rm -f "$TMP_EDGES"

# Hub score: outgoing links per note.
# The failure flag is a FILE, not a variable: the loop body runs in a subshell
# (find | while), so an assignment would be discarded at the pipe. PIPESTATUS is
# bash-only and reads empty under zsh, so it is not the fix.
# rg runs as its own statement rather than as a pipeline stage: piped into
# `wc -l` its status was discarded, so a broken RIPGREP_CONFIG_PATH — or an rg
# missing from PATH — scored every note 0 outgoing links.
# rc 1 means "this file has no links" and is NORMAL; only rc >1 is a failure.
TMP_STRIPPED=$(mktemp) || exit 1
TMP_LINKS=$(mktemp) || { rm -f "$TMP_STRIPPED"; exit 1; }
ERRF="/tmp/graph-hubs-err-$$"
rm -f "$ERRF"
HUB_RAW=$(find "$NOTES_DIR" -type f -name '*.md' | while IFS= read -r f; do
  NAME=$(basename "$f" .md)
  awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$f" > "$TMP_STRIPPED" || {
    touch "$ERRF"; continue
  }
  rg -o '\[\[' "$TMP_STRIPPED" > "$TMP_LINKS"
  if [ $? -gt 1 ]; then
    touch "$ERRF"; continue
  fi
  OUTGOING=$(wc -l < "$TMP_LINKS" | tr -d ' ')
  echo "HUB:$OUTGOING:$NAME"
done)
if [ -e "$ERRF" ]; then
  rm -f "$TMP_STRIPPED" "$TMP_LINKS" "$ERRF"
  echo "error: link scan failed; refusing to report a hub ranking" >&2
  exit 1
fi
rm -f "$TMP_STRIPPED" "$TMP_LINKS" "$ERRF"

# Both rankings print together, AFTER both scans have been checked. Printing
# authorities as soon as they were ready meant a failed hub scan still put a
# full, correct-looking AUTH ranking on stdout with nothing where the hub
# ranking should be — a partial render that reads as "this vault has no hubs".
# Either the whole ranking is trustworthy or the block emits no figures at all.
printf '%s\n' "$AUTH_RAW" | sort -t: -k2 -rn | head -10
printf '%s\n' "$HUB_RAW" | sort -t: -k2 -rn | head -10
```

If `ops/scripts/graph/influence-flow.sh` exists, use it directly.

**Step 2: Identify synthesizers**

Synthesizer {vocabulary.note_plural} score high on BOTH metrics — they absorb many inputs (high authority) and produce many outputs (high hub). These are the most structurally important {vocabulary.note_plural} in the graph.

**Step 3: Present findings**

```
--=={ graph hubs }==--

  Top Authorities (most-linked-to):
    1. [[note]] — [N] incoming links — "[description]"
    2. [[note]] — [N] incoming links — "[description]"
    ...

  Top Hubs (most-linking-from):
    1. [[note]] — [N] outgoing links — "[description]"
    2. [[note]] — [N] outgoing links — "[description]"
    ...

  Synthesizers (high on both — structurally important):
    1. [[note]] — [N] in / [M] out — "[description]"
    ...

  [If no clear synthesizers: "No notes score high on both metrics.
   This suggests the graph has separate input and output layers."]
```

### /graph siblings [[topic]]

Find unconnected {vocabulary.note_plural} within a topic — {vocabulary.note_plural} sharing the same {vocabulary.topic_map} but not linking to each other.

**Step 1: Read the specified {vocabulary.topic_map}**

Find and read the {vocabulary.topic_map} matching the argument. Extract all {vocabulary.note_plural} linked in Core Ideas.

**Step 2: Check pairwise connections**

For each pair of {vocabulary.note_plural} in the {vocabulary.topic_map}:
1. Does A link to B? (grep for `[[B]]` in A's file)
2. Does B link to A? (grep for `[[A]]` in B's file)
3. If neither: this is an unconnected sibling pair

If `ops/scripts/graph/topic-siblings.sh` exists, use it with the topic argument.

**Step 3: Evaluate pairs**

For each unconnected pair:
- Read both descriptions
- Assess whether a connection SHOULD exist
- Rate as: likely connection, possible connection, appropriately separate

**Step 4: Present findings**

```
--=={ graph siblings: [[topic]] }==--

  {vocabulary.topic_map} [[topic]] has [N] {vocabulary.note_plural}.
  Found [M] unconnected sibling pairs:

  Likely connections:
    1. [[note A]] and [[note B]]
       A: "[description]"
       B: "[description]"
       → [Why these likely relate]

  Possible connections:
    2. [[note C]] and [[note D]]
       ...

  Appropriately separate: [N] pairs — no connection needed

  → Action: Run {vocabulary.cmd_reflect} on the "likely" pairs
```

### /graph forward [[note]] [depth]

N-hop forward traversal from a {vocabulary.note}. Default depth: 2.

**Step 1: Start from the specified {vocabulary.note}**

Read the {vocabulary.note} and extract all outgoing wiki links (hop 1).

If `ops/scripts/graph/n-hop-forward.sh` exists, use it with the note and depth arguments.

**Step 2: Traverse**

For each linked {vocabulary.note}:
1. Read it and extract its outgoing wiki links (hop 2)
2. Continue to specified depth
3. Track visited notes to avoid cycles

**Step 3: Present as annotated tree**

```
--=={ forward traversal: [[note]] (depth [N]) }==--

  [[root note]] — "[description]"
    ├── [[link 1]] — "[description]"
    │   ├── [[link 1a]] — "[description]"
    │   └── [[link 1b]] — "[description]"
    ├── [[link 2]] — "[description]"
    │   └── [[link 2a]] — "[description]"
    └── [[link 3]] — "[description]"

  Reached [N] {vocabulary.note_plural} in [depth] hops.
  Dead ends (no outgoing links): [[note X]], [[note Y]]
  Cycles detected: [[note]] → ... → [[note]] (skipped)
```

### /graph backward [[note]] [depth]

N-hop backward traversal to a {vocabulary.note}. Default depth: 2.

**Step 1: Start from the specified {vocabulary.note}**

Find all notes that link TO this {vocabulary.note} (hop 1).

```bash
# Each fenced block is a SEPARATE shell invocation: NOTES_DIR does not survive
# from the blocks above. Left undefined, `find ""` scans nothing and the hop-1
# set comes back empty — which reads exactly like a note nothing links to. The
# `2>/dev/null` on the find below hides even the "No such file" line, so the
# whole traversal reports "no backlinks" at exit 0 on a vault full of them.
NOTES_DIR="{vocabulary.notes}"

# An EMPTY vault is a legitimate empty result; a MISSING directory is a failure
# and must not render as one.
[ -d "$NOTES_DIR" ] || {
  echo "error: notes directory '$NOTES_DIR' does not exist; refusing to report backlinks" >&2
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
if [ "$LINK_EXTRACTION_VERSION" -lt 3 ]; then
  echo "error: link-extraction library is version $LINK_EXTRACTION_VERSION; this skill needs >= 3" >&2
  echo " run /arscontexta:upgrade to refresh it" >&2
  exit 1
fi

NAME="[note name]"
# Backlinks to a specific note. link_edge_map_recursive emits
# source<TAB>target<TAB>source_path (source and target folded); see below for
# why column 3 matters here. This replaces the per-file loop that stripped
# fences and extracted links to check each against the target. Recursive: the
# original scanned all of NOTES_DIR, not just its top level.
# A backlink list is not a count, so its failure mode is worse than a wrong number:
# resolution is delegated to the library; the per-file machinery is no longer needed.
TARGET=$(printf '%s\n' "$NAME" | _fold_lower)
EDGES=$(mktemp) || exit 1
link_edge_map_recursive "$NOTES_DIR" > "$EDGES" || {
  rm -f "$EDGES"
  echo "error: backlink scan failed; refusing to report a partial backlink list" >&2
  exit 1
}
# Column 3 is the source path exactly as link_edge_map_recursive's own find
# produced it, so no basename-to-path resolution is needed. Source basenames
# collide across directories under a recursive scan, so we print and dedupe on
# the path (column 3) itself, not the folded basename in column 1.
awk -F'\t' -v tgt="$TARGET" '$2 == tgt {print $3}' "$EDGES" | LC_ALL=C sort -u
rm -f "$EDGES"
```

If `ops/scripts/graph/recursive-backlinks.sh` exists, use it with the note and depth arguments.

**Step 2: Traverse backward**

For each linking {vocabulary.note}:
1. Find what links to IT (hop 2)
2. Continue to specified depth
3. Track visited notes to avoid cycles

**Step 3: Present as annotated tree**

```
--=={ backward traversal: [[note]] (depth [N]) }==--

  [[root note]] — "[description]"
    ├── [[referrer 1]] — "[description]"
    │   ├── [[referrer 1a]] — "[description]"
    │   └── [[referrer 1b]] — "[description]"
    ├── [[referrer 2]] — "[description]"
    │   └── [[referrer 2a]] — "[description]"
    └── [[referrer 3]] — "[description]"

  [N] {vocabulary.note_plural} lead to [[root note]] within [depth] hops.
  Entry points (no incoming links): [[note X]], [[note Y]]
```

### /graph query [field] [value]

Schema-level YAML query across {vocabulary.note_plural}.

**Step 1: Parse field and value**

Supported query patterns:

| Query | Ripgrep Pattern | Purpose |
|-------|----------------|---------|
| `topics [[X]]` | `rg '^topics:.*\[\[X\]\]'` | Find notes in a topic |
| `type tension` | `rg '^type: tension'` | Find notes by type |
| `methodology X` | `rg '^methodology:.*X'` | Find notes by tradition |
| `status open` | `rg '^status: open'` | Find notes by status |
| `created 2026-02` | `rg '^created: 2026-02'` | Find notes by date range |
| `source [[X]]` | `rg '^source:.*\[\[X\]\]'` | Find notes from a source |

**Step 2: Execute query**

```bash
# Each fenced block is a SEPARATE shell invocation: NOTES_DIR does not survive
# from the blocks above. Left undefined, `find ""` scans nothing and the query
# returns no rows — which reads exactly like a query that matched nothing.
NOTES_DIR="{vocabulary.notes}"

# An EMPTY vault is a legitimate empty result set; a MISSING directory is a
# failure and must not render as one.
[ -d "$NOTES_DIR" ] || {
  echo "error: notes directory '$NOTES_DIR' does not exist; refusing to report query results" >&2
  exit 1
}

# File list comes from `find`, not from rg's own directory walk. Handed a
# directory, rg applies .gitignore/.ignore rules and skips hidden dirs, so a
# gitignored subdirectory would silently return fewer notes here than /graph
# health counts. An explicit file list disables that filtering.
find "$NOTES_DIR" -type f -name '*.md' -exec rg -l "^{field}:.*{value}" {} + 2>/dev/null
```

For each matching file, extract the description for context.

**Step 3: Present results**

```
--=={ graph query: {field} = {value} }==--

  Found [N] {vocabulary.note_plural}:

  1. [[note name]] — "[description]"
  2. [[note name]] — "[description]"
  ...

  Distribution:
    [If querying topics: how many per sub-topic]
    [If querying type: breakdown by status]
    [If querying methodology: breakdown by tradition]
```

---

## Interactive Mode

If no arguments provided:

1. Ask: "What would you like to know about your knowledge graph?"
2. Map natural language to operation:

| User Says | Maps To | Why |
|-----------|---------|-----|
| "Where should I look for connections?" | triangles | Finding synthesis opportunities |
| "What are my most important notes?" | hubs | Authority/hub ranking |
| "Are there isolated areas?" | clusters | Connected component detection |
| "How healthy is my graph?" | health | Full health report |
| "What bridges my topics?" | bridges | Bridge note identification |
| "What connects to [[X]]?" | backward [[X]] | Backward traversal |
| "Where does [[X]] lead?" | forward [[X]] | Forward traversal |
| "Show me notes about [topic]" | query topics [[topic]] | Schema query |
| "What needs connecting in [topic]?" | siblings [[topic]] | Unconnected sibling pairs |

3. Run the mapped operation
4. After presenting results, offer follow-up: "Want to explore any of these further?"

---

## Output Rules

- **Never dump raw data.** Always interpret results with {vocabulary.note} descriptions and context.
- **Always suggest actions.** "Run {vocabulary.cmd_reflect} on these pairs" or "Consider adding a bridge {vocabulary.note} about X."
- **Use domain vocabulary** for all labels and descriptions — {vocabulary.note}, {vocabulary.topic_map}, etc.
- **For large result sets,** summarize top findings (max 10) and offer to show more: "[N] more results. Show all? (yes/no)"
- **Include density benchmarks** for context — "your density of 0.04 is in the healthy range."
- **Distinguish structural from semantic.** Graph analysis reveals structural properties. Semantic judgment about WHETHER connections should exist requires {vocabulary.cmd_reflect}.

---

## Edge Cases

### Small Vault (<10 notes)

Report metrics but contextualize: "With [N] {vocabulary.note_plural}, graph analysis provides limited insight. Graph operations become more valuable as the knowledge graph grows. Current metrics are baseline measurements."

All operations still run — they just produce less data.

### No Graph Scripts Available

If `ops/scripts/graph/` does not exist or individual scripts are missing, implement the analysis inline using grep, file reads, and bash loops as shown in each operation's steps. The inline implementations are complete — scripts are optimization, not requirements.

### No ops/derivation-manifest.md

Use universal vocabulary (notes, MOCs, etc.). All operations work identically.

### Empty Notes Directory

Report: "No {vocabulary.note_plural} found in {vocabulary.notes}/. Start by capturing content to build your knowledge graph."

### Note Not Found (for forward/backward/siblings)

If the specified {vocabulary.note} or {vocabulary.topic_map} does not exist:
1. Search for partial matches: `find "$NOTES_DIR" -type f -name '*{query}*.md' 2>/dev/null`
2. If matches found: "Did you mean: [[match1]], [[match2]]?"
3. If no matches: "{vocabulary.note} '[[name]]' not found. Check the name and try again."
