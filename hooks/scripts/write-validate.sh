#!/bin/bash
# Ars Contexta — Schema Enforcement Hook
# Validates notes in the knowledge space have required fields.
# Runs as PostToolUse hook on Write events.
# Receives tool input as JSON on stdin.

# Only run in Ars Contexta vaults
GUARD_DIR="$(cd "$(dirname "$0")" && pwd)"
if ! "$GUARD_DIR/vaultguard.sh"; then
  cat > /dev/null  # drain stdin
  exit 0
fi

# Read JSON from stdin
INPUT=$(cat)

# Extract file path (requires jq)
if command -v jq &>/dev/null; then
  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
else
  # Fallback: try to extract with grep/sed if jq unavailable
  FILE=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | head -1 | sed 's/"file_path":"//;s/"//')
fi

# Early exit if no file path
[ -z "$FILE" ] && exit 0
[ ! -f "$FILE" ] && exit 0

# Only validate notes in the knowledge space
case "$FILE" in
  */notes/*|*thinking/*)
    WARNS=""
    if ! head -20 "$FILE" | grep -q "^description:"; then
      WARNS="${WARNS}Missing description field. "
    fi
    if ! head -20 "$FILE" | grep -q "^topics:"; then
      WARNS="${WARNS}Missing topics field. "
    fi
    if ! head -1 "$FILE" | grep -q "^---$"; then
      WARNS="${WARNS}Missing YAML frontmatter. "
    fi
    # ── CONTENT-DESTRUCTION GUARD ────────────────────────────────
    # A node-writing pass (/reduce, /reweave, /refactor, an extraction
    # subagent) can replace a developed note with a fragment: partial
    # subagent output, a rewrite from a truncated read, a merge that
    # kept one side. The result is a valid, schema-clean, much smaller
    # note — every check above passes and the loss is silent.
    #
    # WHY THIS CAN SEE THE OLD CONTENT AT ALL: hooks.json runs
    # write-validate BEFORE auto-commit on the same PostToolUse
    # matcher, so at this instant HEAD still holds the pre-write
    # version. That ordering is load-bearing; if auto-commit ever runs
    # first, this guard compares the file to itself and silently
    # passes. The order is asserted in reference/test/hook-config.test.sh.
    if command -v git >/dev/null 2>&1; then
      DIR=$(dirname "$FILE")
      REL=$(git -C "$DIR" ls-files --full-name --error-unmatch "$FILE" 2>/dev/null)
      if [ -n "$REL" ]; then
        OLD=$(git -C "$DIR" show "HEAD:$REL" 2>/dev/null)
        # Distinguish "no previous version" (a new note — nothing to
        # destroy) from "git could not answer". Only the second is a
        # gap, and it is reported rather than passed over: a guard that
        # goes quiet when it cannot run is the defect it exists to catch.
        if [ -n "$OLD" ]; then
          OLD_B=$(printf '%s' "$OLD" | wc -c | tr -d ' ')
          NEW_B=$(wc -c < "$FILE" | tr -d ' ')
          # Links are counted separately from bytes because they fail
          # independently: a rewrite can keep its length and lose every
          # edge, which costs the graph more than the prose.
          OLD_L=$(printf '%s' "$OLD" | grep -o '\[\[' | wc -l | tr -d ' ')
          NEW_L=$(grep -o '\[\[' "$FILE" | wc -l | tr -d ' ')
          # 50% of bytes, and a 200-byte floor so trimming a stub does
          # not warn. Thresholds are deliberately loud-but-rare: a guard
          # that cries wolf gets disabled, which is worse than none.
          if [ "${OLD_B:-0}" -gt 200 ] && [ $((NEW_B * 2)) -lt "$OLD_B" ]; then
            WARNS="${WARNS}CONTENT SHRANK ${OLD_B}->${NEW_B} bytes (over half removed) — confirm this was intended, not a partial write. "
          fi
          if [ "${NEW_L:-0}" -lt "${OLD_L:-0}" ]; then
            WARNS="${WARNS}LOST $((OLD_L - NEW_L)) of $OLD_L wiki links — graph edges removed. "
          fi
        fi
      fi
    else
      WARNS="${WARNS}CONDITION: git absent, content-destruction guard did not run. "
    fi

    if [ -n "$WARNS" ]; then
      FILENAME=$(basename "$FILE" .md)
      echo "{\"additionalContext\": \"Schema warnings for $FILENAME: $WARNS\"}"
    fi
    ;;
esac

exit 0
