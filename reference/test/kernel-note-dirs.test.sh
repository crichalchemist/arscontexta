#!/bin/bash
# kernel-note-dirs.test.sh — behavioral tests for primitive 2's note-directory
# resolution in validate-kernel.sh.
#
# WHY THIS EXISTS: primitive 2 scanned a hardcoded list of canonical directory
# names — 01_thinking, notes, 00_inbox, 04_meta/logs — inside a validator for a
# generator whose whole purpose is renaming them. All four are absent from the
# field vault, so the dangling-link check never ran, and its `WARN No wiki links
# found to check` printed directly beneath `PASS 3786 of 5253 files contain wiki
# links`. Two contradictory lines in one run were read as a soft pass across
# several sessions.
#
# EVERY FIXTURE HERE USES AN ARBITRARY DIRECTORY NAME (`zzz-arbitrary`), never
# `nodes` and never a canonical name. A fix verified against the field vault
# only proves that `nodes` joined the hardcoded list, which is the same defect
# with one more entry.
#
# Run under BOTH shells: `bash …test.sh` and `zsh …test.sh`. The resolver
# deliberately avoids a `"$dir"/*/` glob because zsh's default nomatch makes an
# unmatched glob an error; bump-version.sh shipped a zsh fork for exactly that
# reason, so the validator is invoked here under whichever shell the harness is
# in rather than pinned to bash.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
VALIDATOR="$HERE/../validate-kernel.sh"
passed=0; failed=0

if [ -n "${ZSH_VERSION:-}" ]; then SELF=zsh; else SELF=bash; fi

[ -r "$VALIDATOR" ] || { echo "error: validator not found at '$VALIDATOR'" >&2; exit 1; }
command -v rg >/dev/null 2>&1 || { echo "error: these tests require 'rg'" >&2; exit 1; }

eq() { # eq <label> <expected> <actual>
  if [ "$2" = "$3" ]; then
    passed=$((passed + 1)); printf '  ok   %s\n' "$1"
  else
    failed=$((failed + 1)); printf '  FAIL %s\n       expected: %s\n       actual:   %s\n' "$1" "$2" "$3"
  fi
}

# Run the validator and return primitive 2's result lines with colour stripped.
# Primitive 2's block runs from the "2." header to the "3." header.
#
# ESC is built with printf, not written as \033 inside the sed script: BSD sed
# reads `\033` as a literal backslash-zero-three-three and strips nothing, so
# every `^ *WARN` assertion below silently matched no line and read as a pass.
#
# The sentinel on empty output is half of a review finding's fix. A grep for the
# ABSENCE of something reports absence just as cheerfully over an empty string as
# over correct output; a review replaced p2 with a function returning nothing and
# 6 of 21 assertions still passed. Primitive 2 always prints at least one result
# line, so empty output means the validator did not run at all.
#
# BE PRECISE ABOUT WHAT THIS BUYS, because a verification mechanism described
# more broadly than it works is this repo's own failure class. The sentinel makes
# every *positive* assertion fail on empty output. It does NOT rescue negative
# assertions -- a grep for absence still passes against the sentinel, since the
# sentinel does not contain the phrase either. Measured with the probe the
# reviewer used, 8 of 28 still pass against an empty validator: three call the
# link library or the fixture directly and are meant to be independent of the
# validator, and five are negatives.
#
# THE RULE THAT ACTUALLY COVERS THE NEGATIVES, and the one to preserve when
# adding assertions here: every negative assertion must sit beside a positive one
# in the SAME section, so that silence fails the section even when it satisfies
# the negative. All five comply. Section 8 did not, which is what the review
# found -- it was a lone negative and it is the regression test for this whole
# task. Re-run the probe after adding assertions:
#   sed 's|"$SELF" "$VALIDATOR" "$1" 2>/dev/null|true|' this-file > /tmp/probe.test.sh
ESC=$(printf '\033')
p2() { # p2 <vault>
  _p2=$("$SELF" "$VALIDATOR" "$1" 2>/dev/null \
    | sed "s/${ESC}\\[[0-9;]*m//g" \
    | awk '/^2\. /{on=1; next} /^3\. /{on=0} on')
  if [ -z "$_p2" ]; then
    printf 'VALIDATOR-PRODUCED-NO-OUTPUT'
  else
    printf '%s' "$_p2"
  fi
}

# --- fixture builder ---------------------------------------------------------
# alpha -> beta          resolves (beta.md exists)
# beta  -> nowhere-at-all  dangles  (exactly one)
# gamma -> fenced-ghost  inside a ``` block, must NOT be extracted at all
mkvault() { # mkvault  -> prints vault path
  local root v
  root=$(mktemp -d) || return 1
  v="$root/vault"
  mkdir -p "$v/zzz-arbitrary" "$v/ops"
  printf -- '---\ndescription: a\n---\nlink to [[beta]]\n'            > "$v/zzz-arbitrary/alpha.md"
  printf -- '---\ndescription: b\n---\nlink to [[nowhere-at-all]]\n'  > "$v/zzz-arbitrary/beta.md"
  printf -- '---\ndescription: g\n---\nexample:\n\n```text\n[[fenced-ghost]]\n```\n' \
                                                                      > "$v/zzz-arbitrary/gamma.md"
  printf 'vocabulary:\n  notes: "zzz-arbitrary"\n'                    > "$v/ops/derivation-manifest.md"
  printf '%s' "$v"
}

# =============================================================================
echo "kernel-note-dirs.test.sh (shell: $SELF)"

# --- 1. arbitrary directory name resolves via the manifest -------------------
V=$(mkvault) || { echo "fixture build failed" >&2; exit 1; }
ROOT=$(dirname "$V")
OUT=$(p2 "$V")

eq "arbitrary notes dir: check RUNS (no 'did NOT run')" "ran" \
   "$(printf '%s' "$OUT" | grep -q 'did NOT run' && echo "did-not-run" || echo ran)"
eq "arbitrary notes dir: exactly 1 dangling link" "1" \
   "$(printf '%s' "$OUT" | sed -n 's/^ *WARN \([0-9][0-9]*\) unresolved wiki links.*/\1/p')"
eq "arbitrary notes dir: 2 unique links checked (fenced one excluded)" "2" \
   "$(printf '%s' "$OUT" | sed -n 's/.*out of \([0-9][0-9]*\) unique checked.*/\1/p')"
eq "arbitrary notes dir: names the manifest as the source" "manifest" \
   "$(printf '%s' "$OUT" | grep -q 'derivation-manifest.md vocabulary' && echo manifest || echo "other:$OUT")"
# Naming the SOURCE is not naming the SET. Two vaults identical but for a
# manifest resolve materially different directory sets (3 vs 6 on the field
# vault) under the same green PASS, and a reader could not tell which they got.
eq "arbitrary notes dir: names the scanned set, not just the source" "zzz-arbitrary" \
   "$(printf '%s' "$OUT" | sed -n 's/.*scanned: \([^]]*\)\].*/\1/p')"

# The fenced link must not be extracted AT ALL.
#
# The assertion that stood here grepped the validator's output for the string
# `fenced-ghost` and expected it absent. That could never fail: the validator
# prints counts and never link names, in any branch, so it asserted the absence
# of something that is absent by construction. The real coverage of the fenced
# case is the count above -- 3 unique links instead of 2 if the fence leaked.
#
# What follows tests the property directly, against the one surface that does
# emit names, and in BOTH directions: an empty extraction would satisfy the
# negative alone, so the positive is what makes the negative mean anything.
TARGETS=$(. "$HERE/../lib/link-extraction.sh" >/dev/null 2>&1; extract_link_targets_recursive "$V/zzz-arbitrary")
eq "extraction emits the real link target" "present" \
   "$(printf '%s\n' "$TARGETS" | grep -qx 'beta' && echo present || echo "missing:$TARGETS")"
eq "extraction omits the fenced link target" "absent" \
   "$(printf '%s\n' "$TARGETS" | grep -qx 'fenced-ghost' && echo "present:$TARGETS" || echo absent)"

# --- 2. the FAIL branch is reachable: notes dir named but gone ---------------
rm -rf "$V/zzz-arbitrary"
OUT=$(p2 "$V")
eq "notes dir deleted: primitive FAILs" "fail" \
   "$(printf '%s' "$OUT" | grep -q '^ *FAIL ' && echo fail || echo "not-fail:$OUT")"
# Scoped to the DANGLING branch, not to the whole primitive. Primitive 2 emits
# two result lines, and the other one -- link coverage across the vault -- is a
# separate sub-check that legitimately warns about a vault with no links left in
# it. The claim under test is narrower: the branch that did not run must not
# produce a warning of its own.
eq "notes dir deleted: dangling branch emits no WARN of its own" "no-warn" \
   "$(printf '%s' "$OUT" | grep -qE '^ *WARN .*(wiki links to check|unresolved wiki links)' && echo "warned:$OUT" || echo no-warn)"
eq "notes dir deleted: says the check did not run" "stated" \
   "$(printf '%s' "$OUT" | grep -q 'did NOT run' && echo stated || echo "silent:$OUT")"
rm -rf "$ROOT"

# --- 3. a parsed-but-absent name is not 'resolved' ---------------------------
# The manifest names a directory that does not exist while a DIFFERENT directory
# holding notes does. Resolution must fall through to the shape scan rather than
# treating the successful parse as success.
V=$(mkvault); ROOT=$(dirname "$V")
mv "$V/zzz-arbitrary" "$V/qqq-elsewhere"
OUT=$(p2 "$V")
eq "manifest names a missing dir: falls through to shape scan" "shape" \
   "$(printf '%s' "$OUT" | grep -q 'shape scan' && echo shape || echo "other:$OUT")"
eq "fall-through still finds the 1 dangling link" "1" \
   "$(printf '%s' "$OUT" | sed -n 's/^ *WARN \([0-9][0-9]*\) unresolved wiki links.*/\1/p')"
rm -rf "$ROOT"

# --- 4. ops/config.yaml is the second source ---------------------------------
V=$(mkvault); ROOT=$(dirname "$V")
rm -f "$V/ops/derivation-manifest.md"
printf 'vocabulary:\n  notes: zzz-arbitrary\n' > "$V/ops/config.yaml"
OUT=$(p2 "$V")
eq "config.yaml vocabulary resolves (unquoted value)" "config" \
   "$(printf '%s' "$OUT" | grep -q 'ops/config.yaml vocabulary' && echo config || echo "other:$OUT")"
eq "config.yaml route finds the 1 dangling link" "1" \
   "$(printf '%s' "$OUT" | sed -n 's/^ *WARN \([0-9][0-9]*\) unresolved wiki links.*/\1/p')"
rm -rf "$ROOT"

# --- 5. a file with no vocabulary block must not resolve to empty ------------
# An absent key and a key set to the empty string look identical downstream.
V=$(mkvault); ROOT=$(dirname "$V")
printf -- '---\nengine_version: "1.0"\n---\nnotes: "zzz-arbitrary"\n' > "$V/ops/derivation-manifest.md"
OUT=$(p2 "$V")
eq "no vocabulary block: ignores a bare notes: key outside it" "shape" \
   "$(printf '%s' "$OUT" | grep -q 'shape scan' && echo shape || echo "other:$OUT")"
rm -rf "$ROOT"

# --- 6. self space is read at \$VAULT/self, not \$VAULT/../self ---------------
# Both fixtures below add exactly one extra dangling link. The correct build
# counts the one inside the vault and not the sibling, so the two cases differ
# by their dangling total — a count discriminates where a grep for absence
# would pass on an empty scan.
V=$(mkvault); ROOT=$(dirname "$V")
mkdir -p "$ROOT/self"
printf -- '---\nd: s\n---\n[[sibling-ghost]]\n' > "$ROOT/self/memory.md"
OUT=$(p2 "$V")
# The fixture-sanity assertion is the companion, not a grep for the ghost name:
# the validator never prints link names, so "sibling-ghost is absent from the
# output" held before this fix and after it and could not distinguish them. What
# CAN go wrong silently is the fixture -- if the sibling self space were never
# built, "still 1 dangling" would pass for entirely the wrong reason.
eq "fixture sanity: the sibling self space exists and holds a dangling link" "built" \
   "$(grep -q 'sibling-ghost' "$ROOT/self/memory.md" 2>/dev/null && echo built || echo "fixture-missing")"
eq "sibling ../self is NOT scanned (still 1 dangling)" "1" \
   "$(printf '%s' "$OUT" | sed -n 's/^ *WARN \([0-9][0-9]*\) unresolved wiki links.*/\1/p')"
eq "sibling ../self is not named in the scanned set" "absent" \
   "$(printf '%s' "$OUT" | sed -n 's/.*scanned: \(.*\)\]/\1/p' | grep -q 'self' && echo "present:$OUT" || echo absent)"

mkdir -p "$V/self"
printf -- '---\nd: s\n---\n[[inside-ghost]]\n' > "$V/self/memory.md"
OUT=$(p2 "$V")
eq "in-vault self IS scanned (now 2 dangling)" "2" \
   "$(printf '%s' "$OUT" | sed -n 's/^ *WARN \([0-9][0-9]*\) unresolved wiki links.*/\1/p')"
rm -rf "$ROOT"

# --- 7. resolved-but-empty is a WARN, not a FAIL -----------------------------
# A vault whose notes directory exists and holds no links is legitimate. That is
# a different fact from "no directory could be resolved", and the two must not
# collapse back into one message.
V=$(mkvault); ROOT=$(dirname "$V")
rm -f "$V"/zzz-arbitrary/*.md
printf -- '---\ndescription: n\n---\nno links here\n' > "$V/zzz-arbitrary/plain.md"
OUT=$(p2 "$V")
eq "resolved but linkless: WARNs, does not FAIL" "warn" \
   "$(printf '%s' "$OUT" | grep -q '^ *FAIL ' && echo "failed:$OUT" || { printf '%s' "$OUT" | grep -q '^ *WARN .*no wiki links to check' && echo warn || echo "other:$OUT"; })"
rm -rf "$ROOT"

# --- 8. the two contradictory lines can no longer co-occur -------------------
# The exact shape of the original defect: a PASS about link coverage printed
# beside a WARN saying nothing was found to check.
#
# THIS SECTION IS THE REGRESSION TEST FOR THE WHOLE TASK, and it has now been
# wrong twice, in two different ways.
#
# First it was a lone negative: it reported `clean` whenever its second grep
# missed, which includes the validator printing nothing. A positive companion
# and the p2 sentinel fixed that.
#
# Then a review found the real defect underneath, which the companion did not
# touch: the negative grepped `No wiki links found to check`, and THAT STRING IS
# UNREACHABLE. Commit d384094 -- the commit this whole suite was written for --
# changed the emitted wording to `…contain no wiki links to check` while this
# assertion kept the pre-task spelling. It was born dead. It could not fail, so
# `clean` meant nothing, and adding a companion beside it only ruled out silence
# -- which is not the property this section exists to test. The tell was already
# in the file: §7 asserts the CURRENT wording is present, four sections above a
# §8 asserting a DIFFERENT wording is absent.
#
# Two things keep it honest now. The grep points at the live wording, and §8b
# below pins that grep against a fixture where the contradiction really does
# occur. A negative assertion whose string can drift out from under it is how
# this was born dead; §8b makes the next wording change FAIL a test instead of
# silently disarming one.
V=$(mkvault); ROOT=$(dirname "$V")
OUT=$(p2 "$V")
eq "coverage line IS present (so 'clean' below cannot mean 'nothing printed')" "present" \
   "$(printf '%s' "$OUT" | grep -q 'PASS .* contain wiki links' && echo present || echo "missing:$OUT")"
eq "healthy vault: no coverage PASS beside a 'no wiki links to check'" "clean" \
   "$(if printf '%s' "$OUT" | grep -q 'PASS .* contain wiki links' && printf '%s' "$OUT" | grep -q 'no wiki links to check'; then echo "contradiction:$OUT"; else echo clean; fi)"
rm -rf "$ROOT"

# --- 8b. the detector fires on a vault that really does produce both ---------
# The discriminator: a notes directory that RESOLVES but holds no links, beside
# enough linked files elsewhere to clear the 50% coverage threshold. The vault
# below has 6 markdown files, 4 of them linked, and its resolved notes directory
# is empty of links -- so primitive 2 emits the coverage PASS and the
# nothing-to-check WARN in one run.
#
# This section asserts the DETECTOR FIRES, which is what makes §8a's `clean`
# mean something. If the emitted wording changes again, this fails loudly rather
# than §8a going quietly vacuous.
V2=$(mktemp -d)/vault; mkdir -p "$V2/zzz-arbitrary" "$V2/docs" "$V2/ops"
ROOT2=$(dirname "$V2")
printf -- '---\nd: p\n---\nno links here at all\n' > "$V2/zzz-arbitrary/plain.md"
for n in a b c d; do printf -- '---\nd: %s\n---\nsee [[plain]]\n' "$n" > "$V2/docs/$n.md"; done
printf 'vocabulary:\n  notes: "zzz-arbitrary"\n' > "$V2/ops/derivation-manifest.md"
OUT=$(p2 "$V2")
eq "8b fixture really does emit the coverage PASS" "present" \
   "$(printf '%s' "$OUT" | grep -q 'PASS .* contain wiki links' && echo present || echo "missing:$OUT")"
eq "8b fixture really does emit the nothing-to-check WARN" "present" \
   "$(printf '%s' "$OUT" | grep -q 'no wiki links to check' && echo present || echo "missing:$OUT")"
eq "8a's detector fires here -- proving its grep is live, not dead wording" "contradiction" \
   "$(if printf '%s' "$OUT" | grep -q 'PASS .* contain wiki links' && printf '%s' "$OUT" | grep -q 'no wiki links to check'; then echo contradiction; else echo "detector-dead:$OUT"; fi)"
rm -rf "$ROOT2"

# --- 9. the dangling scan is exhaustive, not sampled -------------------------
# This section used to assert the OPPOSITE: that a `head -100` sample disclosed
# its own scope (percentage checked, unchecked remainder). The cap is gone,
# replaced by a `comm` set difference that is exhaustive AND faster than the
# sample it replaced, so those five assertions pinned machinery that no longer
# exists. The 120-note fixture is kept deliberately -- it sits ABOVE the old cap,
# so it is precisely the case that used to be truncated and reported as clean.
V=$(mkvault); ROOT=$(dirname "$V")
rm -f "$V"/zzz-arbitrary/*.md
i=1
while [ "$i" -le 120 ]; do
    printf -- '---\nd: n\n---\nself ref [[n%03d]]\n' "$i" > "$V/zzz-arbitrary/n$(printf '%03d' "$i").md"
    i=$((i + 1))
done
OUT=$(p2 "$V")
eq "above the old cap: checks all 120, not 100" "120" \
   "$(printf '%s' "$OUT" | sed -n 's/.*checked all \([0-9][0-9]*\) unique links.*/\1/p')"
eq "above the old cap: claims complete coverage" "all" \
   "$(printf '%s' "$OUT" | grep -q 'checked all' && echo all || echo "notall:$OUT")"
# The two sample-disclosure phrasings must be GONE, not merely unused. Each ""
# expectation is paired with the positive assertions above: an empty grep result
# and a broken search are indistinguishable, and the "120" assertion is what
# proves $OUT holds real output rather than an empty string that trivially
# lacks both phrasings.
eq "above the old cap: no unchecked remainder" "" \
   "$(printf '%s' "$OUT" | sed -n 's/.*; \([0-9][0-9]*\) were NOT checked.*/\1/p')"
eq "above the old cap: no percentage disclosure" "" \
   "$(printf '%s' "$OUT" | sed -n 's/.*only \([0-9.]*\)% of.*/\1/p')"
# STRUCTURAL: the cap must not return as a merely larger number. Keyed on the
# executable form only -- comments in this file and in the validator legitimately
# still discuss the old `head -100`, and keying on those would make the guard
# unfixable without rewriting the record of why it exists.
eq "no scan cap survives on the link pipeline" "0" \
   "$(sed 's/#.*$//' "$VALIDATOR" | grep -cE 'link_(candidates|folded).*head -' || true)"
# COLLATION. `comm` consumes two sorted streams and emits nonsense when their
# collations differ; the per-link `grep -qxF` loop it replaced had no such
# requirement, so this risk is NEW as of the cap removal and nothing else pins
# it. Both sides must therefore sort under LC_ALL=C. Asserted structurally
# because the behavioural version is not portable: the inputs that discriminate
# C from a locale collation involve punctuation or non-ASCII names, and macOS
# normalises the latter on the filesystem, which would make the test flaky
# rather than wrong -- and a flaky gate is worse here than an explicit one.
eq "both comm inputs pin LC_ALL=C" "2" \
   "$(grep -c 'LC_ALL=C sort' "$VALIDATOR" || true)"

rm -f "$V"/zzz-arbitrary/*.md
printf -- '---\nd: a\n---\n[[beta]]\n' > "$V/zzz-arbitrary/alpha.md"
printf -- '---\nd: b\n---\n[[alpha]]\n' > "$V/zzz-arbitrary/beta.md"
OUT=$(p2 "$V")
eq "under the cap: PASS says it checked all of them" "all" \
   "$(printf '%s' "$OUT" | grep -q 'checked all 2 unique links' && echo all || echo "other:$OUT")"
rm -rf "$ROOT"

# --- 10. a directory name containing a space ---------------------------------
# Two separate defects met here, and each hid the other. `_vocab_dir` read awk's
# $2, so `notes: "my notes"` yielded `my`; the -d test on it failed; resolution
# fell through to the shape scan and SILENTLY BYPASSED the source this validator
# calls authoritative, with a correct-looking result. And the message joiner
# rewrote every space as ", ", so the shape scan then reported one directory as
# two -- `scanned: my, notes`, a set that does not exist.
#
# Asserted in both halves, because either alone passes while the other is
# broken: the source must be the manifest (not the fallback), AND the name must
# survive intact.
V=$(mktemp -d)/vault; ROOT=$(dirname "$V")
mkdir -p "$V/my notes" "$V/ops"
printf -- '---\nd: a\n---\n[[beta]]\n' > "$V/my notes/alpha.md"
printf -- '---\nd: b\n---\n[[nowhere-at-all]]\n' > "$V/my notes/beta.md"
printf 'vocabulary:\n  notes: "my notes"\n' > "$V/ops/derivation-manifest.md"
OUT=$(p2 "$V")
eq "spaced dir: resolves via the MANIFEST, not the shape-scan fallback" "manifest" \
   "$(printf '%s' "$OUT" | grep -q 'derivation-manifest.md vocabulary' && echo manifest || echo "bypassed:$OUT")"
eq "spaced dir: reported as one directory, not two" "my notes" \
   "$(printf '%s' "$OUT" | sed -n 's/.*scanned: \([^]]*\)\].*/\1/p')"
eq "spaced dir: still finds the 1 dangling link" "1" \
   "$(printf '%s' "$OUT" | sed -n 's/^ *WARN \([0-9][0-9]*\) unresolved wiki links.*/\1/p')"

# Same value unquoted and trailing a comment -- the other spelling a real
# manifest uses. A parser that only handles the quoted form passes the assertion
# above and still bypasses the manifest on this one.
printf 'vocabulary:\n  notes: my notes   # level 1 folder\n' > "$V/ops/derivation-manifest.md"
OUT=$(p2 "$V")
eq "spaced dir, unquoted + trailing comment: still the manifest" "manifest" \
   "$(printf '%s' "$OUT" | grep -q 'derivation-manifest.md vocabulary' && echo manifest || echo "bypassed:$OUT")"
eq "spaced dir, unquoted + trailing comment: comment not part of the name" "my notes" \
   "$(printf '%s' "$OUT" | sed -n 's/.*scanned: \([^]]*\)\].*/\1/p')"
rm -rf "$ROOT"

# =============================================================================
# --- C1: outcome statuses carry their target field ---------------------------
#
# The first CONDITIONAL-field assertion in either tree, so it gets its own
# fixture rather than being read off the field vault: a suite that depends on a
# private vault's content asserts whatever that vault happens to contain today.
#
# The DECOY is the assertion that matters. `decoy.md` is `status: open` in its
# frontmatter and carries `status: implemented` at COLUMN 0 in its body. The
# library excludes it; a naive `grep -rl '^status: implemented'` counts it and
# reports it as a violation — wrong in both terms, since it inflates the
# denominator AND invents a failure. Measured: correct 1 of 2, naive 2 of 3.
c1() { # c1 <vault>  -> C1's own result line
  _c1=$("$SELF" "$VALIDATOR" "$1" 2>/dev/null \
    | sed "s/${ESC}\\[[0-9;]*m//g" \
    | awk '/^C1\. /{on=1; next} /^=== /{on=0} on')
  [ -z "$_c1" ] && printf 'VALIDATOR-PRODUCED-NO-OUTPUT' || printf '%s' "$_c1"
}

# ALL FOUR (directory x status) SPECS GET A VIOLATION. The first version of this
# fixture had a promoted TENSION but no promoted OBSERVATION, so deleting the
# `ops/observations:promoted` spec from the validator changed nothing observable
# and the suite stayed green — the mutation reported STILL NOTHING, which means
# either the assertion is vacuous or the fixture never reaches it. Here it was
# the fixture. Each spec now has exactly one violator, so deleting ANY ONE of
# the four reddens the count.
mkoutcomes() { # mkoutcomes -> vault covering all four specs, plus a body-line decoy
  local root v; root=$(mktemp -d) || return 1; v="$root/vault"
  mkdir -p "$v/zzz-arbitrary" "$v/ops/observations" "$v/ops/tensions"
  printf -- '---\ndescription: a\n---\n# hub\n'                        > "$v/zzz-arbitrary/hub.md"
  printf -- '---\nstatus: implemented\nimplemented_in: p.sh\n---\n#g\n' > "$v/ops/observations/good.md"
  printf -- '---\nstatus: implemented\n---\n# names nothing\n'          > "$v/ops/observations/bad-impl.md"
  printf -- '---\nstatus: promoted\n---\n# names nothing\n'             > "$v/ops/observations/bad-prom.md"
  printf -- '---\nstatus: open\n---\n# open\n\nstatus: implemented\n'   > "$v/ops/observations/decoy.md"
  printf -- '---\nstatus: promoted\npromoted_to: "[[n]]"\n---\n#g\n'    > "$v/ops/tensions/good.md"
  printf -- '---\nstatus: promoted\n---\n# names nothing\n'             > "$v/ops/tensions/bad-prom.md"
  printf -- '---\nstatus: implemented\n---\n# names nothing\n'          > "$v/ops/tensions/bad-impl.md"
  printf '%s' "$v"
}

V=$(mkoutcomes) || { echo "fixture build failed" >&2; exit 1; }
ROOT=$(dirname "$V"); OUT=$(c1 "$V")

eq "C1: the check produced output at all"                "yes" \
   "$([ "$OUT" = "VALIDATOR-PRODUCED-NO-OUTPUT" ] && echo no || echo yes)"
eq "C1: FAILs when an outcome names no target"           "fail" \
   "$(printf '%s' "$OUT" | grep -q 'FAIL' && echo fail || echo other)"
# 2 bad of 4 scanned. The 4 EXCLUDES decoy.md — that is the whole point of the
# denominator being asserted rather than just the numerator.
eq "C1: exactly 4 violations, one per spec"              "4" \
   "$(printf '%s' "$OUT" | sed -n 's/.*FAIL \([0-9]*\) of .*/\1/p')"
eq "C1: scanned 6, so the body-line decoy was NOT counted" "6" \
   "$(printf '%s' "$OUT" | sed -n 's/.*of \([0-9]*\) outcome-status.*/\1/p')"
eq "C1: names the offending observation"                 "present" \
   "$(printf '%s' "$OUT" | grep -q 'observations/bad-impl.md' && echo present || echo absent)"
eq "C1: names the offending tension"                     "present" \
   "$(printf '%s' "$OUT" | grep -q 'tensions/bad-prom.md' && echo present || echo absent)"
eq "C1: covers promoted, not only implemented"           "present" \
   "$(printf '%s' "$OUT" | grep -q 'promoted without a usable promoted_to' && echo present || echo absent)"
eq "C1: does not name the compliant note"                "absent" \
   "$(printf '%s' "$OUT" | grep -q 'observations/good.md' && echo present || echo absent)"
rm -rf "$ROOT"

# A vault with no ops dirs: the rule does not apply. WARN, never a silent PASS —
# "the check did not run" reported as green is the defect primitive 2 shipped.
V=$(mkoutcomes) || exit 1; ROOT=$(dirname "$V")
rm -rf "$V/ops/observations" "$V/ops/tensions"
OUT=$(c1 "$V")
eq "C1: no ops dirs -> WARN, not PASS"                   "warn" \
   "$(printf '%s' "$OUT" | grep -q 'WARN' && echo warn || echo other)"
eq "C1: no ops dirs -> says the rule is not applicable"  "stated" \
   "$(printf '%s' "$OUT" | grep -q 'not applicable' && echo stated || echo silent)"
eq "C1: no ops dirs -> emits no PASS of its own"         "yes" \
   "$(printf '%s' "$OUT" | grep -q 'PASS' && echo no || echo yes)"
rm -rf "$ROOT"

# All outcomes compliant: PASS, and the count is the scanned total not zero.
V=$(mkoutcomes) || exit 1; ROOT=$(dirname "$V")
printf -- '---\nstatus: implemented\nimplemented_in: q.sh\n---\n#f\n' > "$V/ops/observations/bad-impl.md"
printf -- '---\nstatus: promoted\npromoted_to: "[[m]]"\n---\n#f\n'    > "$V/ops/observations/bad-prom.md"
printf -- '---\nstatus: promoted\npromoted_to: "[[m]]"\n---\n#f\n'    > "$V/ops/tensions/bad-prom.md"
printf -- '---\nstatus: implemented\nimplemented_in: q.sh\n---\n#f\n' > "$V/ops/tensions/bad-impl.md"
OUT=$(c1 "$V")
eq "C1: all compliant -> PASS"                           "pass" \
   "$(printf '%s' "$OUT" | grep -q 'PASS' && echo pass || echo other)"
eq "C1: PASS still reports 6 scanned, not 0"             "6" \
   "$(printf '%s' "$OUT" | sed -n 's/.*PASS \([0-9]*\) outcome-status.*/\1/p')"
rm -rf "$ROOT"

# Directories present but NOTHING has reached an outcome status. Distinct branch,
# distinct message: "PASS, all 0 carry their field" is how a scan that found
# nothing reads as a scan that found everything in order.
# ONE directory only, so the pair count (2) and the directory count (1) differ.
# With both directories present they are 4 and 2 and the assertion below cannot
# tell which quantity the message reports — which is how the mislabel shipped.
V=$(mkoutcomes) || exit 1; ROOT=$(dirname "$V")
rm -rf "$V/ops/tensions"
rm -f "$V/ops/observations/"*.md
printf -- '---\nstatus: open\n---\n# not resolved yet\n' > "$V/ops/observations/o.md"
OUT=$(c1 "$V")
eq "C1: empty outcome set -> PASS"                       "pass" \
   "$(printf '%s' "$OUT" | grep -q 'PASS' && echo pass || echo other)"
eq "C1: empty outcome set -> says NO note reached one"   "stated" \
   "$(printf '%s' "$OUT" | grep -q 'no note has reached an outcome status' && echo stated || echo silent)"
# It counts (directory, status) PAIRS, not directories -- the loop runs four
# pairs over two dirs, so one directory scores 2. The first version of this
# message said "2 directories" on a vault that had one.
eq "C1: empty outcome set -> counts PAIRS, not directories" "2" \
   "$(printf '%s' "$OUT" | sed -n 's/.*checked \([0-9]*\) (directory, status).*/\1/p')"
eq "C1: empty outcome set -> claims no per-note check"   "absent" \
   "$(printf '%s' "$OUT" | grep -q 'all carry their target field' && echo present || echo absent)"
rm -rf "$ROOT"

# The SECOND empty-set case exists so the pair count cannot be satisfied by a
# constant. With one directory it is 2; with both it is 4. A review found that
# hardcoding the counter to the fixture's own value (2) reddened nothing, while
# 1/3/9 each reddened one — so the assertion pinned "not an arbitrary constant"
# rather than "counts pairs". Two fixtures with different expected values fixes
# that: no single constant satisfies both.
V=$(mkoutcomes) || exit 1; ROOT=$(dirname "$V")
rm -f "$V/ops/observations/"*.md "$V/ops/tensions/"*.md
printf -- '---\nstatus: open\n---\n# not resolved yet\n' > "$V/ops/observations/o.md"
OUT=$(c1 "$V")
eq "C1: BOTH dirs empty -> 4 pairs, so no constant satisfies both cases" "4" \
   "$(printf '%s' "$OUT" | sed -n 's/.*checked \([0-9]*\) (directory, status).*/\1/p')"
rm -rf "$ROOT"

# A vault that RENAMED ops/. Primitive 12 has always accepted these variants;
# C1 hardcoded `ops/` and so went silent on such a vault while asserting
# "self-evolution not enabled" — two checks in one script disagreeing about the
# same directories. The candidate list is now shared.
V=$(mkoutcomes) || exit 1; ROOT=$(dirname "$V")
mkdir -p "$V/04_meta/logs/observations"
mv "$V/ops/observations/bad-impl.md" "$V/04_meta/logs/observations/"
rm -rf "$V/ops/observations" "$V/ops/tensions"
OUT=$(c1 "$V")
eq "C1: a renamed ops dir is RESOLVED, not reported as absent" "fail" \
   "$(printf '%s' "$OUT" | grep -q 'FAIL' && echo fail || echo other)"
eq "C1: renamed ops dir -> does NOT claim self-evolution is off" "absent" \
   "$(printf '%s' "$OUT" | grep -q 'not applicable' && echo present || echo absent)"
eq "C1: renamed ops dir -> names the file under its real path" "present" \
   "$(printf '%s' "$OUT" | grep -q '04_meta/logs/observations/bad-impl.md' && echo present || echo absent)"
rm -rf "$ROOT"

# A vault that renamed `ops` ITSELF, via its manifest vocabulary. The previous
# fixture used 04_meta/logs/, which is INSIDE the hardcoded candidate list, so it
# could not fail on a resolver that only knows that list — the repo's own
# critique ("a fix verified against the field vault only proves that `nodes`
# joined the hardcoded list") applied to this suite. zzz-meta is in no list.
V=$(mkoutcomes) || exit 1; ROOT=$(dirname "$V")
# NO ops/ DIRECTORY SURVIVES. The first version of this fixture kept one alive
# solely to hold the manifest, which is not a renamed vault — it is two
# directories, and it passed against a resolver that reads the manifest from a
# hardcoded ops/ path. The comment above quotes this repo's critique of a fix
# verified against a shape that cannot fail, and then committed it.
mkdir -p "$V/zzz-meta"
mv "$V/ops/observations" "$V/ops/tensions" "$V/zzz-meta/"
printf 'vocabulary:\n  notes: "zzz-arbitrary"\n  ops: "zzz-meta"\n' > "$V/zzz-meta/derivation-manifest.md"
rm -rf "$V/ops"
OUT=$(c1 "$V")
eq "C1: an ops dir renamed via the manifest RESOLVES"    "fail" \
   "$(printf '%s' "$OUT" | grep -q 'FAIL' && echo fail || echo other)"
eq "C1: renamed ops -> does NOT claim self-evolution off" "absent" \
   "$(printf '%s' "$OUT" | grep -q 'not applicable' && echo present || echo absent)"
eq "C1: renamed ops -> finds all 4 violations"           "4" \
   "$(printf '%s' "$OUT" | sed -n 's/.*FAIL \([0-9]*\) of .*/\1/p')"
eq "C1: renamed ops -> names the real path"              "present" \
   "$(printf '%s' "$OUT" | grep -q 'zzz-meta/observations' && echo present || echo absent)"
rm -rf "$ROOT"

# An EMPTY target field. frontmatter.sh returns rc 0 for a present-but-empty
# field, so a presence test passed `implemented_in:` with no value — exactly as
# unfalsifiable as omitting it, and the cheapest way to turn every violation
# green.
V=$(mkoutcomes) || exit 1; ROOT=$(dirname "$V")
rm -f "$V/ops/observations/"*.md "$V/ops/tensions/"*.md
printf -- '---\nstatus: implemented\nimplemented_in:\n---\n# empty value\n' > "$V/ops/observations/empty.md"
printf -- '---\nstatus: promoted\npromoted_to: ""\n---\n# empty string\n'   > "$V/ops/tensions/empty.md"
OUT=$(c1 "$V")
eq "C1: an EMPTY target field is a violation, not a pass"  "2" \
   "$(printf '%s' "$OUT" | sed -n 's/.*FAIL \([0-9]*\) of .*/\1/p')"
rm -rf "$ROOT"

# THE LIBRARY'S REFUSAL MUST REACH THE VERDICT. list_notes_by_field prints
# "refusing to report a count" and returns 1 on an unreadable directory; C1
# called it inside `<<EOF $(...)`, which has no exit status, so a failed scan
# emitted nothing and reported PASS.
#
# chmod 000 does not restrict root, so this assertion would SILENTLY pass when
# the suite runs as root. It checks first and reports SKIPPED-AS-ROOT rather
# than a green tick, because a check that cannot run must not look like one that
# ran and found nothing — the defect this whole section is about.
V=$(mkoutcomes) || exit 1; ROOT=$(dirname "$V")
chmod 000 "$V/ops/observations" 2>/dev/null
if ls "$V/ops/observations" >/dev/null 2>&1; then
  printf '  SKIP C1: unreadable-dir branch (running as root; chmod 000 does not restrict)\n'
else
  OUT=$(c1 "$V")
  eq "C1: an unscannable directory FAILs, never PASSes"    "fail" \
     "$(printf '%s' "$OUT" | grep -q 'FAIL' && echo fail || echo other)"
  eq "C1: and says the library refused rather than a count" "stated" \
     "$(printf '%s' "$OUT" | grep -q 'could not scan' && echo stated || echo silent)"
fi
chmod 755 "$V/ops/observations" 2>/dev/null
rm -rf "$ROOT"

printf '\npassed=%s failed=%s\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
