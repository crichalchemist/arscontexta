#!/bin/bash
# check-portability.sh — fail on shell constructs that break outside GNU userland.
#
# WHY $GREP IS /usr/bin/grep AND NOT `grep`:
# Claude Code's Bash tool aliases `grep` to a ugrep wrapper, which DOES support -P.
# Running these checks with bare `grep` makes them pass while the bug ships to users.
#
# WHY SCAN IS AN ARRAY:
# A space-joined string with unquoted $SCAN word-splits in bash but NOT in zsh,
# where it becomes one nonexistent path — and with 2>/dev/null that is a silent 0,
# i.e. the guard passes while every bug ships. Verified: bash 9 hits, zsh 0.

set -u
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
GREP=/usr/bin/grep
fail=0

red() { printf '  FAIL %s\n' "$1"; fail=1; }
ok()  { printf '  PASS %s\n' "$1"; }

SCAN=("$ROOT/skills" "$ROOT/skill-sources" "$ROOT/reference")

echo "=== Portability check: $ROOT ==="

echo "1. No PCRE grep (-P) in shipped templates"
hits=$("$GREP" -rn --include='*.md' --include='*.sh' --exclude='check-portability.sh' -E '(^|[^a-zA-Z_-])grep +[^|]*-[a-zA-Z]*P' \
  "${SCAN[@]}" 2>/dev/null || true)
if [ -n "$hits" ]; then
  red "grep -P found (exits 2 on BSD grep, silently yields 0):"
  printf '%s\n' "$hits" | sed 's/^/       /'
else
  ok "no grep -P"
fi

echo "2. Wiki-link capture terminates at | and #"
hits=$("$GREP" -rn --include='*.md' --include='*.sh' -F '\[\[' "${SCAN[@]}" 2>/dev/null \
  | "$GREP" -F '[^' | "$GREP" -v -F '|#' \
  | "$GREP" -v 'lib/link-extraction.sh' || true)
if [ -n "$hits" ]; then
  red "link capture does not exclude | and # (counts [[a|b]] and [[a#c]] as dangling):"
  printf '%s\n' "$hits" | sed 's/^/       /'
else
  ok "link capture terminates correctly"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "PORTABILITY: PASS"; exit 0
else
  echo "PORTABILITY: FAIL"; exit 1
fi
