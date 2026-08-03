#!/bin/bash
# fence-isolation.test.sh — execute every ```bash fence in every SKILL.md as its
# OWN shell invocation, the way Claude actually runs them.
#
# WHY THIS EXISTS: Claude executes each fenced bash block in a SKILL.md as a
# separate Bash tool call. No variable and no sourced function crosses a fence
# boundary. A `$VAR` set in fence 1 expands to the EMPTY STRING in fence 2 —
# silently — and `$(( ))` folds empty to 0. So the failure renders as a
# plausible number at rc=0, never as an error. Four of the six blocking findings
# in the whole-branch review were exactly this, and no existing gate could see
# them: check-portability.sh matches text, link-extraction.test.sh exercises the
# library in isolation where it is correct, guard-failure.test.sh tests the
# guard. None of them executes a fence.
#
# Run under BOTH shells: `bash …test.sh` and `zsh …test.sh`.
#
# THE RUBRIC, which every assertion below serves: a failure must never render as
# a plausible number. An EMPTY vault is a legitimate success (rc 0, value 0); a
# NONEXISTENT vault must fail loudly.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
LINK_LIB_SRC="$ROOT/reference/lib/link-extraction.sh"

# Every spawned shell must be THIS harness's shell, not `sh`. On macOS `sh` is
# bash 3.2 regardless of what launched the harness, so an `sh` site silently
# runs the bash path even under `zsh …test.sh` — which defeats the promise made
# above. Two defects closed on this branch were bash/zsh forks.
if [ -n "${ZSH_VERSION:-}" ]; then SELF=zsh; else SELF=bash; fi

# WHY THE WORK DIRECTORY IS A FIXED, DIGIT-FREE PATH AND NOT `mktemp -d`:
# assertion N asks whether a fence emitted DIGITS on stdout. An mktemp path
# contains digits (`/var/folders/f2/9vss9brn…`), so any fence echoing a filename
# under that root trips the digit test and reports a defect against correct
# code. This was measured as a near-miss false Critical before the path was
# pinned. The shell name keeps the two CI jobs from colliding.
WORK="/tmp/fence-isolation-gate-$SELF"
rm -rf "$WORK"
# Says WHY it died. An `|| exit 1` here exits 1 with an empty stdout and a
# silent stderr — the exact shape this gate exists to eliminate, and it cost a
# debugging cycle during development when a leftover process made the mkdir
# fail and the gate reported nothing at all.
mkdir -p "$WORK/fences" "$WORK/out" || {
  printf 'harness: cannot create work directory %s — cannot conclude anything\n' "$WORK" >&2
  exit 1
}
# FENCE_GATE_KEEP=1 preserves the extracted fences, the generated scripts and
# every captured stdout/stderr. Diagnosing a failure means reading the exact
# script that ran, and a gate whose evidence self-destructs invites guessing.
[ -n "${FENCE_GATE_KEEP:-}" ] || trap 'rm -rf "$WORK"' EXIT INT TERM

fences=0; run=0; skipped=0
h_fail=0; n_fail=0; setu_fail=0; known=0; stale=0
SKIP_LOG="$WORK/skips.txt"; : > "$SKIP_LOG"
FAIL_LOG="$WORK/fails.txt"; : > "$FAIL_LOG"
SETU_LOG="$WORK/setu.txt"; : > "$SETU_LOG"
KNOWN_LOG="$WORK/known.txt"; : > "$KNOWN_LOG"
HIT_LOG="$WORK/hits.txt";    : > "$HIT_LOG"
SEEN_LABELS="$WORK/labels.txt"; : > "$SEEN_LABELS"

# --- fences this gate does not execute --------------------------------------
# Enumerated, one line per site, in the same shape as the two file-level
# exemptions in check-portability.sh. An enumerated list is greppable and its
# entries can be argued with; a pattern loose enough to catch this case would
# also catch working code.
#
# Format: <label>~<reason>
ILLUSTRATIVE='skills/reseed f03~single git mv over literal placeholder operands (old-folder/, new-folder/) under prose that reads "If folder names change"
skill-sources/tasks f03~an if whose entire body is comments describing the steps; bash -n rejects the empty then-branch and zsh accepts it, so listing it keeps the two shells reporting the same counts'

# --- known-open defects this gate FOUND and does not yet block on -----------
# Every line below is a real defect, found by this gate on the tree it landed
# against, in a skill the hardening branch never touched. They are listed rather
# than fixed because fixing them is a separate change with its own review: the
# `seed` sites read `$FILE`, which is the argument the skill is invoked with, so
# the repair is a design decision (re-derive per fence? read `$ARGUMENTS`?) and
# not the stanza copy that closed the `graph` sites.
#
# THE LIST IS CHECKED IN BOTH DIRECTIONS. A listed site that fails is reported
# as KNOWN and does not block. A listed site that PASSES fails the gate, and so
# does a listed site that no longer exists — otherwise the list rots into a
# permanent silence, which is the defect class this whole gate is about.
#
# A reason beginning `ZSH ONLY:` or `BASH ONLY:` marks a site that fails in one
# shell and not the other — a real defect class here, and one the staleness
# check must know about or it would report the entry as rotten in the shell
# where the fence legitimately passes.
#
# Format: <label>~<assertion letter>~<reason>
KNOWN_OPEN='skill-sources/seed f01~H~ZSH ONLY: ops/queue*.yaml matches nothing in a vault whose queue lives at ops/queue/queue.yaml, and zsh aborts the command on a non-matching glob where bash passes the pattern through
skills/health f08~H~ZSH ONLY: self/memory/*.md matches nothing in a vault with no memory notes, same non-matching-glob fork as seed f01'

table_reason() {                    # table_reason <table> <label> [letter]
  printf '%s\n' "$1" | while IFS='~' read -r l a r; do
    if [ -z "${3:-}" ]; then
      [ "$l" = "$2" ] && printf '%s' "$a"
    else
      [ "$l" = "$2" ] && [ "$a" = "$3" ] && printf '%s' "$r"
    fi
  done
}

# --- fixture ----------------------------------------------------------------
# Filenames are digit-free for the same reason the work path is. Content dates
# carry digits, but content only reaches stdout from the healthy fixture, where
# the digit test is not applied.
#
# `mode` is `full` or `hollow`. hollow is the healthy vault MINUS the notes and
# inbox directories — NOT an empty directory. A fence must still get past
# sourcing the link library and reach the notes-dir logic, or assertion N would
# pass vacuously on a fence that never touched the notes directory at all.
build_fixture() {
  v="$1"; mode="$2"
  rm -rf "$v"
  mkdir -p "$v/ops/lib" "$v/ops/queue" "$v/ops/observations" "$v/ops/tensions" \
           "$v/ops/methodology" "$v/ops/sessions" "$v/self" "$v/self/memory" \
           "$v/.claude/skills/stats" || return 1
  : > "$v/.arscontexta"
  cp "$LINK_LIB_SRC" "$v/ops/lib/link-extraction.sh" || {
    printf 'harness: cannot copy %s into the fixture\n' "$LINK_LIB_SRC" >&2
    return 1
  }

  printf 'description: an observation\nstatus: pending\ntitle: an observation\n' > "$v/ops/observations/obs-one.md"
  printf 'status: open\ntitle: a tension\n'              > "$v/ops/tensions/tension-one.md"
  printf 'description: a learned rule\ntitle: a learned rule\n' > "$v/ops/methodology/method-one.md"
  printf 'title: a session\n'                            > "$v/ops/sessions/session-one.md"
  printf -- '- id: one\n  status: pending\n- id: two\n  status: done\n' > "$v/ops/queue/queue.yaml"
  printf 'title: identity\n'                             > "$v/self/identity.md"
  printf 'vocabulary:\n  notes: notes\n'                 > "$v/ops/derivation-manifest.md"
  printf 'derivation record\n'                           > "$v/ops/derivation.md"
  printf 'processing_depth: standard\n'                  > "$v/ops/config.yaml"
  printf 'name: stats\n'                                 > "$v/.claude/skills/stats/SKILL.md"
  # Several fences reach for the JSON queue directly (`jq … ops/queue/queue.json`)
  # rather than through the YAML-or-JSON branch, so both forms must exist or the
  # fence fails on fixture shape rather than on anything it is being judged for.
  printf '{"tasks":[{"id":"one","status":"pending"},{"id":"two","status":"done"}]}\n' > "$v/ops/queue/queue.json"
  # The lock directory is created here because skill-sources/reflect and
  # skill-sources/reweave once spun on an unbounded `while ! mkdir "$LOCKDIR"`
  # and the PARENT of that lock was created by nothing in this repository — see
  # the report's live findings. Both fences now bound the wait at 60s and create
  # the parent themselves, so this no longer prevents a hang; it is kept because
  # a fixture that omits it would exercise the parent-creation branch on every
  # run rather than the acquisition path the fences are actually judged on.
  # KNOWN BLIND SPOT, unchanged: with the directory present the fixture is
  # kinder than a real generated vault.
  mkdir -p "$v/ops/queue/.locks" || return 1
  # `git init` because a fence in skills/reseed calls `git`, which exits 128
  # outside a work tree. Quiet, and with a local identity so a machine without
  # a global git config behaves the same as one with it.
  ( cd "$v" && git init -q . && git config user.email gate@example.invalid \
      && git config user.name gate ) >/dev/null 2>&1 || return 1

  [ "$mode" = hollow ] && return 0

  mkdir -p "$v/notes/sub" "$v/inbox" || return 1
  TODAY=$(date +%Y-%m-%d)
  # alpha is the note the substituted metavariables point at, so the greps that
  # look for it actually match. beta and gamma link to it; delta-moc is a MOC.
  printf -- '---\ntype: note\ntitle: alpha\ndescription: first note\ncreated: %s\ntopics:\n  - "[[delta-moc]]"\n---\nBody of alpha.\n' "$TODAY" > "$v/notes/alpha.md"
  printf -- '---\ntype: note\ntitle: beta\ndescription: second note\ncreated: %s\ntopics:\n  - "[[delta-moc]]"\n---\nLinks to [[alpha]] and [[gamma]].\n' "$TODAY" > "$v/notes/beta.md"
  printf -- '---\ntype: note\ntitle: gamma\ndescription: third note\ncreated: %s\ntopics:\n  - "[[delta-moc]]"\n---\nLinks to [[alpha]].\n' "$TODAY" > "$v/notes/gamma.md"
  printf -- '---\ntype: moc\ntitle: delta-moc\ndescription: the map\ncreated: %s\ntopics:\n  - "[[delta-moc]]"\n---\nCovers [[alpha]], [[beta]], [[gamma]].\n' "$TODAY" > "$v/notes/delta-moc.md"
  printf -- '---\ntype: note\ntitle: nested\ndescription: nested note\ncreated: %s\ntopics:\n  - "[[delta-moc]]"\n---\nLinks to [[alpha]].\n' "$TODAY" > "$v/notes/sub/nested.md"
  printf -- '---\ntitle: raw capture\n---\nUnprocessed material.\n' > "$v/inbox/raw-capture.md"
  return 0
}

VAULT_FULL="$WORK/vault-full"
VAULT_HOLLOW="$WORK/vault-hollow"
build_fixture "$VAULT_HOLLOW" hollow || { echo "harness: cannot build hollow fixture" >&2; exit 1; }

# --- preconditions ----------------------------------------------------------
# Asserted, not assumed. A missing tool makes a fence exit 127, which this gate
# would otherwise report as a defect in the fence — a false Critical, and the
# reader has no way to tell it from a real one. Note that jq, bc and git are
# used by fences but are NOT in the README prerequisite table; that gap is a
# finding in its own right, recorded in the report.
missing=""
for t in rg awk jq bc git sed; do
  command -v "$t" >/dev/null 2>&1 || missing="$missing $t"
done
if [ -n "$missing" ]; then
  printf 'harness: required tool(s) missing:%s — cannot conclude anything\n' "$missing" >&2
  exit 1
fi

# `qmd` is the one dependency the README marks OPTIONAL, and the fences that
# call it must survive its absence. Stubbing it keeps the gate measuring fence
# isolation instead of measuring whether this particular machine happens to have
# a qmd index: unstubbed, the same fence exits 1 here ("Collection not found")
# and 127 on the CI image, so the gate's verdict would depend on the host.
# KNOWN BLIND SPOT: a fence that mishandles a real qmd failure passes here.
mkdir -p "$WORK/bin"
printf '#!/bin/sh\nexit 0\n' > "$WORK/bin/qmd"
chmod +x "$WORK/bin/qmd"
PATH="$WORK/bin:$PATH"
export PATH

# --- placeholder map --------------------------------------------------------
# Discovered by SCAN, never by a hardcoded list of sites: a placeholder left
# unsubstituted produces a failure that looks exactly like the defect this gate
# hunts, so an unmapped token is a HARNESS error, not a fence result.
#
# `{vocabulary.X}` falls back to X, which is right for every vocabulary term the
# generator emits. Author metavariables (`{field}`, `{target}`, …) get concrete
# fixture-valid values so the fence RUNS. They are deliberately NOT a skip rule:
# `{field}` is an author metavariable but `$NOTES_DIR` in the same fence is a
# cross-fence read, and a rule keyed on "has an unresolved placeholder" cannot
# tell them apart — it would silently drop live defects, which is this gate's
# own failure mode.
map_value() {
  case "$1" in
    '{vocabulary.notes}')            printf 'notes' ;;
    '{vocabulary.inbox}')            printf 'inbox' ;;
    '{vocabulary.notes_collection}') printf 'notes' ;;
    '{vocabulary.topic_map}')        printf 'moc' ;;
    '{vocabulary.topic_maps}')       printf 'mocs' ;;
    '{vocabulary.topic_map_plural}') printf 'mocs' ;;
    '{vocabulary.note_plural}')      printf 'notes' ;;
    '{field}')                       printf 'type' ;;
    '{value}')                       printf 'note' ;;
    '{target}')                      printf 'alpha' ;;
    '{condition_key}')               printf 'orphans' ;;
    '{description}')                 printf 'a sample description' ;;
    '{priority}')                    printf 'high' ;;
    '{SOURCE_NAME}')                 printf 'sample-source' ;;
    '{SOURCE_BASENAME}')             printf 'sample-source' ;;
    '{SKILL_NAME}')                  printf 'stats' ;;
    '{skill-name}')                  printf 'stats' ;;
    # `{DOMAIN:notes}` is a second, older templating spelling that survives in
    # skill-sources/seed. The identifier after the colon is already the folder
    # name, so it resolves the same way `{vocabulary.X}` does.
    '{DOMAIN:'*)                     printf '%s' "$(printf '%s' "$1" | sed 's/^{DOMAIN://; s/}$//')" ;;
    '{DATE}')                        printf '%s' "$(date +%Y-%m-%d)" ;;
    '{RATIO}')                       printf '0.5' ;;
    '{vocabulary.'*)                 printf '%s' "$(printf '%s' "$1" | sed 's/^{vocabulary\.//; s/}$//')" ;;
    *)                               return 1 ;;
  esac
  return 0
}

# --- extract every fence ----------------------------------------------------
# An optional argument scopes the run to ONE SKILL.md, which turns a five-minute
# sweep into a twenty-second one. That is what makes the non-vacuity proofs in
# the plan practical: each mutation is checked against the file it was planted
# in, under both shells, instead of against the whole scan set.
TARGET="${1:-}"
if [ -n "$TARGET" ]; then
  [ -f "$ROOT/$TARGET" ] || { printf 'harness: no such file: %s\n' "$TARGET" >&2; exit 1; }
  FILES="$TARGET"
else
  # reference/skill-authoring.md is scanned too: its ```bash examples are what an
  # author copies, so an example that cannot pass H/N/U/S is a defect being taught.
  # Counter-examples in that document live in ```text and are invisible here, which
  # is the only reason it can show a wrong pattern at all.
  FILES=$(cd "$ROOT" && { find skill-sources skills -name SKILL.md
                          find reference -name skill-authoring.md; } | sort)
fi
printf '%s\n' "$FILES" | while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  slug=$(printf '%s' "$rel" | sed 's|/SKILL\.md$||; s|/|--|g')
  awk -v dir="$WORK/fences" -v slug="$slug" '
    FNR==1 { n=0; inf=0 }
    /^```bash[[:space:]]*$/ && !inf { inf=1; n++; f=sprintf("%s/%s__f%02d.raw", dir, slug, n); printf "" > f; next }
    /^```[[:space:]]*$/ && inf { inf=0; close(f); next }
    inf { print $0 >> f }
  ' "$ROOT/$rel"
done

FENCE_FILES=$(find "$WORK/fences" -name '*.raw' | sort)
[ -n "$FENCE_FILES" ] || { echo "harness: extracted no fences — cannot conclude anything" >&2; exit 1; }

# --- discover placeholders and fail loudly on an unmapped one ---------------
# The $-preceding test keeps `${VAR}` out of the token set; only a bare `{tok}`
# is a template placeholder.
TOKENS=$(awk '{
  line=$0
  while (match(line, /\{[A-Za-z_][A-Za-z_.:-]*\}/)) {
    pre = (RSTART > 1) ? substr(line, RSTART-1, 1) : ""
    if (pre != "$") print substr(line, RSTART, RLENGTH)
    line = substr(line, RSTART+RLENGTH)
  }
}' $(printf '%s\n' "$FENCE_FILES" | tr '\n' ' ') | sort -u)

MAPFILE="$WORK/map.txt"; : > "$MAPFILE"
unmapped=""
printf '%s\n' "$TOKENS" | while IFS= read -r tok; do
  [ -n "$tok" ] || continue
  if val=$(map_value "$tok"); then
    printf '%s\t%s\n' "$tok" "$val" >> "$MAPFILE"
  else
    printf '%s\n' "$tok" >> "$WORK/unmapped.txt"
  fi
done
if [ -s "$WORK/unmapped.txt" ] 2>/dev/null; then
  echo "harness: unmapped placeholder(s) — add a value to map_value(), do NOT skip the fence:" >&2
  sed 's/^/  /' "$WORK/unmapped.txt" >&2
  exit 1
fi
unset unmapped

# --- run one fence under one condition --------------------------------------
# The status is captured from a DIRECT invocation, never from a pipeline: a
# pipeline yields its LAST stage's status, and that mechanism alone produced six
# defects on this branch. PIPESTATUS is bash-only and reads empty under zsh, so
# it is not the fix either.
#
# stdin is /dev/null so a fence containing a bare `read` cannot hang the gate.
#
# WHY THERE IS A TIMEOUT AT ALL, AND WHY IT IS NOT `timeout(1)`:
# skill-sources/reflect fence 2 used to spin on `while ! mkdir "$LOCKDIR"; do
# sleep 2; done`, which never terminated when the lock's PARENT directory was
# absent. Measured: the first run of this harness hung there indefinitely. That
# specific spin is now bounded at 60s, so the timeout below is no longer aimed
# at a known hang — it is the general guard that keeps ANY future one
# reportable, which is why it stays. A gate whose
# own failure mode is "hang until the CI job is killed at six hours" is the
# loudest possible instance of the silence this branch exists to remove, so a
# stuck fence must come back as a reportable status instead. `timeout(1)` is GNU
# coreutils — present on the CI image, absent from a stock macOS — so the wait
# is built from a status sentinel and a polled deadline instead.
FENCE_TIMEOUT=20                    # seconds; the fixture is tiny
RCF="$WORK/fence.rc"
PIDF="$WORK/fence.pid"
run_fence() {                       # run_fence <script> <vault> <outfile>
  rm -f "$RCF" "$PIDF"
  ( cd "$2" || exit 125
    # ARGUMENTS is the invocation argument a user-invocable skill is called with.
    # The fixture models a healthy VAULT; without this it did not model a healthy
    # INVOCATION, so every fence that establishes its target from $ARGUMENTS (see
    # skill-sources/seed) failed assertion H for the one reason H cannot forgive —
    # exiting non-zero with a message on stderr — while being entirely correct.
    # Pointed at a file that really exists in the full fixture, and whose path
    # contains the inbox name, so seed's archive-and-move branch is exercised
    # rather than skipped. The empty-$ARGUMENTS path is deliberately NOT tested
    # here; it is verified directly (see the plan's Task 3 notes).
    CLAUDE_PROJECT_DIR="$2" ARGUMENTS="inbox/raw-capture.md" \
      "$SELF" "$1" > "$3" 2> "$3.err" < /dev/null &
    ip=$!; printf '%s\n' "$ip" > "$PIDF"; wait "$ip"; printf '%s\n' "$?" > "$RCF" ) &
  outer=$!
  ticks=0
  while [ ! -f "$RCF" ]; do
    if [ "$ticks" -ge $((FENCE_TIMEOUT * 10)) ]; then
      [ -f "$PIDF" ] && kill -9 "$(cat "$PIDF")" 2>/dev/null
      kill -9 "$outer" 2>/dev/null
      wait "$outer" 2>/dev/null
      return 124
    fi
    sleep 0.1
    ticks=$((ticks+1))
  done
  wait "$outer" 2>/dev/null
  rc=$(cat "$RCF")
  return "${rc:-125}"
}

has_digit() {                       # has_digit <file>
  case "$(cat "$1")" in *[0-9]*) return 0 ;; *) return 1 ;; esac
}

# Digits from the TRAILER only — the variables the fence computed — as opposed
# to digits anywhere on stdout. The distinction is load-bearing and was measured:
# skill-sources/reflect fence 4 is `grep -c … a-moc.md`, which prints `0` and
# exits 1 when the file holds no matching lines. That 0 is the correct answer,
# not a number the fence could not compute, so judging raw stdout reports a
# defect against working code. A number the fence assigned to a variable and
# then failed on is a different thing, and that is what this reads.
trailer_digit() {                   # trailer_digit <file>
  case "$(sed -n '/^___FENCE_TRAILER___$/,$p' "$1")" in *[0-9]*) return 0 ;; *) return 1 ;; esac
}

# THE SCOPE PREFIX IS HONOURED IN BOTH DIRECTIONS, OR THE TWO DISAGREE.
# `ZSH ONLY:` / `BASH ONLY:` marks an entry that applies in one shell only. The
# staleness check already honoured it — a fence that legitimately passes in the
# other shell is not a rotten line. Absorption did NOT, so a `ZSH ONLY:` entry
# silently swallowed a *bash* failure on the same fence. Measured, not argued: a
# fabricated `.probe-skill f01~H~ZSH ONLY:` entry absorbed a fence that exited 1
# writing to stderr, under bash, and the gate printed PASS. One predicate, two
# call sites, agreeing by construction rather than by review — re-deriving the
# condition at the second site is how the two came apart in the first place.
in_scope() { # in_scope <reason> — does this entry apply in the shell we are in?
  case "$1" in
    'ZSH ONLY:'*)  [ "$SELF" = zsh ] ;;
    'BASH ONLY:'*) [ "$SELF" = bash ] ;;
    *) return 0 ;;
  esac
}

# judge <letter> <label> <message> [detail-file]
# Routes one failing assertion to either the KNOWN list or the blocking list.
# Returns 0 when the site is a listed known-open defect, 1 when it blocks.
judge() {
  reason=$(table_reason "$KNOWN_OPEN" "$2" "$1")
  if [ -n "$reason" ] && in_scope "$reason"; then
    known=$((known+1))
    printf '%s~%s\n' "$2" "$1" >> "$HIT_LOG"
    printf '  %s %s — %s\n' "$1" "$2" "$reason" >> "$KNOWN_LOG"
    # THE MEASURED FAILURE, NOT ONLY THE STATED REASON. Absorption still keys on
    # (label, letter) within a shell, so a listed fence that starts failing for a
    # DIFFERENT reason in its own shell is still absorbed. Printing what actually
    # happened beside what the entry claims makes that visible instead of silent:
    # the two lines disagreeing is the signal. Keying absorption on the message
    # itself was considered and rejected — it would couple every entry to this
    # gate's wording, so rewording a message would turn all entries stale, which
    # is a new trap inside the mechanism built to drain them.
    printf '    measured: %s\n' "$3" >> "$KNOWN_LOG"
    return 0
  fi
  printf '%s %s — %s\n' "$1" "$2" "$3" >> "$FAIL_LOG"
  if [ -n "${4:-}" ] && [ -s "$4" ]; then sed 's/^/      /' "$4" | head -3 >> "$FAIL_LOG"; fi
  return 1
}

echo "=== Fence isolation gate ($SELF) ==="

printf '%s\n' "$FENCE_FILES" | while IFS= read -r raw; do
  [ -n "$raw" ] || continue
  printf '%s\n' "$raw" >> "$WORK/seen.txt"
done
fences=$(wc -l < "$WORK/seen.txt" | tr -d ' ')

for raw in $(printf '%s\n' "$FENCE_FILES"); do
  base=$(basename "$raw" .raw)
  label=$(printf '%s' "$base" | sed 's|--|/|g; s|__f| f|')

  # substitution — same $-preceding test as discovery, so `${VAR}` is untouched
  body="$WORK/fences/$base.body"
  awk -v mapfile="$MAPFILE" '
    BEGIN { while ((getline ln < mapfile) > 0) { i=index(ln,"\t"); m[substr(ln,1,i-1)]=substr(ln,i+1) } }
    {
      out=""; line=$0
      while (match(line, /\{[A-Za-z_][A-Za-z_.:-]*\}/)) {
        pre = (RSTART > 1) ? substr(line, RSTART-1, 1) : ""
        tok = substr(line, RSTART, RLENGTH)
        out = out substr(line, 1, RSTART-1)
        out = out ((pre != "$" && tok in m) ? m[tok] : tok)
        line = substr(line, RSTART+RLENGTH)
      }
      print out line
    }' "$raw" > "$body"
  # Bracket-form author metavariables. Enumerated rather than pattern-matched:
  # a pattern loose enough to catch `[moc-name]` also catches a shell character
  # class, and rewriting one of those would corrupt working code. Only the forms
  # that sit in a FILE PATH are listed — those are the ones that make a fence
  # fail on a name that was never meant to be literal. `[[note]]`-style wiki
  # links and YAML list values are deliberately left alone.
  sed -e 's/\[note name\]/alpha/g' -e 's/\[moc-name\]/delta-moc/g' \
      -e 's/\[basename\]/alpha/g'  -e 's/\[domain-folder\]/notes/g' \
      -e 's/\[domain-inbox\]/inbox/g' "$body" > "$body.subst" && mv "$body.subst" "$body"

  # SKIP RULE — the only one. A fence with no command line has nothing to
  # execute, so running it proves nothing. Stated so a reader can check it, and
  # PRINTED below: a silently skipped fence is the exact defect class this gate
  # exists to catch. A fence is NEVER skipped for failing.
  # SKIP RULES — there are exactly two, both stated so a reader can check them,
  # both PRINTED below, and neither of them is "it failed". A silently skipped
  # fence is the same defect class this gate exists to catch.
  #   1. no command line: nothing to execute, so running it proves nothing.
  #   2. not a syntactically complete program: the fence is a FRAGMENT (it opens
  #      mid-construct, e.g. begins after an `if`). The shell rejects it before
  #      running a single command, so it can carry no cross-fence read to find.
  #      Checked with the runner's OWN shell, so a fence valid under one shell
  #      and not the other is skipped only where it truly cannot parse.
  #   3. listed in the ILLUSTRATIVE table above, by exact label, with a reason.
  printf '%s\n' "$label" >> "$SEEN_LABELS"
  ill=$(table_reason "$ILLUSTRATIVE" "$label")
  if [ -n "$ill" ]; then
    skipped=$((skipped+1))
    printf '  %s — %s\n' "$label" "$ill" >> "$SKIP_LOG"
    continue
  fi
  cmdlines=$(sed 's/^[[:space:]]*//' "$body" | /usr/bin/grep -c -v -e '^#' -e '^$')
  if [ "${cmdlines:-0}" -eq 0 ]; then
    skipped=$((skipped+1))
    printf '  %s — no command lines (comments and blanks only)\n' "$label" >> "$SKIP_LOG"
    continue
  fi
  if ! "$SELF" -n "$body" 2>/dev/null; then
    skipped=$((skipped+1))
    printf '  %s — not a complete program (%s -n rejects it; fenced fragment)\n' "$label" "$SELF" >> "$SKIP_LOG"
    continue
  fi
  run=$((run+1))

  # TRAILER — why stdout is not the fence's raw stdout.
  # The fences that produced the historical plausible-number defects ASSIGN
  # (LINK_COUNT=, NOTE_COUNT=, TOTAL_CONTENT=) and print nothing; errors go to
  # stderr. A digit test over raw stdout would therefore be vacuous on exactly
  # the fences it exists to judge. The trailer dumps every variable the fence
  # assigns, so a computed-from-nothing 0 becomes visible.
  # `${NAME-}` (not `$NAME`) so the dump itself cannot abort under `set -u`.
  # The fence's OWN status is captured before the trailer and re-raised after
  # it, so printf cannot mask a non-zero exit. A fence that exits early never
  # reaches the trailer — no digits, which is the correct reading.
  vars=$(/usr/bin/grep -o -E '^[[:space:]]*[A-Za-z_][A-Za-z_0-9]*=' "$body" \
         | tr -d ' \t=' | sort -u)
  script="$WORK/fences/$base.sh"
  { cat "$body"
    echo '__FENCE_RC=$?'
    echo 'printf "%s\n" "___FENCE_TRAILER___"'
    printf '%s\n' "$vars" | while IFS= read -r v; do
      [ -n "$v" ] && printf 'printf "%%s\\n" "${%s-}"\n' "$v"
    done
    echo 'exit $__FENCE_RC'
  } > "$script"

  setu="$WORK/fences/$base.setu.sh"
  { echo 'set -u'; cat "$script"; } > "$setu"

  # --- assertion H: healthy fixture ------------------------------------------
  # FAIL when the fence exits non-zero AND it timed out, wrote to stderr, or
  # carried a computed number out with it. This catches the LOUD half of the
  # defect class: a guard firing on an empty `$NOTES_DIR`, a 127 from a function
  # that was never sourced, a syntax error.
  #
  # WHY NOT SIMPLY "rc must be 0" — MEASURED, not assumed. Five fences in
  # skills/health are boundary-violation DETECTORS whose last command is an `rg`
  # that must find nothing in a healthy vault. rc 1 with a silent stderr is the
  # universal "search found no match" signature, and a fixture rigged to make
  # those match would no longer be a healthy vault.
  #
  # KNOWN BLIND SPOT, and the reason assertion U exists: a fence ending in
  # `… 2>/dev/null` has hidden its own stderr, so its rc 1 is indistinguishable
  # here from a clean no-match. skill-sources/graph fences 4 and 5 are exactly
  # that shape and H cannot see them. U can.
  build_fixture "$VAULT_FULL" full || { echo "harness: fixture build failed" >&2; exit 1; }
  run_fence "$script" "$VAULT_FULL" "$WORK/out/$base.full"
  rc_full=$?
  if [ "$rc_full" -ne 0 ]; then
    why=""
    # A timed-out fence is ALWAYS a failure. It exits with a silent stderr and
    # no output, which is precisely the shape the clause below forgives, so it
    # must be named first or a hang would read as a clean no-match.
    [ "$rc_full" -eq 124 ] && why="timed out after ${FENCE_TIMEOUT}s"
    [ -s "$WORK/out/$base.full.err" ] && why="${why:+$why and }wrote to stderr"
    if trailer_digit "$WORK/out/$base.full"; then
      why="${why:+$why and }reported a computed number"
    fi
    if [ -n "$why" ]; then
      judge H "$label" "exited $rc_full on a healthy fixture and $why" \
        "$WORK/out/$base.full.err" || h_fail=$((h_fail+1))
    fi
  fi

  # --- assertion N: missing notes directory, must not be a plausible number --
  # Scoped by a checkable predicate: applied only to fences that reference the
  # notes directory BEFORE substitution. Fences that never touch it (the system
  # metrics fence counts ops/ and self/) correctly fall outside.
  if /usr/bin/grep -q -e 'NOTES_DIR' -e '{vocabulary.notes}' "$raw"; then
    run_fence "$script" "$VAULT_HOLLOW" "$WORK/out/$base.hollow"
    rc_hollow=$?
    if [ "$rc_hollow" -eq 0 ] && has_digit "$WORK/out/$base.hollow"; then
      judge N "$label" "exited 0 AND emitted digits with no notes directory" \
        "$WORK/out/$base.hollow" || n_fail=$((n_fail+1))
    fi
  fi

  # --- assertion U: no fence may read a variable it did not define ----------
  # THE precise detector for this gate's defect class, and the reason assertion
  # H alone is not enough. Measured: skill-sources/graph fences 4 and 5 read
  # `$NOTES_DIR` from a fence three sections earlier, and both end in
  # `… 2>/dev/null`, so H sees rc 1 with a silent stderr — indistinguishable
  # from a search that found nothing. Under `set -u` the shell itself reports
  # the unbound name, and it does so BEFORE the command's own redirection
  # applies. Verified in both shells:
  #   bash -c 'set -u; find "$U" -type f 2>/dev/null'  → `U: unbound variable`
  #   zsh  -c 'set -u; find "$U" -type f 2>/dev/null'  → `U: parameter not set`
  #
  # The assertion keys on that MESSAGE, not on the exit status. A bare non-zero
  # status under `set -u` conflates two different things: five detector fences
  # in skills/health exit 1 because their `rg` found nothing, with or without
  # `set -u`, and counting those would have made this look like a
  # false-positive generator (16 of 72) when the real signal is far narrower.
  build_fixture "$VAULT_FULL" full || { echo "harness: fixture build failed" >&2; exit 1; }
  run_fence "$setu" "$VAULT_FULL" "$WORK/out/$base.setu"
  rc_setu=$?
  [ "$rc_setu" -ne 0 ] && printf '  %s — rc %s\n' "$label" "$rc_setu" >> "$SETU_LOG"
  if /usr/bin/grep -q -e 'unbound variable' -e 'parameter not set' "$WORK/out/$base.setu.err" 2>/dev/null; then
    uv=$(/usr/bin/grep -o -E '[A-Za-z_][A-Za-z_0-9]*: (unbound variable|parameter not set)' \
           "$WORK/out/$base.setu.err" | sed 's/:.*//' | sort -u | tr '\n' ' ')
    judge U "$label" "reads ${uv}— defined in no fence of this file" \
      "" || setu_fail=$((setu_fail+1))
  fi
done

# --- the allowlist is checked in BOTH directions ----------------------------
# A listed site that no longer fails, or no longer exists, is a stale entry, and
# a stale entry is a permanent silence — the same failure mode this gate exists
# to remove. So it blocks, with the fix spelled out.
# Only on a full sweep: under a scoped run every label from the other 25 files is
# legitimately absent, and reporting those as stale would bury the real ones.
[ -n "$TARGET" ] && KNOWN_OPEN="" && ILLUSTRATIVE=""
printf '%s\n%s\n' "$KNOWN_OPEN" "$ILLUSTRATIVE" | while IFS='~' read -r l a r; do
  [ -n "$l" ] || continue
  if ! /usr/bin/grep -qxF "$l" "$SEEN_LABELS"; then
    printf 'STALE %s — listed in a table but no such fence exists; delete the line\n' "$l" >> "$WORK/stale.txt"
    continue
  fi
  in_scope "$r" || continue
  case "$a" in
    U|N|H)
      /usr/bin/grep -qxF "$l~$a" "$HIT_LOG" || \
        printf 'STALE %s %s — listed as known-open but it PASSES now; delete the line\n' "$a" "$l" >> "$WORK/stale.txt" ;;
  esac
done
[ -f "$WORK/stale.txt" ] && stale=$(/usr/bin/grep -c . "$WORK/stale.txt")

printf 'files=%s fences=%s run=%s skipped=%s known-open=%s\n' \
  "$(printf '%s\n' "$FILES" | /usr/bin/grep -c .)" "$fences" "$run" "$skipped" "$known"

echo
echo "SKIPPED (rules: no command line; not a complete program; listed illustrative):"
if [ -s "$SKIP_LOG" ]; then cat "$SKIP_LOG"; else echo "  (none)"; fi

echo
echo "KNOWN-OPEN (real defects this gate found; listed, not blocking — see the table in this file):"
if [ -s "$KNOWN_LOG" ]; then cat "$KNOWN_LOG"; else echo "  (none)"; fi

echo
printf 'diagnostic — fences exiting non-zero under set -u for ANY reason: %s of %s\n' \
  "$(/usr/bin/grep -c . "$SETU_LOG" 2>/dev/null || echo 0)" "$run"
echo "  (most are detector fences whose rg legitimately finds nothing; assertion U"
echo "   keys on the unbound-variable MESSAGE instead, not on this status)"

echo
printf 'H (healthy: no failure with stderr/digits): %s failing\n' "$h_fail"
printf 'N (no notes dir: never rc 0 with digits):   %s failing\n' "$n_fail"
printf 'U (set -u: no read of an undefined var):    %s failing\n' "$setu_fail"
printf 'S (no stale entry in either table):        %s failing\n' "$stale"
if [ -s "$FAIL_LOG" ]; then echo; echo "FAILURES:"; cat "$FAIL_LOG"; fi
if [ -s "$WORK/stale.txt" ]; then echo; echo "STALE TABLE ENTRIES:"; cat "$WORK/stale.txt"; fi

echo
if [ "$h_fail" -eq 0 ] && [ "$n_fail" -eq 0 ] && [ "$setu_fail" -eq 0 ] && [ "$stale" -eq 0 ]; then
  echo "FENCE ISOLATION: PASS"; exit 0
else
  echo "FENCE ISOLATION: FAIL"; exit 1
fi
