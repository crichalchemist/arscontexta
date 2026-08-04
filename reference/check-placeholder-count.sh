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
# three-family pattern reported 27 -> 21 on the same tree. This script is now the
# single definition and CONTRIBUTING.md points at it.
#
# Do NOT widen to a bare `{…}`: that also matches ${TARGET} and ${FILE}, turning
# a shell-variable count into a placeholder count. skill-authoring.md §2 says so.
PLACEHOLDER_PAT='{vocabulary\.[a-z_]*}\|{config\.[a-z_]*}\|{DOMAIN:[^}]*}'
#
# SCOPE IS skill-sources/ ONLY, and both exclusions are deliberate:
#   * generators/features/*.md carry {DOMAIN:*} too (15 files), but they are
#     composition blocks SELECTED by configuration, not templates copied verbatim.
#     CLAUDE.md records that changing what they emit is a design decision. A gate
#     that fires on a legitimate generator edit gets deleted, not fixed.
#   * platforms/shared/skill-blocks/ holds the repo's densest markup — 146 in
#     `verify` where skill-sources has 27 — but it is FROZEN by check-portability.sh
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
# Empty today: no legitimate decrease has occurred. That is the honest state, and
# an empty list must not be mistaken for an absent mechanism, so the staleness
# half runs over it either way.
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
# test. A ref can exist locally while its history does not: in a depth-1 clone
# rev-parse succeeds, `git show "$BASE:$f"` then returns EMPTY, that reads as
# was=0, and `now >= 0` is true for every file — a silent PASS on the whole diff.
# actions/checkout defaults to depth 1, so that is the DEFAULT CI state, not an
# edge case. merge-base is the test that fails there.
if ! git rev-parse --verify "$BASE" >/dev/null 2>&1; then
    die2 "base ref '$BASE' does not resolve — pass a ref that exists (CI needs fetch-depth: 0)"
elif ! git merge-base "$BASE" HEAD >/dev/null 2>&1; then
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
changed=$(git diff --name-only -z "$BASE"..HEAD 2>/dev/null | tr '\0' '\n' | /usr/bin/grep '^skill-sources/' || true)
n_changed=$(printf '%s\n' "$changed" | /usr/bin/grep -c . || true)

findings=""
if [ "${n_changed:-0}" -gt 0 ]; then
    findings=$(printf '%s\n' "$changed" | while IFS= read -r f; do
        [ -n "$f" ] || continue
        # A file DELETED in this range has no current count; that is a removal,
        # not a hardcoding, and is out of this gate's scope.
        [ -f "$f" ] || continue
        now=$(count_markers < "$f")
        # A file ADDED in this range does not exist at base. That is legitimately
        # was=0, and must not be confused with `git show` failing — which is why
        # existence is tested separately rather than inferred from empty output.
        if git cat-file -e "$BASE:$f" 2>/dev/null; then
            if ! was_raw=$(git show "$BASE:$f" 2>/dev/null); then
                printf 'ERR git show failed for %s at %s\n' "$f" "$BASE"
                continue
            fi
            was=$(printf '%s' "$was_raw" | count_markers)
        else
            was=0
        fi
        [ "$now" -lt "$was" ] || continue
        entry=$(allow_entry_for "$f" "$was" "$now")
        if [ -n "$entry" ]; then
            printf 'OK  allowlisted decrease %s (%s -> %s)\n' "$f" "$was" "$now"
        else
            printf 'BAD HARDCODED A PLACEHOLDER: %s (%s -> %s)\n' "$f" "$was" "$now"
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

# THE OTHER DIRECTION. Without it the list rots rather than drains: a decrease
# corrected in a later commit leaves its entry behind, and the next reader treats
# a closed defect as a standing exception.
stale=$(printf '%s\n' "$PLACEHOLDER_ALLOW" | while IFS= read -r e; do
    [ -n "$e" ] || continue
    epath=$(printf '%s' "$e" | cut -d' ' -f1)
    ecount=$(printf '%s' "$e" | cut -d' ' -f2)
    printf '%s\n' "$findings" | /usr/bin/grep -qF "allowlisted decrease $epath (${ecount%%->*} -> ${ecount##*->})" \
        || printf '  STALE allowlist entry no longer matches the tree: %s %s\n' "$epath" "$ecount"
done)

if [ "$rc2" -eq 1 ]; then
    echo; echo "PLACEHOLDER COUNT: CANNOT CONCLUDE"; exit 2
fi
if [ -n "$bad" ] || [ -n "$stale" ]; then
    [ -n "$bad" ] && { echo "  a placeholder was replaced with a concrete value:"; printf '%s\n' "$bad"; }
    [ -n "$stale" ] && printf '%s\n' "$stale"
    echo "    skill-sources/ templates are copied into vaults. A concrete name here"
    echo "    ships one user's vocabulary to every future system."
    echo "    See CONTRIBUTING.md 'Two reverse-transforms are mandatory'."
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
        echo "  PASS no skill-sources/ templates in $BASE..HEAD — nothing to check"
    elif [ "${n_absorbed:-0}" -gt 0 ]; then
        echo "  PASS $n_changed template(s) changed in $BASE..HEAD; $n_absorbed decrease(s) allowlisted, none unexplained"
    else
        echo "  PASS $n_changed template(s) changed in $BASE..HEAD, no count decreased"
    fi
    echo; echo "PLACEHOLDER COUNT: PASS"; exit 0
fi
echo; echo "PLACEHOLDER COUNT: FAIL"; exit 1
