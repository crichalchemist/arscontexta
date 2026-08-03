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
ESC=$(printf '\033')
p2() { # p2 <vault>
  "$SELF" "$VALIDATOR" "$1" 2>/dev/null \
    | sed "s/${ESC}\\[[0-9;]*m//g" \
    | awk '/^2\. /{on=1; next} /^3\. /{on=0} on'
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

# The fenced link must not be extracted AT ALL. Asserting only "dangling == 1"
# is a negative that also passes if extraction silently produced nothing, so
# pair it with the positive: the ghost name must be absent from the output while
# the real dangling target is reported.
eq "fenced link contributes 0 (ghost name never surfaces)" "absent" \
   "$(printf '%s' "$OUT" | grep -q 'fenced-ghost' && echo present || echo absent)"

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
eq "sibling ../self is NOT scanned (still 1 dangling)" "1" \
   "$(printf '%s' "$OUT" | sed -n 's/^ *WARN \([0-9][0-9]*\) unresolved wiki links.*/\1/p')"
eq "sibling ../self: its link never surfaces" "absent" \
   "$(printf '%s' "$OUT" | grep -q 'sibling-ghost' && echo present || echo absent)"

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
V=$(mkvault); ROOT=$(dirname "$V")
OUT=$(p2 "$V")
eq "no 'PASS … contain wiki links' beside 'No wiki links found to check'" "clean" \
   "$(if printf '%s' "$OUT" | grep -q 'PASS .* contain wiki links' && printf '%s' "$OUT" | grep -q 'No wiki links found to check'; then echo "contradiction:$OUT"; else echo clean; fi)"
rm -rf "$ROOT"

# --- 9. a PASS must state its own scope when the 100-link cap truncates ------
# The cap predates this fix and is left in place, but it used to be harmless:
# nothing resolved, so the sample was always empty. Now that resolution works,
# an unqualified "No dangling wiki links" would assert over every link in the
# vault on the strength of the first hundred. Below and above the cap must read
# differently.
V=$(mkvault); ROOT=$(dirname "$V")
rm -f "$V"/zzz-arbitrary/*.md
i=1
while [ "$i" -le 120 ]; do
  printf -- '---\nd: n\n---\nself ref [[n%03d]]\n' "$i" > "$V/zzz-arbitrary/n$(printf '%03d' "$i").md"
  i=$((i + 1))
done
OUT=$(p2 "$V")
eq "over the cap: PASS says it is a sample of the true total" "120" \
   "$(printf '%s' "$OUT" | sed -n 's/.*-link sample of \([0-9][0-9]*\) unique.*/\1/p')"
eq "over the cap: does not claim to have checked all" "scoped" \
   "$(printf '%s' "$OUT" | grep -q 'checked all' && echo "overclaimed:$OUT" || echo scoped)"

rm -f "$V"/zzz-arbitrary/*.md
printf -- '---\nd: a\n---\n[[beta]]\n' > "$V/zzz-arbitrary/alpha.md"
printf -- '---\nd: b\n---\n[[alpha]]\n' > "$V/zzz-arbitrary/beta.md"
OUT=$(p2 "$V")
eq "under the cap: PASS says it checked all of them" "all" \
   "$(printf '%s' "$OUT" | grep -q 'checked all 2 unique links' && echo all || echo "other:$OUT")"
rm -rf "$ROOT"

printf '\npassed=%s failed=%s\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
