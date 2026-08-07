#!/bin/bash
# fence-isolation.test.sh — execute every ```bash fence in every SKILL.md as its
# OWN shell invocation, the way Claude actually runs them.
#
# WHY THIS EXISTS: Claude executes each fenced bash block in a SKILL.md as a
# separate Bash tool call. No variable and no sourced function crosses a fence
# boundary. A `$VAR` set in fence 1 expands to the EMPTY STRING in fence 2 —
# silently — and `$(( ))` folds empty to 0. So the failure renders as a
# plausible number at rc=0, never as an error. Four of the six blocking findings
# in the whole-branch review were exactly this, and no existing gate could see
# them: check-portability.sh matches text, link-extraction.test.sh exercises the
# library in isolation where it is correct, guard-failure.test.sh tests the
# guard. None of them executes a fence.
#
# Run under BOTH shells: `bash …test.sh` and `zsh …test.sh`.
#
# THE RUBRIC, which every assertion below serves: a failure must never render as
# a plausible number. An EMPTY vault is a legitimate success (rc 0, value 0); a
# NONEXISTENT vault must fail loudly.
#
# ASSERTION M'S BOUNDARY, stated here rather than only beside its own code
# (Spec I Task 5 Step 4): M calls skills/upgrade/SKILL.md's
# resolve_canonical_name (Task 1) and mechanically_compare (Task 3) with real
# arguments against a constructed fixture, and proves those two bash
# primitives behave correctly on it. It proves NOTHING about the render step
# between them (Task 2) — that step is an LLM judgment call with no bash to
# call, so a green M means "the primitive's bash half works," never "the
# /upgrade skill's modification detection works" as a whole.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
LINK_LIB_SRC="$ROOT/reference/lib/link-extraction.sh"
FM_LIB_SRC="$ROOT/reference/lib/frontmatter.sh"

# Every spawned shell must be THIS harness's shell, not `sh`. On macOS `sh` is
# bash 3.2 regardless of what launched the harness, so an `sh` site silently
# runs the bash path even under `zsh …test.sh` — which defeats the promise made
# above. Two defects closed on this branch were bash/zsh forks.
if [ -n "${ZSH_VERSION:-}" ]; then SELF=zsh; else SELF=bash; fi

# WHY THE WORK DIRECTORY IS A FIXED, DIGIT-FREE PATH AND NOT `mktemp -d`:
# assertion N asks whether a fence emitted DIGITS on stdout. An mktemp path
# contains digits (`/var/folders/f2/9vss9brn…`), so any fence echoing a filename
# under that root trips the digit test and reports a defect against correct
# code. This was measured as a near-miss false Critical before the path was
# pinned. The shell name keeps the two CI jobs from colliding.
WORK="/tmp/fence-isolation-gate-$SELF"
rm -rf "$WORK"
# Says WHY it died. An `|| exit 1` here exits 1 with an empty stdout and a
# silent stderr — the exact shape this gate exists to eliminate, and it cost a
# debugging cycle during development when a leftover process made the mkdir
# fail and the gate reported nothing at all.
mkdir -p "$WORK/fences" "$WORK/out" || {
  printf 'harness: cannot create work directory %s — cannot conclude anything\n' "$WORK" >&2
  exit 1
}
# FENCE_GATE_KEEP=1 preserves the extracted fences, the generated scripts and
# every captured stdout/stderr. Diagnosing a failure means reading the exact
# script that ran, and a gate whose evidence self-destructs invites guessing.
[ -n "${FENCE_GATE_KEEP:-}" ] || trap 'rm -rf "$WORK"' EXIT INT TERM

fences=0; run=0; skipped=0
h_fail=0; n_fail=0; setu_fail=0; known=0; stale=0; f_fail=0; m_fail=0
SKIP_LOG="$WORK/skips.txt"; : > "$SKIP_LOG"
FAIL_LOG="$WORK/fails.txt"; : > "$FAIL_LOG"
SETU_LOG="$WORK/setu.txt"; : > "$SETU_LOG"
KNOWN_LOG="$WORK/known.txt"; : > "$KNOWN_LOG"
HIT_LOG="$WORK/hits.txt";    : > "$HIT_LOG"
SEEN_LABELS="$WORK/labels.txt"; : > "$SEEN_LABELS"

# --- fences this gate does not execute --------------------------------------
# Enumerated, one line per site, in the same shape as the two file-level
# exemptions in check-portability.sh. An enumerated list is greppable and its
# entries can be argued with; a pattern loose enough to catch this case would
# also catch working code.
#
# Format: <label>~<reason>
ILLUSTRATIVE='skills/reseed f03~single git mv over literal placeholder operands (old-folder/, new-folder/) under prose that reads "If folder names change"
skill-sources/tasks f03~an if whose entire body is comments describing the steps; bash -n rejects the empty then-branch and zsh accepts it, so listing it keeps the two shells reporting the same counts'

# --- known-open defects this gate FOUND and does not yet block on -----------
# Every line below is a real defect, found by this gate on the tree it landed
# against, in a skill the hardening branch never touched. They are listed rather
# than fixed because fixing them is a separate change with its own review: the
# `seed` sites read `$FILE`, which is the argument the skill is invoked with, so
# the repair is a design decision (re-derive per fence? read `$ARGUMENTS`?) and
# not the stanza copy that closed the `graph` sites.
#
# THE LIST IS CHECKED IN BOTH DIRECTIONS. A listed site that fails is reported
# as KNOWN and does not block. A listed site that PASSES fails the gate, and so
# does a listed site that no longer exists — otherwise the list rots into a
# permanent silence, which is the defect class this whole gate is about.
#
# A reason beginning `ZSH ONLY:` or `BASH ONLY:` marks a site that fails in one
# shell and not the other — a real defect class here, and one the staleness
# check must know about or it would report the entry as rotten in the shell
# where the fence legitimately passes.
#
# Format: <label>~<assertion letter>~<reason>
# A reason may open with the literal, case-sensitive prefix `ZSH ONLY:` or
# `BASH ONLY:` to scope the entry to one shell — see in_scope().
#
# A NEAR-MISS IS A HARNESS ERROR, NOT A DEFAULT. This comment used to claim the
# fallthrough "errs safe (an unrecognised prefix can only widen scope, never
# silently narrow it)" and that a lowercase prefix "silently does nothing". Both
# halves were wrong, and in the direction that matters: widening is the UNSAFE
# direction for absorption. A `zsh only:` entry does not do nothing — it converts
# a shell-scoped entry into an EVERY-shell one and re-absorbs the bash failure
# that scoping exists to block, which is the ce57b25 defect in a broader form.
# Measured before this fix: same broken fence, `ZSH ONLY:` -> bash FAILs (correct);
# `zsh only:` -> bash PASSes. So in_scope now rejects anything that looks like a
# scope marker but is not one of the two canonical spellings.
KNOWN_OPEN='skill-sources/seed f01~H~ZSH ONLY: ops/queue*.yaml matches nothing in a vault whose queue lives at ops/queue/queue.yaml, and zsh aborts the command on a non-matching glob where bash passes the pattern through
skills/health f08~H~ZSH ONLY: self/memory/*.md matches nothing in a vault with no memory notes, same non-matching-glob fork as seed f01'

table_reason() {                    # table_reason <table> <label> [letter]
  printf '%s\n' "$1" | while IFS='~' read -r l a r; do
    if [ -z "${3:-}" ]; then
      [ "$l" = "$2" ] && printf '%s' "$a"
    else
      [ "$l" = "$2" ] && [ "$a" = "$3" ] && printf '%s' "$r"
    fi
  done
}

# --- fixture ----------------------------------------------------------------
# Filenames are digit-free for the same reason the work path is. Content dates
# carry digits, but content only reaches stdout from the healthy fixture, where
# the digit test is not applied.
#
# `mode` is `full` or `hollow`. hollow is the healthy vault MINUS the notes and
# inbox directories — NOT an empty directory. A fence must still get past
# sourcing the link library and reach the notes-dir logic, or assertion N would
# pass vacuously on a fence that never touched the notes directory at all.
build_fixture() {
  v="$1"; mode="$2"
  rm -rf "$v"
  mkdir -p "$v/ops/lib" "$v/ops/queue" "$v/ops/observations" "$v/ops/tensions" \
           "$v/ops/methodology" "$v/ops/sessions" "$v/self" "$v/self/memory" \
           "$v/.claude/skills/stats" "$v/.claude/skills/extract" "$v/.claude/skills/verify" || return 1
  : > "$v/.arscontexta"
  cp "$LINK_LIB_SRC" "$v/ops/lib/link-extraction.sh" || {
    printf 'harness: cannot copy %s into the fixture\n' "$LINK_LIB_SRC" >&2
    return 1
  }
  cp "$FM_LIB_SRC" "$v/ops/lib/frontmatter.sh" || {
    printf 'harness: cannot copy %s into the fixture\n' "$FM_LIB_SRC" >&2
    return 1
  }

  # THE `---` DELIMITERS ARE LOAD-BEARING, not decoration. These two files had none,
  # which was fine while the counting fences matched `^status:` line-anchored anywhere
  # in the file. They read the field out of FRONTMATTER now, and frontmatter is defined
  # strictly: a `---` on line 1 and a closing `---`. Without them these files declare no
  # status at all, every converted fence would count 0 on a HEALTHY fixture, and every
  # assertion would still pass — vacuously. Real generated observations carry the
  # delimiters (generators/features/self-evolution.md:85), so this is fixture fidelity,
  # not a concession to the parser.
  printf -- '---\ndescription: an observation\nstatus: pending\ntitle: an observation\n---\nBody.\n' > "$v/ops/observations/obs-one.md"
  printf -- '---\nstatus: open\ntitle: a tension\n---\nBody.\n'  > "$v/ops/tensions/tension-one.md"
  printf 'description: a learned rule\ntitle: a learned rule\n' > "$v/ops/methodology/method-one.md"
  printf 'title: a session\n'                            > "$v/ops/sessions/session-one.md"
  printf -- '- id: one\n  status: pending\n- id: two\n  status: done\n' > "$v/ops/queue/queue.yaml"
  printf 'title: identity\n'                             > "$v/self/identity.md"
  # Level 5/6/7 markers and one non-identity pair (reduce -> extract) added for
  # assertion M (Spec I Task 5) -- resolve_canonical_name's own guard needs
  # "# Level 5: Process verbs" present verbatim, and mechanically_compare's
  # guard needs "# Level 7:" present verbatim, or both halt on THIS healthy
  # fixture too (measured, not assumed -- see assertion M's own header comment
  # for the two deliberately-malformed copies that test the halt paths).
  # topic_map/hub mirror the REAL collision Task 3 found and fixed in this
  # vault (hub: "index" re-matching the bare word "hub" inside topic_map's
  # own correct value "graph hub") -- present so assertion M's zero-
  # divergence case (below) actually exercises the asymmetry the fix depends
  # on, not just an identity-mapped skill a symmetric-substitution regression
  # would pass through unnoticed (measured: a deliberately reintroduced
  # symmetric-substitution mutation was silently absorbed by the extract/
  # stats pair alone, before this pair was added).
  printf 'vocabulary:\n  notes: notes\n# Level 5: Process verbs\n  reduce: "extract"\n# Level 6: placeholder\n  topic_map: "graph hub"\n  hub: "index"\n# Level 7: Extraction categories\n' \
                                                          > "$v/ops/derivation-manifest.md"
  printf 'derivation record\n'                           > "$v/ops/derivation.md"
  printf 'processing_depth: standard\n'                  > "$v/ops/config.yaml"
  printf 'name: stats\n'                                 > "$v/.claude/skills/stats/SKILL.md"
  # "extract" is the derived name for canonical "reduce" per the pair above.
  # Deliberately diverges from the canonical stub's substituted rendering
  # ("Run extract on the material.") by one extra word, so assertion M's
  # divergence case has real content to detect rather than a name-only stub.
  printf 'Run extract on the raw material.\n'            > "$v/.claude/skills/extract/SKILL.md"
  # "verify" is not vocabulary-derived (identity fallback); this is the
  # zero-divergence, vocabulary-substitution-aware regression case -- the
  # installed content is exactly the canonical stub's own topic_map ->
  # "graph hub" substitution, already applied, i.e. genuinely unmodified.
  printf 'Update the graph hub after verify.\n'          > "$v/.claude/skills/verify/SKILL.md"
  # Several fences reach for the JSON queue directly (`jq … ops/queue/queue.json`)
  # rather than through the YAML-or-JSON branch, so both forms must exist or the
  # fence fails on fixture shape rather than on anything it is being judged for.
  printf '{"tasks":[{"id":"one","status":"pending"},{"id":"two","status":"done"}]}\n' > "$v/ops/queue/queue.json"
  # The lock directory is created here because skill-sources/reflect and
  # skill-sources/reweave once spun on an unbounded `while ! mkdir "$LOCKDIR"`
  # and the PARENT of that lock was created by nothing in this repository — see
  # the report's live findings. Both fences now bound the wait at 60s and create
  # the parent themselves, so this no longer prevents a hang; it is kept because
  # a fixture that omits it would exercise the parent-creation branch on every
  # run rather than the acquisition path the fences are actually judged on.
  # KNOWN BLIND SPOT, unchanged: with the directory present the fixture is
  # kinder than a real generated vault.
  mkdir -p "$v/ops/queue/.locks" || return 1
  # `git init` because a fence in skills/reseed calls `git`, which exits 128
  # outside a work tree. Quiet, and with a local identity so a machine without
  # a global git config behaves the same as one with it.
  ( cd "$v" && git init -q . && git config user.email gate@example.invalid \
      && git config user.name gate ) >/dev/null 2>&1 || return 1

  [ "$mode" = hollow ] && return 0

  mkdir -p "$v/notes/sub" "$v/inbox" || return 1
  TODAY=$(date +%Y-%m-%d)
  # alpha is the note the substituted metavariables point at, so the greps that
  # look for it actually match. beta and gamma link to it; delta-moc is a MOC.
  printf -- '---\ntype: note\ntitle: alpha\ndescription: first note\ncreated: %s\ntopics:\n  - "[[delta-moc]]"\n---\nBody of alpha.\n' "$TODAY" > "$v/notes/alpha.md"
  printf -- '---\ntype: note\ntitle: beta\ndescription: second note\ncreated: %s\ntopics:\n  - "[[delta-moc]]"\n---\nLinks to [[alpha]] and [[gamma]].\n' "$TODAY" > "$v/notes/beta.md"
  printf -- '---\ntype: note\ntitle: gamma\ndescription: third note\ncreated: %s\ntopics:\n  - "[[delta-moc]]"\n---\nLinks to [[alpha]].\n' "$TODAY" > "$v/notes/gamma.md"
  printf -- '---\ntype: moc\ntitle: delta-moc\ndescription: the map\ncreated: %s\ntopics:\n  - "[[delta-moc]]"\n---\nCovers [[alpha]], [[beta]], [[gamma]].\n' "$TODAY" > "$v/notes/delta-moc.md"
  printf -- '---\ntype: note\ntitle: nested\ndescription: nested note\ncreated: %s\ntopics:\n  - "[[delta-moc]]"\n---\nLinks to [[alpha]].\n' "$TODAY" > "$v/notes/sub/nested.md"
  printf -- '---\ntitle: raw capture\n---\nUnprocessed material.\n' > "$v/inbox/raw-capture.md"

  # --- the frontmatter discriminating set -----------------------------------
  # Four notes under one subtree, so the answer can be counted in ISOLATION. Mixed
  # in with alpha..nested the numbers below would be sums over unrelated files and
  # would drift every time someone adds a fixture note.
  #
  # It lives under notes/ rather than beside it because that is where a real vault's
  # status fields live, and because a probe kept in a private directory would stop
  # being exposed to whatever the notes tree grows into.
  mkdir -p "$v/notes/status-probe/deep" || return 1
  printf -- '---\ntitle: one active\nstatus: active\n---\nBody.\n' \
    > "$v/notes/status-probe/one-active.md"
  # COLUMN 0 IS THE WHOLE POINT of this file. Indent the fenced `status: pending`
  # by even one space and `grep -rl '^status:'` stops matching it, the naive arm
  # below returns 2 instead of 1, and the discriminator quietly becomes a tautology
  # that passes whatever the parser does.
  printf -- '---\ntitle: two fenced\n---\nExample of the schema:\n```yaml\nstatus: pending\n```\nEnd.\n' \
    > "$v/notes/status-probe/two-fenced.md"
  printf -- '---\ntitle: three archived\nstatus: archived\n---\nBody.\n' \
    > "$v/notes/status-probe/deep/three-archived.md"
  printf -- 'Just a body. No frontmatter at all.\n' \
    > "$v/notes/status-probe/four-bare.md"
  return 0
}

# --- assertion F: the frontmatter parser, three ways ------------------------
# Not a fence assertion — a library one, kept in this harness rather than in a new
# reference/test/frontmatter.test.sh because an unwired suite is a green-looking
# nothing, and this gate is already wired into CI and CLAUDE.md's table.
#
# THE THREE ARMS TEST DIFFERENT PROPERTIES. Do not delete either as redundant:
#   correct(status)    = 2  the parser reads the FRONTMATTER field
#   naive(grep -rl)    = 1  ...and the body-fenced `status: pending` is why the old
#                           spelling disagreed. This arm tests FENCE/BODY discrimination.
#   wrong-field        = 4  asking for a field NO note declares must return all four.
#                           This arm tests FIELD-NAME discrimination: a parser that
#                           merely detected "has frontmatter" would return 1 here and
#                           the first arm alone would never notice.
# `reviewed` is the wrong-field name because it appears in none of the four
# frontmatters. `type` or `title` would NOT work — two-fenced.md needs some
# frontmatter to distinguish it from four-bare.md, so a field it happens to carry
# would return 3 and the arm would silently stop discriminating.
assert_frontmatter_three_ways() {           # assert_frontmatter_three_ways <vault>
  probe="$1/notes/status-probe"
  f_fail=0
  if [ ! -d "$probe" ]; then
    printf 'F  discriminating set missing at %s — cannot conclude anything\n' "$probe" >> "$FAIL_LOG"
    return 1
  fi
  # Loaded from the FIXTURE copy, not $ROOT: that is the file a generated vault
  # actually sources, so a broken cp is a failure rather than an invisible fallback.
  . "$1/ops/lib/frontmatter.sh" || {
    printf 'F  cannot source the fixture copy of frontmatter.sh\n' >> "$FAIL_LOG"
    return 1
  }
  f_total=$(find "$probe" -type f -name '*.md' | wc -l | tr -d ' ')
  f_naive_has=$(/usr/bin/grep -rl '^status:' "$probe" 2>/dev/null | wc -l | tr -d ' ')
  f_correct=$(count_notes_missing_field "$probe" status) || f_correct=ERR
  f_naive=$((f_total - f_naive_has))
  f_wrong=$(count_notes_missing_field "$probe" reviewed) || f_wrong=ERR

  [ "$f_total" = 4 ] || { printf 'F  discriminating set holds %s notes, expected 4\n' "$f_total" >> "$FAIL_LOG"; f_fail=1; }
  [ "$f_correct" = 2 ] || { printf 'F  correct parser returned %s missing-status, expected 2\n' "$f_correct" >> "$FAIL_LOG"; f_fail=1; }
  [ "$f_naive" = 1 ] || { printf 'F  naive grep -rl returned %s missing-status, expected 1 (fixture no longer discriminates)\n' "$f_naive" >> "$FAIL_LOG"; f_fail=1; }
  [ "$f_wrong" = 4 ] || { printf 'F  wrong-field parser returned %s missing-reviewed, expected 4\n' "$f_wrong" >> "$FAIL_LOG"; f_fail=1; }
  return "$f_fail"
}

VAULT_FULL="$WORK/vault-full"
VAULT_HOLLOW="$WORK/vault-hollow"
build_fixture "$VAULT_HOLLOW" hollow || { echo "harness: cannot build hollow fixture" >&2; exit 1; }

# Assertion F runs ONCE, here, against its own build of the full fixture. It is not
# per-fence, and the fence loop rebuilds VAULT_FULL on every iteration, so running it
# there would repeat the same check ~72 times and report the last one.
build_fixture "$VAULT_FULL" full || { echo "harness: cannot build full fixture" >&2; exit 1; }
assert_frontmatter_three_ways "$VAULT_FULL" || f_fail=1

# --- assertion M: /upgrade's modification-detection primitives, called with
# real arguments -- not just defined and left uncalled -----------------------
# Spec I Task 5. resolve_canonical_name (Task 1) and mechanically_compare
# (Task 3) are DEFINED by fences elsewhere in this file's own generic sweep,
# but a fence that only defines a function and never calls it passes H/N/U
# trivially -- exactly the gap Task 1's and Task 3's own reports flagged as
# deferred to this task. Also not per-fence, for the same reason as F: it runs
# once against VAULT_FULL, not ~72 times inside the fence loop.
#
# STATED BOUNDARY OF WHAT THIS PROVES (Task 5 Step 4, required by the plan):
# this covers Task 1's deterministic lookup and Task 3's diff-based
# comparison -- both are pure bash, callable, and assertable with real
# arguments. It proves NOTHING about Task 2's render step: that step is an
# LLM judgment call with no bash to call, so a green result here means "the
# two bash primitives behave correctly against this fixture," never "the
# /upgrade skill's modification detection works" as a whole. A green M is
# the bash half; Task 2's own Done-when check is a prose-review grep for
# exactly that reason.
#
# NO NEW GLOB is introduced for the "for every skill" success criterion in
# the brief -- all three skills this assertion cares about (extract, stats,
# verify) are addressed by exact path, deliberately, rather than iterating
# `.claude/skills/*/` and risking the zsh `nomatch` trap skill-sources/seed
# f01 and skills/health f08 already carry (see KNOWN_OPEN above). Three named
# skills covering all required outcomes (diverged -> MODIFIED, unmodified,
# identity-mapped -> not, unmodified AND vocabulary-substitution-collision-
# adjacent -> not) satisfy the brief's three success criteria without that
# risk. `verify` is not optional: (c)'s identity-mapped stats/extract pair
# alone does NOT catch the asymmetry regression Task 3's fix depends on --
# see (c2) below and the mutation record in task-5-report.md.
extract_shared_step() {   # extract_shared_step <heading> <next-heading> <outfile>
  m_start=$(/usr/bin/grep -nF "$1" "$ROOT/skills/upgrade/SKILL.md" | head -1 | cut -d: -f1)
  m_end=$(/usr/bin/grep -nF "$2" "$ROOT/skills/upgrade/SKILL.md" | head -1 | cut -d: -f1)
  [ -n "$m_start" ] && [ -n "$m_end" ] || return 1
  sed -n "${m_start},${m_end}p" "$ROOT/skills/upgrade/SKILL.md" \
    | awk '/^```bash[[:space:]]*$/{f=1;next} /^```[[:space:]]*$/{if(f)exit} f' > "$3"
}

build_plugin_stub() {   # build_plugin_stub <dir>
  d="$1"; rm -rf "$d"
  mkdir -p "$d/skill-sources/reduce" "$d/skill-sources/stats" "$d/skill-sources/verify" || return 1
  # Canonical stub for "reduce" -- the bare word "reduce" is what
  # mechanically_compare's substitution table (built from the manifest's
  # reduce: "extract" pair) rewrites to "extract" before diffing.
  printf 'Run reduce on the material.\n' > "$d/skill-sources/reduce/SKILL.md"
  # Canonical stub for "stats" -- byte-identical to the vault's installed
  # .claude/skills/stats/SKILL.md, since "stats" is not vocabulary-derived
  # (identity fallback) and this is the "zero divergence" regression case.
  printf 'name: stats\n' > "$d/skill-sources/stats/SKILL.md"
  # Canonical stub for "verify" -- uses "topic_map", whose substituted value
  # ("graph hub") CONTAINS the bare word "hub", itself a separate table key
  # (hub -> "index"). If the installed side were ever substituted too (the
  # asymmetry regression Task 3 fixed), "hub" inside "graph hub" would get
  # wrongly re-matched. This is the second, vocabulary-aware zero-divergence
  # regression case; "extract"/"stats" alone do not exercise this collision.
  printf 'Update the topic_map after verify.\n' > "$d/skill-sources/verify/SKILL.md"
}

assert_modification_detection() {   # assert_modification_detection <vault> <plugin-root>
  m_vault="$1"; m_plugin="$2"; m_fail=0
  m_rcn="$WORK/upgrade-resolve.sh"; m_mc="$WORK/upgrade-compare.sh"
  extract_shared_step '## Shared Step: Resolving a Vault Skill to Its Canonical Template' \
                       "## Shared Step: Rendering the Canonical Template in This Vault's Vocabulary" \
                       "$m_rcn" || {
    printf 'M  could not extract resolve_canonical_name from skills/upgrade/SKILL.md -- heading text may have drifted\n' >> "$FAIL_LOG"
    m_fail=1; return 1
  }
  extract_shared_step '## Shared Step: Mechanically Comparing a Vault Skill Against Its Canonical Template' \
                       '## Step 1: Inventory Current System' \
                       "$m_mc" || {
    printf 'M  could not extract mechanically_compare from skills/upgrade/SKILL.md -- heading text may have drifted\n' >> "$FAIL_LOG"
    m_fail=1; return 1
  }
  [ -s "$m_rcn" ] && [ -s "$m_mc" ] || {
    printf 'M  extracted fence(s) empty -- heading text found but no bash fence between them\n' >> "$FAIL_LOG"
    m_fail=1; return 1
  }

  # (a) genuine divergence -> MODIFIED (non-empty diff, rc != 0 from diff itself)
  {
    printf '. %s\n' "$m_rcn"
    printf '. %s\n' "$m_mc"
    printf 'canon=$(resolve_canonical_name extract)\n'
    printf 'mechanically_compare "$CLAUDE_PLUGIN_ROOT/skill-sources/$canon/SKILL.md" ".claude/skills/extract/SKILL.md"\n'
  } > "$WORK/m-driver-a.sh"
  m_out=$(cd "$m_vault" && CLAUDE_PLUGIN_ROOT="$m_plugin" "$SELF" "$WORK/m-driver-a.sh" 2>"$WORK/m-a.err")
  if [ -z "$m_out" ]; then
    printf 'M  (a) extract vs. reduce should report MODIFIED (non-empty diff); got empty output, stderr=[%s]\n' "$(cat "$WORK/m-a.err")" >> "$FAIL_LOG"
    m_fail=1
  fi

  # (b) two real halt paths, each naming what failed -- not a silent skip
  m_bad="$WORK/vault-bad-manifest"
  rm -rf "$m_bad"; cp -R "$m_vault" "$m_bad" 2>/dev/null || { printf 'M  (b) cannot copy vault fixture for the malformed-manifest case\n' >> "$FAIL_LOG"; m_fail=1; }
  # vocabulary: present, but no "# Level 7:" marker -- mechanically_compare's
  # own guard, not resolve_canonical_name's (which has a marker of its own).
  printf 'vocabulary:\n  notes: notes\n# Level 5: Process verbs\n  reduce: "extract"\n' > "$m_bad/ops/derivation-manifest.md"
  m_err=$(cd "$m_bad" && CLAUDE_PLUGIN_ROOT="$m_plugin" "$SELF" "$WORK/m-driver-a.sh" 2>&1 1>/dev/null)
  m_rc2=$?
  [ "$m_rc2" -ne 0 ] || { printf 'M  (b) manifest missing "# Level 7:" should halt (rc != 0); got rc=0\n' >> "$FAIL_LOG"; m_fail=1; }
  # Key on text unique to THIS guard's own halt message (mechanically_compare's
  # "# Level 7:" marker check), not a substring ("derivation-manifest.md")
  # every halt in this file happens to share -- a predicate that broad would
  # still pass if resolve_canonical_name's own Level-5 guard fired instead
  # (it names the same manifest path), silently testing the wrong function.
  case "$m_err" in
    *'Level 7'*) : ;;
    *) printf 'M  (b) halt on malformed manifest was not mechanically_compare'"'"'s "# Level 7:" guard: [%s]\n' "$m_err" >> "$FAIL_LOG"; m_fail=1 ;;
  esac
  rm -rf "$m_bad"

  m_noman="$WORK/vault-no-manifest"
  rm -rf "$m_noman"; cp -R "$m_vault" "$m_noman" 2>/dev/null || { printf 'M  (b) cannot copy vault fixture for the missing-manifest case\n' >> "$FAIL_LOG"; m_fail=1; }
  rm -f "$m_noman/ops/derivation-manifest.md"
  printf '. %s\nresolve_canonical_name extract\n' "$m_rcn" > "$WORK/m-driver-b.sh"
  m_err2=$(cd "$m_noman" && "$SELF" "$WORK/m-driver-b.sh" 2>&1 1>/dev/null)
  m_rc3=$?
  [ "$m_rc3" -ne 0 ] || { printf 'M  (b) resolve_canonical_name on a missing manifest should halt (rc != 0); got rc=0\n' >> "$FAIL_LOG"; m_fail=1; }
  # resolve_canonical_name has TWO halts and both interpolate $derived into
  # their message, so "*extract*" alone cannot tell which one fired -- a
  # mutation removing only the missing-file guard (this fixture's actual
  # condition) still halts via the downstream "Level 5" guard on the same
  # nonexistent path, and that message also contains "extract" (measured:
  # this is exactly what the report's own mutation-2 found). Key on "cannot
  # resolve", unique to the missing-manifest-FILE guard's own wording --
  # the Level-5 guard says "cannot verify" instead.
  case "$m_err2" in
    *'cannot resolve'*) : ;;
    *) printf 'M  (b) halt on a missing manifest was not resolve_canonical_name'"'"'s own missing-file guard: [%s]\n' "$m_err2" >> "$FAIL_LOG"; m_fail=1 ;;
  esac
  rm -rf "$m_noman"

  # (c) zero divergence -> not modified (empty diff, rc 0) -- the regression
  # check: nothing before this plan should start reporting differently on an
  # unmodified vault.
  {
    printf '. %s\n' "$m_rcn"
    printf '. %s\n' "$m_mc"
    printf 'canon=$(resolve_canonical_name stats)\n'
    printf 'mechanically_compare "$CLAUDE_PLUGIN_ROOT/skill-sources/$canon/SKILL.md" ".claude/skills/stats/SKILL.md"\n'
  } > "$WORK/m-driver-c.sh"
  m_out2=$(cd "$m_vault" && CLAUDE_PLUGIN_ROOT="$m_plugin" "$SELF" "$WORK/m-driver-c.sh" 2>"$WORK/m-c.err")
  m_rc4=$?
  if [ "$m_rc4" -ne 0 ] || [ -n "$m_out2" ]; then
    printf 'M  (c) unmodified stats skill should report empty diff (not MODIFIED); rc=%s out=[%s] stderr=[%s]\n' \
      "$m_rc4" "$m_out2" "$(cat "$WORK/m-c.err")" >> "$FAIL_LOG"
    m_fail=1
  fi

  # (c2) same regression, but vocabulary-substitution-aware: "verify" is
  # unmodified AND its canonical text contains "topic_map" (substituted
  # value "graph hub" contains the separate table key "hub"). This is the
  # one the identity-mapped "stats" case above cannot exercise -- confirmed
  # by mutation: reintroducing installed-side substitution passed (c) above
  # silently and is caught only here.
  {
    printf '. %s\n' "$m_rcn"
    printf '. %s\n' "$m_mc"
    printf 'canon=$(resolve_canonical_name verify)\n'
    printf 'mechanically_compare "$CLAUDE_PLUGIN_ROOT/skill-sources/$canon/SKILL.md" ".claude/skills/verify/SKILL.md"\n'
  } > "$WORK/m-driver-c2.sh"
  m_out3=$(cd "$m_vault" && CLAUDE_PLUGIN_ROOT="$m_plugin" "$SELF" "$WORK/m-driver-c2.sh" 2>"$WORK/m-c2.err")
  m_rc5=$?
  if [ "$m_rc5" -ne 0 ] || [ -n "$m_out3" ]; then
    printf 'M  (c2) unmodified verify skill (topic_map/hub collision case) should report empty diff (not MODIFIED); rc=%s out=[%s] stderr=[%s]\n' \
      "$m_rc5" "$m_out3" "$(cat "$WORK/m-c2.err")" >> "$FAIL_LOG"
    m_fail=1
  fi

  return "$m_fail"
}

PLUGIN_STUB="$WORK/plugin-stub"
build_plugin_stub "$PLUGIN_STUB" || { echo "harness: cannot build plugin-root stub" >&2; exit 1; }
assert_modification_detection "$VAULT_FULL" "$PLUGIN_STUB" || m_fail=1

# --- preconditions ----------------------------------------------------------
# Asserted, not assumed. A missing tool makes a fence exit 127, which this gate
# would otherwise report as a defect in the fence — a false Critical, and the
# reader has no way to tell it from a real one. Note that jq, bc and git are
# used by fences but are NOT in the README prerequisite table; that gap is a
# finding in its own right, recorded in the report.
missing=""
for t in rg awk jq bc git sed; do
  command -v "$t" >/dev/null 2>&1 || missing="$missing $t"
done
if [ -n "$missing" ]; then
  printf 'harness: required tool(s) missing:%s — cannot conclude anything\n' "$missing" >&2
  exit 1
fi

# `qmd` is the one dependency the README marks OPTIONAL, and the fences that
# call it must survive its absence. Stubbing it keeps the gate measuring fence
# isolation instead of measuring whether this particular machine happens to have
# a qmd index: unstubbed, the same fence exits 1 here ("Collection not found")
# and 127 on the CI image, so the gate's verdict would depend on the host.
# KNOWN BLIND SPOT: a fence that mishandles a real qmd failure passes here.
mkdir -p "$WORK/bin"
printf '#!/bin/sh\nexit 0\n' > "$WORK/bin/qmd"
chmod +x "$WORK/bin/qmd"
PATH="$WORK/bin:$PATH"
export PATH

# --- placeholder map --------------------------------------------------------
# Discovered by SCAN, never by a hardcoded list of sites: a placeholder left
# unsubstituted produces a failure that looks exactly like the defect this gate
# hunts, so an unmapped token is a HARNESS error, not a fence result.
#
# `{vocabulary.X}` falls back to X, which is right for every vocabulary term the
# generator emits. Author metavariables (`{field}`, `{target}`, …) get concrete
# fixture-valid values so the fence RUNS. They are deliberately NOT a skip rule:
# `{field}` is an author metavariable but `$NOTES_DIR` in the same fence is a
# cross-fence read, and a rule keyed on "has an unresolved placeholder" cannot
# tell them apart — it would silently drop live defects, which is this gate's
# own failure mode.
map_value() {
  case "$1" in
    '{vocabulary.notes}')            printf 'notes' ;;
    '{vocabulary.inbox}')            printf 'inbox' ;;
    '{vocabulary.notes_collection}') printf 'notes' ;;
    '{vocabulary.topic_map}')        printf 'moc' ;;
    '{vocabulary.topic_maps}')       printf 'mocs' ;;
    '{vocabulary.topic_map_plural}') printf 'mocs' ;;
    '{vocabulary.note_plural}')      printf 'notes' ;;
    '{field}')                       printf 'type' ;;
    '{value}')                       printf 'note' ;;
    '{target}')                      printf 'alpha' ;;
    '{condition_key}')               printf 'orphans' ;;
    '{description}')                 printf 'a sample description' ;;
    '{priority}')                    printf 'high' ;;
    '{SOURCE_NAME}')                 printf 'sample-source' ;;
    '{SOURCE_BASENAME}')             printf 'sample-source' ;;
    '{SKILL_NAME}')                  printf 'stats' ;;
    '{skill-name}')                  printf 'stats' ;;
    # `{DOMAIN:notes}` is a second, older templating spelling that survives in
    # skill-sources/seed. The identifier after the colon is already the folder
    # name, so it resolves the same way `{vocabulary.X}` does.
    '{DOMAIN:'*)                     printf '%s' "$(printf '%s' "$1" | sed 's/^{DOMAIN://; s/}$//')" ;;
    '{DATE}')                        printf '%s' "$(date +%Y-%m-%d)" ;;
    '{RATIO}')                       printf '0.5' ;;
    '{vocabulary.'*)                 printf '%s' "$(printf '%s' "$1" | sed 's/^{vocabulary\.//; s/}$//')" ;;
    *)                               return 1 ;;
  esac
  return 0
}

# --- extract every fence ----------------------------------------------------
# An optional argument scopes the run to ONE SKILL.md, which turns a five-minute
# sweep into a twenty-second one. That is what makes the non-vacuity proofs in
# the plan practical: each mutation is checked against the file it was planted
# in, under both shells, instead of against the whole scan set.
TARGET="${1:-}"
if [ -n "$TARGET" ]; then
  [ -f "$ROOT/$TARGET" ] || { printf 'harness: no such file: %s\n' "$TARGET" >&2; exit 1; }
  FILES="$TARGET"
else
  # reference/skill-authoring.md is scanned too: its ```bash examples are what an
  # author copies, so an example that cannot pass H/N/U/S is a defect being taught.
  # Counter-examples in that document live in ```text and are invisible here, which
  # is the only reason it can show a wrong pattern at all.
  FILES=$(cd "$ROOT" && { find skill-sources skills -name SKILL.md
                          find reference -name skill-authoring.md; } | sort)
fi
printf '%s\n' "$FILES" | while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  slug=$(printf '%s' "$rel" | sed 's|/SKILL\.md$||; s|/|--|g')
  awk -v dir="$WORK/fences" -v slug="$slug" '
    FNR==1 { n=0; inf=0 }
    /^```bash[[:space:]]*$/ && !inf { inf=1; n++; f=sprintf("%s/%s__f%02d.raw", dir, slug, n); printf "" > f; next }
    /^```[[:space:]]*$/ && inf { inf=0; close(f); next }
    inf { print $0 >> f }
  ' "$ROOT/$rel"
done

FENCE_FILES=$(find "$WORK/fences" -name '*.raw' | sort)
[ -n "$FENCE_FILES" ] || { echo "harness: extracted no fences — cannot conclude anything" >&2; exit 1; }

# --- discover placeholders and fail loudly on an unmapped one ---------------
# The $-preceding test keeps `${VAR}` out of the token set; only a bare `{tok}`
# is a template placeholder.
TOKENS=$(awk '{
  line=$0
  while (match(line, /\{[A-Za-z_][A-Za-z_.:-]*\}/)) {
    pre = (RSTART > 1) ? substr(line, RSTART-1, 1) : ""
    if (pre != "$") print substr(line, RSTART, RLENGTH)
    line = substr(line, RSTART+RLENGTH)
  }
}' $(printf '%s\n' "$FENCE_FILES" | tr '\n' ' ') | sort -u)

MAPFILE="$WORK/map.txt"; : > "$MAPFILE"
unmapped=""
printf '%s\n' "$TOKENS" | while IFS= read -r tok; do
  [ -n "$tok" ] || continue
  if val=$(map_value "$tok"); then
    printf '%s\t%s\n' "$tok" "$val" >> "$MAPFILE"
  else
    printf '%s\n' "$tok" >> "$WORK/unmapped.txt"
  fi
done
if [ -s "$WORK/unmapped.txt" ] 2>/dev/null; then
  echo "harness: unmapped placeholder(s) — add a value to map_value(), do NOT skip the fence:" >&2
  sed 's/^/  /' "$WORK/unmapped.txt" >&2
  exit 1
fi
unset unmapped

# --- run one fence under one condition --------------------------------------
# The status is captured from a DIRECT invocation, never from a pipeline: a
# pipeline yields its LAST stage's status, and that mechanism alone produced six
# defects on this branch. PIPESTATUS is bash-only and reads empty under zsh, so
# it is not the fix either.
#
# stdin is /dev/null so a fence containing a bare `read` cannot hang the gate.
#
# WHY THERE IS A TIMEOUT AT ALL, AND WHY IT IS NOT `timeout(1)`:
# skill-sources/reflect fence 2 used to spin on `while ! mkdir "$LOCKDIR"; do
# sleep 2; done`, which never terminated when the lock's PARENT directory was
# absent. Measured: the first run of this harness hung there indefinitely. That
# specific spin is now bounded at 60s, so the timeout below is no longer aimed
# at a known hang — it is the general guard that keeps ANY future one
# reportable, which is why it stays. A gate whose
# own failure mode is "hang until the CI job is killed at six hours" is the
# loudest possible instance of the silence this branch exists to remove, so a
# stuck fence must come back as a reportable status instead. `timeout(1)` is GNU
# coreutils — present on the CI image, absent from a stock macOS — so the wait
# is built from a status sentinel and a polled deadline instead.
FENCE_TIMEOUT=20                    # seconds; the fixture is tiny
RCF="$WORK/fence.rc"
PIDF="$WORK/fence.pid"
run_fence() {                       # run_fence <script> <vault> <outfile>
  rm -f "$RCF" "$PIDF"
  ( cd "$2" || exit 125
    # ARGUMENTS is the invocation argument a user-invocable skill is called with.
    # The fixture models a healthy VAULT; without this it did not model a healthy
    # INVOCATION, so every fence that establishes its target from $ARGUMENTS (see
    # skill-sources/seed) failed assertion H for the one reason H cannot forgive —
    # exiting non-zero with a message on stderr — while being entirely correct.
    # Pointed at a file that really exists in the full fixture, and whose path
    # contains the inbox name, so seed's archive-and-move branch is exercised
    # rather than skipped. The empty-$ARGUMENTS path is deliberately NOT tested
    # here; it is verified directly (see the plan's Task 3 notes).
    CLAUDE_PROJECT_DIR="$2" ARGUMENTS="inbox/raw-capture.md" \
      "$SELF" "$1" > "$3" 2> "$3.err" < /dev/null &
    ip=$!; printf '%s\n' "$ip" > "$PIDF"; wait "$ip"; printf '%s\n' "$?" > "$RCF" ) &
  outer=$!
  ticks=0
  while [ ! -f "$RCF" ]; do
    if [ "$ticks" -ge $((FENCE_TIMEOUT * 10)) ]; then
      [ -f "$PIDF" ] && kill -9 "$(cat "$PIDF")" 2>/dev/null
      kill -9 "$outer" 2>/dev/null
      wait "$outer" 2>/dev/null
      return 124
    fi
    sleep 0.1
    ticks=$((ticks+1))
  done
  wait "$outer" 2>/dev/null
  rc=$(cat "$RCF")
  return "${rc:-125}"
}

has_digit() {                       # has_digit <file>
  case "$(cat "$1")" in *[0-9]*) return 0 ;; *) return 1 ;; esac
}

# Digits from the TRAILER only — the variables the fence computed — as opposed
# to digits anywhere on stdout. The distinction is load-bearing and was measured:
# skill-sources/reflect fence 4 is `grep -c … a-moc.md`, which prints `0` and
# exits 1 when the file holds no matching lines. That 0 is the correct answer,
# not a number the fence could not compute, so judging raw stdout reports a
# defect against working code. A number the fence assigned to a variable and
# then failed on is a different thing, and that is what this reads.
trailer_digit() {                   # trailer_digit <file>
  case "$(sed -n '/^___FENCE_TRAILER___$/,$p' "$1")" in *[0-9]*) return 0 ;; *) return 1 ;; esac
}

# THE SCOPE PREFIX IS HONOURED IN BOTH DIRECTIONS, OR THE TWO DISAGREE.
# `ZSH ONLY:` / `BASH ONLY:` marks an entry that applies in one shell only. The
# staleness check already honoured it — a fence that legitimately passes in the
# other shell is not a rotten line. Absorption did NOT, so a `ZSH ONLY:` entry
# silently swallowed a *bash* failure on the same fence. Measured, not argued: a
# fabricated `.probe-skill f01~H~ZSH ONLY:` entry absorbed a fence that exited 1
# writing to stderr, under bash, and the gate printed PASS. One predicate, two
# call sites, agreeing by construction rather than by review — re-deriving the
# condition at the second site is how the two came apart in the first place.
in_scope() { # in_scope <reason> — does this entry apply in the shell we are in?
  case "$1" in
    'ZSH ONLY:'*)  [ "$SELF" = zsh ]  ; return ;;
    'BASH ONLY:'*) [ "$SELF" = bash ] ; return ;;
  esac
  # Near-misses are rejected by validate_scope_prefixes at startup, NOT here --
  # in_scope runs inside `while read` pipelines, so an `exit` here would kill the
  # subshell and leave the gate exiting 0 with a loud message and a green tick.
  # That was the first version of this fix and it is the very defect class the
  # gate exists to catch. Validation belongs at the boundary, once, at top level.
  return 0
}

# Reject allowlist reasons that LOOK like a scope marker but are not one of the
# two canonical spellings. Runs once, at top level, before any subshell -- so
# `exit` actually terminates the gate.
#
# The separator class is bounded to [ _-] so ONLY must follow the shell name
# immediately; a legitimate unscoped reason like "zsh aborts the command on a
# non-matching glob" must NOT trip this.
validate_scope_prefixes() {
  printf '%s\n' "$KNOWN_OPEN" | while IFS='~' read -r _l _a r; do
    [ -n "${r:-}" ] || continue
    case "$r" in
      'ZSH ONLY:'*|'BASH ONLY:'*) continue ;;
      [Zz][Ss][Hh][\ _-]*[Oo][Nn][Ll][Yy]*|[Bb][Aa][Ss][Hh][\ _-]*[Oo][Nn][Ll][Yy]*)
        printf 'HARNESS ERROR: allowlist reason opens with an unrecognised scope prefix:\n' >&2
        printf '  %s\n' "$r" >&2
        printf '  Canonical spellings are exactly "ZSH ONLY:" and "BASH ONLY:" -- uppercase,\n' >&2
        printf '  single space, trailing colon. A near-miss silently widens the entry to EVERY\n' >&2
        printf '  shell and absorbs the failures scoping exists to block.\n' >&2
        printf 'BADPREFIX\n' ;;
    esac
  done | grep -q BADPREFIX && exit 2
  return 0
}
validate_scope_prefixes

# judge <letter> <label> <message> [detail-file]
# Routes one failing assertion to either the KNOWN list or the blocking list.
# Returns 0 when the site is a listed known-open defect, 1 when it blocks.
judge() {
  reason=$(table_reason "$KNOWN_OPEN" "$2" "$1")
  if [ -n "$reason" ] && in_scope "$reason"; then
    known=$((known+1))
    printf '%s~%s\n' "$2" "$1" >> "$HIT_LOG"
    printf '  %s %s — %s\n' "$1" "$2" "$reason" >> "$KNOWN_LOG"
    # THE MEASURED FAILURE, NOT ONLY THE STATED REASON. Absorption still keys on
    # (label, letter) within a shell, so a listed fence that starts failing for a
    # DIFFERENT reason in its own shell is still absorbed. Printing what actually
    # happened beside what the entry claims makes that visible instead of silent:
    # the two lines disagreeing is the signal. Keying absorption on the message
    # itself was considered and rejected — it would couple every entry to this
    # gate's wording, so rewording a message would turn all entries stale, which
    # is a new trap inside the mechanism built to drain them.
    printf '    measured: %s\n' "$3" >> "$KNOWN_LOG"
    return 0
  fi
  printf '%s %s — %s\n' "$1" "$2" "$3" >> "$FAIL_LOG"
  if [ -n "${4:-}" ] && [ -s "$4" ]; then sed 's/^/      /' "$4" | head -3 >> "$FAIL_LOG"; fi
  return 1
}

echo "=== Fence isolation gate ($SELF) ==="

printf '%s\n' "$FENCE_FILES" | while IFS= read -r raw; do
  [ -n "$raw" ] || continue
  printf '%s\n' "$raw" >> "$WORK/seen.txt"
done
fences=$(wc -l < "$WORK/seen.txt" | tr -d ' ')

for raw in $(printf '%s\n' "$FENCE_FILES"); do
  base=$(basename "$raw" .raw)
  label=$(printf '%s' "$base" | sed 's|--|/|g; s|__f| f|')

  # substitution — same $-preceding test as discovery, so `${VAR}` is untouched
  body="$WORK/fences/$base.body"
  awk -v mapfile="$MAPFILE" '
    BEGIN { while ((getline ln < mapfile) > 0) { i=index(ln,"\t"); m[substr(ln,1,i-1)]=substr(ln,i+1) } }
    {
      out=""; line=$0
      while (match(line, /\{[A-Za-z_][A-Za-z_.:-]*\}/)) {
        pre = (RSTART > 1) ? substr(line, RSTART-1, 1) : ""
        tok = substr(line, RSTART, RLENGTH)
        out = out substr(line, 1, RSTART-1)
        out = out ((pre != "$" && tok in m) ? m[tok] : tok)
        line = substr(line, RSTART+RLENGTH)
      }
      print out line
    }' "$raw" > "$body"
  # Bracket-form author metavariables. Enumerated rather than pattern-matched:
  # a pattern loose enough to catch `[moc-name]` also catches a shell character
  # class, and rewriting one of those would corrupt working code. Only the forms
  # that sit in a FILE PATH are listed — those are the ones that make a fence
  # fail on a name that was never meant to be literal. `[[note]]`-style wiki
  # links and YAML list values are deliberately left alone.
  sed -e 's/\[note name\]/alpha/g' -e 's/\[moc-name\]/delta-moc/g' \
      -e 's/\[basename\]/alpha/g'  -e 's/\[domain-folder\]/notes/g' \
      -e 's/\[domain-inbox\]/inbox/g' "$body" > "$body.subst" && mv "$body.subst" "$body"

  # SKIP RULE — the only one. A fence with no command line has nothing to
  # execute, so running it proves nothing. Stated so a reader can check it, and
  # PRINTED below: a silently skipped fence is the exact defect class this gate
  # exists to catch. A fence is NEVER skipped for failing.
  # SKIP RULES — there are exactly two, both stated so a reader can check them,
  # both PRINTED below, and neither of them is "it failed". A silently skipped
  # fence is the same defect class this gate exists to catch.
  #   1. no command line: nothing to execute, so running it proves nothing.
  #   2. not a syntactically complete program: the fence is a FRAGMENT (it opens
  #      mid-construct, e.g. begins after an `if`). The shell rejects it before
  #      running a single command, so it can carry no cross-fence read to find.
  #      Checked with the runner's OWN shell, so a fence valid under one shell
  #      and not the other is skipped only where it truly cannot parse.
  #   3. listed in the ILLUSTRATIVE table above, by exact label, with a reason.
  printf '%s\n' "$label" >> "$SEEN_LABELS"
  ill=$(table_reason "$ILLUSTRATIVE" "$label")
  if [ -n "$ill" ]; then
    skipped=$((skipped+1))
    printf '  %s — %s\n' "$label" "$ill" >> "$SKIP_LOG"
    continue
  fi
  cmdlines=$(sed 's/^[[:space:]]*//' "$body" | /usr/bin/grep -c -v -e '^#' -e '^$')
  if [ "${cmdlines:-0}" -eq 0 ]; then
    skipped=$((skipped+1))
    printf '  %s — no command lines (comments and blanks only)\n' "$label" >> "$SKIP_LOG"
    continue
  fi
  if ! "$SELF" -n "$body" 2>/dev/null; then
    skipped=$((skipped+1))
    printf '  %s — not a complete program (%s -n rejects it; fenced fragment)\n' "$label" "$SELF" >> "$SKIP_LOG"
    continue
  fi
  run=$((run+1))

  # TRAILER — why stdout is not the fence's raw stdout.
  # The fences that produced the historical plausible-number defects ASSIGN
  # (LINK_COUNT=, NOTE_COUNT=, TOTAL_CONTENT=) and print nothing; errors go to
  # stderr. A digit test over raw stdout would therefore be vacuous on exactly
  # the fences it exists to judge. The trailer dumps every variable the fence
  # assigns, so a computed-from-nothing 0 becomes visible.
  # `${NAME-}` (not `$NAME`) so the dump itself cannot abort under `set -u`.
  # The fence's OWN status is captured before the trailer and re-raised after
  # it, so printf cannot mask a non-zero exit. A fence that exits early never
  # reaches the trailer — no digits, which is the correct reading.
  vars=$(/usr/bin/grep -o -E '^[[:space:]]*[A-Za-z_][A-Za-z_0-9]*=' "$body" \
         | tr -d ' \t=' | sort -u)
  script="$WORK/fences/$base.sh"
  { cat "$body"
    echo '__FENCE_RC=$?'
    echo 'printf "%s\n" "___FENCE_TRAILER___"'
    printf '%s\n' "$vars" | while IFS= read -r v; do
      [ -n "$v" ] && printf 'printf "%%s\\n" "${%s-}"\n' "$v"
    done
    echo 'exit $__FENCE_RC'
  } > "$script"

  setu="$WORK/fences/$base.setu.sh"
  { echo 'set -u'; cat "$script"; } > "$setu"

  # --- assertion H: healthy fixture ------------------------------------------
  # FAIL when the fence exits non-zero AND it timed out, wrote to stderr, or
  # carried a computed number out with it. This catches the LOUD half of the
  # defect class: a guard firing on an empty `$NOTES_DIR`, a 127 from a function
  # that was never sourced, a syntax error.
  #
  # WHY NOT SIMPLY "rc must be 0" — MEASURED, not assumed. Five fences in
  # skills/health are boundary-violation DETECTORS whose last command is an `rg`
  # that must find nothing in a healthy vault. rc 1 with a silent stderr is the
  # universal "search found no match" signature, and a fixture rigged to make
  # those match would no longer be a healthy vault.
  #
  # KNOWN BLIND SPOT, and the reason assertion U exists: a fence ending in
  # `… 2>/dev/null` has hidden its own stderr, so its rc 1 is indistinguishable
  # here from a clean no-match. skill-sources/graph fences 4 and 5 are exactly
  # that shape and H cannot see them. U can.
  build_fixture "$VAULT_FULL" full || { echo "harness: fixture build failed" >&2; exit 1; }
  run_fence "$script" "$VAULT_FULL" "$WORK/out/$base.full"
  rc_full=$?
  if [ "$rc_full" -ne 0 ]; then
    why=""
    # A timed-out fence is ALWAYS a failure. It exits with a silent stderr and
    # no output, which is precisely the shape the clause below forgives, so it
    # must be named first or a hang would read as a clean no-match.
    [ "$rc_full" -eq 124 ] && why="timed out after ${FENCE_TIMEOUT}s"
    [ -s "$WORK/out/$base.full.err" ] && why="${why:+$why and }wrote to stderr"
    if trailer_digit "$WORK/out/$base.full"; then
      why="${why:+$why and }reported a computed number"
    fi
    if [ -n "$why" ]; then
      judge H "$label" "exited $rc_full on a healthy fixture and $why" \
        "$WORK/out/$base.full.err" || h_fail=$((h_fail+1))
    fi
  fi

  # --- assertion N: missing notes directory, must not be a plausible number --
  # Scoped by a checkable predicate: applied only to fences that reference the
  # notes directory BEFORE substitution. Fences that never touch it (the system
  # metrics fence counts ops/ and self/) correctly fall outside.
  if /usr/bin/grep -q -e 'NOTES_DIR' -e '{vocabulary.notes}' "$raw"; then
    run_fence "$script" "$VAULT_HOLLOW" "$WORK/out/$base.hollow"
    rc_hollow=$?
    if [ "$rc_hollow" -eq 0 ] && has_digit "$WORK/out/$base.hollow"; then
      judge N "$label" "exited 0 AND emitted digits with no notes directory" \
        "$WORK/out/$base.hollow" || n_fail=$((n_fail+1))
    fi
  fi

  # --- assertion U: no fence may read a variable it did not define ----------
  # THE precise detector for this gate's defect class, and the reason assertion
  # H alone is not enough. Measured: skill-sources/graph fences 4 and 5 read
  # `$NOTES_DIR` from a fence three sections earlier, and both end in
  # `… 2>/dev/null`, so H sees rc 1 with a silent stderr — indistinguishable
  # from a search that found nothing. Under `set -u` the shell itself reports
  # the unbound name, and it does so BEFORE the command's own redirection
  # applies. Verified in both shells:
  #   bash -c 'set -u; find "$U" -type f 2>/dev/null'  → `U: unbound variable`
  #   zsh  -c 'set -u; find "$U" -type f 2>/dev/null'  → `U: parameter not set`
  #
  # The assertion keys on that MESSAGE, not on the exit status. A bare non-zero
  # status under `set -u` conflates two different things: five detector fences
  # in skills/health exit 1 because their `rg` found nothing, with or without
  # `set -u`, and counting those would have made this look like a
  # false-positive generator (16 of 72) when the real signal is far narrower.
  build_fixture "$VAULT_FULL" full || { echo "harness: fixture build failed" >&2; exit 1; }
  run_fence "$setu" "$VAULT_FULL" "$WORK/out/$base.setu"
  rc_setu=$?
  [ "$rc_setu" -ne 0 ] && printf '  %s — rc %s\n' "$label" "$rc_setu" >> "$SETU_LOG"
  if /usr/bin/grep -q -e 'unbound variable' -e 'parameter not set' "$WORK/out/$base.setu.err" 2>/dev/null; then
    uv=$(/usr/bin/grep -o -E '[A-Za-z_][A-Za-z_0-9]*: (unbound variable|parameter not set)' \
           "$WORK/out/$base.setu.err" | sed 's/:.*//' | sort -u | tr '\n' ' ')
    judge U "$label" "reads ${uv}— defined in no fence of this file" \
      "" || setu_fail=$((setu_fail+1))
  fi
done

# --- the allowlist is checked in BOTH directions ----------------------------
# A listed site that no longer fails, or no longer exists, is a stale entry, and
# a stale entry is a permanent silence — the same failure mode this gate exists
# to remove. So it blocks, with the fix spelled out.
# Only on a full sweep: under a scoped run every label from the other 25 files is
# legitimately absent, and reporting those as stale would bury the real ones.
[ -n "$TARGET" ] && KNOWN_OPEN="" && ILLUSTRATIVE=""
printf '%s\n%s\n' "$KNOWN_OPEN" "$ILLUSTRATIVE" | while IFS='~' read -r l a r; do
  [ -n "$l" ] || continue
  if ! /usr/bin/grep -qxF "$l" "$SEEN_LABELS"; then
    printf 'STALE %s — listed in a table but no such fence exists; delete the line\n' "$l" >> "$WORK/stale.txt"
    continue
  fi
  in_scope "$r" || continue
  case "$a" in
    U|N|H)
      /usr/bin/grep -qxF "$l~$a" "$HIT_LOG" || \
        printf 'STALE %s %s — listed as known-open but it PASSES now; delete the line\n' "$a" "$l" >> "$WORK/stale.txt" ;;
  esac
done
[ -f "$WORK/stale.txt" ] && stale=$(/usr/bin/grep -c . "$WORK/stale.txt")

printf 'files=%s fences=%s run=%s skipped=%s known-open=%s\n' \
  "$(printf '%s\n' "$FILES" | /usr/bin/grep -c .)" "$fences" "$run" "$skipped" "$known"

echo
echo "SKIPPED (rules: no command line; not a complete program; listed illustrative):"
if [ -s "$SKIP_LOG" ]; then cat "$SKIP_LOG"; else echo "  (none)"; fi

echo
echo "KNOWN-OPEN (real defects this gate found; listed, not blocking — see the table in this file):"
if [ -s "$KNOWN_LOG" ]; then cat "$KNOWN_LOG"; else echo "  (none)"; fi

echo
printf 'diagnostic — fences exiting non-zero under set -u for ANY reason: %s of %s\n' \
  "$(/usr/bin/grep -c . "$SETU_LOG" 2>/dev/null || echo 0)" "$run"
echo "  (most are detector fences whose rg legitimately finds nothing; assertion U"
echo "   keys on the unbound-variable MESSAGE instead, not on this status)"

echo
printf 'H (healthy: no failure with stderr/digits): %s failing\n' "$h_fail"
printf 'N (no notes dir: never rc 0 with digits):   %s failing\n' "$n_fail"
printf 'U (set -u: no read of an undefined var):    %s failing\n' "$setu_fail"
printf 'S (no stale entry in either table):        %s failing\n' "$stale"
printf 'F (frontmatter parser, three ways 2/1/4):   %s failing\n' "$f_fail"
printf 'M (upgrade: resolve+compare called for real):%s failing\n' "$m_fail"
if [ -s "$FAIL_LOG" ]; then echo; echo "FAILURES:"; cat "$FAIL_LOG"; fi
if [ -s "$WORK/stale.txt" ]; then echo; echo "STALE TABLE ENTRIES:"; cat "$WORK/stale.txt"; fi

echo
if [ "$h_fail" -eq 0 ] && [ "$n_fail" -eq 0 ] && [ "$setu_fail" -eq 0 ] && [ "$stale" -eq 0 ] \
   && [ "$f_fail" -eq 0 ] && [ "$m_fail" -eq 0 ]; then
  echo "FENCE ISOLATION: PASS"; exit 0
else
  echo "FENCE ISOLATION: FAIL"; exit 1
fi
