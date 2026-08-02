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

# WHY scan_or_die REPORTS ON STDERR AND NEVER SETS `fail` ITSELF:
# Every caller runs this inside $( ), which is a subshell — a `fail=1` set here
# is discarded before the parent sees it (`fail=0; f(){ fail=1; }; x=$(f)` leaves
# fail=0). The guard previously appeared to fail on a broken scan only because
# this diagnostic went to STDOUT and got captured as a "hit", so the guard
# reported `grep -P found` when the real problem was an unreadable directory —
# a false defect — and routing the message to stderr would have made the guard
# report PASS on a failed scan. Diagnostics go to stderr; results go to stdout;
# the caller checks the return code in the PARENT shell and calls red().
scan_or_die() {            # scan_or_die <description> <grep-args...>
  local desc="$1"; shift
  local out rc
  out=$("$GREP" "$@" 2>/dev/null); rc=$?
  if [ "$rc" -gt 1 ]; then
    printf 'scan failed: %s (grep rc=%s) — cannot conclude anything\n' "$desc" "$rc" >&2
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
if hits=$(scan_or_die "grep -P scan" -rn --include='*.md' --include='*.sh' --exclude='check-portability.sh' -E '(^|[^a-zA-Z_-])(grep|egrep|fgrep|zgrep) +[^|]*(-[a-zA-Z]*P|--perl-regexp)' \
    "${SCAN[@]}"); then
  if [ -n "$hits" ]; then
    red "grep -P or --perl-regexp found (exits 2 on BSD grep, silently yields 0):"
    printf '%s\n' "$hits" | sed 's/^/       /'
  else
    ok "no grep -P"
  fi
else
  red "grep -P scan could not run (see stderr) — cannot conclude anything"
fi

echo "2. Wiki-link capture uses negated classes (not greedy dot quantifiers)"
# Both scans run BEFORE any filtering so their return codes reach this shell.
# Filtering inside the command substitution would give us the last filter's
# status instead; PIPESTATUS is bash-only (zsh spells it pipestatus) and this
# file must run under both.
# Part A: negated character classes that don't exclude the | and # boundaries.
raw_a=$(scan_or_die "link capture scan (negated class)" -rn --include='*.md' --include='*.sh' --exclude='check-portability.sh' -F '\[\[' "${SCAN[@]}")
scan_a_ok=$?
# Part B: greedy/lazy dot quantifiers — vector 4 evasion, e.g. \[\[.*?\]\].
raw_b=$(scan_or_die "link capture scan (greedy quantifiers)" -rn -E --include='*.md' --include='*.sh' --exclude='check-portability.sh' \
  '\\\[\\\[.*\.\*\?\\\]\\\]' "${SCAN[@]}")
scan_b_ok=$?
if [ "$scan_a_ok" -ne 0 ] || [ "$scan_b_ok" -ne 0 ]; then
  red "link capture scan could not run (see stderr) — cannot conclude anything"
else
  temp_a=$(printf '%s\n' "$raw_a" \
    | "$GREP" -F '[^' | "$GREP" -v -F '|#' \
    | "$GREP" -v '^[^:]*lib/link-extraction\.sh:')
  # Counted from the same input and marker as the filter below, so the reported
  # number is always exactly what was removed.
  exempt_count=$(printf '%s\n' "$temp_a" | "$GREP" -c 'portability-exempt' 2>/dev/null || true)
  exempt_count=${exempt_count:-0}
  hits_a=$(printf '%s\n' "$temp_a" | "$GREP" -v 'portability-exempt')  # Exempt shape matchers used with grep -v (not target extractors)
  hits_b=$(printf '%s\n' "$raw_b" | "$GREP" -v '^[^:]*lib/link-extraction\.sh:')
  hits="${hits_a}${hits_b:+
}${hits_b}"
  if [ -n "$hits" ]; then
    red "link capture does not use negated classes or excludes | and # (greedy [[.*]] or no boundaries):"
    printf '%s\n' "$hits" | sed 's/^/       /'
  else
    ok "link capture uses negated classes, terminates correctly"
  fi
  if [ "$exempt_count" -gt 0 ]; then
    echo "  NOTE: $exempt_count site(s) exempt via portability-exempt marker"
  fi
fi

echo "3. No PCRE via ripgrep (fails on rg builds without PCRE2)"
if hits=$(scan_or_die "rg PCRE" -rn --include='*.md' --include='*.sh' --exclude='check-portability.sh' \
    -E '(^|[^a-zA-Z_-])rg +[^|]*(-P|--pcre2)' "${SCAN[@]}"); then
  if [ -n "$hits" ]; then
    red "rg -P or --pcre2 found (fails on rg builds without PCRE2):"
    printf '%s\n' "$hits" | sed 's/^/       /'
  else
    ok "no rg PCRE"
  fi
else
  red "rg PCRE scan could not run (see stderr) — cannot conclude anything"
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
