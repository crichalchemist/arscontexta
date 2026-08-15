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

# WHY `bash "$GUARD"` AND NOT `"$SELF" "$GUARD"` — asked and settled, not overlooked.
#
# THE ARGUMENT IS THE INVOCATION SURFACE, NOT THE SHEBANG. A shebang proves nothing
# on its own: `scripts/bump-version.sh` also carries a bash shebang and is also run
# as `bash …` in CI, and it shipped a zsh fork regardless, because a human typed
# `zsh bump-version.sh`. What distinguishes this guard is that NOTHING invokes it by
# any other name — CI, `.pre-commit-config.yaml` and CLAUDE.md's instructions every
# one of them spell `bash reference/check-portability.sh`. It is never typed by
# hand under an arbitrary shell, so running it under zsh here would exercise a
# configuration that does not occur and could only manufacture false reds.
# `bump-version.test.sh` makes the opposite call for the opposite reason.
#
# What the zsh run of THIS file exercises is therefore the harness's own
# portability, not the guard's. The fence gate is the one that genuinely runs the
# same code under both, because Claude really does invoke those fences under
# whatever shell the user has.
#
# PINNED ON THE THING THE ARGUMENT RESTS ON. If a caller ever invokes the guard
# under another shell, the premise is gone and this assertion goes red, which forces
# whoever added that caller back to this decision.
# NOT HERMETIC, UNLIKE EVERY OTHER ASSERTION IN THIS FILE. These two read the real
# checkout rather than a synthetic root, because the claim is about the real callers
# and nothing else can stand in for them. Consequence: in a tree without `.github/`
# and `.pre-commit-config.yaml` — a packaged plugin, an export, a vendored copy —
# this pair goes red for a reason unrelated to the guard's behaviour.
REPO="$HERE/../.."

# The caller list is asserted to be non-empty FIRST. `$ROOT` was used here for one
# revision; it is not defined in this file, so under `set -u` the substitution
# subshell died and the result came back empty — and empty is what PASSING looks
# like for the negative assertion below. It went green having grepped nothing. A
# negative assertion needs a positive one beside it or it passes on absence.
raw=$(grep -rn 'check-portability\.sh' "$REPO/.github" "$REPO/.pre-commit-config.yaml" 2>/dev/null)
callers=$(printf '%s\n' "$raw" | grep -c .)
eq "the guard's callers are findable at all"           "yes" \
   "$([ "${callers:-0}" -ge 2 ] && echo yes || echo no)"

# MATCH THE INVOCATION POSITION, NOT THE SUBSTRING `bash` ANYWHERE IN THE RECORD.
# Two earlier filters were wrong in opposite directions. One exact string missed
# `bash -n reference/…`, which is bash. Then `grep -v bash` over the whole
# `path:lineno:content` record could be defeated two ways, both measured green at
# 34/34 with zero bash invocations anywhere: a workflow named `bash-checks.yml` hid
# every line in the file behind its own path, and `zsh … # was bash` hid one line
# behind a comment. The positive assertion above does not cover either, because it
# counts the same records without the filter.
#
# So: strip `path:lineno:` before filtering, and require `bash`, optional flags, and
# then the path — the shape of an invocation rather than an appearance of the word.
invocations=$(printf '%s\n' "$raw" | while IFS= read -r line; do
  [ -n "$line" ] || continue
  content=${line#*:}; content=${content#*:}
  printf '%s\n' "$content" \
    | grep -qE '(^|[^-[:alnum:]_])bash( +-[[:alnum:]]+)* +[^ ]*check-portability\.sh' \
    || printf '%s\n' "$line"
done)
eq "nothing invokes the guard under a shell other than bash" "" "$invocations"
# Kept as a consistency check on the same premise: a caller saying `bash` while the
# file declares another interpreter is a contradiction, whichever one is wrong.
eq "the guard declares bash too"                       "#!/bin/bash" "$(head -1 "$GUARD")"

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

# The exit code alone does NOT reach the DELETED branch. `cksum < <missing>` yields
# an empty digest, the comparison against the pinned one fails, and the file is
# reported MODIFIED at the same rc 1 — so mutating `if [ ! -f "$FROZEN_DIR/$name" ]`
# to `if false` leaves the assertion above green. Verified by that mutation: these
# two go red, the one above does not.
#
# The mislabel is not merely lossy. A deletion counted as MODIFIED feeds the n_mod
# tally in check-portability.sh, whose "suspect a differing cksum implementation
# before suspecting N edits" NOTE fires when every pinned file reports MODIFIED —
# so deleting the directory's contents would print a diagnosis pointing the reader
# at their machine rather than at the missing files.
eq "frozen: a deletion is reported as DELETED"      "yes" \
   "$(out_of "$Z" | grep -q 'DELETED b.md' && echo yes || echo no)"
eq "frozen: a deletion is NOT reported as MODIFIED" "yes" \
   "$(out_of "$Z" | grep -q 'MODIFIED b.md' && echo no || echo yes)"

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

# --- check 6: interpolated wiki-link matchers ---------------------------------
# WHY THESE EXIST: check 4 shipped with zero automated coverage and this file's
# freeze section says so in its own header. Check 6 arrived with four hand-run
# probes in a scratch copy, which is the same evidence-in-a-ledger the freeze
# section was written to replace: a hand-run probe proves the check worked once,
# on one machine, on a tree nobody kept.
#
# WHY THE FIXTURES DO NOT RECREATE THE SHIPPED ALLOWLIST:
# The allowlist lives in check-portability.sh, not in the tree, so a fixture that
# reproduced all five entries would fail the moment a sixth site is legitimately
# allowlisted — the brittleness mkfrozen() avoids by pinning two files instead of
# the shipped sixteen. These assert the check's LOGIC: an unlisted hit fails, an
# entry that no longer matches fails, a declared count that moved fails, and a
# tree claiming nothing skips. Each holds whatever the shipped list contains.
INTERP='LINKS=$(grep -rl "\[\[$NAME\]\]" notes/ | wc -l)'

# A tree with none of the allowlisted files and no interpolated matcher claims
# nothing. This is the assertion that keeps check 6 from doing what check 4 once
# did to this suite (19/19 -> 16/3): every mkroot() above lands here, so a check
# that red()s on a clean synthetic tree fails on every tree but the repo itself.
I=$(mkroot)
eq "interp: a tree claiming nothing passes"  "0" "$(rc_of "$I")"
eq "interp: and says SKIP, not PASS"       "yes" \
   "$(out_of "$I" | grep -q 'SKIP no allowlisted file present' && echo yes || echo no)"

# An interpolated matcher in a file no entry covers.
I=$(mkroot); printf '%s\n' "$INTERP" > "$I/skill-sources/zzz-arbitrary.md"
eq "interp: an unlisted site fails"          "1" "$(rc_of "$I")"
eq "interp: and is named UNLISTED"         "yes" \
   "$(out_of "$I" | grep -q 'UNLISTED skill-sources/zzz-arbitrary.md' && echo yes || echo no)"
# The GONE half must stay quiet here. $ROOT is an argument, so this guard runs
# against fixture trees and can be run against a generated vault; neither has any
# reason to hold skills/architect/SKILL.md. Reporting every entry GONE would bury
# the real finding above under five lines about files never expected here.
eq "interp: absent entries are not reported GONE in a tree carrying none" "yes" \
   "$(out_of "$I" | grep -q 'the file is gone' && echo no || echo yes)"

# An allowlisted file that is present but no longer matches — the direction that
# makes the list drain instead of rot. Without it a site fixed on another branch
# leaves its entry behind, and the next reader treats a closed defect as open.
# That is not hypothetical: it is what check 6 found on introduction, in the
# hand-maintained comment it replaced, which still named two files converted on
# fix/spec-f-divergence-drain.
I=$(mkroot); printf 'no matcher here\n' > "$I/reference/testing-milestones.md"
eq "interp: a listed site that was fixed fails" "1" "$(rc_of "$I")"
eq "interp: and is named STALE, by the FIXED arm"  "yes" \
   "$(out_of "$I" | grep -q 'STALE reference/testing-milestones.md — allowlisted but no longer matches' \
      && echo yes || echo no)"

# The OTHER stale arm: entry present in the allowlist, file absent from a tree that
# carries at least one of the others. Without this the arm had no positive assertion
# at all — deleting it outright left the suite green while a repo copy missing an
# allowlisted file went from FAIL to PASS. The two arms also have to be told apart,
# so each assertion greps its own wording rather than the shared 'STALE <path>'.
I=$(mkroot); printf '%s\n' "$INTERP" > "$I/reference/testing-milestones.md"
eq "interp: a listed file that is GONE fails"     "1" "$(rc_of "$I")"
eq "interp: and is named STALE, by the GONE arm"  "yes" \
   "$(out_of "$I" | grep -q 'STALE generators/features/maintenance.md — allowlisted but the file is gone' \
      && echo yes || echo no)" # a deferred entry, so draining a converted site cannot break this fixture again
# ...and the file that IS present with its declared count must NOT be reported.
eq "interp: a correct entry is not reported"      "yes" \
   "$(out_of "$I" | grep -q 'testing-milestones' && echo no || echo yes)"

# A declared count that no longer matches. This is why entries carry a count and
# not a bare path: with a path alone, a file could quietly grow a second site
# behind its first and absorb it.
I=$(mkroot); { printf '%s\n' "$INTERP"; printf '%s\n' "$INTERP"; } > "$I/reference/testing-milestones.md"
eq "interp: a count that moved fails"          "1" "$(rc_of "$I")"
eq "interp: and reports COUNT CHANGED with both numbers" "yes" \
   "$(out_of "$I" | grep -q 'COUNT CHANGED reference/testing-milestones.md — allowlist declares 1, tree has 2' \
      && echo yes || echo no)"

# The scan must reach *.template. Until check 6 was written every scan here passed
# --include='*.md' --include='*.sh', which matches no template at all, so the
# highest-blast-radius site in this class was invisible to the whole file.
I=$(mkroot); mkdir -p "$I/platforms/claude-code/hooks"
printf '%s\n' "$INTERP" > "$I/platforms/claude-code/hooks/probe.sh.template"
eq "interp: a .template is scanned, not skipped by --include" "yes" \
   "$(out_of "$I" | grep -q 'UNLISTED platforms/claude-code/hooks/probe.sh.template' && echo yes || echo no)"

# --- checks 1-3 reach *.template ----------------------------------------------
# WHY THESE EXIST: until check 6 was written every scan in the guard passed
# --include='*.md' --include='*.sh', which matches no template at all, so a
# `grep -P` or `rg -P` in any of the four platform hook templates was reported by
# nothing. The widening that fixed it had zero coverage of its own: stripping
# *.template from checks 1, 2A, 2B and 3 left this suite green and the repo run
# PASSing, which is the same untested-widening shape check 4 shipped with.
#
# The adapter READS those templates during generation (generator.md:27), so a
# construct there can reach a derived vault's hook. That is why they are scanned
# rather than treated as inert documentation.
I=$(mkroot); mkdir -p "$I/platforms/claude-code/hooks"
printf '%s\n' 'x=$(grep -P "^\d+" "$LOG")' > "$I/platforms/claude-code/hooks/probe.sh.template"
eq "check 1 reaches a .template"              "1" "$(rc_of "$I")"
eq "check 1 names the .template"            "yes" \
   "$(out_of "$I" | grep -q 'probe.sh.template' && echo yes || echo no)"

I=$(mkroot); mkdir -p "$I/platforms/claude-code/hooks"
printf '%s\n' 'x=$(rg -P "^\d+" "$LOG")' > "$I/platforms/claude-code/hooks/probe.sh.template"
eq "check 3 reaches a .template"              "1" "$(rc_of "$I")"
eq "check 3 names the .template"            "yes" \
   "$(out_of "$I" | grep -q 'probe.sh.template' && echo yes || echo no)"

# CHECK 2 HAS TWO PARTS AND BOTH NEED THEIR OWN ASSERTION. The first version of
# this section covered checks 1 and 3 only, and the mutation used to justify it
# stripped *.template from all four scans AT ONCE — a compound mutation cannot
# tell which scans an assertion actually covers. Neutered independently, 2A and 2B
# both stayed green at 51/0 while shipping narrowed. Same trap as a suite total
# rising without any new row being able to fail.
# 2A: a negated class that does not exclude the | and # boundaries.
I=$(mkroot); mkdir -p "$I/platforms/claude-code/hooks"
printf '%s\n' "rg -o '\\[\\[([^\\]]+)\\]\\]' notes/" > "$I/platforms/claude-code/hooks/probe.sh.template"
eq "check 2A reaches a .template"             "1" "$(rc_of "$I")"
eq "check 2A names the .template"           "yes" \
   "$(out_of "$I" | grep -q 'probe.sh.template' && echo yes || echo no)"
# 2B: a greedy dot quantifier between the brackets.
I=$(mkroot); mkdir -p "$I/platforms/claude-code/hooks"
printf '%s\n' "rg -o '\\[\\[.*\\]\\]' notes/" > "$I/platforms/claude-code/hooks/probe.sh.template"
eq "check 2B reaches a .template"             "1" "$(rc_of "$I")"
eq "check 2B names the .template"           "yes" \
   "$(out_of "$I" | grep -q 'probe.sh.template' && echo yes || echo no)"

# --- CHECK 7 (frontmatter gate): its own three fixes, gone unguarded before
# this section. `check-doc-claims.sh`'s CLAIMS table records the fix (71/25,
# unchanged), but nothing here exercised the FAILURE paths those fixes added
# -- the same gap this file's own header describes for the guard as a whole,
# just three checks over.
#
# 7A: find's exit status, no longer swallowed by the pipe into `sort`. One
# FM_SCAN root made unreadable; the scan must report the traversal failure,
# not silently proceed on whatever the other eight roots yielded.
#
# Captured ONCE, same reason as FM_STALE_OUT below: the second assertion is
# a negative check ("the healthy SKIP text is absent"), and an independent
# second `out_of "$I"` call would pass that check vacuously if the guard had
# crashed or produced no output at all under check 7 -- absent-because-wrong
# and absent-because-nothing-ran read identically to a bare `grep -q`. Gating
# it on the SAME capture the first (positive) assertion already proved
# contains "find failed" closes that hole here too.
I=$(mkroot)
chmod 000 "$I/hooks"
FM_ROOT_OUT=$(out_of "$I")
eq "check 7: unreadable root -> find failed, not silent" "yes" \
   "$(printf '%s' "$FM_ROOT_OUT" | grep -q 'find failed' && echo yes || echo no)"
eq "check 7: unreadable root does NOT read as a healthy SKIP" "yes" \
   "$(printf '%s' "$FM_ROOT_OUT" | grep -q 'find failed' || { echo no; exit; }; \
      printf '%s' "$FM_ROOT_OUT" | grep -A1 '^7\.' | grep -q 'SKIP no allowlisted' && echo no || echo yes)"
chmod 755 "$I/hooks"

# 7B: fm_hits_in's UNREADABLE sentinel. A file `find` LISTED (needs only the
# containing directory's execute bit) but cannot itself read must not count
# as 0 hits -- indistinguishable from a genuinely clean file, which is what
# the guard reported here before this fix existed.
I=$(mkroot)
printf "grep -rl '^status: open' dir/\\n" > "$I/skills/unreadable-fm.md"
chmod 000 "$I/skills/unreadable-fm.md"
eq "check 7: unreadable allowlist-shaped file -> UNREADABLE, not 0 hits" "yes" \
   "$(out_of "$I" | grep -q 'UNREADABLE skills/unreadable-fm.md' && echo yes || echo no)"
chmod 644 "$I/skills/unreadable-fm.md"

# 7C: the branch-order fix. FM_ALLOW is hardcoded to real repo paths, so a
# synthetic mkroot() fixture can never populate fm_present -- there is no
# live-fixture way to exercise "every remaining allowlisted site converted
# in one branch". Instead, extract the guard's OWN decision block (the
# `if [ "$fm_scan_rc" -ne 0 ]; then ... fi` compound at the end of check 7)
# by anchor, not by hardcoded line numbers, and inject the exact state the
# task-6 report reproduced this defect with: fm_stale non-empty while the
# "scan did not run" heuristic's own condition (fm_present>0 && fm_total==0)
# is ALSO true. Pre-fix, that heuristic fired first and misdiagnosed a
# healthy, fully-converted scan as a broken one. If the anchor ever drifts
# (the block renamed or restructured), this fails loud with its own
# diagnostic rather than silently testing stale text.
fm_decision_block() {
  awk '
    /^if \[ "\$fm_scan_rc" -ne 0 \]; then$/ { f=1 }
    f { print }
    f && /^fi$/ { exit }
  ' "$GUARD"
}
run_fm_decision() { # run_fm_decision <fm_scan_rc> <fm_present> <fm_total> <fm_files> <fm_bad> <fm_stale>
  local block
  block=$(fm_decision_block)
  [ -n "$block" ] || { echo "error: check-portability.sh's fm decision block not found -- anchor drifted, this assertion can no longer run" >&2; return 2; }
  (
    red() { printf 'FAIL %s\n' "$1"; }
    ok()  { printf 'PASS %s\n' "$1"; }
    skip() { printf 'SKIP %s\n' "$1"; }
    fm_scan_rc="$1"; fm_present="$2"; fm_total="$3"; fm_files="$4"; fm_bad="$5"; fm_stale="$6"
    eval "$block"
  )
}
FM_STALE_CASE="    STALE    generators/features/graph-analysis.md — allowlisted but no longer matches; site converted, so drop the entry
"
# Captured ONCE into a variable, then both assertions read the SAME output --
# not two independent invocations. This matters for the second assertion: a
# negative check ("the wrong message is absent") passes vacuously if
# `run_fm_decision` produced NOTHING AT ALL (e.g. the anchor above stopped
# matching), since an empty stream contains neither phrase. Gating the
# negative check on the SAME capture that the positive check already proved
# non-empty and on-topic closes that hole -- an anchor miss now fails BOTH
# assertions instead of silently passing the second one for the wrong reason.
FM_STALE_OUT=$(run_fm_decision 0 5 0 0 "" "$FM_STALE_CASE")
eq "check 7: converted allowlist -> names the stale sites, not 'scan did not run'" "yes" \
   "$(printf '%s' "$FM_STALE_OUT" | grep -q 'does not match the allowlist' && echo yes || echo no)"
eq "check 7: converted allowlist does NOT misdiagnose the scan itself" "yes" \
   "$(printf '%s' "$FM_STALE_OUT" | grep -q 'does not match the allowlist' || { echo no; exit; }; \
      printf '%s' "$FM_STALE_OUT" | grep -q 'the scan did not run' && echo no || echo yes)"

# --- check 6: D19 — anchored hit count, pipe-delimited allowlist --------------
#
# D19a: `interp_hits_in` used `grep -cF "$ROOT/<path>:"` — a SUBSTRING match,
# so a hit line whose CONTENT mentions another allowlisted path (with its
# trailing colon) was counted against that other path too. The damage runs in
# the silent direction this repo documents: maintenance.md is DELETED here, so
# the GONE arm must fire — but the unanchored count read the mention inside
# testing-milestones.md's hit line as a live maintenance.md hit, the stale
# loop's `!= 0` skip swallowed the deletion, and the guard reported check 6
# green. Both assertions were born red against that guard. (Why not the
# false-FAIL direction — a healthy two-file tree wrongly COUNT CHANGED:
# creating generators/features/maintenance.md wakes check 7's OWN allowlist,
# whose other entries then go STALE, and recreating that list here is the
# brittleness the fixtures above already refuse.)
D=$(mkroot)
printf '%s %s/generators/features/maintenance.md: named in content\n' "$INTERP" "$D" \
  > "$D/reference/testing-milestones.md"
D_OUT=$(out_of "$D")
eq "interp: D19a deleted allowlisted file is STALE even when another hit's content names its path" \
   "1" "$(rc_of "$D")"
eq "interp: D19a the GONE arm names it — the substring count masked exactly this" "yes" \
   "$(printf '%s' "$D_OUT" | grep -q 'STALE generators/features/maintenance.md — allowlisted but the file is gone' && echo yes || echo no)"

# D19b: the allowlist itself. `${e%% *}` split on WHITESPACE, so a path
# containing a space mis-parsed silently. The delimiter is now `|`, and this
# measures ENTRIES — every non-empty line between INTERP_ALLOW=" and its
# closing quote — not lines-matching-a-substring inside a fixed grep window,
# which stops being the same quantity the moment two entries share a line or
# the list outgrows the window. Born red: the space-delimited rows carried
# zero `|` field separators, so both counted as malformed. The entry-count
# assertion is the positive control — an awk anchor that stopped matching
# would print 0 there, not pass quietly.
allow_entries=$(awk '/^INTERP_ALLOW="$/{f=1;next} f&&/^"$/{f=0} f&&NF{c++} END{print c+0}' "$GUARD")
allow_malformed=$(awk '/^INTERP_ALLOW="$/{f=1;next} f&&/^"$/{f=0} f&&NF && gsub(/\|/,"|")!=2 {c++} END{print c+0}' "$GUARD")
eq "interp: D19b allowlist still declares 2 entries (counted as entries)" "2" "$allow_entries"
eq "interp: D19b every entry is path|count|reason — exactly two field separators" \
   "0" "$allow_malformed"

# D19 end-to-end: the guard run against THIS repo must still resolve both
# entries through the new delimiter. A parse that silently yields nothing does
# not no-op here — the repo's two real sites would surface as UNLISTED and
# redden the rc assertion — and the second assertion pins that both files
# resolved at their declared counts. Not born red (the old parse also passed
# on the repo); these are the assertions the space-delimiter mutation and the
# unanchored-count mutation must each redden.
REPO_OUT=$(bash "$GUARD" 2>&1); REPO_RC=$?
eq "interp: D19 guard green on the real repo through the new delimiter" "0" "$REPO_RC"
eq "interp: D19 real repo — both allowlisted files accounted for" "yes" \
   "$(printf '%s' "$REPO_OUT" | grep -q 'across 2 allowlisted file(s), all accounted for' && echo yes || echo no)"

printf '\npassed=%s failed=%s\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
