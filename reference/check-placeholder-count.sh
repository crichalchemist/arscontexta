#!/bin/bash
# check-placeholder-count.sh — did an edit HARDCODE a vault's vocabulary into a template?
#
# THE DEFECT. skill-sources/ templates are copied into generated vaults, so they
# must speak placeholders (`{vocabulary.notes}`) and never one vault's concrete
# name (`nodes/`). A backport that copy-pastes a fix out of the field vault
# silently ships that vault's dialect to every future system. CONTRIBUTING.md
# calls reversing this one of two MANDATORY reverse-transforms; nothing enforced it.
#
# THE PROPERTY: for every skill-sources/ file in the diff range, the placeholder
# count must not DECREASE. A rise is normal and is not reported — the hybrid qmd
# query form repeats its query into both `lex` and `vec` sub-queries, so one
# placeholder legitimately becomes two.
#
# KNOWN GRANULARITY LIMIT, stated rather than solved: this compares per-file
# TOTALS, so it cannot distinguish "added a placeholder" from "hardcoded one and
# added two others in the same file". A net non-decrease passes. Per-marker
# identity would need a diff-aware extractor; per-file totals are what this has.
#
# WHY THE PATTERN IS THE THREE-FAMILY ONE, AND WHY THAT IS NOT A DETAIL:
# Two spellings of this command already existed and had already DIVERGED.
# CONTRIBUTING.md's inline copy matched `{vocabulary.*}` and `{config.*}` only;
# reference/skill-authoring.md:62 also matches `{DOMAIN:*}`, an older spelling
# that is still live. Measured across skill-sources/ when this gate was written:
# 488 markers against 616. The 128-marker gap spans NINE files, and hardcoding a
# `{DOMAIN:notes}` produced NO OUTPUT AT ALL from the documented check while the
# three-family pattern reported 27 -> 21 on the same tree. This pattern was
# consolidated here, and is now the single definition in
# reference/lib/placeholder-pattern.sh; CONTRIBUTING.md still points at this
# script to run the check.
#
# The pattern itself now lives in reference/lib/placeholder-pattern.sh -- sourced,
# not redefined, so this script and check-vocabulary-schema.sh can never
# independently drift. See that file's own header for why the pattern has three
# families and why it is not widened to a bare `{…}`.
#
# SCOPE IS skill-sources/ ONLY, and both exclusions are deliberate:
#   * generators/features/*.md carry {DOMAIN:*} too (15 files), but they are
#     composition blocks SELECTED by configuration, not templates copied verbatim.
#     CLAUDE.md records that changing what they emit is a design decision. A gate
#     that fires on a legitimate generator edit gets deleted, not fixed.
#   * platforms/shared/skill-blocks/ holds the repo's densest markup — 146 in
#     `verify` where skill-sources has 36 — but it is FROZEN by check-portability.sh
#     check 4, so it cannot appear in a diff at all. Scanning it is dead code.
#   * skills/ are the plugin's own commands and legitimately carry none, so
#     scanning them yields 0 -> 0 noise.
#
# EXIT CODES, THREE STATES NOT TWO:
#   0  no count decreased (or no skill-sources file is in range)
#   1  a count decreased and no allowlist entry covers it
#   2  the result is NOT EVIDENCE — merge base unreachable, `git show` failed, or
#      the extractor matched zero markers across all of skill-sources/. rc 2
#      outranks rc 1, because "could not run" and "ran and found nothing" are
#      different facts and this repo has twice shipped a scan that matched
#      nothing and reported green.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/placeholder-pattern.sh"
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT" || { echo "check-placeholder-count: cannot cd to repo root '$ROOT'" >&2; exit 2; }

BASE="${1:-main}"

echo "=== check-placeholder-count ==="
echo "property: no skill-sources/ file LOSES placeholders across the range"
echo "scope:    skill-sources/ only; generators/ and the frozen skill-blocks/ are out by design"
echo "NOT checked: whether a rise is a real placeholder or a duplicate; per-file totals only"
echo

# ALLOWLIST — "<path> <old>-><new> <reason>". Bidirectional, on check 6's model:
# an entry whose decrease no longer matches the tree is STALE and fails, so the
# list drains rather than rots. Keyed on the COUNTS, not the filename alone —
# a bare path would absorb a second, unrelated decrease in the same file later.
# The staleness half runs whether this is empty or not, so an entry here is
# never a silent, permanent exemption.
# DRAINED 2026-08-08. The one entry -- skill-sources/reduce/SKILL.md 132->131,
# the {vocabulary.seed} unwrapping -- was excusing a decrease that 752f38f4 has
# since carried into main, so a range based on main can no longer exhibit it.
# It lay dormant exactly as the range-relative note at the staleness half
# predicts ("a fully obsolete entry survives until a range touches its file
# again") and fired the moment an unrelated backport edited that same file.
# Deleting it is the drain, not a workaround for it.
PLACEHOLDER_ALLOW=""

fail=0
rc2=0
die2() { printf '  CANNOT CONCLUDE: %s\n' "$1"; rc2=1; }

# --- guards, before any measurement -----------------------------------------
# THE EXTRACTOR MUST MATCH SOMETHING. If the marker syntax is ever changed and
# this pattern is not, every file reports 0 and every comparison passes: 0 >= 0
# for all of them, rc 0, a green tick over a gate measuring nothing.
total_markers=$(/usr/bin/grep -roh "$PLACEHOLDER_PAT" skill-sources/ 2>/dev/null | /usr/bin/grep -c . || true)
if [ ! -d skill-sources ]; then
    die2 "skill-sources/ does not exist in this tree — wrong root, or a moved layout"
elif [ "${total_markers:-0}" -eq 0 ]; then
    die2 "the extractor matched ZERO markers across all of skill-sources/ — the pattern is stale, not the tree clean"
fi

# THE MERGE BASE MUST ACTUALLY RESOLVE, and `git rev-parse --verify` is NOT that
# test — but get the mechanism right, because the obvious story is wrong and this
# comment told it for one commit. `git show "$BASE:$f"` does NOT return empty in a
# shallow clone: the blob is present, and it returns 27 markers of real content.
#
# What actually breaks is that there is no common ancestor to diff FROM. Neutered
# on a base with no shared history, the gate prints `PASS 32 template(s) changed
# … no count decreased`, rc 0, over a genuine hardcode — because the range itself
# is meaningless, not because any single lookup returned nothing. That is the
# silent PASS, and merge-base is the test that catches it. actions/checkout
# defaults to depth 1, so an unfetched base ref is the DEFAULT CI state.
MB=""
if ! git rev-parse --verify "$BASE" >/dev/null 2>&1; then
    die2 "base ref '$BASE' does not resolve — pass a ref that exists (CI needs fetch-depth: 0)"
elif ! MB=$(git merge-base "$BASE" HEAD 2>/dev/null) || [ -z "$MB" ]; then
    die2 "no merge base between '$BASE' and HEAD — shallow clone? CI needs fetch-depth: 0"
fi

[ "$rc2" -eq 1 ] && { echo; echo "PLACEHOLDER COUNT: CANNOT CONCLUDE"; exit 2; }

# --- one predicate, used for both the tree side and the base side ------------
# Re-deriving this at the second site is how the fence gate's two halves came
# apart; check-portability.sh check 6 carries the same note for the same reason.
count_markers() {          # count_markers  (reads the file/stream on stdin)
    /usr/bin/grep -o "$PLACEHOLDER_PAT" 2>/dev/null | /usr/bin/grep -c . || true
}

# WHY THE ARGUMENTS ARE COPIED TO NAMED LOCALS FIRST:
# The first draft called `set -- $e` inside this loop to split the entry, which
# CLOBBERS the function's own positional parameters — after it, "$3" was a field
# of the allowlist line rather than the path argument, so every lookup compared
# the wrong things. It was invisible because the allowlist is empty, so the branch
# never ran: an untested branch behind an empty list, which is the shape this repo
# keeps finding. Fixed by not using positional params past the first three lines,
# and exercised by a test that populates the list.
allow_entry_for() {        # allow_entry_for <path> <old> <new> -> the entry, or empty
    a_path="$1"; a_old="$2"; a_new="$3"
    printf '%s\n' "$PLACEHOLDER_ALLOW" | while IFS= read -r e; do
        [ -n "$e" ] || continue
        epath=${e%% *}
        rest=${e#* }; ecount=${rest%% *}
        [ "$epath" = "$a_path" ] || continue
        [ "$ecount" = "$a_old->$a_new" ] || continue
        printf '%s' "$e"
    done
}

# --- the scan ----------------------------------------------------------------
# THE RANGE IS THE MERGE BASE, NOT THE BASE REF. `git diff A..HEAD` compares the
# two TIPS, so every file the base branch moved ahead on appears here with its
# base-side content — and a placeholder ADDED on main reads as one REMOVED here.
# Reproduced: main adds 3 markers to verify/SKILL.md, a branch that never touched
# that file reports `HARDCODED A PLACEHOLDER: verify/SKILL.md (30 -> 27)`, rc 1.
# origin/main is routinely ahead in CI, so this fired on ordinary branches. The
# script already computed the merge base as a guard and then did not use it.
#
# RENAMES ARE FOLLOWED (-M), because otherwise a `git mv` plus a hardcode escapes
# completely: the new path has no base-side counterpart, so `was` is 0 and any
# count clears it. Measured before this change: renaming verify/SKILL.md and
# hardcoding ALL 27 of its markers reported `PASS 2 template(s) changed, no count
# decreased`, rc 0. Comparing the OLD path at the merge base against the NEW path
# now is what closes it.
#
# --name-status without -z, because -z's rename records are three NUL-separated
# fields against two for everything else, and mis-parsing that silently shifts
# every subsequent record. Tab separation handles spaces; a path containing a
# newline or a quote is QUOTED by git, which is detected below and reported as
# rc 2 rather than skipped — this repo has no such path, and a silent skip is how
# a scan that covered nothing would report clean.
if ! raw_status=$(git diff --name-status -M "$MB" HEAD 2>/dev/null); then
    die2 "git diff failed against merge base $MB — cannot enumerate changed templates"
fi
[ "$rc2" -eq 1 ] && { echo; echo "PLACEHOLDER COUNT: CANNOT CONCLUDE"; exit 2; }

# THE SET-DEFINING MEASUREMENT NEEDS ITS OWN GUARD. Before the line above, this
# was `$(git diff … || true)`: on failure it produced an empty list and the gate
# printed "PASS no skill-sources/ templates … nothing to check", rc 0 — a positive
# claim about the tree derived from a measurement that did not run. It was the one
# measurement here without an rc-2 guard, and it defined the set all the others read.
pairs=$(printf '%s\n' "$raw_status" | while IFS= read -r line; do
    [ -n "$line" ] || continue
    st=${line%%	*}; rest=${line#*	}
    case "$st" in
      R*) old=${rest%%	*}; new=${rest#*	} ;;
      # A DELETION GIT DID NOT PAIR. Deleting a template is not a hardcoding, so
      # this is not a failure — but it must not be silent either. `-M` pairs a
      # rename with a heavy edit only while the two sides stay similar: measured,
      # a realistic template renamed with EVERY marker hardcoded still scores
      # R098 and is caught, while a one-line file rewritten end to end has no
      # similarity left and git reports A + D. In that shape the added path has
      # no base-side counterpart, was=0, and any count clears it. Naming the
      # deletion turns a silent escape into a visible one for a human to judge.
      D*) case "$rest" in skill-sources/*) printf 'DEL\t%s\n' "$rest" ;; esac; continue ;;
      *)  old=$rest; new=$rest ;;
    esac
    case "$new" in skill-sources/*) ;; *) case "$old" in skill-sources/*) ;; *) continue ;; esac ;; esac
    case "$old$new" in \"*|*\"*) printf 'ERR git quoted a path (newline or quote in name): %s\n' "$line"; continue ;; esac
    printf '%s\t%s\n' "$old" "$new"
done)
deleted=$(printf '%s\n' "$pairs" | /usr/bin/grep '^DEL	' | cut -f2- || true)
pairs=$(printf '%s\n' "$pairs" | /usr/bin/grep -v '^DEL	' || true)
n_changed=$(printf '%s\n' "$pairs" | /usr/bin/grep -c . || true)

findings=""
if [ "${n_changed:-0}" -gt 0 ]; then
    findings=$(printf '%s\n' "$pairs" | while IFS= read -r pair; do
        [ -n "$pair" ] || continue
        case "$pair" in ERR*) printf '%s\n' "$pair"; continue ;; esac
        old=${pair%%	*}; new=${pair#*	}
        [ -f "$new" ] || continue
        now=$(count_markers < "$new")
        # A file ADDED in this range does not exist at the merge base. That is
        # legitimately was=0, and must not be confused with `git show` failing,
        # which is why existence is tested separately rather than inferred from
        # empty output.
        if git cat-file -e "$MB:$old" 2>/dev/null; then
            if ! was_raw=$(git show "$MB:$old" 2>/dev/null); then
                printf 'ERR git show failed for %s at %s\n' "$old" "$MB"
                continue
            fi
            was=$(printf '%s' "$was_raw" | count_markers)
        else
            was=0
        fi
        case "$now$was" in *[!0-9]*|"") printf 'ERR non-numeric count for %s (was=%s now=%s)\n' "$new" "$was" "$now"; continue ;; esac
        [ "$now" -lt "$was" ] || continue
        label="$new"; [ "$old" = "$new" ] || label="$old -> $new"
        entry=$(allow_entry_for "$new" "$was" "$now")
        if [ -n "$entry" ]; then
            printf 'OK  allowlisted decrease %s (%s -> %s)\n' "$label" "$was" "$now"
        else
            printf 'BAD HARDCODED A PLACEHOLDER: %s (%s -> %s)\n' "$label" "$was" "$now"
        fi
    done)
fi

# WHY THIS IS A CAPTURE-THEN-TEST AND NOT A PIPELINE WITH `&& rc2=1`:
# The draft read `... | grep '^ERR ' | sed ... && rc2=1`. sed ALWAYS exits 0, so
# the `&&` fires whether or not grep matched — the gate would report CANNOT
# CONCLUDE on every clean run. It happened not to, purely because `set -o
# pipefail` let grep's rc 1 through, i.e. the correctness of a visible branch
# rested on a shell option set 90 lines away. Capture first, test the string.
errs=$(printf '%s\n' "$findings" | /usr/bin/grep '^ERR ' || true)
if [ -n "$errs" ]; then
    printf '%s\n' "$errs" | sed 's/^ERR /  CANNOT CONCLUDE: /'
    rc2=1
fi

bad=$(printf '%s\n' "$findings" | /usr/bin/grep '^BAD ' | sed 's/^BAD /  /' || true)

# THE OTHER DIRECTION — BUT SCOPED TO FILES ACTUALLY IN THIS RANGE, which is the
# difference between a range-relative gate and a tree-relative one.
#
# check 6's allowlist is keyed on TREE STATE, so "this entry no longer matches"
# is a fact about the repository and is true from every angle. This gate's key is
# RANGE-RELATIVE, and the first version copied check 6's shape without noticing
# that. The result: any entry made every unrelated branch red, because a range
# that touches no skill-sources/ file cannot exhibit the decrease the entry
# excuses. No entry could survive the merge of the change it was written for —
# CI would stay red until someone deleted it, which is a mechanism that punishes
# its own correct use.
#
# Scoping to files present in the range keeps the drain and drops the false red:
# an entry whose file IS in the range and no longer shows that decrease is stale
# and fails; an entry whose file is simply absent from the range says nothing.
# The cost, stated rather than hidden: a fully obsolete entry survives until a
# range touches its file again. That is the price of a range-relative key.
stale=$(printf '%s\n' "$PLACEHOLDER_ALLOW" | while IFS= read -r e; do
    [ -n "$e" ] || continue
    epath=${e%% *}
    rest=${e#* }; ecount=${rest%% *}
    case "$ecount" in *-\>*) ;; *) printf '  MALFORMED allowlist entry (want "<path> <old>-><new> <reason>"): %s\n' "$e"; continue ;; esac
    printf '%s\n' "$pairs" | /usr/bin/grep -qF "	$epath" || continue
    printf '%s\n' "$findings" | /usr/bin/grep -qF "allowlisted decrease $epath (${ecount%%->*} -> ${ecount##*->})" \
        || printf '  STALE allowlist entry no longer matches the tree: %s %s\n' "$epath" "$ecount"
done)

if [ -n "$deleted" ]; then
    printf '%s\n' "$deleted" | sed 's|^|  NOTE template deleted, not compared: |'
    # Name any skill-sources/ path ADDED in the same range beside it. In the
    # add+delete shape a rename is exactly that pair, and reporting the two
    # separately leaves the reader to notice the pairing themselves. Still rc 0 —
    # this is legibility, not a verdict, and failing a legitimate deletion is the
    # "fires on a correct edit" condition this file warns about elsewhere.
    added_here=$(printf '%s\n' "$pairs" | while IFS= read -r pr; do
        [ -n "$pr" ] || continue
        po=${pr%%	*}; pn=${pr#*	}
        [ "$po" = "$pn" ] || continue
        git cat-file -e "$MB:$pn" 2>/dev/null || printf '%s\n' "$pn"
    done)
    [ -n "$added_here" ] && printf '%s\n' "$added_here" | sed 's|^|       added in the same range: |'
    echo "    Deleting a template is not a hardcoding, so this does not fail. But git"
    echo "    pairs a rename with an edit only while the two stay similar, so a file"
    echo "    renamed AND rewritten arrives as a delete plus an unrelated add, where"
    echo "    the added path has no base-side count to fall short of. Check by eye."
fi

if [ "$rc2" -eq 1 ]; then
    echo; echo "PLACEHOLDER COUNT: CANNOT CONCLUDE"; exit 2
fi
if [ -n "$bad" ] || [ -n "$stale" ]; then
    # EACH REMEDY GOES WITH ITS OWN FINDING. Printing the hardcoding advice on a
    # stale-only run tells the reader to reverse a transform nobody performed,
    # and sends them looking for a defect that is not there. Two findings, two
    # remedies, neither shown without its cause.
    if [ -n "$bad" ]; then
        echo "  a placeholder was replaced with a concrete value:"
        printf '%s\n' "$bad"
        echo "    skill-sources/ templates are copied into vaults. A concrete name here"
        echo "    ships one user's vocabulary to every future system."
        echo "    See CONTRIBUTING.md 'Two reverse-transforms are mandatory'."
    fi
    if [ -n "$stale" ]; then
        printf '%s\n' "$stale"
        echo "    The allowlist describes a decrease this range no longer shows."
        echo "    Delete the entry — that is the list draining, which is the point of it."
    fi
    fail=1
fi

if [ "$fail" -eq 0 ]; then
    # COUNTED, NOT WRITTEN, and the range is named so a green tick cannot be read
    # as covering a range it never looked at.
    # AN ABSORBED DECREASE MUST BE VISIBLE, AND THE PASS LINE MUST NOT DENY IT.
    # The first version printed only BAD findings and said "no count decreased"
    # regardless — so an allowlisted decrease was reported nowhere and actively
    # contradicted by the summary. That is the unsupportable-label defect this
    # repo has now fixed in skills/help, session-orient.sh, skills/health and
    # check 6's own PASS line; shipping a fifth instance inside a gate written to
    # stop exactly this would be the joke telling itself.
    absorbed=$(printf '%s\n' "$findings" | /usr/bin/grep '^OK ' | sed 's/^OK /  /' || true)
    n_absorbed=$(printf '%s\n' "$absorbed" | /usr/bin/grep -c . || true)
    [ -n "$absorbed" ] && printf '%s\n' "$absorbed"
    if [ "${n_changed:-0}" -eq 0 ]; then
        echo "  PASS no skill-sources/ templates changed since the merge base with $BASE ($MB) — nothing to check"
    elif [ "${n_absorbed:-0}" -gt 0 ]; then
        echo "  PASS $n_changed template(s) changed since the merge base with $BASE ($MB); $n_absorbed decrease(s) allowlisted, none unexplained"
    else
        echo "  PASS $n_changed template(s) changed since the merge base with $BASE ($MB), no count decreased"
    fi
    echo; echo "PLACEHOLDER COUNT: PASS"; exit 0
fi
echo; echo "PLACEHOLDER COUNT: FAIL"; exit 1
