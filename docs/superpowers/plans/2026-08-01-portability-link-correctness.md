# Portability and Link Correctness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove all nine `grep -P` invocations from shipped skill templates, correct wiki-link target extraction at all twelve sites, and add a shared library, guard, and CI so the bug class cannot silently return.

**Architecture:** Twelve bash sites across five files extract wiki links. Nine use `grep -P`, which does not exist on BSD grep (macOS default) and fails silently to `0`. The logic is extracted **once** into `reference/lib/link-extraction.sh`; every consumer sources it and fails loud if it is missing. A guard script written first fails against the current tree, then each fix turns it green — the guard is the failing test.

**Tech Stack:** Bash, `awk` (POSIX), `ripgrep`, GitHub Actions. No new language runtimes.

## Global Constraints

- **Never use `grep -P`.** Fails on BSD grep with `invalid option -- P`, exit 2.
- **Never introduce `python3`.** Not a declared prerequisite; zero occurrences under `skill-sources/`. `awk` is POSIX-mandated and is the approved alternative.
- **The extraction logic lives in exactly one place** — `reference/lib/link-extraction.sh`. Do not inline a copy anywhere. Verbatim duplication was explicitly rejected.
- **Sourcing the library must fail loud**, never fall back silently. A silent fallback reintroduces the failure class this plan removes.
- **All counted variables must hold bare integers**, never labelled strings. `total: 2` breaks the numeric comparison at `skill-sources/stats/SKILL.md:276`.
- **Verification must invoke `/usr/bin/grep` explicitly.** Claude Code's Bash tool aliases `grep` to ugrep (which supports `-P`), producing a false pass.
- **Case comparison folds both sides against an index.** `[ -f "$DIR/$NAME.md" ]` delegates half the comparison to the filesystem and is filesystem-dependent (case-insensitive APFS, case-sensitive Linux).
- **Do not modify `platforms/shared/skill-blocks/`.** Verified vestigial, outside the generation path.
- **Do not "fix" `tree -P`** at `platforms/claude-code/hooks/session-orient.sh.template:74`. Different tool, legitimate flag.
- **Shell arrays, not space-joined strings**, for multi-path variables. `SCAN="a b c"` + unquoted `$SCAN` word-splits in bash but NOT zsh, silently yielding zero results.
- Branch: `fix/portability-link-correctness`. Target: PR to `upstream` (`agenticnotetaking/arscontexta`).

## The Twelve Sites

| File | Lines | Form |
|---|---|---|
| `skill-sources/stats/SKILL.md` | 68, 183 | A (count) |
| `skill-sources/stats/SKILL.md` | 78, 102 | B (resolve) |
| `skill-sources/graph/SKILL.md` | 69, 308 | A (count) |
| `skill-sources/graph/SKILL.md` | 84, 151 | B (resolve) |
| `skills/architect/SKILL.md` | 180 | B (resolve) |
| `reference/validate-kernel.sh` | 57, 67, 75, 85 | B (resolve, adapted) |
| `skills/health/SKILL.md` | 167 | B (resolve) |

## Shared Test Fixture

Every task uses this. Throwaway — create in a temp dir, never commit.

```bash
FIX=$(mktemp -d); mkdir -p "$FIX/notes"
printf -- '---\ntitle: real\ncreated: 2026-08-01\n---\nbody\n' > "$FIX/notes/real.md"
printf -- '---\ntitle: alpha\ncreated: 2026-08-01\n---\nbody\n' > "$FIX/notes/alpha.md"
cat > "$FIX/notes/probe.md" <<'EOF'
---
title: probe
created: 2026-08-01
topics:
  - "[[real]]"
  - "[[Alpha|display name]]"
---
Plain: [[real]]
Alias: [[real|some alias]]
Anchor: [[real#a-heading]]
Both:  [[real|alias#frag]]
Case:  [[Alpha]]
Ghost: [[nonexistent-note]]
```
[[in-code-fence]]
```
EOF
echo "$FIX"
```

| Metric | Correct value | Reasoning |
|---|---|---|
| `count_links notes` | `8` | 2 frontmatter `topics:` links + 6 body links; the fenced one excluded (9 raw `[[` − 1) |
| `extract_link_targets notes` | `alpha`, `nonexistent-note`, `real` | folded, terminated, fence-stripped |
| Dangling | `1` | `nonexistent-note` only |

**`topics:` links count toward link totals, and that is correct.** The original
`grep -ohP '\[\[[^\]]+\]\]'` scanned whole files including YAML frontmatter, and `topics:`
entries are real graph edges (note → hub). An earlier draft of this plan said `6`, having
counted only body links; that expectation was wrong, not the code.

## File Structure

| File | Responsibility |
|---|---|
| `reference/lib/link-extraction.sh` | **New.** Sole definition of link counting/extraction. Three functions. |
| `reference/check-portability.sh` | **New.** Guard: fails on `grep -P`, on naive capture, and on inline duplication of the library logic. |
| `.github/workflows/checks.yml` | **New.** Repo's first CI. |
| `skill-sources/stats/SKILL.md` | 4 sites → source library |
| `skill-sources/graph/SKILL.md` | 4 sites → source library |
| `skills/architect/SKILL.md` | 1 site → source library |
| `skills/health/SKILL.md` | 1 site → source library |
| `reference/validate-kernel.sh` | 4 lines → source library by relative path |
| `README.md` | Add `awk` prerequisite (Task 1, before first use) |

---

### Task 1: Guard script (RED) + `awk` prerequisite

**Files:**
- Create: `reference/check-portability.sh`
- Modify: `README.md` (prerequisite table)

**Interfaces:**
- Consumes: nothing.
- Produces: executable `reference/check-portability.sh [root]`. Exit `0` clean, `1` violations. Tasks 3–5 run it to confirm progress; Task 6 wires it into CI.

- [ ] **Step 1: Write the guard**

```bash
#!/bin/bash
# check-portability.sh — fail on shell constructs that break outside GNU userland.
#
# WHY $GREP IS /usr/bin/grep AND NOT `grep`:
# Claude Code's Bash tool aliases `grep` to a ugrep wrapper, which DOES support -P.
# Running these checks with bare `grep` makes them pass while the bug ships to users.
#
# WHY SCAN IS AN ARRAY:
# A space-joined string with unquoted $SCAN word-splits in bash but NOT in zsh,
# where it becomes one nonexistent path — and with 2>/dev/null that is a silent 0,
# i.e. the guard passes while every bug ships. Verified: bash 9 hits, zsh 0.

set -u
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
GREP=/usr/bin/grep
fail=0

red() { printf '  FAIL %s\n' "$1"; fail=1; }
ok()  { printf '  PASS %s\n' "$1"; }

SCAN=("$ROOT/skills" "$ROOT/skill-sources" "$ROOT/reference")

echo "=== Portability check: $ROOT ==="

echo "1. No PCRE grep (-P) in shipped templates"
# --exclude the guard's own source: its search pattern necessarily CONTAINS the
# construct it searches for, so without this it self-flags 3 times (12 hits, not
# the 9 real defects). Found during implementation; the count in an earlier draft
# of this plan was computed before the guard existed and was therefore wrong.
hits=$("$GREP" -rn --include='*.md' --include='*.sh' --exclude='check-portability.sh' \
  -E '(^|[^a-zA-Z_-])grep +[^|]*-[a-zA-Z]*P' \
  "${SCAN[@]}" 2>/dev/null || true)
if [ -n "$hits" ]; then
  red "grep -P found (exits 2 on BSD grep, silently yields 0):"
  printf '%s\n' "$hits" | sed 's/^/       /'
else
  ok "no grep -P"
fi

echo "2. Wiki-link capture terminates at | and #"
hits=$("$GREP" -rn --include='*.md' --include='*.sh' -F '\[\[' "${SCAN[@]}" 2>/dev/null \
  | "$GREP" -F '[^' | "$GREP" -v -F '|#' \
  | "$GREP" -v 'lib/link-extraction.sh' || true)
if [ -n "$hits" ]; then
  red "link capture does not exclude | and # (counts [[a|b]] and [[a#c]] as dangling):"
  printf '%s\n' "$hits" | sed 's/^/       /'
else
  ok "link capture terminates correctly"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "PORTABILITY: PASS"; exit 0
else
  echo "PORTABILITY: FAIL"; exit 1
fi
```

- [ ] **Step 2: Make executable and run — verify it FAILS**

```bash
chmod +x reference/check-portability.sh
bash reference/check-portability.sh; echo "exit=$?"
```

Expected: `PORTABILITY: FAIL`, `exit=1`, with **exactly**:
- Check 1: **9** hits — `stats` 68/78/102/183, `graph` 69/84/151/308, `architect` 180.
- Check 2: **12** hits — those 9 plus `validate-kernel.sh` 67/75 and `skills/health/SKILL.md:167`.

**If it reports PASS, the guard is broken — stop and fix it.** A guard never seen red is not known to work.

**If check 1 reports 0**, you hit the word-splitting trap: run with `bash` explicitly and compare. This exact failure occurred during planning.

- [ ] **Step 3: Verify it does NOT flag `tree -P`**

```bash
bash reference/check-portability.sh 2>&1 | /usr/bin/grep -c 'session-orient'
```

Expected: `0`. Non-zero means check 1's regex is over-broad and would break working code.

- [ ] **Step 4: Declare the `awk` prerequisite**

Add to the README prerequisite table, alongside `tree` and `ripgrep`:

```markdown
| `awk` | Yes | Code-fence stripping in link extraction (POSIX; preinstalled on macOS and Linux) |
```

Declared here, before Task 2 introduces the dependency.

- [ ] **Step 5: Commit**

```bash
git add reference/check-portability.sh README.md
git commit -m "Add portability guard (currently failing); declare awk prerequisite

Fails on grep -P and non-terminating wiki-link capture. Invokes
/usr/bin/grep explicitly because Claude Code's shell aliases grep to
ugrep, which supports -P and produces a false pass.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Shared library `reference/lib/link-extraction.sh`

**Files:**
- Create: `reference/lib/link-extraction.sh`

**Interfaces:**
- Consumes: nothing.
- Produces three functions, sourced by Tasks 3–5:
  - `count_links <dir>` → integer on stdout. Fence-aware occurrence count.
  - `extract_link_targets <dir>` → newline-separated targets: fence-stripped, terminated at `|`/`#`, trimmed, lowercase-folded, sorted-unique.
  - `existing_note_index <dir>` → newline-separated lowercase-folded basenames of `*.md`.

- [ ] **Step 1: Write the library**

```bash
#!/bin/bash
# link-extraction.sh — the single definition of wiki-link counting and resolution.
#
# Sourced by skill templates and by validate-kernel.sh. Do NOT inline copies of
# these functions anywhere; check-portability.sh enforces that.
#
# Correctness requirements encoded here:
#   1. No `grep -P` — absent from BSD grep, and it fails silently to 0.
#   2. Fenced code blocks are not edges — ``` examples must not count as links.
#   3. Targets terminate at `|` and `#` — [[slug|alias]] and [[slug#head]] resolve
#      to `slug`, not to the whole string.
#   4. Case folds on BOTH sides — [ -f ] alone delegates to the filesystem, which
#      is case-insensitive on macOS APFS and case-sensitive on Linux, so identical
#      content yields different answers per platform.

# Strip fenced code blocks from one file, emit remaining lines.
_strip_fences() {
  awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$1"
}

# count_links <dir> -> integer
count_links() {
  local dir="$1" f
  local n=0
  for f in "$dir"/*.md; do
    [ -e "$f" ] || continue
    n=$(( n + $(_strip_fences "$f" | rg -o '\[\[' 2>/dev/null | wc -l | tr -d ' ') ))
  done
  printf '%s' "$n"
}

# extract_link_targets <dir> -> newline-separated folded unique targets
extract_link_targets() {
  local dir="$1" f
  for f in "$dir"/*.md; do
    [ -e "$f" ] || continue
    _strip_fences "$f"
  done | rg -o '\[\[([^\]|#]+)' -r '$1' 2>/dev/null \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | tr '[:upper:]' '[:lower:]' | sort -u
}

# existing_note_index <dir> -> newline-separated folded basenames
existing_note_index() {
  local dir="$1" p
  for p in "$dir"/*.md; do
    [ -e "$p" ] || continue
    basename "$p" .md
  done | tr '[:upper:]' '[:lower:]' | sort -u
}
```

- [ ] **Step 2: Build the fixture and test all three functions**

Create the fixture from **Shared Test Fixture**, then:

```bash
. reference/lib/link-extraction.sh
cd "$FIX"
echo "count_links       -> $(count_links notes)          [expect 6]"
echo "extract_targets   -> $(extract_link_targets notes | tr '\n' ' ')  [expect: alpha nonexistent-note real]"
echo "existing_index    -> $(existing_note_index notes | tr '\n' ' ')   [expect: alpha probe real]"
```

All three must match. If `count_links` returns `0`, `rg` is missing or the fence stripper is wrong.

- [ ] **Step 3: Test the dangling composition and the empty-dir edge case**

```bash
IDX=$(existing_note_index notes)
DANG=$(extract_link_targets notes | while read -r n; do
  [ -n "$n" ] && ! printf '%s\n' "$IDX" | /usr/bin/grep -qxF "$n" && echo "$n"
done)
echo "dangling -> $DANG   [expect: nonexistent-note]"
echo "count    -> $(printf '%s\n' "$DANG" | sed '/^$/d' | wc -l | tr -d ' ')   [expect 1]"

mkdir -p /tmp/emptyvault
echo "empty count -> $(count_links /tmp/emptyvault)   [expect 0, no error]"
```

The empty case must return `0` and must not emit a glob-literal error.

- [ ] **Step 4: Verify case folding is filesystem-independent**

```bash
mv notes/alpha.md notes/Alpha.md
printf '%s\n' "$(existing_note_index notes)" | /usr/bin/grep -qxF alpha && echo "PASS: resolves regardless of file case"
mv notes/Alpha.md notes/alpha.md
```

Expected: `PASS`. This is the check the one-sided `[ -f ]` form fails on Linux while appearing to pass on macOS.

- [ ] **Step 5: Commit**

```bash
git add reference/lib/link-extraction.sh
git commit -m "Add shared link-extraction library

Single definition of link counting and resolution: fence-aware, terminates
targets at | and #, folds case on both sides. Replaces per-site duplication.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Fix `skill-sources/stats/SKILL.md` (4 sites)

**Files:**
- Modify: `skill-sources/stats/SKILL.md:68`, `:78`, `:102`, `:183`

**Interfaces:**
- Consumes: `count_links`, `extract_link_targets`, `existing_note_index` from Task 2.
- Produces: `LINK_COUNT`, `TOPIC_COUNT`, `DANGLING_COUNT`, `THIS_WEEK_LINKS` — all bare integers. `DANGLING_COUNT` is consumed at `:276` by a numeric `-gt` and rendered at `:244`.

- [ ] **Step 1: Confirm the current failure**

```bash
cd "$FIX" && /usr/bin/grep -ohP '\[\[[^\]]+\]\]' notes/*.md 2>/dev/null | wc -l | tr -d ' '
```

Expected: `0` — the silent failure being fixed.

- [ ] **Step 2: Add the loud library source at the top of the first bash block**

Insert immediately after `NOTES_DIR="{vocabulary.notes}"` at `:60`:

```bash
LINK_LIB="${CLAUDE_PLUGIN_ROOT:-}/reference/lib/link-extraction.sh"
if [ -r "$LINK_LIB" ]; then
  . "$LINK_LIB"
else
  echo "error: link-extraction library not found at '$LINK_LIB'" >&2
  echo "       is the arscontexta plugin installed and CLAUDE_PLUGIN_ROOT set?" >&2
  exit 1
fi
```

Do not add a silent fallback. Absent library must stop the block.

- [ ] **Step 3: Fix `:68` — LINK_COUNT**

Replace:

```bash
LINK_COUNT=$(grep -ohP '\[\[[^\]]+\]\]' "$NOTES_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
```

With:

```bash
LINK_COUNT=$(count_links "$NOTES_DIR")
```

- [ ] **Step 4: Fix `:78` — TOPIC_COUNT**

Topics live in YAML frontmatter, never inside fences, and need the quoted-list pattern. Replace:

```bash
TOPIC_COUNT=$(grep -ohP '^\s*-\s*"\[\[([^\]]+)\]\]"' "$NOTES_DIR"/*.md 2>/dev/null | sort -u | wc -l | tr -d ' ')
```

With:

```bash
TOPIC_COUNT=$(rg -oN --no-filename '^\s*-\s*"\[\[([^\]|#]+)' -r '$1' "$NOTES_DIR"/*.md 2>/dev/null \
  | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
  | tr '[:upper:]' '[:lower:]' | sort -u | wc -l | tr -d ' ')
```

- [ ] **Step 5: Fix `:102` — DANGLING_COUNT**

Replace lines 101–105:

```bash
# Dangling link count
DANGLING_COUNT=$(grep -ohP '\[\[([^\]]+)\]\]' "$NOTES_DIR"/*.md 2>/dev/null | sort -u | while read -r link; do
  NAME=$(echo "$link" | sed 's/\[\[//;s/\]\]//')
  [[ ! -f "$NOTES_DIR/$NAME.md" ]] && echo "$NAME"
done | wc -l | tr -d ' ')
```

With:

```bash
# Dangling link count (folded on both sides — see reference/lib/link-extraction.sh)
NOTE_INDEX=$(existing_note_index "$NOTES_DIR")
DANGLING_COUNT=$(extract_link_targets "$NOTES_DIR" | while read -r NAME; do
  [ -n "$NAME" ] && ! printf '%s\n' "$NOTE_INDEX" | grep -qxF "$NAME" && echo "$NAME"
done | wc -l | tr -d ' ')
```

- [ ] **Step 6: Fix `:183` — THIS_WEEK_LINKS**

This counts links in one file at a time, so it uses the fence stripper directly. Replace:

```bash
    [[ "$CREATED" > "$WEEK_AGO" || "$CREATED" == "$WEEK_AGO" ]] && grep -oP '\[\[[^\]]+\]\]' "$f" 2>/dev/null
```

With:

```bash
    [[ "$CREATED" > "$WEEK_AGO" || "$CREATED" == "$WEEK_AGO" ]] && \
      awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$f" | rg -o '\[\['
```

- [ ] **Step 7: Verify against the fixture**

Extract each block and run with `NOTES_DIR=notes` inside `$FIX`, with `CLAUDE_PLUGIN_ROOT` set to the repo root. Assert `LINK_COUNT`=`8`, `TOPIC_COUNT`=`2`, `DANGLING_COUNT`=`1`, `THIS_WEEK_LINKS`=`8`. Then:

```bash
[ "$DANGLING_COUNT" -gt 0 ] && echo "numeric OK"
```

Expected `numeric OK`, no `integer expression expected`.

- [ ] **Step 8: Verify the loud failure path**

```bash
( unset CLAUDE_PLUGIN_ROOT; bash -c '<paste the source guard>' ) 2>&1 | head -2
```

Expected: the two-line error, non-zero exit. Silence or a `0` count means the guard is wrong.

- [ ] **Step 9: Run the portability guard**

```bash
bash reference/check-portability.sh 2>&1 | /usr/bin/grep -c 'stats/SKILL.md'
```

Expected `0`. Guard still exits 1 overall (graph, architect, validate-kernel, health remain).

- [ ] **Step 10: Commit**

```bash
git add skill-sources/stats/SKILL.md
git commit -m "Fix grep -P and link capture in stats skill

Four sites returned 0 on macOS: BSD grep rejects -P and stderr was
suppressed. Now sources the shared library; dangling folds case on both
sides against an index rather than relying on filesystem semantics.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Fix `skill-sources/graph/SKILL.md` (4 sites)

**Files:**
- Modify: `skill-sources/graph/SKILL.md:69`, `:84`, `:151`, `:308`

**Interfaces:**
- Consumes: library functions from Task 2; the loud source block from Task 3 Step 2 (same text).
- Produces: `LINK_COUNT` (integer), `DANGLING:` lines, `LINKS` (folded targets), `OUTGOING` (integer).

- [ ] **Step 1: Add the loud library source**

Insert after `NOTES_DIR="{vocabulary.notes}"` at `:63`, using the same block as Task 3 Step 2.

- [ ] **Step 2: Fix `:69` — LINK_COUNT**

Replace:

```bash
LINK_COUNT=$(grep -ohP '\[\[[^\]]+\]\]' "$NOTES_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
```

With:

```bash
LINK_COUNT=$(count_links "$NOTES_DIR")
```

- [ ] **Step 3: Fix `:84` — dangling report**

Replace lines 83–87:

```bash
# Find dangling links (links to non-existent files)
grep -ohP '\[\[([^\]]+)\]\]' "$NOTES_DIR"/*.md 2>/dev/null | sort -u | while read -r link; do
  NAME=$(echo "$link" | sed 's/\[\[//;s/\]\]//')
  [[ ! -f "$NOTES_DIR/$NAME.md" ]] && echo "DANGLING: $NAME"
done
```

With:

```bash
# Find dangling links (links to non-existent files)
NOTE_INDEX=$(existing_note_index "$NOTES_DIR")
extract_link_targets "$NOTES_DIR" | while read -r NAME; do
  [ -n "$NAME" ] && ! printf '%s\n' "$NOTE_INDEX" | grep -qxF "$NAME" && echo "DANGLING: $NAME"
done
```

- [ ] **Step 4: Fix `:151` — per-note outgoing targets**

Single file, so use the fence stripper directly. Replace:

```bash
  LINKS=$(grep -oP '\[\[([^\]]+)\]\]' "$f" 2>/dev/null | sed 's/\[\[//;s/\]\]//' | sort -u)
```

With:

```bash
  LINKS=$(awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$f" \
    | rg -o '\[\[([^\]|#]+)' -r '$1' \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | tr '[:upper:]' '[:lower:]' | sort -u)
```

- [ ] **Step 5: Fix `:308` — OUTGOING**

Replace:

```bash
  OUTGOING=$(grep -oP '\[\[[^\]]+\]\]' "$f" 2>/dev/null | wc -l | tr -d ' ')
```

With:

```bash
  OUTGOING=$(awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$f" \
    | rg -o '\[\[' | wc -l | tr -d ' ')
```

- [ ] **Step 6: Verify against the fixture**

`LINK_COUNT`=`8`; dangling output exactly `DANGLING: nonexistent-note`; for `probe.md`, `LINKS` contains `real`, `alpha`, `nonexistent-note` and NOT `in-code-fence`; `OUTGOING` for `probe.md`=`8`.

- [ ] **Step 7: Run the guard**

```bash
bash reference/check-portability.sh 2>&1 | /usr/bin/grep -c 'graph/SKILL.md'
```

Expected `0`.

- [ ] **Step 8: Commit**

```bash
git add skill-sources/graph/SKILL.md
git commit -m "Fix grep -P and link capture in graph skill

Four sites: link count, dangling report, per-note outgoing targets, hub
score. All returned 0 or empty on macOS.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Fix `architect`, `validate-kernel`, and `health` (4 sites)

**Files:**
- Modify: `skills/architect/SKILL.md:180`
- Modify: `reference/validate-kernel.sh:57`, `:67`, `:75`, `:85`
- Modify: `skills/health/SKILL.md:167`

**Interfaces:**
- Consumes: library functions from Task 2.
- Produces: guard checks 1 and 2 both clean — the GREEN moment for the plan.

- [ ] **Step 1: Fix `architect:180`**

Widest blast radius — bad link data here feeds architecture *proposals*. Uses the `{vocabulary.notes}` placeholder, not `$NOTES_DIR`. Add the loud source block (Task 3 Step 2) at the top of this bash block, then replace lines 179–183:

```bash
# Find dangling links
grep -ohP '\[\[([^\]]+)\]\]' {vocabulary.notes}/*.md | sort -u | while read -r link; do
  NAME=$(echo "$link" | sed 's/\[\[//;s/\]\]//')
  [[ ! -f "{vocabulary.notes}/$NAME.md" ]] && echo "DANGLING: $NAME"
done
```

With:

```bash
# Find dangling links (folded both sides — see reference/lib/link-extraction.sh)
NOTE_INDEX=$(existing_note_index "{vocabulary.notes}")
extract_link_targets "{vocabulary.notes}" | while read -r NAME; do
  [ -n "$NAME" ] && ! printf '%s\n' "$NOTE_INDEX" | grep -qxF "$NAME" && echo "DANGLING: $NAME"
done
```

- [ ] **Step 2: Source the library in `validate-kernel.sh`**

It runs from the plugin directory, so use a relative path. Add near the top, after the colour definitions:

```bash
LINK_LIB="$(cd "$(dirname "$0")" && pwd)/lib/link-extraction.sh"
if [ -r "$LINK_LIB" ]; then
  . "$LINK_LIB"
else
  echo "error: link-extraction library not found at '$LINK_LIB'" >&2
  exit 1
fi
```

- [ ] **Step 3: Fix `validate-kernel.sh:57` — fold the index**

Replace:

```bash
existing_files=$(find "$VAULT" -name "*.md" -not -path "*/.git/*" 2>/dev/null | xargs -I{} basename {} .md | sort -u)
```

With:

```bash
existing_files=$(find "$VAULT" -name "*.md" -not -path "*/.git/*" 2>/dev/null | xargs -I{} basename {} .md \
    | tr '[:upper:]' '[:lower:]' | sort -u)
```

- [ ] **Step 4: Fix `:67` and `:75` — use the library**

This scans several candidate directories rather than one `$NOTES_DIR`, so call the library per directory. Replace at `:67`:

```bash
        new_links=$(grep -roh '\[\[[A-Za-z][^]]*\]\]' "$VAULT/$d" 2>/dev/null | sed 's/\[\[//g;s/\]\]//g' | sort -u)
```

With:

```bash
        new_links=$(extract_link_targets "$VAULT/$d")
```

Replace the identical line at `:75` (the `$VAULT/../self` branch) with:

```bash
    new_links=$(extract_link_targets "$VAULT/../self")
```

- [ ] **Step 5: Fix `:85` — fold the comparison**

Targets from `extract_link_targets` are already folded; `existing_files` is folded by Step 3. Replace:

```bash
    if ! echo "$existing_files" | grep -qxF "$link"; then
```

With:

```bash
    if ! echo "$existing_files" | grep -qxF "$(printf '%s' "$link" | tr '[:upper:]' '[:lower:]')"; then
```

The explicit fold is belt-and-braces: `$link` also arrives from `head -100` sampling, so do not assume provenance.

- [ ] **Step 6: Fix `health:167`**

Already uses `rg`, so no portability defect — but the same naive capture, meaning `/health`, the command users run to check vault health, reports false dangling links. Read lines 160–180 first. Replace:

```bash
rg -oN '\[\[([^\]]+)\]\]' --glob '*.md' -r '$1' | sort -u | while read target; do
```

With:

```bash
rg -oN '\[\[([^\]|#]+)' --glob '*.md' -r '$1' \
  | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
  | tr '[:upper:]' '[:lower:]' | sort -u | while read -r target; do
```

Note `read -r` (was bare `read`), preventing backslash mangling. If the loop body resolves with `[ -f ]`, convert it to the folded-index comparison.

- [ ] **Step 7: Verify validate-kernel still runs**

```bash
bash reference/validate-kernel.sh ~/second-brain
```

Expected: completes, reports primitive 2. The dangling warn count should be **lower** than before (alias and anchor links no longer miscounted). Record before/after in the commit message.

- [ ] **Step 8: Run the guard — expect PASS**

```bash
bash reference/check-portability.sh; echo "exit=$?"
```

Expected: `PORTABILITY: PASS`, `exit=0`. GREEN moment.

- [ ] **Step 9: Commit**

```bash
git add skills/architect/SKILL.md reference/validate-kernel.sh skills/health/SKILL.md
git commit -m "Fix last grep -P site and remaining naive link captures

architect:180 fed evolution proposals from empty link data on macOS.
validate-kernel and health captured through | and #, inflating dangling
counts — health being the command users run to check vault health.

Portability guard now passes.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: CI and regression proof

**Files:**
- Create: `.github/workflows/checks.yml`

**Interfaces:**
- Consumes: passing guard from Task 5.
- Produces: CI enforcement. Does NOT open the PR.

- [ ] **Step 1: Add the workflow**

```yaml
name: checks

on:
  push:
  pull_request:

jobs:
  portability:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install ripgrep
        run: sudo apt-get update && sudo apt-get install -y ripgrep
      - name: Portability guard
        run: bash reference/check-portability.sh
      - name: Shell syntax check
        run: |
          bash -n reference/validate-kernel.sh
          bash -n reference/check-portability.sh
          bash -n reference/lib/link-extraction.sh
```

The syntax check replaces running `validate-kernel.sh` itself: this repo is a generator, not a vault, so it cannot satisfy all 15 primitives, and a step gated with `|| true` would assert nothing. `bash -n` asserts something real — the scripts parse.

- [ ] **Step 2: Prove the guard catches a regression**

A guard never seen red *after* the fix is not known to still work.

```bash
cp skill-sources/stats/SKILL.md /tmp/stats.bak
printf '\n```bash\nBOGUS=$(grep -ohP "x" f)\n```\n' >> skill-sources/stats/SKILL.md
bash reference/check-portability.sh; echo "exit=$? (expect 1)"
cp /tmp/stats.bak skill-sources/stats/SKILL.md
bash reference/check-portability.sh; echo "exit=$? (expect 0)"
git diff --quiet skill-sources/stats/SKILL.md && echo "restored cleanly"
```

Expected `exit=1`, then `exit=0`, then `restored cleanly`. If the first is `0`, the guard does not work — stop.

- [ ] **Step 3: Prove the guard catches inline duplication**

The library must stay the single definition.

```bash
cp skill-sources/graph/SKILL.md /tmp/graph.bak
printf '\n```bash\nX=$(rg -o "\\\\[\\\\[([^\\\\]]+)" f)\n```\n' >> skill-sources/graph/SKILL.md
bash reference/check-portability.sh; echo "exit=$? (expect 1 — check 2 catches naive capture)"
cp /tmp/graph.bak skill-sources/graph/SKILL.md
```

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/checks.yml
git commit -m "Add CI running portability guard and shell syntax checks

Repo's first workflow. Ubuntu runner is case-sensitive, which is why the
case-folding in earlier commits is a prerequisite for green CI.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 5: STOP — do not open the PR**

Push the branch if asked, but **do not open a PR against `upstream`**. That is outward-facing and requires the repository owner's explicit confirmation. Report completion and let the controller surface the PR decision.

When the PR is eventually opened, its body must state: the user-visible symptom; the ugrep masking (so reviewers do not "verify" with bare `grep`); the **case-folding behavior change**; and that `platforms/shared/skill-blocks/` was deliberately left alone.

## Self-Review

**Spec coverage.** Shared library (§0) → Task 2. Root cause / `/usr/bin/grep` → Task 1. Form A → Tasks 3.3, 3.6, 4.2, 4.5. Form B → Tasks 3.4, 3.5, 4.3, 4.4, 5.1, 5.4, 5.6. Bare integers → Task 3.7. Case folding both sides → Task 2.4, 3.5, 4.3, 5.3, 5.5. Loud-failure sourcing → Tasks 3.2, 3.8, 5.2. Guard → Task 1. `tree -P` exclusion → Task 1.3. CI → Task 6.1. Fixture → Shared Test Fixture. "Deliberately reintroduce" → Task 6.2. Single-definition enforcement → Task 6.3. `awk` prerequisite → Task 1.4 (before first use). All 12 sites → Tasks 3 (4), 4 (4), 5 (4). **No gaps.**

**Placeholders.** None: every code step contains runnable code. The loud-source block is referenced by name across Tasks 3–5 rather than abbreviated, and its full text appears at Task 3 Step 2.

**Type consistency.** `count_links` / `extract_link_targets` / `existing_note_index` are used with those exact names in Tasks 3–5. `NOTE_INDEX` names the folded index in the three template consumers; `existing_files` is validate-kernel's pre-existing name, kept. All counted variables are bare integers.

**Pre-verified during planning:** both canonical forms against the fixture; both-sides folding via index (and the proof that one-sided `[ -f ]` passes falsely on APFS); both guard detectors against the real tree (9 and 12); the bash-vs-zsh word-splitting failure that silently zeroed the guard; and `${CLAUDE_PLUGIN_ROOT}` precedent at `skill-sources/refactor/SKILL.md:163`.
