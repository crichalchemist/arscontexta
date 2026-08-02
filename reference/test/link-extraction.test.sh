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

# Every assertion that needs a fresh shell must spawn THIS harness's shell, not
# `sh`. On macOS `sh` is bash 3.2 regardless of what launched the harness, so
# `sh -c` sites silently ran the bash path even under `zsh …test.sh` — which
# defeats the promise made at the top of this file. Verified: `sh -c 'echo
# ${ZSH_VERSION:-unset}'` prints `unset` when invoked from zsh.
if [ -n "${ZSH_VERSION:-}" ]; then SELF=zsh; else SELF=bash; fi

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
   "$(LC_ALL=C "$SELF" -c ". '$LIB'; existing_note_index '$N'" | /usr/bin/grep -qx 'über' && echo yes || echo no)"

# --- failure must never be a number ----------------------------------------
eq "missing dir fails, emits no count"        "loud" \
   "$(out=$(count_links "$FIX/nope" 2>/dev/null); rc=$?; [ "$rc" -ne 0 ] && [ -z "$out" ] && echo loud || echo "silent:$out")"
# PATH must point at a directory that genuinely has no rg. /usr/bin:/bin does NOT
# qualify everywhere: apt installs ripgrep to /usr/bin/rg, so on Linux this left rg
# on PATH, count_links correctly returned a number, and the assertion failed against
# a library that was behaving. An empty directory holds the precondition on every
# platform. (The library's own deps check also needs awk, which is likewise absent
# here -- either missing dep must fail loud, which is what this asserts.)
NOBIN="$FIX/nobin"; mkdir -p "$NOBIN"
eq "missing rg fails, emits no count"         "loud" \
   "$(out=$(PATH="$NOBIN" "$SELF" -c ". '$LIB'; count_links '$N'" 2>/dev/null); rc=$?; \
      [ "$rc" -ne 0 ] && [ -z "$out" ] && echo loud || echo "silent:$out")"
BADRC=$(mktemp); printf -- '--nonexistent-flag-xyz\n' > "$BADRC"
eq "rg runtime failure fails loud"            "loud" \
   "$(out=$(RIPGREP_CONFIG_PATH="$BADRC" "$SELF" -c ". '$LIB'; count_links '$N'" 2>/dev/null); rc=$?; \
      [ "$rc" -ne 0 ] && [ -z "$out" ] && echo loud || echo "silent:$out")"
rm -f "$BADRC"
eq "library declares a contract version"      "yes" \
   "$([ "${LINK_EXTRACTION_VERSION:-0}" -ge 1 ] 2>/dev/null && echo yes || echo no)"

# --- caller must survive failures (not exit under zsh) ----------------------------
# An earlier version of these two assertions passed against the very library
# that had the defect. It was vacuous three times over, and each fault is worth
# naming because each is easy to write again:
#   1. it spawned `sh`, which is bash on macOS, so the zsh-only defect was
#      unreachable no matter which shell ran the harness;
#   2. it called the library on a NONEXISTENT directory, which returns at the
#      `[ -d ]` check and never reaches rg — so the rg failure path it claimed
#      to test never executed;
#   3. it ended in `|| echo survived`, which supplies the expected answer when
#      the caller dies — the one outcome it existed to detect.
# The form below was verified to discriminate before being written in: against
# commit c5c159c it yields empty under zsh (the caller died) and `reached`
# under bash; against the fix it yields `reached` under both.
BADRC=$(mktemp); printf -- '--nonexistent-flag-xyz\n' > "$BADRC"
eq "direct call: caller survives rg failure"  "reached" \
   "$(RIPGREP_CONFIG_PATH="$BADRC" "$SELF" -c ". '$LIB'; count_links '$N' >/dev/null 2>&1; printf reached" 2>/dev/null)"
# `if` does NOT contain the exit: zsh runs the last pipeline stage in the
# current shell, so an `exit` inside the library kills the caller from within
# the condition. Measured before the fix — this form died exactly like the bare
# call, which is why testing only the guarded form would have proved nothing.
eq "guarded call: caller survives rg failure" "reached" \
   "$(RIPGREP_CONFIG_PATH="$BADRC" "$SELF" -c ". '$LIB'; if count_links '$N' >/dev/null 2>&1; then :; fi; printf reached" 2>/dev/null)"
rm -f "$BADRC"

# --- empty vault (legitimate state, not a failure) ----------------------------
EMPTY=$(mktemp -d); mkdir -p "$EMPTY/notes"
eq "empty dir: count_links yields 0"          "zero" \
   "$(out=$(count_links "$EMPTY/notes" 2>/dev/null); rc=$?; [ "$rc" -eq 0 ] && [ "$out" = "0" ] && echo zero || echo "failed:$out:rc=$rc")"
eq "empty dir: count_links_recursive yields 0" "zero" \
   "$(out=$(count_links_recursive "$EMPTY/notes" 2>/dev/null); rc=$?; [ "$rc" -eq 0 ] && [ "$out" = "0" ] && echo zero || echo "failed:$out:rc=$rc")"
eq "empty dir: extract_link_targets empty"    "empty" \
   "$(out=$(extract_link_targets "$EMPTY/notes" 2>/dev/null); rc=$?; [ "$rc" -eq 0 ] && [ -z "$out" ] && echo empty || echo "failed:$out:rc=$rc")"
eq "empty dir: extract_link_targets_recursive empty" "empty" \
   "$(out=$(extract_link_targets_recursive "$EMPTY/notes" 2>/dev/null); rc=$?; [ "$rc" -eq 0 ] && [ -z "$out" ] && echo empty || echo "failed:$out:rc=$rc")"
rm -rf "$EMPTY"

rm -rf "$FIX"
printf '\npassed=%s failed=%s\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
