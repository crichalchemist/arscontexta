#!/bin/bash
# link-extraction.test.sh — behavioral tests for the link-extraction library.
#
# WHY THIS EXISTS: CI previously ran only a textual guard and `bash -n`. It
# executed no library code, which is why a shell-dependent subshell bug, a
# swallowed dependency failure, and a locale-dependent fold all shipped.
#
# Run under BOTH shells: `bash …test.sh` and `zsh …test.sh`. Two known defects
# were bash/zsh forks; a single-shell run cannot see them.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
LIB="$HERE/../lib/link-extraction.sh"
passed=0; failed=0

ok()   { passed=$((passed+1)); }
fail() { failed=$((failed+1)); printf 'FAIL: %s\n       expected [%s] got [%s]\n' "$1" "$2" "$3"; }
eq()   { if [ "$2" = "$3" ]; then ok; else fail "$1" "$2" "$3"; fi; }

build_fixture() {
  local d="$1"
  mkdir -p "$d/notes/sub"
  printf -- '---\ntitle: real\ncreated: 2026-08-01\n---\nbody\n' > "$d/notes/real.md"
  printf -- '---\ntitle: alpha\ncreated: 2026-08-01\n---\nbody\n' > "$d/notes/alpha.md"
  printf -- '---\ntitle: Über\ncreated: 2026-08-01\n---\nbody\n' > "$d/notes/Über.md"
  printf -- 'Nested: [[buried-target]]\n'                        > "$d/notes/sub/nested.md"
  printf -- '---\ntitle: buried-target\n---\nbody\n'             > "$d/notes/sub/buried-target.md"
  {
    printf -- '---\ntitle: probe\ncreated: 2026-08-01\ntopics:\n'
    printf -- '  - "[[real]]"\n  - "[[Alpha|display name]]"\n---\n'
    printf -- 'Plain: [[real]]\nAlias: [[real|some alias]]\nAnchor: [[real#a-heading]]\n'
    printf -- 'Both:  [[real|alias#frag]]\nCase:  [[Alpha]]\nAccent: [[über]]\n'
    printf -- 'Ghost: [[nonexistent-note]]\n'
    printf -- '```\n[[in-code-fence]]\n```\n'
  } > "$d/notes/probe.md"
}

FIX=$(mktemp -d); build_fixture "$FIX"
. "$LIB"
N="$FIX/notes"

# --- extraction correctness -------------------------------------------------
eq "count_links excludes fenced links"        "9" "$(count_links "$N")"
eq "targets terminate at | and #"             "alpha nonexistent-note real über" \
   "$(extract_link_targets "$N" | tr '\n' ' ' | sed 's/ $//')"
eq "index folds case"                         "alpha probe real über" \
   "$(existing_note_index "$N" | tr '\n' ' ' | sed 's/ $//')"

# --- dangling resolution ----------------------------------------------------
dangling() {                       # dangling <extract-fn> <index-fn> <dir>
  local idx; idx=$("$2" "$3")
  "$1" "$3" | while IFS= read -r n; do
    [ -n "$n" ] && ! printf '%s\n' "$idx" | /usr/bin/grep -qxF "$n" && echo "$n"
  done | tr '\n' ' ' | sed 's/ $//'
}
eq "flat dangling finds only the ghost"       "nonexistent-note" \
   "$(dangling extract_link_targets existing_note_index "$N")"
eq "recursive resolves the nested target"     "nonexistent-note" \
   "$(dangling extract_link_targets_recursive existing_note_index_recursive "$N")"

# --- recursion --------------------------------------------------------------
eq "recursive sees subdirectories"            "yes" \
   "$(extract_link_targets_recursive "$N" | /usr/bin/grep -qx 'buried-target' && echo yes || echo no)"
eq "flat does NOT see subdirectories"         "no" \
   "$(extract_link_targets "$N" | /usr/bin/grep -qx 'buried-target' && echo yes || echo no)"
eq "count_links_recursive is shell-agnostic"  "10" "$(count_links_recursive "$N")"

# --- locale independence ----------------------------------------------------
eq "fold handles non-ASCII under LC_ALL=C"    "yes" \
   "$(LC_ALL=C sh -c ". '$LIB'; existing_note_index '$N'" | /usr/bin/grep -qx 'über' && echo yes || echo no)"

# --- failure must never be a number ----------------------------------------
eq "missing dir fails, emits no count"        "loud" \
   "$(out=$(count_links "$FIX/nope" 2>/dev/null); rc=$?; [ "$rc" -ne 0 ] && [ -z "$out" ] && echo loud || echo "silent:$out")"
eq "missing rg fails, emits no count"         "loud" \
   "$(out=$(PATH=/usr/bin:/bin sh -c ". '$LIB'; count_links '$N'" 2>/dev/null); rc=$?; \
      [ "$rc" -ne 0 ] && [ -z "$out" ] && echo loud || echo "silent:$out")"
BADRC=$(mktemp); printf -- '--nonexistent-flag-xyz\n' > "$BADRC"
eq "rg runtime failure fails loud"            "loud" \
   "$(out=$(RIPGREP_CONFIG_PATH="$BADRC" sh -c ". '$LIB'; count_links '$N'" 2>/dev/null); rc=$?; \
      [ "$rc" -ne 0 ] && [ -z "$out" ] && echo loud || echo "silent:$out")"
rm -f "$BADRC"
eq "library declares a contract version"      "yes" \
   "$([ "${LINK_EXTRACTION_VERSION:-0}" -ge 1 ] 2>/dev/null && echo yes || echo no)"

rm -rf "$FIX"
printf '\npassed=%s failed=%s\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
