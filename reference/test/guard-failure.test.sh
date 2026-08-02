#!/bin/bash
# guard-failure.test.sh — behavioral tests for check-portability.sh's own failure paths.
#
# WHY THIS EXISTS: the guard once passed every check it had while being broken.
# `scan_or_die` set `fail=1` inside a command substitution — a subshell — so the
# flag never reached the parent. The guard still exited non-zero, but only
# because the function's diagnostic went to STDOUT and was captured as a "hit",
# which made it report `grep -P found` when the real cause was an unreadable
# directory. Routing that message to stderr, the obvious cleanup, would have
# made it print PORTABILITY: PASS on a broken scan.
#
# CI runs the guard against this repo, which exercises only the PASS path. These
# assertions exercise the FAILURE path, which is the one that was wrong.
#
# THE DISCRIMINATING ASSERTIONS are the two about WHAT the guard says:
# "failure is reported as a scan failure" and "failure does NOT claim a grep -P
# defect". Verified against the real pre-fix code (commit 5562168): those two go
# red, and so does the exemption-anchoring one. Checking the exit code alone does
# NOT discriminate — the broken version also exited 1, which is precisely why the
# defect survived review.
#
# Note for anyone extending this file: redirecting the guard's own stdout does
# not neutralise the old bug. The leak was an internal `$( )` capture into
# `$hits`, so it happened regardless of where the script's stdout pointed. An
# earlier version of this comment claimed "run it with both streams discarded"
# was the discriminating check; that was wrong, and measured to be wrong.
#
# Run: bash reference/test/guard-failure.test.sh

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
GUARD="$HERE/../check-portability.sh"
passed=0; failed=0
TMPDIRS=()

ok()   { passed=$((passed+1)); }
fail() { failed=$((failed+1)); printf 'FAIL: %s\n  expected [%s] got [%s]\n' "$1" "$2" "$3"; }
eq()   { if [ "$2" = "$3" ]; then ok; else fail "$1" "$2" "$3"; fi; }

# Permissions are removed during these tests. Without this trap a failed
# assertion leaves a directory nothing can delete.
cleanup() {
  local d
  for d in "${TMPDIRS[@]:-}"; do
    [ -n "$d" ] || continue
    chmod -R u+rwX "$d" 2>/dev/null
    rm -rf "$d"
  done
}
trap cleanup EXIT INT TERM

# A root the guard accepts: all nine shipped directories must exist.
mkroot() {
  local d
  d=$(mktemp -d)
  TMPDIRS+=("$d")
  local sub
  for sub in skills skill-sources reference generators platforms presets hooks agents scripts; do
    mkdir -p "$d/$sub"
  done
  printf '%s' "$d"
}

# Exit code only — no pipeline, because PIPESTATUS is bash-only and reads empty
# under zsh, which renders as a blank rather than an error.
rc_of() { bash "$GUARD" "$1" >/dev/null 2>&1; printf '%s' "$?"; }
out_of() { bash "$GUARD" "$1" 2>/dev/null; }

# --- the failure path -------------------------------------------------------
# All nine directories exist and are readable, so the guard's directory-existence
# loop is provably silent. Only scan_or_die's return code can catch this. The
# predecessor review missed the defect because every mode it tried was caught by
# that loop instead.
R=$(mkroot)
printf 'harmless\n' > "$R/skills/unreadable.md"
chmod 000 "$R/skills/unreadable.md"

# Weak on its own — the broken version passed this too, by leaking its
# diagnostic into the variable the caller tested. Kept because a guard that
# stopped failing entirely would be a worse regression, not because it
# discriminates.
eq "unreadable file makes the guard fail"      "1"   "$(rc_of "$R")"

# These two are the real gate. Both go red against commit 5562168.
eq "failure is reported as a scan failure"     "yes" \
   "$(out_of "$R" | grep -q 'could not run' && echo yes || echo no)"
eq "failure does NOT claim a grep -P defect"   "yes" \
   "$(out_of "$R" | grep -q 'grep -P or --perl-regexp found' && echo no || echo yes)"
chmod 644 "$R/skills/unreadable.md"

# A clean tree must still pass, or the assertions above prove nothing: a guard
# that always failed would satisfy every one of them.
eq "clean tree still passes"                   "0"   "$(rc_of "$R")"

# --- exemption marker -------------------------------------------------------
E=$(mkroot)
printf 'rg -o "\\[\\[([^\\]]+)\\]\\]" a/  # portability-exempt: shape matcher\n' > "$E/skills/x.md"
eq "deliberate marker exempts"                 "0"   "$(rc_of "$E")"
eq "exemption is reported, not silent"         "yes" \
   "$(out_of "$E" | grep -q 'site(s) exempt' && echo yes || echo no)"

# Anchored to the start of a comment. An unanchored match reintroduced the very
# evasion this guard was told to remove: a trailing comment that merely names
# the mechanism must not grant it.
printf 'rg -o "\\[\\[([^\\]]+)\\]\\]" a/  # TODO: is this portability-exempt?\n' > "$E/skills/x.md"
eq "merely mentioning the marker does NOT exempt" "1" "$(rc_of "$E")"

# Over-filtering is the characteristic failure of exemption mechanisms: the
# exempted line must be removed without taking a real defect beside it.
{ printf 'rg -o "\\[\\[([^\\]]+)\\]\\]" a/  # portability-exempt: shape matcher\n'
  printf 'rg -o "\\[\\[([^\\]]+)\\]\\]" b/\n'; } > "$E/skills/x.md"
eq "exemption does not hide a defect beside it"   "1" "$(rc_of "$E")"

# --- evasion vectors --------------------------------------------------------
V=$(mkroot)
probe() {
  printf '%s\n' "$2" > "$V/skills/probe.md"
  local rc; rc=$(rc_of "$V")
  rm -f "$V/skills/probe.md"
  eq "$1" "1" "$rc"
}
probe "catches grep --perl-regexp" 'grep --perl-regexp "x" n/'
probe "catches egrep -oP"          'egrep -oP "x" n/'
probe "catches rg -P"              'rg -P "x" n/'
probe "catches rg --pcre2"         'rg --pcre2 "x" n/'
probe "catches greedy [[.*?]]"     "rg -o '\\[\\[.*?\\]\\]' n/"
eq "empty root passes after probes" "0" "$(rc_of "$V")"

# --- a missing scan directory -----------------------------------------------
eq "nonexistent root fails"        "1"   "$(rc_of "/nonexistent-root-xyz")"

printf '\npassed=%s failed=%s\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
