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

# --- link_edge_map: source<TAB>target<TAB>source_path edges -----------------
# Every note makes a different wrong implementation fail. Do not trim the fixture.
# a.b/axb pair catches interpolation bug; fenced note tests _strip_fences.
EDGE_DIR=$(mktemp -d)
mkdir -p "$EDGE_DIR/notes" "$EDGE_DIR/empty"
printf -- '---\ntitle: Alpha\n---\nlinks [[Target]] [[a.b]]\n' > "$EDGE_DIR/notes/alpha.md"
printf -- '---\ntitle: Beta\n---\nlinks [[TARGET]] [[Target|an alias]]\n' > "$EDGE_DIR/notes/beta.md"
printf -- '---\ntitle: Gamma\n---\nlinks [[Target#a-heading]]\n' > "$EDGE_DIR/notes/gamma.md"
printf -- '---\ntitle: a.b\n---\n[[Target]]\n' > "$EDGE_DIR/notes/a.b.md"
printf -- '---\ntitle: axb\n---\n[[not-a-match]]\n' > "$EDGE_DIR/notes/axb.md"
printf -- 'target linking itself\n[[target]]\n' > "$EDGE_DIR/notes/target.md"
printf -- '---\ntitle: Lonely\n---\nno links here\n' > "$EDGE_DIR/notes/lonely.md"
printf -- '---\ntitle: Fenced\n---\n```\n[[in-code-fence]]\n```\n' > "$EDGE_DIR/notes/fenced.md"
printf -- '---\ntitle: SelfOnly\n---\n[[selfonly]]\n' > "$EDGE_DIR/notes/selfonly.md"

edges=$(link_edge_map "$EDGE_DIR/notes" 2>/dev/null)

# 1. case folds both sides: [[TARGET]], [[Target]] both -> target from beta (also alpha -> target)
eq "link_edge_map: case folds both sides" "3" "$(printf '%s\n' "$edges" | LC_ALL=C awk -F'\t' '$2=="target" && ($1=="alpha" || $1=="beta")' | grep -c .)"

# 2. a.b is literal not regex: [[a.b]] matches only a.b, not axb
eq "link_edge_map: a.b resolves itself exactly once" "1" "$(printf '%s\n' "$edges" | LC_ALL=C awk -F'\t' '$2=="a.b"' | grep -c .)"

# 3. fences: fenced note contributes NO edge
eq "link_edge_map: link inside fence not an edge" "0" "$(printf '%s\n' "$edges" | LC_ALL=C awk -F'\t' '$1=="fenced"' | grep -c .)"

# 4. self-edges ARE present at layer (Task 2's backlink_counts removes them)
eq "link_edge_map: self-edges emitted here" "1" "$(printf '%s\n' "$edges" | LC_ALL=C awk -F'\t' '$1=="target" && $2=="target"' | grep -c .)"

# 5. failure must never number
out=$(link_edge_map "$EDGE_DIR/does-not-exist" 2>/dev/null); rc=$?
eq "link_edge_map: missing directory returns 1" "1" "$rc"
eq "link_edge_map: missing directory prints NOTHING, not 0" "" "$out"

# 6. empty directory is legitimate: rc 0, empty output
mkdir -p "$EDGE_DIR/empty"
out=$(link_edge_map "$EDGE_DIR/empty" 2>/dev/null); rc=$?
eq "link_edge_map: empty directory rc 0" "0" "$rc"
eq "link_edge_map: empty directory output empty" "" "$out"

# 7. recursive variant tests
edges_recursive=$(link_edge_map_recursive "$EDGE_DIR/notes" 2>/dev/null)
eq "link_edge_map_recursive: basic functionality" "9" "$(printf '%s\n' "$edges_recursive" | grep -c .)"

# 8. recursive empty directory
out=$(link_edge_map_recursive "$EDGE_DIR/empty" 2>/dev/null); rc=$?
eq "link_edge_map_recursive: empty directory rc 0" "0" "$rc"
eq "link_edge_map_recursive: empty directory output empty" "" "$out"

# 9. rg failure handling in link_edge_map
BADRC=$(mktemp)
printf 'invalid-config' > "$BADRC"
out=$(RIPGREP_CONFIG_PATH="$BADRC" link_edge_map "$EDGE_DIR/notes" >/dev/null 2>&1); rc=$?
eq "link_edge_map: rg failure returns 1" "1" "$rc"
out=$(RIPGREP_CONFIG_PATH="$BADRC" link_edge_map "$EDGE_DIR/notes" 2>/dev/null)
eq "link_edge_map: rg failure prints NOTHING, not partial" "" "$out"
rm -f "$BADRC"

# 10. rg failure handling in link_edge_map_recursive
BADRC=$(mktemp)
printf 'invalid-config' > "$BADRC"
out=$(RIPGREP_CONFIG_PATH="$BADRC" link_edge_map_recursive "$EDGE_DIR/notes" >/dev/null 2>&1); rc=$?
eq "link_edge_map_recursive: rg failure returns 1" "1" "$rc"
out=$(RIPGREP_CONFIG_PATH="$BADRC" link_edge_map_recursive "$EDGE_DIR/notes" 2>/dev/null)
eq "link_edge_map_recursive: rg failure prints NOTHING, not partial" "" "$out"
rm -f "$BADRC"

# 11. partial failure scenario: some files succeed, later one fails
PART_DIR=$(mktemp -d)
mkdir -p "$PART_DIR/notes"
printf -- '---\ntitle: Good1\n---\n[[Target]]\n' > "$PART_DIR/notes/good1.md"
printf -- '---\ntitle: Good2\n---\n[[Other]]\n' > "$PART_DIR/notes/good2.md"
chmod 000 "$PART_DIR/notes/good2.md"  # Make file unreadable to cause failure
out=$(link_edge_map "$PART_DIR/notes" 2>/dev/null); rc=$?
eq "link_edge_map: partial failure returns 1" "1" "$rc"
eq "link_edge_map: partial failure prints NOTHING, not partial" "" "$out"
chmod 644 "$PART_DIR/notes/good2.md"  # restore for cleanup
rm -rf "$PART_DIR"

# 12. recursive with nested directories (vs flat)
NEST_DIR=$(mktemp -d)
mkdir -p "$NEST_DIR/notes/sub"
printf -- '---\ntitle: Root\n---\n[[Target]]\n' > "$NEST_DIR/notes/root.md"
printf -- '---\ntitle: Nested\n---\n[[Target]]\n' > "$NEST_DIR/notes/sub/nested.md"
flat_count=$(link_edge_map "$NEST_DIR/notes" 2>/dev/null | grep -c .)
recursive_count=$(link_edge_map_recursive "$NEST_DIR/notes" 2>/dev/null | grep -c .)
eq "link_edge_map: flat does NOT descend" "1" "$flat_count"
eq "link_edge_map_recursive: recurses into subdirectories" "2" "$recursive_count"

# 12a. link_edge_map: third column (source path) shape and content
flat_edges=$(link_edge_map "$NEST_DIR/notes" 2>/dev/null)
flat_edge_count=$(printf '%s\n' "$flat_edges" | grep -c .)
eq "link_edge_map: all edges have exactly 3 tab-separated columns" "$flat_edge_count" \
  "$(printf '%s\n' "$flat_edges" | awk -F'\t' 'NF==3' | grep -c .)"

# 12b. link_edge_map_recursive: third column (source path) shape and content
recurse_edges=$(link_edge_map_recursive "$NEST_DIR/notes" 2>/dev/null)
recurse_edge_count=$(printf '%s\n' "$recurse_edges" | grep -c .)
eq "link_edge_map_recursive: all edges have exactly 3 tab-separated columns" "$recurse_edge_count" \
  "$(printf '%s\n' "$recurse_edges" | awk -F'\t' 'NF==3' | grep -c .)"
eq "link_edge_map_recursive: nested path is in column 3, not just basename" "1" \
  "$(printf '%s\n' "$recurse_edges" | LC_ALL=C awk -F'\t' '$3 ~ /sub\/nested/ {print "found"} END {print NR}' | grep -q 'found' && echo 1 || echo 0)"

# 12c. duplicate basenames in different subdirectories have distinct paths in column 3
DUP_DIR=$(mktemp -d)
mkdir -p "$DUP_DIR/notes/a-dir" "$DUP_DIR/notes/b-dir"
printf -- '---\ntitle: DupA\n---\n[[target]]\n' > "$DUP_DIR/notes/a-dir/dup.md"
printf -- '---\ntitle: DupB\n---\n[[target]]\n' > "$DUP_DIR/notes/b-dir/dup.md"
dup_edges=$(link_edge_map_recursive "$DUP_DIR/notes" 2>/dev/null)
dup_paths=$(printf '%s\n' "$dup_edges" | LC_ALL=C awk -F'\t' '{print $3}' | LC_ALL=C sort -u)
dup_path_count=$(printf '%s\n' "$dup_paths" | grep -c .)
eq "link_edge_map_recursive: basename collision produces distinct paths in column 3" "2" "$dup_path_count"
eq "link_edge_map_recursive: first dup path is a-dir/dup.md" "1" \
  "$(printf '%s\n' "$dup_paths" | grep -c 'a-dir/dup.md')"
eq "link_edge_map_recursive: second dup path is b-dir/dup.md" "1" \
  "$(printf '%s\n' "$dup_paths" | grep -c 'b-dir/dup.md')"
rm -rf "$DUP_DIR"

rm -rf "$NEST_DIR"

# 13. backlink_counts: incoming edge counts with self-edges excluded
counts=$(backlink_counts "$EDGE_DIR/notes" 2>/dev/null)

# target has 6 raw edges (including self), ONE of which is its own self-link -> 5
eq "backlink_counts: excludes the self-edge (6 raw edges -> 5 incoming)" "5" \
  "$(printf '%s\n' "$counts" | LC_ALL=C awk -F'\t' '$1=="target"{print $2}')"

# a note with no incoming links is ABSENT, not zero -- absence is the zero
eq "backlink_counts: a target with no incoming links does not appear" "" \
  "$(printf '%s\n' "$counts" | LC_ALL=C awk -F'\t' '$1=="lonely"{print $2}')"

# a.b and axb tests (a.b.md links to target, alpha.md links to a.b)
eq "backlink_counts: a.b counted exactly once, axb not at all" "1" \
  "$(printf '%s\n' "$counts" | LC_ALL=C awk -F'\t' '$1=="a.b"{print $2}')"
eq "backlink_counts: axb has no incoming links" "" \
  "$(printf '%s\n' "$counts" | LC_ALL=C awk -F'\t' '$1=="axb"{print $2}')"

out=$(backlink_counts "$EDGE_DIR/does-not-exist" 2>/dev/null); rc=$?
eq "backlink_counts: missing directory returns 1" "1" "$rc"
eq "backlink_counts: missing directory prints NOTHING" "" "$out"

# 14. backlink_counts empty directory test (rc 0, empty output)
out=$(backlink_counts "$EDGE_DIR/empty" 2>/dev/null); rc=$?
eq "backlink_counts: empty directory rc 0" "0" "$rc"
eq "backlink_counts: empty directory output empty" "" "$out"

# 15. backlink_counts_recursive tests
counts_recursive=$(backlink_counts_recursive "$EDGE_DIR/notes" 2>/dev/null)
eq "backlink_counts_recursive: basic functionality, self-excluded" "5" \
  "$(printf '%s\n' "$counts_recursive" | LC_ALL=C awk -F'\t' '$1=="target"{print $2}')"

# 16. backlink_counts_recursive empty directory
out=$(backlink_counts_recursive "$EDGE_DIR/empty" 2>/dev/null); rc=$?
eq "backlink_counts_recursive: empty directory rc 0" "0" "$rc"
eq "backlink_counts_recursive: empty directory output empty" "" "$out"

# 17. backlink_counts_recursive failure handling (missing dir)
out=$(backlink_counts_recursive "$EDGE_DIR/does-not-exist" 2>/dev/null); rc=$?
eq "backlink_counts_recursive: missing directory returns 1" "1" "$rc"
eq "backlink_counts_recursive: missing directory prints NOTHING" "" "$out"

# 18. orphan_notes basic functionality
orphans=$(orphan_notes "$EDGE_DIR/notes" 2>/dev/null)
eq "orphan_notes: lonely (no incoming links)" "1" \
  "$(printf '%s\n' "$orphans" | grep -Fxc 'lonely')"
eq "orphan_notes: axb is orphan (not-a-match doesn't exist)" "1" \
  "$(printf '%s\n' "$orphans" | grep -Fxc 'axb')"
eq "orphan_notes: target is NOT orphan (has incoming from alpha, beta, gamma, a.b)" "0" \
  "$(printf '%s\n' "$orphans" | grep -Fxc 'target')"
eq "orphan_notes: a.b is NOT orphan (linked from alpha)" "0" \
  "$(printf '%s\n' "$orphans" | grep -Fxc 'a.b')"
eq "orphan_notes: fenced is orphan (link only in fence)" "1" \
  "$(printf '%s\n' "$orphans" | grep -Fxc 'fenced')"
eq "orphan_notes: selfonly is orphan (self-link alone doesn't rescue it)" "1" \
  "$(printf '%s\n' "$orphans" | grep -Fxc 'selfonly')"

# 18b. LC_ALL=C pinning is STRUCTURAL (not behaviorally testable on BSD sort)
# Both sides of comm must be sorted under the same collation; pinning ensures it.
# Grep the library to verify the pins are present, then mutation-prove by removing one.
eq "orphan_notes: LC_ALL=C sort for index" "1" \
  "$(sed -n '414p' reference/lib/link-extraction.sh | grep -c 'LC_ALL=C sort -u.*idx')"
eq "orphan_notes: LC_ALL=C sort for targets" "1" \
  "$(sed -n '419p' reference/lib/link-extraction.sh | grep -c 'LC_ALL=C sort -u.*tgts')"
eq "orphan_notes: LC_ALL=C comm call" "1" \
  "$(sed -n '422p' reference/lib/link-extraction.sh | grep -c 'LC_ALL=C comm -23')"
eq "orphan_notes_recursive: LC_ALL=C sort for index" "1" \
  "$(sed -n '435p' reference/lib/link-extraction.sh | grep -c 'LC_ALL=C sort -u.*idx')"
eq "orphan_notes_recursive: LC_ALL=C sort for targets" "1" \
  "$(sed -n '440p' reference/lib/link-extraction.sh | grep -c 'LC_ALL=C sort -u.*tgts')"
eq "orphan_notes_recursive: LC_ALL=C comm call" "1" \
  "$(sed -n '443p' reference/lib/link-extraction.sh | grep -c 'LC_ALL=C comm -23')"

# 19. orphan_notes empty directory (rc 0, empty output)
out=$(orphan_notes "$EDGE_DIR/empty" 2>/dev/null); rc=$?
eq "orphan_notes: empty directory rc 0" "0" "$rc"
eq "orphan_notes: empty directory output empty" "" "$out"

# 20. orphan_notes missing directory (rc 1, no output)
out=$(orphan_notes "$EDGE_DIR/does-not-exist" 2>/dev/null); rc=$?
eq "orphan_notes: missing directory returns 1" "1" "$rc"
eq "orphan_notes: missing directory prints NOTHING" "" "$out"

# 21. orphan_notes_recursive basic functionality
orphans_r=$(orphan_notes_recursive "$EDGE_DIR/notes" 2>/dev/null)
eq "orphan_notes_recursive: lonely is orphan" "1" \
  "$(printf '%s\n' "$orphans_r" | grep -Fxc 'lonely')"
eq "orphan_notes_recursive: axb is orphan" "1" \
  "$(printf '%s\n' "$orphans_r" | grep -Fxc 'axb')"
eq "orphan_notes_recursive: target is NOT orphan" "0" \
  "$(printf '%s\n' "$orphans_r" | grep -Fxc 'target')"
eq "orphan_notes_recursive: a.b is NOT orphan" "0" \
  "$(printf '%s\n' "$orphans_r" | grep -Fxc 'a.b')"
eq "orphan_notes_recursive: fenced is orphan" "1" \
  "$(printf '%s\n' "$orphans_r" | grep -Fxc 'fenced')"
eq "orphan_notes_recursive: selfonly is orphan (self-link doesn't rescue)" "1" \
  "$(printf '%s\n' "$orphans_r" | grep -Fxc 'selfonly')"

# 22. orphan_notes_recursive empty directory
out=$(orphan_notes_recursive "$EDGE_DIR/empty" 2>/dev/null); rc=$?
eq "orphan_notes_recursive: empty directory rc 0" "0" "$rc"
eq "orphan_notes_recursive: empty directory output empty" "" "$out"

# 23. orphan_notes_recursive missing directory
out=$(orphan_notes_recursive "$EDGE_DIR/does-not-exist" 2>/dev/null); rc=$?
eq "orphan_notes_recursive: missing directory returns 1" "1" "$rc"
eq "orphan_notes_recursive: missing directory prints NOTHING" "" "$out"

# 24. orphan_notes mid-scan producer failure (link_edge_map fails)
BADRC=$(mktemp)
printf 'invalid-config' > "$BADRC"
out=$(RIPGREP_CONFIG_PATH="$BADRC" orphan_notes "$EDGE_DIR/notes" >/dev/null 2>&1); rc=$?
eq "orphan_notes: link_edge_map failure returns 1" "1" "$rc"
out=$(RIPGREP_CONFIG_PATH="$BADRC" orphan_notes "$EDGE_DIR/notes" 2>/dev/null)
eq "orphan_notes: link_edge_map failure prints NOTHING" "" "$out"
rm -f "$BADRC"

# 25. orphan_notes_recursive mid-scan producer failure (link_edge_map_recursive fails)
BADRC=$(mktemp)
printf 'invalid-config' > "$BADRC"
out=$(RIPGREP_CONFIG_PATH="$BADRC" orphan_notes_recursive "$EDGE_DIR/notes" >/dev/null 2>&1); rc=$?
eq "orphan_notes_recursive: link_edge_map_recursive failure returns 1" "1" "$rc"
out=$(RIPGREP_CONFIG_PATH="$BADRC" orphan_notes_recursive "$EDGE_DIR/notes" 2>/dev/null)
eq "orphan_notes_recursive: link_edge_map_recursive failure prints NOTHING" "" "$out"
rm -f "$BADRC"

# 26. orphan_notes transform-pipeline awk failure (selective stub)
STUB_AWK=$(mktemp)
STUB_DIR=$(mktemp -d)
# Selective stub: fail on the transform pattern, pass through otherwise
cat > "$STUB_AWK" <<'EOFAWK'
#!/bin/bash
# Selective awk stub for link-extraction test
# Fail (return 1) on the orphan_notes transform invocation: awk -F'\t' '$1 != $2 { print $2 }'
# Pass through to real awk for all other invocations

# Check if this is the transform invocation by looking at argv
case "$*" in
  *'$1 != $2'*)
    exit 1
    ;;
  *)
    # Delegate to real awk
    exec /usr/bin/awk "$@"
    ;;
esac
EOFAWK
chmod +x "$STUB_AWK"
ln -s "$STUB_AWK" "$STUB_DIR/awk"

out=$(PATH="$STUB_DIR:$PATH" orphan_notes "$EDGE_DIR/notes" >/dev/null 2>&1); rc=$?
eq "orphan_notes: transform awk failure returns 1" "1" "$rc"
out=$(PATH="$STUB_DIR:$PATH" orphan_notes "$EDGE_DIR/notes" 2>/dev/null)
eq "orphan_notes: transform awk failure prints NOTHING" "" "$out"
rm -rf "$STUB_DIR" "$STUB_AWK"

# 27. orphan_notes_recursive transform-pipeline awk failure (selective stub)
STUB_AWK=$(mktemp)
STUB_DIR=$(mktemp -d)
# Selective stub: fail on the transform pattern, pass through otherwise
cat > "$STUB_AWK" <<'EOFAWK'
#!/bin/bash
# Selective awk stub for link-extraction test
# Fail (return 1) on the orphan_notes_recursive transform invocation: awk -F'\t' '$1 != $2 { print $2 }'
# Pass through to real awk for all other invocations

# Check if this is the transform invocation by looking at argv
case "$*" in
  *'$1 != $2'*)
    exit 1
    ;;
  *)
    # Delegate to real awk
    exec /usr/bin/awk "$@"
    ;;
esac
EOFAWK
chmod +x "$STUB_AWK"
ln -s "$STUB_AWK" "$STUB_DIR/awk"

out=$(PATH="$STUB_DIR:$PATH" orphan_notes_recursive "$EDGE_DIR/notes" >/dev/null 2>&1); rc=$?
eq "orphan_notes_recursive: transform awk failure returns 1" "1" "$rc"
out=$(PATH="$STUB_DIR:$PATH" orphan_notes_recursive "$EDGE_DIR/notes" 2>/dev/null)
eq "orphan_notes_recursive: transform awk failure prints NOTHING" "" "$out"
rm -rf "$STUB_DIR" "$STUB_AWK"

rm -rf "$EDGE_DIR"

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
