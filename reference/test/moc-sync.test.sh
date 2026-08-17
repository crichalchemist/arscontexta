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

cat > "$FIX/observations.md" <<'EOF'
# Observations

## Open (1)
- [[alpha-note]] — Alpha description here
- [[zebra-note]] — Zebra description that was EDITED
EOF

# --- moc_harvest_entries --------------------------------------------------
ok "harvest finds both entries" "2" "$(moc_harvest_entries "$FIX/observations.md" | /usr/bin/grep -c .)"
ok "harvest carries the prose" "Zebra description that was EDITED" \
   "$(moc_harvest_entries "$FIX/observations.md" | /usr/bin/awk -F'\t' '$1=="zebra-note"{print $2}')"
# PAIRED WITH A POSITIVE: an empty-expectation assertion passes when the function does
# not exist, so on its own it certifies nothing.
ok "harvest of a missing file is empty" "" "$(moc_harvest_entries "$FIX/nope.md" 2>/dev/null)"
moc_harvest_entries "$FIX/nope.md" >/dev/null 2>&1; ok "harvest of a missing file is rc 0" "0" "$?"

# --- moc_render -----------------------------------------------------------
BODY=$(MOC_SYNC_EXISTING="$FIX/observations.md" moc_render "$FIX/observations" "$MOC_MAP_OBSERVATIONS" 2>/dev/null)

ok "Open heading counts 2" "## Open (2)" "$(printf '%s\n' "$BODY" | /usr/bin/grep -m1 '^## Open')"
ok "Implemented heading counts 1" "## Implemented (1)" \
   "$(printf '%s\n' "$BODY" | /usr/bin/grep -m1 '^## Implemented')"

# ORDER IS ASCENDING BY FILENAME (spec Decision 12).
ok "entries sort by filename" "alpha-note zebra-note" \
   "$(printf '%s\n' "$BODY" | /usr/bin/awk '/^## Open/{f=1;next} /^## /{f=0} f&&/^- \[\[/' \
      | /usr/bin/sed 's/^- \[\[//; s/\]\].*//' | /usr/bin/tr '\n' ' ' | /usr/bin/sed 's/ $//')"

ok "existing prose is carried forward" "Zebra description that was EDITED" \
   "$(printf '%s\n' "$BODY" | /usr/bin/sed -n 's/^- \[\[zebra-note\]\] — //p')"
ok "new entry is seeded from description" "Middle description here" \
   "$(printf '%s\n' "$BODY" | /usr/bin/sed -n 's/^- \[\[middle-note\]\] — //p')"

# EVERY MAPPED SECTION IS EMITTED, even at zero: an absent section cannot be
# distinguished from "no notes have that status".
ok "empty sections are emitted at 0" "## Dissolved (0)" \
   "$(printf '%s\n' "$BODY" | /usr/bin/grep -m1 '^## Dissolved')"

# ZSH GUARD: an uninitialised in-loop `local` prints `x=value` into stdout. Assert the
# rendered body contains no such line — this is the only assertion that catches it, and
# it catches it in the output rather than in a shell-version check.
ok "render emits no stray variable lines" "0" \
   "$(printf '%s\n' "$BODY" | /usr/bin/grep -cE '^[a-z_]+=')"

# A bad directory is rc 1 and prints an error.
moc_render "$FIX/no-such-dir" "$MOC_MAP_OBSERVATIONS" >/dev/null 2>&1
ok "bad notes-dir is rc 1" "1" "$?"

# --- rule 2: divergent summary preserved AND warned about ------------------
ERRF="$FIX/stderr.txt"
BODY=$(MOC_SYNC_EXISTING="$FIX/observations.md" \
       moc_render "$FIX/observations" "$MOC_MAP_OBSERVATIONS" 2>"$ERRF")

ok "divergent summary is preserved" "Zebra description that was EDITED" \
   "$(printf '%s\n' "$BODY" | /usr/bin/sed -n 's/^- \[\[zebra-note\]\] — //p')"
ok "divergence warns exactly once" "1" "$(/usr/bin/grep -c 'summary not derivable' "$ERRF")"
ok "the warning names the slug" "1" \
   "$(/usr/bin/grep -c 'summary not derivable from current frontmatter: zebra-note' "$ERRF")"

# THE WARNING MUST NOT CLAIM A CAUSE. "someone hand-edited this" is measurably wrong for
# most divergent entries: 7 of the 29 divergent Implemented entries follow a second
# derivation convention ("implemented via <target>"), the rest are stale derivations.
# Paired with the positive assertion above so it cannot pass on absence.
ok "warning does not assert hand-editing" "0" "$(/usr/bin/grep -ci 'hand.edit' "$ERRF")"
ok "an agreeing summary does not warn" "0" \
   "$(/usr/bin/grep -c 'not derivable from current frontmatter: alpha-note' "$ERRF")"

# --- rule 3(b): note exists, status unreadable ----------------------------
# frontmatter.sh treats an UNCLOSED frontmatter block as NO frontmatter. Such a note
# EXISTS, so "the note is gone" cannot catch it.
printf -- '---\ndescription: Unclosed\nstatus: open\n\nbody\n' > "$FIX/observations/broken-note.md"
BODY=$(MOC_SYNC_EXISTING="$FIX/observations.md" \
       moc_render "$FIX/observations" "$MOC_MAP_OBSERVATIONS" 2>"$ERRF")
ok "unreadable status is reported" "1" "$(/usr/bin/grep -c 'no readable status' "$ERRF")"
ok "unreadable note names the path" "1" "$(/usr/bin/grep -c 'broken-note.md' "$ERRF")"
ok "unreadable note is NOT placed" "0" "$(printf '%s\n' "$BODY" | /usr/bin/grep -c '\[\[broken-note\]\]')"
rm -f "$FIX/observations/broken-note.md"

# --- rule 3(c) / rule 6: status readable but off-map ----------------------
mknote orphan-note superseded "Orphan description"
BODY=$(MOC_SYNC_EXISTING="$FIX/observations.md" \
       moc_render "$FIX/observations" "$MOC_MAP_OBSERVATIONS" 2>"$ERRF")
ok "off-map status is reported" "1" "$(/usr/bin/grep -c 'maps to no section' "$ERRF")"
ok "off-map report names status and slug" "1" \
   "$(/usr/bin/grep -c "status 'superseded' maps to no section, not placed: orphan-note" "$ERRF")"
ok "off-map note is NOT placed" "0" "$(printf '%s\n' "$BODY" | /usr/bin/grep -c '\[\[orphan-note\]\]')"
rm -f "$FIX/observations/orphan-note.md"

# --- rule 3(a): an entry whose note is gone -------------------------------
# Spec rule 3(a). The first draft of this plan claimed this in a commit message and
# never implemented it.
cat > "$FIX/gone.md" <<'EOF'
## Open (1)
- [[deleted-note]] — This note was deleted from disk
EOF
BODY=$(MOC_SYNC_EXISTING="$FIX/gone.md" \
       moc_render "$FIX/observations" "$MOC_MAP_OBSERVATIONS" 2>"$ERRF")
ok "gone entry is reported" "1" "$(/usr/bin/grep -c 'entry has no note, not removed: deleted-note' "$ERRF")"
ok "gone entry is not silently resurrected" "0" \
   "$(printf '%s\n' "$BODY" | /usr/bin/grep -c '\[\[deleted-note\]\]')"

printf '\nmoc-sync: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
