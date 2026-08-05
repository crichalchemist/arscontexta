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
    # SCOPE LIMITS — TWO, and the second is the larger one. It was
    # omitted from this list for a whole branch while the list read as
    # complete, which is the failure mode divergence 16 is about.
    #
    # 1. hooks.json matches "Write" only, so an Edit or MultiEdit that
    #    destroys a note never reaches this guard. Two of the three
    #    threat cases above (a truncated-read rewrite, a merge that
    #    kept one side) can arrive by either tool.
    # 2. THE CASE FILTER ABOVE IS `*/notes/*|*thinking/*`, HARDCODED.
    #    A generated vault renames its notes directory — the field
    #    vault's is `nodes/` — so on the very vault whose defect
    #    motivated this guard, the filter excludes every note before
    #    the guard is reached. The TEMPLATE spells that filter with a
    #    NOTES_DIR placeholder, which LOOKS like it avoids the problem
    #    and does not actually avoid it: nothing in this repo
    #    substitutes that placeholder — session-orient.sh records the
    #    same of its two neighbours — and a doubled-brace marker is not
    #    shell expansion, so an unsubstituted arm matches a literal
    #    path and fires on nothing. BOTH SIDES ARE BROKEN, differently.
    #    An earlier version of this comment credited the template with
    #    a fix a placeholder cannot deliver, which is the same
    #    over-credit this whole block exists to prevent.
    #
    # Neither is fixed here: widening the matcher changes what fires on
    # every edit in every installed vault, and widening the filter
    # changes what this hook validates for every user. Both are scope
    # decisions. What is fixed is that the list no longer reads as
    # complete while omitting the one that matters most.
    #
    # WHY IT CAN SEE THE OLD CONTENT: hooks.json lists write-validate
    # BEFORE auto-commit on the same PostToolUse matcher, so HEAD
    # should still hold the pre-write version at this instant.
    #
    # THAT IS AN ORDERING ASSUMPTION, NOT A GUARANTEE, and the
    # difference is worth stating rather than papering over.
    # auto-commit is declared "async": true, so list order does not
    # prove it has not already committed. hook-config.test.sh asserts
    # the LIST order — which is the only half of this a config test can
    # reach; nothing here observes execution order. If auto-commit does
    # win the race, HEAD holds the new content, this guard compares the
    # file to itself, and says nothing. The failure is one-directional:
    # this guard can fall SILENT, it cannot warn wrongly.
    #
    # WHAT IS SILENT BY DESIGN vs WHAT IS REPORTED. Three states are
    # silent because in each there is genuinely nothing to destroy:
    # the file is untracked, it is tracked but not yet in any commit,
    # or the repo has no commits at all. Two states are REPORTED,
    # because they mean the guard could not run — and a guard that goes
    # quiet when it cannot run is the defect it exists to catch: git is
    # absent, or this is not a git repository. Earlier revisions of
    # this comment claimed the second pair without implementing it.
    DIR=$(dirname "$FILE")
    if ! command -v git >/dev/null 2>&1; then
      WARNS="${WARNS}CONDITION: git absent, content-destruction guard did not run. "
    elif ! git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1; then
      WARNS="${WARNS}CONDITION: not a git repository, content-destruction guard did not run. "
    else
      REL=$(git -C "$DIR" ls-files --full-name --error-unmatch "$FILE" 2>/dev/null)
      # cat-file -e tests for the blob without materialising it, and
      # keeps the byte count below off command substitution, which
      # strips trailing newlines and would undercount the old file
      # against a new one measured with wc -c.
      if [ -n "$REL" ] && git -C "$DIR" cat-file -e "HEAD:$REL" 2>/dev/null; then
        OLD_B=$(git -C "$DIR" show "HEAD:$REL" 2>/dev/null | wc -c | tr -d ' ')
        NEW_B=$(wc -c < "$FILE" | tr -d ' ')
        # Links are counted separately from bytes because they fail
        # independently: a rewrite can keep its length and lose every
        # edge, which costs the graph more than the prose.
        #
        # KNOWN LIMIT: this counts `[[` inside fenced code blocks too.
        # reference/lib/link-extraction.sh has _strip_fences, and this
        # hook deliberately does not source it — the same call
        # divergence 12 records for session-orient.sh.template, where a
        # missing library would break every session rather than skew
        # one number. Both sides are counted the same way, so a fenced
        # `[[` only misleads when the fence itself changes.
        OLD_L=$(git -C "$DIR" show "HEAD:$REL" 2>/dev/null | grep -o '\[\[' | wc -l | tr -d ' ')
        NEW_L=$(grep -o '\[\[' "$FILE" | wc -l | tr -d ' ')
        # 50% of bytes, and a 200-byte floor so trimming a stub does
        # not warn. Thresholds are deliberately loud-but-rare: a guard
        # that cries wolf gets disabled, which is worse than none.
        #
        # THE LINK ARM HAS NO FLOOR AND FIRES ON LOSING ONE LINK, which
        # is a third number this comment used to claim did not exist
        # ("the only two numbers in this check"). It is deliberate and
        # it is a judgement call, not an oversight: a lost edge is
        # invisible in the note and visible only in the graph, so the
        # asymmetry with bytes is intended. /reduce and /reweave DO
        # legitimately drop edges, so if this proves noisy in practice
        # the fix is a floor here, not deleting the arm.
        # Mirrored in platforms/claude-code/hooks/write-validate.sh.template
        # section 1 — edit both, they are two declarations and not one
        # copy, so nothing but this note stops them drifting apart.
        if [ "${OLD_B:-0}" -gt 200 ] && [ $((NEW_B * 2)) -lt "$OLD_B" ]; then
          WARNS="${WARNS}CONTENT SHRANK ${OLD_B}->${NEW_B} bytes (over half removed) — confirm this was intended, not a partial write. "
        fi
        if [ "${NEW_L:-0}" -lt "${OLD_L:-0}" ]; then
          WARNS="${WARNS}LOST $((OLD_L - NEW_L)) of $OLD_L wiki links — graph edges removed. "
        fi
      fi
    fi

    if [ -n "$WARNS" ]; then
      FILENAME=$(basename "$FILE" .md)
      echo "{\"additionalContext\": \"Schema warnings for $FILENAME: $WARNS\"}"
    fi
    ;;
esac

exit 0
