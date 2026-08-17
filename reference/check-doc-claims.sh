#!/usr/bin/env bash
# check-doc-claims.sh — do the numbers our own documents state still match reality?
#
# WHAT THIS CHECKS, AND WHAT IT DOES NOT. This repo's documents quote counts —
# suite totals, CI step counts, check inventories — and those counts rot the
# moment anything moves. The rot is invisible: nobody reads a prose numeral as a
# claim to verify, so "There are nine executable checks" sat three lines above
# "seven" for a whole branch without either being noticed.
#
# SCOPE IS DELIBERATELY NARROW, AND THE BANNER SAYS SO ON EVERY RUN:
#   * DECLARED CLAIMS ONLY. The CLAIMS table below is a stated list, not a
#     discovery scan. A number this file does not name is not checked, and a
#     green run is NOT evidence that every number in every document is right.
#   * BASH-RUN TOTALS ONLY. Suite totals are taken under bash. A suite that
#     passes under bash and forks under zsh is this repo's most-shipped defect
#     class, and this gate does not see it — the per-suite CI steps do.
#
# The narrowness is the point. A gate whose green is read as the broader claim
# is worse than no gate, which is the failure this repo documents most often.
#
# WHY THE SCRIPT ITSELF RUNS UNDER BOTH SHELLS EVEN THOUGH ITS TOTALS ARE
# BASH-RUN. Those are two different claims and conflating them shipped a defect
# here: the first version stored "fn arg" in one field and called $truthfn
# unquoted, which bash word-splits and zsh does not, so `zsh check-doc-claims.sh`
# exited 2 with two rows unevaluated while bash exited 0. The file is executable
# and carries a shebang, so nothing stops a contributor typing `zsh` in front of
# it — exactly how `bump-version.sh` acquired its own zsh fork. The table now
# carries the argument in its own field and every call is quoted.
#
# EXIT CODES, THREE STATES NOT TWO:
#   0  every declared claim matches
#   1  a claim disagrees with reality  — the document is stale, fix the document
#   2  a claim could not be evaluated  — the ANCHOR moved (document reworded,
#      claim deleted), or a truth source would not run. NOT the same as clean,
#      and emphatically not the same as a mismatch: rc 2 means this gate does
#      not know. It outranks rc 1 for that reason.
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
echo "             meaningful — only whether it is current"
echo

# --- truth sources ----------------------------------------------------------
# Each prints one bare number on stdout, or NOTHING on failure. Printing nothing
# is load-bearing: the caller turns an empty truth into rc 2 rather than
# comparing against an empty string, which would silently equal a failed extract.
# Every one of them guards its input and returns 1 — a missing file is a
# could-not-run, never a mismatch. (truth_check_files lacked that guard and
# reported "document says 10, tree measures 4" when run from the wrong root.)

truth_suite() {   # truth_suite <suite-basename> -> passed count, ONLY if failed=0
    local f="reference/test/$1.test.sh" line passed failed
    [ -r "$f" ] || return 1
    line=$(bash "$f" 2>/dev/null | tail -1)
    # TWO TOTAL FORMATS EXIST IN THIS REPO. Most suites print
    # `passed=N failed=M`; threshold-namespace prints `NAME: N passed, M failed`.
    # Handling only the first yields an empty passed for the second, which this
    # gate would report as a could-not-run on a perfectly healthy suite.
    passed=$(printf '%s' "$line" | sed -n 's/.*passed=\([0-9][0-9]*\).*/\1/p')
    failed=$(printf '%s' "$line" | sed -n 's/.*failed=\([0-9][0-9]*\).*/\1/p')
    [ -n "$passed" ] || passed=$(printf '%s' "$line" | sed -n 's/.*[: ]\([0-9][0-9]*\) passed,.*/\1/p')
    [ -n "$failed" ] || failed=$(printf '%s' "$line" | sed -n 's/.*, \([0-9][0-9]*\) failed.*/\1/p')
    # THREE TOTAL FORMATS EXIST NOW. vocabulary-schema.test.sh prints a bare
    # `P/T` (passed/total, e.g. `12/12` -- a shape example, not a live claim;
    # re-derive the real count rather than trusting this comment), added after
    # this comment described "two" -- sed alone cannot compute failed = total
    # minus passed, so this branch
    # captures both numbers and derives it in the shell rather than matching a
    # failed=N group that does not exist in this format.
    if [ -z "$passed" ]; then
        local p_slash t_slash
        p_slash=$(printf '%s' "$line" | sed -n 's/^\([0-9][0-9]*\)\/[0-9][0-9]*$/\1/p')
        t_slash=$(printf '%s' "$line" | sed -n 's/^[0-9][0-9]*\/\([0-9][0-9]*\)$/\1/p')
        if [ -n "$p_slash" ] && [ -n "$t_slash" ]; then
            passed="$p_slash"
            failed=$((t_slash - p_slash))
        fi
    fi
    [ -n "$passed" ] || return 1
    # A FAILING SUITE MUST NOT PRODUCE A TRUTH VALUE. The extract anchors on
    # `failed=0` in the document but nothing asserted the tree agreed, so a suite
    # at `passed=34 failed=1` returned 34 and this gate printed `ok`, vouching for
    # a red suite. Worse at `passed=33 failed=1`: it reported "document says 34,
    # tree measures 33 — fix the document", which would have encoded a regression
    # into CONTRIBUTING.md as though it were the new expectation.
    [ "${failed:-0}" = "0" ] || { echo "SUITE_FAILING:$line"; return 0; }
    printf '%s' "$passed"
}

truth_ci_steps() {
    local _n
    # Count step ITEMS, not `name:` keys. `actions/checkout` carries no name:,
    # so `grep -c '^      - name:'` returns one fewer and reads as plausible.
    [ -r .github/workflows/checks.yml ] || return 1
    _n=$(grep -c '^      - ' .github/workflows/checks.yml || true)
    # Zero step ITEMS means checks.yml was restructured or truncated, not that
    # CI has no steps. `grep -c` prints 0 and returns 1; reported as an answer it
    # would instruct 0 into the documents.
    [ "${_n:-0}" -gt 0 ] || return 1
    printf '%s' "$_n"
}

truth_ci_steps_main() {
    local _n
    # A claim about `main` rots on MERGE, not on edit — nothing in the working
    # tree changes when a branch lands, so the number goes stale with no diff to
    # notice. That is exactly how "14 on main" survived its own branch merging
    # four more steps into main. Absent `main` is a could-not-run, not a mismatch.
    # RESOLVE main, DO NOT ASSUME A LOCAL BRANCH. actions/checkout creates no
    # local `main` when it checks out a feature branch, so this returned nothing
    # and the gate exited 2 on every CI run of every branch — measured in a
    # CI-shaped clone, and invisible locally where `main` always exists. The
    # placeholder gate beside it already spells `origin/main` for this reason.
    local _ref=""
    for _c in main origin/main refs/remotes/origin/main; do
        git rev-parse --verify "$_c" >/dev/null 2>&1 && { _ref="$_c"; break; }
    done
    [ -n "$_ref" ] || return 1
    _n=$(git show "$_ref:.github/workflows/checks.yml" 2>/dev/null | grep -c '^      - ' || true)
    # Zero here means main's workflow could not be read or has no steps -- a
    # could-not-run. Reporting it as 0 produced "document says 18, tree measures
    # 0 -- fix the document", instructing a wrong number into CLAUDE.md.
    [ "${_n:-0}" -gt 0 ] || return 1
    printf '%s' "$_n"
}

truth_check_files() {
    local _n
    [ -d reference/test ] || return 1
    _n=$(ls reference/check-*.sh reference/test/*.test.sh reference/validate-kernel.sh 2>/dev/null  | grep -c . || true)
    # Zero files means the glob matched nothing -- wrong cwd, or a moved
    # reference/ tree. It is never a true inventory of zero, since this script
    # is itself one of the files being counted.
    [ "${_n:-0}" -gt 0 ] || return 1
    printf '%s' "$_n"
}

# The NUMBERED checks inside check-portability.sh, which is a different quantity
# from truth_check_files above: that counts gate FILES, this counts checks within
# one file. Five prose sites enumerate them, four of which sat at "five checks"
# after a sixth shipped — including reference/lib/link-extraction.sh and
# reference/lib/frontmatter.sh, whose headers name each check individually, and
# skill-sources/next/SKILL.md, which is a template that ships into vaults.
#
# Anchored on `^echo "<n>. `, the form every check header uses, so adding a check
# updates this without anyone remembering to. A count of zero means the anchor
# moved, not that the guard lost its checks.
# Test SUITES named in CLAUDE.md's verification fence — a different quantity from
# truth_check_files (which counts every gate FILE, standalone checks included).
# The prose "the N test suites each run under both shells" went stale twice
# without anyone noticing, because no claim row read it.
truth_fence_suites() {
    local _n
    [ -r CLAUDE.md ] || return 1
    _n=$(awk '/^for s in bash zsh; do/,/^done/' CLAUDE.md | /usr/bin/grep -c 'test\.sh' || true)
    [ "${_n:-0}" -gt 0 ] || return 1
    printf '%s' "$_n"
}

# Kernel primitives declared in kernel.yaml. Counted because both README.md and
# CLAUDE.md said 15 for a tree that declares 16 — `unique-addresses` is a full
# primitive that validate-kernel.sh numbers `10A` rather than renumbering, so the
# highest LABEL is 15 and the COUNT is 16, and the label was read as the total.
truth_kernel_primitives() {
    local _n
    [ -r reference/kernel.yaml ] || return 1
    _n=$(/usr/bin/grep -c '^  - id:' reference/kernel.yaml || true)
    [ "${_n:-0}" -gt 0 ] || return 1
    printf '%s' "$_n"
}

# check 7's allowlist totals. Ungated, these drift the moment an entry drains —
# the check goes green at 73/24 while CLAUDE.md still says 74/25. Global
# constraint: gate every number you mint, in the commit that mints it.
truth_fm_sites() {
    local _n
    [ -f reference/check-portability.sh ] || return 1
    _n=$(awk '/^FM_ALLOW="/{f=1;next} f&&/^"/{exit} f&&NF{s+=$2} END{print s+0}' \
           reference/check-portability.sh)
    [ "${_n:-0}" -gt 0 ] || return 1
    printf '%s' "$_n"
}
# truth_fm_files counts the allowlisted frontmatter files in reference/check-portability.sh and fails if the file or allowlist is missing or empty.
truth_fm_files() {
    local _n
    [ -f reference/check-portability.sh ] || return 1
    _n=$(awk '/^FM_ALLOW="/{f=1;next} f&&/^"/{exit} f&&NF{c++} END{print c+0}' \
           reference/check-portability.sh)
    [ "${_n:-0}" -gt 0 ] || return 1
    printf '%s' "$_n"
}

# truth_portability_checks counts numbered portability checks in the repository portability-check script.
truth_portability_checks() {
    local _n
    [ -f reference/check-portability.sh ] || return 1
    _n=$(/usr/bin/grep -cE '^echo "[0-9]+\. ' reference/check-portability.sh || true)
    [ "${_n:-0}" -gt 0 ] || return 1
    printf '%s' "$_n"
}

# Divergence 12's matcher-site count -- the number this branch itself ratcheted
# 10 -> 12 by adding check 6 and its coverage, because the published command had
# no exemption and was counting the gate's own text. Gating it is the point: a
# count that moves when someone DOCUMENTS the subject is measuring documentation.
#
# The exclusion is directory-anchored, not a basename match. `grep -r` emits a
# doubled slash, which `/+` absorbs; a basename form silently drops a real hit in
# any file named to resemble a gate, which is the one-rename evasion
# check-portability.sh's own header rejects for --exclude.
truth_divergence12_matchers() {
    local _n
    [ -d skill-sources ] && [ -d reference ] || return 1
    _n=$(/usr/bin/grep -rnE '(grep|rg)[^|]*\\\[\\\[.*\\\]\\\]' \
           skill-sources/ skills/ platforms/claude-code/ reference/ 2>/dev/null \
         | /usr/bin/grep -Ev 'reference/+(check-portability\.sh|test/guard-failure\.test\.sh):' \
         | /usr/bin/grep -c . || true)
    # Zero means the scan broke, never that the class is gone -- the allowlisted
    # sites are load-bearing and deliberately unconverted.
    [ "${_n:-0}" -gt 0 ] || return 1
    printf '%s' "$_n"
}

truth_ci_run_checks() {
    local _n
    # Checks CI actually EXECUTES — distinct from checks that merely APPEAR in
    # the workflow. `validate-kernel.sh` is named there only under `bash -n`, and
    # a grep for its name counts that mention as a run. This session made exactly
    # that error before catching it.
    [ -r .github/workflows/checks.yml ] || return 1
    _n=$(grep -oE 'run: (bash|zsh) reference/(check-[a-z-]+\.sh|test/[a-z-]+\.test\.sh|validate-kernel\.sh)'  .github/workflows/checks.yml | sed 's/.*reference\///' | sort -u | grep -c . || true)
    # Zero means the workflow no longer spells its runs as one-line
    # `run: <shell> reference/...` -- a `run: |` block scalar or a matrix, both
    # shapes checks.yml already uses elsewhere. The checks still run; only this
    # pattern stopped seeing them, which is a could-not-run, not a count of 0.
    [ "${_n:-0}" -gt 0 ] || return 1
    printf '%s' "$_n"
}

# word2num — documents state small counts as English words ("run all ten",
# "Nine run in CI", "all nineteen CI steps"). Two of the five stale claims this
# gate was built from were in word form, and correcting them into ungated prose
# would have left half the found defects free to re-rot.
word2num() {
    case "$1" in
        one) echo 1;; two) echo 2;; three) echo 3;; four) echo 4;; five) echo 5;;
        six) echo 6;; seven) echo 7;; eight) echo 8;; nine) echo 9;; ten) echo 10;;
        eleven) echo 11;; twelve) echo 12;; thirteen) echo 13;; fourteen) echo 14;;
        fifteen) echo 15;; sixteen) echo 16;; seventeen) echo 17;; eighteen) echo 18;;
        nineteen) echo 19;; twenty) echo 20;;
        # Hyphenated forms, because documents write "all twenty-two CI steps"
        # and a missing entry here is an rc-2 ERROR, not a silent pass — which
        # is right, but it stalls a correct edit until the word is added.
        twenty-one) echo 21;; twenty-two) echo 22;; twenty-three) echo 23;;
        twenty-four) echo 24;; twenty-five) echo 25;; twenty-six) echo 26;;
        twenty-seven) echo 27;; twenty-eight) echo 28;; twenty-nine) echo 29;;
        thirty) echo 30;;
        # The thirties, filled in one go when the CI step count crossed 30, matching
        # how the twenties were filled rather than adding the single word in use. The
        # decade costs nine lines once; adding them one at a time costs an rc-2 ERROR
        # and a second commit every time a step is added.
        thirty-one) echo 31;; thirty-two) echo 32;; thirty-three) echo 33;;
        thirty-four) echo 34;; thirty-five) echo 35;; thirty-six) echo 36;;
        thirty-seven) echo 37;; thirty-eight) echo 38;; thirty-nine) echo 39;;
        *) return 1;;
    esac
}

# --- the declared claim table ----------------------------------------------
# <file>|<label>|<sed extract yielding the CLAIMED value>|<truth fn>|<arg>
#
# The argument lives in its OWN field. Packing "fn arg" into one field and
# calling it unquoted is the zsh fork described in the header.
#
# EACH SUITE ROW MUST NAME ITS SUITE IN THE EXTRACT. A bare
# `s/.*passed=\([0-9]*\).*/\1/p` matches EVERY suite's expectation line in the
# document; the moment two suites legitimately differ it yields two values and
# this gate reports a false mismatch on a correct document. link-extraction is
# listed and is CURRENTLY CORRECT on purpose — it is the positive control
# proving these rows can return ok rather than the gate firing on everything.
#
# `[^#]*` rather than `.*` before ` # ` binds to the FIRST comment marker on the
# line, not the last.
CLAIMS='reference/lib/link-extraction.sh|portability check count (word)|s/.*runs \([a-z][a-z-]*\) checks.*/\1/p|truth_portability_checks|
reference/lib/frontmatter.sh|portability check count (word)|s/.*runs \([a-z][a-z-]*\) checks.*/\1/p|truth_portability_checks|
reference/skill-authoring.md|portability check count (word)|s/.*runs \([a-z][a-z-]*\) checks.*/\1/p|truth_portability_checks|
skill-sources/next/SKILL.md|portability check count (word)|s/.*runs \([a-z][a-z-]*\) checks.*/\1/p|truth_portability_checks|
CLAUDE.md|portability check count (word)|s/.*the \([a-z][a-z-]*\) checks are enumerated above.*/\1/p|truth_portability_checks|
CLAUDE.md|test suites run under both shells (word)|s/.*\*\*the \([a-z][a-z-]*\) test suites each run under both.*/\1/p|truth_fence_suites|
README.md|kernel primitives|s/.*`reference\/kernel\.yaml` -- \([0-9][0-9]*\) primitives.*/\1/p|truth_kernel_primitives|
CLAUDE.md|kernel primitives|s/.*`reference\/kernel\.yaml` declares the \([0-9][0-9]*\) primitives.*/\1/p|truth_kernel_primitives|
CLAUDE.md|divergence 12 matcher sites|s/.*not remembered: \*\*\([0-9][0-9]*\) hits\*\*.*/\1/p|truth_divergence12_matchers|
reference/lib/frontmatter.sh|check-7 allowlist sites (library header)|s/.*born red at \([0-9][0-9]*\) allowlisted sites.*/\1/p|truth_fm_sites|
CLAUDE.md|check-7 allowlist sites|s/.*born red at \([0-9][0-9]*\) sites across.*/\1/p|truth_fm_sites|
CLAUDE.md|check-7 allowlist files|s/.*born red at [0-9][0-9]* sites across \([0-9][0-9]*\) files.*/\1/p|truth_fm_files|
CLAUDE.md|portability check count, gate table (word)|s/.*check-portability\.sh[^a-z]*\([a-z][a-z-]*\) checks:.*/\1/p|truth_portability_checks|
CONTRIBUTING.md|guard-failure suite total|s/.*guard-failure.*passed=\([0-9][0-9]*\) failed=0.*/\1/p|truth_suite|guard-failure
CONTRIBUTING.md|link-extraction suite total|s/.*link-extraction.*passed=\([0-9][0-9]*\) failed=0.*/\1/p|truth_suite|link-extraction
CONTRIBUTING.md|bump-version suite total|s/.*bump-version.*passed=\([0-9][0-9]*\) failed=0.*/\1/p|truth_suite|bump-version
CONTRIBUTING.md|kernel-note-dirs suite total|s/.*kernel-note-dirs.*passed=\([0-9][0-9]*\) failed=0.*/\1/p|truth_suite|kernel-note-dirs
CONTRIBUTING.md|threshold-namespace suite total|s/.*threshold-namespace.*expect: \([0-9][0-9]*\) passed,.*/\1/p|truth_suite|threshold-namespace
CONTRIBUTING.md|placeholder-count suite total|s/.*placeholder-count.*passed=\([0-9][0-9]*\) failed=0.*/\1/p|truth_suite|placeholder-count
CONTRIBUTING.md|hook-config suite total|s/.*hook-config.*passed=\([0-9][0-9]*\) failed=0.*/\1/p|truth_suite|hook-config
CONTRIBUTING.md|vocabulary-schema suite total|s/.*vocabulary-schema.*# expect: \([0-9][0-9]*\)\/[0-9][0-9]*.*/\1/p|truth_suite|vocabulary-schema
CONTRIBUTING.md|CI step count (word form)|s/.*[Aa]ll \([a-z][a-z-]*\) CI steps must pass.*/\1/p|truth_ci_steps|
CONTRIBUTING.md|CI step count, green (word)|s/.*means all \([a-z][a-z-]*\) CI steps ran.*/\1/p|truth_ci_steps|
CONTRIBUTING.md|check inventory (word form)|s/^## Verification — run all \([a-z][a-z-]*\),.*/\1/p|truth_check_files|
CONTRIBUTING.md|checks in CI (word form)|s/^\([A-Z][a-z]*\) run in CI on every push.*/\1/p|truth_ci_run_checks|
CLAUDE.md|check inventory (word form)|s/^There are \([a-z][a-z-]*\) executable checks\..*/\1/p|truth_check_files|
CLAUDE.md|checks in CI (word form)|s/^There are [a-z]* executable checks\. \([A-Z][a-z]*\) run in CI.*/\1/p|truth_ci_run_checks|
CLAUDE.md|CI step items (this branch)|s/^grep -c .\^      - . \.github\/workflows\/checks\.yml[^#]*# *\([0-9][0-9]*\).*/\1/p|truth_ci_steps|
CLAUDE.md|link-extraction fence total|s/^ *\$s reference\/test\/link-extraction\.test\.sh[^#]*# *\([0-9][0-9]*\)\/[0-9][0-9]*.*/\1/p|truth_suite|link-extraction
CLAUDE.md|guard-failure fence total|s/^ *\$s reference\/test\/guard-failure\.test\.sh[^#]*# *\([0-9][0-9]*\)\/[0-9][0-9]*.*/\1/p|truth_suite|guard-failure
CLAUDE.md|bump-version fence total|s/^ *\$s reference\/test\/bump-version\.test\.sh[^#]*# *\([0-9][0-9]*\)\/[0-9][0-9]*.*/\1/p|truth_suite|bump-version
CLAUDE.md|kernel-note-dirs fence total|s/^ *\$s reference\/test\/kernel-note-dirs\.test\.sh[^#]*# *\([0-9][0-9]*\)\/[0-9][0-9]*.*/\1/p|truth_suite|kernel-note-dirs
CLAUDE.md|threshold-namespace fence total|s/^ *\$s reference\/test\/threshold-namespace\.test\.sh[^#]*# *\([0-9][0-9]*\)\/[0-9][0-9]*.*/\1/p|truth_suite|threshold-namespace
CLAUDE.md|placeholder-count fence total|s/^ *\$s reference\/test\/placeholder-count\.test\.sh[^#]*# *\([0-9][0-9]*\)\/[0-9][0-9]*.*/\1/p|truth_suite|placeholder-count
CLAUDE.md|hook-config fence total|s/^ *\$s reference\/test\/hook-config\.test\.sh[^#]*# *\([0-9][0-9]*\)\/[0-9][0-9]*.*/\1/p|truth_suite|hook-config
CLAUDE.md|vocabulary-schema fence total|s/^ *\$s reference\/test\/vocabulary-schema\.test\.sh[^#]*# *\([0-9][0-9]*\)\/[0-9][0-9]*.*/\1/p|truth_suite|vocabulary-schema
CLAUDE.md|executable check count|s/^ls reference\/check-\*\.sh [^#]*# *\([0-9][0-9]*\).*/\1/p|truth_check_files|'

while IFS='|' read -r file label extract truthfn arg; do
    [ -n "${file:-}" ] || continue
    printf '  %-18s %-30s ' "$file" "$label"

    if [ ! -r "$file" ]; then
        echo "ERROR  file not readable"
        errors=$((errors + 1)); continue
    fi

    claimed=$(sed -n "$extract" "$file" | sort -u)
    n_claimed=$(printf '%s\n' "$claimed" | grep -c . || true)

    if [ "$n_claimed" -eq 0 ]; then
        echo "ERROR  claim anchor not found — document reworded, or claim removed"
        errors=$((errors + 1)); continue
    fi
    if [ "$n_claimed" -gt 1 ]; then
        echo "MISMATCH  document states $n_claimed DIFFERENT values: $(printf '%s' "$claimed" | tr '\n' ' ')"
        mismatches=$((mismatches + 1)); continue
    fi

    # word form -> number, so "all nineteen CI steps" is gated like `# 19`
    case "$claimed" in
        [0-9]*) claimed_n="$claimed" ;;
        *) claimed_n=$(word2num "$(printf '%s' "$claimed" | tr '[:upper:]' '[:lower:]')") || {
               echo "ERROR  claimed value '$claimed' is neither a number nor a known number-word"
               errors=$((errors + 1)); continue
           } ;;
    esac

    if [ -n "$arg" ]; then actual=$("$truthfn" "$arg" 2>/dev/null); else actual=$("$truthfn" 2>/dev/null); fi

    case "${actual:-}" in
        "")
            echo "ERROR  truth source '$truthfn ${arg:-}' produced nothing"
            errors=$((errors + 1)); continue ;;
        SUITE_FAILING:*)
            echo "ERROR  suite is RED (${actual#SUITE_FAILING:}) — a claim about a failing suite cannot be validated"
            errors=$((errors + 1)); continue ;;
    esac

    if [ "$claimed_n" = "$actual" ]; then
        echo "ok     $claimed"
    else
        echo "MISMATCH  document says $claimed, tree measures $actual"
        mismatches=$((mismatches + 1))
    fi
done <<EOF
$CLAIMS
EOF

# --- a stated count must match the LIST it heads ----------------------------
# A count can be current while the list beneath it is short, and then both the
# number and the gate are right and the document is still wrong. "run all ten"
# sat above nine commands, and "There are ten executable checks" above an
# eight-command fence — because the previous pass corrected the numbers without
# touching the lists they introduce. Comparing a number against `ls` can never
# see that; only comparing it against the list can.
check_list_len() {  # <file> <label> <awk program selecting the list> <expected fn>
    local file="$1" label="$2" prog="$3" fn="$4" n expect
    printf '  %-18s %-30s ' "$file" "$label"
    [ -r "$file" ] || { echo "ERROR  file not readable"; errors=$((errors + 1)); return; }
    n=$(awk "$prog" "$file" | grep -c . || true)
    expect=$("$fn" 2>/dev/null)
    if [ -z "${expect:-}" ]; then
        echo "ERROR  truth source '$fn' produced nothing"; errors=$((errors + 1)); return
    fi
    if [ "$n" -eq 0 ]; then
        echo "ERROR  extracted an EMPTY list — the block's shape changed, not the list cleaned"
        errors=$((errors + 1)); return
    fi
    if [ "$n" = "$expect" ]; then
        echo "ok     $n listed"
    else
        echo "MISMATCH  $n listed, $expect exist"
        mismatches=$((mismatches + 1))
    fi
}

check_list_len CONTRIBUTING.md "verification list is complete" \
    '/^## Verification/{f=1} f&&/^```bash/{b=1;next} b&&/^```/{exit} b&&/reference\//' \
    truth_check_files
# CLAUDE.md's fence deliberately OMITS validate-kernel.sh -- it needs a generated
# vault and is documented in its own fence directly below. Comparing this list
# against the raw file count would demand an entry that does not belong here, so
# the expectation is the count minus that one, and the reason is stated rather
# than left as an unexplained -1.
truth_checks_no_vault() { local n; n=$(truth_check_files) || return 1; echo $((n - 1)); }
check_list_len CLAUDE.md "verification fence is complete" \
    '/^bash reference\/check-portability/{f=1} f&&/^```/{exit} f&&/reference\//' \
    truth_checks_no_vault

# --- divergence-number uniqueness -------------------------------------------
# SCOPED TO THE DIVERGENCE LIST, NOT THE WHOLE FILE, and that scoping is the
# whole correctness of this sub-check. CLAUDE.md carries at least two unrelated
# bold-numbered lists — `## Architecture: three generation paths` numbers 1..3,
# and `## Known open divergences` numbers 1..13. An unscoped `^\*\*[0-9]+\.`
# extraction reports 1, 2 and 3 as duplicates ON A CLEAN TREE. A gate that fires
# on correct documents gets deleted rather than fixed.
#
# A GAP IS NOT A DEFECT. The list legitimately skips numbers when entries are
# collapsed (8 and 9 folded into 7) or closed. Only a REPEATED number is a
# defect, because entries are cross-referenced by number and two entries sharing
# one makes every reference ambiguous.
# CI STEPS NEVER REGRESS AGAINST main — A RELATIONSHIP, NOT A DECLARED NUMERAL.
#
# This replaces a CLAIMS row that pinned main's step count as a literal in CLAUDE.md. That
# row was STRUCTURALLY UNSATISFIABLE ACROSS A MERGE: before the merge the document had to
# say 30, after it 32, and nothing in any working tree changes when a branch lands — so the
# PR ran green and main went red the moment it merged, with no diff to notice and no signal
# until main's own CI run. Measured, not predicted: merging this branch into main and
# running this gate produced "document says 30, tree measures 32".
#
# So every branch touching CI owed a follow-up commit to un-redden main. A gate that
# manufactures its own failures trains people to ignore it, which costs more than the drift
# it was built to catch. It also contradicted this file's own governing idiom, which
# CLAUDE.md states a dozen times: re-derive a number, never quote one.
#
# The RELATIONSHIP is stable in both states — 30 <= 32 before, 32 <= 32 after — needs no
# numeral in any document, and cannot rot. It still catches a real defect nothing else here
# sees: a branch that DELETES CI steps. That is strictly more coverage than the numeral had,
# since the numeral only ever detected its own staleness.
printf '  %-18s %-30s ' ".github/" "CI steps vs main"
_ci_tree=$(truth_ci_steps || true)
_ci_main=$(truth_ci_steps_main || true)
if [ -z "$_ci_tree" ]; then
    echo "ERROR  cannot count steps in this tree's checks.yml"
    errors=$((errors + 1))
elif [ -z "$_ci_main" ]; then
    # UNREACHABLE main IS A COULD-NOT-RUN, NOT A PASS. A shallow clone with no main must not
    # read as "steps never regressed" — that is the silent-green this repo's gates exist to
    # refuse, and truth_ci_steps_main already returns 1 rather than 0 for the same reason.
    echo "ERROR  main unreachable — relationship UNCHECKED (not a pass)"
    errors=$((errors + 1))
elif [ "$_ci_main" -gt "$_ci_tree" ]; then
    echo "MISMATCH  main has $_ci_main step(s), this tree has $_ci_tree — CI steps were removed"
    mismatches=$((mismatches + 1))
else
    echo "ok     $_ci_tree here, $_ci_main on main"
fi

printf '  %-18s %-30s ' "CLAUDE.md" "divergence numbers unique"
if [ ! -r CLAUDE.md ]; then
    echo "ERROR  CLAUDE.md not readable"; errors=$((errors + 1))
else
    section=$(awk '/^## Known open divergences/{f=1;next} f&&/^## /{exit} f' CLAUDE.md)
    nums=$(printf '%s\n' "$section" | sed -n 's/^\*\*\([0-9][0-9]*\)[.,].*/\1/p')
    n_nums=$(printf '%s\n' "$nums" | grep -c . || true)
    if [ "$n_nums" -eq 0 ]; then
        echo "ERROR  zero divergence headers extracted — the section heading or the '**N.' form changed"
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

# --- structural: the generator status enums ---------------------------------
# Spec G item 22, deferred there pending Spec F's fix and unbuilt when Spec F
# merged. Divergence 15 records the expectation and that nothing carried it out.
#
# WHICH ENUM THIS COVERS AND WHICH IT CANNOT — the decision, not an omission.
# "The declaring files agree" is not one property, because the three status
# vocabularies are declared different numbers of times:
#   * the NOTE enum is declared FOUR times and must agree with itself
#   * the OBSERVATION enum is declared ONCE (self-evolution.md), so there is
#     nothing for it to agree WITH; cross-declaration agreement is vacuous for it
#   * the TENSION enum is likewise declared once — but it has CONSUMERS, and a
#     consumer that matches a value the enum no longer declares returns zero
#     forever. That is a real coupling and it IS checkable, so the second check
#     below covers it. This is the defect this branch shipped and caught in
#     review: three recipes matched `^status: pending` alone after `pending` was
#     briefly removed from the enum.
#
# FOUR, NOT THREE. Divergence 15 says three FILES, which is true and is not the
# same number: schema.md declares the note enum twice, once in a table and once
# in its _schema block. A file-to-file comparison cannot see those two disagree
# — the same blind spot bump-version.sh had for two fields of one manifest.
#
# WHY THE COUNTS ARE PINNED. Discovery keys on an anchor value (`preliminary`,
# `dissolved`), so a declaration that DROPS the anchor stops being discovered —
# and a split enum is exactly the case where that happens. Three sites left
# agreeing with each other would read PASS. The expected count is therefore
# declared, and a move in EITHER direction is rc 2, not a quiet pass.
#   /usr/bin/grep -rc 'preliminary' generators/ --include='*.md' | grep -v ':0'   # 4 across 3 files
#   /usr/bin/grep -rn 'status:.*dissolved' generators/ --include='*.md'   # 1
#   /usr/bin/grep -rn 'list_notes_by_field.*type tension' generators/ --include='*.md'   # 3
# (The recipe shape moved on fix/spec-h-enforcement-gap from an inline
# `status: (pending|open)` to a list_notes_by_field call whose FOLLOWING line
# names the values via `[ "$s" = "..." ]`. The anchor above tracks the new
# shape; TENSION_RECIPES itself is unchanged, since the same 3 sites moved.)
#
# TENSION_ENUM_DECLS EXISTS FOR THE SAME REASON NOTE_ENUM_DECLS DOES, added
# because the tension enum's own count guard didn't. Before this pin, `tenum`
# was read with `| head -1` and no declaration count check at all — a SECOND
# `status:...dissolved` line anywhere in generators/ would be silently and
# arbitrarily chosen between, with no signal that a choice had even been made.
# Reproduced directly: with a decoy second declaration present, `head -1`
# picked the decoy over the real enum, and the check reported a MISMATCH
# blaming the wrong cause (`pending`/`open` "not declared") rather than
# surfacing the actual defect (two declarations, an arbitrary pick).
NOTE_ENUM_DECLS=4
TENSION_RECIPES=3
TENSION_ENUM_DECLS=1

# Normalisation is two rules and no vocabulary: take everything after `enum` if
# the line has it (the table row), else after `status`, then drop punctuation.
# The value set is compared, never the text — the four sites legitimately spell
# the same enum three ways (`a | b`, `[a, b]`, and backticked table cells), so a
# textual diff reports a split that is not there.
enum_values() { sed 's/.*enum//' | sed 's/.*status[`:]*//' | tr -d '`|,[]' \
                | tr -s ' ' | sed 's/^ *//;s/ *$//' | tr ' ' '\n' | grep -v '^$' | LC_ALL=C sort -u; }

printf '  %-18s %-30s ' "generators/" "note status enum agrees"
decls=$(/usr/bin/grep -rn 'preliminary' generators/ --include='*.md' 2>/dev/null)
n_decls=$(printf '%s\n' "$decls" | grep -c . || true)
if [ "$n_decls" -ne "$NOTE_ENUM_DECLS" ]; then
    echo "ERROR  found $n_decls note-enum declaration(s), expected $NOTE_ENUM_DECLS — the set moved; re-derive and re-pin"
    errors=$((errors + 1))
else
    sigs=""; bad=""
    while IFS= read -r d; do
        [ -n "$d" ] || continue
        site=$(printf '%s' "$d" | cut -d: -f1-2)
        vals=$(printf '%s' "${d#*:*:}" | enum_values | tr '\n' ' ')
        nv=$(printf '%s' "$vals" | wc -w | tr -d ' ')
        if [ "$nv" -lt 2 ]; then bad="$bad $site"; fi
        sigs="$sigs$site|$vals"$'\n'
    done <<EOF_DECLS
$decls
EOF_DECLS
    distinct=$(printf '%s' "$sigs" | grep -v '^$' | cut -d'|' -f2 | LC_ALL=C sort -u | grep -c . || true)
    if [ -n "$bad" ]; then
        echo "ERROR  extraction yielded under 2 values at:$bad — the declaration form changed"
        errors=$((errors + 1))
    elif [ "$distinct" -ne 1 ]; then
        echo "MISMATCH  $distinct different value sets across $n_decls declarations:"
        printf '%s' "$sigs" | grep -v '^$' | sed 's/^/      /'
        mismatches=$((mismatches + 1))
    else
        echo "ok     $n_decls declarations, one value set"
    fi
fi

printf '  %-18s %-30s ' "generators/" "tension recipes match enum"
# TENSION_ENUM_DECLS GUARD, MIRRORING NOTE_ENUM_DECLS FIVE LINES ABOVE (the
# sibling NOTE-enum check). Before this guard, `tenum` was read with a bare
# `| head -1` and no declaration-count check at all: a SECOND `status:...
# dissolved` line anywhere in generators/ would be silently and arbitrarily
# chosen between, with nothing to say a choice had even been made. Count
# first, require exactly one, error otherwise — same shape as NOTE_ENUM_DECLS.
tdecls=$(/usr/bin/grep -rn 'status:.*dissolved' generators/ --include='*.md' 2>/dev/null)
n_tdecls=$(printf '%s\n' "$tdecls" | grep -c . || true)
# The recipe used to be one line, `type: tension` piped to `status: (a|b)`, so
# the values were extractable from the same line matched. Since the conversion
# to list_notes_by_field (fix/spec-h-enforcement-gap), the values live on the
# FOLLOWING line instead — `[ "$s" = "pending" ] || [ "$s" = "open" ]` — so this
# check now reads one line past each match rather than parsing the match itself.
recipes=$(/usr/bin/grep -rn 'list_notes_by_field.*type tension' generators/ --include='*.md' 2>/dev/null)
n_rec=$(printf '%s\n' "$recipes" | grep -c . || true)
if [ "$n_tdecls" -eq 0 ]; then
    echo "ERROR  tension enum not found (anchor 'dissolved') — cannot evaluate"
    errors=$((errors + 1))
elif [ "$n_tdecls" -ne "$TENSION_ENUM_DECLS" ]; then
    echo "ERROR  found $n_tdecls tension-enum declaration(s), expected $TENSION_ENUM_DECLS — the set moved; re-derive and re-pin"
    errors=$((errors + 1))
elif [ "$n_rec" -ne "$TENSION_RECIPES" ]; then
    echo "ERROR  found $n_rec tension recipe(s), expected $TENSION_RECIPES — the set moved; re-derive and re-pin"
    errors=$((errors + 1))
else
    tenum_file=$(printf '%s' "$tdecls" | cut -d: -f1)
    tenum=$(/usr/bin/grep -h 'status:.*dissolved' "$tenum_file" 2>/dev/null | enum_values)
    undeclared=""
    zero_extract=""
    while IFS= read -r r; do
        [ -n "$r" ] || continue
        f=$(printf '%s' "$r" | cut -d: -f1)
        ln=$(printf '%s' "$r" | cut -d: -f2)
        site="$f:$ln"
        follow=$(sed -n "$((ln + 1))p" "$f")
        vals=$(printf '%s' "$follow" | /usr/bin/grep -oE '"\$s" = "[a-zA-Z_]+"' | sed 's/.*"\([a-zA-Z_]*\)"$/\1/')
        # A ZERO-VALUE EXTRACTION IS AN ERROR, NOT A SILENT "ok". The old
        # shape read the follow-line, found nothing to iterate, and the `for`
        # loop below simply ran zero times — undeclared stayed empty, and
        # "ok $n_rec recipes, all values declared" printed having checked
        # NOTHING for this recipe. Reproduced directly: reordering one
        # recipe's follow-line left this check green while validating zero
        # of its three sites.
        if [ -z "$vals" ]; then
            zero_extract="$zero_extract $site"
            continue
        fi
        for v in $vals; do
            printf '%s\n' "$tenum" | grep -qxF "$v" || undeclared="$undeclared $site:$v"
        done
    done <<EOF_REC
$recipes
EOF_REC
    if [ -n "$zero_extract" ]; then
        echo "ERROR  recipe(s) at$zero_extract extracted zero values from the follow-line — the recipe shape moved"
        errors=$((errors + 1))
    elif [ -n "$undeclared" ]; then
        echo "MISMATCH  recipe matches value(s) the enum does not declare:$undeclared"
        mismatches=$((mismatches + 1))
    else
        echo "ok     $n_rec recipes, all values declared"
    fi
fi

echo
[ "$mismatches" -gt 0 ] && RC=1
[ "$errors" -gt 0 ] && RC=2      # could-not-run outranks mismatch: an unevaluated
                                 # claim means this gate does not know its own scope
if [ "$RC" -eq 0 ]; then
    echo "DOC CLAIMS: PASS (declared claims only — bash-run totals only)"
elif [ "$RC" -eq 1 ]; then
    echo "DOC CLAIMS: FAIL — $mismatches stale claim(s). Fix the document, not the gate."
else
    echo "DOC CLAIMS: ERROR — $errors claim(s) could not be evaluated ($mismatches mismatch(es) also seen)."
    echo "  This is NOT a clean run. An anchor that moved means the claim is unchecked."
fi
exit "$RC"
