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

# moc_harvest_entries <moc-file> -> "slug<TAB>summary" per entry, file order.
# A missing file is not an error: a vault whose MOC does not exist yet is a legitimate
# first-run state, and the rebuild creates it.
moc_harvest_entries() {
  local file="$1"
  [ -r "$file" ] || return 0
  /usr/bin/awk '
    match($0, /^[[:space:]]*-[[:space:]]*\[\[[^]|#]+\]\]/) {
      line = $0
      slug = line
      sub(/^[[:space:]]*-[[:space:]]*\[\[/, "", slug)
      sub(/\]\].*$/, "", slug)
      rest = line
      sub(/^[^]]*\]\][[:space:]]*/, "", rest)
      sub(/^(—|--)[[:space:]]*/, "", rest)
      printf "%s\t%s\n", slug, rest
    }
  ' "$file"
}

# moc_render <notes-dir> <map-string> -> the MOC body on stdout.
#
# Pure with respect to files: writes nothing, so a caller can inspect a candidate render
# before committing to it. rc 1 on a bad directory — rebuild_status_moc DEPENDS on that rc
# and its first draft ignored it, which destroyed the MOC at rc 0.
#
# Every `local` below that lives inside a loop carries an initialiser. Under zsh a bare
# re-declaration prints `name=value` on stdout, i.e. into the MOC.
moc_render() {
  local dir="$1" map="$2"
  if [ ! -d "$dir" ]; then
    echo "error: moc-sync: not a directory: '$dir'" >&2
    return 1
  fi
  if [ -z "$map" ]; then
    echo "error: moc-sync: moc_render needs <notes-dir> <map-string>" >&2
    return 1
  fi

  local existing="${MOC_SYNC_EXISTING:-}" harvest=""
  [ -n "$existing" ] && harvest=$(moc_harvest_entries "$existing")

  local notes="" pair="" sec="" st_want="" note="" st="" slug="" desc="" summary="" lines="" count=0
  notes=$(LC_ALL=C find -H "$dir" -type f -name '*.md' 2>/dev/null | LC_ALL=C sort)

  # The outer loop visits EVERY note once per section, so an unguarded report fires 4x for
  # observations and 7x for tensions. Each report is guarded on the first section so it
  # fires exactly once per note.
  local first_sec="" placed_slugs=""
  first_sec=$(_moc_each_pair "$map" | /usr/bin/sed -n 1p)
  first_sec="${first_sec#*:}"

  while IFS= read -r pair; do
    [ -n "$pair" ] || continue
    st_want="${pair%%:*}"
    sec="${pair#*:}"
    lines=""
    count=0

    while IFS= read -r note; do
      [ -n "$note" ] || continue
      st=$(frontmatter_field "$note" status 2>/dev/null)

      # Rule 3(b): the note EXISTS but its status cannot be read — frontmatter.sh treats an
      # unclosed block as no frontmatter. "The note is gone" cannot catch this case.
      if [ -z "$st" ]; then
        [ "$sec" = "$first_sec" ] && \
          echo "warn: moc-sync: note has no readable status, not placed: $note" >&2
        continue
      fi
      # Rule 3(c) / rule 6: status readable but off-map. Reported rather than guessed at.
      if ! moc_section_for "$st" "$map" >/dev/null 2>&1; then
        [ "$sec" = "$first_sec" ] && \
          echo "warn: moc-sync: status '$st' maps to no section, not placed: $(basename "$note" .md)" >&2
        continue
      fi
      [ "$st" = "$st_want" ] || continue

      slug=$(basename "$note" .md)
      placed_slugs="${placed_slugs}${slug}
"

      summary=$(printf '%s\n' "$harvest" | /usr/bin/awk -F'\t' -v s="$slug" '$1==s{print $2; exit}')
      desc=$(frontmatter_field "$note" description 2>/dev/null)
      if [ -z "$summary" ]; then
        summary="$desc"
      else
        # Rule 2: keep the file's version; warn only when it is not derivable.
        # NORMALISE FIRST — the live convention truncates with an ellipsis, so a raw
        # compare would flag every correctly-derived entry.
        local a="" b=""
        a=$(printf '%s' "$summary" | /usr/bin/tr -d '\r' | /usr/bin/sed 's/[.… ]*$//')
        b=$(printf '%s' "$desc"    | /usr/bin/tr -d '\r' | /usr/bin/sed 's/[.… ]*$//')
        case "$b" in
          "$a"*) : ;;
          *) echo "warn: moc-sync: summary not derivable from current frontmatter: $slug" >&2 ;;
        esac
      fi
      lines="${lines}- [[${slug}]] — ${summary}
"
      count=$((count + 1))
    done <<INNER
$notes
INNER

    printf '## %s (%d)\n' "$sec" "$count"
    [ "$count" -gt 0 ] && printf '%s' "$lines"
    printf '\n'
  done <<OUTER
$(_moc_each_pair "$map")
OUTER

  # Rule 3(a): a harvested entry with no surviving note. Reported, never silently
  # dropped: that is either a rename to fix or a deletion to record.
  local hslug=""
  while IFS= read -r hslug; do
    [ -n "$hslug" ] || continue
    case "
$placed_slugs" in
      *"
$hslug
"*) : ;;
      *) echo "warn: moc-sync: entry has no note, not removed: $hslug" >&2 ;;
    esac
  done <<GONE
$(printf '%s\n' "$harvest" | /usr/bin/awk -F'\t' 'NF{print $1}')
GONE
  return 0
}

# _moc_lock <file> -> prints the lock dir, rc 0; rc 1 on timeout.
# mkdir is the atomic primitive. A BOUNDED WAIT THAT FAILS MUST NOT BREAK THE LOCK IT
# COULD NOT TAKE — an auto-break wearing a failure message is how concurrent writers lose
# updates. queue-edit.sh's header argues this at length; same contract.
_moc_lock() {
  local file="$1" lockdir="$1.lock" waited=0
  while ! mkdir "$lockdir" 2>/dev/null; do
    waited=$((waited + 1))
    if [ "$waited" -ge 60 ]; then
      echo "error: moc-sync: could not acquire lock '$lockdir' within 60s; NOT breaking it" >&2
      return 1
    fi
    sleep 1
  done
  printf '%s\n' "$lockdir"
}

# rebuild_status_moc <moc-file> <notes-dir> <map-string>
rebuild_status_moc() {
  local file="$1" dir="$2" map="$3"
  if [ -z "$file" ] || [ -z "$dir" ] || [ -z "$map" ]; then
    echo "error: moc-sync: rebuild_status_moc needs <moc-file> <notes-dir> <map-string>" >&2
    return 1
  fi

  local lockdir="" tmp="" body_tmp=""
  lockdir=$(_moc_lock "$file") || return 1
  tmp="${file}.$$.tmp"
  body_tmp="${file}.$$.body"

  # RENDER FIRST, INTO ITS OWN FILE, AND CHECK THE RC. The first draft rendered inside a
  # brace group that had already written header lines, discarded the group's status, and
  # guarded only on emptiness — so a render failure replaced the MOC with a header and
  # returned 0. Content destruction at exit 0 is this repo's cardinal failure class, and
  # it was in the one function whose contract promised the opposite.
  if ! MOC_SYNC_EXISTING="$file" moc_render "$dir" "$map" > "$body_tmp"; then
    echo "error: moc-sync: render failed; '$file' left unchanged" >&2
    rm -f "$body_tmp"; rm -rf "$lockdir"; return 1
  fi
  if [ ! -s "$body_tmp" ]; then
    echo "error: moc-sync: render produced no sections; '$file' left unchanged" >&2
    rm -f "$body_tmp"; rm -rf "$lockdir"; return 1
  fi

  {
    printf '# %s\n\n' "$(basename "$file" .md)"
    printf 'derived: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf '<!-- Derived from note frontmatter. Do not move entries by hand; they will be\n'
    printf '     regenerated. Re-derive with:\n'
    printf '       . ops/lib/moc-sync.sh && rebuild_status_moc <moc-file> <notes-dir> <map> -->\n\n'
    cat "$body_tmp"
  } > "$tmp"
  rm -f "$body_tmp"

  # THE GUARDED RENAME. Ending this `mv` without a failure branch returns the exit status
  # of the following `rm -rf` — 0 — while leaving an undeclared second copy on disk. That
  # exact defect shipped in queue-edit.sh and its suite was written red to pin it.
  if ! mv "$tmp" "$file"; then
    echo "error: moc-sync: could not move '$tmp' into place at '$file'" >&2
    rm -f "$tmp"
    rm -rf "$lockdir"
    return 1
  fi
  rm -rf "$lockdir"
  return 0
}
