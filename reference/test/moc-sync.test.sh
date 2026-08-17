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
