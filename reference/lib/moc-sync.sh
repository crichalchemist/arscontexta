#!/bin/bash
# moc-sync.sh — derive a status MOC (e.g. ops/observations.md) from note frontmatter.
#
# WHY THIS EXISTS: skill-sources/rethink/SKILL.md used to instruct an agent to "move
# entries between Pending/Promoted/Blocked/Archived/Resolved/Dissolved sections". That is
# incremental maintenance of a cache, and it can only be correct if every status change
# flows through the mover. Four templates write the notes a status MOC indexes and only one
# touched the MOC, so it diverged at the rate of note activity — three times in the field,
# most recently within 72 hours of a rebuild. Deriving is idempotent: running it IS the
# repair and running it twice is a no-op.
#
# NAMED MOC, NOT HUB. "Hub" is the field vault's dialect; the canonical term is MOC
# (reference/vocabulary-transforms.md:17). A library ships verbatim into every generated
# vault's ops/lib/ and its function names are NOT vocabulary-substituted.
#
# TWO ZSH RULES THIS FILE OBEYS, both of which killed its first draft:
#   1. `status` is a READ-ONLY SPECIAL VARIABLE in zsh and assigning it aborts the script
#      outright. Nothing here declares or assigns `status`, `path`, `options` or `argv`.
#   2. A bare `local x` re-declared inside a loop PRINTS `x=value` from the second
#      iteration onward — straight into this file's stdout, i.e. into the rendered MOC.
#      Every `local` inside a loop here carries an initialiser.
MOC_SYNC_VERSION=1

# THE SECTION MAP IS PINNED HERE, NOT CHOSEN BY CALLERS. Three vocabularies are live in the
# field at once: rethink's own six-name instruction, the observations MOC's "canonical
# three", and a tensions MOC carrying a literal "Non-canonical status: resolved" heading. A
# rebuild under any one of them silently drops the others' notes — measured 2026-08-17:
# 2 dissolved observations, 8 promoted + 6 archived tensions. Silent omission of a note that
# exists is the defect this library removes, so every status a vault can hold gets a section.
MOC_MAP_OBSERVATIONS="open:Open implemented:Implemented archived:Archived dissolved:Dissolved"
MOC_MAP_TENSIONS="open:Open blocked:Blocked implemented:Implemented promoted:Promoted archived:Archived dissolved:Dissolved resolved:Resolved"

# _moc_each_pair <map-string> -> one "status:Section" pair per line.
#
# THE MAP IS ALWAYS ONE QUOTED ARGUMENT AND IS SPLIT HERE, never by word-splitting at a
# call site. zsh does not word-split unquoted parameter expansions, so `f $MAP` passes ONE
# argument under zsh and three under bash. The first draft of this library relied on that
# splitting, so under zsh its shipped fence processed only the first pair and silently
# dropped every non-open note at rc 0.
_moc_each_pair() {
  local rest="$1" pair=""
  while [ -n "$rest" ]; do
    pair="${rest%% *}"
    [ -n "$pair" ] && printf '%s\n' "$pair"
    case "$rest" in
      *" "*) rest="${rest#* }" ;;
      *)     rest="" ;;
    esac
  done
}

# moc_section_for <status> <map-string> -> section name
#   rc 0 = mapped (section printed)
#   rc 2 = off-map (NOTHING printed — the caller reports it per rule 6)
#   rc 1 = usage error
# rc 2 is deliberately distinct from rc 1: collapsing them makes an off-map note
# indistinguishable from a bug in the caller.
moc_section_for() {
  local want="$1" map="$2" pair=""
  if [ -z "$want" ] || [ -z "$map" ]; then
    echo "error: moc-sync: moc_section_for needs <status> <map-string>" >&2
    return 1
  fi
  while IFS= read -r pair; do
    [ -n "$pair" ] || continue
    if [ "${pair%%:*}" = "$want" ]; then
      printf '%s\n' "${pair#*:}"
      return 0
    fi
  done <<EOF
$(_moc_each_pair "$map")
EOF
  return 2
}
