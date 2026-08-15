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
# The guard's own message and jq's own failure message are textually distinct —
# "not a readable file" is printed only by the guard, never by jq. Without the
# guard, execution reaches jq, which fails with its own "Could not open file"
# text instead. This is the discriminator; rc and the bare presence of the path
# in the message are not, since jq's failure also yields rc 1 and also names the
# path.
eq "missing: guard's own message, not jq's"   "yes" "$(has "not a readable file" "$err")"

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

# --- a readable directory ----------------------------------------------------
# A directory passes -r (directories are commonly readable) but is not a queue
# file. Without a regular-file check it would create a .locks/ directory as a
# side effect and only fail once jq is invoked against it. mkfix() already
# creates ops/queue/queue.json as a regular file, so a *different* path is used
# here — mkdir -p on mkfix's own queue.json path would fail (file exists) and
# leave $D as that pre-existing readable file, silently testing the wrong thing.
F=$(mkfix); D="$F/ops/queue/adir"; mkdir -p "$D"
err=$( queue_edit '.' "$D" 2>&1 >/dev/null ); rc=$?
eq "directory: returns 1"                     "1"   "$rc"
eq "directory: creates no lock directory"     "no"  \
   "$([ -d "$F/ops/queue/.locks" ] && echo yes || echo no)"

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

# The guard is keyed on the basename queue.json specifically, not any *.json —
# an unrelated tasks.json beside a queue.yaml is not the tombstone shape and
# must be accepted, not refused.
T="$D/tasks.json"
printf '%s\n' '{"tasks":[]}' > "$T"
out=$( queue_edit '.' "$T" 2>&1 ); rc=$?
eq "unrelated json: tasks.json beside queue.yaml is accepted" "0" "$rc"

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

# --- v2: _queue_lock and queue_yaml (ported from the field vault) ------------
# The port is Task 12a's ruling (i): the YAML write path was proven in the field
# vault and never existed here. Each assertion below was run against the v1
# library first and confirmed RED — a function that does not exist exits 127 and
# prints none of the messages asserted on — so a green run is evidence the port
# landed, not evidence the assertions cannot fail.

# A YAML fixture shaped like the live queue: a BARE LIST (no tasks: key), one
# folded scalar so "surgical" is a checkable property rather than a label.
mkyfix() { # mkyfix -> fixture root
  local d
  d=$(mktemp -d)
  TMPDIRS+=("$d")
  mkdir -p "$d/ops/queue"
  printf -- '- id: alpha\n  status: pending\n  note: >-\n    a folded scalar that\n    spans two lines\n- id: beta\n  status: done\n  completed_phases:\n  - reduce\n' \
    > "$d/ops/queue/queue.yaml"
  printf '%s' "$d"
}
YTMP_GLOB='queue.yaml.tmp.*'
ytemps_in() { find "$1" -name "$YTMP_GLOB" 2>/dev/null | tr '\n' ' ' | sed 's/ *$//'; }

# --- v2: version and surface -------------------------------------------------
eq "v2: QUEUE_EDIT_VERSION is 2"          "2"   "${QUEUE_EDIT_VERSION:-0}"
eq "v2: queue_yaml is defined"            "yes" "$(command -v queue_yaml >/dev/null 2>&1 && echo yes || echo no)"
eq "v2: _queue_lock is defined"           "yes" "$(command -v _queue_lock >/dev/null 2>&1 && echo yes || echo no)"
eq "v2: queue_edit.py ships beside the library" "yes" \
   "$([ -r "$ROOT/reference/lib/queue_edit.py" ] && echo yes || echo no)"

# --- _queue_lock directly ----------------------------------------------------
F=$(mkyfix); Y="$F/ops/queue/queue.yaml"; L="$F/ops/queue/.locks/queue.lock"
out=$(_queue_lock "$Y" 2>/dev/null); rc=$?
eq "_queue_lock: returns 0 and echoes the lockdir" "$L" "$out"
eq "_queue_lock: the lock exists after acquisition" "yes" "$([ -d "$L" ] && echo yes || echo no)"
rm -rf "$L"
mkdir -p "$L"
err=$( sleep() { :; }; _queue_lock "$Y" 2>&1 >/dev/null ); rc=$?
eq "_queue_lock contended: returns 1"     "1"   "$rc"
eq "_queue_lock contended: does NOT break the held lock" "yes" \
   "$([ -d "$L" ] && echo yes || echo no)"
rm -rf "$L"

# --- queue_edit refuses a YAML target ----------------------------------------
# v1 also returned 1 here — jq cannot parse YAML — so rc alone is not the
# discriminator; the remedy message naming queue_yaml is (red on v1).
F=$(mkyfix); Y="$F/ops/queue/queue.yaml"; before=$(cat "$Y")
err=$( queue_edit '.' "$Y" 2>&1 >/dev/null ); rc=$?
eq "yaml refusal: returns 1"              "1"   "$rc"
eq "yaml refusal: names queue_yaml as the remedy" "yes" "$(has "queue_yaml" "$err")"
eq "yaml refusal: leaves the file byte-identical" "$before" "$(cat "$Y")"

# --- queue_yaml: a successful --where/--set ----------------------------------
F=$(mkyfix); Y="$F/ops/queue/queue.yaml"; L="$F/ops/queue/.locks/queue.lock"
before=$(cat "$Y")
err=$( queue_yaml "$Y" --where id=alpha --set status=done 2>&1 >/dev/null ); rc=$?
eq "queue_yaml set: returns 0"            "0"   "$rc"
eq "queue_yaml set: the edit is on disk"  "  status: done" "$(sed -n '2p' "$Y")"
eq "queue_yaml set: reports the match count on stderr" "yes" "$(has "1 task(s) updated" "$err")"
# Surgical means exactly one line replaced: one removal, one addition in a diff.
diffcount=$( { printf '%s\n' "$before" | diff - "$Y" || true; } | /usr/bin/grep -c '^[<>]' )
eq "queue_yaml set: exactly one line changed (surgical)" "2" "$diffcount"
eq "queue_yaml set: the folded scalar is untouched" "yes" "$(has "spans two lines" "$(cat "$Y")")"
eq "queue_yaml set: releases the lock"    "no"  "$([ -d "$L" ] && echo yes || echo no)"
eq "queue_yaml set: leaves no temp behind" ""   "$(ytemps_in "$F")"

# --- queue_yaml: --where matching nothing is a loud failure ------------------
# The silent zero-match write is the failure this whole port exists to end.
F=$(mkyfix); Y="$F/ops/queue/queue.yaml"; L="$F/ops/queue/.locks/queue.lock"
before=$(cat "$Y")
err=$( queue_yaml "$Y" --where id=nonesuch --set status=done 2>&1 >/dev/null ); rc=$?
eq "no match: returns 1"                  "1"   "$rc"
eq "no match: says nothing was written"   "yes" "$(has "nothing written" "$err")"
eq "no match: leaves the queue byte-identical" "$before" "$(cat "$Y")"
eq "no match: releases the lock"          "no"  "$([ -d "$L" ] && echo yes || echo no)"
eq "no match: leaves no temp behind"      ""    "$(ytemps_in "$F")"

# --- queue_yaml: --where is required -----------------------------------------
err=$( queue_yaml "$Y" --set status=done 2>&1 >/dev/null ); rc=$?
eq "missing --where: returns 1"           "1"   "$rc"
eq "missing --where: refuses to edit every task" "yes" "$(has "refusing" "$err")"
eq "missing --where: leaves the queue byte-identical" "$before" "$(cat "$Y")"

# --- queue_yaml: --add-task and --append -------------------------------------
F=$(mkyfix); Y="$F/ops/queue/queue.yaml"
queue_yaml "$Y" --add-task id=gamma type=maintenance status=pending >/dev/null 2>&1; rc=$?
eq "add-task: returns 0"                  "0"   "$rc"
eq "add-task: the block is appended"      "yes" "$(has "- id: gamma" "$(cat "$Y")")"
eq "add-task: fields ride at indent 2"    "yes" "$(has "  type: maintenance" "$(cat "$Y")")"
queue_yaml "$Y" --where id=beta --append completed_phases=reflect >/dev/null 2>&1; rc=$?
eq "append: returns 0"                    "0"   "$rc"
eq "append: the item lands in the list"   "yes" "$(has "  - reflect" "$(cat "$Y")")"

# --- queue_yaml: a held lock -------------------------------------------------
F=$(mkyfix); Y="$F/ops/queue/queue.yaml"; L="$F/ops/queue/.locks/queue.lock"
before=$(cat "$Y")
mkdir -p "$L"
err=$( sleep() { :; }; queue_yaml "$Y" --where id=alpha --set status=done 2>&1 >/dev/null ); rc=$?
eq "queue_yaml locked: returns 1"         "1"   "$rc"
eq "queue_yaml locked: does NOT break the lock it failed to take" "yes" \
   "$([ -d "$L" ] && echo yes || echo no)"
eq "queue_yaml locked: leaves the queue byte-identical" "$before" "$(cat "$Y")"
rm -rf "$L"

# --- queue_yaml: a failed rename ---------------------------------------------
# Same mechanism-stub as queue_edit's EXPECTED-RED block above, same claim
# limits: the organic trigger is hand-run only.
F=$(mkyfix); Y="$F/ops/queue/queue.yaml"; before=$(cat "$Y")
err=$( mv() { return 1; }; queue_yaml "$Y" --where id=alpha --set status=done 2>&1 >/dev/null ); rc=$?
eq "queue_yaml failed rename: returns 1"  "1"   "$rc"
eq "queue_yaml failed rename: discards its temp" "" "$(ytemps_in "$F")"
eq "queue_yaml failed rename: names the path" "yes" "$(has "queue.yaml" "$err")"
eq "queue_yaml failed rename: leaves the queue byte-identical" "$before" "$(cat "$Y")"

# --- queue_yaml: a missing helper --------------------------------------------
# The library resolves queue_edit.py beside its own sourced path — captured at
# source time, which is also what makes the resolution work under zsh. A copy of
# the .sh with no .py beside it must fail loud, not fall through to python3
# erroring on a path that does not exist.
F=$(mkyfix); Y="$F/ops/queue/queue.yaml"
cp "$LIB" "$F/qe.sh"
err=$( . "$F/qe.sh"; queue_yaml "$Y" --where id=alpha --set status=done 2>&1 >/dev/null ); rc=$?
eq "missing helper: returns 1"            "1"   "$rc"
eq "missing helper: names the helper it could not find" "yes" "$(has "queue_edit.py" "$err")"

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
