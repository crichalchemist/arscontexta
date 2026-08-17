# MOC Derivation and Approval Channel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `/rethink`'s stateful MOC edit with an idempotent derivation from frontmatter, and restructure its approval gates so a run without an interactive channel completes instead of stalling.

**Architecture:** A new shell library `reference/lib/moc-sync.sh` derives a status MOC (section membership, wiki-links, counts) from note frontmatter, preserving existing human-visible summaries and reporting — never silently dropping — any note it cannot place. `skill-sources/rethink/SKILL.md` calls it behind a fail-loud version guard instead of instructing an agent to move entries by hand, and its two blocking approval gates are redrawn so frontmatter status edits proceed while every side effect routes to a persisted artifact for separate approval.

**Tech Stack:** bash (POSIX-leaning, must also run under zsh), `awk`, `sed`, `/usr/bin/grep`, `find`; existing libraries `reference/lib/frontmatter.sh` and `reference/lib/queue-edit.sh` (v2, provides `queue_yaml`); test suites are hand-rolled bash assertion counters following `reference/test/queue-edit.test.sh`.

**Spec:** `docs/superpowers/specs/2026-08-17-hub-derivation-and-approval-channel-design.md`

## Global Constraints

Every task's requirements implicitly include this section. Values are copied from the spec and from `CLAUDE.md`.

- **Do not write `platforms/shared/skill-blocks/`.** It is `cksum`-frozen at any depth by `check-portability.sh` check 4; any modification, deletion or unpinned addition fails CI.
- **Never `git add docs/field-intel-2026-08-15.md` or `docs/field-intel-2026-08-17.md`.** Both are untracked by design and must stay so. Stage files by explicit path — never `git add -A` or `git add .`.
- **Canonical vocabulary, not vault dialect.** Every new identifier uses **MOC** (`reference/vocabulary-transforms.md:17`), never "hub". Library function names are not vocabulary-substituted, so a dialect name ships verbatim into every generated vault.
- **`skill-sources/` templates use placeholders, not concrete paths**, for anything vocabulary-variable: `{vocabulary.notes}`, `{vocabulary.topic_map}`, `{DOMAIN:note}`. `ops/` is canonical and stays literal.
- **`MOC_SYNC_VERSION` starts at `1`.** Consumer fences guard `[ "$MOC_SYNC_VERSION" -lt 1 ]`.
- **The section map is a pinned input** (spec Decision 11), never an implementer's choice. Task 1 fixes it.
- **Entry order within a section is ascending by filename** (spec Decision 12), so idempotence means the same thing across vaults, not only within one.
- **Every test suite must pass under both `bash` and `zsh`.** Three shipped defects in this repo were shell forks. Unquoted `$var` does not word-split under zsh; a non-matching glob is a hard error under zsh's default `nomatch`.
- **Run gates UNPIPED when the rc matters.** `false | tail -1; echo $?` yields `0`. Piping a `grep` that legitimately returns rc 1 into `wc -l` converts "no hits" into a plausible `0` at rc 0.
- **Use `/usr/bin/grep`, never bare `grep`** — it is intercepted and rewritten in this environment, and output is mangled and truncated.
- **Adding a check has a mandatory documentation cost.** Task 9 updates `CLAUDE.md`'s declared numerals tree-side in the same commit. The `main`-side numeral takes a documented post-merge correction — no value is green on both sides of a merge.
- **`~/second-brain` is READ-ONLY** for the whole of this plan. Use it to measure, never to write. Fixtures go under `mktemp -d`.

---

## File Structure

| File | Responsibility |
|---|---|
| `reference/lib/moc-sync.sh` (create) | The derivation: section mapping, entry harvesting, rendering, guarded write. Sole owner of MOC output format. |
| `reference/test/moc-sync.test.sh` (create) | Behavioral tests for the above, both shells. |
| `skill-sources/rethink/SKILL.md` (modify) | `:329` becomes a rebuild call behind a version guard; approval gates redrawn by act; proposal phase terminates in an artifact. |
| `skills/health/SKILL.md` (modify) | Category 9 gains a `moc-sync` library check via the existing `check_lib` helper. |
| `.github/workflows/checks.yml` (modify) | Two steps for the new suite (bash + zsh). |
| `CLAUDE.md` (modify) | Declared numerals: check count, CI step count. Verification table row for the new gate. |

---

### Task 1: Section map and status resolution

The foundation for rule 6. Three section vocabularies are live in the field simultaneously, and any single map silently drops the others' notes — 2 dissolved observations and 14 promoted/archived tensions today. This task makes an unmappable status a reportable event rather than an absence.

**Files:**
- Create: `reference/lib/moc-sync.sh`
- Create: `reference/test/moc-sync.test.sh`

**Interfaces:**
- Consumes: nothing (first task).
- Produces:
  - `MOC_SYNC_VERSION` — integer, `1`.
  - `moc_section_for <status> <status:Section>...` — prints the section name for `<status>` on stdout, rc 0. Prints nothing and returns **rc 2** when the status matches no pair. Returns rc 1 on a usage error (empty status, or no pairs supplied).
  - `MOC_MAP_OBSERVATIONS` — array-free, space-free canonical map string for observation notes.
  - `MOC_MAP_TENSIONS` — the same for tension notes.

- [ ] **Step 1: Write the failing test**

Create `reference/test/moc-sync.test.sh`:

```bash
#!/bin/bash
# moc-sync.test.sh — behavioral tests for reference/lib/moc-sync.sh.
#
# Runs under bash AND zsh; CI runs both. Assertions here pin the contract the
# library's header argues for, because this repo's dominant failure mode is a
# function that exits 0 having done nothing.

LIB="$(cd "$(dirname "$0")/../lib" && pwd)/moc-sync.sh"
PASS=0; FAIL=0

ok() { # ok <label> <expected> <actual>
  if [ "$2" = "$3" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); printf 'FAIL %s\n  expected: [%s]\n  actual:   [%s]\n' "$1" "$2" "$3"; fi
}

# shellcheck source=/dev/null
. "$LIB" || { echo "FAIL: cannot source $LIB"; exit 1; }

MAP_OBS="open:Open implemented:Implemented archived:Archived"

# --- moc_section_for -------------------------------------------------------
ok "maps a known status" "Open" "$(moc_section_for open $MAP_OBS)"
ok "maps a second known status" "Implemented" "$(moc_section_for implemented $MAP_OBS)"

# An off-map status must be rc 2 AND print nothing. rc alone is not enough:
# a function that prints a guessed section and returns 2 would pass an rc-only test.
off_out=$(moc_section_for dissolved $MAP_OBS); off_rc=$?
ok "off-map status returns rc 2" "2" "$off_rc"
ok "off-map status prints nothing" "" "$off_out"

# Usage errors are rc 1, distinct from rc 2 — the caller must be able to tell
# "this vault has an unmapped status" from "the caller passed nothing".
moc_section_for "" $MAP_OBS >/dev/null 2>&1; ok "empty status is rc 1" "1" "$?"
moc_section_for open        >/dev/null 2>&1; ok "no pairs is rc 1"     "1" "$?"

# --- the pinned maps ------------------------------------------------------
# Pinned by VALUE, so a later edit that silently drops a status reddens here.
ok "observations map is pinned" \
   "open:Open implemented:Implemented archived:Archived dissolved:Dissolved" \
   "$MOC_MAP_OBSERVATIONS"
ok "tensions map is pinned" \
   "open:Open blocked:Blocked implemented:Implemented promoted:Promoted archived:Archived dissolved:Dissolved resolved:Resolved" \
   "$MOC_MAP_TENSIONS"

# Every status the field vault holds must be mappable — this is rule 6's whole point.
for s in open implemented archived dissolved; do
  moc_section_for "$s" $MOC_MAP_OBSERVATIONS >/dev/null \
    || { FAIL=$((FAIL+1)); echo "FAIL: observations map cannot place '$s'"; }
done
for s in open blocked implemented promoted archived dissolved resolved; do
  moc_section_for "$s" $MOC_MAP_TENSIONS >/dev/null \
    || { FAIL=$((FAIL+1)); echo "FAIL: tensions map cannot place '$s'"; }
done
PASS=$((PASS+11))

printf '\nmoc-sync: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run it to confirm it fails for the stated reason**

```bash
bash reference/test/moc-sync.test.sh
```

Expected: `FAIL: cannot source .../moc-sync.sh`, exit 1. The file does not exist yet. **If it fails any other way, stop and read the error** — a suite that fails for the wrong reason proves nothing.

- [ ] **Step 3: Write the minimal implementation**

Create `reference/lib/moc-sync.sh`:

```bash
#!/bin/bash
# moc-sync.sh — derive a status MOC (e.g. ops/observations.md) from note frontmatter.
#
# WHY THIS EXISTS: skill-sources/rethink/SKILL.md used to instruct an agent to "move
# entries between Pending/Promoted/Blocked/Archived/Resolved/Dissolved sections". That is
# incremental maintenance of a cache, and it can only be correct if every status change
# flows through the mover. Four templates write the notes a status MOC indexes and only
# one touched the MOC, so it diverged at the rate of note activity. Deriving is idempotent:
# running it IS the repair and running it twice is a no-op.
#
# NAMED MOC, NOT HUB. "Hub" is the field vault's dialect; the canonical term is MOC
# (reference/vocabulary-transforms.md:17). A library ships verbatim into every generated
# vault's ops/lib/ and its function names are NOT vocabulary-substituted, so a dialect
# name here would hardcode one user's word into every system.
MOC_SYNC_VERSION=1

# THE SECTION MAP IS PINNED HERE, NOT CHOSEN BY CALLERS. Three vocabularies are live in
# the field at once: rethink's own six-name instruction, the observations MOC's
# "canonical three", and a tensions MOC carrying a literal "Non-canonical status:
# resolved" heading. A rebuild under any one of them silently drops the others' notes —
# measured 2026-08-17: 2 dissolved observations, 8 promoted + 6 archived tensions. Silent
# omission of a note that exists is the exact defect this library was written to remove,
# so every status a vault can hold gets a section.
MOC_MAP_OBSERVATIONS="open:Open implemented:Implemented archived:Archived dissolved:Dissolved"
MOC_MAP_TENSIONS="open:Open blocked:Blocked implemented:Implemented promoted:Promoted archived:Archived dissolved:Dissolved resolved:Resolved"

# moc_section_for <status> <status:Section>... -> section name
#   rc 0 = mapped (section printed)
#   rc 2 = off-map (NOTHING printed — the caller reports it per rule 6)
#   rc 1 = usage error
# rc 2 is deliberately distinct from rc 1 so a caller can tell "this vault holds a status
# no section covers" from "I called this wrong". Collapsing them would make an off-map
# note indistinguishable from a bug in the caller.
moc_section_for() {
  local status="$1"
  shift
  if [ -z "$status" ] || [ $# -eq 0 ]; then
    echo "error: moc-sync: moc_section_for needs <status> <status:Section>..." >&2
    return 1
  fi
  local pair
  for pair in "$@"; do
    if [ "${pair%%:*}" = "$status" ]; then
      printf '%s\n' "${pair#*:}"
      return 0
    fi
  done
  return 2
}
```

- [ ] **Step 4: Run the suite under both shells**

```bash
bash reference/test/moc-sync.test.sh; echo "bash rc=$?"
zsh  reference/test/moc-sync.test.sh; echo "zsh  rc=$?"
```

Expected: `19 passed, 0 failed` and rc=0 under both. **Note the unquoted `$MAP_OBS` in the test is intentional word-splitting** — under zsh that does NOT split, so if the zsh run fails on the mapping assertions, the fix is to quote-and-split explicitly in the test (`set -- ${=MAP_OBS}` is zsh-only; use a portable `for pair in $(printf '%s\n' "$MAP_OBS")` loop instead). Do not "fix" the library for a test-harness shell fork.

- [ ] **Step 5: Commit**

```bash
git add reference/lib/moc-sync.sh reference/test/moc-sync.test.sh
git commit -m "feat: moc-sync section map and status resolution

Pins the canonical section map for observation and tension notes, and makes an
unmappable status a distinguishable rc 2 rather than an absence. Three section
vocabularies are live in the field simultaneously; any single map drops 16
existing notes silently, which is the defect this library exists to remove."
```

---

### Task 2: Harvest existing entries and render sections

The derivation core: membership, wiki-links, counts and ordering. Summaries are carried forward verbatim here; Task 3 adds the divergence warning.

**Files:**
- Modify: `reference/lib/moc-sync.sh`
- Modify: `reference/test/moc-sync.test.sh`

**Interfaces:**
- Consumes: `moc_section_for`, `MOC_MAP_OBSERVATIONS` from Task 1.
- Produces:
  - `moc_harvest_entries <moc-file>` — prints `slug<TAB>summary` for every `- [[slug]] — summary` line, one per line, in file order. Prints nothing (rc 0) for a missing or entry-free file.
  - `moc_render <notes-dir> <status:Section>...` — prints the complete MOC body to stdout. Does not write files.

- [ ] **Step 1: Write the failing tests**

Append to `reference/test/moc-sync.test.sh`, immediately before the final `printf`:

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

# --- moc_harvest_entries --------------------------------------------------
cat > "$FIX/observations.md" <<'EOF'
# Observations

## Open (1)
- [[alpha-note]] — Alpha description here
- [[zebra-note]] — Zebra description that was EDITED
EOF
ok "harvest finds both entries" "2" "$(moc_harvest_entries "$FIX/observations.md" | /usr/bin/grep -c .)"
ok "harvest carries the prose" "Zebra description that was EDITED" \
   "$(moc_harvest_entries "$FIX/observations.md" | /usr/bin/awk -F'\t' '$1=="zebra-note"{print $2}')"
ok "harvest of a missing file is empty, rc 0" "" "$(moc_harvest_entries "$FIX/nope.md" 2>/dev/null)"
moc_harvest_entries "$FIX/nope.md" >/dev/null 2>&1; ok "harvest of a missing file is rc 0" "0" "$?"

# --- moc_render -----------------------------------------------------------
BODY=$(moc_render "$FIX/observations" $MOC_MAP_OBSERVATIONS)

ok "Open heading counts 2" "## Open (2)"        "$(printf '%s\n' "$BODY" | /usr/bin/grep -m1 '^## Open')"
ok "Implemented heading counts 1" "## Implemented (1)" \
   "$(printf '%s\n' "$BODY" | /usr/bin/grep -m1 '^## Implemented')"

# ORDER IS ASCENDING BY FILENAME (spec Decision 12). Without a pinned order,
# "idempotent" holds per-vault and means nothing across vaults.
ok "entries sort by filename" "alpha-note zebra-note" \
   "$(printf '%s\n' "$BODY" | /usr/bin/awk '/^## Open/{f=1;next} /^## /{f=0} f&&/^- \[\[/' \
      | /usr/bin/sed 's/^- \[\[//; s/\]\].*//' | /usr/bin/tr '\n' ' ' | /usr/bin/sed 's/ $//')"

# An existing summary is carried forward; a note with no existing entry is seeded
# from its description.
ok "existing prose is carried forward" "Zebra description that was EDITED" \
   "$(printf '%s\n' "$BODY" | /usr/bin/sed -n 's/^- \[\[zebra-note\]\] — //p')"
ok "new entry is seeded from description" "Middle description here" \
   "$(printf '%s\n' "$BODY" | /usr/bin/sed -n 's/^- \[\[middle-note\]\] — //p')"

# EVERY SECTION IN THE MAP IS EMITTED, even at zero — an absent section is
# indistinguishable from "no notes have that status", and a reader cannot tell
# whether the rebuild considered it.
ok "empty sections are emitted at 0" "## Dissolved (0)" \
   "$(printf '%s\n' "$BODY" | /usr/bin/grep -m1 '^## Dissolved')"
PASS=$((PASS+0))
```

- [ ] **Step 2: Run to confirm the new assertions fail**

```bash
bash reference/test/moc-sync.test.sh
```

Expected: the Task 1 assertions still pass; every new one fails with an empty `actual` because neither function exists. Confirm the failure count is 10 and not 19 — Task 1's work must not have regressed.

- [ ] **Step 3: Implement both functions**

Append to `reference/lib/moc-sync.sh`:

```bash
# moc_harvest_entries <moc-file> -> "slug<TAB>summary" per entry, file order.
# A missing file is not an error: a vault whose MOC does not exist yet is a
# legitimate first-run state, and the rebuild creates it.
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

# moc_render <notes-dir> <status:Section>... -> the MOC body on stdout.
#
# Pure: writes no files, so a caller can diff a candidate render against the live
# file before committing to it. Task 4 adds the guarded write around this.
moc_render() {
  local dir="$1"
  shift
  if [ ! -d "$dir" ]; then
    echo "error: moc-sync: not a directory: '$dir'" >&2
    return 1
  fi
  if [ $# -eq 0 ]; then
    echo "error: moc-sync: moc_render needs <notes-dir> <status:Section>..." >&2
    return 1
  fi

  local moc_file="${MOC_SYNC_EXISTING:-}"
  local harvest="" pair section status slug desc summary note
  [ -n "$moc_file" ] && harvest=$(moc_harvest_entries "$moc_file")

  for pair in "$@"; do
    section="${pair#*:}"
    status="${pair%%:*}"

    # Collect this section's notes, sorted by filename (Decision 12).
    # LC_ALL=C pins the collation: a locale-dependent sort makes "idempotent"
    # depend on the caller's environment, which is not idempotent at all.
    local lines="" count=0
    for note in $(LC_ALL=C find -H "$dir" -type f -name '*.md' 2>/dev/null | LC_ALL=C sort); do
      [ "$(frontmatter_field "$note" status 2>/dev/null)" = "$status" ] || continue
      slug=$(basename "$note" .md)

      # Carry an existing summary forward verbatim; otherwise seed from description.
      summary=$(printf '%s\n' "$harvest" | /usr/bin/awk -F'\t' -v s="$slug" '$1==s{print $2; exit}')
      if [ -z "$summary" ]; then
        desc=$(frontmatter_field "$note" description 2>/dev/null)
        summary="$desc"
      fi
      lines="${lines}- [[${slug}]] — ${summary}
"
      count=$((count + 1))
    done

    printf '## %s (%d)\n' "$section" "$count"
    [ "$count" -gt 0 ] && printf '%s' "$lines"
    printf '\n'
  done
}
```

Note the suite must now source `frontmatter.sh` too. Add near the top of the test file, after the `LIB` assignment:

```bash
FMLIB="$(cd "$(dirname "$0")/../lib" && pwd)/frontmatter.sh"
# shellcheck source=/dev/null
. "$FMLIB" || { echo "FAIL: cannot source $FMLIB"; exit 1; }
```

and set `MOC_SYNC_EXISTING="$FIX/observations.md"` before the `moc_render` call.

- [ ] **Step 4: Run under both shells**

```bash
bash reference/test/moc-sync.test.sh; echo "bash rc=$?"
zsh  reference/test/moc-sync.test.sh; echo "zsh  rc=$?"
```

Expected: `0 failed`, rc=0 both. If the zsh run reports zero notes in every section, the `for note in $(find ...)` word-split is the cause — replace it with a `while IFS= read -r note` loop over a process substitution or a temp file, which is portable and also survives filenames with spaces.

- [ ] **Step 5: Commit**

```bash
git add reference/lib/moc-sync.sh reference/test/moc-sync.test.sh
git commit -m "feat: moc-sync entry harvesting and section rendering

Derives membership, wiki-links and counts from frontmatter; carries existing
summaries forward and seeds new entries from description. Entry order is
ascending by filename under LC_ALL=C, so idempotence means the same thing
across vaults rather than only within one. Every mapped section is emitted
even at zero, because an absent section cannot be distinguished from an
unconsidered one."
```

---

### Task 3: Summary divergence warning and the three unplaceable-note reports

Rules 2 and 3. This is where the spec's measured reality lands: 33 of 90 observation entries and 7 of 16 tension entries are **not** prefixes of their note's current `description`, so overwriting would destroy ~40 human-visible summaries.

**Files:**
- Modify: `reference/lib/moc-sync.sh`
- Modify: `reference/test/moc-sync.test.sh`

**Interfaces:**
- Consumes: `moc_render`, `moc_harvest_entries`, `moc_section_for`.
- Produces:
  - `moc_render` gains stderr warnings; stdout is unchanged.
  - Warning formats, exact:
    - `warn: moc-sync: summary not derivable from current frontmatter: <slug>`
    - `warn: moc-sync: note has no readable status, not placed: <path>`
    - `warn: moc-sync: status '<status>' maps to no section, not placed: <slug>`
  - `moc_unplaceable_count` — integer set by `moc_render`, the total of the last two categories.

- [ ] **Step 1: Write the failing tests**

Append before the final `printf`:

```bash
# --- rule 2: divergent summary preserved AND warned about ------------------
# zebra-note's entry says "...that was EDITED"; its description says
# "Zebra description here". That is a genuine divergence, and it is the common
# case in the field: 33 of 90 observation entries diverge.
ERRF="$FIX/stderr.txt"
BODY=$(MOC_SYNC_EXISTING="$FIX/observations.md" \
       moc_render "$FIX/observations" $MOC_MAP_OBSERVATIONS 2>"$ERRF")

ok "divergent summary is preserved in output" "Zebra description that was EDITED" \
   "$(printf '%s\n' "$BODY" | /usr/bin/sed -n 's/^- \[\[zebra-note\]\] — //p')"
ok "divergent summary warns exactly once" "1" \
   "$(/usr/bin/grep -c 'summary not derivable' "$ERRF")"
ok "the warning names the slug" "1" \
   "$(/usr/bin/grep -c 'summary not derivable from current frontmatter: zebra-note' "$ERRF")"

# THE WARNING MUST NOT CLAIM A CAUSE. "someone hand-edited this" is measurably wrong
# for most divergent entries — 7 of 29 divergent Implemented entries follow a second
# derivation convention ("implemented via <target>"), and the rest are stale
# derivations from an edited description.
ok "warning does not assert hand-editing" "0" "$(/usr/bin/grep -ci 'hand.edit' "$ERRF")"

# An AGREEING summary must not warn — otherwise every run warns about everything
# and the signal is worthless.
ok "agreeing summary does not warn" "0" \
   "$(/usr/bin/grep -c 'not derivable from current frontmatter: alpha-note' "$ERRF")"

# --- rule 3(b): note exists, status unreadable ----------------------------
# reference/lib/frontmatter.sh treats an UNCLOSED frontmatter block as NO
# frontmatter. Such a note exists, so "the note is gone" cannot catch it — this is
# precisely the predicate the first draft of the spec's rule 3 got wrong.
printf -- '---\ndescription: Unclosed\nstatus: open\n\nbody\n' > "$FIX/observations/broken-note.md"
BODY=$(MOC_SYNC_EXISTING="$FIX/observations.md" \
       moc_render "$FIX/observations" $MOC_MAP_OBSERVATIONS 2>"$ERRF")
ok "unreadable status is reported" "1" "$(/usr/bin/grep -c 'no readable status' "$ERRF")"
ok "unreadable note is NOT silently placed" "0" \
   "$(printf '%s\n' "$BODY" | /usr/bin/grep -c 'broken-note')"
rm -f "$FIX/observations/broken-note.md"

# --- rule 6 / rule 3(c): status readable but off-map ----------------------
mknote orphan-note superseded "Orphan description"
BODY=$(MOC_SYNC_EXISTING="$FIX/observations.md" \
       moc_render "$FIX/observations" $MOC_MAP_OBSERVATIONS 2>"$ERRF")
ok "off-map status is reported" "1" "$(/usr/bin/grep -c "maps to no section" "$ERRF")"
ok "off-map report names the status and slug" "1" \
   "$(/usr/bin/grep -c "status 'superseded' maps to no section, not placed: orphan-note" "$ERRF")"
ok "off-map note is NOT silently dropped from the count" "1" "$moc_unplaceable_count"
rm -f "$FIX/observations/orphan-note.md"
```

- [ ] **Step 2: Run to confirm the new assertions fail**

```bash
bash reference/test/moc-sync.test.sh
```

Expected: 11 new failures; Tasks 1-2 assertions still green.

- [ ] **Step 3: Implement**

In `reference/lib/moc-sync.sh`, replace the body of the per-note loop inside `moc_render` so it classifies before placing. The full revised loop:

```bash
    local lines="" count=0
    while IFS= read -r note; do
      [ -n "$note" ] || continue
      local st
      st=$(frontmatter_field "$note" status 2>/dev/null)

      if [ -z "$st" ]; then
        # Only report once per note, not once per section — the outer loop visits
        # every note for every section, so an unguarded warning would fire N times.
        if [ "$section" = "$_moc_first_section" ]; then
          echo "warn: moc-sync: note has no readable status, not placed: $note" >&2
          moc_unplaceable_count=$((moc_unplaceable_count + 1))
        fi
        continue
      fi

      if ! moc_section_for "$st" "$@" >/dev/null 2>&1; then
        if [ "$section" = "$_moc_first_section" ]; then
          echo "warn: moc-sync: status '$st' maps to no section, not placed: $(basename "$note" .md)" >&2
          moc_unplaceable_count=$((moc_unplaceable_count + 1))
        fi
        continue
      fi

      [ "$st" = "$status" ] || continue
      slug=$(basename "$note" .md)

      summary=$(printf '%s\n' "$harvest" | /usr/bin/awk -F'\t' -v s="$slug" '$1==s{print $2; exit}')
      desc=$(frontmatter_field "$note" description 2>/dev/null)
      if [ -z "$summary" ]; then
        summary="$desc"
      else
        # Rule 2: keep the file's version, and warn only when it is not derivable.
        # NORMALISE BEFORE COMPARING: the live convention truncates with an ellipsis,
        # so a raw string compare would flag every correctly-derived entry.
        local a b
        a=$(printf '%s' "$summary" | /usr/bin/tr -d '\r' | /usr/bin/sed 's/[.… ]*$//')
        b=$(printf '%s' "$desc"    | /usr/bin/tr -d '\r' | /usr/bin/sed 's/[.… ]*$//')
        case "$b" in
          "$a"*) : ;;                       # derivable: existing is a prefix of description
          *) echo "warn: moc-sync: summary not derivable from current frontmatter: $slug" >&2 ;;
        esac
      fi
      lines="${lines}- [[${slug}]] — ${summary}
"
      count=$((count + 1))
    done <<EOF
$(LC_ALL=C find -H "$dir" -type f -name '*.md' 2>/dev/null | LC_ALL=C sort)
EOF
```

And immediately after the argument checks in `moc_render`, before the section loop:

```bash
  moc_unplaceable_count=0
  _moc_first_section="${1#*:}"
```

**Why the `_moc_first_section` guard.** `moc_render` visits every note once per section, so an unguarded warning fires once per section per note — 4 copies for observations, 7 for tensions. Reporting on the first section only gives exactly one report per note. The alternative, a seen-list, needs an associative array and is not portable to both shells.

- [ ] **Step 4: Run under both shells**

```bash
bash reference/test/moc-sync.test.sh; echo "bash rc=$?"
zsh  reference/test/moc-sync.test.sh; echo "zsh  rc=$?"
```

Expected: `0 failed`, rc=0 both.

- [ ] **Step 5: Measure against the real field vault, read-only**

This is the step that proves the warning is usable rather than merely correct. Expect roughly 33 divergence warnings for observations and 7 for tensions — the spec's measured figures.

```bash
cd /Volumes/Containers/arscontexta
. reference/lib/frontmatter.sh; . reference/lib/moc-sync.sh
MOC_SYNC_EXISTING=~/second-brain/ops/observations.md \
  moc_render ~/second-brain/ops/observations $MOC_MAP_OBSERVATIONS \
  >/tmp/rendered-obs.md 2>/tmp/rendered-obs.err
/usr/bin/grep -c 'not derivable'      /tmp/rendered-obs.err   # expect ~33
/usr/bin/grep -c 'maps to no section' /tmp/rendered-obs.err   # expect 0 — dissolved IS mapped
/usr/bin/grep -c '^- \[\[' /tmp/rendered-obs.md               # expect 112, every observation placed
```

**The second number is the load-bearing one:** 0 off-map reports means the pinned map covers every status the field vault actually holds. If it is non-zero, the map is incomplete — add the status to `MOC_MAP_OBSERVATIONS` and to Task 1's pinned-value assertion in the same commit.

- [ ] **Step 6: Commit**

```bash
git add reference/lib/moc-sync.sh reference/test/moc-sync.test.sh
git commit -m "feat: moc-sync preserves divergent summaries and reports unplaceable notes

Rule 2: a summary that is not a prefix of its note's description is preserved
and warned about, with wording that does not assert a cause — 'someone
hand-edited this' is measurably wrong for most of the ~40 divergent entries in
the field.

Rule 3: three distinct reports for the three ways a note cannot be placed —
gone, status unreadable (the unclosed-frontmatter case, which 'the note is
gone' cannot catch), and status off-map. None is a silent omission, because
silent omission of an existing note is the defect this library removes."
```

---

### Task 4: The guarded write

Rules 4 and 5. Mirrors `queue-edit.sh`'s lock-and-guarded-rename idiom exactly, including the defect `queue-edit.test.sh` was written red to pin: a commit step ending `mv "$tmp" "$file"` with no `||` leaves the temp on disk, prints nothing, and returns the exit status of the following `rm -rf` — which is 0.

**Files:**
- Modify: `reference/lib/moc-sync.sh`
- Modify: `reference/test/moc-sync.test.sh`

**Interfaces:**
- Consumes: `moc_render`.
- Produces: `rebuild_status_moc <moc-file> <notes-dir> <status:Section>...` — rc 0 on success, rc 1 on any failure (lock, render, rename). On failure the target file is byte-identical to before and no temp survives beside it.

- [ ] **Step 1: Write the failing tests**

```bash
# --- rebuild_status_moc ---------------------------------------------------
cp "$FIX/observations.md" "$FIX/observations.md.orig"
rebuild_status_moc "$FIX/observations.md" "$FIX/observations" $MOC_MAP_OBSERVATIONS 2>/dev/null
ok "rebuild returns 0" "0" "$?"
ok "rebuild wrote the Open heading" "## Open (2)" \
   "$(/usr/bin/grep -m1 '^## Open' "$FIX/observations.md")"
ok "rebuild emitted provenance" "1" "$(/usr/bin/grep -c '^derived: [0-9]' "$FIX/observations.md")"
ok "provenance carries the re-derive command" "1" \
   "$(/usr/bin/grep -c 'rebuild_status_moc' "$FIX/observations.md")"

# IDEMPOTENCE: two consecutive rebuilds are byte-identical. The provenance
# timestamp is excluded, because a wall-clock stamp legitimately differs and
# comparing it would make this assertion fail for the wrong reason.
strip() { /usr/bin/grep -v '^derived: ' "$1"; }
rebuild_status_moc "$FIX/observations.md" "$FIX/observations" $MOC_MAP_OBSERVATIONS 2>/dev/null
strip "$FIX/observations.md" > "$FIX/pass1.txt"
rebuild_status_moc "$FIX/observations.md" "$FIX/observations" $MOC_MAP_OBSERVATIONS 2>/dev/null
strip "$FIX/observations.md" > "$FIX/pass2.txt"
cmp -s "$FIX/pass1.txt" "$FIX/pass2.txt"; ok "two rebuilds are byte-identical" "0" "$?"

# ORDER-INDEPENDENCE: a second fixture with the same frontmatter but the entries
# listed in a different order must produce the same file. An implementation that
# "preserves existing order and appends" passes the idempotence test above and
# fails this one — which is the whole reason Decision 12 pins the sort.
mkdir -p "$FIX/obs2"; cp "$FIX/observations"/*.md "$FIX/obs2/" 2>/dev/null
cat > "$FIX/moc2.md" <<'EOF'
## Open (2)
- [[zebra-note]] — Zebra description that was EDITED
- [[alpha-note]] — Alpha description here
EOF
rebuild_status_moc "$FIX/moc2.md" "$FIX/obs2" $MOC_MAP_OBSERVATIONS 2>/dev/null
strip "$FIX/moc2.md" > "$FIX/pass3.txt"
cmp -s "$FIX/pass1.txt" "$FIX/pass3.txt"; ok "reordered input yields identical output" "0" "$?"

# GUARDED RENAME: a failed mv returns 1, discards its temp, and names the path.
# Forced with a shell-function stub — a genuine same-directory mv failure needs
# `chflags uchg` (macOS) or `chattr +i` (root, Linux) and is not portable to CI.
# The MECHANISM is covered here; the organic trigger is hand-run only, and that
# is not the same claim. queue-edit.test.sh records the identical limitation.
cp "$FIX/observations.md" "$FIX/before-mv.txt"
mv() { return 1; }
rebuild_status_moc "$FIX/observations.md" "$FIX/observations" $MOC_MAP_OBSERVATIONS 2>"$ERRF"
ok "failed rename returns 1" "1" "$?"
unset -f mv
ok "failed rename names the path" "1" "$(/usr/bin/grep -c "$FIX/observations.md" "$ERRF")"
cmp -s "$FIX/observations.md" "$FIX/before-mv.txt"; ok "target unchanged after failed rename" "0" "$?"
ok "no temp survives beside the target" "0" \
   "$(find "$FIX" -maxdepth 1 -name 'observations.md.*tmp*' | /usr/bin/grep -c .)"
```

- [ ] **Step 2: Run to confirm failure**

```bash
bash reference/test/moc-sync.test.sh
```

Expected: 12 new failures, earlier tasks green.

- [ ] **Step 3: Implement**

```bash
# _moc_lock <file> -> prints the lock dir it created, rc 0; rc 1 on timeout.
# mkdir is the atomic primitive. A BOUNDED WAIT THAT FAILS MUST NOT BREAK THE LOCK
# IT COULD NOT TAKE — an auto-break wearing a failure message is how concurrent
# writers lose updates. queue-edit.sh's header argues this at length; this is the
# same contract.
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

# rebuild_status_moc <moc-file> <notes-dir> <status:Section>...
rebuild_status_moc() {
  local file="$1" dir="$2"
  shift 2
  if [ -z "$file" ] || [ -z "$dir" ] || [ $# -eq 0 ]; then
    echo "error: moc-sync: rebuild_status_moc needs <moc-file> <notes-dir> <status:Section>..." >&2
    return 1
  fi

  local lockdir tmp
  lockdir=$(_moc_lock "$file") || return 1
  tmp="${file}.$$.tmp"

  {
    printf '# %s\n\n' "$(basename "$file" .md)"
    printf 'derived: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf '<!-- Derived from note frontmatter. Do not move entries by hand; they will be\n'
    printf '     regenerated. Re-derive with:\n'
    printf '       . ops/lib/moc-sync.sh && rebuild_status_moc %s %s <status:Section>... -->\n\n' \
      "$file" "$dir"
    MOC_SYNC_EXISTING="$file" moc_render "$dir" "$@"
  } > "$tmp" 2>>/dev/stderr

  if [ ! -s "$tmp" ]; then
    echo "error: moc-sync: render produced an empty file; '$file' left unchanged" >&2
    rm -f "$tmp"; rm -rf "$lockdir"; return 1
  fi

  # THE GUARDED RENAME. Ending this `mv` without a failure branch returns the exit
  # status of the following `rm -rf` — which is 0 — while leaving an undeclared
  # second copy of the content on disk. That exact defect shipped in
  # queue-edit.sh and its suite was written red to pin it.
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

Expected: `0 failed`, rc=0 both.

- [ ] **Step 5: Commit**

```bash
git add reference/lib/moc-sync.sh reference/test/moc-sync.test.sh
git commit -m "feat: moc-sync guarded write with lock, provenance and idempotence

Mirrors queue-edit.sh: a bounded lock wait that fails does NOT break the lock it
could not take, and a failed rename returns 1, discards its temp and names the
path rather than returning the rm's 0.

Two idempotence assertions, not one: byte-identical consecutive runs, AND
identical output from a fixture whose existing entries are in a different order.
A 'preserve current order and append' implementation passes the first and fails
the second, which is why Decision 12 pins the sort."
```

---

### Task 5: Wire the library into `skill-sources/rethink`

`:329` stops instructing a stateful edit. The fence carries a fail-loud version guard, matching the sourcing idiom already at `:160-171`.

**Files:**
- Modify: `skill-sources/rethink/SKILL.md` (the `:329` "Update MOCs" instruction, and a new fence beside it)

**Interfaces:**
- Consumes: `rebuild_status_moc`, `MOC_MAP_OBSERVATIONS`, `MOC_MAP_TENSIONS`, `MOC_SYNC_VERSION`.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Read the current instruction and its context**

```bash
/usr/bin/sed -n '325,333p' skill-sources/rethink/SKILL.md
/usr/bin/sed -n '160,172p' skill-sources/rethink/SKILL.md   # the sourcing idiom to match
```

Confirm `:329` still reads "**Update MOCs:** After triage execution, update `ops/observations.md` … Move entries between Pending/Promoted/Blocked/Archived/Resolved/Dissolved sections as appropriate." **If it does not, stop and report** — the line has moved and this task's anchor is stale.

- [ ] **Step 2: Replace the instruction**

Replace that line with:

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

# Version guard. A stale-but-working copy above the floor is fine; below it, the
# functions this fence calls either do not exist or do not honour the section map,
# and a rebuild would silently drop notes.
if [ "${MOC_SYNC_VERSION:-0}" -lt 1 ]; then
  echo "error: ops/lib/moc-sync.sh is older than this skill requires (need >= 1, have ${MOC_SYNC_VERSION:-none})" >&2
  echo "       run /arscontexta:upgrade to refresh it" >&2
  exit 1
fi

rc=0
rebuild_status_moc ops/observations.md ops/observations $MOC_MAP_OBSERVATIONS || rc=1
rebuild_status_moc ops/tensions.md     ops/tensions     $MOC_MAP_TENSIONS     || rc=1
if [ "$rc" -ne 0 ]; then
  echo "error: MOC rebuild failed; the MOCs are unchanged and still reflect the pre-triage state" >&2
  exit 1
fi
echo "MOCs rebuilt from frontmatter. Unplaceable notes, if any, are reported above."
```
```

- [ ] **Step 3: Verify the fence is self-contained and passes the fence gate**

Every ```bash fence in a SKILL.md runs as its own shell invocation, so a variable from an earlier fence expands to empty and `$(( ))` folds it to 0. This fence therefore sources both libraries itself rather than relying on the fence at `:164`.

```bash
bash reference/test/fence-isolation.test.sh 2>&1 | /usr/bin/tail -20
```

Expected: PASS. Read the `files=`/`fences=`/`run=`/`skipped=` line — **a fence that does not parse is SKIPPED, not failed**, so a rise in `skipped` is a silent failure of this step. Record the four numbers; Task 9 needs them.

- [ ] **Step 4: Verify the portability and placeholder gates**

```bash
bash reference/check-portability.sh;      echo "portability rc=$?"
bash reference/check-placeholder-count.sh main; echo "placeholder rc=$?"
bash reference/check-prose-paths.sh;      echo "prose-paths rc=$?"
```

Expected: rc=0 for all three, run unpiped. `check-placeholder-count.sh` is the gate that catches a backport hardcoding a vault's vocabulary into a template — this fence deliberately uses literal `ops/` paths, which is canonical and correct, and no `{vocabulary.*}` placeholder was removed.

- [ ] **Step 5: Commit**

```bash
git add skill-sources/rethink/SKILL.md
git commit -m "feat: rethink rebuilds MOCs from frontmatter instead of moving entries

:329 instructed a stateful edit of a derivable file. Four templates write the
notes a status MOC indexes (next, reduce, remember, rethink) and only this one
touched the MOC, so it diverged at the rate of note activity — three times, most
recently within 72 hours of a rebuild.

The fence sources both libraries itself because each bash fence in a SKILL.md is
its own shell invocation, and guards MOC_SYNC_VERSION >= 1 fail-loud rather than
letting a missing function read as an empty result."
```

---

### Task 6: `/health` gains a `moc-sync` library check

Mirrors the existing `check_lib` helper, whose floors are per-library and derived from the consumers' own guards. The queue-edit precedent also added a companion-file check, because a version constant cannot detect a library split from a file it needs.

**Files:**
- Modify: `skills/health/SKILL.md`

**Interfaces:**
- Consumes: `MOC_SYNC_VERSION` floor of 1, as declared by Task 5's guard.
- Produces: nothing.

- [ ] **Step 1: Read the existing helper and its per-library floors**

```bash
/usr/bin/grep -n 'check_lib\|FLOOR IS PER-LIBRARY\|queue_edit\.py' skills/health/SKILL.md | /usr/bin/head -20
```

Confirm `check_lib` exists and that its floors are per-library. **The floor must equal the consumers' guard, not the library's current version** — `/health` vouching at 1 for a library the skills refuse to run below 2 is a defect this repo has already shipped and reversed.

- [ ] **Step 2: Add the check**

Add a `check_lib` invocation for `moc-sync.sh` with floor **1**, alongside the existing three:

```bash
check_lib "moc-sync.sh"      "MOC_SYNC_VERSION"      1
```

- [ ] **Step 3: Verify the floor matches the consumer**

```bash
/usr/bin/grep -n 'MOC_SYNC_VERSION" -lt\|MOC_SYNC_VERSION:-0}" -lt' skill-sources/rethink/SKILL.md
/usr/bin/grep -n 'check_lib "moc-sync' skills/health/SKILL.md
```

Both must name **1**. If the guard is ever raised, this floor moves in the same commit.

- [ ] **Step 4: Run the gates**

```bash
bash reference/test/fence-isolation.test.sh 2>&1 | /usr/bin/tail -5
bash reference/check-prose-paths.sh; echo "prose-paths rc=$?"
```

Expected: PASS and rc=0.

- [ ] **Step 5: Commit**

```bash
git add skills/health/SKILL.md
git commit -m "feat: /health checks the moc-sync library at its consumer's floor

Floor is 1, derived from rethink's own guard rather than from the library's
current version — vouching at a floor below what a consumer requires reports
PASS beside every call to that library failing."
```

---

### Task 7: Redraw the approval gates by act

The spec's Critical C2. `1d` does far more than move statuses: PROMOTE creates knowledge-base notes, IMPLEMENT modifies files, and IMPLEMENT step 2 carries a **second** interactive gate. Un-gating the phase would auto-implement system changes, which `:704` forbids.

**Files:**
- Modify: `skill-sources/rethink/SKILL.md` (`:290`-`:292` and `1d`'s branch instructions)

**Interfaces:**
- Consumes: nothing.
- Produces: the artifact contract Task 8 implements — side-effect items are written with `status: awaiting_approval` and an `act:` field of `promote` | `implement` | `methodology`.

- [ ] **Step 1: Read the current gate and every `1d` branch**

```bash
/usr/bin/sed -n '286,296p' skill-sources/rethink/SKILL.md    # the ask + the blocking wait
/usr/bin/sed -n '293,322p' skill-sources/rethink/SKILL.md    # all five 1d branches
/usr/bin/sed -n '700,710p' skill-sources/rethink/SKILL.md    # :704, which must survive verbatim
```

Record which branches are status-only (ARCHIVE, KEEP PENDING) and which have side effects (PROMOTE, IMPLEMENT, METHODOLOGY). **If a sixth branch exists that this plan does not name, stop and report** — the act inventory is the whole basis of the split.

- [ ] **Step 2: Replace the blocking wait at `:292`**

Replace "**Wait for user confirmation before proceeding to 1d.** Do not execute triage without approval." with:

```markdown
**If an approval channel is available, wait for confirmation before proceeding to 1d.**

**If no approval channel is available** (subagent execution, where `AskUserQuestion` cannot
be used), proceed under the split below rather than stalling. A run that generates a triage
and then stops has produced nothing a later invocation can act on, which is how 21+
proposals accumulated across three runs.

| Act | Branches | Without a channel |
|---|---|---|
| frontmatter status edit | ARCHIVE, KEEP PENDING | **proceed** — reversible, and recorded in the note's own history |
| note creation | PROMOTE step 1 | **defer** — write to the pending artifact, do not create the note |
| file/section modification | IMPLEMENT step 1 | **defer** — write to the pending artifact, do not modify the file |
| methodology elevation | METHODOLOGY | **defer** — write to the pending artifact |

Deferring is not skipping: the item is persisted with its full disposition and reasoning, so
the approval invocation can execute it without re-deriving the triage.
```

- [ ] **Step 3: Add the deferral instruction to each side-effect branch**

To PROMOTE, IMPLEMENT and METHODOLOGY, prepend:

```markdown
**If no approval channel is available:** do not perform this act. Append the item to
`ops/rethink/pending.yaml` per Phase 1e and leave the source observation/tension at its
current status — a status that claims an act which did not happen is worse than a pending
one, because nothing downstream can tell the difference.
```

**Note on IMPLEMENT step 2.** Its "get confirmation if the change is non-trivial" is a second
blocking gate. Under this split it is unreachable without a channel, because IMPLEMENT itself
defers — so it needs no separate treatment. Leave its text unchanged and say so, rather than
appearing to have missed it.

- [ ] **Step 4: Verify `:704` survived and the gates pass**

```bash
/usr/bin/grep -c 'Auto-implement system changes — proposals require human approval, always' \
  skill-sources/rethink/SKILL.md      # must be 1
bash reference/test/fence-isolation.test.sh 2>&1 | /usr/bin/tail -5
bash reference/check-portability.sh; echo "portability rc=$?"
```

Expected: `1`, PASS, rc=0. **If `:704`'s count is 0, revert this task** — the split's entire justification is that `:704` continues to hold.

- [ ] **Step 5: Commit**

```bash
git add skill-sources/rethink/SKILL.md
git commit -m "fix: split rethink's triage gate by act, not by phase

Un-gating the triage PHASE would auto-implement: 1d's PROMOTE branch creates
knowledge-base notes and its IMPLEMENT branch modifies files, so a phase-level
split contradicts :704 while claiming to preserve it.

Split by act instead. Frontmatter status edits (ARCHIVE, KEEP PENDING) proceed
without a channel; note creation, file modification and methodology elevation
defer to ops/rethink/pending.yaml. IMPLEMENT step 2's own confirmation gate
becomes unreachable rather than needing separate handling, because IMPLEMENT
itself defers."
```

---

### Task 8: The pending artifact and its resume path

The proposal phase terminates in a durable artifact and exits 0. Approval is a separate invocation.

**Files:**
- Modify: `skill-sources/rethink/SKILL.md` (a new Phase 1e; the proposal gate at `:562`; the `:630` report format)

**Interfaces:**
- Consumes: `queue_yaml` from `ops/lib/queue-edit.sh` (v2), the `act:` vocabulary from Task 7.
- Produces: `ops/rethink/pending.yaml`, a bare YAML list whose items carry `id`, `act` (`promote`|`implement`|`methodology`|`proposal`), `status` (`awaiting_approval`|`approved`|`rejected`|`deferred`), `source`, `summary`, `detail`.

- [ ] **Step 1: Confirm the writer and its guard idiom**

```bash
/usr/bin/grep -n 'QUEUE_EDIT_VERSION=' reference/lib/queue-edit.sh          # expect 2
/usr/bin/sed -n '/^# queue_yaml FILE/,+6p' reference/lib/queue-edit.sh      # the signature
/usr/bin/grep -rn 'QUEUE_EDIT_VERSION' skill-sources/rethink/SKILL.md | /usr/bin/head -3
```

`queue_yaml` takes an arbitrary file argument, which is exactly why the destination has to be pinned here and not left to the implementer.

- [ ] **Step 2: Add Phase 1e**

```markdown
### 1e. Persist Deferred Acts and Proposals

Everything the run could not adjudicate lands here, in one file, with one vocabulary.

**File:** `ops/rethink/pending.yaml` — a bare YAML list. **Deliberately NOT the operational
queue**: proposals in the queue would enter the store `/next` drains, and while `/next`
filters `--where status=pending` and would probably skip them, "probably" is the defect. No
queue schema declares `awaiting_approval`, and a status no consumer declares is the
unfalsifiable state this skill legislates against elsewhere.

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

Write through `queue_yaml`, under the same version guard the queue fences use:

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
[ -f ops/rethink/pending.yaml ] || printf '[]\n' > ops/rethink/pending.yaml
# One queue_yaml call per item. A zero-match --where fails loud rather than
# silently writing nothing — the silence that left seven fences dead for a month.
```

**Then report and exit 0.** Do not wait. The run has produced something a later invocation
can act on, which is the point.

```
Pending acts and proposals: [count] written to ops/rethink/pending.yaml
Resume with: /rethink approve
```
```

- [ ] **Step 3: Apply the same treatment to the proposal gate at `:562`**

Replace the blocking `AskUserQuestion` + wait with: ask if a channel exists; otherwise write
each proposal as an `act: proposal` item and exit 0. **`:704` is unaffected** — a persisted
proposal is not an implemented one, and nothing in this task implements anything.

- [ ] **Step 4: Extend the `:630` report format**

Add one line, leaving the existing four counts untouched — they are the surface that made this
defect visible at all, and three log lines reading `0 approved` are why there is a fix:

```markdown
**Pending:** [count] awaiting approval in `ops/rethink/pending.yaml`
```

- [ ] **Step 5: Run the gates**

```bash
bash reference/test/fence-isolation.test.sh 2>&1 | /usr/bin/tail -8
bash reference/test/queue-edit.test.sh; echo "queue-edit rc=$?"
bash reference/check-portability.sh; echo "portability rc=$?"
bash reference/check-prose-paths.sh; echo "prose-paths rc=$?"
```

Expected: PASS, rc=0 for each, run unpiped. Read the fence gate's `skipped=` — the new fences must be RUN, not skipped.

- [ ] **Step 6: Commit**

```bash
git add skill-sources/rethink/SKILL.md
git commit -m "feat: rethink persists deferred acts and proposals, then exits 0

The proposal phase terminated in a question, so a run without an interactive
channel generated proposals and stalled — three logged runs at '0 approved', one
naming the cause outright. It now terminates in ops/rethink/pending.yaml and
exits 0, with approval as a separate invocation.

The store is pinned rather than left to the implementer: queue_yaml takes an
arbitrary file, and putting awaiting_approval items in the operational queue
would create a status no consumer declares in a file four skills act on.

Better even where the channel exists: it survives mid-run context exhaustion,
removes the behavioural difference between subagent and interactive execution,
and makes the batch-approval workflow the field already performs the supported
path rather than a workaround."
```

---

### Task 9: CI wiring and the mandatory numeral update

Adding a check has a documentation cost this repo enforces. `check-doc-claims.sh` reads the declared numerals in `CLAUDE.md` and fails when the tree and the document disagree.

**Files:**
- Modify: `.github/workflows/checks.yml`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: `reference/test/moc-sync.test.sh` from Tasks 1-4.
- Produces: nothing.

- [ ] **Step 1: Re-derive every affected numeral — do not increment**

```bash
ls reference/check-*.sh reference/test/*.test.sh reference/validate-kernel.sh | wc -l
/usr/bin/grep -c '^      - ' .github/workflows/checks.yml
bash reference/test/fence-isolation.test.sh 2>&1 | /usr/bin/grep -m1 -oE 'files=[0-9]+|fences=[0-9]+|run=[0-9]+|skipped=[0-9]+'
```

**Incrementing assumes you know the current value.** `CLAUDE.md` records four occasions where a prose count was stale in exactly that way, including one that went wrong inside the paragraph explaining the hazard.

- [ ] **Step 2: Add the two CI steps**

Two steps, matching the existing both-shells pattern:

```yaml
      - name: moc-sync (bash)
        run: bash reference/test/moc-sync.test.sh
      - name: moc-sync (zsh)
        run: zsh reference/test/moc-sync.test.sh
```

- [ ] **Step 3: Update `CLAUDE.md`**

Three edits, using the values from Step 1:

1. The check count in the Verification section — "seventeen executable checks" becomes eighteen, in the same word form the gate reads.
2. The CI-run count sentence — "Fifteen run in CI" becomes sixteen.
3. A new row in the gate table naming what only this suite can catch:

```markdown
| `moc-sync.test.sh` | the only gate that executes `reference/lib/moc-sync.sh` — a derivation whose failure mode is a *plausible* MOC: correct headings over silently missing notes. It pins that an off-map status is reported rather than omitted (16 live instances in the field vault today, which any single one of the three competing section maps would have dropped), that a note existing with unreadable frontmatter is reported rather than vanished, that a divergent summary survives byte-identical (~40 entries would otherwise be destroyed), and idempotence in BOTH senses — byte-identical consecutive runs, and identical output from reordered input, which a "preserve order and append" implementation passes the first of and fails the second |
```

**Leave the `main`-side numeral alone.** It cannot be green on both sides of the merge: pre-merge `main` genuinely carries the old count, so writing the new one reddens this branch. It takes the documented post-merge correction, and this step is where an executor otherwise chases an impossible green.

- [ ] **Step 4: Run the two gates that read those numerals, unpiped**

```bash
bash reference/check-doc-claims.sh;  echo "doc-claims rc=$?"    # ~100s
bash reference/check-prose-paths.sh; echo "prose-paths rc=$?"
```

Expected: rc=0 for both. A non-zero `check-doc-claims.sh` names the disagreeing claim — fix the document to match the tree, never the reverse.

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

Expected: every rc=0. Each gate runs **unpiped** so `$?` is the gate's own status. This takes several minutes; run it in the background rather than letting it hit a foreground timeout.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/checks.yml CLAUDE.md
git commit -m "ci: wire moc-sync.test.sh and update the declared numerals

Adding a check moves CLAUDE.md's declared check count and CI step count, and
check-doc-claims.sh fails when the tree and the document disagree. Both were
re-derived rather than incremented.

The main-side CI step numeral is deliberately NOT updated: no value is green on
both sides of a merge, and it takes the documented post-merge correction. That
numeral has been corrected three times for exactly this reason."
```

---

## Deferrals

- **Summary backfill for the ~40 divergent entries** — deferred, no tracked file yet. The rebuild preserves them and warns on every run, which means a permanent warning that will be tuned out. Two options, both out of scope here: backfill the descriptions, or adopt the `implemented via <implemented_in target>` convention 7 entries already use. Recorded in the spec's "What is NOT claimed".
- **Delivery to existing vaults** — deferred to divergence 16's own spec. This plan changes what a vault *receives*; two deliveries must land before an existing vault converges (template regeneration, and `ops/lib/moc-sync.sh` installation via `/upgrade` 5e). Recorded in the spec's Migration section, which names both.
- **`1d`'s pre-existing gate ambiguity** — not fixed here. PROMOTE and IMPLEMENT already execute system changes behind a *triage* approval rather than a *proposal* approval, so a user approving a triage table has approved file modifications presented as status dispositions. Task 7's split resolves it as a side effect; it is not targeted, and no separate task exists for it. Recorded in the spec under the corrected split.
- **G1, G4, G5** — out of scope by the spec's own "What is NOT claimed". G1 (the topic-map rule's two numbers and its non-existent config key) and G4 (`session-orient.sh`'s label overclaim) are recorded in `docs/field-intel-2026-08-17.md` §A. G5 (a gate for enums with no consumer inside `generators/`) belongs to `docs/superpowers/specs/archive/2026-08-04-ci-hardening-design.md` and **must be filed there as a numbered item** — an entry deferred without a home is divergence 10's failure mode.
- **The `main`-side CI step numeral** — deliberately left stale by Task 9 Step 3, because no value is green on both sides of a merge. Takes the documented post-merge correction; recorded in Task 9's commit message.

---

## Self-Review

**Spec coverage.** Every numbered decision maps to a task: D1/D2 → Tasks 2, 5; D3 → Tasks 1-4, 6; D4 → Task 3; D5 → Deferrals (delivery) and Task 5's guard (the fail-loud behaviour that makes D5's correction true); D6 → Task 7; D7 → Task 8; D8 → Task 8; D9 → Task 9; D10 → no task, correctly — it is a decision *not* to build a gate; D11 → Task 1; D12 → Tasks 2, 4. Rebuild-contract rules 1-6 → Tasks 2 (1, 6 membership), 3 (2, 3, 6 reporting), 4 (4, 5). Every Testing-table assertion appears as a concrete test in Tasks 1-4.

**Placeholder scan.** No "TBD", no "add error handling", no "similar to Task N". Every code step carries runnable code; every verification step carries its command and expected result. Two steps deliberately instruct *stopping* rather than acting (Task 5 Step 1, Task 7 Step 1) — both are anchor-staleness checks, where proceeding on a moved line number would edit the wrong text.

**Type consistency.** `moc_section_for` is rc 0/1/2 throughout. `moc_harvest_entries` emits `slug<TAB>summary` and is consumed as `-F'\t'` in Tasks 2-3. `rebuild_status_moc <moc-file> <notes-dir> <status:Section>...` has the same argument order in Tasks 4, 5 and the provenance comment. `MOC_SYNC_VERSION` floor is 1 in Task 5's guard and Task 6's `check_lib`, and Task 6 Step 3 asserts they agree. The `act:` vocabulary (`promote`|`implement`|`methodology`|`proposal`) is introduced in Task 7 and consumed unchanged in Task 8. `MOC_MAP_OBSERVATIONS`/`MOC_MAP_TENSIONS` are pinned by value in Task 1's test and used verbatim in Tasks 2-5.

One gap found and closed during review: Task 2's `moc_render` needed `frontmatter_field`, which Task 1's suite did not source. Task 2 Step 3 now adds the `FMLIB` sourcing to the test file explicitly rather than leaving an implementer to discover it from a runtime error.
