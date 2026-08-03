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
# The four spellings below all PASSED the guard before check 2 part B was
# broadened: it matched the literal `.*?` text only. Each is an equally valid
# way to write the same defect, and part A cannot catch any of them — it keys
# on `[^` being present, and none of these contain a negated class. A probe
# that passes both before and after the fix proves nothing, so these were
# confirmed red against the pre-fix pattern.
probe "catches greedy [[.*]]"      "rg -o '\\[\\[.*\\]\\]' n/"
probe "catches lazy [[.+?]]"       "rg -o '\\[\\[.+?\\]\\]' n/"
probe "catches grouped [[(.+)]]"   "rg -o '\\[\\[(.+)\\]\\]' n/"
probe "catches grouped [[(.*)]]"   "rg -o '\\[\\[(.*)\\]\\]' n/"
eq "empty root passes after probes" "0" "$(rc_of "$V")"

# --- a missing scan directory -----------------------------------------------
eq "nonexistent root fails"        "1"   "$(rc_of "/nonexistent-root-xyz")"

# --- check 4: the freeze ----------------------------------------------------
# WHY THESE EXIST: check 4 shipped with zero automated coverage. Every mkroot()
# above lands in its SKIP branch, so all four gates exercised the one path that
# does nothing, and its three violation paths were evidenced only by a hand-run
# probe table in a git-ignored ledger. That is the same trap the freeze itself was
# added to close, from the other side: a check nothing tests can regress while
# every gate stays green. It already did once — the first version failed on any
# tree without the frozen directory, which broke the three assertions above that
# prove this guard is not vacuous.
#
# A two-file fixture, not a copy of the real directory: these assert the check's
# LOGIC, and pinning them to the shipped 16 would make every legitimate manifest
# regeneration look like a test failure.
mkfrozen() {
  local d
  d=$(mkroot)
  mkdir -p "$d/platforms/shared/skill-blocks"
  printf 'alpha\n' > "$d/platforms/shared/skill-blocks/a.md"
  printf 'beta\n'  > "$d/platforms/shared/skill-blocks/b.md"
  # Same format the check parses: "<cksum-with-dashes> <basename>", sorted.
  ( cd "$d/platforms/shared/skill-blocks" && for f in a.md b.md; do
      printf '%s %s\n' "$(cksum < "$f" | tr -s ' ' | tr ' ' '-')" "$f"
    done | sort ) > "$d/reference/skill-blocks.frozen"
  # CLAUDE.md marks this as an arscontexta root, so removing the freeze is a
  # failure rather than a skip.
  printf '# marker\n' > "$d/CLAUDE.md"
  printf '%s' "$d"
}

Z=$(mkfrozen)
eq "frozen: intact tree passes"       "0" "$(rc_of "$Z")"
printf 'edited\n' >> "$Z/platforms/shared/skill-blocks/a.md"
eq "frozen: modified file fails"      "1" "$(rc_of "$Z")"

Z=$(mkfrozen); rm "$Z/platforms/shared/skill-blocks/b.md"
eq "frozen: deleted file fails"       "1" "$(rc_of "$Z")"

# Nested, because a top-level *.md glob let sub/*.md through while the prose
# claimed any edit was rejected — a contributor porting guards into a subdirectory
# is exactly the scenario the freeze exists to stop.
Z=$(mkfrozen); mkdir -p "$Z/platforms/shared/skill-blocks/sub"
printf 'x\n' > "$Z/platforms/shared/skill-blocks/sub/evil.md"
eq "frozen: nested addition fails"    "1" "$(rc_of "$Z")"

Z=$(mkfrozen); printf 'x\n' > "$Z/platforms/shared/skill-blocks/.hidden.md"
eq "frozen: dotfile addition fails"   "1" "$(rc_of "$Z")"

# Deleting the manifest is the documented way someone would "let an edit through".
Z=$(mkfrozen); rm "$Z/reference/skill-blocks.frozen"
eq "frozen: manifest deletion fails"  "1" "$(rc_of "$Z")"

# Removing BOTH from a tree that still has CLAUDE.md is removal, not absence.
Z=$(mkfrozen); rm -rf "$Z/platforms/shared/skill-blocks" "$Z/reference/skill-blocks.frozen"
eq "frozen: removing both fails"      "1" "$(rc_of "$Z")"

# ...but a tree that never claimed a freeze must still pass, or check 4 becomes
# the every-tree-but-one guard it was the first time.
Z=$(mkfrozen); rm -rf "$Z/platforms/shared/skill-blocks" "$Z/reference/skill-blocks.frozen" "$Z/CLAUDE.md"
eq "frozen: unclaimed tree skips"     "0" "$(rc_of "$Z")"

# A manifest whose last line has no newline must not silently un-freeze that entry:
# `read` returns non-zero at EOF, so the loop body would never run for it.
Z=$(mkfrozen)
printf '%s' "$(cat "$Z/reference/skill-blocks.frozen")" > "$Z/reference/skill-blocks.frozen.tmp"
mv "$Z/reference/skill-blocks.frozen.tmp" "$Z/reference/skill-blocks.frozen"
printf 'edited\n' >> "$Z/platforms/shared/skill-blocks/b.md"
eq "frozen: no-trailing-newline still checks last entry" "1" "$(rc_of "$Z")"

# The violation channel must not depend on writing to ROOT. It once did, via a
# temp file whose write nobody checked, so a read-only checkout reported PASS on a
# modified template: rc 0, plausible line, no error on stdout.
Z=$(mkfrozen); printf 'edited\n' >> "$Z/platforms/shared/skill-blocks/a.md"
chmod a-w "$Z"
eq "frozen: read-only root still reports the violation" "1" "$(rc_of "$Z")"
chmod u+w "$Z"

printf '\npassed=%s failed=%s\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
