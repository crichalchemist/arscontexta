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
# THE MAP IS THE GENERATOR'S DECLARED ENUM PLUS THE STATUSES THE SPEC ITSELF NAMES — and no
# more. Re-derive it from `generators/features/self-evolution.md` whenever that enum moves;
# NEVER from a field measurement.
#
# THAT BOUNDARY IS NARROW ON PURPOSE, in both directions. Widen it to "whatever the field
# holds" and the map absorbs every ad-hoc status a vault invents, which is how rule 6 dies:
# an unknown status would get a section instead of a report. The field vault carries exactly
# one such today — `status: executed`, declared in no enum anywhere — and the correct behavior
# is the one you get below: reported, not placed, not guessed at.
#
# WHY `dissolved` IS HERE AND `executed` IS NOT — and the test is checkable, not a judgement
# call. `dissolved` is DECLARED in this file's tension enum (`self-evolution.md:220`) and
# described at `:235-236`; it is simply absent from the OBSERVATION enum, which is a gap in
# that enum rather than an invention of one vault. `executed` has ZERO hits anywhere in
# `generators/` or `reference/kernel.yaml`. Grep for the status: if the generator names it,
# it belongs here; if nothing names it, it gets reported. An earlier draft of this comment
# justified `dissolved` by saying the spec "measures 2 such notes by name" — that launders a
# field measurement into a rule, which is precisely the mistake below.
#
# THE MISTAKE, RECORDED SO IT IS NOT REPEATED: the first version of this map was measured
# against one live vault, scored "0 off-map", and was wrong anyway — that vault happens to use
# `open`, while the generator declares `pending` and `/rethink` itself WRITES it (KEEP PENDING
# leaves `status: pending`; PROMOTE sets `status: promoted`). So the template that calls this
# rebuild wrote two statuses the rebuild silently dropped: this library's own failure class,
# inside its pinned input. A measurement confirms a sample; only a declaration confirms a
# contract.
MOC_MAP_OBSERVATIONS="pending:Pending open:Open promoted:Promoted implemented:Implemented archived:Archived dissolved:Dissolved"
MOC_MAP_TENSIONS="pending:Pending open:Open blocked:Blocked promoted:Promoted implemented:Implemented resolved:Resolved archived:Archived dissolved:Dissolved"

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
  # FAIL LOUD WHEN frontmatter.sh WAS NOT SOURCED. Without this the status read below returns
  # empty for every note, every note is reported as "no readable status", and the rebuild writes
  # a MOC with every section at (0) at rc 0 — content destruction at exit 0, with the warning
  # blaming the notes for a missing library. Reproduced by following this file's own provenance
  # banner verbatim, which is how the defect was found.
  if ! command -v frontmatter_field >/dev/null 2>&1; then
    echo "error: moc-sync: frontmatter_field is not defined — source ops/lib/frontmatter.sh" >&2
    echo "       before this library; moc_render cannot read any status without it" >&2
    return 1
  fi
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
  # observations and 7x for tensions. Each report is guarded to the FIRST ITERATION so it
  # fires exactly once per note.
  #
  # GUARDED ON THE ITERATION INDEX, NOT ON THE SECTION NAME. Comparing `$sec` against the
  # first pair's section is correct only while every status maps to a DISTINCT section — an
  # invariant the two pinned maps happen to satisfy and nothing states or enforces. Hand
  # this function `open:Everything implemented:Everything` and the name compare is true on
  # two iterations, so every unplaceable note is reported twice. An index cannot collide.
  # TWO SETS, NOT ONE. `placed_slugs` is what landed in a section; `seen_slugs` is every note
  # that exists on disk, placed or not. Rule 3(a) must key on SEEN, because an off-map or
  # unreadable note is not placed yet plainly exists — keying on placed made the gone-report
  # fire for notes the other two reports had just named, asserting they had "no note".
  local sec_index=0 placed_slugs="" seen_slugs=""

  while IFS= read -r pair; do
    [ -n "$pair" ] || continue
    sec_index=$((sec_index + 1))
    st_want="${pair%%:*}"
    sec="${pair#*:}"
    lines=""
    count=0

    while IFS= read -r note; do
      [ -n "$note" ] || continue
      if [ "$sec_index" -eq 1 ]; then
        seen_slugs="${seen_slugs}$(basename "$note" .md)
"
      fi
      st=$(frontmatter_field "$note" status 2>/dev/null)

      # Rule 3(b): the note EXISTS but its status cannot be read — frontmatter.sh treats an
      # unclosed block as no frontmatter. "The note is gone" cannot catch this case.
      if [ -z "$st" ]; then
        [ "$sec_index" -eq 1 ] && \
          echo "warn: moc-sync: note has no readable status, not placed: $note" >&2
        continue
      fi
      # Rule 3(c) / rule 6: status readable but off-map. Reported rather than guessed at.
      if ! moc_section_for "$st" "$map" >/dev/null 2>&1; then
        [ "$sec_index" -eq 1 ] && \
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
        if [ -z "$a" ]; then
          # A summary that normalises to NOTHING is derivable from no description at all,
          # and must not fall through to the prefix compare: `case "$b" in ""*)` is the
          # glob `*`, which matches every description and silently suppresses the warning.
          # Silent suppression of a report is the failure class this library exists to end.
          echo "warn: moc-sync: summary not derivable from current frontmatter: $slug" >&2
        else
          case "$b" in
            "$a"*) : ;;
            *) echo "warn: moc-sync: summary not derivable from current frontmatter: $slug" >&2 ;;
          esac
        fi
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

  # Rule 3(a): a harvested entry with no surviving note ANYWHERE on disk — keyed on seen_slugs,
  # not placed_slugs, so an off-map or unreadable note (already reported above, and plainly
  # present) is not additionally accused of not existing.
  #
  # THE MESSAGE SAYS "removed" BECAUSE THE ENTRY IS REMOVED. The spec's Testing table asks for
  # "reported, not deleted", and this deliberately diverges on the second half while honouring
  # the first: preserving an entry whose note is gone would emit a wiki-link to a file that does
  # not exist, which is precisely what validate-kernel.sh primitive 2 counts as a dangling link.
  # Satisfying one row of the contract by manufacturing the defect another primitive gates on is
  # not a fix. The anti-pattern that row names is SILENT deletion; this is loud. A message that
  # said "not removed" while removing would be the very mismatch this library exists to end —
  # and the first version of this line said exactly that.
  local hslug=""
  while IFS= read -r hslug; do
    [ -n "$hslug" ] || continue
    case "
$seen_slugs" in
      *"
$hslug
"*) : ;;
      *) echo "warn: moc-sync: entry has no note on disk, removed from the MOC: $hslug" >&2 ;;
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
    printf '       . ops/lib/frontmatter.sh && . ops/lib/moc-sync.sh &&\n'
    printf '       rebuild_status_moc <moc-file> <notes-dir> <map> -->\n\n'
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
