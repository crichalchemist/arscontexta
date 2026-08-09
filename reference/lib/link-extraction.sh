#!/bin/bash
# link-extraction.sh — the single definition of wiki-link counting and resolution.
#
# Sourced by skill templates and by validate-kernel.sh. Do NOT inline copies of
# these functions anywhere.
#
# NOTHING ENFORCES THAT SENTENCE. It used to end "check-portability.sh enforces
# that", and that was false. That script runs seven checks — PCRE grep, wiki-link
# capture using negated classes, PCRE via ripgrep, the frozen skill-blocks
# manifest, AGENTS.md being a symlink, interpolated wiki-link matchers, and
# hand-rolled frontmatter parsing — and none detects an inlined copy of
# anything defined HERE. Check 7 is the near miss to be precise about: it bans
# inlining reference/lib/frontmatter.sh, the OTHER library, and covers nothing
# in this file. The rule here is real and still binding; the enforcement is
# convention. Believing otherwise is how a green run gets read as proof, which is
# what happened: matcher sites survived four gates for months. Owner of the gap:
# the CI-hardening spec.
#
# Writing or editing a SKILL.md? Read reference/skill-authoring.md — which tree
# you are in, placeholder families, when a fail-loud guard fires, and what makes a
# prose contract complete. This pointer is here because it was measured: agents
# asked to add a counting fence read this file in full and never found that one.
#
# FLAT vs RECURSIVE:
# Flat functions (count_links, extract_link_targets, existing_note_index) scan
# a single directory only. Recursive variants (*_recursive) scan a directory
# tree using find.
#
# THE RECURSIVE VARIANTS ARE THE DEFAULT. A vault directory that has no
# subdirectories today may grow one tomorrow, and the flat scan will not say so
# — it silently under-reports rather than failing. The flat variants remain for
# callers that deliberately want a single directory; choosing flat where
# recursive was meant produces a plausible wrong number, so prefer recursive
# unless you can justify otherwise.
#
# A consumer that calls a _recursive variant MUST also enumerate its own files
# recursively. Mixing the two is worse than either alone: counting links over a
# nested tree while counting notes over one directory made graph's density read
# 5.00, and density is links/possible-links, so it cannot exceed 1.
#
# Correctness requirements encoded here:
#   1. No PCRE regex grep — absent from BSD grep, and it fails silently to 0.
#   2. Fenced code blocks are not edges — ``` examples must not count as links.
#   3. Targets terminate at `|` and `#` — [[slug|alias]] and [[slug#head]] resolve
#      to `slug`, not to the whole string.
#   4. Case folds on BOTH sides — index AND extraction both lowercase. [[Zettelkasten]]
#      must match file Zettelkasten.md on case-insensitive filesystems and
#      mismatches on case-sensitive ones. Delegate case handling to BOTH sides or
#      neither. Folding only one side (e.g., search via rg without -i over mixed-case
#      filesystem) violates this and produces false positives.

# Contract version. Bump on any BEHAVIOR change (fold rules, termination, recursion semantics).
LINK_EXTRACTION_VERSION=3

# Case folding must fold NON-ASCII, and neither a locale name nor a tool name is
# enough to know that it will:
#   BSD tr folds multibyte in a UTF-8 locale; GNU tr is byte-oriented in EVERY locale.
#   gawk folds multibyte; mawk -- the default awk on Debian/Ubuntu -- does not.
#   GNU sed supports \L; BSD sed treats it as a literal L.
# Probing for a locale NAME therefore verifies a proxy, not the property: it found
# C.utf8 on ubuntu-latest and folding still failed. Probe the BEHAVIOR instead --
# fold U+00DC and require U+00FC back -- and keep the first candidate that passes.
_LINK_FOLD_MODE=""
_LINK_FOLD_LOCALE=""

_link_probe_fold() {
  [ -n "$_LINK_FOLD_MODE" ] && return 0        # probe once per shell, not per call
  local up low locs c
  up=$(printf '\303\234')                      # U+00DC capital U with diaeresis
  low=$(printf '\303\274')                     # U+00FC small u with diaeresis
  locs=$(locale -a 2>/dev/null)
  for c in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do
    printf '%s\n' "$locs" | /usr/bin/grep -qx "$c" || continue
    if [ "$(printf '%s\n' "$up" | LC_ALL="$c" tr '[:upper:]' '[:lower:]' 2>/dev/null)" = "$low" ]; then
      _LINK_FOLD_LOCALE="$c"; _LINK_FOLD_MODE=tr; return 0
    fi
    if [ "$(printf '%s\n' "$up" | LC_ALL="$c" awk '{print tolower($0)}' 2>/dev/null)" = "$low" ]; then
      _LINK_FOLD_LOCALE="$c"; _LINK_FOLD_MODE=awk; return 0
    fi
    if [ "$(printf '%s\n' "$up" | LC_ALL="$c" sed 's/.*/\L&/' 2>/dev/null)" = "$low" ]; then
      _LINK_FOLD_LOCALE="$c"; _LINK_FOLD_MODE=sed; return 0
    fi
  done
  # Nothing here folds non-ASCII. Degrade to ASCII-only rather than refusing to run
  # (an all-ASCII vault is unaffected), but SAY SO on stderr. A silent degrade is
  # precisely the defect class this library exists to remove.
  _LINK_FOLD_LOCALE=C
  _LINK_FOLD_MODE=ascii
  echo "warning: link-extraction: no non-ASCII case folding on this system (tried tr, awk and" >&2
  echo "  sed under C.UTF-8, C.utf8, en_US.UTF-8, en_US.utf8); a link differing from a filename" >&2
  echo "  only by non-ASCII case will be reported dangling" >&2
  return 0
}
_link_probe_fold

# _fold_lower: stdin -> stdout, lowercased by whichever tool the probe PROVED works here.
_fold_lower() {
  case "$_LINK_FOLD_MODE" in
    tr)  LC_ALL="$_LINK_FOLD_LOCALE" tr '[:upper:]' '[:lower:]' ;;
    awk) LC_ALL="$_LINK_FOLD_LOCALE" awk '{print tolower($0)}' ;;
    sed) LC_ALL="$_LINK_FOLD_LOCALE" sed 's/.*/\L&/' ;;
    *)   LC_ALL=C tr '[:upper:]' '[:lower:]' ;;
  esac
}

# Check dependencies and directory argument.
_require_deps_and_dir() { # _require_deps_and_dir <dir>
  local dir="$1"
  if ! command -v rg >/dev/null 2>&1; then
    echo "error: link-extraction requires 'rg', not found in PATH" >&2
    return 1
  fi
  if ! command -v awk >/dev/null 2>&1; then
    echo "error: link-extraction requires 'awk', not found in PATH" >&2
    return 1
  fi
  if [ -z "$dir" ] || [ ! -d "$dir" ]; then
    echo "error: link-extraction: not directory: '${dir:-<empty>}'" >&2
    return 1
  fi
  return 0
}

# Strip fenced code blocks from one file, emit remaining lines.
_strip_fences() {
  if ! command -v awk >/dev/null 2>&1; then
    echo "error: link-extraction library requires 'awk', not found in PATH" >&2
    return 1
  fi
  awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$1"
}

# count_links <dir> -> integer
count_links() {
  _require_deps_and_dir "$1" || return 1
  local dir="$1" tmpf tmpcount errf
  tmpf=$(mktemp) || return 1
  tmpcount=$(mktemp) || { rm -f "$tmpf"; return 1; }
  errf="/tmp/link-extraction-err-$$"

  find "$dir" -maxdepth 1 -type f -name '*.md' | while IFS= read -r f; do
    if ! _strip_fences "$f" > "$tmpf" 2>/dev/null; then
      touch "$errf"
      continue
    fi
    rg -o '\[\[' "$tmpf" >> "$tmpcount" 2>/dev/null
    if [ $? -gt 1 ]; then
      touch "$errf"
    fi
  done

  if [ -e "$errf" ]; then
    rm -f "$tmpf" "$tmpcount" "$errf"
    return 1
  fi

  if [ -s "$tmpcount" ]; then
    wc -l < "$tmpcount" | tr -d ' '
  else
    printf '0'
  fi

  rm -f "$tmpf" "$tmpcount" "$errf"
}

# extract_link_targets <dir> -> newline-separated folded unique targets
extract_link_targets() {
  _require_deps_and_dir "$1" || return 1
  local dir="$1" tmpf tmpdata errf
  tmpf=$(mktemp) || return 1
  tmpdata=$(mktemp) || { rm -f "$tmpf"; return 1; }
  errf="/tmp/link-extraction-err-$$"

  find "$dir" -maxdepth 1 -type f -name '*.md' | while IFS= read -r f; do
    if ! _strip_fences "$f" >> "$tmpdata" 2>/dev/null; then
      touch "$errf"
    fi
  done

  if [ -e "$errf" ]; then
    rm -f "$tmpf" "$tmpdata" "$errf"
    return 1
  fi

  rg -o '\[\[([^\]|#]+)' -r '$1' "$tmpdata" > "$tmpf" 2>/dev/null
  local rg_rc=$?

  if [ "$rg_rc" -gt 1 ]; then
    rm -f "$tmpf" "$tmpdata" "$errf"
    return 1
  fi

  cat "$tmpf" \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | _fold_lower | sort -u

  rm -f "$tmpf" "$tmpdata" "$errf"
}

# existing_note_index <dir> -> newline-separated folded basenames
existing_note_index() {
  _require_deps_and_dir "$1" || return 1
  local dir="$1" p
  for p in "$dir"/*.md; do
    [ -e "$p" ] || continue
    basename "$p" .md
  done | _fold_lower | sort -u
}

# count_links_recursive <dir> -> integer (scans directory tree)
count_links_recursive() {
  _require_deps_and_dir "$1" || return 1
  local tmpf tmpcount errf
  tmpf=$(mktemp) || return 1
  tmpcount=$(mktemp) || { rm -f "$tmpf"; return 1; }
  errf="/tmp/link-extraction-err-$$"

  find "$1" -type f -name '*.md' | while IFS= read -r f; do
    if ! _strip_fences "$f" > "$tmpf" 2>/dev/null; then
      touch "$errf"
      continue
    fi
    rg -o '\[\[' "$tmpf" >> "$tmpcount" 2>/dev/null
    if [ $? -gt 1 ]; then
      touch "$errf"
    fi
  done

  if [ -e "$errf" ]; then
    rm -f "$tmpf" "$tmpcount" "$errf"
    return 1
  fi

  if [ -s "$tmpcount" ]; then
    wc -l < "$tmpcount" | tr -d ' '
  else
    printf '0'
  fi

  rm -f "$tmpf" "$tmpcount" "$errf"
}

# extract_link_targets_recursive <dir> -> newline-separated folded unique targets (scans directory tree)
extract_link_targets_recursive() {
  _require_deps_and_dir "$1" || return 1
  local dir="$1" tmpf tmpdata errf
  tmpf=$(mktemp) || return 1
  tmpdata=$(mktemp) || { rm -f "$tmpf"; return 1; }
  errf="/tmp/link-extraction-err-$$"

  find "$dir" -type f -name '*.md' | while IFS= read -r f; do
    if ! _strip_fences "$f" >> "$tmpdata" 2>/dev/null; then
      touch "$errf"
    fi
  done

  if [ -e "$errf" ]; then
    rm -f "$tmpf" "$tmpdata" "$errf"
    return 1
  fi

  rg -o '\[\[([^\]|#]+)' -r '$1' "$tmpdata" > "$tmpf" 2>/dev/null
  local rg_rc=$?

  if [ "$rg_rc" -gt 1 ]; then
    rm -f "$tmpf" "$tmpdata" "$errf"
    return 1
  fi

  cat "$tmpf" \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | _fold_lower | sort -u

  rm -f "$tmpf" "$tmpdata" "$errf"
}

# existing_note_index_recursive <dir> -> newline-separated folded basenames (scans directory tree)
existing_note_index_recursive() {
  _require_deps_and_dir "$1" || return 1
  local dir="$1" p
  find "$dir" -type f -name '*.md' | while IFS= read -r p; do
    basename "$p" .md
  done | _fold_lower | sort -u
}

# link_edge_map <dir> -> source<TAB>target edges (flat, no recursion)
# Emits one tab-separated line per (source, target) pair found in <dir>'s markdown files.
# Fenced code blocks are excluded. Targets are folded to lowercase.
# Self-edges ARE included; backlink_counts filters them at the next layer.
link_edge_map() {
  _require_deps_and_dir "$1" || return 1
  local dir="$1" f src stripped errf tmpdata rgtmp
  stripped=$(mktemp) || return 1
  tmpdata=$(mktemp) || { rm -f "$stripped"; return 1; }
  rgtmp=$(mktemp) || { rm -f "$stripped" "$tmpdata"; return 1; }
  errf="/tmp/link-extraction-err-$$"

  find "$dir" -maxdepth 1 -type f -name '*.md' | while IFS= read -r f; do
    src=$(basename "$f" .md | _fold_lower)
    if ! _strip_fences "$f" > "$stripped" 2>/dev/null; then
      touch "$errf"
      continue
    fi
    rg -o '\[\[([^\]|#]+)' -r '$1' "$stripped" 2>/dev/null > "$rgtmp"
    if [ $? -gt 1 ]; then
      touch "$errf"
      continue
    fi
    cat "$rgtmp" \
      | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
      | _fold_lower \
      | while IFS= read -r tgt; do
        [ -n "$tgt" ] || continue
        printf '%s\t%s\n' "$src" "$tgt"
      done >> "$tmpdata"
  done

  if [ -e "$errf" ]; then
    rm -f "$stripped" "$tmpdata" "$rgtmp" "$errf"
    return 1
  fi

  cat "$tmpdata"
  rm -f "$stripped" "$tmpdata" "$rgtmp" "$errf"
}

# link_edge_map_recursive <dir> -> source<TAB>target edges (recursive tree scan)
link_edge_map_recursive() {
  _require_deps_and_dir "$1" || return 1
  local dir="$1" f src stripped errf tmpdata rgtmp
  stripped=$(mktemp) || return 1
  tmpdata=$(mktemp) || { rm -f "$stripped"; return 1; }
  rgtmp=$(mktemp) || { rm -f "$stripped" "$tmpdata"; return 1; }
  errf="/tmp/link-extraction-err-$$"

  find "$dir" -type f -name '*.md' -not -path '*/.git/*' | while IFS= read -r f; do
    src=$(basename "$f" .md | _fold_lower)
    if ! _strip_fences "$f" > "$stripped" 2>/dev/null; then
      touch "$errf"
      continue
    fi
    rg -o '\[\[([^\]|#]+)' -r '$1' "$stripped" 2>/dev/null > "$rgtmp"
    if [ $? -gt 1 ]; then
      touch "$errf"
      continue
    fi
    cat "$rgtmp" \
      | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
      | _fold_lower \
      | while IFS= read -r tgt; do
        [ -n "$tgt" ] || continue
        printf '%s\t%s\n' "$src" "$tgt"
      done >> "$tmpdata"
  done

  if [ -e "$errf" ]; then
    rm -f "$stripped" "$tmpdata" "$rgtmp" "$errf"
    return 1
  fi

  cat "$tmpdata"
  rm -f "$stripped" "$tmpdata" "$rgtmp" "$errf"
}

# backlink_counts <dir> -> "<target>\t<count>", self-edges excluded, sorted by target.
# A target with zero incoming links is ABSENT, not a zero row.
backlink_counts() {
  local edges
  edges=$(mktemp) || return 1
  link_edge_map "$1" > "$edges" || { rm -f "$edges"; return 1; }

  LC_ALL=C awk -F'\t' '$1 != $2 { print $2 }' "$edges" \
    | LC_ALL=C sort \
    | uniq -c \
    | LC_ALL=C awk '{ c=$1; $1=""; sub(/^ /,""); printf "%s\t%s\n", $0, c }'

  rm -f "$edges"
}

# backlink_counts_recursive <dir> -> same as backlink_counts but descends subdirectories.
backlink_counts_recursive() {
  local edges
  edges=$(mktemp) || return 1
  link_edge_map_recursive "$1" > "$edges" || { rm -f "$edges"; return 1; }

  LC_ALL=C awk -F'\t' '$1 != $2 { print $2 }' "$edges" \
    | LC_ALL=C sort \
    | uniq -c \
    | LC_ALL=C awk '{ c=$1; $1=""; sub(/^ /,""); printf "%s\t%s\n", $0, c }'

  rm -f "$edges"
}
