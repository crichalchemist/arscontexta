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
#    on every exit path, no auto-break on staleness — see _queue_lock below and
#    skills/setup/SKILL.md's own ruling against mtime-based auto-break, which applies here too.
#
# 2. SEVEN DUPLICATED CALL SITES. One bug in the read-modify-write pattern is one bug in seven
#    places. Centralized so a future fix — or a future caller — has one function to call, not
#    one pattern to copy.
#
# Sourced by skill templates. Do NOT inline copies of this function anywhere.

QUEUE_EDIT_VERSION=2
# v2 (2026-08-15, ported from the field vault's ops/lib/queue-edit.sh v2) adds _queue_lock()
# and queue_yaml() for the live bare-list YAML queue, and makes queue_edit() REFUSE a .yaml
# target instead of failing obscurely inside jq. Callers testing `-lt 1` keep working; the
# seven skill fences now require >= 2 because they dispatch on queue format.

# The directory this library was sourced from, captured AT SOURCE TIME so queue_yaml can find
# its Python helper beside itself. `${BASH_SOURCE[0]:-$0}` covers both shells: bash sets
# BASH_SOURCE when sourcing; zsh leaves it unset but (with its default FUNCTION_ARGZERO) sets
# $0 to the sourced file's path while the file's top level runs. Capturing inside the function
# instead would read a $0 that has long since reverted to the caller.
QUEUE_EDIT_LIB_DIR="$(dirname "${BASH_SOURCE[0]:-$0}")"

# Shared by queue_edit and queue_yaml so both get identical mutual exclusion.
# Echoes the lockdir on success.
_queue_lock() {
  local file="$1" lockdir waited=0
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
  echo "$lockdir"
}

# queue_edit <jq-filter> <queue-file> [jq-args...]
#
# Applies <jq-filter> to <queue-file> under a lock, atomically (temp file + mv, never a
# partial write). Any [jq-args...] are passed through to jq BEFORE the filter — e.g.
# `queue_edit '(.tasks[] | select(.id==$id)).status = $status' "$QUEUE" --arg id "$TASK_ID"
# --arg status "done"`. Always prefer --arg over interpolating a shell variable directly into
# the filter string: a value containing a quote or jq metacharacter would corrupt the filter
# rather than just fail to match.
#
# Fails loud: missing/unreadable file, a YAML target, a filter jq itself rejects, or a lock
# that can't be acquired within 60s all print a reason to stderr and return 1. Success is
# silent, matching every one of the seven call sites this replaces — none of them printed
# anything on a normal write.
queue_edit() {
  local filter="$1" file="$2"
  shift 2
  if [ -z "$file" ] || [ ! -f "$file" ] || [ ! -r "$file" ]; then
    echo "error: queue-edit: not a readable file: '${file:-<empty>}'" >&2
    return 1
  fi
  # REFUSE YAML rather than fail obscurely inside jq. jq cannot read YAML at all, and the
  # live queue is a BARE LIST with no `.tasks` key — so a jq filter is wrong twice over.
  case "$file" in
    *.yaml|*.yml)
      echo "error: queue-edit: '$file' is YAML; jq cannot read it and there is no .tasks key." >&2
      echo "       use queue_yaml instead, e.g.:" >&2
      echo "         queue_yaml '$file' --where id=\"\$ID\" --set status=done" >&2
      return 1 ;;
  esac
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
  local lockdir tmp
  lockdir="$(_queue_lock "$file")" || return 1
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

# queue_yaml FILE --where k=v [--where k2=v2] --set f=v [--set f2=v2] [--append list=v]
# queue_yaml FILE --add-task k=v [k2=v2 ...]
#
# Surgical: edits LINES, so every byte outside a changed field is preserved. A load+dump
# round-trip is NOT acceptable here — measured 2026-08-12 in the field vault on its live
# 439,861-byte queue, python yaml rewrote 277 lines and `yq` rewrote 3,503 (277 even with
# -c), all by reflowing folded scalars. See the header of queue_edit.py beside this file.
#
# Fails loudly when --where matches nothing, instead of writing an unchanged file: a queue
# write that silently matches zero tasks is the exact failure this library was fixed to end.
# On success the helper reports the match count on stderr — a write matching more tasks than
# intended is as much a defect as one matching none, and only the caller knows which number
# is right.
queue_yaml() {
  local file="$1"
  shift
  if [ -z "$file" ] || [ ! -f "$file" ] || [ ! -r "$file" ]; then
    echo "error: queue-edit: not a readable file: '${file:-<empty>}'" >&2
    return 1
  fi
  local helper lockdir tmp
  helper="$QUEUE_EDIT_LIB_DIR/queue_edit.py"
  if [ ! -r "$helper" ]; then
    echo "error: queue-edit: helper not found at '$helper'" >&2
    echo "       queue_edit.py ships beside queue-edit.sh; run /arscontexta:upgrade to restore it" >&2
    return 1
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    echo "error: queue-edit: python3 is required for YAML queue writes and is not on PATH" >&2
    return 1
  fi
  lockdir="$(_queue_lock "$file")" || return 1
  tmp="${file}.tmp.$$"
  if ! python3 "$helper" "$file" "$@" > "$tmp"; then
    rm -f "$tmp"
    rm -rf "$lockdir"
    return 1
  fi
  if ! mv "$tmp" "$file"; then
    echo "error: queue-edit: $file could not be moved into place" >&2
    rm -f "$tmp"
    rm -rf "$lockdir"
    return 1
  fi
  rm -rf "$lockdir"
}
