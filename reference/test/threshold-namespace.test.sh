#!/bin/bash
# threshold-namespace.test.sh — behavioral tests for the self-evolution threshold
# namespace decision, and the first coverage `read_config.sh` has ever had.
#
# WHY THIS EXISTS: two namespaces declared the same two thresholds in one file.
# `ops/config.yaml` in the field vault carried
# `maintenance.conditions.pending_observations_threshold: 20` /
# `pending_tensions_threshold: 10` at lines 68-69 and `self_evolution:` 10/5 at
# lines 71-73. `/rethink` read the first pair; `/next`, `/remember` and the
# SessionStart hook read the second. Measured at 14 open observations and 8 open
# tensions, `/rethink` reported the threshold unmet while the other three
# recommended running it. A vault's own tools contradicted each other.
#
# `self_evolution.*` was made authoritative. THE LOAD-BEARING REASON IS TESTED
# HERE, not merely asserted in prose: `read_config.sh` resolves ONE level of
# nesting, so the three-level `maintenance.conditions.*` key is unreachable by
# the hook. If `unreadable_by_the_hook` below ever starts passing a real value,
# the rationale for the whole decision is void and this suite must fail loudly
# rather than let the choice stand on a claim that stopped being true.
#
# THE BEFORE-STATE IS ASSERTED FIRST, DELIBERATELY. A suite that only checks the
# after-state cannot distinguish "the fix works" from "the check never could
# fail" — this branch has already shipped one assertion that was born dead
# because it grepped a string the same commit stopped emitting. Every fixture
# here is proven to produce the contradiction before it is proven to resolve it.
#
# WHAT THIS DOES NOT TEST, stated because a verification mechanism described more
# broadly than it works is this repo's own failure class: `/upgrade` Step 6c is
# prose that Claude executes, and no test can run prose. What is checked is that
# the reconciliation OPERATION 6c specifies produces agreement across the four
# readers, and that the repo names one namespace. That Claude performs the
# operation when asked is not verified here and is not claimed to be.
#
# Run under BOTH shells: `bash …test.sh` and `zsh …test.sh`.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
READER="$REPO/hooks/scripts/read_config.sh"
passed=0; failed=0

[ -r "$READER" ] || { echo "error: read_config.sh not found at '$READER'" >&2; exit 1; }

eq() { # eq <label> <expected> <actual>
  if [ "$2" = "$3" ]; then
    passed=$((passed + 1)); printf '  ok   %s\n' "$1"
  else
    failed=$((failed + 1)); printf '  FAIL %s\n       expected: %s\n       actual:   %s\n' "$1" "$2" "$3"
  fi
}

TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------------------
# Fixtures. Each is a vault root containing only ops/config.yaml.
#
# The `maintenance:` block reproduces the field vault's shape, including the
# seven sibling keys, so section-boundary behaviour is exercised against a
# realistic file rather than a two-line minimum.
# ---------------------------------------------------------------------------
mkfixture() { # mkfixture <name> <self_evolution obs|absent> <self_evolution ten>
  d="$TMP/$1"; mkdir -p "$d/ops"
  {
    printf 'dimensions:\n  maintenance: condition-based\n\n'
    printf 'maintenance:\n  conditions:\n'
    printf '    orphan_nodes_threshold: 10\n'
    printf '    dangling_links_threshold: 1\n'
    printf '    draft_age_days: 14\n'
    printf '    draft_age_threshold: 20\n'
    printf '    unprocessed_captures_threshold: 30\n'
    printf '    stale_active_nodes_days: 60\n'
    printf '    stale_active_nodes_threshold: 16\n'
    printf '    pending_observations_threshold: 20\n'
    printf '    pending_tensions_threshold: 10\n'
    if [ "$2" != absent ]; then
      printf '\nself_evolution:\n'
      printf '  observation_threshold: %s   # open observations before suggesting rethink\n' "$2"
      printf '  tension_threshold: %s        # open tensions before suggesting rethink\n' "$3"
    fi
    printf '\nprovenance: full\n'
  } > "$d/ops/config.yaml"
  echo "$d"
}

# What the four `self_evolution.*` readers see: the real reader, invoked exactly
# as session-orient.sh invokes it.
others_see() { CLAUDE_PROJECT_DIR="$1" "$READER" "self_evolution.$2" "$3" 2>/dev/null; }

# What a pre-decision `/rethink` sees. This is a MODEL of that skill's documented
# read, not a call into shared code, because no bash reader for three-level keys
# exists in this repo — which is the entire reason the decision went the other
# way. Modelling it is honest here; using it as evidence that three-level keys
# are readable would not be.
rethink_sees() {
  awk -v f="$2" '
    /^maintenance:/            { inm=1; next }
    /^[^[:space:]#]/           { inm=0 }
    inm && /^  conditions:/    { inc=1; next }
    inm && /^  [^[:space:]]/   { inc=0 }
    inc && $1 == f":"          { print $2; exit }
  ' "$1/ops/config.yaml"
}

BEFORE=$(mkfixture before 10 5)     # field-vault state: tuned 20/10, seeded 10/5
AFTER=$(mkfixture after 20 10)      # after step 5 carries 20/10 across
ONLY_MC=$(mkfixture only_mc absent) # tuned, but self_evolution never seeded

echo "== the contradiction is present in the before-state =="
b_obs=$(others_see "$BEFORE" observation_threshold 10)
b_ten=$(others_see "$BEFORE" tension_threshold 5)
r_obs=$(rethink_sees "$BEFORE" pending_observations_threshold)
r_ten=$(rethink_sees "$BEFORE" pending_tensions_threshold)
eq "before: /next,/remember,hook read observation_threshold" "10" "$b_obs"
eq "before: /rethink reads pending_observations_threshold"   "20" "$r_obs"
eq "before: observation surfaces DISAGREE"                   "disagree" \
   "$([ "$b_obs" = "$r_obs" ] && echo agree || echo disagree)"
eq "before: tension surfaces DISAGREE"                       "disagree" \
   "$([ "$b_ten" = "$r_ten" ] && echo agree || echo disagree)"

# The lived consequence, recomputed rather than restated: at the field vault's
# measured 14 open observations / 8 open tensions, the two surfaces give opposite
# answers to "is it time to run /rethink?".
fires() { [ "$1" -ge "$2" ] && echo FIRES || echo silent; }
eq "before: at 14 obs, /rethink is silent"       "silent" "$(fires 14 "$r_obs")"
eq "before: at 14 obs, the other three fire"     "FIRES"  "$(fires 14 "$b_obs")"
eq "before: at 8 tensions, /rethink is silent"   "silent" "$(fires 8 "$r_ten")"
eq "before: at 8 tensions, the other three fire" "FIRES"  "$(fires 8 "$b_ten")"

echo "== the contradiction is absent in the after-state =="
a_obs=$(others_see "$AFTER" observation_threshold 10)
a_ten=$(others_see "$AFTER" tension_threshold 5)
ar_obs=$(rethink_sees "$AFTER" pending_observations_threshold)
ar_ten=$(rethink_sees "$AFTER" pending_tensions_threshold)
eq "after: /next,/remember,hook read the tuned 20" "20" "$a_obs"
eq "after: /rethink still reads 20"                "20" "$ar_obs"
eq "after: observation surfaces AGREE"             "agree" \
   "$([ "$a_obs" = "$ar_obs" ] && echo agree || echo disagree)"
eq "after: tension surfaces AGREE"                 "agree" \
   "$([ "$a_ten" = "$ar_ten" ] && echo agree || echo disagree)"
# EACH VERDICT IS PINNED TO A LITERAL, and each reader is asserted separately.
#
# The first draft of this sweep compared `fires "$c" "$ar_obs"` against
# `fires "$c" "$a_obs"` and called the property "agreement". Both variables are
# pinned to "20" by the two assertions directly above, so every one of those 14
# assertions compared a function to ITSELF and could not redden: inverting
# `fires` to `-lt` left all 14 green, and replacing its body with a constant
# `echo FIRES` left all 14 green. Agreement between two values already proven
# identical is not a property, it is a tautology.
#
# Agreement is still what matters, but it is now a CONSEQUENCE of both readers
# being pinned to the same literal rather than an assertion about the pair. The
# expected verdicts encode the point of the whole task: after 20/10 is carried
# across, 14 observations is `silent` for everyone, because the vault asked for
# 20. Asserting "all four fire at 14" would assert that the tuning was ignored.
for c in 0 10 19; do
  eq "after: at $c obs, /next,/remember,hook are silent" "silent" "$(fires "$c" "$a_obs")"
  eq "after: at $c obs, /rethink is silent"              "silent" "$(fires "$c" "$ar_obs")"
done
for c in 20 25; do
  eq "after: at $c obs, /next,/remember,hook fire" "FIRES" "$(fires "$c" "$a_obs")"
  eq "after: at $c obs, /rethink fires"            "FIRES" "$(fires "$c" "$ar_obs")"
done
for c in 0 5 9; do
  eq "after: at $c tensions, /next,/remember,hook are silent" "silent" "$(fires "$c" "$a_ten")"
  eq "after: at $c tensions, /rethink is silent"              "silent" "$(fires "$c" "$ar_ten")"
done
for c in 10 12; do
  eq "after: at $c tensions, /next,/remember,hook fire" "FIRES" "$(fires "$c" "$a_ten")"
  eq "after: at $c tensions, /rethink fires"            "FIRES" "$(fires "$c" "$ar_ten")"
done
# The before-state must disagree at exactly the counts that fall between the two
# thresholds — 10, 14 and 19 are >= 10 but < 20, so the two surfaces split there.
#
# ON ITS OWN THIS ONE DOES NOT DISCRIMINATE A BROKEN `fires`: inverting the
# comparison flips both sides and the count stays 3. It is the four literal
# `before:` verdicts above that catch that, which is why they are not redundant
# with this and none of them may be collapsed into it.
disagreements=0
for c in 10 14 19; do
  [ "$(fires "$c" "$r_obs")" = "$(fires "$c" "$b_obs")" ] || disagreements=$((disagreements + 1))
done
eq "before: the surfaces split at exactly 3 of the swept counts" "3" "$disagreements"
# Carrying across COPIES; the old pair must survive, or the stale /rethink in an
# un-regenerated vault drops to its built-in default and re-opens the split from
# the other side.
eq "after: maintenance.conditions pair is left in place" "20 10" "$ar_obs $ar_ten"

echo "== the hook structurally cannot read the three-level key =="
# This is the decision's load-bearing claim. read_config.sh routes a dotted key
# to <section>/<field>; `maintenance.conditions.pending_observations_threshold`
# resolves to section `maintenance`, field `conditions.pending_...`, which no
# line matches — so the default comes back. A vault tuned only under
# maintenance.conditions gets the DEFAULT everywhere, which is why step 5 must
# carry the value rather than the reader chase it.
eq "unreadable_by_the_hook: 3-level key yields the default, not 20" "10" \
   "$(CLAUDE_PROJECT_DIR="$ONLY_MC" "$READER" maintenance.conditions.pending_observations_threshold 10 2>/dev/null)"
eq "only maintenance.conditions: self_evolution read falls back to default" "10" \
   "$(others_see "$ONLY_MC" observation_threshold 10)"
eq "only maintenance.conditions: surfaces DISAGREE (20 vs default 10)" "disagree" \
   "$([ "$(others_see "$ONLY_MC" observation_threshold 10)" = "$(rethink_sees "$ONLY_MC" pending_observations_threshold)" ] \
      && echo agree || echo disagree)"

echo "== section isolation: a sibling section must not answer =="
# `draft_age_threshold: 20` lives under maintenance.conditions. Asking for
# self_evolution.draft_age_threshold must return the default, not 20.
eq "sibling section does not answer for self_evolution" "7" \
   "$(others_see "$BEFORE" draft_age_threshold 7)"

echo "== the repo names exactly one namespace =="
# BOTH DIRECTIONS. A bare "no legacy spelling survives" check passes just as
# happily when a consumer has lost its reader entirely, so the positive half is
# not optional decoration.
#
# Every list below is written literally into its `for`. An unquoted "$VAR" list
# does NOT word-split under zsh's defaults: the first draft of this suite folded
# four filenames into one and reported two confident failures, and folded two
# legacy spellings into one pattern that then passed vacuously. Same class of
# bug, opposite verdicts, one cause.
#
# `grep -q` on the exit status, never `grep -c` piped through `|| echo 0` — a
# non-matching `grep -c` prints its own "0" AND fires the fallback, producing
# "0\n0" and an "integer expression expected" that reads as a test-harness crash
# rather than as the absence it actually is.
says() { grep -qE "$2" "$REPO/$1" 2>/dev/null && echo yes || echo no; }

for f in \
  skill-sources/next/SKILL.md \
  skill-sources/remember/SKILL.md \
  skill-sources/rethink/SKILL.md \
  hooks/scripts/session-orient.sh
do
  for k in observation_threshold tension_threshold; do
    eq "positive: $f names self_evolution.$k" "yes" "$(says "$f" "self_evolution\.$k")"
  done
done

# The negative half is keyed on the PROPERTY — "a legacy threshold key is read as
# a threshold source" — so both legacy spellings are checked, not one. Only
# skills/upgrade may name them: it reconciles the two, so it must say both.
for k in pending_observations_threshold pending_tensions_threshold; do
  hits=$(grep -rlE "$k" "$REPO/skills" "$REPO/skill-sources" "$REPO/hooks" \
                       "$REPO/generators" "$REPO/reference" "$REPO/presets" \
                       "$REPO/platforms" 2>/dev/null \
         | grep -v "/skills/upgrade/SKILL.md$" \
         | grep -v "/reference/test/threshold-namespace.test.sh$" \
         | sort | tr '\n' ' ' | sed 's/ $//')
  eq "negative: no generating surface reads $k" "" "$hits"

  # And the one file allowed to name it must actually still name it. An
  # allowlist entry that has gone quiet is how the reconciliation step could be
  # deleted with the negative check above still reporting all-clear.
  eq "allowlist is live: skills/upgrade names $k" "yes" \
     "$(says skills/upgrade/SKILL.md "$k")"
done

# The generator emits the authoritative namespace and only it.
eq "setup emits a self_evolution: block" "yes" "$(says skills/setup/SKILL.md '^self_evolution:')"
eq "no generator emits the legacy pair" "0" \
   "$(grep -rlE 'pending_observations_threshold' "$REPO/skills/setup/SKILL.md" "$REPO/generators" 2>/dev/null | wc -l | tr -d ' ')"

echo
printf 'threshold-namespace: %d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ] || exit 1
