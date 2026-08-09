# Link Edge Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `reference/lib/link-extraction.sh` the per-target functions it lacks, then convert the 12 sites that inline them — removing an O(n²) scan and a live regex-injection bug in the same change.

**Architecture:** Three new functions built in a dependency chain — `link_edge_map` emits the raw edge list, `backlink_counts` aggregates it, `orphan_notes` set-subtracts it from the note index. Each has a flat and a `_recursive` variant, matching the library's existing pattern. Consumers then read the library instead of re-inlining a three-stage pipeline.

**Tech Stack:** POSIX-ish bash (must run identically under bash and zsh), `rg`, `awk`, `sed`, `comm`, `sort` with `LC_ALL=C` pinned.

**Source spec:** `docs/superpowers/specs/2026-08-08-corpus-wide-passes-design.md` — item 2 only. Items 1 and 3 are a separate plan; they are coupled to each other and independent of this one.

## Global Constraints

- **`LINK_EXTRACTION_VERSION` 2 → 3.** Every consumer guard asserts `>= 3`. The constant, `skills/setup`'s library copy table, and `skills/upgrade` §6a's version table move together — a bump that moves some declared sites and not others is the defect `bump-version.test.sh` exists to catch.
- **`LC_ALL=C` on EVERY sort and every `comm` input.** Default `sort` is locale-dependent; an unpinned side makes non-ASCII names spuriously dangle, silently. This is the collation trap from the exhaustive-dangling-scan fix.
- **A failure must never be a number.** Existing library functions `return 1` on error and print nothing. Preserve that — a function that prints `0` on failure is indistinguishable from a correct empty result.
- **No scan caps.** No `head -N` on any link or note pipeline. Divergence 11 was a `head -100` that reported a sampled PASS as a property of the whole graph.
- **Both shells, every task.** `bash` and `zsh`. Three shipped defects here were bash/zsh forks; zsh's default `nomatch` makes an unmatched glob an error rather than an empty list.
- **Vault-side templates source `ops/lib/`, repo-side scripts source `reference/lib/`.** A generated vault has no `reference/` directory.
- **New `LINK_LIB` sites use the prefixed spelling** `LINK_LIB="$VAULT_ROOT/ops/lib/link-extraction.sh"` — 8 existing sites use it, 1 (`next:261`) uses a bare relative path that depends on the fence's working directory. Match the 8. Do not convert the 1 in this work.

## Deviation from the spec, decided here

The spec proposed variadic `link_edge_map <dir>...`. **The library does not work that way**: every existing function takes a single `<dir>` and pairs with a `_recursive` variant (`count_links` / `count_links_recursive`, etc.), and each calls `_require_deps_and_dir "$1"`. Rule 12 — conformance over taste — so this plan ships **flat + `_recursive` pairs** instead. Consumers needing whole-vault scope call the `_recursive` variant on the vault root; consumers needing the notes directory call the flat one. This makes scope explicit at the call site, which is what the spec actually wanted.

---

## File Structure

| file | responsibility | change |
|---|---|---|
| `reference/lib/link-extraction.sh` | the single definition of link counting and resolution | +6 functions, version 2→3 |
| `reference/test/link-extraction.test.sh` | library behaviour, incl. "a failure must never be a number" | +fixture, +assertions |
| `skills/health/SKILL.md` | vault health report | 3 sites converted |
| `skills/architect/SKILL.md` | evolution advice | 1 site converted |
| `platforms/claude-code/hooks/session-orient.sh.template` | SessionStart orientation | 1 site, special treatment |
| `skill-sources/{graph,reflect,reweave,stats}/SKILL.md` | vault skills | 7 extraction sites converted |
| `reference/check-portability.sh` | check 6 allowlist | 3 entries drained |
| `skills/setup/SKILL.md`, `skills/upgrade/SKILL.md` | library copy + version tables | v3 |
| `CLAUDE.md` | divergences 12, 13 | counts updated |

---

## Task 1: `link_edge_map` and the version bump

**Files:**
- Modify: `reference/lib/link-extraction.sh` (version constant; append 2 functions)
- Modify: `reference/test/link-extraction.test.sh`
- Modify: `skills/setup/SKILL.md` (library copy table), `skills/upgrade/SKILL.md` (§6a version table)

**Interfaces:**
- Consumes: `_require_deps_and_dir`, `_strip_fences`, `_fold_lower` (existing private helpers)
- Produces: `link_edge_map <dir>` and `link_edge_map_recursive <dir>`, each emitting `source<TAB>target` lines — source is the folded basename of the linking file, target the folded link target. Self-edges included at this layer (Task 2 excludes them). Returns 1 and prints nothing on error.

- [ ] **Step 1: Write the failing test — build the discriminating fixture**

Add to `reference/test/link-extraction.test.sh`, before the summary block:

```bash
# --- link_edge_map: one fixture, one row per correctness property -------------
# Every note here exists to make a DIFFERENT wrong implementation fail. Do not
# trim it: the a.b/axb pair is the live bug (3 field-vault notes exposed), and
# the fenced note is the one an rg-without-_strip_fences passes.
EDGE_DIR=$(mktemp -d)
mkdir -p "$EDGE_DIR/notes"
printf -- '---\ntitle: Alpha\n---\nlinks [[Target]] and [[a.b]]\n'          > "$EDGE_DIR/notes/alpha.md"
printf -- '---\ntitle: Beta\n---\nlinks [[TARGET]] and [[Target|an alias]]\n' > "$EDGE_DIR/notes/beta.md"
printf -- '---\ntitle: Gamma\n---\nlinks [[Target#a-heading]]\n'            > "$EDGE_DIR/notes/gamma.md"
printf -- '---\ntitle: Fenced\n---\n```\n[[Target]]\n```\n'                 > "$EDGE_DIR/notes/fenced.md"
printf -- '---\ntitle: Target\n---\nlinks [[Target]] (a self-link)\n'       > "$EDGE_DIR/notes/target.md"
printf -- '---\ntitle: axb\n---\nno links here\n'                           > "$EDGE_DIR/notes/axb.md"
printf -- '---\ntitle: a.b\n---\nno links here\n'                           > "$EDGE_DIR/notes/a.b.md"
printf -- '---\ntitle: Lonely\n---\nno links here\n'                        > "$EDGE_DIR/notes/lonely.md"

edges=$(link_edge_map "$EDGE_DIR/notes")

# 1. case folding: alpha, beta (x2 -- plain + alias), gamma, target(self) = 5
assert_eq "5" "$(printf '%s\n' "$edges" | LC_ALL=C awk -F'\t' '$2=="target"' | grep -c .)" \
  "link_edge_map: folds case, resolves alias and anchor to the bare target"

# 2. THE LIVE BUG: a.b must not match axb. A regex-interpolating implementation
#    scores axb an incoming edge it does not have.
assert_eq "0" "$(printf '%s\n' "$edges" | LC_ALL=C awk -F'\t' '$2=="axb"' | grep -c .)" \
  "link_edge_map: a.b does not match axb -- the target is literal, not a regex"
assert_eq "1" "$(printf '%s\n' "$edges" | LC_ALL=C awk -F'\t' '$2=="a.b"' | grep -c .)" \
  "link_edge_map: a.b resolves to itself exactly once"

# 3. fences: the fenced note contributes NO edge
assert_eq "0" "$(printf '%s\n' "$edges" | LC_ALL=C awk -F'\t' '$1=="fenced"' | grep -c .)" \
  "link_edge_map: a link inside a fence is not an edge"

# 4. self-edges ARE present at this layer (Task 2's backlink_counts removes them)
assert_eq "1" "$(printf '%s\n' "$edges" | LC_ALL=C awk -F'\t' '$1=="target" && $2=="target"' | grep -c .)" \
  "link_edge_map: self-edges are emitted here; exclusion belongs to backlink_counts"

# 5. a failure must never be a number
out=$(link_edge_map "$EDGE_DIR/does-not-exist" 2>/dev/null); rc=$?
assert_eq "1" "$rc"  "link_edge_map: missing directory returns 1"
assert_eq ""  "$out" "link_edge_map: missing directory prints NOTHING, not 0"

rm -rf "$EDGE_DIR"
```

- [ ] **Step 2: Run it and watch it fail for the right reason**

```bash
bash reference/test/link-extraction.test.sh 2>&1 | tail -5
```

Expected: failures naming `link_edge_map: command not found`. **If instead it reports `passed=19 failed=0`, the new block was appended after the summary print — move it above.** A test that never runs reports the same green as a passing one.

- [ ] **Step 3: Implement `link_edge_map` and `link_edge_map_recursive`**

Append to `reference/lib/link-extraction.sh`:

```bash
# link_edge_map <dir> -> "<source>\t<target>" per link occurrence, both folded.
# WHY A TAB AND NOT A SPACE: note basenames legitimately contain spaces; a
# space-separated pair cannot be split back apart. awk -F'\t' is the reader.
# Self-edges are emitted here on purpose -- backlink_counts drops them, and a
# caller counting a note's own outbound links needs them present.
link_edge_map() {
  _require_deps_and_dir "$1" || return 1
  local dir="$1" f src stripped
  stripped=$(mktemp) || return 1
  for f in "$dir"/*.md; do
    [ -e "$f" ] || continue
    src=$(basename "$f" .md | _fold_lower)
    if ! _strip_fences "$f" > "$stripped" 2>/dev/null; then
      rm -f "$stripped"; return 1
    fi
    rg -o '\[\[([^\]|#]+)' -r '$1' "$stripped" 2>/dev/null \
      | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
      | _fold_lower \
      | while IFS= read -r tgt; do
          [ -n "$tgt" ] || continue
          printf '%s\t%s\n' "$src" "$tgt"
        done
  done
  rm -f "$stripped"
}

# link_edge_map_recursive <dir> -> same, scanning the whole tree.
link_edge_map_recursive() {
  _require_deps_and_dir "$1" || return 1
  local dir="$1" f src stripped
  stripped=$(mktemp) || return 1
  find "$dir" -type f -name '*.md' -not -path '*/.git/*' | while IFS= read -r f; do
    src=$(basename "$f" .md | _fold_lower)
    if ! _strip_fences "$f" > "$stripped" 2>/dev/null; then
      continue
    fi
    rg -o '\[\[([^\]|#]+)' -r '$1' "$stripped" 2>/dev/null \
      | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
      | _fold_lower \
      | while IFS= read -r tgt; do
          [ -n "$tgt" ] || continue
          printf '%s\t%s\n' "$src" "$tgt"
        done
  done
  rm -f "$stripped"
}
```

- [ ] **Step 4: Bump the version constant**

In `reference/lib/link-extraction.sh` line 53, change `LINK_EXTRACTION_VERSION=2` to `LINK_EXTRACTION_VERSION=3`.

- [ ] **Step 5: Run the tests under BOTH shells**

```bash
bash reference/test/link-extraction.test.sh 2>&1 | tail -3
zsh  reference/test/link-extraction.test.sh 2>&1 | tail -3
```

Expected: both `failed=0`, and the total risen by 6 from 19 to 25.

- [ ] **Step 6: Move the version tables in the same commit**

`skills/setup/SKILL.md` library copy table and `skills/upgrade/SKILL.md` §6a version table both name `link-extraction.sh` with a version. Update both to `3`. Find them:

```bash
grep -n 'LINK_EXTRACTION_VERSION\|link-extraction' skills/setup/SKILL.md skills/upgrade/SKILL.md
```

- [ ] **Step 7: Verify no declared site was left behind**

```bash
grep -rn 'LINK_EXTRACTION_VERSION' reference/ skills/ skill-sources/
```

Expected: the constant at `3`, and every consumer guard still asserting `>= 2` (they are converted in later tasks; a `>= 2` guard against a v3 library passes, which is correct — the guard is a floor).

- [ ] **Step 8: Commit**

```bash
git add reference/lib/link-extraction.sh reference/test/link-extraction.test.sh \
        skills/setup/SKILL.md skills/upgrade/SKILL.md
git commit -m "Add link_edge_map to the link library, v2 -> v3

The library answered directory-scoped questions only, so every caller needing
backlinks re-inlined the same three-stage pipeline -- 7 sites, divergence 13.

Fixture is discriminating rather than illustrative: the a.b/axb pair is the live
regex-injection bug (an interpolated note name is a regex; 3 field-vault notes
are exposed), and the fenced note fails any implementation that skips
_strip_fences. Self-edges are emitted here deliberately; backlink_counts drops
them.

Tab-separated because note basenames legitimately contain spaces.

19 -> 25 assertions, both shells."
```

---

## Task 2: `backlink_counts`

**Files:**
- Modify: `reference/lib/link-extraction.sh`, `reference/test/link-extraction.test.sh`

**Interfaces:**
- Consumes: `link_edge_map`, `link_edge_map_recursive` (Task 1)
- Produces: `backlink_counts <dir>` and `backlink_counts_recursive <dir>` emitting `target<TAB>count`, self-edges excluded, sorted by target under `LC_ALL=C`. A target with zero incoming links does not appear — absence is the zero.

- [ ] **Step 1: Write the failing test**

Append inside the same fixture block created in Task 1, before `rm -rf "$EDGE_DIR"`:

```bash
counts=$(backlink_counts "$EDGE_DIR/notes")

# target has 5 raw edges, ONE of which is its own self-link -> 4
assert_eq "4" "$(printf '%s\n' "$counts" | LC_ALL=C awk -F'\t' '$1=="target"{print $2}')" \
  "backlink_counts: excludes the self-edge (5 raw edges -> 4 incoming)"

# a note with no incoming links is ABSENT, not zero -- absence is the zero
assert_eq "" "$(printf '%s\n' "$counts" | LC_ALL=C awk -F'\t' '$1=="lonely"{print $2}')" \
  "backlink_counts: a target with no incoming links does not appear"

assert_eq "1" "$(printf '%s\n' "$counts" | LC_ALL=C awk -F'\t' '$1=="a.b"{print $2}')" \
  "backlink_counts: a.b counted exactly once, axb not at all"
assert_eq "" "$(printf '%s\n' "$counts" | LC_ALL=C awk -F'\t' '$1=="axb"{print $2}')" \
  "backlink_counts: axb has no incoming links"

out=$(backlink_counts "$EDGE_DIR/does-not-exist" 2>/dev/null); rc=$?
assert_eq "1" "$rc"  "backlink_counts: missing directory returns 1"
assert_eq ""  "$out" "backlink_counts: missing directory prints NOTHING"
```

- [ ] **Step 2: Run and verify it fails**

```bash
bash reference/test/link-extraction.test.sh 2>&1 | tail -5
```

Expected: `backlink_counts: command not found`.

- [ ] **Step 3: Implement**

```bash
# backlink_counts <dir> -> "<target>\t<count>", self-edges excluded.
# A target with zero incoming links is ABSENT, not a zero row: emitting zero
# rows would require knowing the full note set, which is orphan_notes' job.
backlink_counts() {
  link_edge_map "$1" \
    | LC_ALL=C awk -F'\t' '$1 != $2 { print $2 }' \
    | LC_ALL=C sort \
    | uniq -c \
    | LC_ALL=C awk '{ c=$1; $1=""; sub(/^ /,""); printf "%s\t%s\n", $0, c }'
}

backlink_counts_recursive() {
  link_edge_map_recursive "$1" \
    | LC_ALL=C awk -F'\t' '$1 != $2 { print $2 }' \
    | LC_ALL=C sort \
    | uniq -c \
    | LC_ALL=C awk '{ c=$1; $1=""; sub(/^ /,""); printf "%s\t%s\n", $0, c }'
}
```

**Note on error propagation:** `link_edge_map` returning 1 makes the pipeline emit nothing, and the function's exit status is the last stage's. Step 4 verifies the rc is still 1 — if it is not, add `set -o pipefail` guarded for zsh compatibility, or capture the inner rc explicitly.

- [ ] **Step 4: Run under both shells**

```bash
bash reference/test/link-extraction.test.sh 2>&1 | tail -3
zsh  reference/test/link-extraction.test.sh 2>&1 | tail -3
```

Expected: `failed=0`, total 25 → 31. **If the two "missing directory returns 1" assertions fail, the pipeline swallowed the inner return** — fix it before proceeding; a wrong rc here is exactly the silent-failure class.

- [ ] **Step 5: Commit**

```bash
git add reference/lib/link-extraction.sh reference/test/link-extraction.test.sh
git commit -m "Add backlink_counts, built on link_edge_map

Self-edges excluded, preserving the grep -v \"\$f\" behaviour of the sites this
replaces. A target with no incoming links is ABSENT rather than a zero row --
emitting zeros needs the full note set, which is orphan_notes' job.

25 -> 31 assertions, both shells. Two of the six pin that a failure returns 1
and prints nothing, because a pipeline can silently swallow the inner rc."
```

---

## Task 3: `orphan_notes`

**Files:**
- Modify: `reference/lib/link-extraction.sh`, `reference/test/link-extraction.test.sh`

**Interfaces:**
- Consumes: `link_edge_map` (Task 1), `existing_note_index` (pre-existing)
- Produces: `orphan_notes <dir>` and `orphan_notes_recursive <dir>` emitting folded basenames with zero incoming links, one per line, `LC_ALL=C` sorted. Self-links do not rescue a note from orphanhood.

- [ ] **Step 1: Write the failing test**

```bash
orphans=$(orphan_notes "$EDGE_DIR/notes")

assert_eq "1" "$(printf '%s\n' "$orphans" | grep -cx 'lonely')" \
  "orphan_notes: a note with no incoming links is an orphan"
assert_eq "1" "$(printf '%s\n' "$orphans" | grep -cx 'axb')" \
  "orphan_notes: axb IS an orphan -- the a.b link must not rescue it"
assert_eq "0" "$(printf '%s\n' "$orphans" | grep -cx 'target')" \
  "orphan_notes: a linked-to note is not an orphan"
assert_eq "0" "$(printf '%s\n' "$orphans" | grep -cx 'a.b')" \
  "orphan_notes: a.b is linked from alpha, so not an orphan"

# A self-link must NOT rescue a note. `fenced` links only inside a fence and
# nothing links TO it, so it is an orphan.
assert_eq "1" "$(printf '%s\n' "$orphans" | grep -cx 'fenced')" \
  "orphan_notes: a note whose only inbound link is inside a fence is an orphan"

out=$(orphan_notes "$EDGE_DIR/does-not-exist" 2>/dev/null); rc=$?
assert_eq "1" "$rc"  "orphan_notes: missing directory returns 1"
assert_eq ""  "$out" "orphan_notes: missing directory prints NOTHING, not an empty-but-successful list"
```

- [ ] **Step 2: Run and verify it fails**

```bash
bash reference/test/link-extraction.test.sh 2>&1 | tail -5
```

- [ ] **Step 3: Implement as a set difference, not a loop**

```bash
# orphan_notes <dir> -> folded basenames with zero incoming links.
# comm, not a per-note loop: the loop shape is what made the callers O(n^2).
# BOTH inputs pin LC_ALL=C -- comm emits nonsense when its two streams were
# sorted under different collations, and it does so SILENTLY.
orphan_notes() {
  _require_deps_and_dir "$1" || return 1
  local dir="$1" idx tgts
  idx=$(mktemp)  || return 1
  tgts=$(mktemp) || { rm -f "$idx"; return 1; }
  existing_note_index "$dir" | LC_ALL=C sort -u > "$idx"      || { rm -f "$idx" "$tgts"; return 1; }
  link_edge_map "$dir" | LC_ALL=C awk -F'\t' '$1 != $2 { print $2 }' \
    | LC_ALL=C sort -u > "$tgts"                              || { rm -f "$idx" "$tgts"; return 1; }
  LC_ALL=C comm -23 "$idx" "$tgts"
  rm -f "$idx" "$tgts"
}

orphan_notes_recursive() {
  _require_deps_and_dir "$1" || return 1
  local dir="$1" idx tgts
  idx=$(mktemp)  || return 1
  tgts=$(mktemp) || { rm -f "$idx"; return 1; }
  existing_note_index_recursive "$dir" | LC_ALL=C sort -u > "$idx" || { rm -f "$idx" "$tgts"; return 1; }
  link_edge_map_recursive "$dir" | LC_ALL=C awk -F'\t' '$1 != $2 { print $2 }' \
    | LC_ALL=C sort -u > "$tgts"                                   || { rm -f "$idx" "$tgts"; return 1; }
  LC_ALL=C comm -23 "$idx" "$tgts"
  rm -f "$idx" "$tgts"
}
```

- [ ] **Step 4: Run under both shells**

```bash
bash reference/test/link-extraction.test.sh 2>&1 | tail -3
zsh  reference/test/link-extraction.test.sh 2>&1 | tail -3
```

Expected: `failed=0`, total 31 → 38.

- [ ] **Step 5: Mutation-prove the LC_ALL=C pinning, because a green run is not evidence**

Drop `LC_ALL=C` from the `existing_note_index` side only, then re-run. If the suite stays green, the fixture has no name that discriminates collations — **add one** (a basename with a non-ASCII character) rather than accepting the green.

```bash
S=reference/lib/link-extraction.sh; B=$(mktemp); cp $S $B
perl -0pi -e 's/existing_note_index "\$dir" \| LC_ALL=C sort -u/existing_note_index "\$dir" | sort -u/' $S
cmp -s $B $S && echo 'MUTATION DID NOT APPLY - result meaningless' || \
  bash reference/test/link-extraction.test.sh 2>&1 | tail -2
cp $B $S; rm -f $B
```

- [ ] **Step 6: Commit**

```bash
git add reference/lib/link-extraction.sh reference/test/link-extraction.test.sh
git commit -m "Add orphan_notes as a set difference, not a per-note loop

comm -23 over two LC_ALL=C-sorted streams. The loop shape is precisely what made
the callers quadratic, so reproducing it inside the library would move the cost
rather than remove it.

Both comm inputs pin LC_ALL=C. An unpinned side makes comm emit nonsense
SILENTLY -- the same trap the exhaustive-dangling-scan fix documented.

A self-link does not rescue a note from orphanhood, and neither does a link that
only appears inside a fence; both are pinned.

31 -> 38 assertions, both shells."
```

---

## Task 4: Convert `skills/health` (3 sites) and drain its allowlist entry

**Files:**
- Modify: `skills/health/SKILL.md` — sites at `:174` (orphans), `:509` (incoming count), `:562` (MOC count)
- Modify: `reference/check-portability.sh` — delete the `skills/health/SKILL.md 3 …` line from `INTERP_ALLOW`

**Interfaces:**
- Consumes: `orphan_notes_recursive`, `backlink_counts` (Tasks 1–3)
- Produces: nothing other tasks read.

**The allowlist drain MUST be in this task, not a later one.** Check 6 is bidirectional: a listed site that starts passing fails the gate. Converting without draining turns CI red at this commit.

- [ ] **Step 1: Re-derive the line numbers before editing**

```bash
grep -n 'rg -l' skills/health/SKILL.md
```

CLAUDE.md's divergence-12 table cites `:132, :467, :520, :543` — those are **stale by +42**. Trust this command, not the table.

- [ ] **Step 2: Record the before-numbers against the field vault**

```bash
cd ~/second-brain && bash -c '
. ops/lib/link-extraction.sh 2>/dev/null || . /Volumes/Containers/arscontexta/reference/lib/link-extraction.sh
echo "orphans(before-scope: whole vault): $(orphan_notes_recursive . | grep -c .)"
echo "orphans(notes dir only):            $(orphan_notes nodes | grep -c .)"'
```

**Write both numbers into the commit message.** `:174` currently scans the *whole vault* (`rg -l … --glob '*.md'`, no directory); `:562` scans the notes directory. Converting `:174` to the notes directory would silently change the reported orphan count. Preserve the whole-vault scope with `orphan_notes_recursive`, and if you deliberately narrow it, state the delta.

- [ ] **Step 3: Replace the orphan loop at `:174`**

```bash
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

# Scope is the WHOLE VAULT, matching what the rg -l line it replaces scanned.
orphan_notes_recursive "$VAULT_ROOT" | while IFS= read -r n; do
  echo "WARN: $n — no incoming links (orphan)"
done
```

- [ ] **Step 4: Replace the incoming-count site at `:509` and the MOC site at `:562`**

Both read one pre-aggregated table instead of scanning per note. Each fence needs its own library stanza — fences are separate shell invocations, so a `.`-source in an earlier fence is not in scope here.

```bash
# (library stanza as in Step 3, repeated -- fences do not share state)

COUNTS=$(mktemp)
backlink_counts "{vocabulary.notes}" > "$COUNTS"

for f in {vocabulary.notes}/*.md; do
  [ -e "$f" ] || continue
  b=$(basename "$f" .md | tr '[:upper:]' '[:lower:]')
  incoming=$(LC_ALL=C awk -F'\t' -v n="$b" '$1==n{print $2}' "$COUNTS")
  incoming=${incoming:-0}
  # ... existing threshold logic, unchanged ...
done
rm -f "$COUNTS"
```

- [ ] **Step 5: Drain the allowlist entry**

Delete this exact line from `INTERP_ALLOW` in `reference/check-portability.sh`:

```
skills/health/SKILL.md 3 orphan, incoming and MOC counts; report-only, no threshold reads them
```

- [ ] **Step 6: Verify both the gate and the fences**

```bash
bash reference/check-portability.sh 2>&1 | tail -3     # expect "4 interpolated matcher(s) across 4"
bash reference/test/fence-isolation.test.sh 2>&1 | tail -3
zsh  reference/test/fence-isolation.test.sh 2>&1 | tail -3
```

Expected: portability PASS with the interpolated count down 7 → 4; fence gate PASS in both shells.

- [ ] **Step 7: Mutation-prove each new fence actually sources the library**

For each converted fence, delete its `.` `"$LINK_LIB"` line and confirm the fence gate reddens naming that fence, then restore. A fence that does not source the library but still passes is reading a stale global.

- [ ] **Step 8: Commit**

```bash
git add skills/health/SKILL.md reference/check-portability.sh
git commit -m "Convert health's three matcher sites to the link library

Was three per-note full-corpus scans. Measured on the field vault: 58ms/note x
2686 = ~157s per loop, ~471s for the three, growing as n^2. One pass is ~0.29s.

Two defects, one fix. The scans also interpolated a note name into a regex, so a
note called a.b matched axb -- 3 field-vault basenames carry regex
metacharacters and were returning wrong counts with exit 0.

SCOPE PRESERVED DELIBERATELY: the orphan site scanned the WHOLE VAULT (rg -l with
no directory) while the MOC site scanned the notes directory. Converted to
orphan_notes_recursive and backlink_counts respectively so neither reported
number moves. Before-numbers are in the plan's Step 2 output.

Check 6's allowlist entry drained in the same commit -- the list is
bidirectional, so a converted-but-still-listed site fails the gate."
```

---

## Task 5: Convert `skills/architect` and drain its entry

**Files:**
- Modify: `skills/architect/SKILL.md:179`
- Modify: `reference/check-portability.sh` — delete the `skills/architect/SKILL.md 1 …` line

**Interfaces:**
- Consumes: `backlink_counts` (Task 2)

- [ ] **Step 1: Re-derive the line and read its current scope**

```bash
grep -n 'grep -rl' skills/architect/SKILL.md
sed -n '175,185p' skills/architect/SKILL.md
```

- [ ] **Step 2: Replace with a library read**

Use the same library stanza as Task 4 Step 3, then read `backlink_counts` for the counts the site currently computes per note. Preserve whatever directory the `grep -rl` scanned.

- [ ] **Step 3: Drain the allowlist entry**

Delete from `INTERP_ALLOW`:

```
skills/architect/SKILL.md 1 link counts in evolution advice; nothing acts on the number
```

- [ ] **Step 4: Verify**

```bash
bash reference/check-portability.sh 2>&1 | tail -3      # expect "3 interpolated matcher(s) across 3"
bash reference/test/fence-isolation.test.sh 2>&1 | tail -3
zsh  reference/test/fence-isolation.test.sh 2>&1 | tail -3
```

- [ ] **Step 5: Commit**

```bash
git add skills/architect/SKILL.md reference/check-portability.sh
git commit -m "Convert architect's link-count matcher to the library

Same interpolated-regex defect as health's three, in the site that feeds
evolution advice. Allowlist entry drained in the same commit."
```

---

## Task 6: Convert the 7 divergence-13 extraction sites

**Files:**
- Modify: `skill-sources/graph/SKILL.md` (4 sites), `skill-sources/reflect/SKILL.md` (1), `skill-sources/reweave/SKILL.md` (1), `skill-sources/stats/SKILL.md` (1)

**Interfaces:**
- Consumes: `link_edge_map`, `backlink_counts`, `orphan_notes` (Tasks 1–3)

- [ ] **Step 1: Re-derive the exact site list**

```bash
grep -rnF "rg -o '\[\[([^" skill-sources/ skills/
```

Expected 7 hits. `-F` is load-bearing: without it the `[^` opens a bracket expression and the command returns 2 — a wrong answer that looks like a plausible count.

- [ ] **Step 2: Convert each, one commit per file**

Each fence gets the library stanza from Task 4 Step 3 (with the `>= 3` guard), then replaces its inlined `_strip_fences | rg -o | _fold_lower` chain with the matching library call:

| what the site computes | call |
|---|---|
| in-degree / authority ranking | `link_edge_map` piped to an `awk` tally |
| "which notes link to X" | `backlink_counts` |
| orphan set | `orphan_notes` |
| triangles / backward links | `link_edge_map` |

- [ ] **Step 3: After each file, run the fence gate in both shells**

```bash
bash reference/test/fence-isolation.test.sh 2>&1 | tail -3
zsh  reference/test/fence-isolation.test.sh 2>&1 | tail -3
```

- [ ] **Step 4: Verify the class is empty in these trees**

```bash
grep -rnF "rg -o '\[\[([^" skill-sources/ skills/ | wc -l    # expect 0
grep -rnF "rg -o '\[\[' "   skill-sources/ skills/ | wc -l    # expect 2, UNCHANGED
```

The second command must still return **2**. Those are `graph:569` and `stats:397`, which *count brackets* rather than capture targets — a different operation, correctly out of scope. If that number moved, a bracket counter was converted by mistake.

- [ ] **Step 5: Commit (one per file, message names the site count)**

---

## Task 7: Convert the SessionStart hook template

**Files:**
- Modify: `platforms/claude-code/hooks/session-orient.sh.template:160`
- Modify: `reference/check-portability.sh` — delete the template's `INTERP_ALLOW` line

**Isolated as its own task deliberately.** It runs on **every** SessionStart in every vault the plugin is installed in. A reviewer should be able to reject this while approving Tasks 4–6.

- [ ] **Step 1: Read the site and its neighbours**

```bash
grep -n 'grep -rl' platforms/claude-code/hooks/session-orient.sh.template
grep -n 'SESS_COUNT\|INBOX_COUNT' platforms/claude-code/hooks/session-orient.sh.template
```

**The `SESS_COUNT`/`INBOX_COUNT` cross-references installed by divergence 3 must survive this edit.** Those values are declared in two places and the cross-reference is the only thing stopping an edit to one from silently splitting them.

- [ ] **Step 2: Convert with the SessionStart contract, NOT the skill contract**

This is the one converted site that must **not** exit. Copy the precedent from `hooks/scripts/session-orient.sh`:

```bash
LINK_LIB="$VAULT_ROOT/ops/lib/link-extraction.sh"
if [ -r "$LINK_LIB" ] && . "$LINK_LIB" 2>/dev/null \
   && [ "${LINK_EXTRACTION_VERSION:-0}" -ge 3 ]; then
  ORPHANS=$(orphan_notes_recursive "$VAULT_ROOT" | grep -c .)
  printf 'Orphan notes: %s\n' "$ORPHANS"
else
  # DELIBERATELY NOT exit 1, and DELIBERATELY NOT 0.
  # This is a SessionStart hook: exiting turns a missing library into a broken
  # session. Substituting 0 is worse than omitting -- 0 is exactly the value
  # that stops a threshold from ever firing, invisibly. An omitted line is
  # visible. Precedent: hooks/scripts/session-orient.sh, divergences 7-9.
  echo "warning: link-extraction library unavailable; orphan signal omitted" >&2
fi
```

- [ ] **Step 3: Verify the three failure modes by hand**

The hook gate cannot construct these; check each directly.

| condition | required behaviour |
|---|---|
| library present, v3 | prints the orphan line |
| library absent | warns on stderr, **omits** the line, exits 0 |
| library present but v2 | warns on stderr, **omits** the line, exits 0 |

```bash
bash reference/test/hook-config.test.sh 2>&1 | tail -2
zsh  reference/test/hook-config.test.sh 2>&1 | tail -2
```

- [ ] **Step 4: Drain the allowlist entry and verify**

```bash
bash reference/check-portability.sh 2>&1 | tail -3     # expect "2 interpolated matcher(s) across 2"
```

The remaining 2 are `reference/testing-milestones.md` (a test spec) and `generators/features/maintenance.md` (a recipe) — both blocked for stated reasons, not skipped.

- [ ] **Step 5: Commit**

```bash
git add platforms/claude-code/hooks/session-orient.sh.template reference/check-portability.sh
git commit -m "Convert the SessionStart hook template to the link library

The highest-blast-radius site in the class: it runs on every SessionStart in
every vault the plugin is installed in.

It gets the SessionStart contract, not the skill contract -- warn on stderr and
OMIT the signal, never exit 1 and never substitute 0. Exiting turns a missing
library into a broken session; a substituted 0 is precisely the value that stops
a threshold from ever firing, and it does so invisibly, where an omitted line is
visible. Precedent: hooks/scripts/session-orient.sh, divergences 7-9.

Divergence 3's SESS_COUNT/INBOX_COUNT cross-references preserved verbatim -- they
are the only thing stopping the two declarations from silently splitting.

Check 6 down to 2: testing-milestones (a test spec) and maintenance.md (a recipe
that cannot source a library). Both blocked for stated reasons, not skipped."
```

---

## Task 8: Update CLAUDE.md's divergence entries

**Files:**
- Modify: `CLAUDE.md` — divergences 12 and 13

- [ ] **Step 1: Re-derive every number before writing one**

```bash
/usr/bin/grep -rnE '(grep|rg)[^|]*\\\[\\\[.*\\\]\\\]' \
    skill-sources/ skills/ platforms/claude-code/ reference/ \
  | /usr/bin/grep -Ev 'reference/+(check-portability\.sh|test/guard-failure\.test\.sh):'
grep -rnF "rg -o '\[\[([^" skill-sources/ skills/ | wc -l
bash reference/check-portability.sh 2>&1 | grep interpolated
```

- [ ] **Step 2: Rewrite divergence 13 as closed-within-scope, not closed**

`maintenance.md:29` is an eighth site of that class, outside divergence 13's published search (which scans `skill-sources/` and `skills/` only). State the scope with the count, or the entry claims more than it delivers.

- [ ] **Step 3: Update divergence 12's table and its line numbers**

Re-derive **every** row, not only the health ones. `reference/testing-milestones.md` is at `:425`; CLAUDE.md still says `:410`.

- [ ] **Step 4: Run the doc gate**

```bash
bash reference/check-doc-claims.sh 2>&1 | tail -3     # ~100s
```

- [ ] **Step 5: Commit**

---

## Self-Review

**Spec coverage.** Item 2's every element maps to a task: the three functions (1–3), the five matcher conversions (4, 5, 7), the seven extraction conversions (6), the allowlist drain (4, 5, 7 — folded into the tasks that create the need), the version bump and its tables (1), the correctness fixture (1–3), the scope-preservation requirement (4, Step 2). The `LINK_LIB` spelling decision is in Global Constraints.

**Not covered, deliberately:** the spec's `<dir>...` variadic signature, replaced by the house flat/`_recursive` pattern with the reason stated above.

**Type consistency.** `link_edge_map` emits `source<TAB>target` in Task 1 and is read as `-F'\t'` with `$1`/`$2` in Tasks 2, 3, 4, 6. `backlink_counts` emits `target<TAB>count` in Task 2 and is read as `$1`/`$2` in Task 4. `orphan_notes` emits bare basenames in Task 3 and is read line-wise in Tasks 4 and 7. Version floor is `>= 3` in every consumer stanza.

**Placeholder scan.** No TBDs. Every code step carries the actual code. Task 5 Step 2 and Task 6 Step 2 describe a transformation against a table rather than quoting final code, because the target lines must be re-derived first (their numbers are known-stale) — each carries the exact stanza to insert and the exact call to use.

---

## Deferrals

Each names its entry in **`docs/superpowers/deferrals.md`** rather than restating it.
That file carries the reason and the reopening trigger; this section carries only what
this plan chose not to do. A deferral restated in two places drifts in one of them.

| what this plan defers | ledger entry |
|---|---|
| `generators/features/maintenance.md` — both its `:20` matcher and its `:29` extraction | **1** |
| `reference/testing-milestones.md:425` | **2** |
| `skill-sources/next:261`'s bare-relative `LINK_LIB` spelling | **3** |
| the materialized backlink cache | **4** |

**Not deferred, and not a deferral:** `skills/health`'s 4th matcher hit takes no note
title, tests MOC list shape rather than a backlink, and already carries
`portability-exempt`. It is *correctly outside the class* — there is nothing to defer.
Listing it as a deferral would imply work someone might one day do.
