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

# WHY TWO FILES ARE EXCLUDED FROM EVERY SCAN:
# Both must CONTAIN the constructs this guard forbids in order to do their jobs —
# this file states the patterns it searches for, and guard-failure.test.sh writes
# `grep -P` / `rg -P` payloads into fixtures and greps for this guard's own output
# text. Neither ever executes them. Excluding them by filename is narrower than
# excluding a directory, and it keeps every other file under reference/ scanned.
#
# This is a genuine exemption for checks 1 and 3, which the exemption-marker
# comment further down says cannot exist. Both statements hold: the marker is a
# per-LINE mechanism for code that runs, and there is no line of running code
# that needs `grep -P`. A whole file whose purpose is to test the guard is a
# different category, handled at file level, exactly as this file always was.
#
# The cost is a real blind spot: a genuine defect inside guard-failure.test.sh
# would not be caught. Accepted because that file ships no vault behaviour, but
# do not extend this list without the same reasoning.
#
# WHY THE EXCLUSION IS A PATH FILTER AND NOT `--exclude`:
# grep's --exclude matches BASENAMES anywhere in the tree, so `--exclude=
# 'guard-failure.test.sh'` would also skip a file of that name dropped into
# skill-sources/ — a one-rename evasion, and the same shape as the content-based
# exclusions already removed from this guard twice. Verified before the change:
# a `grep -P` planted in skill-sources/guard-failure.test.sh was not reported.
# Filtering on the full path after the scan pins each exemption to one location.
EXEMPT_PATHS='^[^:]*reference/(check-portability\.sh|test/guard-failure\.test\.sh):'
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
if hits=$(scan_or_die "grep -P scan" -rn --include='*.md' --include='*.sh' -E '(^|[^a-zA-Z_-])(grep|egrep|fgrep|zgrep) +[^|]*(-[a-zA-Z]*P|--perl-regexp)' \
    "${SCAN[@]}"); then
  hits=$(printf '%s\n' "$hits" | "$GREP" -Ev "$EXEMPT_PATHS")
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
raw_a=$(scan_or_die "link capture scan (negated class)" -rn --include='*.md' --include='*.sh' -F '\[\[' "${SCAN[@]}")
scan_a_ok=$?
# Part B: greedy/lazy dot-or-plus quantifiers between \[\[ and \]\] — vector 4
# evasion. This matched ONLY the literal `.*?` spelling; verified against a
# planted fixture, `\[\[.*\]\]`, `\[\[.+?\]\]` and `\[\[(.+)\]\]` all passed.
# Part A cannot cover them either: it keys on `[^` being PRESENT, and a dot
# quantifier contains no negated class at all. `\.[*+]\??` spans greedy and
# lazy forms of both quantifiers, with `.*` on each side so a capture group or
# any other wrapping around the quantifier does not evade the match.
raw_b=$(scan_or_die "link capture scan (greedy quantifiers)" -rn -E --include='*.md' --include='*.sh' \
  '\\\[\\\[.*\.[*+]\??.*\\\]\\\]' "${SCAN[@]}")
scan_b_ok=$?
if [ "$scan_a_ok" -ne 0 ] || [ "$scan_b_ok" -ne 0 ]; then
  red "link capture scan could not run (see stderr) — cannot conclude anything"
else
  temp_a=$(printf '%s\n' "$raw_a" \
    | "$GREP" -F '[^' | "$GREP" -v -F '|#' \
    | "$GREP" -v '^[^:]*lib/link-extraction\.sh:' \
    | "$GREP" -Ev "$EXEMPT_PATHS")
  # Counted from the same input and marker as the filter below, so the reported
  # number is always exactly what was removed.
  # ANCHORED to the start of a comment, not matched anywhere in the line. An
  # unanchored match reintroduced exactly the evasion this task was told to
  # remove: the old library exclusion was content-based, so a trailing comment
  # naming that path could hide a defect, and it was replaced with a path-based
  # test. An unanchored `portability-exempt` had the same shape — verified, a
  # line reading `rg -o "\[\[([^\]]+)\]\]" notes/  # TODO: is this
  # portability-exempt?` was silently excluded and the guard reported PASS.
  # Merely ASKING about the marker must not grant it.
  exempt_count=$(printf '%s\n' "$temp_a" | "$GREP" -c '#[[:space:]]*portability-exempt' 2>/dev/null || true)
  exempt_count=${exempt_count:-0}
  # SCOPE OF THE EXEMPTION MARKER — deliberately narrow, and verified so:
  # `portability-exempt` is honoured HERE ONLY (check 2, part A). It is silently
  # ignored by check 1 (grep -P) and by part B (greedy quantifiers). That is
  # intentional: part A is a SHAPE HEURISTIC — it flags any line containing `[^`
  # without `|#`, which false-positives on lines that merely match a shape rather
  # than extract link targets (see skills/health/SKILL.md). The other two detect
  # constructs with no legitimate use at all: `grep -P` exits 2 on BSD grep
  # everywhere, and a greedy `[[.*]]` never terminates correctly. There is no
  # such thing as a justified exemption for those, so the marker must not appear
  # to offer one.
  # The name reads as universal, so say plainly that it is not: a contributor who
  # adds the marker to a check-1 hit will see it ignored, and the dangerous next
  # move is widening an exclusion or deleting a check. If you hit a genuine false
  # positive in check 1 or part B, fix the pattern — do not reach for the marker.
  hits_a=$(printf '%s\n' "$temp_a" | "$GREP" -v '#[[:space:]]*portability-exempt')
  hits_b=$(printf '%s\n' "$raw_b" | "$GREP" -v '^[^:]*lib/link-extraction\.sh:' \
    | "$GREP" -Ev "$EXEMPT_PATHS")
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
if hits=$(scan_or_die "rg PCRE" -rn --include='*.md' --include='*.sh' \
    -E '(^|[^a-zA-Z_-])rg +[^|]*(-P|--pcre2)' "${SCAN[@]}"); then
  hits=$(printf '%s\n' "$hits" | "$GREP" -Ev "$EXEMPT_PATHS")
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
# The following 11 sites use rg -l or grep -rl with bare [[NAME]] patterns,
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
#     skill-sources/stats/SKILL.md (grep -rl, 2 instances)
#   Milestone testing:
#     reference/testing-milestones.md (grep -rl, 1 instance)
#
# Count this by enumeration, not from memory — it has been wrong twice. It read
# "13 sites" (stale from the predecessor branch, citing line numbers that had
# since moved or been deleted), then "9 sites" after a correction that dropped
# skill-sources/stats entirely. Both undercounts made the blind spot look
# smaller than it is, which defeats the only purpose this comment has. To
# re-derive:
#   /usr/bin/grep -nE '(rg -l|grep -rl|grep -l)[^|]*\\\[\\\[\$' <file>
# across the five files above. Deliberately no line numbers here: they drift on
# every edit, and a stale number is what produced both wrong counts.
#
# Future work: Add a separate guard for matching direction or migrate to unified
# pattern that captures variants at extraction time (not search time).

echo
if [ "$fail" -eq 0 ]; then
  echo "PORTABILITY: PASS"; exit 0
else
  echo "PORTABILITY: FAIL"; exit 1
fi
