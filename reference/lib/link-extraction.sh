#!/bin/bash
# link-extraction.sh — the single definition of wiki-link counting and resolution.
#
# Sourced by skill templates and by validate-kernel.sh. Do NOT inline copies of
# these functions anywhere; check-portability.sh enforces that.
#
# FLAT vs RECURSIVE:
# Flat functions (count_links, extract_link_targets, existing_note_index) scan
# a single directory only. Recursive variants (*_recursive) scan a directory
# tree using find. Use recursive variants when scanning vault directories with
# subdirectories (validate-kernel.sh, health). Use flat variants for single-level
# dirs (stats, graph scanning {vocabulary.notes} as flat collection).
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
LINK_EXTRACTION_VERSION=1

# Case folding needs UTF-8 locale. No single locale name exists on every platform
# (C.UTF-8 absent on macOS; en_US.UTF-8 absent on Alpine), naming missing one
# silently degrades ASCII folding exit 0.
_LINK_FOLD_LOCALE=""
for _c in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do
  if locale -a 2>/dev/null | /usr/bin/grep -qx "$_c"; then
    _LINK_FOLD_LOCALE="$_c"
    break
  fi
done
if [ -z "$_LINK_FOLD_LOCALE" ]; then
  echo "error: link-extraction requires UTF-8 locale case folding; none found" >&2
  echo " (looked for: C.UTF-8, C.utf8, en_US.UTF-8, en_US.utf8)" >&2
  exit 1
fi

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
  local dir="$1" tmpf tmpcount
  tmpf=$(mktemp) || return 1
  tmpcount=$(mktemp) || { rm -f "$tmpf"; return 1; }

  find "$dir" -maxdepth 1 -type f -name '*.md' | while IFS= read -r f; do
    _strip_fences "$f" > "$tmpf" || exit 1
    rg -o '\[\[' "$tmpf" >> "$tmpcount" 2>/dev/null || [ $? -le 1 ] || exit 1
  done
  local result=$?

  if [ $result -ne 0 ]; then
    rm -f "$tmpf" "$tmpcount"
    return 1
  fi

  if [ -s "$tmpcount" ]; then
    wc -l < "$tmpcount" | tr -d ' '
  else
    printf '0'
  fi

  rm -f "$tmpf" "$tmpcount"
}

# extract_link_targets <dir> -> newline-separated folded unique targets
extract_link_targets() {
  _require_deps_and_dir "$1" || return 1
  local dir="$1" tmpf tmpdata
  tmpf=$(mktemp) || return 1
  tmpdata=$(mktemp) || { rm -f "$tmpf"; return 1; }

  find "$dir" -maxdepth 1 -type f -name '*.md' | while IFS= read -r f; do
    _strip_fences "$f" >> "$tmpdata" || exit 1
  done || { rm -f "$tmpf" "$tmpdata"; return 1; }

  rg -o '\[\[([^\]|#]+)' -r '$1' "$tmpdata" > "$tmpf" 2>/dev/null
  local rg_rc=$?

  if [ "$rg_rc" -gt 1 ]; then
    rm -f "$tmpf" "$tmpdata"
    return 1
  fi

  cat "$tmpf" \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | LC_ALL="$_LINK_FOLD_LOCALE" tr '[:upper:]' '[:lower:]' | sort -u

  rm -f "$tmpf" "$tmpdata"
}

# existing_note_index <dir> -> newline-separated folded basenames
existing_note_index() {
  _require_deps_and_dir "$1" || return 1
  local dir="$1" p
  for p in "$dir"/*.md; do
    [ -e "$p" ] || continue
    basename "$p" .md
  done | LC_ALL="$_LINK_FOLD_LOCALE" tr '[:upper:]' '[:lower:]' | sort -u
}

# count_links_recursive <dir> -> integer (scans directory tree)
count_links_recursive() {
  _require_deps_and_dir "$1" || return 1
  find "$1" -type f -name '*.md' | while IFS= read -r f; do
    _strip_fences "$f" | rg -o '\[\['
  done | wc -l | tr -d ' '
}

# extract_link_targets_recursive <dir> -> newline-separated folded unique targets (scans directory tree)
extract_link_targets_recursive() {
  _require_deps_and_dir "$1" || return 1
  local dir="$1" tmpf tmpdata
  tmpf=$(mktemp) || return 1
  tmpdata=$(mktemp) || { rm -f "$tmpf"; return 1; }

  find "$dir" -type f -name '*.md' | while IFS= read -r f; do
    _strip_fences "$f" >> "$tmpdata" || exit 1
  done || { rm -f "$tmpf" "$tmpdata"; return 1; }

  rg -o '\[\[([^\]|#]+)' -r '$1' "$tmpdata" > "$tmpf" 2>/dev/null
  local rg_rc=$?

  if [ "$rg_rc" -gt 1 ]; then
    rm -f "$tmpf" "$tmpdata"
    return 1
  fi

  cat "$tmpf" \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | LC_ALL="$_LINK_FOLD_LOCALE" tr '[:upper:]' '[:lower:]' | sort -u

  rm -f "$tmpf" "$tmpdata"
}

# existing_note_index_recursive <dir> -> newline-separated folded basenames (scans directory tree)
existing_note_index_recursive() {
  _require_deps_and_dir "$1" || return 1
  local dir="$1" p
  find "$dir" -type f -name '*.md' | while IFS= read -r p; do
    basename "$p" .md
  done | LC_ALL="$_LINK_FOLD_LOCALE" tr '[:upper:]' '[:lower:]' | sort -u
}
