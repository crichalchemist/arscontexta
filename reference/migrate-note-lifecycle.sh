#!/bin/bash
# migrate-note-lifecycle.sh — ONE-TIME migration. Delete after it runs.
#
# Edits the RAW LINE. It never rebuilds a parsed value: reading through
# frontmatter_field strips balanced quotes, and a write built from that output
# loses them. See the design doc for the 473 files that would break.
#
# Fail loud: every way this script can be handed nothing to do exits non-zero
# rather than printing a clean zero. Exit 0 with empty output is this repo's
# documented failure mode and the reason this migration is reviewed at all.
set -u
VAULT="${1:?usage: migrate-note-lifecycle.sh <vault-dir> [--apply]}"
APPLY="${2:-}"
[ -d "$VAULT/nodes" ] || { echo "error: no nodes/ under $VAULT" >&2; exit 1; }
command -v awk >/dev/null || { echo "error: awk required" >&2; exit 1; }

# The glob below is the only source of work. Under zsh an unmatched glob is an
# error and under bash it expands to itself; either way an empty nodes/ means
# the caller pointed this at the wrong tree, so say so instead of reporting 0.
set -- "$VAULT"/nodes/*.md
[ -e "$1" ] || { echo "error: no .md files under $VAULT/nodes/" >&2; exit 1; }

changed=0; stripped=0; stamped=0; mapped=0; refused=0

# Only a file with BOTH an opening and a closing `---` is frontmatter. Without
# the closing delimiter every body line would still be inside the frontmatter
# state and a body line beginning `status:` or `description:` would be rewritten.
#
# END owns the only `exit`. In awk an `exit 0` inside a rule does not return 0 --
# it jumps to END, and an `exit` there overrides it. Written the obvious way
# (`$0=="---" { exit 0 } END { exit 1 }`) this guard refuses every well-formed
# file, and the script then reports `files changed: 0` and exits 0.
has_frontmatter() { # has_frontmatter <file>
  awk 'NR==1 { if ($0!="---") exit; next } $0=="---" { found=1; exit } END { exit (found?0:1) }' "$1"
}

transform() { # transform <file> <classfile> -> stdout; exit 0 if it changed
  awk -v CLASS="$2" -v SQ="'" '
    function unquote(s,   a,z) {
      a=substr(s,1,1); z=substr(s,length(s),1)
      if (length(s)>=2 && a==z && (a=="\"" || a==SQ)) return substr(s,2,length(s)-2)
      return s
    }
    BEGIN { infm=0; seen_status=0; k_strip=0; k_stamp=0; k_map=0 }
    NR==1 && $0=="---" { infm=1; print; next }
    infm && $0=="---" {
      # BACKFILL IS `active`, NOT `preliminary`. The statusless notes predate
      # the stamp; `active` asserts they exist and are reachable, nothing about
      # quality. `preliminary` would assert the opposite claim, equally unearned.
      # The migration commit is what distinguishes these from promoted notes.
      if (!seen_status) { print "status: active"; k_stamp=1 }
      infm=0; print; next
    }
    infm && /^status:/ {
      seen_status=1
      v=$0; sub(/^status:[[:space:]]*/,"",v); v=unquote(v)
      if (v=="closed")        { print "status: archived"; k_map=1; next }
      if (v=="verified" || v=="valid" || v=="evergreen") { print "status: active"; k_map=1; next }
      if (v=="investigating") { print "status: open"; k_map=1; next }
      print; next
    }
    infm && /^description:/ {
      # Split into prefix, delimiter, interior, delimiter -- never parse. The
      # delimiter is only a delimiter when it is BALANCED: a value that merely
      # starts with a quote is left whole rather than truncated by one char.
      body=$0; sub(/^description:[[:space:]]*/,"",body)
      inner=unquote(body)
      q = (inner==body) ? "" : substr(body,1,1)
      if (inner ~ /\.$/ && inner !~ /\.\.$/ && length(inner)>1) {
        inner=substr(inner,1,length(inner)-1); k_strip=1
      }
      print "description: " q inner q; next
    }
    { print }
    END {
      if (k_strip || k_stamp || k_map) {
        printf "%d %d %d\n", k_strip, k_stamp, k_map > CLASS
        exit 0
      }
      exit 1
    }
  ' "$1"
}

for f in "$VAULT"/nodes/*.md; do
  [ -r "$f" ] || { echo "refused (unreadable): $f" >&2; refused=$((refused+1)); continue; }
  has_frontmatter "$f" || { refused=$((refused+1)); continue; }
  tmp=$(mktemp) || exit 1
  cls=$(mktemp) || { rm -f "$tmp"; exit 1; }
  if transform "$f" "$cls" > "$tmp"; then
    if head -1 "$tmp" | /usr/bin/grep -q '^---$'; then
      # Counters decompose by change kind. A single total agrees with the wrong
      # decomposition just as readily as the right one, and this script's whole
      # subject is a value silently not surviving a rewrite.
      read -r s1 s2 s3 < "$cls"
      stripped=$((stripped + s1)); stamped=$((stamped + s2)); mapped=$((mapped + s3))
      changed=$((changed+1))
      if [ "$APPLY" = "--apply" ]; then
        mv "$tmp" "$f" || { rm -f "$tmp" "$cls"; echo "error: could not write $f" >&2; exit 1; }
        tmp=""
      fi
    else
      echo "refused (bad output): $f" >&2; refused=$((refused+1))
    fi
  fi
  [ -n "$tmp" ] && rm -f "$tmp"
  rm -f "$cls"
done

printf 'files changed: %s   stripped: %s   stamped: %s   mapped: %s   refused: %s   (%s)\n' \
  "$changed" "$stripped" "$stamped" "$mapped" "$refused" \
  "$([ "$APPLY" = "--apply" ] && echo applied || echo 'DRY RUN — pass --apply to write')"

# A refusal is an anomaly, not a routine skip: every note in the target corpus is
# expected to have frontmatter. Exit 2 -- distinct from the exit 1 that means
# "you pointed me at the wrong tree" -- so a run that quietly bounced its input
# cannot be read as a run that found nothing to do. This exists because the
# frontmatter guard above did precisely that.
if [ "$refused" -gt 0 ]; then
  echo "error: $refused file(s) refused — inspect them before trusting this run" >&2
  exit 2
fi
