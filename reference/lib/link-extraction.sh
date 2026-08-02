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
  if ! command -v rg >/dev/null 2>&1; then
    echo "error: link-extraction library requires 'rg', not found in PATH" >&2
    return 1
  fi
  if ! command -v awk >/dev/null 2>&1; then
    echo "error: link-extraction library requires 'awk', not found in PATH" >&2
    return 1
  fi
  local dir="$1" f
  local n=0
  for f in "$dir"/*.md; do
    [ -e "$f" ] || continue
    n=$(( n + $(_strip_fences "$f" | rg -o '\[\[' 2>/dev/null | wc -l | tr -d ' ') ))
  done
  printf '%s' "$n"
}

# extract_link_targets <dir> -> newline-separated folded unique targets
extract_link_targets() {
  if ! command -v rg >/dev/null 2>&1; then
    echo "error: link-extraction library requires 'rg', not found in PATH" >&2
    return 1
  fi
  if ! command -v awk >/dev/null 2>&1; then
    echo "error: link-extraction library requires 'awk', not found in PATH" >&2
    return 1
  fi
  local dir="$1" f
  for f in "$dir"/*.md; do
    [ -e "$f" ] || continue
    _strip_fences "$f"
  done | rg -o '\[\[([^\]|#]+)' -r '$1' 2>/dev/null \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | tr '[:upper:]' '[:lower:]' | sort -u
}

# existing_note_index <dir> -> newline-separated folded basenames
existing_note_index() {
  local dir="$1" p
  for p in "$dir"/*.md; do
    [ -e "$p" ] || continue
    basename "$p" .md
  done | tr '[:upper:]' '[:lower:]' | sort -u
}

# count_links_recursive <dir> -> integer (scans directory tree)
count_links_recursive() {
  if ! command -v rg >/dev/null 2>&1; then
    echo "error: link-extraction library requires 'rg', not found in PATH" >&2
    return 1
  fi
  if ! command -v awk >/dev/null 2>&1; then
    echo "error: link-extraction library requires 'awk', not found in PATH" >&2
    return 1
  fi
  local dir="$1" f
  local n=0
  find "$dir" -type f -name '*.md' | while IFS= read -r f; do
    n=$(( n + $(_strip_fences "$f" | rg -o '\[\[' 2>/dev/null | wc -l | tr -d ' ') ))
  done
  printf '%s' "$n"
}

# extract_link_targets_recursive <dir> -> newline-separated folded unique targets (scans directory tree)
extract_link_targets_recursive() {
  if ! command -v rg >/dev/null 2>&1; then
    echo "error: link-extraction library requires 'rg', not found in PATH" >&2
    return 1
  fi
  if ! command -v awk >/dev/null 2>&1; then
    echo "error: link-extraction library requires 'awk', not found in PATH" >&2
    return 1
  fi
  local dir="$1" f
  find "$dir" -type f -name '*.md' | while IFS= read -r f; do
    _strip_fences "$f"
  done | rg -o '\[\[([^\]|#]+)' -r '$1' 2>/dev/null \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | tr '[:upper:]' '[:lower:]' | sort -u
}

# existing_note_index_recursive <dir> -> newline-separated folded basenames (scans directory tree)
existing_note_index_recursive() {
  local dir="$1" p
  find "$dir" -type f -name '*.md' | while IFS= read -r p; do
    basename "$p" .md
  done | tr '[:upper:]' '[:lower:]' | sort -u
}
