#!/usr/bin/env bash
# check-doc-claims.sh — do the numbers our own documents state still match reality?
#
# WHAT THIS CHECKS, AND WHAT IT DOES NOT. This repo's documents quote counts —
# suite totals, CI step counts — and those counts rot the moment anything moves.
# The rot is invisible: nobody reads a prose numeral as a claim to verify, so
# "There are nine executable checks" sat three lines above "seven" for a whole
# branch without either being noticed.
#
# SCOPE IS DELIBERATELY NARROW, AND THE BANNER SAYS SO ON EVERY RUN:
#   * DECLARED CLAIMS ONLY. The CLAIMS table below is a stated list, not a
#     discovery scan. A number this file does not name is not checked, and a
#     green run is NOT evidence that every number in every document is right.
#   * BASH-RUN TOTALS ONLY. Suite totals are taken under bash. A suite that
#     passes under bash and forks under zsh is this repo's most-shipped defect
#     class, and this gate does not see it -- the per-suite CI steps do.
#
# The narrowness is the point. A gate whose green is read as the broader claim
# is worse than no gate, which is the failure this repo documents most often.
#
# EXIT CODES, THREE STATES NOT TWO:
#   0  every declared claim matches
#   1  a claim disagrees with reality  -- the document is stale, fix the document
#   2  a claim could not be evaluated  -- the ANCHOR moved (document reworded,
#      claim deleted) or a truth source would not run. NOT the same as clean, and
#      emphatically not the same as a mismatch: rc 2 means this gate does not know.
#
# rc 2 exists because "the scan found nothing" and "the scan could not run" are
# different facts. This repo has twice shipped a scan that matched nothing and
# reported green.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT" || { echo "check-doc-claims: cannot cd to repo root '$ROOT'" >&2; exit 2; }

RC=0
mismatches=0
errors=0

echo "=== check-doc-claims ==="
echo "property: numbers our documents DECLARE still match what the tree measures"
echo "scope:    DECLARED CLAIMS ONLY (the table in this file), BASH-RUN TOTALS ONLY"
echo "NOT checked: any number not listed here; zsh-run totals; whether a number is"
echo "             meaningful -- only whether it is current"
echo

# --- truth sources ----------------------------------------------------------
# Each prints one bare number on stdout, or nothing at all on failure. Printing
# nothing is load-bearing: the caller turns an empty truth into rc 2 rather than
# comparing against an empty string, which would silently equal a failed extract.

truth_suite() {   # truth_suite <suite-basename> -> passed=N
    local f="reference/test/$1.test.sh"
    [ -r "$f" ] || return 1
    bash "$f" 2>/dev/null | tr ' ' '\n' | sed -n 's/^passed=\([0-9][0-9]*\)$/\1/p' | tail -1
}

truth_ci_steps() {
    # Count step ITEMS, not `name:` keys. `actions/checkout` carries no name:,
    # so `grep -c '^      - name:'` returns one fewer and reads as plausible.
    [ -r .github/workflows/checks.yml ] || return 1
    grep -c '^      - ' .github/workflows/checks.yml
}

truth_check_files() {
    ls reference/check-*.sh reference/test/*.test.sh reference/validate-kernel.sh 2>/dev/null \
        | grep -c .
}

truth_ci_steps_main() {
    # A claim about `main` rots on MERGE, not on edit -- nothing in the working
    # tree changes when a branch lands, so the number goes stale with no diff to
    # notice. That is exactly how "14 on main" survived its own branch merging
    # four more steps into main. Skipped rather than failed off-main-having
    # clones: absent `main` is a could-not-run, not a mismatch.
    git rev-parse --verify main >/dev/null 2>&1 || return 1
    git show main:.github/workflows/checks.yml 2>/dev/null | grep -c '^      - '
}

# --- the declared claim table ----------------------------------------------
# One row per claim:  <file>|<label>|<sed extract producing the CLAIMED number>|<truth fn>
#
# The extract must yield exactly the number the document states. If it yields
# nothing, the anchor moved -> rc 2. If it yields several, they must agree with
# each other AND with truth; a document stating one number twice and updating
# only one copy is precisely the drift this gate exists to catch.
# EACH SUITE ROW MUST NAME ITS SUITE IN THE EXTRACT. A bare
# `s/.*passed=\([0-9]*\) failed=0.*/\1/p` matches EVERY suite's expectation line
# in the document. Today it happens to work only because two suites both state
# 19; the moment they legitimately differ, the extract yields two values and this
# gate reports "document states 2 DIFFERENT values" -- a false mismatch on a
# correct document. link-extraction is listed too, and is CURRENTLY CORRECT on
# purpose: it is the positive control proving these rows can come back ok rather
# than the gate simply firing on everything.
CLAIMS='CONTRIBUTING.md|guard-failure suite total|s/.*guard-failure.*passed=\([0-9][0-9]*\) failed=0.*/\1/p|truth_suite guard-failure
CONTRIBUTING.md|link-extraction suite total|s/.*link-extraction.*passed=\([0-9][0-9]*\) failed=0.*/\1/p|truth_suite link-extraction
CLAUDE.md|CI step items (this branch)|s/^grep -c .\^      - . \.github\/workflows\/checks\.yml *# *\([0-9][0-9]*\).*/\1/p|truth_ci_steps
CLAUDE.md|executable check count|s/^ls reference\/check-\*\.sh .* # *\([0-9][0-9]*\).*/\1/p|truth_check_files
CLAUDE.md|CI step items (main)|s/^git show main:\.github\/workflows\/checks\.yml.* # *\([0-9][0-9]*\).*/\1/p|truth_ci_steps_main'

while IFS='|' read -r file label extract truthfn; do
    [ -n "${file:-}" ] || continue
    printf '  %-28s %-34s ' "$file" "$label"

    if [ ! -r "$file" ]; then
        echo "ERROR  file not readable"
        errors=$((errors + 1)); continue
    fi

    claimed=$(sed -n "$extract" "$file" | sort -u)
    n_claimed=$(printf '%s\n' "$claimed" | grep -c . || true)

    if [ "$n_claimed" -eq 0 ]; then
        echo "ERROR  claim anchor not found -- document reworded, or claim removed"
        errors=$((errors + 1)); continue
    fi
    if [ "$n_claimed" -gt 1 ]; then
        echo "MISMATCH  document states $n_claimed DIFFERENT values: $(printf '%s' "$claimed" | tr '\n' ' ')"
        mismatches=$((mismatches + 1)); continue
    fi

    actual=$($truthfn 2>/dev/null)
    if [ -z "${actual:-}" ]; then
        echo "ERROR  truth source '$truthfn' produced nothing"
        errors=$((errors + 1)); continue
    fi

    if [ "$claimed" = "$actual" ]; then
        echo "ok     $claimed"
    else
        echo "MISMATCH  document says $claimed, tree measures $actual"
        mismatches=$((mismatches + 1))
    fi
done <<EOF
$CLAIMS
EOF

# --- divergence-number uniqueness -------------------------------------------
# SCOPED TO THE DIVERGENCE LIST, NOT THE WHOLE FILE, and that scoping is the
# whole correctness of this sub-check. CLAUDE.md carries at least two unrelated
# bold-numbered lists -- `## Architecture: three generation paths` numbers 1..3,
# and `## Known open divergences` numbers 1..13. An unscoped `^\*\*[0-9]+\.`
# extraction reports 1, 2 and 3 as duplicates ON A CLEAN TREE. A gate that fires
# on correct documents gets deleted rather than fixed.
#
# A GAP IS NOT A DEFECT. The list legitimately skips numbers when entries are
# collapsed (8 and 9 folded into 7) or closed. Only a REPEATED number is a
# defect, because entries are cross-referenced by number and two entries sharing
# one makes every reference to it ambiguous.
printf '  %-28s %-34s ' "CLAUDE.md" "divergence numbers unique"
if [ ! -r CLAUDE.md ]; then
    echo "ERROR  CLAUDE.md not readable"; errors=$((errors + 1))
else
    section=$(awk '/^## Known open divergences/{f=1;next} f&&/^## /{exit} f' CLAUDE.md)
    nums=$(printf '%s\n' "$section" | sed -n 's/^\*\*\([0-9][0-9]*\)[.,].*/\1/p')
    n_nums=$(printf '%s\n' "$nums" | grep -c . || true)
    if [ "$n_nums" -eq 0 ]; then
        echo "ERROR  zero divergence headers extracted -- the section heading or the"
        echo "         '**N.' header form changed. The extractor is broken, not the list clean."
        errors=$((errors + 1))
    else
        dupes=$(printf '%s\n' "$nums" | sort -n | uniq -d)
        if [ -n "$dupes" ]; then
            echo "MISMATCH  repeated: $(printf '%s' "$dupes" | tr '\n' ' ')"
            mismatches=$((mismatches + 1))
        else
            echo "ok     $n_nums entries, all distinct"
        fi
    fi
fi

echo
[ "$mismatches" -gt 0 ] && RC=1
[ "$errors" -gt 0 ] && RC=2      # could-not-run outranks mismatch: an unevaluated
                                 # claim means this gate does not know its own scope
if [ "$RC" -eq 0 ]; then
    echo "DOC CLAIMS: PASS (declared claims only -- bash-run totals only)"
elif [ "$RC" -eq 1 ]; then
    echo "DOC CLAIMS: FAIL -- $mismatches stale claim(s). Fix the document, not the gate."
else
    echo "DOC CLAIMS: ERROR -- $errors claim(s) could not be evaluated ($mismatches mismatch(es) also seen)."
    echo "  This is NOT a clean run. An anchor that moved means the claim is unchecked."
fi
exit "$RC"
