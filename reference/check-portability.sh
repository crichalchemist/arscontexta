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

scan_or_die() {            # scan_or_die <description> <grep-args...>
  local desc="$1"; shift
  local out rc
  out=$("$GREP" "$@" 2>/dev/null); rc=$?
  if [ "$rc" -gt 1 ]; then
    printf '  FAIL %s: scan itself failed (grep rc=%s) — cannot conclude anything\n' "$desc" "$rc"
    fail=1
    return 2
  fi
  printf '%s' "$out"
  return 0
}

SCAN=("$ROOT/skills" "$ROOT/skill-sources" "$ROOT/reference" \
      "$ROOT/generators" "$ROOT/platforms" "$ROOT/presets" \
      "$ROOT/hooks" "$ROOT/agents" "$ROOT/scripts")

echo "=== Portability check: $ROOT ==="

for d in "${SCAN[@]}"; do
  [ -d "$d" ] || { printf '  FAIL scan directory missing: %s\n' "$d"; fail=1; }
done

echo "1. No PCRE grep (-P) or long-form in shipped templates"
hits=$(scan_or_die "grep -P scan" -rn --include='*.md' --include='*.sh' --exclude='check-portability.sh' -E '(^|[^a-zA-Z_-])(grep|egrep|fgrep|zgrep) +[^|]*(-[a-zA-Z]*P|--perl-regexp)' \
  "${SCAN[@]}")
if [ -n "$hits" ]; then
  red "grep -P or --perl-regexp found (exits 2 on BSD grep, silently yields 0):"
  printf '%s\n' "$hits" | sed 's/^/       /'
else
  ok "no grep -P"
fi

echo "2. Wiki-link capture terminates at | and #"
hits=$(scan_or_die "link capture scan" -rn --include='*.md' --include='*.sh' -F '\[\[' "${SCAN[@]}" \
  | "$GREP" -F '[^' | "$GREP" -v -F '|#' \
  | "$GREP" -v '^[^:]*lib/link-extraction\.sh:')
if [ -n "$hits" ]; then
  red "link capture does not exclude | and # (counts [[a|b]] and [[a#c]] as dangling):"
  printf '%s\n' "$hits" | sed 's/^/       /'
else
  ok "link capture terminates correctly"
fi

echo "3. No PCRE via ripgrep (fails on rg builds without PCRE2)"
hits=$(scan_or_die "rg PCRE" -rn --include='*.md' --include='*.sh' --exclude='check-portability.sh' \
  -E '(^|[^a-zA-Z_-])rg +[^|]*(-P|--pcre2)' "${SCAN[@]}")
if [ -n "$hits" ]; then
  red "rg -P or --pcre2 found (fails on rg builds without PCRE2):"
  printf '%s\n' "$hits" | sed 's/^/       /'
else
  ok "no rg PCRE"
fi

# KNOWN BLIND SPOT (matching direction):
# This guard checks extraction direction only — it verifies that extracted links
# terminate at | and #. It does NOT check matching direction — whether searches
# for links correctly handle [[slug|alias]] and [[slug#heading]] patterns.
#
# The following 9 sites use rg -l or grep -rl with bare [[NAME]] patterns,
# which miss [[NAME|alias]] and [[NAME#heading]] variations. These cause false
# positives in orphan detection and MOC coverage reports. The guard does not flag
# these because checking would require recursive template evaluation (matching
# direction requires parsing both link format AND file search scope simultaneously).
#
# Sites with matching direction blind spot (by content type):
#   Orphan detection in skill MOCs:
#     skills/architect/SKILL.md (grep -rl, 1 instance)
#     skills/health/SKILL.md (rg -l, 3 instances)
#   Backlink counts in skill-sources:
#     skill-sources/graph/SKILL.md (grep -rl, 4 instances)
#   Milestone testing:
#     reference/testing-milestones.md (grep -rl, 1 instance)
#
# Future work: Add a separate guard for matching direction or migrate to unified
# pattern that captures variants at extraction time (not search time).

echo
if [ "$fail" -eq 0 ]; then
  echo "PORTABILITY: PASS"; exit 0
else
  echo "PORTABILITY: FAIL"; exit 1
fi
