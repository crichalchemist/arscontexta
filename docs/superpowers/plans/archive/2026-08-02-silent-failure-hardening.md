# Silent-Failure Hardening Implementation Plan

> **Checkboxes ticked retroactively on 2026-08-02**, against the commit record in the
> execution ledger under `.superpowers/sdd/`. This plan was fully executed and merged while
> showing 0 steps complete — a status file that lied about status, which is precisely the defect
> class this project exists to remove. The ledger was accurate throughout because it was written
> as a side effect of the work; the checkboxes needed a separate deliberate act, and did not get
> one. Tick as you go.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close every open path where a failure produces a plausible-looking number instead of an error, and make that property testable rather than asserted.

**Architecture:** A behavioral test harness is written FIRST and must fail against today's code — it is the RED that every later task turns green. Then: the guard is made to fail when it cannot look, the library is made to fail loudly on every dependency and argument fault, consumers are made to propagate those failures, and generated vaults get the library by copy instead of by a variable that is never set.

**Tech Stack:** Bash, zsh, `awk` (POSIX), `ripgrep`, GitHub Actions. No new language runtimes.

## Global Constraints

- **A failure must never produce a number.** This is the spec's thesis. Ten instances are catalogued; five are open. Any change that leaves a failure path returning `0` or empty with exit 0 has failed its task.
- **Never use `grep -P`.** Fails on BSD grep with `invalid option -- P`, exit 2.
- **Never introduce `python3`.** Not a declared prerequisite; `awk` is the approved alternative.
- **Verification must invoke `/usr/bin/grep` explicitly.** Claude Code's Bash tool aliases `grep` to ugrep, which supports `-P` and yields a false pass.
- **Run every script under `bash` explicitly.** The session shell is zsh; two known defects are bash/zsh forks.
- **`ops/` is a fixed directory name**, written literally throughout `skills/setup/SKILL.md`. Safe to hardcode. `{vocabulary.*}` placeholders must NEVER be resolved to literals.
- **Match `hooks/scripts/read_config.sh:20` for vault-root lookup** — `${CLAUDE_PROJECT_DIR:-$(pwd)}`. Do not invent a third mechanism, and do not add a walk-up (deferred, spec §3.2c).
- **Do not fix the ~11 mirror-defect sites** (`rg -l "\[\[$NAME\]\]"`). Out of scope, own spec.
- Branch: continue on `fix/portability-link-correctness`. Do not open a PR.

## Known-open defects this plan closes

| Spec § | Defect | Verified symptom |
|---|---|---|
| 1.1 | guard passes when its own scan fails | `check-portability.sh /nonexistent` → PASS exit 0 |
| 1.2 | guard scans 3 of 9 shipped dirs | live naive capture in `generators/` unseen |
| 1.3 | `grep --perl-regexp` passes both checks | evasion |
| 2.1 | library `2>/dev/null` eats rg runtime faults | broken `RIPGREP_CONFIG_PATH` → `0` |
| 2.2 | `stats:87` bypasses the library | rg absent → `TOPIC_COUNT=0` silently |
| 2.3 | `VAR=$(fn)` discards `return 1` | renders `Dangling: 0` after dep error |
| 2.4 | nonexistent dir ≡ empty vault | plausible healthy report |
| 2.5 | `count_links_recursive` subshell | bash `0`, zsh `9` |
| 3.1 | flat vs recursive disagree | opposite answers, same vault |
| 3.2 | `CLAUDE_PLUGIN_ROOT` unset | generated `/stats` fails every run |
| 3.3 | fold is locale-dependent | `[[über]]` DANGLING under `LC_ALL=C` |

## File Structure

| File | Responsibility |
|---|---|
| `reference/test/link-extraction.test.sh` | **New.** Behavioral test harness. Sole executable proof of library correctness. Runs under bash AND zsh. |
| `reference/lib/link-extraction.sh` | Library. Gains a version constant, argument validation, loud rg failures, locale-independent folding. |
| `reference/check-portability.sh` | Guard. Gains scan-failure detection, full directory coverage, evasion closure. |
| `generators/features/maintenance.md` | 1 live naive-capture site (line 29). |
| `skill-sources/stats/SKILL.md` | `:87` routed through library; error propagation. |
| `skill-sources/graph/SKILL.md` | trim+fold at the triangles block. |
| `skills/health/SKILL.md` | scope contract reconciled. |
| `skills/setup/SKILL.md` | **Generator change.** Creates `ops/lib/` and copies the library. |
| `.github/workflows/checks.yml` | Runs the harness under bash and zsh. |

## Shared fixture builder

Used by the harness and by manual verification. Note `created:` fields and the `topics:` block — both were missing from an earlier fixture and made two assertions unverifiable.

```bash
build_fixture() {           # build_fixture <dir>
  local d="$1"
  mkdir -p "$d/notes/sub"
  printf -- '---\ntitle: real\ncreated: 2026-08-01\n---\nbody\n' > "$d/notes/real.md"
  printf -- '---\ntitle: alpha\ncreated: 2026-08-01\n---\nbody\n' > "$d/notes/alpha.md"
  printf -- '---\ntitle: Über\ncreated: 2026-08-01\n---\nbody\n' > "$d/notes/Über.md"
  printf -- 'Nested: [[buried-target]]\n'                        > "$d/notes/sub/nested.md"
  printf -- '---\ntitle: buried-target\n---\nbody\n'             > "$d/notes/sub/buried-target.md"
  {
    printf -- '---\ntitle: probe\ncreated: 2026-08-01\ntopics:\n'
    printf -- '  - "[[real]]"\n  - "[[Alpha|display name]]"\n---\n'
    printf -- 'Plain: [[real]]\nAlias: [[real|some alias]]\nAnchor: [[real#a-heading]]\n'
    printf -- 'Both:  [[real|alias#frag]]\nCase:  [[Alpha]]\nAccent: [[über]]\n'
    printf -- 'Ghost: [[nonexistent-note]]\n'
    printf -- '```\n[[in-code-fence]]\n```\n'
  } > "$d/notes/probe.md"
}
```

**Expected values against this fixture** (`notes/` only, flat):

| Assertion | Value |
|---|---|
| `count_links notes` | `9` (2 topics + 7 body; the fenced one excluded — verified empirically, not derived) |
| `count_links_recursive notes` | `10` (flat 9 + the nested link) |
| `extract_link_targets notes` | `alpha`, `nonexistent-note`, `real`, `über` |
| `existing_note_index notes` | `alpha`, `probe`, `real`, `über` |
| flat dangling | `nonexistent-note` only |
| `extract_link_targets_recursive notes` | adds `buried-target` |
| recursive dangling | `nonexistent-note` only (buried-target resolves) |

---

### Task 1: Behavioral test harness (RED)

**Files:**
- Create: `reference/test/link-extraction.test.sh`

**Interfaces:**
- Consumes: `reference/lib/link-extraction.sh`.
- Produces: executable `reference/test/link-extraction.test.sh`. Exit `0` all pass, `1` any fail. Prints `FAIL: <name>` per failure and a `passed/failed` summary. Tasks 2–9 run it; Task 10 wires it into CI.

- [x] **Step 1: Write the harness**

```bash
#!/bin/bash
# link-extraction.test.sh — behavioral tests for the link-extraction library.
#
# WHY THIS EXISTS: CI previously ran only a textual guard and `bash -n`. It
# executed no library code, which is why a shell-dependent subshell bug, a
# swallowed dependency failure, and a locale-dependent fold all shipped.
#
# Run under BOTH shells: `bash …test.sh` and `zsh …test.sh`. Two known defects
# were bash/zsh forks; a single-shell run cannot see them.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
LIB="$HERE/../lib/link-extraction.sh"
passed=0; failed=0

ok()   { passed=$((passed+1)); }
fail() { failed=$((failed+1)); printf 'FAIL: %s\n       expected [%s] got [%s]\n' "$1" "$2" "$3"; }
eq()   { if [ "$2" = "$3" ]; then ok; else fail "$1" "$2" "$3"; fi; }

build_fixture() {
  local d="$1"
  mkdir -p "$d/notes/sub"
  printf -- '---\ntitle: real\ncreated: 2026-08-01\n---\nbody\n' > "$d/notes/real.md"
  printf -- '---\ntitle: alpha\ncreated: 2026-08-01\n---\nbody\n' > "$d/notes/alpha.md"
  printf -- '---\ntitle: Über\ncreated: 2026-08-01\n---\nbody\n' > "$d/notes/Über.md"
  printf -- 'Nested: [[buried-target]]\n'                        > "$d/notes/sub/nested.md"
  printf -- '---\ntitle: buried-target\n---\nbody\n'             > "$d/notes/sub/buried-target.md"
  {
    printf -- '---\ntitle: probe\ncreated: 2026-08-01\ntopics:\n'
    printf -- '  - "[[real]]"\n  - "[[Alpha|display name]]"\n---\n'
    printf -- 'Plain: [[real]]\nAlias: [[real|some alias]]\nAnchor: [[real#a-heading]]\n'
    printf -- 'Both:  [[real|alias#frag]]\nCase:  [[Alpha]]\nAccent: [[über]]\n'
    printf -- 'Ghost: [[nonexistent-note]]\n'
    printf -- '```\n[[in-code-fence]]\n```\n'
  } > "$d/notes/probe.md"
}

FIX=$(mktemp -d); build_fixture "$FIX"
. "$LIB"
N="$FIX/notes"

# --- extraction correctness -------------------------------------------------
eq "count_links excludes fenced links"        "9" "$(count_links "$N")"
eq "targets terminate at | and #"             "alpha nonexistent-note real über" \
   "$(extract_link_targets "$N" | tr '\n' ' ' | sed 's/ $//')"
eq "index folds case"                         "alpha probe real über" \
   "$(existing_note_index "$N" | tr '\n' ' ' | sed 's/ $//')"

# --- dangling resolution ----------------------------------------------------
dangling() {                       # dangling <extract-fn> <index-fn> <dir>
  local idx; idx=$("$2" "$3")
  "$1" "$3" | while IFS= read -r n; do
    [ -n "$n" ] && ! printf '%s\n' "$idx" | /usr/bin/grep -qxF "$n" && echo "$n"
  done | tr '\n' ' ' | sed 's/ $//'
}
eq "flat dangling finds only the ghost"       "nonexistent-note" \
   "$(dangling extract_link_targets existing_note_index "$N")"
eq "recursive resolves the nested target"     "nonexistent-note" \
   "$(dangling extract_link_targets_recursive existing_note_index_recursive "$N")"

# --- recursion --------------------------------------------------------------
eq "recursive sees subdirectories"            "yes" \
   "$(extract_link_targets_recursive "$N" | /usr/bin/grep -qx 'buried-target' && echo yes || echo no)"
eq "flat does NOT see subdirectories"         "no" \
   "$(extract_link_targets "$N" | /usr/bin/grep -qx 'buried-target' && echo yes || echo no)"
eq "count_links_recursive is shell-agnostic"  "10" "$(count_links_recursive "$N")"

# --- locale independence ----------------------------------------------------
eq "fold handles non-ASCII under LC_ALL=C"    "yes" \
   "$(LC_ALL=C sh -c ". '$LIB'; existing_note_index '$N'" | /usr/bin/grep -qx 'über' && echo yes || echo no)"

# --- failure must never be a number ----------------------------------------
eq "missing dir fails, emits no count"        "loud" \
   "$(out=$(count_links "$FIX/nope" 2>/dev/null); rc=$?; [ "$rc" -ne 0 ] && [ -z "$out" ] && echo loud || echo "silent:$out")"
eq "missing rg fails, emits no count"         "loud" \
   "$(out=$(PATH=/usr/bin:/bin sh -c ". '$LIB'; count_links '$N'" 2>/dev/null); rc=$?; \
      [ "$rc" -ne 0 ] && [ -z "$out" ] && echo loud || echo "silent:$out")"
eq "library declares a contract version"      "yes" \
   "$([ "${LINK_EXTRACTION_VERSION:-0}" -ge 1 ] 2>/dev/null && echo yes || echo no)"

rm -rf "$FIX"
printf '\npassed=%s failed=%s\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
```

- [x] **Step 2: Make executable and run under BOTH shells — verify it FAILS**

```bash
chmod +x reference/test/link-extraction.test.sh
bash reference/test/link-extraction.test.sh; echo "bash exit=$?"
zsh  reference/test/link-extraction.test.sh; echo "zsh exit=$?"
```

Expected: both exit 1, with failures including `count_links_recursive is shell-agnostic` (bash reports 0), `fold handles non-ASCII under LC_ALL=C`, `missing dir fails`, `missing rg fails`, and `library declares a contract version`.

**If either shell reports all-pass, the harness is broken — stop and fix it.** Every defect it names is independently confirmed present.

Record the exact failing set for both shells in your report; later tasks are measured against it shrinking.

- [x] **Step 3: Commit**

```bash
git add reference/test/link-extraction.test.sh
git commit -m "Add behavioral test harness for link-extraction (currently failing)

CI ran only a textual guard and bash -n, executing no library code — which
is why a shell-dependent subshell bug, a swallowed dependency failure and a
locale-dependent fold all shipped. Runs under bash and zsh because two known
defects are shell forks.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Guard must fail when it cannot look, and must look everywhere

**Files:**
- Modify: `reference/check-portability.sh:21,26-28,36-38`
- Modify: `generators/features/maintenance.md:29`

**Interfaces:**
- Consumes: nothing.
- Produces: guard that exits non-zero on scan failure and covers all nine shipped directories.

- [x] **Step 1: Confirm the defect**

```bash
bash reference/check-portability.sh /nonexistent-root-xyz; echo "exit=$? (currently 0 — the bug)"
```

- [x] **Step 2: Make scan failure fatal**

Replace the check-1 and check-2 `hits=$(...)` assignments so grep's return code is inspected. grep returns `0` = matches, `1` = no matches, `>1` = error.

```bash
scan_or_die() {            # scan_or_die <description> <grep-args...>
  local desc="$1"; shift
  local out rc
  out=$("$GREP" "$@" 2>/dev/null); rc=$?
  if [ "$rc" -gt 1 ]; then
    printf '  FAIL %s: scan itself failed (grep rc=%s) — cannot conclude anything\n' "$desc" "$rc"
    fail=1
    return 2
  fi
  printf '%s' "$out"
  return 0
}
```

Also assert the scan roots exist before scanning:

```bash
for d in "${SCAN[@]}"; do
  [ -d "$d" ] || { printf '  FAIL scan directory missing: %s\n' "$d"; fail=1; }
done
```

- [x] **Step 3: Extend SCAN to all nine shipped directories**

Replace line 21:

```bash
SCAN=("$ROOT/skills" "$ROOT/skill-sources" "$ROOT/reference" \
      "$ROOT/generators" "$ROOT/platforms" "$ROOT/presets" \
      "$ROOT/hooks" "$ROOT/agents" "$ROOT/scripts")
```

- [x] **Step 4: Run the guard — expect it to go RED on real findings**

```bash
bash reference/check-portability.sh; echo "exit=$?"
```

Expected: FAIL, listing at minimum `generators/features/maintenance.md:29`. Record every hit. Any hit outside that file is pre-existing in a newly-scanned directory — triage it in your report; do not fix beyond scope without saying so.

- [x] **Step 5: Fix the live defect**

`generators/features/maintenance.md:29`. Replace:

```bash
rg -o '\[\[([^\]]+)\]\]' {DOMAIN:notes/} -r '$1' --no-filename | sort -u | while read title; do
```

With:

```bash
rg -oNI '\[\[([^\]|#]+)' {DOMAIN:notes/} -r '$1' | sed 's/[[:space:]]*$//' | sort -u | while IFS= read -r title; do
```

Note `-I` (no filename; `-N` alone is no-line-number and leaves `path:` prefixes), `|#` termination, trailing-space trim, and `read -r`.

- [x] **Step 6: Verify the guard is clean and the fixture harness is unaffected**

```bash
bash reference/check-portability.sh; echo "exit=$? (expect 0)"
bash reference/check-portability.sh /nonexistent-root-xyz; echo "exit=$? (expect non-zero)"
```

Both must hold. The second is the whole point of this task.

- [x] **Step 7: Commit**

```bash
git add reference/check-portability.sh generators/features/maintenance.md
git commit -m "Guard: fail on scan error, scan all shipped directories

The guard treated grep's exit 2 as 'no matches', so a missing scan root or
absent /usr/bin/grep produced PASS. It also scanned 3 of 9 shipped
directories, missing a live naive capture in generators/ that it would have
caught verbatim.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Close guard evasion vectors

**Files:**
- Modify: `reference/check-portability.sh` (check-1 and check-2 patterns)

**Interfaces:**
- Consumes: Task 2's guard.
- Produces: guard that catches `grep --perl-regexp`, `egrep -oP`, `rg -P`/`--pcre2`, and non-negated-class naive captures.

- [x] **Step 1: Write failing probes**

```bash
T=$(mktemp -d); mkdir -p "$T/skills" "$T/skill-sources" "$T/reference" "$T/generators" \
  "$T/platforms" "$T/presets" "$T/hooks" "$T/agents" "$T/scripts"
printf 'x=$(grep --perl-regexp "a" f)\n'      > "$T/skills/a.md"
printf 'y=$(egrep -oP "b" f)\n'               > "$T/skills/b.md"
printf 'z=$(rg -P "c" f)\n'                   > "$T/skills/c.md"
printf "w=\$(rg -o '\\\\[\\\\[.*?\\\\]\\\\]' f)\n" > "$T/skills/d.md"
bash reference/check-portability.sh "$T"; echo "exit=$? (currently 0 — all four evade)"
```

- [x] **Step 2: Widen check 1**

```bash
-E '(^|[^a-zA-Z_-])(grep|egrep|fgrep|zgrep) +[^|]*(-[a-zA-Z]*P|--perl-regexp)'
```

And add a third check for PCRE via ripgrep:

```bash
echo "3. No PCRE via ripgrep (fails on rg builds without PCRE2)"
hits=$(scan_or_die "rg PCRE" -rn --include='*.md' --include='*.sh' \
  -E '(^|[^a-zA-Z_-])rg +[^|]*(-P|--pcre2)' "${SCAN[@]}") || true
```

- [x] **Step 3: Widen check 2 to non-negated captures**

Add a second pattern catching lazy/greedy dot captures between `[[` and `]]`:

```bash
-E '\\\[\\\[\(?\.[*+]'
```

Replace the content-based exclusion (`grep -v 'lib/link-extraction.sh'`) with a **path-based** one so a trailing comment mentioning that path cannot hide a defect:

```bash
| "$GREP" -v '^[^:]*lib/link-extraction\.sh:'
```

- [x] **Step 4: Verify all four probes now caught, real tree still clean**

```bash
bash reference/check-portability.sh "$T"; echo "exit=$? (expect non-zero)"
bash reference/check-portability.sh;     echo "exit=$? (expect 0)"
rm -rf "$T"
```

- [x] **Step 5: Commit**

```bash
git add reference/check-portability.sh
git commit -m "Guard: close four evasion vectors

grep --perl-regexp passed both checks despite being the exact BSD-exit-2 bug
class; egrep -oP evaded check 1; rg -P was uncovered; and a non-negated
capture passed check 2. The library exclusion is now path-based, so a
trailing comment naming that file can no longer hide a defect.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Library — fail loudly on every fault

**Files:**
- Modify: `reference/lib/link-extraction.sh`

**Interfaces:**
- Consumes: Task 1's harness.
- Produces: `LINK_EXTRACTION_VERSION=1`; all six functions validate their directory argument, surface rg runtime failures, fold locale-independently, and emit nothing on failure. `count_links_recursive` returns the same value under bash and zsh.

- [x] **Step 1: Run the harness, record which assertions fail**

```bash
bash reference/test/link-extraction.test.sh 2>&1 | tail -20
```

- [x] **Step 2: Add the contract version as the first executable line**

```bash
# Contract version. Bump on any BEHAVIOR change (fold rules, termination,
# recursion semantics). Consumers assert a minimum immediately after sourcing.
LINK_EXTRACTION_VERSION=1
```

- [x] **Step 3: Add a shared precondition helper and use it in all six functions**

```bash
_require_deps_and_dir() {   # _require_deps_and_dir <dir>
  local dir="$1"
  if ! command -v rg >/dev/null 2>&1; then
    echo "error: link-extraction requires 'rg', not found in PATH" >&2; return 1
  fi
  if ! command -v awk >/dev/null 2>&1; then
    echo "error: link-extraction requires 'awk', not found in PATH" >&2; return 1
  fi
  if [ -z "$dir" ] || [ ! -d "$dir" ]; then
    echo "error: link-extraction: not a directory: '${dir:-<empty>}'" >&2; return 1
  fi
  return 0
}
```

Each function begins `_require_deps_and_dir "$1" || return 1` and emits **nothing** on that path. A nonexistent directory must no longer be indistinguishable from an empty vault.

- [x] **Step 4: Remove `2>/dev/null` from every rg call**

Lines 48, 67, 94, 112. `command -v rg` proves existence, not health — a broken `RIPGREP_CONFIG_PATH` makes rg exit 2 on every call, and the redirect converted that to `0`. rg's no-match exit 1 is already silent, so the redirect protects nothing.

- [x] **Step 5: Fix `count_links_recursive` — mirror its working siblings**

Replace the accumulator loop (the `while` is the last stage of a pipe, so bash discards `n` in a subshell; zsh does not, hence bash `0` / zsh `9`):

```bash
count_links_recursive() {
  _require_deps_and_dir "$1" || return 1
  find "$1" -type f -name '*.md' | while IFS= read -r f; do
    _strip_fences "$f" | rg -o '\[\['
  done | wc -l | tr -d ' '
}
```

- [x] **Step 6: Make folding locale-independent**

`tr '[:upper:]' '[:lower:]'` does not fold non-ASCII under `LC_ALL=C`. Set the locale for the fold at each of the four sites:

```bash
| LC_ALL=en_US.UTF-8 tr '[:upper:]' '[:lower:]'
```

If that locale may be absent, prefer `awk '{print tolower($0)}'` under the same `LC_ALL`. Verify with the harness's non-ASCII assertion, which runs under `LC_ALL=C` deliberately.

- [x] **Step 7: Run the harness under BOTH shells**

```bash
bash reference/test/link-extraction.test.sh; echo "bash exit=$?"
zsh  reference/test/link-extraction.test.sh; echo "zsh exit=$?"
```

Expected: both exit 0, `failed=0`. Report the actual summary lines.

- [x] **Step 8: Commit**

```bash
git add reference/lib/link-extraction.sh
git commit -m "Library: fail loudly on missing deps, bad dirs, and rg faults

Adds LINK_EXTRACTION_VERSION, validates the directory argument, removes the
2>/dev/null that converted rg runtime failures into 0, fixes the
count_links_recursive subshell accumulator (bash 0 / zsh 9), and makes the
case fold locale-independent.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Consumers — propagate failure, stop bypassing the library

**Files:**
- Modify: `skill-sources/stats/SKILL.md:87` and its counter assignments
- Modify: `skill-sources/graph/SKILL.md` counter assignments
- Modify: `skills/architect/SKILL.md` counter assignments
- Modify: `skills/health/SKILL.md` counter assignments

**Interfaces:**
- Consumes: `LINK_EXTRACTION_VERSION`, `_require_deps_and_dir` behavior from Task 4.
- Produces: every consumer aborts on library failure instead of rendering a number.

- [x] **Step 1: Add the version assertion immediately after each library source**

```bash
: "${LINK_EXTRACTION_VERSION:=0}"
if [ "$LINK_EXTRACTION_VERSION" -lt 1 ]; then
  echo "error: link-extraction library is version $LINK_EXTRACTION_VERSION; this skill needs >= 1" >&2
  echo "       run /arscontexta:upgrade to refresh it" >&2
  exit 1
fi
```

- [x] **Step 2: Propagate errors past command substitution**

`VAR=$(count_links "$D")` discards the function's `return 1`. Every counter assignment becomes:

```bash
LINK_COUNT=$(count_links "$NOTES_DIR") || {
  echo "error: link counting failed; refusing to report a number" >&2; exit 1; }
```

Apply to every counter in all four files.

- [x] **Step 3: Route `stats:87` through the library**

Replace the inline `rg ... 2>/dev/null` TOPIC_COUNT block — it bypasses the library's dependency check and dropped trim + fold, so `[[Hub-Topic]]` and `[[hub-topic]]` counted as two topics:

```bash
TOPIC_COUNT=$(rg -oNI '^\s*-\s*"\[\[([^\]|#]+)' -r '$1' "$NOTES_DIR"/*.md \
  | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
  | LC_ALL=en_US.UTF-8 tr '[:upper:]' '[:lower:]' | sort -u | wc -l | tr -d ' ') || {
  echo "error: topic counting failed; refusing to report a number" >&2; exit 1; }
```

- [x] **Step 4: Verify no consumer renders a number after a dependency failure**

```bash
FIX=$(mktemp -d); mkdir -p "$FIX/notes"; printf 'A: [[one]]\n' > "$FIX/notes/a.md"
bash -c 'export PATH=/usr/bin:/bin
. reference/lib/link-extraction.sh
LINK_COUNT=$(count_links '"$FIX"'/notes) || { echo "aborted correctly"; exit 1; }
echo "LEAKED A NUMBER: $LINK_COUNT"'
```

Expected: `aborted correctly`. Any output containing a number is a failure of this task.

- [x] **Step 5: Guard + harness still clean**

```bash
bash reference/check-portability.sh; echo "exit=$?"
bash reference/test/link-extraction.test.sh; echo "exit=$?"
```

- [x] **Step 6: Commit**

```bash
git add skill-sources/stats/SKILL.md skill-sources/graph/SKILL.md skills/architect/SKILL.md skills/health/SKILL.md
git commit -m "Consumers: assert library version and abort instead of reporting

VAR=\$(fn) discarded the library's return 1, so a dependency error still
rendered 'Dangling: 0'. stats:87 additionally bypassed the library entirely
and had dropped trim+fold.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Resolve the flat/recursive split

**Files:**
- Modify: `skill-sources/stats/SKILL.md`, `skill-sources/graph/SKILL.md`, `skills/architect/SKILL.md`
- Modify: `reference/lib/link-extraction.sh` (header contract)

**Interfaces:**
- Consumes: Task 4's library.
- Produces: all five consumers agree on the same vault.

- [x] **Step 1: Demonstrate the disagreement**

```bash
V=$(mktemp -d); mkdir -p "$V/notes/sub"
printf 'Top: [[buried]]\n' > "$V/notes/top.md"
printf -- '---\ntitle: buried\n---\nbody\n' > "$V/notes/sub/buried.md"
bash -c '. reference/lib/link-extraction.sh
IF=$(existing_note_index '"$V"'/notes); IR=$(existing_note_index_recursive '"$V"'/notes)
echo "flat:      $(extract_link_targets '"$V"'/notes | while read -r n; do [ -n "$n" ] && ! printf "%s\n" "$IF" | /usr/bin/grep -qxF "$n" && echo "DANGLING:$n"; done)"
echo "recursive: $(extract_link_targets_recursive '"$V"'/notes | while read -r n; do [ -n "$n" ] && ! printf "%s\n" "$IR" | /usr/bin/grep -qxF "$n" && echo "DANGLING:$n"; done)"'
```

Expected today: flat reports `DANGLING:buried`, recursive reports nothing.

- [x] **Step 2: Switch the three flat consumers to the recursive variants**

Recursive is correct: `health` and `validate-kernel` already use it, nothing forbids subdirectories, and a vault that nests notes gets false FAILs from the flat consumers. In `stats`, `graph`, and `architect`, replace `count_links` → `count_links_recursive`, `extract_link_targets` → `extract_link_targets_recursive`, `existing_note_index` → `existing_note_index_recursive`.

- [x] **Step 3: Record the decision in the library header**

Replace the "FLAT vs RECURSIVE" block with:

```bash
# All SHIPPED consumers use the _recursive variants: a vault may nest notes,
# and a flat scan silently under-reports rather than failing. The flat
# variants remain for callers that deliberately want a single directory —
# they are NOT the default. Choosing flat where recursive is meant produces a
# plausible wrong number, so prefer recursive unless you can justify otherwise.
```

- [x] **Step 4: Verify agreement**

Re-run Step 1. Both lines must now be empty. Then guard + harness clean.

- [x] **Step 5: Commit**

```bash
git add skill-sources/stats/SKILL.md skill-sources/graph/SKILL.md skills/architect/SKILL.md reference/lib/link-extraction.sh
git commit -m "Unify consumers on recursive scanning

stats/graph/architect scanned flat while health/validate-kernel scanned
recursively, so the same vault got opposite dangling verdicts and health
escalates any dangling to FAIL.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

> **Natural stopping point.** Tasks 1–6 close every open instance of the bug class inside the plugin repo and are independently shippable. Tasks 7–9 change how generated vaults obtain the library and require a generator change.

---

### Task 7: Vault-tier sourcing — copy, don't reference

**Files:**
- Modify: `skill-sources/stats/SKILL.md`, `skill-sources/graph/SKILL.md` (source blocks)

**Interfaces:**
- Consumes: `LINK_EXTRACTION_VERSION` from Task 4.
- Produces: templates that source `$VAULT_ROOT/ops/lib/link-extraction.sh`. Task 8 makes setup put the file there.

- [x] **Step 1: Prove the current design is broken**

```bash
cd /Users/controlroom/second-brain && bash -c 'echo "CLAUDE_PLUGIN_ROOT=[${CLAUDE_PLUGIN_ROOT:-UNSET}]"
L="${CLAUDE_PLUGIN_ROOT:-}/reference/lib/link-extraction.sh"; echo "resolves to: $L"
[ -r "$L" ] && echo READABLE || echo "NOT READABLE — every /stats run fails"'
```

- [x] **Step 2: Replace the source block in both templates**

`ops/` is a fixed directory name (written literally throughout `skills/setup/SKILL.md`), so this path is safe to hardcode. The lookup matches `hooks/scripts/read_config.sh:20` exactly — do not invent a third mechanism.

```bash
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
  echo "error: $LINK_LIB is version $LINK_EXTRACTION_VERSION; this skill needs >= 1" >&2
  echo "       run /arscontexta:upgrade to refresh it" >&2
  exit 1
fi
```

Leave `skills/architect/SKILL.md` and `skills/health/SKILL.md` alone — they are plugin-tier and source from the plugin, where the file genuinely lives.

- [x] **Step 3: Simulate a generated vault end-to-end**

```bash
V=$(mktemp -d); mkdir -p "$V/notes" "$V/ops/lib"
printf 'A: [[one]]\nB: [[two]]\n' > "$V/notes/a.md"
cp reference/lib/link-extraction.sh "$V/ops/lib/"
cd "$V" && bash -c 'VAULT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
. "$VAULT_ROOT/ops/lib/link-extraction.sh"
echo "sourced ok, version=$LINK_EXTRACTION_VERSION, count=$(count_links_recursive notes)"'
```

Expected: `sourced ok, version=1, count=2`.

- [x] **Step 4: Verify the missing-library path is loud**

```bash
rm "$V/ops/lib/link-extraction.sh"
cd "$V" && bash -c 'VAULT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LINK_LIB="$VAULT_ROOT/ops/lib/link-extraction.sh"
if [ -r "$LINK_LIB" ]; then . "$LINK_LIB"; else echo "error: not found at $LINK_LIB" >&2; exit 1; fi' 2>&1
echo "exit=$? (expect non-zero)"
```

- [x] **Step 5: Commit**

```bash
git add skill-sources/stats/SKILL.md skill-sources/graph/SKILL.md
git commit -m "Vault-tier skills source the library from ops/lib/

CLAUDE_PLUGIN_ROOT is unset in a shell, so the previous form resolved to an
absolute path from filesystem root and every generated /stats and /graph hit
the failure branch. Generated vaults are self-contained — they hold their own
copies of hooks — so the library is copied too, and located with the same
mechanism read_config.sh already uses.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Generator — setup copies the library into the vault

**Files:**
- Modify: `skills/setup/SKILL.md` (the step that writes `.claude/hooks/`)

**Interfaces:**
- Consumes: Task 7's expected path.
- Produces: freshly generated vaults contain `ops/lib/link-extraction.sh`.

- [x] **Step 1: Locate the hook-writing step**

```bash
/usr/bin/grep -n '\.claude/hooks' skills/setup/SKILL.md | head -5
```

- [x] **Step 2: Add the library copy alongside it**

In the same generation step, instruct: create `ops/lib/` and copy `${CLAUDE_PLUGIN_ROOT}/reference/lib/link-extraction.sh` into it. Setup is a plugin-tier skill, so `${CLAUDE_PLUGIN_ROOT}` is available to it — this is the one place that reference is correct.

Add to the generated-artifacts table (near line 434) a row: `| Link library | Always | ops/lib/link-extraction.sh |`.

- [x] **Step 3: Make `/arscontexta:upgrade` refresh the copy**

In `skills/upgrade/SKILL.md`, add a step that compares the vault's `ops/lib/link-extraction.sh` `LINK_EXTRACTION_VERSION` against the plugin's, refreshes when they differ, and **reports the replacement** rather than overwriting silently.

- [x] **Step 4: Make `/arscontexta:health` surface drift**

In `skills/health/SKILL.md`, add a check that reads both versions and FAILs on mismatch or a missing vault copy, so drift is visible without waiting for a skill to break.

- [x] **Step 5: Verify against the real vault**

```bash
ls -la /Users/controlroom/second-brain/ops/lib/link-extraction.sh 2>&1
```

Expected: absent (that vault predates this change). Record it — it is what `/arscontexta:upgrade` must repair, and confirms the upgrade path is needed rather than theoretical.

- [x] **Step 6: Commit**

```bash
git add skills/setup/SKILL.md skills/upgrade/SKILL.md skills/health/SKILL.md
git commit -m "Generator copies the link library into generated vaults

Generated vaults are self-contained and never reference the plugin. setup
now writes ops/lib/link-extraction.sh beside the hooks it already copies;
upgrade refreshes it and reports the replacement; health FAILs on version
drift so a stale copy cannot silently compute wrong answers.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Health scope, graph fold, and CI

**Files:**
- Modify: `skills/health/SKILL.md:160` (contract) and `:175-182`
- Modify: `skill-sources/graph/SKILL.md:161-162`
- Modify: `.github/workflows/checks.yml`

**Interfaces:**
- Consumes: everything above.
- Produces: CI that executes the library under bash and zsh.

- [x] **Step 1: Reconcile health's scope contract**

`:160` says "Every wiki link in every file" while the code now scans only `{vocabulary.notes}`. Links in `inbox/` and `self/` go unchecked; links *to* files outside notes/ false-FAIL. Change the documented contract to match the code — narrower and symmetric — and state the limitation explicitly:

```markdown
Scope: wiki links within {vocabulary.notes}. Links in other spaces
({vocabulary.inbox}, self/) are not checked, and links pointing outside
{vocabulary.notes} will report as dangling.
```

- [x] **Step 2: Restore trim + fold at graph's triangles block**

`:161-162` dropped both, so closure detection miscomputes on case variants while the dangling check in the same file folds:

```bash
  LINKS=$(awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$f" \
    | rg -o '\[\[([^\]|#]+)' -r '$1' \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | LC_ALL=en_US.UTF-8 tr '[:upper:]' '[:lower:]' | sort -u)
```

- [x] **Step 3: Wire the harness into CI under both shells**

```yaml
      - name: Install ripgrep and zsh
        run: sudo apt-get update && sudo apt-get install -y ripgrep zsh
      - name: Behavioral tests (bash)
        run: bash reference/test/link-extraction.test.sh
      - name: Behavioral tests (zsh)
        run: zsh reference/test/link-extraction.test.sh
```

The zsh job is not redundant: two defects closed by this plan were bash/zsh forks, and CI running only bash would not have seen either.

- [x] **Step 4: Full verification sweep**

```bash
bash reference/check-portability.sh; echo "guard=$?"
bash reference/check-portability.sh /nonexistent; echo "guard-on-bad-root=$? (expect non-zero)"
bash reference/test/link-extraction.test.sh; echo "tests-bash=$?"
zsh  reference/test/link-extraction.test.sh; echo "tests-zsh=$?"
for f in reference/validate-kernel.sh reference/check-portability.sh reference/lib/link-extraction.sh reference/test/link-extraction.test.sh; do bash -n "$f" || echo "SYNTAX FAIL $f"; done
```

Expected: `0`, non-zero, `0`, `0`, no syntax failures.

- [x] **Step 5: Prove the harness catches a reintroduction**

```bash
cp reference/lib/link-extraction.sh /tmp/lib.bak
/usr/bin/sed -i '' 's|rg -o .\[\[([^\]|#]+).|rg -o "\\[\\[([^\\]]+)"|' reference/lib/link-extraction.sh
bash reference/test/link-extraction.test.sh >/dev/null 2>&1; echo "regressed=$? (expect 1)"
cp /tmp/lib.bak reference/lib/link-extraction.sh; rm -f /tmp/lib.bak
bash reference/test/link-extraction.test.sh >/dev/null 2>&1; echo "restored=$? (expect 0)"
git diff --quiet reference/lib/link-extraction.sh && echo "byte-clean"
```

A harness never seen red after the fixes is not known to work.

- [x] **Step 6: Commit**

```bash
git add skills/health/SKILL.md skill-sources/graph/SKILL.md .github/workflows/checks.yml
git commit -m "Reconcile health scope, restore graph fold, run behavioral tests in CI

CI previously executed no library code. It now runs the harness under bash
and zsh — two defects closed by this plan were shell forks that a bash-only
run could not see.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

## Self-Review

**Spec coverage.** §1.1 → T2.2; §1.2 → T2.3/2.5; §1.3 → T3; §2.1 → T4.4; §2.2 → T5.3; §2.3 → T5.2; §2.4 → T4.3; §2.5 → T4.5; §3.1 → T6; §3.2a → T7 (vault tier) + T8 (generator); §3.2b → T4.2, T5.1, T8.3, T8.4; §3.2c → deferred by design, no task; §3.3 → T4.6; §3.4 → T9.1; §3.5 → T9.2; Phase 4 → T1 + T9.3. **No gaps.**

**Placeholders.** None: every code step contains runnable code, and the source block is repeated in full at T5.1 and T7.2 rather than cross-referenced.

**Type consistency.** `LINK_EXTRACTION_VERSION` (integer, ≥1) is defined T4.2 and asserted T5.1, T7.2, T8.3, T8.4. `_require_deps_and_dir <dir> → rc` defined T4.3, used by all six functions. `count_links_recursive` / `extract_link_targets_recursive` / `existing_note_index_recursive` are the names adopted repo-wide at T6.2. `VAULT_ROOT` and `LINK_LIB` are used consistently at T7.2.

**Ordering dependency.** Task 1 must precede 4–9 (it is their pass/fail gate). Task 4 must precede 5 (version constant and helper). Task 7 must precede 8 (defines the path setup writes to). Tasks 1–6 are shippable without 7–9.
