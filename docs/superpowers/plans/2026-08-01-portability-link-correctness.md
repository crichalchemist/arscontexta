# Portability and Link Correctness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove all nine `grep -P` invocations from shipped skill templates, correct wiki-link target extraction, and add a guard plus CI so the bug class cannot silently return.

**Architecture:** Nine bash blocks across three template files use `grep -P`, which does not exist on BSD grep (macOS default) and fails silently to `0`. They fall into two shapes: *count* sites and *resolve* sites. A guard script written first fails against the current tree, then each file's fixes turn it green — the guard is the failing test. CI runs the guard on every push.

**Tech Stack:** Bash, `awk` (POSIX), `ripgrep`, GitHub Actions. No new language runtimes.

## Global Constraints

- **Never use `grep -P`.** It fails on BSD grep with `invalid option -- P`, exit 2.
- **Never introduce `python3`.** Not in the README prerequisite table; zero occurrences under `skill-sources/`. `awk` is POSIX-mandated and is the approved alternative.
- **All counted variables must hold bare integers**, never labelled strings. A value like `total: 2` breaks the numeric comparison at `skill-sources/stats/SKILL.md:276`.
- **Verification must invoke `/usr/bin/grep` explicitly.** Claude Code's Bash tool aliases `grep` to ugrep (which supports `-P`), so bare `grep` produces a false pass.
- **Case comparison must fold both sides against an index.** `[ -f "$DIR/$NAME.md" ]` delegates half the comparison to the filesystem and is therefore filesystem-dependent.
- **Do not modify `platforms/shared/skill-blocks/`.** Verified vestigial; out of scope per spec.
- **Do not "fix" `tree -P`** at `platforms/claude-code/hooks/session-orient.sh.template:74`. Different tool, legitimate flag.
- Branch: `fix/portability-link-correctness`. Target: PR to `upstream` (`agenticnotetaking/arscontexta`).

## Two Canonical Forms

**Form A — count occurrences.** Used where the code counts how many links exist. Alias/anchor termination is irrelevant to a count; only fences matter.

```bash
for f in "$NOTES_DIR"/*.md; do
  awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$f"
done | rg -o '\[\[' | wc -l | tr -d ' '
```

**Form B — resolve targets.** Used where the code extracts a target and tests existence.

```bash
EXISTING=$(ls -1 "$NOTES_DIR"/*.md 2>/dev/null | while read -r p; do basename "$p" .md; done \
  | tr '[:upper:]' '[:lower:]' | sort -u)

for f in "$NOTES_DIR"/*.md; do
  awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$f"
done | rg -o '\[\[([^\]|#]+)' -r '$1' \
  | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
  | tr '[:upper:]' '[:lower:]' | sort -u | while read -r NAME; do
  [ -n "$NAME" ] && ! printf '%s\n' "$EXISTING" | grep -qxF "$NAME" && echo "$NAME"
done
```

## Shared Test Fixture

Every task uses this fixture. It is throwaway — create it in a temp dir, never commit it.

```bash
FIX=$(mktemp -d); mkdir -p "$FIX/notes"
printf -- '---\ntitle: real\n---\nbody\n' > "$FIX/notes/real.md"
printf -- '---\ntitle: alpha\n---\nbody\n' > "$FIX/notes/alpha.md"
cat > "$FIX/notes/probe.md" <<'EOF'
---
title: probe
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

**Expected values for this fixture:**

| Metric | Correct value | Reasoning |
|---|---|---|
| Link count (Form A) | `6` | 6 body links; the fenced one excluded |
| Dangling (Form B) | `1` | `nonexistent-note` only; `Alpha`→`alpha.md` folds |
| Unique topics | `2` | `real`, `alpha` |

## File Structure

| File | Responsibility |
|---|---|
| `reference/check-portability.sh` | **New.** Guard: fails on `grep -P` and on non-terminating link capture. Sole enforcement point. |
| `.github/workflows/checks.yml` | **New.** Repo's first CI. Runs guard + `validate-kernel.sh`. |
| `skill-sources/stats/SKILL.md` | 4 sites: 68, 78, 102, 183 |
| `skill-sources/graph/SKILL.md` | 4 sites: 69, 84, 151, 308 |
| `skills/architect/SKILL.md` | 1 site: 180 |
| `reference/validate-kernel.sh` | 2 sites: 67, 75 (capture only, no `-P`) |
| `skills/health/SKILL.md` | 1 site: 167 (capture only; already uses `rg`) |
| `README.md` | Add `awk` to prerequisite table |

---

### Task 1: Guard script (RED)

**Files:**
- Create: `reference/check-portability.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: executable `reference/check-portability.sh [root]`. Exit `0` = clean, `1` = violations. Later tasks run it to confirm progress; Task 5 wires it into CI.

- [ ] **Step 1: Write the guard script**

```bash
#!/bin/bash
# check-portability.sh — fail on shell constructs that break outside GNU userland.
#
# WHY THIS INVOKES /usr/bin/grep EXPLICITLY:
# Claude Code's Bash tool aliases `grep` to a ugrep wrapper, which DOES support -P.
# Running these checks with bare `grep` makes them pass while the bug ships to users.
# Do not "simplify" $GREP back to `grep`.
#
# platforms/ is deliberately NOT scanned: platforms/shared/skill-blocks/ is a
# vestigial copy outside the generation path, and session-orient.sh.template uses
# `tree -P`, a different tool with a legitimate -P flag.

set -u
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
GREP=/usr/bin/grep
fail=0

red() { printf '  FAIL %s\n' "$1"; fail=1; }
ok()  { printf '  PASS %s\n' "$1"; }

# SCAN is an ARRAY, not a space-joined string. A string + unquoted $SCAN word-splits
# in bash but NOT in zsh, where it becomes one nonexistent path — and with 2>/dev/null
# that yields a silent 0, i.e. the guard passes while the bug ships. Verified: bash 9
# hits, zsh 0, from the identical command. Do not "simplify" this back to a string.
SCAN=("$ROOT/skills" "$ROOT/skill-sources" "$ROOT/reference")

echo "=== Portability check: $ROOT ==="

echo "1. No PCRE grep (-P) in shipped templates"
hits=$("$GREP" -rn --include='*.md' --include='*.sh' -E '(^|[^a-zA-Z_-])grep +[^|]*-[a-zA-Z]*P' \
  "${SCAN[@]}" 2>/dev/null || true)
if [ -n "$hits" ]; then
  red "grep -P found (exits 2 on BSD grep, silently yields 0):"
  printf '%s\n' "$hits" | sed 's/^/       /'
else
  ok "no grep -P"
fi

echo "2. Wiki-link capture terminates at | and #"
hits=$("$GREP" -rn --include='*.md' --include='*.sh' -F '\[\[' "${SCAN[@]}" 2>/dev/null \
  | "$GREP" -F '[^' | "$GREP" -v -F '|#' || true)
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

- [ ] **Step 2: Make executable and run it — verify it FAILS**

```bash
chmod +x reference/check-portability.sh
./reference/check-portability.sh
```

Expected: `PORTABILITY: FAIL`, exit 1, with **exactly these counts**:

- Check 1: **9** hits — `stats` 68/78/102/183, `graph` 69/84/151/308, `architect` 180.
- Check 2: **12** hits — those 9, plus `validate-kernel.sh` 67/75, plus `skills/health/SKILL.md:167`.

**If it reports PASS, the guard is broken — stop and fix it before proceeding.** A guard that has never been seen red is not known to work.

**If check 1 reports 0, you are almost certainly hitting the word-splitting trap.** Confirm with:

```bash
bash reference/check-portability.sh
```

If bash gives 9 and your shell gave 0, `SCAN` is being expanded as a single string. This exact failure was observed during planning.

- [ ] **Step 3: Verify it does NOT flag `tree -P`**

```bash
./reference/check-portability.sh 2>&1 | /usr/bin/grep -c 'session-orient'
```

Expected: `0`. If non-zero, check 1's regex is over-broad and would break working code.

- [ ] **Step 4: Commit**

```bash
git add reference/check-portability.sh
git commit -m "Add portability guard (currently failing)

Fails on grep -P and non-terminating wiki-link capture. Invokes
/usr/bin/grep explicitly because Claude Code's shell aliases grep to
ugrep, which supports -P and produces a false pass.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Fix `skill-sources/stats/SKILL.md` (4 sites)

**Files:**
- Modify: `skill-sources/stats/SKILL.md:68`, `:78`, `:102`, `:183`

**Interfaces:**
- Consumes: `reference/check-portability.sh` from Task 1.
- Produces: `LINK_COUNT`, `TOPIC_COUNT`, `DANGLING_COUNT`, `THIS_WEEK_LINKS` — all bare integers. `DANGLING_COUNT` is consumed at `:276` by a numeric `-gt` comparison and rendered at `:244`.

- [ ] **Step 1: Build fixture and capture wrong values**

Create the fixture from **Shared Test Fixture** above, then:

```bash
cd "$FIX" && NOTES_DIR=notes
/usr/bin/grep -ohP '\[\[[^\]]+\]\]' "$NOTES_DIR"/*.md 2>/dev/null | wc -l | tr -d ' '
```

Expected: `0` — proving the silent failure (BSD grep rejects `-P`, `2>/dev/null` hides it).

- [ ] **Step 2: Fix `:68` — LINK_COUNT (Form A)**

Replace:

```bash
LINK_COUNT=$(grep -ohP '\[\[[^\]]+\]\]' "$NOTES_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
```

With:

```bash
LINK_COUNT=$(for f in "$NOTES_DIR"/*.md; do
  awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$f"
done | rg -o '\[\[' | wc -l | tr -d ' ')
```

- [ ] **Step 3: Fix `:78` — TOPIC_COUNT (Form B, frontmatter)**

Replace:

```bash
TOPIC_COUNT=$(grep -ohP '^\s*-\s*"\[\[([^\]]+)\]\]"' "$NOTES_DIR"/*.md 2>/dev/null | sort -u | wc -l | tr -d ' ')
```

With:

```bash
TOPIC_COUNT=$(rg -oN --no-filename '^\s*-\s*"\[\[([^\]|#]+)' -r '$1' "$NOTES_DIR"/*.md 2>/dev/null \
  | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
  | tr '[:upper:]' '[:lower:]' | sort -u | wc -l | tr -d ' ')
```

No fence-stripping here: `topics:` entries live in YAML frontmatter, which is never inside a code fence.

- [ ] **Step 4: Fix `:102` — DANGLING_COUNT (Form B)**

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
# Dangling link count
# Case folded on BOTH sides against an index: [ -f ] alone is filesystem-dependent
# (case-insensitive on macOS APFS, case-sensitive on Linux) and would report
# different counts for identical content.
EXISTING_NOTES=$(ls -1 "$NOTES_DIR"/*.md 2>/dev/null | while read -r p; do basename "$p" .md; done \
  | tr '[:upper:]' '[:lower:]' | sort -u)
DANGLING_COUNT=$(for f in "$NOTES_DIR"/*.md; do
  awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$f"
done | rg -o '\[\[([^\]|#]+)' -r '$1' \
  | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
  | tr '[:upper:]' '[:lower:]' | sort -u | while read -r NAME; do
  [ -n "$NAME" ] && ! printf '%s\n' "$EXISTING_NOTES" | grep -qxF "$NAME" && echo "$NAME"
done | wc -l | tr -d ' ')
```

- [ ] **Step 5: Fix `:183` — THIS_WEEK_LINKS (Form A)**

Replace:

```bash
    [[ "$CREATED" > "$WEEK_AGO" || "$CREATED" == "$WEEK_AGO" ]] && grep -oP '\[\[[^\]]+\]\]' "$f" 2>/dev/null
```

With:

```bash
    [[ "$CREATED" > "$WEEK_AGO" || "$CREATED" == "$WEEK_AGO" ]] && \
      awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$f" | rg -o '\[\['
```

- [ ] **Step 6: Verify all four against the fixture**

Extract each block and run it with `NOTES_DIR=notes` inside `$FIX`. Assert:

| Variable | Expected |
|---|---|
| `LINK_COUNT` | `6` |
| `TOPIC_COUNT` | `2` |
| `DANGLING_COUNT` | `1` |
| `THIS_WEEK_LINKS` | `6` (all fixture notes are recent) |

Then confirm the bare-integer requirement:

```bash
[ "$DANGLING_COUNT" -gt 0 ] && echo "numeric OK"
```

Expected: `numeric OK` with no `integer expression expected` error.

- [ ] **Step 7: Run the guard — stats sites should be gone**

```bash
./reference/check-portability.sh 2>&1 | /usr/bin/grep -c 'stats/SKILL.md'
```

Expected: `0`. Guard still exits 1 overall (graph, architect, validate-kernel remain).

- [ ] **Step 8: Commit**

```bash
git add skill-sources/stats/SKILL.md
git commit -m "Fix grep -P and link capture in stats skill

LINK_COUNT, TOPIC_COUNT, DANGLING_COUNT and THIS_WEEK_LINKS all returned 0
on macOS because BSD grep rejects -P and stderr was suppressed. Dangling
now folds case on both sides against an index rather than relying on
filesystem case semantics.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Fix `skill-sources/graph/SKILL.md` (4 sites)

**Files:**
- Modify: `skill-sources/graph/SKILL.md:69`, `:84`, `:151`, `:308`

**Interfaces:**
- Consumes: guard from Task 1; Forms A and B as used in Task 2.
- Produces: `LINK_COUNT` (integer), `DANGLING:` lines, `LINKS` (newline-separated folded targets), `OUTGOING` (integer).

- [ ] **Step 1: Fix `:69` — LINK_COUNT (Form A)**

Replace:

```bash
LINK_COUNT=$(grep -ohP '\[\[[^\]]+\]\]' "$NOTES_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
```

With:

```bash
LINK_COUNT=$(for f in "$NOTES_DIR"/*.md; do
  awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$f"
done | rg -o '\[\[' | wc -l | tr -d ' ')
```

- [ ] **Step 2: Fix `:84` — dangling report (Form B)**

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
# Case folded on both sides — see stats/SKILL.md for rationale.
EXISTING_NOTES=$(ls -1 "$NOTES_DIR"/*.md 2>/dev/null | while read -r p; do basename "$p" .md; done \
  | tr '[:upper:]' '[:lower:]' | sort -u)
for f in "$NOTES_DIR"/*.md; do
  awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$f"
done | rg -o '\[\[([^\]|#]+)' -r '$1' \
  | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
  | tr '[:upper:]' '[:lower:]' | sort -u | while read -r NAME; do
  [ -n "$NAME" ] && ! printf '%s\n' "$EXISTING_NOTES" | grep -qxF "$NAME" && echo "DANGLING: $NAME"
done
```

- [ ] **Step 3: Fix `:151` — per-note outgoing targets (Form B, single file)**

Replace:

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

- [ ] **Step 4: Fix `:308` — OUTGOING count (Form A, single file)**

Replace:

```bash
  OUTGOING=$(grep -oP '\[\[[^\]]+\]\]' "$f" 2>/dev/null | wc -l | tr -d ' ')
```

With:

```bash
  OUTGOING=$(awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$f" \
    | rg -o '\[\[' | wc -l | tr -d ' ')
```

- [ ] **Step 5: Verify against fixture**

Run each block with `NOTES_DIR=notes` inside `$FIX`. Assert `LINK_COUNT` = `6`; dangling output is exactly `DANGLING: nonexistent-note`; for `probe.md`, `LINKS` contains `real`, `alpha`, `nonexistent-note` and does **not** contain `in-code-fence`; `OUTGOING` for `probe.md` = `6`.

- [ ] **Step 6: Run the guard**

```bash
./reference/check-portability.sh 2>&1 | /usr/bin/grep -c 'graph/SKILL.md'
```

Expected: `0`.

- [ ] **Step 7: Commit**

```bash
git add skill-sources/graph/SKILL.md
git commit -m "Fix grep -P and link capture in graph skill

Four sites: link count, dangling report, per-note outgoing targets, and
hub score. All returned 0 or empty on macOS.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Fix `architect`, `validate-kernel`, and `health` (4 sites)

**Files:**
- Modify: `skills/architect/SKILL.md:180`
- Modify: `reference/validate-kernel.sh:57`, `:67`, `:75`, `:85`
- Modify: `skills/health/SKILL.md:167`

**Interfaces:**
- Consumes: Form B; guard from Task 1.
- Produces: guard check 1 and check 2 both clean — the GREEN moment for the plan.

Grouped because these are the last `-P` site and the last capture sites; the guard only turns green when all four are done.

- [ ] **Step 1: Fix `architect:180` (Form B)**

This site has the widest blast radius — bad link data here feeds architecture *proposals*. Note it uses the `{vocabulary.notes}` placeholder, not `$NOTES_DIR`. Replace lines 179–183:

```bash
# Find dangling links
grep -ohP '\[\[([^\]]+)\]\]' {vocabulary.notes}/*.md | sort -u | while read -r link; do
  NAME=$(echo "$link" | sed 's/\[\[//;s/\]\]//')
  [[ ! -f "{vocabulary.notes}/$NAME.md" ]] && echo "DANGLING: $NAME"
done
```

With:

```bash
# Find dangling links
# Case folded on both sides — [ -f ] alone is filesystem-dependent.
EXISTING_NOTES=$(ls -1 {vocabulary.notes}/*.md 2>/dev/null | while read -r p; do basename "$p" .md; done \
  | tr '[:upper:]' '[:lower:]' | sort -u)
for f in {vocabulary.notes}/*.md; do
  awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$f"
done | rg -o '\[\[([^\]|#]+)' -r '$1' \
  | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
  | tr '[:upper:]' '[:lower:]' | sort -u | while read -r NAME; do
  [ -n "$NAME" ] && ! printf '%s\n' "$EXISTING_NOTES" | grep -qxF "$NAME" && echo "DANGLING: $NAME"
done
```

- [ ] **Step 2: Fix `validate-kernel.sh:67` and `:75` (adaptation, not paste)**

These two have **no `-P`** — they are capture-correctness only. They scan `$VAULT/$d` across candidate directories and feed `grep -qxF` against `existing_files`. Keep that loop structure; change only the extraction.

Replace at `:67`:

```bash
        new_links=$(grep -roh '\[\[[A-Za-z][^]]*\]\]' "$VAULT/$d" 2>/dev/null | sed 's/\[\[//g;s/\]\]//g' | sort -u)
```

With:

```bash
        new_links=$(rg -oN --no-filename '\[\[([A-Za-z][^\]|#]*)' -r '$1' "$VAULT/$d" 2>/dev/null \
            | sed 's/[[:space:]]*$//' | sort -u)
```

Replace the identical line at `:75` (the `$VAULT/../self` branch) the same way.

- [ ] **Step 3: Fold case in the validate-kernel comparison**

`existing_files` at `:57` and the membership test at `:85` must fold too, or this file keeps the filesystem dependency the rest of the change removes.

Replace `:57`:

```bash
existing_files=$(find "$VAULT" -name "*.md" -not -path "*/.git/*" 2>/dev/null | xargs -I{} basename {} .md | sort -u)
```

With:

```bash
existing_files=$(find "$VAULT" -name "*.md" -not -path "*/.git/*" 2>/dev/null | xargs -I{} basename {} .md \
    | tr '[:upper:]' '[:lower:]' | sort -u)
```

Replace `:85`:

```bash
    if ! echo "$existing_files" | grep -qxF "$link"; then
```

With:

```bash
    if ! echo "$existing_files" | grep -qxF "$(printf '%s' "$link" | tr '[:upper:]' '[:lower:]')"; then
```

- [ ] **Step 3b: Fix `skills/health/SKILL.md:167` (capture only)**

This site already uses `rg`, so it has no portability defect — but its capture is the same naive `[^\]]+`, which means `/health`, the command users run to check vault health, reports false dangling links.

Replace:

```bash
rg -oN '\[\[([^\]]+)\]\]' --glob '*.md' -r '$1' | sort -u | while read target; do
```

With:

```bash
rg -oN '\[\[([^\]|#]+)' --glob '*.md' -r '$1' \
  | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
  | tr '[:upper:]' '[:lower:]' | sort -u | while read -r target; do
```

Note `read -r` (was bare `read`), which prevents backslash mangling in targets.

Check the surrounding block: if the loop body tests existence with `[ -f ]`, it must use the folded-index comparison instead, for the reason given in Task 2 Step 4. Read lines 160–180 before editing.

- [ ] **Step 4: Verify validate-kernel still runs**

```bash
./reference/validate-kernel.sh ~/second-brain
```

Expected: completes, reports primitive 2. The dangling warn count should be **lower than before** the change (alias and anchor links no longer miscounted). Record before/after numbers in the commit message.

- [ ] **Step 5: Run the guard — expect PASS**

```bash
./reference/check-portability.sh; echo "exit=$?"
```

Expected: `PORTABILITY: PASS`, `exit=0`. This is the GREEN moment for the whole plan.

- [ ] **Step 6: Commit**

```bash
git add skills/architect/SKILL.md reference/validate-kernel.sh skills/health/SKILL.md
git commit -m "Fix last grep -P site and remaining naive link captures

architect:180 fed evolution proposals from empty link data on macOS.
validate-kernel and health captured through | and #, inflating dangling
counts — health being the command users run to check vault health.
Both sides of each comparison now fold case.

Portability guard now passes.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: CI, prerequisites, regression proof, PR

**Files:**
- Create: `.github/workflows/checks.yml`
- Modify: `README.md` (prerequisite table)

**Interfaces:**
- Consumes: passing guard from Task 4.
- Produces: CI enforcement; PR to upstream.

- [ ] **Step 1: Add CI workflow**

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
        run: sudo apt-get update && sudo apt-get install -y ripgrep tree
      - name: Portability guard
        run: ./reference/check-portability.sh
      - name: Kernel validation (self-check)
        run: ./reference/validate-kernel.sh . || true
```

`validate-kernel.sh` runs with `|| true` because this repo is a generator, not a vault — it will not satisfy all 15 primitives. It is included so breakage in the script itself surfaces.

- [ ] **Step 2: Add `awk` to the README prerequisite table**

Add a row alongside `tree` and `ripgrep`:

```markdown
| `awk` | Yes | Code-fence stripping in link extraction (POSIX; preinstalled on macOS and Linux) |
```

- [ ] **Step 3: Prove the guard catches a regression**

A guard never seen red after the fix is not known to still work.

```bash
cp skill-sources/stats/SKILL.md /tmp/stats.bak
printf '\n```bash\nBOGUS=$(grep -ohP "x" f)\n```\n' >> skill-sources/stats/SKILL.md
./reference/check-portability.sh; echo "exit=$? (expect 1)"
cp /tmp/stats.bak skill-sources/stats/SKILL.md
./reference/check-portability.sh; echo "exit=$? (expect 0)"
git diff --quiet skill-sources/stats/SKILL.md && echo "restored cleanly"
```

Expected: `exit=1`, then `exit=0`, then `restored cleanly`. If the first is `0`, the guard does not work — stop and fix it.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/checks.yml README.md
git commit -m "Add CI running portability guard; document awk prerequisite

Repo's first workflow. Ubuntu runner is case-sensitive, which is why the
case-folding change in earlier commits is a prerequisite for green CI.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 5: Push and open the PR**

```bash
git push -u origin fix/portability-link-correctness
```

PR body must state:
1. The user-visible symptom (macOS users see `Connections: 0`, `Topics: 0`, `Dangling: 0`).
2. The ugrep masking, so reviewers do not "verify" with bare `grep` and conclude there was no bug.
3. **The case-folding behavior change** — dangling results change for vaults with mixed-case slugs. This is deliberate, not incidental.
4. That `platforms/shared/skill-blocks/` was deliberately left alone, and why.

Do not open the PR against `upstream` without confirming with the repository owner first.

## Self-Review

**Spec coverage.** Problem → Tasks 2–4. Root cause/`/usr/bin/grep` → Task 1 Step 1. Form A → Tasks 2.2, 2.5, 3.1, 3.4. Form B → Tasks 2.3, 2.4, 3.2, 3.3, 4.1, 4.3b. Bare integers → Task 2 Step 6. Case folding both sides → Tasks 2.4, 3.2, 4.1, 4.3, 4.3b. Guard → Task 1. `tree -P` exclusion → Task 1 Step 3. CI → Task 5.1. Verification fixture → Shared Test Fixture. Success criterion "deliberately reintroduce" → Task 5.3. `awk` prerequisite risk → Task 5.2. All 12 sites → Tasks 2 (4), 3 (4), 4 (4). **No gaps.**

**Empirically pre-verified during planning**, so the implementer inherits working code rather than plausible code: Form A and Form B against the fixture; both-sides case folding via index (and the proof that the one-sided `-f` form passes falsely on APFS); both guard detectors against the real tree (9 and 12); and the bash-vs-zsh word-splitting failure that silently zeroed the guard.

**Placeholders.** None: every code step contains runnable code; no "similar to Task N" — blocks are repeated in full.

**Type consistency.** `NOTES_DIR` used in stats/graph; `{vocabulary.notes}` in architect (placeholder, deliberate); `$VAULT/$d` in validate-kernel. `EXISTING_NOTES` names the folded index in all three template files; `existing_files` is validate-kernel's pre-existing name and is kept. All counted variables are bare integers.
