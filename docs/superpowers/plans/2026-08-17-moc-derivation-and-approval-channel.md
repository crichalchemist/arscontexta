# MOC Derivation and Approval Channel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `/rethink`'s stateful MOC edit with an idempotent derivation from frontmatter, and restructure its approval gates so a run without an interactive channel completes instead of stalling.

**Architecture:** A new shell library `reference/lib/moc-sync.sh` derives a status MOC (section membership, wiki-links, counts) from note frontmatter, preserving existing human-visible summaries and reporting — never silently dropping — any note it cannot place. `skill-sources/rethink/SKILL.md` calls it behind a fail-loud version guard instead of instructing an agent to move entries by hand, and its two blocking approval gates are redrawn so frontmatter status edits proceed while every side effect routes to a persisted artifact for separate approval.

**Tech Stack:** bash (POSIX-leaning, must also run under zsh), `awk`, `sed`, `/usr/bin/grep`, `find`; existing libraries `reference/lib/frontmatter.sh` and `reference/lib/queue-edit.sh` (v2, provides `queue_yaml`); test suites are hand-rolled bash assertion counters following `reference/test/queue-edit.test.sh`.

**Spec:** `docs/superpowers/specs/2026-08-17-hub-derivation-and-approval-channel-design.md`

**Revision note.** This plan was adversarially reviewed on 2026-08-17 (8 Critical, 5 Major, 6 Minor) and rewritten. The first version dictated a library that was **dead under zsh three independent ways** and whose write path **destroyed the MOC at rc 0** on a render failure. Both are fixed below, and the mechanisms are recorded in the task text rather than silently corrected, because they are the defect classes this plan exists to remove.

## Global Constraints

Every task's requirements implicitly include this section. Values are copied from the spec and from `CLAUDE.md`.

- **Do not write `platforms/shared/skill-blocks/`.** It is `cksum`-frozen at any depth by `check-portability.sh` check 4.
- **Never `git add docs/field-intel-2026-08-15.md` or `docs/field-intel-2026-08-17.md`.** Both are untracked by design. Stage by explicit path — never `git add -A` or `git add .`.
- **Canonical vocabulary, not vault dialect.** Every new identifier uses **MOC** (`reference/vocabulary-transforms.md:17`), never "hub". Library function names are not vocabulary-substituted, so a dialect name ships verbatim into every generated vault.
- **`status`, `path`, `options`, `argv` and `PATH` are RESERVED — never declare or assign them in library code.** In zsh, `status` is a **read-only special variable** and assigning it is a *fatal, script-aborting* error, not a warning. Verify before trusting this:
  ```bash
  zsh -c 'f(){ local status="x"; echo reached; }; f; echo after'   # prints only: f: read-only variable: status
  bash -c 'f(){ local status="x"; echo reached; }; f; echo after'  # prints: reached / after
  ```
- **Never rely on word-splitting an unquoted variable.** zsh does not word-split parameter expansions:
  ```bash
  for sh in bash zsh; do $sh -c 'M="a b c"; n(){ echo "$#"; }; n $M'; done   # bash: 3, zsh: 1
  ```
  The map is therefore passed as **one quoted string** and split inside the library by `_moc_each_pair`.
- **In zsh, a bare `local x` inside a loop PRINTS `x=value` on the second and later iterations.** Always give an initialiser (`local x=""`) or hoist the declaration above the loop. An unassigned re-declaration corrupts stdout — which for `moc_render` means corrupting the rendered MOC.
- **`MOC_SYNC_VERSION` starts at `1`.** Consumer fences guard `[ "${MOC_SYNC_VERSION:-0}" -lt 1 ]`.
- **The section map is a pinned input** (spec Decision 11). Task 1 fixes it.
- **Entry order within a section is ascending by filename under `LC_ALL=C`** (spec Decision 12).
- **Every test suite must pass under both `bash` and `zsh`.** CI runs both.
- **Run gates UNPIPED when the rc matters.** `false | tail -1; echo $?` yields `0`.
- **Use `/usr/bin/grep`, never bare `grep`** — it is intercepted and rewritten here.
- **Adding a check has a mandatory documentation cost.** Task 9 updates `CLAUDE.md`'s tree-side numerals in the same commit; the `main`-side numeral takes a documented post-merge correction.
- **`~/second-brain` is READ-ONLY** throughout. Fixtures go under `mktemp -d`.

---

## File Structure

| File | Responsibility |
|---|---|
| `reference/lib/moc-sync.sh` (create) | The derivation: map splitting, section mapping, entry harvesting, rendering, guarded write. Sole owner of MOC output format. |
| `reference/test/moc-sync.test.sh` (create) | Behavioral tests, both shells. |
| `reference/test/fence-isolation.test.sh` (modify) | Its healthy fixture must copy `moc-sync.sh` into `ops/lib/`, or Task 5's fence fails the gate. |
| `skill-sources/rethink/SKILL.md` (modify) | `:329` becomes a rebuild call; approval gates redrawn by act; proposal phase terminates in an artifact. |
| `skills/health/SKILL.md` (modify) | Category 9 gains a `moc-sync` check via the existing `check_lib` helper. |
| `.github/workflows/checks.yml` (modify) | Two steps for the new suite (bash + zsh). |
| `CLAUDE.md` (modify) | Five numeral/prose edits — see Task 9. |

---

### Task 1: Map splitting, section resolution, and the pinned maps

Foundation for rule 6. Three section vocabularies are live in the field simultaneously, and any single map silently drops the others' notes — 16 notes today (2 dissolved observations, 8 promoted + 6 archived tensions, all measured). This task makes an unmappable status a reportable event rather than an absence.

**Files:**
- Create: `reference/lib/moc-sync.sh`
- Create: `reference/test/moc-sync.test.sh`

**Interfaces:**
- Consumes: nothing (first task).
- Produces:
  - `MOC_SYNC_VERSION` — integer, `1`.
  - `_moc_each_pair <map-string>` — prints one `status:Section` pair per line. Portable: splits by parameter expansion, never by word-splitting.
  - `moc_section_for <status> <map-string>` — prints the section name, rc 0. Prints nothing, **rc 2**, when off-map. rc 1 on usage error. **The map is ONE quoted argument**, not a splatted list.
  - `MOC_MAP_OBSERVATIONS`, `MOC_MAP_TENSIONS` — space-separated map strings. Each *pair* is space-free; the string is not.

- [ ] **Step 1: Write the failing test**

Create `reference/test/moc-sync.test.sh`:

```bash
#!/bin/bash
# moc-sync.test.sh — behavioral tests for reference/lib/moc-sync.sh.
#
# Runs under bash AND zsh; CI runs both. Assertions pin the contract the library's
# header argues for, because this repo's dominant failure mode is a function that
# exits 0 having done nothing.
#
# EVERY assertion goes through ok(), including loop iterations. An unconditional
# `PASS=$((PASS+N))` counts a failing iteration as both passed and failed, which is
# the same inflated-total defect CLAUDE.md records for the kernel validator's
# "PASS: 15".

LIB="$(cd "$(dirname "$0")/../lib" && pwd)/moc-sync.sh"
FMLIB="$(cd "$(dirname "$0")/../lib" && pwd)/frontmatter.sh"
PASS=0; FAIL=0

ok() { # ok <label> <expected> <actual>
  if [ "$2" = "$3" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); printf 'FAIL %s\n  expected: [%s]\n  actual:   [%s]\n' "$1" "$2" "$3"; fi
}

# shellcheck source=/dev/null
. "$FMLIB" || { echo "FAIL: cannot source $FMLIB"; exit 1; }
# shellcheck source=/dev/null
. "$LIB"   || { echo "FAIL: cannot source $LIB";   exit 1; }

MAP_OBS="open:Open implemented:Implemented archived:Archived"

# --- _moc_each_pair: splitting must NOT depend on word-splitting ------------
ok "each_pair yields 3 pairs" "3" "$(_moc_each_pair "$MAP_OBS" | /usr/bin/grep -c .)"
ok "each_pair yields the first pair" "open:Open" "$(_moc_each_pair "$MAP_OBS" | /usr/bin/sed -n 1p)"
ok "each_pair yields the last pair" "archived:Archived" "$(_moc_each_pair "$MAP_OBS" | /usr/bin/sed -n 3p)"
ok "each_pair on one pair yields one" "1" "$(_moc_each_pair "open:Open" | /usr/bin/grep -c .)"
ok "each_pair on empty yields none" "0" "$(_moc_each_pair "" | /usr/bin/grep -c .)"

# --- moc_section_for -------------------------------------------------------
ok "maps a known status" "Open" "$(moc_section_for open "$MAP_OBS")"
ok "maps a later status" "Archived" "$(moc_section_for archived "$MAP_OBS")"

# An off-map status must be rc 2 AND print nothing. rc alone is insufficient:
# a function printing a guessed section and returning 2 would pass an rc-only test.
off_out=$(moc_section_for dissolved "$MAP_OBS"); off_rc=$?
ok "off-map status returns rc 2" "2" "$off_rc"
ok "off-map status prints nothing" "" "$off_out"

# Usage errors are rc 1, distinct from rc 2 — a caller must distinguish "this vault
# holds an unmapped status" from "I called this wrong".
moc_section_for "" "$MAP_OBS" >/dev/null 2>&1; ok "empty status is rc 1" "1" "$?"
moc_section_for open ""       >/dev/null 2>&1; ok "empty map is rc 1"    "1" "$?"

# --- the pinned maps ------------------------------------------------------
ok "observations map is pinned" \
   "open:Open implemented:Implemented archived:Archived dissolved:Dissolved" \
   "$MOC_MAP_OBSERVATIONS"
ok "tensions map is pinned" \
   "open:Open blocked:Blocked implemented:Implemented promoted:Promoted archived:Archived dissolved:Dissolved resolved:Resolved" \
   "$MOC_MAP_TENSIONS"

# Every status the field vault holds must be mappable — rule 6's whole point.
# Counted through ok(), so the totals stay honest.
for s in open implemented archived dissolved; do
  moc_section_for "$s" "$MOC_MAP_OBSERVATIONS" >/dev/null 2>&1
  ok "observations map places '$s'" "0" "$?"
done
for s in open blocked implemented promoted archived dissolved resolved; do
  moc_section_for "$s" "$MOC_MAP_TENSIONS" >/dev/null 2>&1
  ok "tensions map places '$s'" "0" "$?"
done

printf '\nmoc-sync: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run it to confirm it fails for the stated reason**

```bash
bash reference/test/moc-sync.test.sh
```

Expected: `FAIL: cannot source .../moc-sync.sh`, exit 1 — the file does not exist. **If it fails any other way, stop and read the error.**

- [ ] **Step 3: Write the implementation**

Create `reference/lib/moc-sync.sh`:

```bash
#!/bin/bash
# moc-sync.sh — derive a status MOC (e.g. ops/observations.md) from note frontmatter.
#
# WHY THIS EXISTS: skill-sources/rethink/SKILL.md used to instruct an agent to "move
# entries between Pending/Promoted/Blocked/Archived/Resolved/Dissolved sections". That is
# incremental maintenance of a cache, and it can only be correct if every status change
# flows through the mover. Four templates write the notes a status MOC indexes and only one
# touched the MOC, so it diverged at the rate of note activity — three times in the field,
# most recently within 72 hours of a rebuild. Deriving is idempotent: running it IS the
# repair and running it twice is a no-op.
#
# NAMED MOC, NOT HUB. "Hub" is the field vault's dialect; the canonical term is MOC
# (reference/vocabulary-transforms.md:17). A library ships verbatim into every generated
# vault's ops/lib/ and its function names are NOT vocabulary-substituted.
#
# TWO ZSH RULES THIS FILE OBEYS, both of which killed its first draft:
#   1. `status` is a READ-ONLY SPECIAL VARIABLE in zsh and assigning it aborts the script
#      outright. Nothing here declares or assigns `status`, `path`, `options` or `argv`.
#   2. A bare `local x` re-declared inside a loop PRINTS `x=value` from the second
#      iteration onward — straight into this file's stdout, i.e. into the rendered MOC.
#      Every `local` inside a loop here carries an initialiser.
MOC_SYNC_VERSION=1

# THE SECTION MAP IS PINNED HERE, NOT CHOSEN BY CALLERS. Three vocabularies are live in the
# field at once: rethink's own six-name instruction, the observations MOC's "canonical
# three", and a tensions MOC carrying a literal "Non-canonical status: resolved" heading. A
# rebuild under any one of them silently drops the others' notes — measured 2026-08-17:
# 2 dissolved observations, 8 promoted + 6 archived tensions. Silent omission of a note that
# exists is the defect this library removes, so every status a vault can hold gets a section.
MOC_MAP_OBSERVATIONS="open:Open implemented:Implemented archived:Archived dissolved:Dissolved"
MOC_MAP_TENSIONS="open:Open blocked:Blocked implemented:Implemented promoted:Promoted archived:Archived dissolved:Dissolved resolved:Resolved"

# _moc_each_pair <map-string> -> one "status:Section" pair per line.
#
# THE MAP IS ALWAYS ONE QUOTED ARGUMENT AND IS SPLIT HERE, never by word-splitting at a
# call site. zsh does not word-split unquoted parameter expansions, so `f $MAP` passes ONE
# argument under zsh and three under bash. The first draft of this library relied on that
# splitting, so under zsh its shipped fence processed only the first pair and silently
# dropped every non-open note at rc 0.
_moc_each_pair() {
  local rest="$1" pair=""
  while [ -n "$rest" ]; do
    pair="${rest%% *}"
    [ -n "$pair" ] && printf '%s\n' "$pair"
    case "$rest" in
      *" "*) rest="${rest#* }" ;;
      *)     rest="" ;;
    esac
  done
}

# moc_section_for <status> <map-string> -> section name
#   rc 0 = mapped (section printed)
#   rc 2 = off-map (NOTHING printed — the caller reports it per rule 6)
#   rc 1 = usage error
# rc 2 is deliberately distinct from rc 1: collapsing them makes an off-map note
# indistinguishable from a bug in the caller.
moc_section_for() {
  local want="$1" map="$2" pair=""
  if [ -z "$want" ] || [ -z "$map" ]; then
    echo "error: moc-sync: moc_section_for needs <status> <map-string>" >&2
    return 1
  fi
  while IFS= read -r pair; do
    [ -n "$pair" ] || continue
    if [ "${pair%%:*}" = "$want" ]; then
      printf '%s\n' "${pair#*:}"
      return 0
    fi
  done <<EOF
$(_moc_each_pair "$map")
EOF
  return 2
}
```

- [ ] **Step 4: Run under both shells**

```bash
bash reference/test/moc-sync.test.sh; echo "bash rc=$?"
zsh  reference/test/moc-sync.test.sh; echo "zsh  rc=$?"
```

Expected: **`24 passed, 0 failed`**, rc=0 under **both**. There is no shell-specific remedy to apply: the map is a single quoted argument at every call site and no reserved name is assigned, so bash and zsh must agree. **If zsh prints `read-only variable` or a bare `x=value` line, a reserved name or an uninitialised in-loop `local` has crept in — fix the library, not the test.**

- [ ] **Step 5: Commit**

```bash
git add reference/lib/moc-sync.sh reference/test/moc-sync.test.sh
git commit -m "feat: moc-sync map splitting and status resolution

Pins the canonical section map for observation and tension notes, and makes an
unmappable status a distinguishable rc 2 rather than an absence. Three section
vocabularies are live in the field simultaneously; any single map drops 16
existing notes silently.

The map is one quoted argument split inside the library, because zsh does not
word-split unquoted parameter expansions — relying on that splitting would make
every caller pass a one-pair map under zsh. No reserved name (status, path,
options, argv) is assigned: in zsh, assigning \`status\` aborts the script."
```

---

### Task 2: Harvest existing entries and render sections

Membership, wiki-links, counts and ordering. Summaries carry forward here; Task 3 adds the warnings.

**Files:**
- Modify: `reference/lib/moc-sync.sh`
- Modify: `reference/test/moc-sync.test.sh`

**Interfaces:**
- Consumes: `_moc_each_pair`, `moc_section_for`, `MOC_MAP_OBSERVATIONS`; `frontmatter_field` from `frontmatter.sh`.
- Produces:
  - `moc_harvest_entries <moc-file>` — prints `slug<TAB>summary` per entry, file order. Missing/entry-free file → nothing, rc 0.
  - `moc_render <notes-dir> <map-string>` — prints the MOC body to stdout, rc 0; rc 1 on a bad directory or usage error. Reads `$MOC_SYNC_EXISTING` (optional) for summary carry-forward.

- [ ] **Step 1: Write the failing tests**

Append before the final `printf`:

```bash
# --- fixture --------------------------------------------------------------
FIX=$(mktemp -d)
trap 'rm -rf "$FIX"' EXIT
mkdir -p "$FIX/observations"

mknote() { # mknote <slug> <status> <description>
  printf -- '---\ndescription: %s\ntype: observation\nstatus: %s\n---\n\nbody\n' \
    "$3" "$2" > "$FIX/observations/$1.md"
}
mknote zebra-note   open        "Zebra description here"
mknote alpha-note   open        "Alpha description here"
mknote middle-note  implemented "Middle description here"

cat > "$FIX/observations.md" <<'EOF'
# Observations

## Open (1)
- [[alpha-note]] — Alpha description here
- [[zebra-note]] — Zebra description that was EDITED
EOF

# --- moc_harvest_entries --------------------------------------------------
ok "harvest finds both entries" "2" "$(moc_harvest_entries "$FIX/observations.md" | /usr/bin/grep -c .)"
ok "harvest carries the prose" "Zebra description that was EDITED" \
   "$(moc_harvest_entries "$FIX/observations.md" | /usr/bin/awk -F'\t' '$1=="zebra-note"{print $2}')"
# PAIRED WITH A POSITIVE: an empty-expectation assertion passes when the function does
# not exist, so on its own it certifies nothing.
ok "harvest of a missing file is empty" "" "$(moc_harvest_entries "$FIX/nope.md" 2>/dev/null)"
moc_harvest_entries "$FIX/nope.md" >/dev/null 2>&1; ok "harvest of a missing file is rc 0" "0" "$?"

# --- moc_render -----------------------------------------------------------
BODY=$(MOC_SYNC_EXISTING="$FIX/observations.md" moc_render "$FIX/observations" "$MOC_MAP_OBSERVATIONS" 2>/dev/null)

ok "Open heading counts 2" "## Open (2)" "$(printf '%s\n' "$BODY" | /usr/bin/grep -m1 '^## Open')"
ok "Implemented heading counts 1" "## Implemented (1)" \
   "$(printf '%s\n' "$BODY" | /usr/bin/grep -m1 '^## Implemented')"

# ORDER IS ASCENDING BY FILENAME (spec Decision 12).
ok "entries sort by filename" "alpha-note zebra-note" \
   "$(printf '%s\n' "$BODY" | /usr/bin/awk '/^## Open/{f=1;next} /^## /{f=0} f&&/^- \[\[/' \
      | /usr/bin/sed 's/^- \[\[//; s/\]\].*//' | /usr/bin/tr '\n' ' ' | /usr/bin/sed 's/ $//')"

ok "existing prose is carried forward" "Zebra description that was EDITED" \
   "$(printf '%s\n' "$BODY" | /usr/bin/sed -n 's/^- \[\[zebra-note\]\] — //p')"
ok "new entry is seeded from description" "Middle description here" \
   "$(printf '%s\n' "$BODY" | /usr/bin/sed -n 's/^- \[\[middle-note\]\] — //p')"

# EVERY MAPPED SECTION IS EMITTED, even at zero: an absent section cannot be
# distinguished from "no notes have that status".
ok "empty sections are emitted at 0" "## Dissolved (0)" \
   "$(printf '%s\n' "$BODY" | /usr/bin/grep -m1 '^## Dissolved')"

# ZSH GUARD: an uninitialised in-loop `local` prints `x=value` into stdout. Assert the
# rendered body contains no such line — this is the only assertion that catches it, and
# it catches it in the output rather than in a shell-version check.
ok "render emits no stray variable lines" "0" \
   "$(printf '%s\n' "$BODY" | /usr/bin/grep -cE '^[a-z_]+=')"

# A bad directory is rc 1 and prints an error.
moc_render "$FIX/no-such-dir" "$MOC_MAP_OBSERVATIONS" >/dev/null 2>&1
ok "bad notes-dir is rc 1" "1" "$?"
```

- [ ] **Step 2: Run to confirm the new assertions fail**

```bash
bash reference/test/moc-sync.test.sh
```

Expected: Task 1's 24 still pass; **`9 failed`** of the 12 new assertions. Three pass before implementation and that is expected, not a mistake: `harvest of a missing file is empty` (empty vs empty), `render emits no stray variable lines` (an empty `$BODY` has none), and `bad notes-dir is rc 1` (an undefined function returns 127 — *no*, it returns 127 not 1, so this one fails; the two vacuous passes are the first and second). **The number to see is 9, not 10.**

- [ ] **Step 3: Implement both functions**

Append to `reference/lib/moc-sync.sh`:

```bash
# moc_harvest_entries <moc-file> -> "slug<TAB>summary" per entry, file order.
# A missing file is not an error: a vault whose MOC does not exist yet is a legitimate
# first-run state, and the rebuild creates it.
moc_harvest_entries() {
  local file="$1"
  [ -r "$file" ] || return 0
  /usr/bin/awk '
    match($0, /^[[:space:]]*-[[:space:]]*\[\[[^]|#]+\]\]/) {
      line = $0
      slug = line
      sub(/^[[:space:]]*-[[:space:]]*\[\[/, "", slug)
      sub(/\]\].*$/, "", slug)
      rest = line
      sub(/^[^]]*\]\][[:space:]]*/, "", rest)
      sub(/^(—|--)[[:space:]]*/, "", rest)
      printf "%s\t%s\n", slug, rest
    }
  ' "$file"
}

# moc_render <notes-dir> <map-string> -> the MOC body on stdout.
#
# Pure with respect to files: writes nothing, so a caller can inspect a candidate render
# before committing to it. rc 1 on a bad directory — rebuild_status_moc DEPENDS on that rc
# and its first draft ignored it, which destroyed the MOC at rc 0.
#
# Every `local` below that lives inside a loop carries an initialiser. Under zsh a bare
# re-declaration prints `name=value` on stdout, i.e. into the MOC.
moc_render() {
  local dir="$1" map="$2"
  if [ ! -d "$dir" ]; then
    echo "error: moc-sync: not a directory: '$dir'" >&2
    return 1
  fi
  if [ -z "$map" ]; then
    echo "error: moc-sync: moc_render needs <notes-dir> <map-string>" >&2
    return 1
  fi

  local existing="${MOC_SYNC_EXISTING:-}" harvest=""
  [ -n "$existing" ] && harvest=$(moc_harvest_entries "$existing")

  local notes pair="" sec="" st_want="" note="" st="" slug="" desc="" summary="" lines="" count=0
  notes=$(LC_ALL=C find -H "$dir" -type f -name '*.md' 2>/dev/null | LC_ALL=C sort)

  while IFS= read -r pair; do
    [ -n "$pair" ] || continue
    st_want="${pair%%:*}"
    sec="${pair#*:}"
    lines=""
    count=0

    while IFS= read -r note; do
      [ -n "$note" ] || continue
      st=$(frontmatter_field "$note" status 2>/dev/null)
      [ "$st" = "$st_want" ] || continue
      slug=$(basename "$note" .md)

      summary=$(printf '%s\n' "$harvest" | /usr/bin/awk -F'\t' -v s="$slug" '$1==s{print $2; exit}')
      if [ -z "$summary" ]; then
        desc=$(frontmatter_field "$note" description 2>/dev/null)
        summary="$desc"
      fi
      lines="${lines}- [[${slug}]] — ${summary}
"
      count=$((count + 1))
    done <<INNER
$notes
INNER

    printf '## %s (%d)\n' "$sec" "$count"
    [ "$count" -gt 0 ] && printf '%s' "$lines"
    printf '\n'
  done <<OUTER
$(_moc_each_pair "$map")
OUTER
  return 0
}
```

- [ ] **Step 4: Run under both shells**

```bash
bash reference/test/moc-sync.test.sh; echo "bash rc=$?"
zsh  reference/test/moc-sync.test.sh; echo "zsh  rc=$?"
```

Expected: **`36 passed, 0 failed`**, rc=0 both. The `render emits no stray variable lines` assertion is the zsh canary — if it fails, an in-loop `local` lost its initialiser.

- [ ] **Step 5: Commit**

```bash
git add reference/lib/moc-sync.sh reference/test/moc-sync.test.sh
git commit -m "feat: moc-sync entry harvesting and section rendering

Derives membership, wiki-links and counts from frontmatter; carries existing
summaries forward and seeds new entries from description. Order is ascending by
filename under LC_ALL=C so idempotence means the same thing across vaults. Every
mapped section is emitted even at zero, because an absent section cannot be
distinguished from an unconsidered one.

moc_render returns 1 on a bad directory, and Task 4's write path depends on that
rc. A test asserts the rendered body contains no \`name=value\` line — the zsh
in-loop \`local\` corruption is only visible in the output."
```

---

### Task 3: Divergence warning and the three unplaceable-note reports

Rules 2 and 3. Measured reality: 33 of 90 observation entries and 7 of 16 tension entries are **not** prefixes of their note's current `description`, so overwriting would destroy ~40 human-visible summaries.

**Files:**
- Modify: `reference/lib/moc-sync.sh`
- Modify: `reference/test/moc-sync.test.sh`

**Interfaces:**
- Consumes: everything from Tasks 1-2.
- Produces: `moc_render` gains stderr reports; stdout unchanged; rc unchanged. Exact formats:
  - `warn: moc-sync: summary not derivable from current frontmatter: <slug>`
  - `warn: moc-sync: note has no readable status, not placed: <path>`
  - `warn: moc-sync: status '<st>' maps to no section, not placed: <slug>`
  - `warn: moc-sync: entry has no note, not removed: <slug>`
- **No counter variable is exported.** The first draft declared `moc_unplaceable_count` "set by `moc_render`", which no caller can read: every call site captures stdout in `$( )`, and a command substitution is a subshell in both shells. Assertions count warnings on stderr instead.

- [ ] **Step 1: Write the failing tests**

```bash
# --- rule 2: divergent summary preserved AND warned about ------------------
ERRF="$FIX/stderr.txt"
BODY=$(MOC_SYNC_EXISTING="$FIX/observations.md" \
       moc_render "$FIX/observations" "$MOC_MAP_OBSERVATIONS" 2>"$ERRF")

ok "divergent summary is preserved" "Zebra description that was EDITED" \
   "$(printf '%s\n' "$BODY" | /usr/bin/sed -n 's/^- \[\[zebra-note\]\] — //p')"
ok "divergence warns exactly once" "1" "$(/usr/bin/grep -c 'summary not derivable' "$ERRF")"
ok "the warning names the slug" "1" \
   "$(/usr/bin/grep -c 'summary not derivable from current frontmatter: zebra-note' "$ERRF")"

# THE WARNING MUST NOT CLAIM A CAUSE. "someone hand-edited this" is measurably wrong for
# most divergent entries: 7 of the 29 divergent Implemented entries follow a second
# derivation convention ("implemented via <target>"), the rest are stale derivations.
# Paired with the positive assertion above so it cannot pass on absence.
ok "warning does not assert hand-editing" "0" "$(/usr/bin/grep -ci 'hand.edit' "$ERRF")"
ok "an agreeing summary does not warn" "0" \
   "$(/usr/bin/grep -c 'not derivable from current frontmatter: alpha-note' "$ERRF")"

# --- rule 3(b): note exists, status unreadable ----------------------------
# frontmatter.sh treats an UNCLOSED frontmatter block as NO frontmatter. Such a note
# EXISTS, so "the note is gone" cannot catch it.
printf -- '---\ndescription: Unclosed\nstatus: open\n\nbody\n' > "$FIX/observations/broken-note.md"
BODY=$(MOC_SYNC_EXISTING="$FIX/observations.md" \
       moc_render "$FIX/observations" "$MOC_MAP_OBSERVATIONS" 2>"$ERRF")
ok "unreadable status is reported" "1" "$(/usr/bin/grep -c 'no readable status' "$ERRF")"
ok "unreadable note names the path" "1" "$(/usr/bin/grep -c 'broken-note.md' "$ERRF")"
ok "unreadable note is NOT placed" "0" "$(printf '%s\n' "$BODY" | /usr/bin/grep -c '\[\[broken-note\]\]')"
rm -f "$FIX/observations/broken-note.md"

# --- rule 3(c) / rule 6: status readable but off-map ----------------------
mknote orphan-note superseded "Orphan description"
BODY=$(MOC_SYNC_EXISTING="$FIX/observations.md" \
       moc_render "$FIX/observations" "$MOC_MAP_OBSERVATIONS" 2>"$ERRF")
ok "off-map status is reported" "1" "$(/usr/bin/grep -c 'maps to no section' "$ERRF")"
ok "off-map report names status and slug" "1" \
   "$(/usr/bin/grep -c "status 'superseded' maps to no section, not placed: orphan-note" "$ERRF")"
ok "off-map note is NOT placed" "0" "$(printf '%s\n' "$BODY" | /usr/bin/grep -c '\[\[orphan-note\]\]')"
rm -f "$FIX/observations/orphan-note.md"

# --- rule 3(a): an entry whose note is gone -------------------------------
# Spec rule 3(a). The first draft of this plan claimed this in a commit message and
# never implemented it.
cat > "$FIX/gone.md" <<'EOF'
## Open (1)
- [[deleted-note]] — This note was deleted from disk
EOF
BODY=$(MOC_SYNC_EXISTING="$FIX/gone.md" \
       moc_render "$FIX/observations" "$MOC_MAP_OBSERVATIONS" 2>"$ERRF")
ok "gone entry is reported" "1" "$(/usr/bin/grep -c 'entry has no note, not removed: deleted-note' "$ERRF")"
ok "gone entry is not silently resurrected" "0" \
   "$(printf '%s\n' "$BODY" | /usr/bin/grep -c '\[\[deleted-note\]\]')"
```

- [ ] **Step 2: Run to confirm the new assertions fail**

```bash
bash reference/test/moc-sync.test.sh
```

Expected: **`6 failed`** of 15 new assertions. Nine pass before implementation, and that is expected: the four preservation/absence assertions (Task 2's render already preserves summaries, and three grep-count-zero assertions pass on absence — each is paired with a positive assertion that does not), the two "NOT placed" assertions (Task 2 already skips a status mismatch), and the gone-entry stdout assertion. **The number to see is 6, not 11.**

- [ ] **Step 3: Implement**

In `moc_render`, add the divergence check and the three reports. Reports fire **once per note**, guarded on the first section — the outer loop visits every note once per section, so an unguarded report fires 4× for observations and 7× for tensions:

```bash
  # After `notes=$(...)`, before the section loop:
  local first_sec="" placed_slugs=""
  first_sec=$(_moc_each_pair "$map" | /usr/bin/sed -n 1p)
  first_sec="${first_sec#*:}"
```

Inside the inner note loop, replacing the bare `[ "$st" = "$st_want" ] || continue`:

```bash
      st=$(frontmatter_field "$note" status 2>/dev/null)

      if [ -z "$st" ]; then
        [ "$sec" = "$first_sec" ] && \
          echo "warn: moc-sync: note has no readable status, not placed: $note" >&2
        continue
      fi
      if ! moc_section_for "$st" "$map" >/dev/null 2>&1; then
        [ "$sec" = "$first_sec" ] && \
          echo "warn: moc-sync: status '$st' maps to no section, not placed: $(basename "$note" .md)" >&2
        continue
      fi
      [ "$st" = "$st_want" ] || continue

      slug=$(basename "$note" .md)
      placed_slugs="${placed_slugs}${slug}
"

      summary=$(printf '%s\n' "$harvest" | /usr/bin/awk -F'\t' -v s="$slug" '$1==s{print $2; exit}')
      desc=$(frontmatter_field "$note" description 2>/dev/null)
      if [ -z "$summary" ]; then
        summary="$desc"
      else
        # Rule 2: keep the file's version; warn only when it is not derivable.
        # NORMALISE FIRST — the live convention truncates with an ellipsis, so a raw
        # compare would flag every correctly-derived entry.
        local a="" b=""
        a=$(printf '%s' "$summary" | /usr/bin/tr -d '\r' | /usr/bin/sed 's/[.… ]*$//')
        b=$(printf '%s' "$desc"    | /usr/bin/tr -d '\r' | /usr/bin/sed 's/[.… ]*$//')
        case "$b" in
          "$a"*) : ;;
          *) echo "warn: moc-sync: summary not derivable from current frontmatter: $slug" >&2 ;;
        esac
      fi
```

And after the section loop closes, before `return 0` — rule 3(a):

```bash
  # Rule 3(a): a harvested entry with no surviving note. Reported, never silently
  # dropped: that is either a rename to fix or a deletion to record.
  local hslug=""
  while IFS= read -r hslug; do
    [ -n "$hslug" ] || continue
    case "
$placed_slugs" in
      *"
$hslug
"*) : ;;
      *) echo "warn: moc-sync: entry has no note, not removed: $hslug" >&2 ;;
    esac
  done <<GONE
$(printf '%s\n' "$harvest" | /usr/bin/awk -F'\t' 'NF{print $1}')
GONE
```

- [ ] **Step 4: Run under both shells**

```bash
bash reference/test/moc-sync.test.sh; echo "bash rc=$?"
zsh  reference/test/moc-sync.test.sh; echo "zsh  rc=$?"
```

Expected: **`51 passed, 0 failed`**, rc=0 both.

- [ ] **Step 5: Measure against the real field vault, read-only**

Proves the warnings are usable rather than merely correct.

```bash
cd /Volumes/Containers/arscontexta
. reference/lib/frontmatter.sh; . reference/lib/moc-sync.sh
MOC_SYNC_EXISTING=~/second-brain/ops/observations.md \
  moc_render ~/second-brain/ops/observations "$MOC_MAP_OBSERVATIONS" \
  >/tmp/rendered-obs.md 2>/tmp/rendered-obs.err
/usr/bin/grep -c 'not derivable'      /tmp/rendered-obs.err   # expect 33
/usr/bin/grep -c 'maps to no section' /tmp/rendered-obs.err   # expect 0
/usr/bin/grep -c '^- \[\[' /tmp/rendered-obs.md               # expect 112
```

**The middle number is load-bearing:** 0 means the pinned map covers every status the field vault holds. Non-zero means the map is incomplete — add the status to `MOC_MAP_OBSERVATIONS` **and** to Task 1's pinned-value assertion in the same commit. All three figures were verified exact on 2026-08-17; tensions gives 7 / 0 / 31.

- [ ] **Step 6: Commit**

```bash
git add reference/lib/moc-sync.sh reference/test/moc-sync.test.sh
git commit -m "feat: moc-sync preserves divergent summaries and reports every unplaceable note

Rule 2: a summary that is not a prefix of its note's description is preserved and
warned about, with wording that does not assert a cause — 'someone hand-edited
this' is measurably wrong for most of the ~40 divergent entries in the field.

Rule 3, all FOUR reports: entry whose note is gone, note with unreadable status
(the unclosed-frontmatter case, which 'the note is gone' cannot catch), status
off-map, and summary divergence. None is a silent omission.

No counter variable is exported. The first draft declared one 'set by moc_render'
that no caller could read — every call site captures stdout in a command
substitution, which is a subshell in both shells."
```

---

### Task 4: The guarded write

Rules 4 and 5.

**Files:**
- Modify: `reference/lib/moc-sync.sh`
- Modify: `reference/test/moc-sync.test.sh`

**Interfaces:**
- Consumes: `moc_render` (**and its rc**).
- Produces: `rebuild_status_moc <moc-file> <notes-dir> <map-string>` — rc 0 on success; rc 1 on lock failure, **render failure**, or rename failure. On any failure the target is byte-identical to before and no temp survives beside it.

- [ ] **Step 1: Write the failing tests**

```bash
# --- rebuild_status_moc ---------------------------------------------------
rebuild_status_moc "$FIX/observations.md" "$FIX/observations" "$MOC_MAP_OBSERVATIONS" 2>/dev/null
ok "rebuild returns 0" "0" "$?"
ok "rebuild wrote the Open heading" "## Open (2)" "$(/usr/bin/grep -m1 '^## Open' "$FIX/observations.md")"
ok "rebuild emitted provenance" "1" "$(/usr/bin/grep -c '^derived: [0-9]' "$FIX/observations.md")"
ok "provenance carries the re-derive command" "1" "$(/usr/bin/grep -c 'rebuild_status_moc' "$FIX/observations.md")"

# IDEMPOTENCE (1): two consecutive rebuilds byte-identical. The provenance timestamp is
# excluded — a wall-clock stamp legitimately differs.
body_only() { /usr/bin/sed -n '/^## /,$p' "$1"; }
rebuild_status_moc "$FIX/observations.md" "$FIX/observations" "$MOC_MAP_OBSERVATIONS" 2>/dev/null
body_only "$FIX/observations.md" > "$FIX/pass1.txt"
rebuild_status_moc "$FIX/observations.md" "$FIX/observations" "$MOC_MAP_OBSERVATIONS" 2>/dev/null
body_only "$FIX/observations.md" > "$FIX/pass2.txt"
cmp -s "$FIX/pass1.txt" "$FIX/pass2.txt"; ok "two rebuilds are byte-identical" "0" "$?"

# IDEMPOTENCE (2): reordered existing entries produce the same BODY. An implementation
# that preserves current order and appends passes (1) and fails (2).
# COMPARE BODIES ONLY: the header is `# $(basename file)` and the provenance embeds the
# file and dir arguments, so a whole-file cmp of two differently-named fixtures can never
# pass and would read as a broken implementation.
mkdir -p "$FIX/obs2"; cp "$FIX/observations/zebra-note.md" "$FIX/observations/alpha-note.md" \
                          "$FIX/observations/middle-note.md" "$FIX/obs2/"
cat > "$FIX/moc2.md" <<'EOF'
## Open (2)
- [[zebra-note]] — Zebra description that was EDITED
- [[alpha-note]] — Alpha description here
EOF
rebuild_status_moc "$FIX/moc2.md" "$FIX/obs2" "$MOC_MAP_OBSERVATIONS" 2>/dev/null
body_only "$FIX/moc2.md" > "$FIX/pass3.txt"
cmp -s "$FIX/pass1.txt" "$FIX/pass3.txt"; ok "reordered input yields identical body" "0" "$?"

# RENDER FAILURE MUST NOT DESTROY THE TARGET. The first draft wrote header lines into the
# temp BEFORE rendering and guarded only on `[ ! -s "$tmp" ]`, which cannot fire — so a
# typo'd notes-dir replaced the MOC with a header and returned 0. Demonstrated: 2 entries
# became 0 entries at rc 0.
cp "$FIX/observations.md" "$FIX/before-bad-dir.txt"
rebuild_status_moc "$FIX/observations.md" "$FIX/TYPO-no-such-dir" "$MOC_MAP_OBSERVATIONS" 2>"$ERRF"
ok "bad notes-dir returns 1" "1" "$?"
cmp -s "$FIX/observations.md" "$FIX/before-bad-dir.txt"; ok "bad notes-dir leaves target intact" "0" "$?"
ok "bad notes-dir still has its entries" "2" "$(/usr/bin/grep -c '^- \[\[' "$FIX/observations.md")"

# GUARDED RENAME: forced with a shell-function stub. A genuine same-directory mv failure
# needs `chflags uchg` (macOS) or `chattr +i` (root, Linux), neither portable to CI. The
# MECHANISM is covered; the organic trigger is hand-run only, and that is not the same
# claim. queue-edit.test.sh records the identical limitation.
cp "$FIX/observations.md" "$FIX/before-mv.txt"
mv() { return 1; }
rebuild_status_moc "$FIX/observations.md" "$FIX/observations" "$MOC_MAP_OBSERVATIONS" 2>"$ERRF"
ok "failed rename returns 1" "1" "$?"
unset -f mv
ok "failed rename names the path" "1" "$(/usr/bin/grep -c "observations.md" "$ERRF")"
cmp -s "$FIX/observations.md" "$FIX/before-mv.txt"; ok "target unchanged after failed rename" "0" "$?"
ok "no temp survives beside the target" "0" \
   "$(find "$FIX" -maxdepth 1 -name 'observations.md.*' ! -name '*.txt' | /usr/bin/grep -c .)"
ok "no lock survives beside the target" "0" \
   "$(find "$FIX" -maxdepth 1 -name 'observations.md.lock' | /usr/bin/grep -c .)"
```

- [ ] **Step 2: Run to confirm the new assertions fail**

```bash
bash reference/test/moc-sync.test.sh
```

Expected: **`7 failed`** of 14 new assertions, and Tasks 1-3's 51 still green. Seven pass vacuously before implementation because the file never changes (the two `cmp` idempotence pairs, the three "unchanged/intact" assertions, and the two find-count-zero assertions) — each is paired with an rc assertion that does not.

- [ ] **Step 3: Implement**

```bash
# _moc_lock <file> -> prints the lock dir, rc 0; rc 1 on timeout.
# mkdir is the atomic primitive. A BOUNDED WAIT THAT FAILS MUST NOT BREAK THE LOCK IT
# COULD NOT TAKE — an auto-break wearing a failure message is how concurrent writers lose
# updates. queue-edit.sh's header argues this at length; same contract.
_moc_lock() {
  local file="$1" lockdir="$1.lock" waited=0
  while ! mkdir "$lockdir" 2>/dev/null; do
    waited=$((waited + 1))
    if [ "$waited" -ge 60 ]; then
      echo "error: moc-sync: could not acquire lock '$lockdir' within 60s; NOT breaking it" >&2
      return 1
    fi
    sleep 1
  done
  printf '%s\n' "$lockdir"
}

# rebuild_status_moc <moc-file> <notes-dir> <map-string>
rebuild_status_moc() {
  local file="$1" dir="$2" map="$3"
  if [ -z "$file" ] || [ -z "$dir" ] || [ -z "$map" ]; then
    echo "error: moc-sync: rebuild_status_moc needs <moc-file> <notes-dir> <map-string>" >&2
    return 1
  fi

  local lockdir="" tmp="" body_tmp=""
  lockdir=$(_moc_lock "$file") || return 1
  tmp="${file}.$$.tmp"
  body_tmp="${file}.$$.body"

  # RENDER FIRST, INTO ITS OWN FILE, AND CHECK THE RC. The first draft rendered inside a
  # brace group that had already written header lines, discarded the group's status, and
  # guarded only on emptiness — so a render failure replaced the MOC with a header and
  # returned 0. Content destruction at exit 0 is this repo's cardinal failure class, and
  # it was in the one function whose contract promised the opposite.
  if ! MOC_SYNC_EXISTING="$file" moc_render "$dir" "$map" > "$body_tmp"; then
    echo "error: moc-sync: render failed; '$file' left unchanged" >&2
    rm -f "$body_tmp"; rm -rf "$lockdir"; return 1
  fi
  if [ ! -s "$body_tmp" ]; then
    echo "error: moc-sync: render produced no sections; '$file' left unchanged" >&2
    rm -f "$body_tmp"; rm -rf "$lockdir"; return 1
  fi

  {
    printf '# %s\n\n' "$(basename "$file" .md)"
    printf 'derived: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf '<!-- Derived from note frontmatter. Do not move entries by hand; they will be\n'
    printf '     regenerated. Re-derive with:\n'
    printf '       . ops/lib/moc-sync.sh && rebuild_status_moc <moc-file> <notes-dir> <map> -->\n\n'
    cat "$body_tmp"
  } > "$tmp"
  rm -f "$body_tmp"

  # THE GUARDED RENAME. Ending this `mv` without a failure branch returns the exit status
  # of the following `rm -rf` — 0 — while leaving an undeclared second copy on disk. That
  # exact defect shipped in queue-edit.sh and its suite was written red to pin it.
  if ! mv "$tmp" "$file"; then
    echo "error: moc-sync: could not move '$tmp' into place at '$file'" >&2
    rm -f "$tmp"
    rm -rf "$lockdir"
    return 1
  fi
  rm -rf "$lockdir"
  return 0
}
```

- [ ] **Step 4: Run under both shells**

```bash
bash reference/test/moc-sync.test.sh; echo "bash rc=$?"
zsh  reference/test/moc-sync.test.sh; echo "zsh  rc=$?"
```

Expected: **`65 passed, 0 failed`**, rc=0 both.

- [ ] **Step 5: Prove the suite is not vacuous — mutate and confirm it reddens**

A suite that stays green when the implementation breaks is not a suite. Run each mutation, confirm the failure count rises, then revert.

```bash
cp reference/lib/moc-sync.sh /tmp/moc-sync.orig
# M1: off-map collapses rc 2 into rc 0 -> off-map notes silently placed
/usr/bin/sed -i '' 's/^  return 2$/  return 0/' reference/lib/moc-sync.sh
bash reference/test/moc-sync.test.sh | /usr/bin/tail -1     # must show FAILURES > 0
cp /tmp/moc-sync.orig reference/lib/moc-sync.sh
# M2: always overwrite the summary -> rule 2 destroyed
/usr/bin/sed -i '' 's/^        summary="\$desc"$/        summary="$desc"; summary="$desc"/' reference/lib/moc-sync.sh
# (edit by hand if that anchor does not match: force `summary="$desc"` unconditionally)
bash reference/test/moc-sync.test.sh | /usr/bin/tail -1     # must show FAILURES > 0
cp /tmp/moc-sync.orig reference/lib/moc-sync.sh
# M3: unguarded rename
/usr/bin/sed -i '' 's/^  if ! mv "\$tmp" "\$file"; then$/  mv "$tmp" "$file"; if false; then/' reference/lib/moc-sync.sh
bash reference/test/moc-sync.test.sh | /usr/bin/tail -1     # must show FAILURES > 0
cp /tmp/moc-sync.orig reference/lib/moc-sync.sh
bash reference/test/moc-sync.test.sh | /usr/bin/tail -1     # back to 0 failed
```

**A mutation that changes nothing is itself a finding** — it means no assertion covers that line. Report it rather than moving on.

- [ ] **Step 6: Commit**

```bash
git add reference/lib/moc-sync.sh reference/test/moc-sync.test.sh
git commit -m "feat: moc-sync guarded write with lock, provenance and idempotence

Renders into its own file and CHECKS THE RC before assembling the output. The
first draft wrote header lines first and guarded only on emptiness, so a bad
notes-dir replaced the MOC with a header and returned 0 — measured: 2 entries
became 0 at rc 0, in the one function whose contract promised the opposite.

A bounded lock wait that fails does NOT break the lock it could not take, and a
failed rename returns 1, discards its temp and names the path.

Two idempotence assertions: byte-identical consecutive runs, AND identical BODY
from reordered input. Bodies only — the header and provenance embed the file and
dir arguments, so a whole-file compare of two fixtures can never pass."
```

---

### Task 5: Wire the library into `skill-sources/rethink` and into the fence gate's fixture

**Files:**
- Modify: `skill-sources/rethink/SKILL.md`
- Modify: `reference/test/fence-isolation.test.sh`

**Interfaces:**
- Consumes: `rebuild_status_moc`, `MOC_MAP_OBSERVATIONS`, `MOC_MAP_TENSIONS`, `MOC_SYNC_VERSION`.
- Produces: nothing consumed later.

- [ ] **Step 1: Verify the anchor before editing**

```bash
/usr/bin/sed -n '329p' skill-sources/rethink/SKILL.md
/usr/bin/sed -n '160,171p' skill-sources/rethink/SKILL.md
```

`:329` must be the "**Update MOCs:** … Move entries between Pending/Promoted/Blocked/Archived/Resolved/Dissolved sections as appropriate." line. All six anchors this plan uses (`:160-171`, `:290-292`, `:329`, `:562`, `:630`, `:704`) were verified current on 2026-08-17. **If `:329` is not that line, stop and report** — do not search for it and edit blind.

- [ ] **Step 2: Add `moc-sync.sh` to the fence gate's fixture FIRST**

Do this before touching the template, so the gate is ready when the fence lands. `fence-isolation.test.sh`'s healthy fixture copies exactly four libraries into `ops/lib/` (around `:167-182`): `link-extraction.sh`, `frontmatter.sh`, `queue-edit.sh`, `queue_edit.py`. Task 5's fence begins by requiring `ops/lib/moc-sync.sh`, so on that fixture it would exit 1 — an assertion-H failure.

```bash
/usr/bin/grep -n 'queue_edit.py\|queue-edit.sh\|frontmatter.sh' reference/test/fence-isolation.test.sh | /usr/bin/head
```

Add `moc-sync.sh` to that copy list. **Do not add an allowlist entry instead** — that is the rot the gate's two-directional check exists to drain, and this plan's fence is not a known-open defect.

```bash
bash reference/test/fence-isolation.test.sh 2>&1 | /usr/bin/tail -6
git add reference/test/fence-isolation.test.sh
git commit -m "test: fence-isolation fixture provides moc-sync.sh

Task 5's rethink fence requires ops/lib/moc-sync.sh. Without it in the healthy
fixture the fence exits 1 there and the gate reports an assertion-H failure, and
the tempting wrong fix is an allowlist entry — the rot the two-directional check
was built to drain."
```

- [ ] **Step 3: Replace the instruction**

```markdown
**Rebuild MOCs:** After triage execution, rebuild `ops/observations.md` and
`ops/tensions.md` from frontmatter. The rebuild is idempotent and authoritative on
membership, links and counts; existing summaries are preserved. **Do not move entries by
hand** — they will be regenerated, and a hand-move cannot correct a status that changed
outside this run, which is how the MOC diverged three times.

```bash
MOC_LIB="ops/lib/moc-sync.sh"
FM_LIB="ops/lib/frontmatter.sh"
for lib in "$MOC_LIB" "$FM_LIB"; do
  if [ ! -r "$lib" ]; then
    echo "error: library not found at '$lib'" >&2
    echo "       run /arscontexta:upgrade to restore it" >&2
    exit 1
  fi
done
. "$FM_LIB"
. "$MOC_LIB"

if [ "${MOC_SYNC_VERSION:-0}" -lt 1 ]; then
  echo "error: ops/lib/moc-sync.sh is older than this skill requires (need >= 1, have ${MOC_SYNC_VERSION:-none})" >&2
  echo "       run /arscontexta:upgrade to refresh it" >&2
  exit 1
fi

# THE MAP IS ONE QUOTED ARGUMENT. Unquoted, zsh passes the whole string as a single
# argument, only the first pair is honoured, and every non-open note is silently
# dropped at rc 0 — on the user-facing path, under the shell half of real users run.
rc=0
rebuild_status_moc ops/observations.md ops/observations "$MOC_MAP_OBSERVATIONS" || rc=1
rebuild_status_moc ops/tensions.md     ops/tensions     "$MOC_MAP_TENSIONS"     || rc=1
if [ "$rc" -ne 0 ]; then
  echo "error: MOC rebuild failed; the MOCs are unchanged and still reflect the pre-triage state" >&2
  exit 1
fi
echo "MOCs rebuilt from frontmatter. Unplaceable notes, if any, are reported above."
```
```

- [ ] **Step 4: Verify the fence in isolation and under both shells**

Each ```bash fence in a SKILL.md is its own shell invocation, so this fence sources both libraries itself rather than relying on `:164`.

```bash
bash -n /dev/stdin <<'F'   # paste the fence body; syntax only
F
bash reference/test/fence-isolation.test.sh 2>&1 | /usr/bin/tail -20
```

Expected: PASS. **Read the `files=`/`fences=`/`run=`/`skipped=` line and record all four — Task 9 Step 3 needs them.** A fence that does not parse is SKIPPED, not failed, so a rise in `skipped` is a silent failure of this step.

- [ ] **Step 5: Run the other gates, unpiped**

```bash
bash reference/check-portability.sh;            echo "portability rc=$?"
bash reference/check-placeholder-count.sh main; echo "placeholder rc=$?"
bash reference/check-prose-paths.sh;            echo "prose-paths rc=$?"
```

Expected: rc=0 for all three.

- [ ] **Step 6: Commit**

```bash
git add skill-sources/rethink/SKILL.md
git commit -m "feat: rethink rebuilds MOCs from frontmatter instead of moving entries

:329 instructed a stateful edit of a derivable file. Four templates write the
notes a status MOC indexes and only this one touched the MOC, so it diverged at
the rate of note activity — three times, most recently within 72 hours of a
rebuild.

The fence sources both libraries itself because each bash fence in a SKILL.md is
a separate shell invocation, guards MOC_SYNC_VERSION >= 1 fail-loud, and passes
the map QUOTED — unquoted, zsh would honour only the first pair and drop every
non-open note at rc 0."
```

---

### Task 6: `/health` gains a `moc-sync` library check

**Files:**
- Modify: `skills/health/SKILL.md`

**Interfaces:**
- Consumes: the `MOC_SYNC_VERSION` floor of 1 declared by Task 5's guard.
- Produces: nothing.

- [ ] **Step 1: Read the real helper signature — it is four arguments, not three**

```bash
/usr/bin/sed -n '708p' skills/health/SKILL.md
/usr/bin/sed -n '747,749p' skills/health/SKILL.md
```

`check_lib <path> <version-var-name> <label> <min-version>`, and the existing three calls pass a full `"$VAULT_ROOT/ops/lib/….sh"` path. A three-argument call yields an unreadable relative path (unconditional FAIL row), puts `1` in the label slot, and leaves min-version empty so the floor comparison errors.

- [ ] **Step 2: Add the check**

```bash
check_lib "$VAULT_ROOT/ops/lib/moc-sync.sh" MOC_SYNC_VERSION moc-sync 1
```

- [ ] **Step 3: Verify the floor matches the consumer's guard**

```bash
/usr/bin/grep -n 'MOC_SYNC_VERSION:-0}" -lt' skill-sources/rethink/SKILL.md
/usr/bin/grep -n 'MOC_SYNC_VERSION moc-sync' skills/health/SKILL.md
```

Both must name **1**. The floor is the consumer's guard, never the library's current version — `/health` vouching below what a consumer requires prints PASS beside every call to that library failing, a defect this repo has already shipped and reversed.

- [ ] **Step 4: Run the gates**

```bash
bash reference/test/fence-isolation.test.sh 2>&1 | /usr/bin/tail -6
bash reference/check-prose-paths.sh; echo "prose-paths rc=$?"
```

Expected: PASS and rc=0. Category 9 reports and never exits, so a fixture lacking `moc-sync.sh` prints FAIL rows without reddening the fence gate — but Task 5 Step 2 already added it.

- [ ] **Step 5: Commit**

```bash
git add skills/health/SKILL.md
git commit -m "feat: /health checks the moc-sync library at its consumer's floor

Floor is 1, derived from rethink's own guard rather than the library's current
version. Uses the helper's real four-argument signature with a full VAULT_ROOT
path, matching the three existing calls."
```

---

### Task 7: Redraw the approval gates by act

The spec's Critical C2. `1d` does far more than move statuses.

**Files:**
- Modify: `skill-sources/rethink/SKILL.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the artifact contract Task 8 implements — side-effect items carry `status: awaiting_approval` and an `act:` of `promote` | `implement` | `methodology`.

- [ ] **Step 1: Read the gate and enumerate ALL SIX `1d` branches**

```bash
/usr/bin/sed -n '286,296p' skill-sources/rethink/SKILL.md
/usr/bin/sed -n '293,325p' skill-sources/rethink/SKILL.md
/usr/bin/sed -n '700,710p' skill-sources/rethink/SKILL.md
```

`1d` has **six** branches: PROMOTE, IMPLEMENT, METHODOLOGY, ARCHIVE, KEEP PENDING, and **BLOCKED** (tensions only, at `:321` — `status: blocked` plus a named blocker). The first draft of this plan said "five" and omitted BLOCKED, leaving unclassified behavior inside the machinery built to remove it. **If a seventh exists, stop and report** — the act inventory is the entire basis of the split.

- [ ] **Step 2: Replace the blocking wait at `:292`**

```markdown
**If an approval channel is available, wait for confirmation before proceeding to 1d.**

**If no approval channel is available** (subagent execution, where `AskUserQuestion` cannot
be used), proceed under the split below rather than stalling. A run that generates a triage
and then stops has produced nothing a later invocation can act on, which is how 21+
proposals accumulated across three runs.

| Act | Branches | Without a channel |
|---|---|---|
| frontmatter status edit | ARCHIVE, KEEP PENDING, **BLOCKED** | **proceed** — reversible, recorded in the note's own history |
| note creation | PROMOTE step 1 | **defer** to the pending artifact |
| file/section modification | IMPLEMENT step 1 | **defer** to the pending artifact |
| methodology elevation | METHODOLOGY | **defer** to the pending artifact |

All six `1d` branches appear in this table. Deferring is not skipping: the item is persisted
with its full disposition and reasoning, so the approval invocation need not re-derive the
triage.
```

- [ ] **Step 3: Add the deferral instruction to the three side-effect branches**

Prepend to PROMOTE, IMPLEMENT and METHODOLOGY:

```markdown
**If no approval channel is available:** do not perform this act. Append the item to
`ops/rethink/pending.yaml` per Phase 1e and leave the source observation/tension at its
current status — a status claiming an act that did not happen is worse than a pending one,
because nothing downstream can tell the difference.
```

**IMPLEMENT step 2's** "get confirmation if the change is non-trivial" is a second blocking gate. Under this split it becomes **unreachable** without a channel, because IMPLEMENT itself defers — so it needs no separate treatment. Leave its text unchanged, and say so here rather than appearing to have missed it.

- [ ] **Step 4: Verify `:704` survived and all six branches are classified**

```bash
/usr/bin/grep -c 'Auto-implement system changes — proposals require human approval, always' \
  skill-sources/rethink/SKILL.md      # must be 1
for b in PROMOTE IMPLEMENT METHODOLOGY ARCHIVE 'KEEP PENDING' BLOCKED; do
  printf '%-14s in the act table: %s\n' "$b" \
    "$(/usr/bin/sed -n '/^| Act |/,/^$/p' skill-sources/rethink/SKILL.md | /usr/bin/grep -c "$b")"
done
bash reference/test/fence-isolation.test.sh 2>&1 | /usr/bin/tail -6
bash reference/check-portability.sh; echo "portability rc=$?"
```

Expected: `1`; every branch ≥ 1; PASS; rc=0. **If `:704`'s count is 0, revert this task** — the split's entire justification is that `:704` continues to hold.

- [ ] **Step 5: Commit**

```bash
git add skill-sources/rethink/SKILL.md
git commit -m "fix: split rethink's triage gate by act, not by phase

Un-gating the triage PHASE would auto-implement: 1d's PROMOTE branch creates
knowledge-base notes and IMPLEMENT modifies files, so a phase-level split
contradicts :704 while claiming to preserve it.

Split by act instead, covering all SIX 1d branches — the first draft named five
and omitted BLOCKED, leaving unclassified behavior inside the machinery built to
remove it. IMPLEMENT step 2's own confirmation gate becomes unreachable rather
than needing separate handling, because IMPLEMENT itself defers."
```

---

### Task 8: The pending artifact and its resume path

**Files:**
- Modify: `skill-sources/rethink/SKILL.md`

**Interfaces:**
- Consumes: `queue_yaml` from `ops/lib/queue-edit.sh` (v2); the `act:` vocabulary from Task 7.
- Produces: `ops/rethink/pending.yaml` — a bare YAML list whose items carry `id`, `act` (`promote`|`implement`|`methodology`|`proposal`), `status` (`awaiting_approval`|`approved`|`rejected`|`deferred`), `source`, `summary`, `detail`.

- [ ] **Step 1: Confirm the writer, and expect NO existing guard in rethink**

```bash
/usr/bin/grep -n 'QUEUE_EDIT_VERSION=' reference/lib/queue-edit.sh          # expect 2
/usr/bin/sed -n '/^# queue_yaml FILE/,+6p' reference/lib/queue-edit.sh      # the signature
/usr/bin/grep -c 'QUEUE_EDIT_VERSION' skill-sources/rethink/SKILL.md        # expect 0
```

**The last count is expected to be 0** — rethink has no queue fence today; the guard idiom lives in `next`, `reduce` and `remember`, and you are adding rethink's first. An empty result here is the expected state, not a failed confirmation.

- [ ] **Step 2: Add Phase 1e**

```markdown
### 1e. Persist Deferred Acts and Proposals

**File:** `ops/rethink/pending.yaml` — a bare YAML list. **Deliberately NOT the operational
queue**: no queue schema declares `awaiting_approval`, and a status no consumer declares is
the unfalsifiable state this skill legislates against elsewhere.

**Item shape:**

```yaml
- id: p-2026-08-17-001
  act: implement            # promote | implement | methodology | proposal
  status: awaiting_approval # -> approved | rejected | deferred
  source: observations/some-observation-slug.md
  summary: One line, what would change
  detail: |
    The full disposition, so the approval invocation need not re-derive the triage.
```

```bash
QE_LIB="ops/lib/queue-edit.sh"
if [ ! -r "$QE_LIB" ]; then
  echo "error: library not found at '$QE_LIB'" >&2
  echo "       run /arscontexta:upgrade to restore it" >&2
  exit 1
fi
. "$QE_LIB"
if [ "${QUEUE_EDIT_VERSION:-0}" -lt 2 ]; then
  echo "error: ops/lib/queue-edit.sh must be >= 2 for YAML writes (have ${QUEUE_EDIT_VERSION:-none})" >&2
  exit 1
fi

mkdir -p ops/rethink
# SEED AS AN EMPTY FILE, NOT AS `[]`. queue_yaml appends a block sequence; after a
# flow-style `[]` the result is `[]` followed by `- id: …`, which is not a YAML document
# at all — and queue_yaml reports "1 task(s) updated" at rc 0 while producing it. Verified:
# an empty file yields valid YAML; a MISSING file is refused loudly (rc 1), which is why
# the seed must exist and must be empty.
[ -f ops/rethink/pending.yaml ] || : > ops/rethink/pending.yaml

# One queue_yaml call per item. A zero-match --where fails loud rather than silently
# writing nothing — the silence that left seven fences dead for a month.
```

**Then report and exit 0.** Do not wait.

```
Pending acts and proposals: [count] written to ops/rethink/pending.yaml
Resume with: /rethink approve
```
```

- [ ] **Step 3: Verify the seed produces parseable YAML**

```bash
cd "$(mktemp -d)" && . /Volumes/Containers/arscontexta/reference/lib/queue-edit.sh
: > pending.yaml
queue_yaml pending.yaml --add-task id=p-test-001 act=implement status=awaiting_approval
/usr/bin/python3 -c 'import yaml,sys; print("PARSED:", yaml.safe_load(open("pending.yaml")))'
```

Expected: a parsed list of one dict. **Then repeat with `printf '[]\n' > pending.yaml` and confirm it raises `ParserError`** — that is the defect this step exists to prevent, and seeing it fail is how you know the empty seed is load-bearing rather than cosmetic.

- [ ] **Step 4: Apply the same treatment to the proposal gate at `:562`**

Ask if a channel exists; otherwise write each proposal as an `act: proposal` item and exit 0. **`:704` is unaffected** — a persisted proposal is not an implemented one.

- [ ] **Step 5: Extend the `:630` report format**

Add one line, leaving the existing four counts untouched — they are the surface that made this defect visible, and three log lines reading `0 approved` are why there is a fix:

```markdown
**Pending:** [count] awaiting approval in `ops/rethink/pending.yaml`
```

- [ ] **Step 6: Run the gates**

```bash
bash reference/test/fence-isolation.test.sh 2>&1 | /usr/bin/tail -8
bash reference/test/queue-edit.test.sh;   echo "queue-edit rc=$?"
bash reference/check-portability.sh;      echo "portability rc=$?"
bash reference/check-prose-paths.sh;      echo "prose-paths rc=$?"
```

Expected: PASS, rc=0 each, unpiped. **Record the fence gate's four numbers again — Tasks 5 and 8 both add fences, and Task 9 needs the final values.**

- [ ] **Step 7: Commit**

```bash
git add skill-sources/rethink/SKILL.md
git commit -m "feat: rethink persists deferred acts and proposals, then exits 0

The proposal phase terminated in a question, so a run without an interactive
channel generated proposals and stalled — three logged runs at '0 approved'. It
now terminates in ops/rethink/pending.yaml and exits 0, with approval as a
separate invocation.

The store is pinned rather than left to the implementer, and it is seeded EMPTY
rather than with '[]': queue_yaml appends a block sequence, so after a flow-style
'[]' the file is not a YAML document and queue_yaml reports success anyway."
```

---

### Task 9: CI wiring and the five numeral edits

**Files:**
- Modify: `.github/workflows/checks.yml`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: `reference/test/moc-sync.test.sh`; the fence-gate numbers recorded in Tasks 5 and 8.
- Produces: nothing.

- [ ] **Step 1: Re-derive every affected numeral — do not increment**

```bash
ls reference/check-*.sh reference/test/*.test.sh reference/validate-kernel.sh | wc -l
/usr/bin/grep -c '^      - ' .github/workflows/checks.yml
bash reference/test/fence-isolation.test.sh 2>&1 | /usr/bin/grep -m1 -oE 'files=[0-9]+|fences=[0-9]+|run=[0-9]+|skipped=[0-9]+'
```

**Incrementing assumes you know the current value.** `CLAUDE.md` records four occasions where a prose count was stale in exactly that way, including one that went wrong inside the paragraph explaining the hazard.

- [ ] **Step 2: Add the two CI steps**

```yaml
      - name: moc-sync (bash)
        run: bash reference/test/moc-sync.test.sh
      - name: moc-sync (zsh)
        run: zsh reference/test/moc-sync.test.sh
```

- [ ] **Step 3: Make FIVE `CLAUDE.md` edits, not three**

1. The check count — "seventeen executable checks" → eighteen, in the word form the gate reads.
2. The CI-run count — "Fifteen run in CI" → sixteen.
3. **"the ten test suites each run under both shells"** (~`:50`) → eleven, **and** add a `moc-sync.test.sh` line to the verification fence's suite list. These two are gated *against each other* (`check-doc-claims.sh` compares the word against the suites named in the fence), so touching one without the other reddens the gate — and touching **neither** leaves them agreeing while the document lies.
4. The fence-gate prose — "extracts 78 fences from 27 files … runs 75 … the 3 it skips" — re-derived from Step 1's third command. Ungated, and the spec's Gates section explicitly orders it.
5. A new gate-table row:

```markdown
| `moc-sync.test.sh` | the only gate that executes `reference/lib/moc-sync.sh` — a derivation whose failure mode is a *plausible* MOC: correct headings over silently missing notes. It pins all four unplaceable-note reports (gone, unreadable status, off-map, divergent summary — 16 live off-map instances in the field today, which any one of the three competing section maps would have dropped), that a divergent summary survives byte-identical (~40 entries would otherwise be destroyed), that a render failure leaves the target intact rather than replacing it with a header at rc 0, and idempotence in BOTH senses — byte-identical consecutive runs, and identical body from reordered input, which a "preserve order and append" implementation passes the first of and fails the second |
```

**Leave the `main`-side numeral alone.** It cannot be green on both sides of the merge: pre-merge `main` carries the old count, so writing the new one reddens this branch. It takes the documented post-merge correction, and this is where an executor otherwise chases an impossible green.

- [ ] **Step 4: Run the two gates that read those numerals, unpiped**

```bash
bash reference/check-doc-claims.sh;  echo "doc-claims rc=$?"    # ~100s
bash reference/check-prose-paths.sh; echo "prose-paths rc=$?"
```

Expected: rc=0 both. A non-zero `check-doc-claims.sh` names the disagreeing claim — fix the document to match the tree, never the reverse.

- [ ] **Step 5: Full suite before handoff**

```bash
for s in bash zsh; do
  for t in link-extraction guard-failure fence-isolation bump-version kernel-note-dirs \
           threshold-namespace placeholder-count hook-config vocabulary-schema queue-edit moc-sync; do
    "$s" "reference/test/$t.test.sh" >/dev/null 2>&1
    printf '%-34s %s rc=%s\n' "$t" "$s" "$?"
  done
done
for c in portability prose-paths doc-claims vocabulary-schema; do
  bash "reference/check-$c.sh" >/dev/null 2>&1; printf '%-34s rc=%s\n' "check-$c" "$?"
done
bash reference/check-placeholder-count.sh main >/dev/null 2>&1; echo "placeholder-count rc=$?"
```

Expected: every rc=0. Each gate runs **unpiped**. Several minutes — run in the background rather than hitting a foreground timeout.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/checks.yml CLAUDE.md
git commit -m "ci: wire moc-sync.test.sh and update the declared numerals

Five edits, not three: the check count, the CI-run count, the 'ten test suites'
word AND the verification fence's suite list (gated against each other, so
touching one without the other reddens the gate and touching neither leaves them
agreeing while the doc lies), the re-derived fence-gate counts, and a gate-table
row. All re-derived rather than incremented.

The main-side CI step numeral is deliberately NOT updated: no value is green on
both sides of a merge. It has been corrected three times for exactly this reason."
```

---

## Deferrals

- **Summary backfill for the ~40 divergent entries** — deferred. The rebuild preserves them and warns on every run, which is a permanent warning that will be tuned out. Two options, both out of scope: backfill the descriptions, or adopt the `implemented via <implemented_in target>` convention 7 entries already use. **Tracked home:** the spec's "What is NOT claimed" section, which already carries it.
- **Delivery to existing vaults** — deferred to divergence 16's own spec. Two deliveries must land before an existing vault converges (template regeneration, and `ops/lib/moc-sync.sh` installation via `/upgrade` 5e). **Tracked home:** the spec's Migration section, which names both.
- **Rebuild against a vault that renamed `ops/`** — the spec's Testing table asks for it; no task implements it. `rebuild_status_moc` takes explicit paths, so a caller can already point it anywhere; what is untested is the *fence* resolving a renamed directory. **Tracked home:** this plan's Deferrals; needs a `resolve_ops_dir`-style helper in the fence, which is a change to what generation emits.
- **`1d`'s pre-existing gate ambiguity** — not fixed. PROMOTE and IMPLEMENT already execute system changes behind a *triage* approval rather than a *proposal* approval. Task 7's split resolves it as a side effect; it is not targeted. **Tracked home:** the spec, under the corrected split.
- **G1, G4, G5** — out of scope by the spec's "What is NOT claimed". **Tracked home:** the spec's own "What is NOT claimed" list names all three; `docs/field-intel-2026-08-17.md` carries the evidence but is **untracked and is not a home**. G5 (a gate for enums with no consumer inside `generators/`) must additionally be filed as a numbered item in `docs/superpowers/specs/archive/2026-08-04-ci-hardening-design.md` — an entry deferred without a tracked home is divergence 10's failure mode, and this plan's first draft committed it by pointing at the untracked file.
- **The `main`-side CI step numeral** — deliberately left stale by Task 9 Step 3. Takes the documented post-merge correction. **Tracked home:** Task 9's commit message.
- **A drain for `ops/rethink/pending.yaml`** — deferred, and added by the final whole-branch
  review rather than foreseen here. This plan makes a channel-less run *terminate in an
  artifact* instead of stalling, which is what G3 asked for; it does **not** make anything read
  that artifact back. Measured at the end of the branch: all 8 references to `pending.yaml` are
  writes, `awaiting_approval` has zero consumers, and `approve` is not one of `/rethink`'s
  parsed targets — so the report's original "Resume with: `/rethink approve`" named an
  invocation that would have fallen through to the specific-filename rule and run a fresh full
  rethink, appending a second batch to the same file. The message now says the items await
  human review and names no command. **Tracked home:** this line, plus the paragraph in
  `skill-sources/rethink/SKILL.md` beside the report that states the gap in full. Building the
  drain is a design question — a new `/rethink approve` target that reads the artifact and
  re-enters 1d — and belongs to its own spec, not to a fix wave.

---

## Self-Review

**Spec coverage.** D1/D2 → Tasks 2, 5; D3 → Tasks 1-4, 6; D4 → Task 3; D5 → Deferrals + Task 5's guard; D6 → Task 7; D7/D8 → Task 8; D9 → Task 9; D10 → no task, correctly (a decision *not* to build); D11 → Task 1; D12 → Tasks 2, 4. Rebuild-contract rules 1-6 → Tasks 2 (1, 6), 3 (2, 3a-c, 6), 4 (1, 4, 5). Spec Testing-table rows: all covered in Tasks 1-4 **except** "renamed `ops/`", now recorded in Deferrals rather than claimed — the first draft's Self-Review asserted full coverage and was false on that row and on rule 3(a).

**Placeholder scan.** No "TBD", no "add error handling", no "similar to Task N". Every code step carries runnable code; every verification step carries its command and its expected result, including the intermediate failure counts (9 / 6 / 7), which the first draft stated wrongly as 10 / 11 / 12. Three steps deliberately instruct *stopping* (Task 5 Step 1, Task 7 Step 1, and Task 4 Step 5's "a mutation that changes nothing is itself a finding").

**Type consistency.** `moc_section_for <status> <map-string>` — two args, rc 0/1/2 — is called that way in Tasks 1 and 3. `_moc_each_pair <map-string>` likewise. `moc_harvest_entries` emits `slug<TAB>summary`, consumed as `-F'\t'` in Tasks 2-3. `moc_render <notes-dir> <map-string>` returns 1 on a bad directory in Task 2 and Task 4 depends on that rc. `rebuild_status_moc <moc-file> <notes-dir> <map-string>` has the same three-argument order in Tasks 4, 5 and its own provenance comment. `check_lib` uses the real four-argument signature. `MOC_SYNC_VERSION` floor is 1 in Task 5's guard and Task 6's call, and Task 6 Step 3 asserts they agree. The `act:` vocabulary is introduced in Task 7 and consumed unchanged in Task 8. **No counter variable crosses a command-substitution boundary** — the first draft's `moc_unplaceable_count` did, and could never be read.
