#!/bin/bash
# queue-edit.sh — single definition for writing to a queue file, sourced by skill templates.
#
# Every existing write site (verify, next, reflect, reweave, reduce) reimplemented the same
# read-modify-write by hand: `jq '<filter>' ops/queue/queue.json > tmp.json && mv tmp.json
# ops/queue/queue.json`. Correct per-write, but with two gaps a single shared function closes:
#
# 1. NO LOCK. Two orchestrators writing queue.json at the same moment both read the same old
#    file, both compute a filtered copy from that old content, and the second `mv` silently
#    discards the first write — a lost update, not a crash, so nothing at either write site
#    would ever report it. Concurrent verify/reflect/reweave/reduce orchestrators (fan-out
#    sessions routinely run several at once) are exactly the shape that triggers this. Locked
#    the same way reflect/reweave already lock qmd search: bounded mkdir mutex, explicit release
#    on every exit path, no auto-break on staleness — see the lock block below and
#    skills/setup/SKILL.md's own ruling against mtime-based auto-break, which applies here too.
#
# 2. SEVEN DUPLICATED CALL SITES. One bug in the read-modify-write pattern is one bug in seven
#    places. Centralized so a future fix — or a future caller — has one function to call, not
#    one pattern to copy.
#
# Sourced by skill templates. Do NOT inline copies of this function anywhere.

QUEUE_EDIT_VERSION=1

# queue_edit <jq-filter> <queue-file> [jq-args...]
#
# Applies <jq-filter> to <queue-file> under a lock, atomically (temp file + mv, never a
# partial write). Any [jq-args...] are passed through to jq BEFORE the filter — e.g.
# `queue_edit '(.tasks[] | select(.id==$id)).status = $status' "$QUEUE" --arg id "$TASK_ID"
# --arg status "done"`. Always prefer --arg over interpolating a shell variable directly into
# the filter string: a value containing a quote or jq metacharacter would corrupt the filter
# rather than just fail to match.
#
# Fails loud: missing/unreadable file, a filter jq itself rejects, or a lock that can't be
# acquired within 60s all print a reason to stderr and return 1. Success is silent, matching
# every one of the seven call sites this replaces — none of them printed anything on a normal
# write.
queue_edit() {
  local filter="$1" file="$2"
  shift 2
  if [ -z "$file" ] || [ ! -f "$file" ] || [ ! -r "$file" ]; then
    echo "error: queue-edit: not a readable file: '${file:-<empty>}'" >&2
    return 1
  fi
  # queue.json with a queue.yaml sibling in the same directory is the
  # tombstone shape: valid JSON, jq succeeds on it, and every write lands
  # on a file the live queue moved away from — silently, at rc 0. Refuse
  # rather than guess which one the caller meant. Keyed on the basename
  # queue.json specifically, not any *.json — an unrelated tasks.json
  # beside a queue.yaml is not this shape and must not be refused.
  case "$(basename "$file")" in
    queue.json)
      local sib="$(dirname "$file")/queue.yaml"
      if [ -e "$sib" ]; then
        echo "error: queue-edit: '$file' is JSON but a sibling queue exists at '$sib' — refusing to write to the stale JSON copy" >&2
        return 1
      fi
      ;;
  esac
  local lockdir tmp waited=0
  lockdir="$(dirname "$file")/.locks/queue.lock"
  # mkdir WITHOUT -p is the mutex, same reasoning as the qmd lock in reflect/reweave: `-p`
  # would return 0 on an existing directory and destroy mutual exclusion. Only the PARENT
  # is created with -p.
  mkdir -p "$(dirname "$lockdir")"
  until mkdir "$lockdir" 2>/dev/null; do
    if [ "$waited" -ge 60 ]; then
      echo "error: queue-edit: could not acquire $lockdir after ${waited}s" >&2
      echo "       if no other run is active, remove it: rm -rf '$lockdir'" >&2
      return 1
    fi
    sleep 2
    waited=$((waited + 2))
  done
  tmp="${file}.tmp.$$"
  local jqerr
  if ! jqerr=$(jq "$@" "$filter" "$file" 2>&1 1>"$tmp"); then
    rm -f "$tmp"
    rm -rf "$lockdir"
    echo "error: queue-edit: jq rejected the filter or its arguments against '$file'" >&2
    [ -n "$jqerr" ] && printf '%s\n' "$jqerr" >&2
    return 1
  fi
  # Guard the rename, discard the temp, name the path — the bump-version.sh remedy
  # verbatim. Leaving the temp on a failed mv is an undeclared second copy of the
  # queue; discarding it is safe because it is redundant with the file it failed to
  # replace, and the failed rename never touched that file.
  if ! mv "$tmp" "$file"; then
    echo "error: queue-edit: $file could not be moved into place" >&2
    rm -f "$tmp"
    rm -rf "$lockdir"
    return 1
  fi
  rm -rf "$lockdir"
}
