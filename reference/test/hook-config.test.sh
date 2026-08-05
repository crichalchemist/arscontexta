#!/bin/bash
# hook-config.test.sh — behavioral tests for hooks/scripts/.
#
# WHY THIS EXISTS, measured rather than assumed. Before this suite, four of five
# hook scripts could be broken with every existing gate still green. Probed by
# mutation, one script at a time, against threshold-namespace, guard-failure,
# kernel-note-dirs, link-extraction and check-portability:
#
#   read_config.sh   kill dotted-key routing        -> caught (threshold-namespace)
#   read_config.sh   unparseable key returns default -> NOTHING NOTICED
#   session-orient   threshold never fires           -> NOTHING NOTICED
#   session-orient   ignore the configured threshold -> see the caveat below
#   vaultguard.sh    inertness inverted              -> NOTHING NOTICED
#
# The first row is the positive control: coverage IS detectable by that probe, so
# the NOTHINGs are a measurement and not a broken harness. Note which row is
# covered — the plan's own Step 1 proposed reverting exactly the dotted-key
# routing to demonstrate zero coverage, and that is the single mutation Spec F
# already protects. The gaps were elsewhere.
#
# ROW 4 NEEDS ITS CAVEAT, because the first version of this table over-claimed and
# a reviewer caught it. `threshold-namespace.test.sh` checks TEXTUALLY that
# session-orient.sh NAMES the key, so it depends on the SHAPE of the break:
#
#   OBS_THRESHOLD=10                       (key name gone) -> CAUGHT, 51/1
#   ...=$(threshold <key> 10 >/dev/null; echo 10)          -> NOT caught, 52/0
#                                          (name kept, value ignored)
#
# The second is the one that ships from an ordinary edit, and it is caught here
# and nowhere else. So the accurate claim is: three of five scripts had no
# coverage at all, and session-orient had TEXTUAL but not BEHAVIOURAL coverage —
# not "four of five unprotected".
#
# Two of the uncovered rows are not hypothetical. "Unparseable returns the
# default" is the thing CLAUDE.md divergence 3 says must never happen —
# *returning the default is exactly how the hardcoded 10 stayed invisible*. And
# "ignore the configured threshold" is that divergence's entire subject, the
# defect commit 820af90 was written to fix. Both shipped with nothing holding them.
#
# vaultguard.sh had ZERO references from any gate and the widest blast radius of
# the three: it is what makes every plugin hook inert outside a vault, so
# inverting it fires auto-commit and write-validate in EVERY repository the
# plugin is installed in.
#
# WHICH SHELL RUNS THE SUBJECT: whichever shell is running this harness, per
# bump-version.test.sh's decision and for its reason — these are shebang scripts
# a user or another hook can invoke as `zsh hooks/scripts/...`, so pinning them
# to bash would leave the fork class this repo has shipped three times unexercised.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../../hooks/scripts"
for f in read_config.sh vaultguard.sh session-orient.sh; do
    [ -r "$SRC/$f" ] || { echo "FAIL: cannot read $SRC/$f"; exit 1; }
done
FM_SRC="$HERE/../lib/frontmatter.sh"
[ -r "$FM_SRC" ] || { echo "FAIL: cannot read $FM_SRC"; exit 1; }

# The shell under test is this harness's own.
if [ -n "${ZSH_VERSION:-}" ]; then SH=zsh; else SH=bash; fi

passed=0; failed=0; skipped=0
TMPDIRS=()
ok()   { passed=$((passed+1)); }
fail() { failed=$((failed+1)); printf 'FAIL: %s\n  expected [%s] got [%s]\n' "$1" "$2" "$3"; }
eq()   { if [ "$2" = "$3" ]; then ok; else fail "$1" "$2" "$3"; fi; }
cleanup() { local d; for d in "${TMPDIRS[@]:-}"; do [ -n "$d" ] && rm -rf "$d"; done; }
trap cleanup EXIT INT TERM

mkvault() {   # mkvault -> a directory the hooks accept as a vault
    local d; d=$(mktemp -d); TMPDIRS+=("$d")
    mkdir -p "$d/hooks/scripts" "$d/ops/observations" "$d/ops/tensions" "$d/ops/lib"
    cp "$SRC/read_config.sh" "$SRC/vaultguard.sh" "$SRC/session-orient.sh" "$d/hooks/scripts/"
    cp "$FM_SRC" "$d/ops/lib/frontmatter.sh"
    printf '# marker\ngit: true\nsession_capture: false\n' > "$d/.arscontexta"
    # 12 open observations and 6 open tensions. The counts straddle BOTH default
    # thresholds (10 and 5) so a fixture that silently produced zero would fail
    # the fires-case rather than passing the does-not-fire case by accident.
    local i
    for i in $(seq 1 12); do printf -- '---\nstatus: open\n---\nobservation %s\n' "$i" > "$d/ops/observations/o$i.md"; done
    for i in $(seq 1 6);  do printf -- '---\nstatus: open\n---\ntension %s\n' "$i" > "$d/ops/tensions/t$i.md"; done
    printf '%s' "$d"
}
# THE FIXTURE ASSERTS ITS OWN SETUP. placeholder-count.test.sh went 30/30, 28/2,
# 29/1 with its subject unchanged because a silent setup failure left it
# measuring a tree that was never built. A suite is not exempt from the defect
# class it exists to catch.
staged() {    # staged <vault> <expected-observations> [<expected-tensions>]
    local d="$1" want="$2" wantt="${3:-6}" got gott
    got=$(ls -1 "$d"/ops/observations/*.md 2>/dev/null | wc -l | tr -d ' ')
    # TENSIONS TOO. Checking only observations left a fixture with 12 of one and
    # zero of the other passing setup, after which the tension assertion failed
    # for a reason that reads like a defect in the subject.
    gott=$(ls -1 "$d"/ops/tensions/*.md 2>/dev/null | wc -l | tr -d ' ')
    [ "$got" = "$want" ] && [ "$gott" = "$wantt" ] \
      && [ -f "$d/.arscontexta" ] && [ -r "$d/ops/lib/frontmatter.sh" ] && return 0
    printf 'FIXTURE NOT STAGED: %s has %s observations (want %s) and %s tensions (want %s), marker=%s fmlib=%s\n' \
        "$d" "$got" "$want" "$gott" "$wantt" "$([ -f "$d/.arscontexta" ] && echo y || echo n)" \
        "$([ -r "$d/ops/lib/frontmatter.sh" ] && echo y || echo n)" >&2
    failed=$((failed+1)); return 1
}
cfg() {       # cfg <vault> <obs-threshold> <tension-threshold>
    printf 'self_evolution:\n  observation_threshold: %s\n  tension_threshold: %s\n' "$2" "$3" > "$1/ops/config.yaml"
}
rc()  { ( cd "$1" && shift && CLAUDE_PROJECT_DIR="$PWD" $SH "$@" >/dev/null 2>&1; echo $? ); }
out() { ( cd "$1" && shift && CLAUDE_PROJECT_DIR="$PWD" $SH "$@" 2>/dev/null ); }
err() { ( cd "$1" && shift && CLAUDE_PROJECT_DIR="$PWD" $SH "$@" 2>&1 >/dev/null ); }
# session-orient.sh reads stdin (`INPUT=$(cat)`); without a redirect it BLOCKS
# forever. Supplying `{}` models the SessionStart payload with no session_id,
# which keeps session-capture out of the way of the threshold assertions.
orient()  { ( cd "$1" && CLAUDE_PROJECT_DIR="$PWD" $SH hooks/scripts/session-orient.sh </dev/null 2>/dev/null ); }
orient_e(){ ( cd "$1" && CLAUDE_PROJECT_DIR="$PWD" $SH hooks/scripts/session-orient.sh </dev/null 2>&1 >/dev/null ); }
# Its own helper rather than an inline subshell: written inline, the "$PWD" in
# CLAUDE_PROJECT_DIR expands in the CALLER before the cd runs, so the hook was
# handed this repo's path instead of the fixture's — and the assertion compared a
# command string against "0" rather than running anything.
orient_rc(){ ( cd "$1" && CLAUDE_PROJECT_DIR="$PWD" $SH hooks/scripts/session-orient.sh </dev/null >/dev/null 2>&1; echo $? ); }

# === read_config.sh — three states, and the third is the one that matters =====
V=$(mkvault); staged "$V" 12 || true
cfg "$V" 10 5

# NOT CONFIGURED -> the default, quietly. The ordinary case.
eq "read_config: an absent key returns the default" "77" \
   "$(out "$V" hooks/scripts/read_config.sh self_evolution.no_such_key 77)"
eq "read_config: and exits 0 doing it"               "0" \
   "$(rc "$V" hooks/scripts/read_config.sh self_evolution.no_such_key 77)"
# CONFIGURED -> the value. The positive companion: without this, every assertion
# below is satisfied by a reader that always returns the default.
eq "read_config: a configured key returns its VALUE, not the default" "10" \
   "$(out "$V" hooks/scripts/read_config.sh self_evolution.observation_threshold 99)"
eq "read_config: the second key too"                 "5" \
   "$(out "$V" hooks/scripts/read_config.sh self_evolution.tension_threshold 99)"

# CONFIGURED BUT UNREADABLE -> exit 1 and say so, NEVER the default. This is the
# assertion the whole file is for. CLAUDE.md divergence 3: "returning the default
# is exactly how the hardcoded 10 stayed invisible".
printf 'self_evolution:\n  observation_threshold:\n' > "$V/ops/config.yaml"
eq "read_config: an unparseable value exits 1"       "1" \
   "$(rc "$V" hooks/scripts/read_config.sh self_evolution.observation_threshold 10)"
eq "read_config: and does NOT return the default"   "yes" \
   "$(out "$V" hooks/scripts/read_config.sh self_evolution.observation_threshold 10 | grep -q '^10$' && echo no || echo yes)"
eq "read_config: and names the key on stderr"       "yes" \
   "$(err "$V" hooks/scripts/read_config.sh self_evolution.observation_threshold 10 | grep -q 'observation_threshold' && echo yes || echo no)"

# CONFIGURED BUT UNREADABLE — the state `[ -f ]` cannot distinguish from absent.
# This was a live defect when the suite was written: a config at chmod 000
# returned the DEFAULT at rc 0 with empty stderr, because `[ -f ]` tests
# existence and awk's own 2>/dev/null swallowed the permission error, so an empty
# parse read as "not configured". A vault whose owner set 20 was silently told
# 10 — divergence 3's exact failure, inside the routing added to fix it.
#
# The chmod is VERIFIED to have taken effect: as root it does not, and an
# assertion that silently tests nothing is the thing this repo keeps finding.
printf 'self_evolution:\n  observation_threshold: 20\n' > "$V/ops/config.yaml"
chmod 000 "$V/ops/config.yaml"
if [ -r "$V/ops/config.yaml" ]; then
    echo "SKIP: chmod 000 did not deny reads (running as root?) — 3 assertions not run" >&2; skipped=$((skipped+3))
else
    eq "read_config: an UNREADABLE config exits 1"       "1" \
       "$(rc "$V" hooks/scripts/read_config.sh self_evolution.observation_threshold 10)"
    eq "read_config: and does NOT return the default"   "yes" \
       "$(out "$V" hooks/scripts/read_config.sh self_evolution.observation_threshold 10 | grep -q '^10$' && echo no || echo yes)"
    eq "read_config: and says so on stderr"             "yes" \
       "$(err "$V" hooks/scripts/read_config.sh self_evolution.observation_threshold 10 | grep -q 'cannot be read' && echo yes || echo no)"
fi
chmod 644 "$V/ops/config.yaml"
# The bare-key path had the identical hole.
chmod 000 "$V/.arscontexta"
if [ -r "$V/.arscontexta" ]; then
    echo "SKIP: chmod 000 did not deny reads — 1 assertion not run" >&2; skipped=$((skipped+1))
else
    eq "read_config: an UNREADABLE .arscontexta also exits 1" "1" \
       "$(rc "$V" hooks/scripts/read_config.sh session_capture true)"
fi
chmod 644 "$V/.arscontexta"

# SECTION SCOPING. A same-named field in a different section must not answer —
# otherwise two unrelated settings silently share one value.
printf 'other_section:\n  observation_threshold: 999\nself_evolution:\n  tension_threshold: 4\n' > "$V/ops/config.yaml"
eq "read_config: a field in ANOTHER section does not answer" "22" \
   "$(out "$V" hooks/scripts/read_config.sh self_evolution.observation_threshold 22)"
eq "read_config: while the right section still does"          "4" \
   "$(out "$V" hooks/scripts/read_config.sh self_evolution.tension_threshold 22)"

# BARE KEYS still read .arscontexta, unchanged by the dotted-key routing.
eq "read_config: a bare key reads .arscontexta"      "false" \
   "$(out "$V" hooks/scripts/read_config.sh session_capture true)"
eq "read_config: and an absent bare key defaults"    "yes" \
   "$(out "$V" hooks/scripts/read_config.sh no_such_bare_key yes)"

# CLAUDE_PROJECT_DIR IS HONOURED, not merely equal to the cwd. Every helper cds
# into the fixture and then sets CLAUDE_PROJECT_DIR to the same place, so the two
# roots were never distinguished and `PROJECT_DIR=$(pwd)` — dropping the variable
# entirely — passed every assertion. Running from ELSEWHERE separates them.
V3=$(mkvault); staged "$V3" 12 || true
cfg "$V3" 33 5
eq "read_config: CLAUDE_PROJECT_DIR is used, not the cwd" "33" \
   "$( cd / && CLAUDE_PROJECT_DIR="$V3" $SH "$V3/hooks/scripts/read_config.sh" self_evolution.observation_threshold 99 )"

# === session-orient.sh — the thresholds actually gate something ===============
V=$(mkvault); staged "$V" 12 || true

# 12 observations against a threshold of 10, 6 tensions against 5: both fire.
cfg "$V" 10 5
eq "session-orient: 12 obs over a threshold of 10 fires"  "yes" \
   "$(orient "$V" | grep -q 'CONDITION: 12 pending observations' && echo yes || echo no)"
eq "session-orient: 6 tensions over a threshold of 5 fires" "yes" \
   "$(orient "$V" | grep -q 'CONDITION: 6 unresolved tensions' && echo yes || echo no)"

# Same tree, thresholds raised past the counts: neither fires. This is the pair
# that proves the hook READS the config rather than hardcoding 10/5 — the exact
# defect 820af90 fixed, which nothing has held since.
cfg "$V" 99 99
eq "session-orient: raising the threshold past the count silences it" "yes" \
   "$(orient "$V" | grep -q 'pending observations' && echo no || echo yes)"
eq "session-orient: and the tension signal too"                       "yes" \
   "$(orient "$V" | grep -q 'unresolved tensions' && echo no || echo yes)"
# ...and the hook still produced its other output, so the two assertions above
# are not passing because the whole hook died.
eq "session-orient: the hook still ran (not silent because it crashed)" "yes" \
   "$(orient "$V" | grep -q . && echo yes || echo no)"

# A CONFIG THE READER CANNOT PARSE MUST NOT SILENTLY BECOME A WORKING THRESHOLD.
# The hook does not exit 1 — it is SessionStart, and aborting costs the user the
# whole orientation block — so it says so on stderr and falls back visibly.
printf 'self_evolution:\n  observation_threshold: not-a-number\n  tension_threshold: 5\n' > "$V/ops/config.yaml"
eq "session-orient: an unparseable threshold is reported on stderr" "yes" \
   "$(orient_e "$V" | grep -q 'CONDITION' && echo yes || echo no)"
eq "session-orient: and it still starts the session"                "0" "$(orient_rc "$V")"

# === vaultguard.sh — the inertness every other hook depends on ================
# CONTRACT-PINNING, NOT DEFECT-DERIVED: no defect is known here. These exist
# because this script decides whether EVERY plugin hook runs at all, and it had
# no coverage; a one-character inversion fires auto-commit and write-validate in
# every repository the plugin is installed in.
G=$(mktemp -d); TMPDIRS+=("$G"); mkdir -p "$G/hooks/scripts"
cp "$SRC/vaultguard.sh" "$G/hooks/scripts/"
eq "vaultguard: a plain directory is NOT a vault"        "1" "$(rc "$G" hooks/scripts/vaultguard.sh)"
eq "vaultguard: and says nothing while declining"       "yes" \
   "$([ -z "$(out "$G" hooks/scripts/vaultguard.sh)" ] && echo yes || echo no)"
eq "vaultguard: and creates no marker in a tree it rejected" "yes" \
   "$( rc "$G" hooks/scripts/vaultguard.sh >/dev/null; [ -f "$G/.arscontexta" ] && echo no || echo yes)"
# The positive companion — without it, a guard that always exits 1 passes above.
printf '# marker\n' > "$G/.arscontexta"
eq "vaultguard: a marker makes it a vault"               "0" "$(rc "$G" hooks/scripts/vaultguard.sh)"

# THE AUTO-MIGRATE BRANCH, pinned because it WRITES. A directory holding
# ops/config.yaml is adopted as a vault and given a marker it never had. That is
# the documented behaviour; it is pinned here so changing it is a decision rather
# than a side effect, and so a reader knows a plain `ops/config.yaml` is enough.
G2=$(mktemp -d); TMPDIRS+=("$G2"); mkdir -p "$G2/hooks/scripts" "$G2/ops"
cp "$SRC/vaultguard.sh" "$G2/hooks/scripts/"
printf 'x: 1\n' > "$G2/ops/config.yaml"
eq "vaultguard: a legacy ops/config.yaml is adopted"     "0" "$(rc "$G2" hooks/scripts/vaultguard.sh)"
eq "vaultguard: and a marker is WRITTEN into that tree" "yes" \
   "$([ -f "$G2/.arscontexta" ] && echo yes || echo no)"

# THE OTHER BRANCH THAT WRITES. vaultguard rewrites a legacy cat-face marker into
# the YAML form. Unpinned, both "delete the branch" and "make its condition
# always true" left this suite green — and the second makes EVERY SessionStart
# rewrite .arscontexta, resetting a live `git: false / session_capture: false`
# back to true. A guard that silently re-enables auto-commit is worse than one
# that fails.
G3=$(mktemp -d); TMPDIRS+=("$G3"); mkdir -p "$G3/hooks/scripts"
cp "$SRC/vaultguard.sh" "$G3/hooks/scripts/"
printf '(^.^)\n' > "$G3/.arscontexta"
eq "vaultguard: a legacy cat-face marker is still a vault"  "0" "$(rc "$G3" hooks/scripts/vaultguard.sh)"
eq "vaultguard: and is REWRITTEN into the YAML form"      "yes" \
   "$(grep -q 'session_capture:' "$G3/.arscontexta" && echo yes || echo no)"
# The companion, and the one that matters: a marker WITHOUT the cat-face must be
# left exactly as the user wrote it.
printf '# mine\ngit: false\nsession_capture: false\n' > "$G3/.arscontexta"
eq "vaultguard: a user's own marker is left alone"        "0" "$(rc "$G3" hooks/scripts/vaultguard.sh)"
eq "vaultguard: and its values are NOT reset to true"    "yes" \
   "$(grep -q 'session_capture: false' "$G3/.arscontexta" && echo yes || echo no)"

# OMISSION, NOT SUBSTITUTION. session-orient.sh's own comment says an unmeasured
# count must be OMITTED rather than reported as 0, because 0 is precisely the
# value that stops a threshold ever firing — an omitted line is visible, a
# substituted 0 is not. Nothing held that: with the library removed, changing
# OBS_COUNT="" to OBS_COUNT=0 left the suite green. It is reachable by an
# ordinary edit (`|| echo 0` has shipped in this repo before), not by accident.
V2=$(mkvault); staged "$V2" 12 || true
cfg "$V2" 10 5
rm -f "$V2/ops/lib/frontmatter.sh"
eq "session-orient: no frontmatter lib -> the signal is OMITTED"  "yes" \
   "$(orient "$V2" | grep -q 'pending observations' && echo no || echo yes)"
eq "session-orient: and NOT reported as a count of 0"           "yes" \
   "$(orient "$V2" | grep -q '0 pending observations' && echo no || echo yes)"
eq "session-orient: and the reason is on stderr"                "yes" \
   "$(orient_e "$V2" | grep -q 'frontmatter.sh missing' && echo yes || echo no)"
eq "session-orient: and the session still starts"                 "0" "$(orient_rc "$V2")"

# THE DISCRIMINATING CASE, and it took finding. With the usual threshold of 10,
# an omitted count and a substituted 0 are INDISTINGUISHABLE — both leave
# `0 >= 10` false and print nothing, so mutating `OBS_COUNT=""` to `OBS_COUNT=0`
# changed nothing observable and the suite stayed green over it. A threshold of
# ZERO separates them: omission still prints nothing, while a substituted 0
# satisfies `0 -ge 0` and emits the absurd line "0 pending observations" — a
# maintenance signal fabricated out of a measurement that never happened.
#
# (The other route to this branch is a scan that FAILS while the library is
# present. It is not reachable: count_notes_by_field on an unreadable directory
# returns 0 at rc 0 rather than failing, so the `||` never fires. That is the
# same silent-failure class one layer down, in reference/lib/frontmatter.sh, and
# is recorded rather than fixed here — it is a different file with its own gate.)
cfg "$V2" 0 0
# ANCHORED: a bare '0 pending observations' is a substring of 10, 20 and 30, so
# an unanchored match would go red on healthy code the moment mkvault's fixture
# size changed. False-red rather than false-green, but it fails for the wrong
# reason and that is how an assertion gets deleted instead of fixed.
eq "session-orient: an unmeasured count is not fabricated as 0" "yes" \
   "$(orient "$V2" | grep -q '^CONDITION: 0 pending observations' && echo no || echo yes)"
eq "session-orient: nor the tension count"                     "yes" \
   "$(orient "$V2" | grep -q '^CONDITION: 0 unresolved tensions' && echo no || echo yes)"
# The positive companion: with the library BACK, a threshold of 0 does fire, so
# the two assertions above are not passing because nothing ever fires at 0.
cp "$FM_SRC" "$V2/ops/lib/frontmatter.sh"
eq "session-orient: with the library back, threshold 0 DOES fire"  "yes" \
   "$(orient "$V2" | grep -q '12 pending observations' && echo yes || echo no)"

# THE TOTAL MUST NOT MOVE WHEN AN ASSERTION IS SKIPPED. As root, chmod 000 does
# not deny reads, so the four permission assertions correctly SKIP — and the
# suite then printed passed=36, which check-doc-claims reads as "document says
# 40, tree measures 36 — fix the document, not the gate", instructing a wrong
# number into two files over a runner difference. GitHub-hosted ubuntu-latest is
# uid 1001, but container and self-hosted runners are root. Skipped assertions
# are counted and named, so the documented total means "assertions in this
# suite" on every runner, and a skip is visible rather than silent.
# === the content-destruction guard ==========================================
# Every other check in write-validate.sh asks "is this note well-formed?".
# None asks "is it still THERE?" — so a pass that replaced a developed note with
# a schema-clean fragment left every check green.
#
# THE ORDERING ASSERTION IS THE LOAD-BEARING ONE. The guard reads HEAD to see the
# pre-write content, which only works because write-validate runs BEFORE
# auto-commit on the same PostToolUse matcher. Invert that and the guard compares
# the file to itself and passes silently on every write — the guard's own failure
# mode being the defect it exists to catch.
ORDER=$(python3 -c "
import json,sys
h=json.load(open('$HERE/../../hooks/hooks.json'))
d=h.get('hooks') or h
for e in d.get('PostToolUse',[]):
    names=[c.get('command','').split('/')[-1] for c in e.get('hooks',[])]
    if 'write-validate.sh' in names and 'auto-commit.sh' in names:
        print('ok' if names.index('write-validate.sh') < names.index('auto-commit.sh') else 'INVERTED')
        sys.exit()
print('NOT-IN-SAME-MATCHER')
" 2>/dev/null)
eq "guard: write-validate runs BEFORE auto-commit"        "ok" "$ORDER"

# A vault fixture with git, so the guard has a HEAD to compare against.
mkguard() {
    local d; d=$(mktemp -d); TMPDIRS+=("$d")
    mkdir -p "$d/hooks/scripts" "$d/notes"
    cp "$SRC/write-validate.sh" "$SRC/vaultguard.sh" "$d/hooks/scripts/"
    printf '# marker\n' > "$d/.arscontexta"
    { printf -- '---\ndescription: a developed note\ntopics: ["[[hub]]"]\n---\n'
      for i in $(seq 1 20); do echo "Substantial paragraph $i of prose that took real work."; done
      for i in $(seq 1 6); do echo "See [[rel-$i]]."; done; } > "$d/notes/n.md"
    ( cd "$d" && git init -q . && git config user.email t@t && git config user.name t \
      && git add -A && git commit -qm base ) >/dev/null 2>&1
    printf '%s' "$d"
}
gwrite() { ( cd "$1" && printf '{"tool_input":{"file_path":"%s"}}' "$1/notes/n.md" \
             | $SH hooks/scripts/write-validate.sh 2>&1 ); }

# Destruction: a developed note replaced by a fragment.
G=$(mkguard); printf -- '---\ndescription: d\ntopics: ["[[hub]]"]\n---\nfragment\n' > "$G/notes/n.md"
eq "guard: a note shrinking by over half WARNS"          "yes" \
   "$(gwrite "$G" | grep -q 'SHRANK' && echo yes || echo no)"
eq "guard: and names both byte counts"                   "yes" \
   "$(gwrite "$G" | grep -qE 'SHRANK [0-9]+->[0-9]+' && echo yes || echo no)"

# Links are a SEPARATE property: a rewrite can hold its length and drop every edge.
G=$(mkguard)
{ printf -- '---\ndescription: d\ntopics: ["[[hub]]"]\n---\n'
  for i in $(seq 1 26); do echo "Substantial paragraph $i of prose that took real work."; done; } > "$G/notes/n.md"
eq "guard: links lost with length kept still WARNS"      "yes" \
   "$(gwrite "$G" | grep -q 'wiki links' && echo yes || echo no)"
eq "guard: and does NOT claim the note shrank"           "yes" \
   "$(gwrite "$G" | grep -q 'SHRANK' && echo no || echo yes)"

# The three silences. A guard that fires on correct work gets switched off,
# which is worse than no guard — so each of these has its own assertion.
G=$(mkguard)
{ printf -- '---\ndescription: d\ntopics: ["[[hub]]"]\n---\n'
  for i in $(seq 1 40); do echo "More developed prose, paragraph $i."; done
  for i in $(seq 1 9); do echo "See [[rel-$i]]."; done; } > "$G/notes/n.md"
eq "guard: a note that GREW is silent"                   "yes" \
   "$(gwrite "$G" | grep -qE 'SHRANK|wiki links' && echo no || echo yes)"

G=$(mkguard); printf -- '---\ndescription: d\ntopics: []\n---\nbrand new\n' > "$G/notes/fresh.md"
eq "guard: a NEW note has nothing to destroy, silent"    "yes" \
   "$( ( cd "$G" && printf '{"tool_input":{"file_path":"%s"}}' "$G/notes/fresh.md" \
        | $SH hooks/scripts/write-validate.sh 2>&1 ) | grep -qE 'SHRANK|wiki links' && echo no || echo yes)"

# The stub must HALVE, or this assertion holds with or without the floor and
# proves nothing — the first version shrank 40->38 bytes and stayed green under
# a mutation that removed the floor entirely.
G=$(mkguard)
{ printf -- '---\ndescription: s\ntopics: []\n---\n'; for i in $(seq 1 4); do echo "short line $i"; done; } > "$G/notes/stub.md"
( cd "$G" && git add -A && git commit -qm stub ) >/dev/null 2>&1
printf -- '---\ndescription: s\ntopics: []\n---\n' > "$G/notes/stub.md"
eq "guard: a stub under the 200-byte floor is silent"    "yes" \
   "$( ( cd "$G" && printf '{"tool_input":{"file_path":"%s"}}' "$G/notes/stub.md" \
        | $SH hooks/scripts/write-validate.sh 2>&1 ) | grep -q 'SHRANK' && echo no || echo yes)"

printf '\npassed=%s failed=%s\n' "$((passed + skipped))" "$failed"
[ "${skipped:-0}" -eq 0 ] || printf 'note: %s assertion(s) SKIPPED (see stderr) and counted in the total\n' "$skipped"
[ "$failed" -eq 0 ]
