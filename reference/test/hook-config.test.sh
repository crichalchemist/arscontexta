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
#   session-orient   ignore the configured threshold -> NOTHING NOTICED
#   vaultguard.sh    inertness inverted              -> NOTHING NOTICED
#
# The first row is the positive control: coverage IS detectable by that probe, so
# the four NOTHINGs are a measurement and not a broken harness. Note which row is
# covered — the plan's own Step 1 proposed reverting exactly the dotted-key
# routing to demonstrate zero coverage, and that is the single mutation Spec F
# already protects. The gaps were elsewhere.
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

passed=0; failed=0
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
staged() {    # staged <vault> <expected-open-observations>
    local d="$1" want="$2" got
    got=$(ls -1 "$d"/ops/observations/*.md 2>/dev/null | wc -l | tr -d ' ')
    [ "$got" = "$want" ] && [ -f "$d/.arscontexta" ] && [ -r "$d/ops/lib/frontmatter.sh" ] && return 0
    printf 'FIXTURE NOT STAGED: %s has %s observations (want %s), marker=%s fmlib=%s\n' \
        "$d" "$got" "$want" "$([ -f "$d/.arscontexta" ] && echo y || echo n)" \
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

printf '\npassed=%s failed=%s\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
