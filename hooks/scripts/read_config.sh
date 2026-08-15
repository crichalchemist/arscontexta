#!/bin/bash
# Ars Contexta — Config Reader
# Usage: read_config.sh <key> [default]
#
#   read_config.sh git true                                 -> .arscontexta, top-level scalar
#   read_config.sh self_evolution.observation_threshold 10   -> ops/config.yaml, one level down
#
# Returns: the configured value, or the default if the key is not configured.
# Default default: "true" (preserves existing behaviour when no config exists).
#
# Migration: old marker files (cat face text) have no YAML keys,
# so grep returns nothing → defaults apply → behaviour unchanged.
#
# WHY TWO FILES AND NOT ONE. There are two config surfaces and they are not
# redundant: `.arscontexta` is the vault MARKER, which vaultguard.sh tests for to
# decide whether the hooks apply at all, and it doubles as a flat scalar config.
# `ops/config.yaml` is the vault's own settings, nested, and it is where the three
# skill templates (`next`, `remember`, `rethink`) read `self_evolution.*`.
#
# Until this routing existed, the SessionStart hook could not reach `ops/config.yaml`
# at all — a bare-key reader pointed at a different file. So a user who set
# `observation_threshold: 20` got the three skills honouring it and the hook still
# firing at its hardcoded 10, with nothing reporting the disagreement. The field
# vault is the evidence: someone wanted 20/10, hand-patched the hook because that was
# the only lever, and that vault's hook and its own config.yaml now disagree.
#
# Dotted keys route to ops/config.yaml; bare keys are unchanged. One level of nesting
# only — that is all `self_evolution.*` needs, and a general YAML parser in bash is
# how you get a second class of silent wrong answers.

KEY="$1"
DEFAULT="${2:-true}"

if [ -z "$KEY" ]; then
  echo "$DEFAULT"
  exit 0
fi

# Find project root — use CLAUDE_PROJECT_DIR if set, otherwise walk up
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

case "$KEY" in
  *.*)
    NESTED="$PROJECT_DIR/ops/config.yaml"
    SECTION="${KEY%%.*}"
    FIELD="${KEY#*.}"
    # ABSENT AND UNREADABLE ARE DIFFERENT ANSWERS, and `[ -f ]` cannot tell them
    # apart. A config the user wrote but this process cannot open returned the
    # DEFAULT at rc 0 with nothing on stderr: `[ -f ]` tests existence, and awk's
    # own `2>/dev/null` swallowed the permission error, so an empty LINE read as
    # "not configured". A vault whose owner set 20 was silently told 10 — the
    # precise failure divergence 3 exists to prevent, inside the routing added to
    # fix it. Reproduced with `chmod 000 ops/config.yaml`.
    if [ ! -e "$NESTED" ]; then echo "$DEFAULT"; exit 0; fi
    if [ ! -r "$NESTED" ]; then
      printf 'read_config: %s exists but cannot be read (permissions?): %s\n' "$NESTED" "$KEY" >&2
      exit 1
    fi

    # The field's raw line, if the section exists and contains it. Section ends at
    # the next column-0 line, so a same-named field in a different section cannot
    # be picked up.
    # FIXED-STRING matching via index(), not an interpolated ERE. The key used
    # to be spliced into two awk regexes, so an ERE metacharacter in it matched
    # arbitrary text — section `se+ction` found the header `seection:`. Same
    # fixed-string idiom frontmatter.sh uses.
    LINE=$(awk -v sec="$SECTION" -v fld="$FIELD" '
      # Section header: `sec:` at column 0, rest blank or a comment.
      (index($0, sec ":") == 1) {
        rest = substr($0, length(sec) + 2)
        sub(/^[[:space:]]*/, "", rest)
        if (rest == "" || substr(rest, 1, 1) == "#") { insec = 1; next }
      }
      ($0 ~ /^[^[:space:]#]/) { insec = 0 }
      (insec) {
        bare = $0; sub(/^[[:space:]]+/, "", bare)
        # bare != $0 keeps the original requirement that a field line be
        # indented, so a column-0 key of the same name is not picked up.
        if (bare != $0 && index(bare, fld ":") == 1) { print; exit }
      }
    ' "$NESTED" 2>/dev/null)

    # NOT CONFIGURED and CONFIGURED-BUT-UNREADABLE ARE DIFFERENT ANSWERS. Absent is
    # ordinary — return the default and say nothing. But a key the user wrote and
    # this reader cannot parse must NOT come back as the default: that is precisely
    # how the hook's hardcoded 10 stayed invisible while config.yaml said otherwise.
    [ -n "$LINE" ] || { echo "$DEFAULT"; exit 0; }

    VALUE=$(printf '%s\n' "$LINE" \
      | sed 's/[[:space:]]*#.*$//' \
      | sed 's/^[^:]*:[[:space:]]*//' \
      | sed 's/^["'"'"']//;s/["'"'"']$//' \
      | sed 's/[[:space:]]*$//')

    if [ -z "$VALUE" ]; then
      printf 'read_config: %s is set in %s but its value could not be read: %s\n' \
        "$KEY" "$NESTED" "$LINE" >&2
      exit 1
    fi
    echo "$VALUE"
    exit 0
    ;;
esac

CONFIG_FILE="$PROJECT_DIR/.arscontexta"

# Same distinction on the bare-key path, which had the identical hole: a
# `.arscontexta` at chmod 000 returned the default rather than saying it could
# not be read. Both paths now separate "absent" from "unreadable".
if [ ! -e "$CONFIG_FILE" ]; then
  echo "$DEFAULT"
  exit 0
fi
if [ ! -r "$CONFIG_FILE" ]; then
  printf 'read_config: %s exists but cannot be read (permissions?): %s\n' "$CONFIG_FILE" "$KEY" >&2
  exit 1
fi

# Simple YAML key-value reader (top-level scalar keys only)
# Handles: key: value, key: "value", key: 'value'
#
# FIXED-STRING key match, and ABSENT kept apart from PRESENT-BUT-EMPTY — the
# dotted path above already draws both distinctions and this path did not:
# `grep -E "^${KEY}:"` made the key a regex, and an empty VALUE collapsed
# "the user wrote this key with no readable value" into the default at rc 0.
# Returning the default for a key the user wrote verbatim is how divergence
# 3's hardcoded 10 stayed invisible.
LINE=$(awk -v k="$KEY" 'index($0, k ":") == 1 { print; exit }' "$CONFIG_FILE" 2>/dev/null)

# Absent is ordinary: return the default and say nothing.
if [ -z "$LINE" ]; then
  echo "$DEFAULT"
  exit 0
fi

VALUE=$(printf '%s\n' "$LINE" \
  | sed 's/[[:space:]]*#.*$//' \
  | sed 's/^[^:]*:[[:space:]]*//' \
  | sed 's/^["'"'"']//;s/["'"'"']$//' \
  | sed 's/[[:space:]]*$//')

if [ -z "$VALUE" ]; then
  printf 'read_config: %s is set in %s but its value could not be read: %s\n' "$KEY" "$CONFIG_FILE" "$LINE" >&2
  exit 1
fi
echo "$VALUE"
