#!/bin/bash
# Ars Contexta — Session Orientation Hook
# Injects workspace structure, identity, methodology, and maintenance signals at session start.
# Also handles session tracking (capture moved here from Stop hook — fires once per session).

# Only run in Ars Contexta vaults
GUARD_DIR="$(cd "$(dirname "$0")" && pwd)"
"$GUARD_DIR/vaultguard.sh" || exit 0

# ── Session tracking (silent — no stdout) ──────────────────────
# SessionStart provides session info as JSON on stdin.
# Read it before any echo statements.

INPUT=$(cat)
SESSION_ID=""
if command -v jq &>/dev/null; then
  SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
else
  SESSION_ID=$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | head -1 | sed 's/"session_id":"//;s/"//')
fi

READ_CONFIG="$GUARD_DIR/read_config.sh"

if [ -n "$SESSION_ID" ] && [ "$(bash "$READ_CONFIG" "session_capture" "true")" = "true" ]; then
  TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")
  mkdir -p ops/sessions

  # Promote previous session if it's a different ID
  if [ -f ops/sessions/current.json ]; then
    if command -v jq &>/dev/null; then
      PREV_ID=$(jq -r '.id // empty' ops/sessions/current.json)
      PREV_STARTED=$(jq -r '.started // empty' ops/sessions/current.json)
    else
      PREV_ID=$(grep -o '"id":"[^"]*"' ops/sessions/current.json | head -1 | sed 's/"id":"//;s/"//')
      PREV_STARTED=$(grep -o '"started":"[^"]*"' ops/sessions/current.json | head -1 | sed 's/"started":"//;s/"//')
    fi

    if [ -n "$PREV_ID" ] && [ "$PREV_ID" != "$SESSION_ID" ]; then
      # Different session — promote previous to timestamped archive
      ARCHIVE_TS="${PREV_STARTED:-$TIMESTAMP}"
      mv ops/sessions/current.json "ops/sessions/${ARCHIVE_TS}.json"
    fi
  fi

  # Write current session
  cat > ops/sessions/current.json << EOF
{
  "id": "$SESSION_ID",
  "started": "$TIMESTAMP",
  "status": "active"
}
EOF

  # Git commit if enabled
  if [ "$(bash "$READ_CONFIG" "git" "true")" = "true" ] && git rev-parse --is-inside-work-tree &>/dev/null; then
    git add ops/sessions/ 2>/dev/null
    [ -f self/goals.md ] && git add self/goals.md 2>/dev/null
    [ -f ops/goals.md ] && git add ops/goals.md 2>/dev/null
    git commit -m "Session start: ${TIMESTAMP}" --quiet --no-verify 2>/dev/null || true
  fi
fi

# Export session ID for later hooks
if [ -n "$CLAUDE_ENV_FILE" ] && [ -n "$SESSION_ID" ]; then
  echo "export CLAUDE_SESSION_ID='$SESSION_ID'" >> "$CLAUDE_ENV_FILE"
fi

# ── Context injection (stdout → conversation) ──────────────────

echo "## Workspace Structure"
echo ""

# Show directory tree (3 levels deep, markdown files only)
if command -v tree &> /dev/null; then
    tree -L 3 --charset ascii -I '.git|node_modules' -P '*.md' .
else
    find . -name "*.md" -not -path "./.git/*" -not -path "*/node_modules/*" -maxdepth 3 | sort | while read -r file; do
        depth=$(echo "$file" | tr -cd '/' | wc -c)
        indent=$(printf '%*s' "$((depth * 2))" '')
        basename=$(basename "$file")
        echo "${indent}${basename}"
    done
fi

echo ""
echo "---"
echo ""

# Previous session state (continuity)
if [ -f ops/sessions/current.json ]; then
  echo "--- Previous session context ---"
  cat ops/sessions/current.json
  echo ""
fi

# Persistent working memory (goals)
if [ -f self/goals.md ]; then
  cat self/goals.md
  echo ""
elif [ -f ops/goals.md ]; then
  cat ops/goals.md
  echo ""
fi

# Identity (if self space enabled)
if [ -f self/identity.md ]; then
  cat self/identity.md self/methodology.md 2>/dev/null
  echo ""
fi

# Learned behavioral patterns (recent methodology notes)
for f in $(ls -t ops/methodology/*.md 2>/dev/null | head -5); do
  head -3 "$f"
done

# Condition-based maintenance signals
# Count only the items that are actually open. Counting every file and calling the
# total "pending" nags forever on a vault whose observations are all resolved — the
# field instance hit exactly this and patched its own copy of this hook rather than
# the source. Reporting open-of-total makes the difference visible either way.
#
# Accept BOTH spellings: generated vaults write `status: open`, older templates
# write `status: pending`. Matching one alone yields 0 on half the vaults in
# existence, and a threshold that reads 0 can never fire.
#
# The FIELD is read from frontmatter, not matched line-anchored anywhere in the file.
# The `grep -rl '^status: pending'` spelling this replaced also matched a `status:`
# line in the BODY, including inside a fenced block, so an observation that quoted a
# schema example counted itself as open. Sourced, never re-implemented — a rule held
# by convention, not by a gate. See reference/lib/frontmatter.sh.
#
# THIS HOOK DOES NOT `exit 1` THE WAY THE SLASH COMMANDS DO. It runs at SessionStart,
# where aborting costs the user the entire orientation block over one missing file. It
# follows `threshold()` below instead: say the condition on stderr, OMIT the signal,
# let the session start. Omitting is visible. Substituting 0 would not be — and 0 is
# precisely the value that stops a threshold from ever firing.
FM_LIB="ops/lib/frontmatter.sh"
FM_OK=0
if [ -r "$FM_LIB" ] && . "$FM_LIB" 2>/dev/null; then
  FM_OK=1
else
  echo "CONDITION: ops/lib/frontmatter.sh missing or unreadable — observation and tension" >&2
  echo "  signals omitted this session. Run /arscontexta:upgrade to restore it." >&2
fi

# A directory that does not exist means that feature is not active — valid state, 0.
# A scan that FAILS over a directory that DOES exist omits the signal rather than
# reporting 0, for the reason stated above.
count_open_items() { # count_open_items <dir>
  [ -d "$1" ] || { printf '0'; return 0; }
  count_notes_by_field "$1" status pending open
}

OBS_TOTAL=$(ls -1 ops/observations/*.md 2>/dev/null | wc -l | tr -d ' ')
TENS_TOTAL=$(ls -1 ops/tensions/*.md 2>/dev/null | wc -l | tr -d ' ')
OBS_COUNT=""
TENS_COUNT=""
if [ "$FM_OK" -eq 1 ]; then
  OBS_COUNT=$(count_open_items ops/observations) || {
    echo "CONDITION: observation scan failed — signal omitted this session." >&2
    OBS_COUNT=""
  }
  TENS_COUNT=$(count_open_items ops/tensions) || {
    echo "CONDITION: tension scan failed — signal omitted this session." >&2
    TENS_COUNT=""
  }
fi
# NO `|| echo 0` HERE. `grep -c` prints `0` AND exits 1 when nothing matches, so a
# `|| echo 0` fallback fires *in addition* to the 0 already printed and the variable
# becomes the two-line string "0\n0". Every session start then emits
# `[: 0\n0: integer expected` and the -ge comparison below errors (rc 2) rather than
# evaluating. That is the repo's own named `grep -c || echo 0` family, and it was live
# here in the commonest state of all: a vault whose only session file is current.json.
# grep -c's printed 0 is already the answer.
SESS_COUNT=$(ls -1 ops/sessions/*.json 2>/dev/null | grep -cv current)
INBOX_COUNT=$(ls -1 inbox/*.md 2>/dev/null | wc -l | tr -d ' ')

# THESE TWO ARE READ, NOT HARDCODED — the three skill templates (`next`, `remember`,
# `rethink`) already read `self_evolution.*` from ops/config.yaml, and this hook used
# to hardcode the same defaults. Identical values hid the defect: a user who changed
# the threshold got the skills honouring it and this hook still firing at 10, with
# nothing reporting the split. `read_config.sh` routes dotted keys to ops/config.yaml.
#
# A value the user wrote but the reader cannot parse exits 1 rather than returning the
# default. Surface that in the orientation output instead of falling back silently —
# but do not abort the session over a config typo.
threshold() { # threshold <dotted-key> <default>
  local v
  if ! v=$(bash "$READ_CONFIG" "$1" "$2" 2>&1); then
    echo "CONDITION: $v — falling back to $2" >&2
    printf '%s' "$2"; return
  fi
  case "$v" in
    ''|*[!0-9]*)
      echo "CONDITION: $1 is '$v', which is not a number — falling back to $2" >&2
      printf '%s' "$2"; return ;;
  esac
  printf '%s' "$v"
}
OBS_THRESHOLD=$(threshold self_evolution.observation_threshold 10)
TENS_THRESHOLD=$(threshold self_evolution.tension_threshold 5)

# The -n guards are the omission path, not defensive padding: an unmeasured count is
# the empty string, and `[ "" -ge 10 ]` is an `integer expected` error, not a false.
# The condition was already reported on stderr where the count could not be taken.
if [ -n "$OBS_COUNT" ] && [ "$OBS_COUNT" -ge "$OBS_THRESHOLD" ]; then
  echo "CONDITION: $OBS_COUNT pending observations (of $OBS_TOTAL total). Consider /rethink."
fi
if [ -n "$TENS_COUNT" ] && [ "$TENS_COUNT" -ge "$TENS_THRESHOLD" ]; then
  echo "CONDITION: $TENS_COUNT unresolved tensions (of $TENS_TOTAL total). Consider /rethink."
fi
# UNDECLARED THRESHOLDS. These two, and the 30 in the staleness check below, appear in
# no config file — `ops/config.yaml` declares only `self_evolution.*`. They are left
# hardcoded rather than given invented config keys, but "one surface owns each
# threshold" is not yet true of them. Recorded in the ledger, not silently equalised.
if [ "$SESS_COUNT" -ge 5 ]; then
  echo "CONDITION: $SESS_COUNT unprocessed sessions. Consider /remember --mine-sessions."
fi
if [ "$INBOX_COUNT" -ge 3 ]; then
  echo "CONDITION: $INBOX_COUNT items in inbox. Consider /reduce or /pipeline."
fi

# Workboard reconciliation
if [ -f ops/scripts/reconcile.sh ]; then
  bash ops/scripts/reconcile.sh --compact 2>/dev/null
fi

# Methodology staleness check (Rule Zero)
if [ -d ops/methodology ] && [ -f ops/config.yaml ]; then
  # GNU `-c` first, BSD `-f` second: GNU reads `-f` as "filesystem status" and
  # exits 0 with Namelen/Type, so a `-f`-first chain never falls through on Linux.
  CONFIG_MTIME=$(stat -c %Y ops/config.yaml 2>/dev/null || stat -f %m ops/config.yaml 2>/dev/null || echo 0)
  NEWEST_METH=$(ls -t ops/methodology/*.md 2>/dev/null | head -1)
  if [ -n "$NEWEST_METH" ]; then
    METH_MTIME=$(stat -c %Y "$NEWEST_METH" 2>/dev/null || stat -f %m "$NEWEST_METH" 2>/dev/null || echo 0)
    DAYS_STALE=$(( (CONFIG_MTIME - METH_MTIME) / 86400 ))
    if [ "$DAYS_STALE" -ge 30 ]; then
      echo "CONDITION: Methodology notes are ${DAYS_STALE}+ days behind config changes. Consider /rethink drift."
    fi
  fi
fi
