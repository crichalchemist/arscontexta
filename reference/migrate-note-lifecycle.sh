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

# An empty nodes/ means the caller pointed this at the wrong tree. Under bash an
# unmatched glob expands to itself, so without this the literal pattern would be
# processed as one unreadable "file" and reported as a refusal.
set -- "$VAULT"/nodes/*.md
[ -e "$1" ] || { echo "error: no .md files under $VAULT/nodes/" >&2; exit 1; }

changed=0; stripped=0; stamped=0; mapped=0; refused=0

# END owns the only `exit`. In awk an `exit` inside a rule does not return its
# code -- it jumps to END, and an `exit` there overrides it. Written the obvious
# way (`$0=="---" { exit 0 } END { exit 1 }`) this guard refuses every
# well-formed file, and the script then reports `files changed: 0` and exits 0.
has_frontmatter() { # has_frontmatter <file> -- needs BOTH delimiters
  awk 'NR==1 { if ($0!="---") exit; next } $0=="---" { found=1; exit } END { exit (found?0:1) }' "$1"
}

# stat's flag for "permission bits" differs between GNU and BSD, and the two
# spellings COLLIDE: on GNU, `stat -f` means --file-system, so probing BSD-first
# prints filesystem data AND exits 1, the `||` appends the GNU output, and the
# caller gets a multi-line blob that is non-empty and not a mode. GNU's `-c` is
# not a BSD flag at all, so it simply fails there -- probing it first has no such
# collision. The result is then validated as octal, because "non-empty" is not
# the same test as "is a file mode".
file_mode() { # file_mode <file> -> 3-4 octal digits, or empty
  m=$(stat -c '%a' "$1" 2>/dev/null) || m=$(stat -f '%OLp' "$1" 2>/dev/null) || m=""
  case "$m" in
    [0-7][0-7][0-7]|[0-7][0-7][0-7][0-7]) printf '%s' "$m" ;;
    *) printf '' ;;
  esac
}

# exit 0 = changed, 1 = nothing to do, 3 = malformed, refuse the file
transform() { # transform <file> <classfile> -> stdout
  awk -v CLASS="$2" -v SQ="'" '
    function unquote(s,   a,z) {
      a=substr(s,1,1); z=substr(s,length(s),1)
      if (length(s)>=2 && a==z && (a=="\"" || a==SQ)) return substr(s,2,length(s)-2)
      return s
    }
    # A trailing dot is only a sentence terminator when the token carrying it is
    # not an abbreviation. Three classes, each measured in the field vault:
    #   - a known abbreviation      "... represented Mr."   (4 notes)
    #   - a single-character token  "... constant C."       (1 note, an initial)
    #   - a token with an interior dot "... in the U.S."    (0 notes, guarded anyway)
    # Without this the migration silently rewrites `Mr.` to `Mr`.
    function ends_abbrev(s,   n, w, base, parts) {
      n = split(s, parts, /[[:space:]]+/)
      w = parts[n]
      if (w !~ /\.$/) return 0
      base = substr(w, 1, length(w)-1)
      if (base == "")             return 0
      # LETTERS only, not digits. `Ch. 6.` and `Ch. 8.` end in a bare numeral
      # whose dot IS a sentence terminator; only an initial like `constant C.`
      # is an abbreviation.
      if (base ~ /^[A-Za-z]$/)    return 1
      # Purely alphabetic dotted forms only -- `U.S.`, `e.g.`. Matching any
      # interior dot also matches decimals, so `(6.11% -> 13.39%).` was spared a
      # period that genuinely ends its sentence.
      if (base ~ /^[A-Za-z.]+$/ && base ~ /\./) return 1
      return (tolower(base) in ABBREV)
    }
    BEGIN {
      infm=0; seen_status=0; k_strip=0; k_stamp=0; k_map=0; malformed=0
      split("mr mrs ms dr prof rev hon st sen gov jr sr inc corp co ltd llc " \
            "etc vs al ave blvd rd no vol pp fig ch ed eds approx est cf ibid viz", A, " ")
      for (i in A) ABBREV[A[i]] = 1
    }
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
      # delimiter is only a delimiter when it is BALANCED on this line.
      body=$0; sub(/^description:[[:space:]]*/,"",body)
      a=substr(body,1,1)
      if ((a=="\"" || a==SQ) && !(length(body)>=2 && substr(body,length(body),1)==a)) {
        # A value that opens a quote it never closes is a multi-line scalar.
        # Stripping a period here would edit the MIDDLE of the value. Refuse the
        # whole file rather than guess where it ends.
        malformed=1; print; next
      }
      inner=unquote(body)
      q = (inner==body) ? "" : a
      if (inner ~ /\.$/ && inner !~ /\.\.$/ && length(inner)>1 && !ends_abbrev(inner)) {
        inner=substr(inner,1,length(inner)-1); k_strip=1
      }
      print "description: " q inner q; next
    }
    { print }
    END {
      if (malformed) exit 3
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
  has_frontmatter "$f" || { echo "refused (no closing --- delimiter): $f" >&2; refused=$((refused+1)); continue; }
  tmp=$(mktemp) || exit 1
  cls=$(mktemp) || { rm -f "$tmp"; exit 1; }
  transform "$f" "$cls" > "$tmp"; rc=$?

  if [ "$rc" -eq 3 ]; then
    echo "refused (description opens a quote it does not close): $f" >&2
    refused=$((refused+1))
  elif [ "$rc" -eq 0 ]; then
    # Two invariants before this file is replaced. `head -1` alone is not enough:
    # an output that lost its tail still begins `---`. The transform only ever
    # ADDS a line (the status backfill) and never removes one, so the output can
    # never legitimately be shorter than the input.
    #
    # This is NOT the guard against a full disk or a signal -- those make awk
    # exit non-zero, and a non-zero rc never reaches this branch. The `else`
    # below is what catches those. An earlier revision of this comment claimed
    # otherwise and was wrong.
    out_lines=$(wc -l < "$tmp"); in_lines=$(wc -l < "$f")
    if ! head -1 "$tmp" | /usr/bin/grep -q '^---$'; then
      echo "refused (bad output: no leading ---): $f" >&2; refused=$((refused+1))
    elif [ "$out_lines" -lt "$in_lines" ]; then
      echo "refused (bad output: $out_lines lines from $in_lines — truncated): $f" >&2
      refused=$((refused+1))
    else
      # Counters decompose by change kind. A single total agrees with the wrong
      # decomposition just as readily as the right one, and this script's whole
      # subject is a value silently not surviving a rewrite.
      s1=0; s2=0; s3=0
      read -r s1 s2 s3 < "$cls"
      stripped=$((stripped + s1)); stamped=$((stamped + s2)); mapped=$((mapped + s3))
      changed=$((changed+1))
      if [ "$APPLY" = "--apply" ]; then
        # mktemp creates 0600 and mv carries that mode onto the target. git
        # records only the executable bit, so a mode change here is invisible in
        # review -- every migrated note would silently become owner-read-only.
        # Fail CLOSED: an unreadable mode, or a chmod that does not take, stops
        # the run rather than writing the file with mktemp's 0600.
        mode=$(file_mode "$f")
        [ -n "$mode" ] || { rm -f "$tmp" "$cls"; echo "error: cannot read the mode of $f — refusing to write it as 0600" >&2; exit 1; }
        chmod "$mode" "$tmp" || { rm -f "$tmp" "$cls"; echo "error: chmod $mode failed for $f" >&2; exit 1; }
        mv "$tmp" "$f" || { rm -f "$tmp" "$cls"; echo "error: could not write $f" >&2; exit 1; }
        tmp=""
      fi
    fi
  elif [ "$rc" -ne 1 ]; then
    # rc 1 is the only remaining expected value: "this file needed no change".
    # ANY other code -- awk killed by a signal, out of memory, SIGXFSZ from a
    # file-size limit -- must be a refusal. Without this branch such a run
    # reports `files changed: 0 ... refused: 0` and exits 0, which is verbatim
    # the failure mode this script's header exists to prevent.
    echo "refused (transform exited $rc): $f" >&2
    refused=$((refused+1))
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
# cannot be read as a run that found nothing to do. Each refusal names its file
# on stderr above, because "inspect them" is useless across 2874 notes otherwise.
if [ "$refused" -gt 0 ]; then
  echo "error: $refused file(s) refused — named above; inspect them before trusting this run" >&2
  exit 2
fi
