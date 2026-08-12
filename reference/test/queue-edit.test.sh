#!/bin/bash
# queue-edit.test.sh — behavioral tests for reference/lib/queue-edit.sh.
#
# WHY THIS EXISTS: queue-edit.sh is a shared library with SEVEN consumers and, until
# this file, ZERO tests. That is how its unguarded commit step shipped: the function
# ends `mv "$tmp" "$file"` with no `||`, so a rename that fails leaves the temp on
# disk, says nothing, and returns the exit status of the following `rm -rf` — which
# is 0. A lost queue write that reports success is the house failure class wearing
# the queue file, and the library's own header spends nineteen lines explaining the
# lost-update hazard it was built to close while asserting none of it.
#
# THREE ASSERTIONS HERE ARE EXPECTED TO FAIL TODAY. They are labelled `EXPECTED RED`
# and they pin the defect above: rc 1 on a failed rename, the temp discarded, and the
# failing path named. They are not a bug in this suite — the suite proves the defect
# before the fix lands, and the fix turns them green. Do not "repair" the library to
# make this file green; that is a separate task with its own review.
#
# THE RENAME FAILURE IS FORCED WITH A SHELL-FUNCTION STUB, NOT ORGANICALLY. Making a
# same-directory `mv` genuinely fail needs a read-only target inside a writable
# directory — `chflags uchg` on macOS, `chattr +i` as root on Linux — and neither is
# portable to CI. bump-version.test.sh's record states the same limit for the same
# reason. What is covered here is the MECHANISM (rc, temp, message); the organic
# trigger is hand-run only and this comment is the whole of the claim.
#
# THE LOCK-CONTENTION CASE STUBS `sleep`, NOT THE LOCK. queue_edit waits 60s in 2s
# steps before giving up, so a real contended run costs a full minute per assertion.
# The stub removes the wall-clock cost and changes nothing about the branch taken:
# the loop still runs its 30 iterations and still exits through the same message.
#
# Run: bash reference/test/queue-edit.test.sh   (and the same file under zsh)

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
LIB="$ROOT/reference/lib/queue-edit.sh"

passed=0; failed=0
TMPDIRS=()

ok()   { passed=$((passed+1)); }
fail() { failed=$((failed+1)); printf 'FAIL: %s\n  expected [%s] got [%s]\n' "$1" "$2" "$3"; }
eq()   { if [ "$2" = "$3" ]; then ok; else fail "$1" "$2" "$3"; fi; }

# Substring test as a helper rather than a grep, because grep on an empty haystack
# and grep on a haystack missing the needle both return 1 — indistinguishable, and
# the empty case is the one a silent failure produces.
has()  { case "$2" in *"$1"*) printf 'yes' ;; *) printf 'no' ;; esac; }

# Preconditions are asserted, not assumed. Without the jq check every jq-path
# assertion fails for an unrelated reason and the suite reads as a library defect;
# without the uid check the unreadable-file assertion passes vacuously, because root
# reads a 000 file and `[ ! -r ]` never fires.
command -v jq >/dev/null 2>&1 || {
  echo "harness: jq is required — cannot conclude anything" >&2; exit 1; }
[ -r "$LIB" ] || { printf 'harness: no library at %s\n' "$LIB" >&2; exit 1; }
[ "$(id -u)" -ne 0 ] || {
  echo "harness: running as root — the unreadable-file assertion cannot fail" >&2; exit 1; }

cleanup() {
  local d
  for d in "${TMPDIRS[@]:-}"; do
    [ -n "$d" ] || continue
    chmod -R u+rwX "$d" 2>/dev/null
    rm -rf "$d"
  done
}
trap cleanup EXIT INT TERM

# shellcheck source=../lib/queue-edit.sh
. "$LIB"

# A fixture vault fragment shaped like the real thing: queue_edit derives its lock
# directory from `dirname "$file"`, so the queue file must sit in a directory the
# test can inspect for `.locks/` afterwards.
mkfix() { # mkfix -> fixture root
  local d
  d=$(mktemp -d)
  TMPDIRS+=("$d")
  mkdir -p "$d/ops/queue"
  printf '%s\n' '{"tasks":[{"id":"t1","status":"pending"},{"id":"t2","status":"done"}]}' \
    > "$d/ops/queue/queue.json"
  printf '%s' "$d"
}

# The pattern every "leaves no temp behind" assertion searches for. A negative
# assertion passes on absence, so this string being wrong would make four assertions
# green for free — the exact hole bump-version.test.sh records shipping. It is tied
# to the library's own source by the control at the bottom of this file, which
# derives a temp name from the assignment inside queue-edit.sh and requires this
# glob to match it. Renaming the suffix in the library turns that control red.
TMP_GLOB='queue.json.tmp.*'
temps_in() { find "$1" -name "$TMP_GLOB" 2>/dev/null | tr '\n' ' ' | sed 's/ *$//'; }

# --- a successful edit ------------------------------------------------------
F=$(mkfix); Q="$F/ops/queue/queue.json"; L="$F/ops/queue/.locks/queue.lock"
err=$( queue_edit '(.tasks[] | select(.id=="t1")).status = "done"' "$Q" 2>&1 >/dev/null ); rc=$?
eq "success: returns 0"                       "0"    "$rc"
eq "success: the filter's effect is on disk"  "done" "$(jq -r '.tasks[0].status' "$Q")"
eq "success: is silent on stderr"             ""     "$err"
eq "success: leaves no temp behind"           ""     "$(temps_in "$F")"
eq "success: releases the lock"               "no"   "$([ -d "$L" ] && echo yes || echo no)"

# --- jq arguments pass through BEFORE the filter -----------------------------
# The documented calling shape at all seven consumers, and the one the header tells
# callers to prefer over interpolating a shell value into the filter string. An
# implementation that appended "$@" after the filter would still return 0 here while
# writing nothing, so the effect is asserted, not just the exit code.
F=$(mkfix); Q="$F/ops/queue/queue.json"
queue_edit '(.tasks[] | select(.id==$id)).status = $st' "$Q" --arg id t2 --arg st blocked \
  >/dev/null 2>&1; rc=$?
eq "jq args: pass-through returns 0"          "0"       "$rc"
eq "jq args: --arg values reach the filter"   "blocked" "$(jq -r '.tasks[1].status' "$Q")"

# --- a missing file ---------------------------------------------------------
F=$(mkfix)
err=$( queue_edit '.' "$F/ops/queue/absent.json" 2>&1 >/dev/null ); rc=$?
eq "missing: returns 1"                       "1"   "$rc"
eq "missing: names the path it could not read" "yes" "$(has "absent.json" "$err")"
eq "missing: creates no lock directory"       "no"  \
   "$([ -d "$F/ops/queue/.locks" ] && echo yes || echo no)"

# An empty first-argument path is a distinct caller error — an unset shell variable
# rather than a wrong one — and the library spells it `<empty>` so the message does
# not read as a missing filename.
err=$( queue_edit '.' "" 2>&1 >/dev/null ); rc=$?
eq "empty path: returns 1"                    "1"   "$rc"
eq "empty path: says <empty> rather than nothing" "yes" "$(has "<empty>" "$err")"

# --- an unreadable file -----------------------------------------------------
F=$(mkfix); Q="$F/ops/queue/queue.json"
chmod 000 "$Q"
err=$( queue_edit '.' "$Q" 2>&1 >/dev/null ); rc=$?
chmod 644 "$Q"
eq "unreadable: returns 1"                    "1"   "$rc"
eq "unreadable: names the file"               "yes" "$(has "queue.json" "$err")"

# --- a JSON queue file with a YAML sibling (the field tombstone shape) ------
# ops/queue/queue.json (636B, Jul 7) beside a live ops/queue/queue.yaml (440999B,
# modified today) is not hypothetical — it is the measured field-vault state.
# Every call site writes to the .json tombstone silently, at rc 0, because it is
# valid JSON and jq succeeds on it. Digit-free subdirectory name, per this repo's
# own "mktemp paths void no-digits assertions" lesson.
F=$(mkfix); D="$F/ops/queue-sibling-fixture"; mkdir -p "$D"
Q="$D/queue.json"; Y="$D/queue.yaml"
printf '%s\n' '{"tasks":[]}' > "$Q"
printf '%s\n' 'tasks: []' > "$Y"
err=$( queue_edit '.' "$Q" 2>&1 >/dev/null ); rc=$?
eq "json+yaml sibling: returns 1" "1" "$rc"
eq "json+yaml sibling: names both paths" "yes" \
   "$([ "$(has "$Q" "$err")" = "yes" ] && [ "$(has "$Y" "$err")" = "yes" ] && echo yes || echo no)"

# --- a filter jq rejects ----------------------------------------------------
F=$(mkfix); Q="$F/ops/queue/queue.json"; L="$F/ops/queue/.locks/queue.lock"
before=$(cat "$Q")
err=$( queue_edit '.tasks[' "$Q" 2>&1 >/dev/null ); rc=$?
eq "bad filter: returns 1"                    "1"   "$rc"
eq "bad filter: names the file"               "yes" "$(has "queue.json" "$err")"
eq "bad filter: leaves no temp behind"        ""    "$(temps_in "$F")"
eq "bad filter: releases the lock"            "no"  "$([ -d "$L" ] && echo yes || echo no)"
# The redirection is into the temp, never the queue file — but a future rewrite that
# wrote in place would pass every assertion above while truncating the queue.
eq "bad filter: leaves the queue file byte-identical" "$before" "$(cat "$Q")"

# --- lock acquisition failure -----------------------------------------------
# `sleep` is stubbed to a no-op so the bounded 60s wait costs nothing; the branch
# taken is unchanged. The lock is pre-created, which is what a concurrent
# orchestrator holding it looks like from here.
F=$(mkfix); Q="$F/ops/queue/queue.json"; L="$F/ops/queue/.locks/queue.lock"
before=$(cat "$Q")
mkdir -p "$L"
err=$( sleep() { :; }; queue_edit '.tasks = []' "$Q" 2>&1 >/dev/null ); rc=$?
eq "locked: returns 1"                        "1"   "$rc"
eq "locked: names the lock directory"         "yes" "$(has "$L" "$err")"
eq "locked: prints the manual-removal remedy" "yes" "$(has "rm -rf" "$err")"
# The library's header rules out mtime-based auto-break. A run that gives up and
# then deletes the lock anyway would be an auto-break wearing a failure message.
eq "locked: does NOT break the lock it failed to take" "yes" \
   "$([ -d "$L" ] && echo yes || echo no)"
eq "locked: leaves the queue file byte-identical" "$before" "$(cat "$Q")"
eq "locked: leaves no temp behind"            ""    "$(temps_in "$F")"

# --- EXPECTED RED: the commit step is unguarded ------------------------------
# `mv` is a shell function here, so the library's own `mv "$tmp" "$file"` resolves to
# it and fails without needing an unwritable target. Today the library ignores that
# failure: rc comes from the following `rm -rf` (0), the temp survives, and nothing
# is printed. THE THREE ASSERTIONS BELOW FAIL UNTIL THE COMMIT STEP IS GUARDED.
F=$(mkfix); Q="$F/ops/queue/queue.json"
before=$(cat "$Q")
err=$( mv() { return 1; }; queue_edit '(.tasks[] | select(.id=="t1")).status = "done"' "$Q" \
       2>&1 >/dev/null ); rc=$?
eq "EXPECTED RED — failed rename returns 1"          "1"   "$rc"
eq "EXPECTED RED — failed rename discards its temp"  ""    "$(temps_in "$F")"
eq "EXPECTED RED — failed rename names the path"     "yes" "$(has "queue.json" "$err")"
# Green today and after: a rename that did not happen must not have damaged the file
# it was going to replace. Asserted so a future fix cannot buy the three above by
# writing the queue file some other way.
eq "failed rename: leaves the queue file byte-identical" "$before" "$(cat "$Q")"

# --- controls on the temp search --------------------------------------------
# A "leaves no temp behind" assertion is satisfied by a search that can never find
# anything. Both controls below exist to make that impossible, and the second is the
# one that ties $TMP_GLOB to the library rather than to a string typed twice.
F=$(mkfix)
lib_tmp_expr=$(/usr/bin/grep -o '^ *tmp="[^"]*"' "$LIB" | head -1)
# Without this, an extraction that matched nothing would leave $derived empty, plant
# no file, and let the control below compare "" against "" and pass.
eq "control: the library's temp-name assignment was found" "yes" \
   "$([ -n "$lib_tmp_expr" ] && echo yes || echo no)"
derived=$( file="$F/ops/queue/queue.json"; eval "$lib_tmp_expr"; printf '%s' "${tmp:-}" )
[ -n "$derived" ] && : > "$derived"
eq "control: \$TMP_GLOB matches a name built from the library's own source" \
   "$derived" "$(temps_in "$F")"
rm -f "$derived"

printf '\npassed=%s failed=%s\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
