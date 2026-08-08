#!/bin/bash
# check-doc-claims.test.sh — mutation tests for check-doc-claims.sh's TENSION
# validation. No test file existed for this script at all before this one.
#
# WHY THIS EXISTS: check-doc-claims.sh's TENSION row had two silent gaps,
# both reproduced directly against the real tree before being fixed. (a)
# `tenum` was read with a bare `grep -rh ... | head -1`, with no check that
# exactly one `status:...dissolved` declaration exists — a second one
# anywhere in generators/ would be silently and arbitrarily chosen between.
# Reproduced: a decoy second declaration made `head -1` pick the WRONG one,
# and the check reported a MISMATCH blaming "pending"/"open" as undeclared
# rather than surfacing the real defect (two declarations, an arbitrary
# pick). (b) the per-recipe value extraction read exactly one line past each
# `list_notes_by_field.*type tension` match; if that follow-line ever moved,
# the extraction silently yielded zero values and the `for` loop below
# simply ran zero times — reported "ok N recipes, all values declared"
# having validated nothing for that recipe. Reproduced: inserting one
# comment line between a recipe's match line and its value-check line left
# the check green while checking zero of that recipe's three sites.
#
# check-doc-claims.sh is NOT vault-parameterized -- it hardcodes generators/
# relative to its CWD, so these tests mutate the real tree's generators/
# files temporarily and restore them via a trap, rather than building an
# isolated fixture the way kernel-note-dirs.test.sh does for
# validate-kernel.sh. Every mutation is backed up before writing and
# restored on ANY exit path, including a failed assertion mid-test.
#
# BASH-ONLY, DELIBERATELY -- not run under zsh, and not listed inside the
# "for s in bash zsh; do ... done" fence in CLAUDE.md/CONTRIBUTING.md. This
# suite invokes check-doc-claims.sh three times (baseline + 2 mutations),
# and check-doc-claims.sh's own header states its totals are BASH-RUN ONLY
# -- there is nothing for a zsh run of THIS suite to check that a zsh run
# of the target script wouldn't already need to check first. Matches the
# precedent CLAUDE.md's Verification section states for
# check-portability.sh: run under one shell by declared choice, not by
# omission. It is still listed as a standalone line in both fences (outside
# the both-shells loop), because check-doc-claims.sh's own check_list_len
# assertions count `reference/` lines in those fences against the live
# file count -- omitting it entirely would make check-doc-claims.sh fail
# against its own healthy tree.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
CHECK="$ROOT/reference/check-doc-claims.sh"
RECIPE_FILE="$ROOT/generators/features/graph-analysis.md"
DECOY_FILE="$ROOT/generators/features/_scratch-check-doc-claims-decoy.md"
passed=0; failed=0

[ -n "${ZSH_VERSION:-}" ] && { echo "error: bash-only suite (see header) -- run with bash, not zsh" >&2; exit 1; }
SELF=bash

[ -r "$CHECK" ] || { echo "error: check-doc-claims.sh not found at '$CHECK'" >&2; exit 1; }
[ -r "$RECIPE_FILE" ] || { echo "error: recipe file not found at '$RECIPE_FILE'" >&2; exit 1; }

eq() { # eq <label> <expected> <actual>
  if [ "$2" = "$3" ]; then
    passed=$((passed + 1)); printf '  ok   %s\n' "$1"
  else
    failed=$((failed + 1)); printf '  FAIL %s\n       expected: %s\n       actual:   %s\n' "$1" "$2" "$3"
  fi
}

# tension_row -> the "tension recipes match enum" row's own text, plus the
# script's own exit code, captured together since a `$(...)` command
# substitution cannot also hand back `$?` for a separate later read.
tension_row() {
  (cd "$ROOT" && "$SELF" "$CHECK" 2>&1); printf '::RC=%s' "$?"
}

RECIPE_BACKUP=""
HEAD_BLOB=""
cleanup() {
  rm -f "$DECOY_FILE"
  if [ -n "$RECIPE_BACKUP" ] && [ -f "$RECIPE_BACKUP" ]; then
    cp "$RECIPE_BACKUP" "$RECIPE_FILE"
    rm -f "$RECIPE_BACKUP"
  fi
  [ -n "$HEAD_BLOB" ] && rm -f "$HEAD_BLOB"
}
trap cleanup EXIT INT TERM

# =============================================================================
echo "check-doc-claims.test.sh (shell: $SELF)"

# --- Baseline: healthy tree, no mutation -----------------------------------
OUT=$(tension_row)
RC=$(printf '%s' "$OUT" | sed -n 's/.*::RC=//p')
ROW=$(printf '%s' "$OUT" | /usr/bin/grep 'tension recipes match enum')
eq "baseline: healthy tree -> ok, non-vacuous" "present" \
   "$(printf '%s' "$ROW" | /usr/bin/grep -qE 'ok +[0-9]+ recipes, all values declared' && echo present || echo absent)"
eq "baseline: healthy tree -> script exits 0" "0" "$RC"

# --- Mutation (a): a second status:...dissolved declaration ----------------
printf 'status: fresh | different | dissolved | values | here\n' > "$DECOY_FILE"
OUT=$(tension_row)
RC=$(printf '%s' "$OUT" | sed -n 's/.*::RC=//p')
ROW=$(printf '%s' "$OUT" | /usr/bin/grep 'tension recipes match enum')
eq "mutation (a): second tension-enum decl -> ERROR, not a silent pick" "present" \
   "$(printf '%s' "$ROW" | /usr/bin/grep -q 'ERROR' && echo present || echo absent)"
eq "mutation (a): message names the declaration count" "present" \
   "$(printf '%s' "$ROW" | /usr/bin/grep -q 'tension-enum declaration' && echo present || echo absent)"
eq "mutation (a): does NOT silently blame pending/open as undeclared" "absent" \
   "$(printf '%s' "$ROW" | /usr/bin/grep -q 'does not declare' && echo present || echo absent)"
eq "mutation (a): script exits 2 (could not evaluate, not a mismatch)" "2" "$RC"
rm -f "$DECOY_FILE"

# --- Mutation (b): a recipe's follow-line pushed out of position -----------
RECIPE_BACKUP=$(mktemp) || exit 1
cp "$RECIPE_FILE" "$RECIPE_BACKUP"
# Insert one comment line between the match line and its value-check line,
# at the FIRST of graph-analysis.md's two recipe sites -- reproducing
# exactly the "recipe shape moved" scenario Step 1 measured.
awk '
  /^tensions=\$\(list_notes_by_field.*type tension\)/ && !done {
    print
    print "# TASK5 MUTATION: reordering probe, one extra line before the value check"
    done = 1
    next
  }
  { print }
' "$RECIPE_BACKUP" > "$RECIPE_FILE"
eq "mutation (b): setup actually changed the file" "yes" \
   "$(cmp -s "$RECIPE_FILE" "$RECIPE_BACKUP" && echo no || echo yes)"
OUT=$(tension_row)
RC=$(printf '%s' "$OUT" | sed -n 's/.*::RC=//p')
ROW=$(printf '%s' "$OUT" | /usr/bin/grep 'tension recipes match enum')
eq "mutation (b): displaced follow-line -> ERROR, not a silent ok" "present" \
   "$(printf '%s' "$ROW" | /usr/bin/grep -q 'ERROR' && echo present || echo absent)"
eq "mutation (b): message names zero-value extraction" "present" \
   "$(printf '%s' "$ROW" | /usr/bin/grep -q 'extracted zero values' && echo present || echo absent)"
eq "mutation (b): does NOT report ok having checked nothing" "absent" \
   "$(printf '%s' "$ROW" | /usr/bin/grep -qE 'ok +[0-9]+ recipes' && echo present || echo absent)"
eq "mutation (b): script exits 2 (could not evaluate, not a mismatch)" "2" "$RC"
cp "$RECIPE_BACKUP" "$RECIPE_FILE"
rm -f "$RECIPE_BACKUP"; RECIPE_BACKUP=""

# --- Restore confirmed clean -------------------------------------------------
# Compare against `git show HEAD:<path>` written to a temp file, not a
# PRISTINE snapshot taken at script start -- a snapshot taken once and held
# across three ~100s check-doc-claims.sh invocations is vulnerable to any
# transient external touch to the file in between (this was measured
# happening once; the isolated mutate/restore sequence alone, without the
# long intervening invocations, was clean 5/5). Comparing against git's own
# ground truth avoids the question of timing entirely. Not `git diff
# --quiet`, per the same file-scoped byte comparison this replaces: that
# form would false-fail on unrelated pre-existing dirt anywhere else in the
# repo, and would silently report clean if `git` were absent. `git show`
# writes to a FILE, not a `$()` capture, because command substitution
# strips trailing newlines and would introduce a spurious mismatch on a
# byte-exact comparison.
HEAD_BLOB=$(mktemp) || exit 1
if (cd "$ROOT" && git show HEAD:generators/features/graph-analysis.md > "$HEAD_BLOB" 2>/dev/null); then
  eq "teardown: recipe file restored byte-identical to git HEAD" "yes" \
     "$(cmp -s "$RECIPE_FILE" "$HEAD_BLOB" && echo yes || echo no)"
else
  eq "teardown: recipe file restored byte-identical to git HEAD" "yes" "git show HEAD failed -- cannot verify"
fi
eq "teardown: no decoy file left behind" "yes" \
   "$([ ! -e "$DECOY_FILE" ] && echo yes || echo no)"

printf '\npassed=%s failed=%s\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
