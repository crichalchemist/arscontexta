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
# A third outcome, distinct from both. "This tree does not claim the property"
# is not "this tree has the property" — reporting it as PASS is exactly the
# vacuity these checks exist to prevent. skip() never touches `fail`, and never
# prints PASS, so a reader can tell a verified check from an inapplicable one.
skip() { printf '  SKIP %s\n' "$1"; }

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
if hits=$(scan_or_die "grep -P scan" -rn --include='*.md' --include='*.sh' --include='*.template' -E '(^|[^a-zA-Z_-])(grep|egrep|fgrep|zgrep) +[^|]*(-[a-zA-Z]*P|--perl-regexp)' \
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
raw_a=$(scan_or_die "link capture scan (negated class)" -rn --include='*.md' --include='*.sh' --include='*.template' -F '\[\[' "${SCAN[@]}")
scan_a_ok=$?
# Part B: greedy/lazy dot-or-plus quantifiers between \[\[ and \]\] — vector 4
# evasion. This matched ONLY the literal `.*?` spelling; verified against a
# planted fixture, `\[\[.*\]\]`, `\[\[.+?\]\]` and `\[\[(.+)\]\]` all passed.
# Part A cannot cover them either: it keys on `[^` being PRESENT, and a dot
# quantifier contains no negated class at all. `\.[*+]\??` spans greedy and
# lazy forms of both quantifiers, with `.*` on each side so a capture group or
# any other wrapping around the quantifier does not evade the match.
raw_b=$(scan_or_die "link capture scan (greedy quantifiers)" -rn -E --include='*.md' --include='*.sh' --include='*.template' \
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
if hits=$(scan_or_die "rg PCRE" -rn --include='*.md' --include='*.sh' --include='*.template' \
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

# KNOWN BLIND SPOT (matching direction), NARROWED BY CHECK 6:
# This guard checks the EXTRACTION direction — it verifies that captured links
# terminate at | and #. The MATCHING direction is whether a search FOR a link
# handles [[slug|alias]] and [[slug#heading]]. Check 6 below now closes the
# sharpest edge of that gap, the one where a note name is interpolated into the
# pattern and every character of it becomes a regex. What remains open is the
# alias/heading half: a matcher spelled with a literal name still misses its own
# aliased and anchored forms, and catching that would require evaluating a
# template recursively, since it means parsing the link format and the file
# search scope at the same time.
#
# THE ENUMERATION THAT USED TO LIVE HERE IS GONE, DELIBERATELY.
# It listed the sites by file with a per-file count, plus a command to re-derive
# them, plus a note that the count "has been wrong twice" — 13, then 9, both
# undercounts. It was wrong a third time when check 6 was built: it claimed 11
# sites across five files when the tree held 6, because it still named
# skill-sources/graph (4) and skill-sources/stats (2) after both were converted
# to the shared library on fix/spec-f-divergence-drain, and it never listed
# session-orient.sh.template at all. That third error is the informative one. It
# is the first OVERCOUNT, so unlike its predecessors it sends a reader to two
# files where the defect no longer exists, where they cannot tell a rotted
# comment from a mis-run command. And it rotted on a MERGE, not on an edit —
# nothing in this file changed when that branch landed, so no diff existed for
# review to catch. Care cannot close that; only a check that counts can.
# Check 6's allowlist is that check, and it fails in both directions.

echo "4. platforms/shared/skill-blocks/ is frozen (content unchanged)"
# WHY A CONTENT MANIFEST AND NOT `git diff --name-only`:
# The spec called for a git-diff rule. Measured before implementing: on the branch
# that introduced this check, `git diff --name-only main...HEAD -- <dir>` already
# reported three files — reflect.md, reweave.md, seed.md — because the inherited
# Spec C commits legitimately touched them. A diff-range gate is therefore born
# failing, and the only ways out are to pick a baseline that drifts (main moves) or
# to except the very files most likely to be edited again. Hashing the content
# answers "is it what we froze?" directly, with no baseline, no branch range, and
# the same verdict in CI and a dirty working tree.
#
# WHY cksum: POSIX-mandated, so it is present wherever this runs. sha256sum is
# absent on macOS and shasum is absent on minimal CI images; a per-machine tool
# choice would make the digests themselves machine-dependent, turning a portability
# guard into a portability defect. This detects accidental edits, not forgery.
FROZEN_DIR="$ROOT/platforms/shared/skill-blocks"
FROZEN_MANIFEST="$ROOT/reference/skill-blocks.frozen"
# WHY VIOLATIONS ACCUMULATE IN A VARIABLE AND NOT A TEMP FILE:
# This check used to write findings to "$ROOT/.frozen-check.$$" and decide with
# [ -s ]. Nothing verified the write succeeded and `set -e` is not in effect, so on
# a read-only $ROOT every `printf >>` failed to stderr, the file stayed empty, and
# the check reported PASS on a modified template — rc 0, plausible line, no error
# on stdout. The house defect, inside the guard written to prevent it. A read-only
# checkout or mount is enough to trigger it, and this repo lives under /Volumes.
# A read-only check has no business taking a write dependency on the tree it reads.
frozen_bad=""
# WHY THE MANIFEST IS THE KEY AND NOT THE DIRECTORY:
# The first version of this check called red() whenever the frozen directory was
# absent. That broke guard-failure.test.sh (19/19 -> 16/3) and the three broken
# assertions were the ones proving this guard is not vacuous — "a clean tree must
# still pass, or the assertions above prove nothing." Its mkroot() builds the nine
# shipped directories to test the FAILURE path; it has no reason to carry this
# repo's frozen content, and demanding it does turns check-portability.sh into a
# guard that fails on every tree but one. Loud failure on a legitimately clean
# tree — the house defect with its sign flipped.
#
# The manifest is the tree's ASSERTION that a freeze exists, so it is the right
# discriminator. Absent manifest AND absent directory means nothing here claims to
# be frozen: skip, and say so. Either one alone is a real failure, including the
# dangerous case the README names — deleting the manifest to let an edit through.
#
# The CLAUDE.md clause closes a deliberate escape: renaming the frozen directory
# and deleting the manifest in one commit would otherwise skip, leaving the
# templates live-editable with CI green. A tree with no manifest, no frozen
# directory AND no CLAUDE.md is not an arscontexta root; a tree with CLAUDE.md
# that dropped both is an arscontexta root that dropped its freeze.
if [ ! -f "$FROZEN_MANIFEST" ] && [ ! -d "$FROZEN_DIR" ] && [ ! -f "$ROOT/CLAUDE.md" ]; then
  skip "no frozen manifest and no frozen directory — nothing here claims a freeze"
elif [ ! -f "$FROZEN_MANIFEST" ] && [ ! -d "$FROZEN_DIR" ]; then
  red "manifest and frozen directory are both gone from a tree that has CLAUDE.md — the freeze was removed, not absent"
elif [ ! -f "$FROZEN_MANIFEST" ]; then
  red "frozen manifest missing: $FROZEN_MANIFEST — the directory is here with nothing pinning it"
elif [ ! -d "$FROZEN_DIR" ]; then
  red "frozen directory missing: $FROZEN_DIR — the manifest pins files that are gone"
else
  # Modified or deleted: every manifest entry must still hash to its recorded value.
  # The `|| [ -n ... ]` continuation matters: `read` returns non-zero at EOF, so a
  # manifest whose final line lacks a newline would silently skip its last entry —
  # un-freezing exactly one file, without a word.
  # ONE PARSE, AND MALFORMED LINES ARE A FAILURE, NOT A SKIP:
  # This loop used to read `want name` and `continue` when name was empty, while a
  # separate `cut -d' ' -f2-` built the untracked list. The two disagreed. A line
  # carrying only a filename parsed as want=<filename>, name="" and was skipped by
  # the hash check — and `cut` returned the line unchanged when the delimiter was
  # absent, so the name appeared in the untracked list too and passed that test.
  # The file was neither hashed nor reported: rc 0, plausible count, no error. The
  # guard's own regeneration snippet emits exactly that line when cksum cannot read
  # a file. Both lists now come from this one parse, and a line that does not look
  # like "<digits>-<digits> <name>" fails loudly instead of vanishing.
  pinned=0
  pinned_names=""
  while IFS= read -r line || [ -n "${line:-}" ]; do
    [ -n "${line:-}" ] || continue
    case "$line" in
      [0-9]*-[0-9]*\ ?*) ;;
      *) frozen_bad="$frozen_bad  MALFORMED MANIFEST LINE: $line
"; continue ;;
    esac
    want=${line%% *}
    name=${line#* }
    pinned=$((pinned + 1))
    pinned_names="$pinned_names$name
"
    if [ ! -f "$FROZEN_DIR/$name" ]; then
      frozen_bad="$frozen_bad  DELETED $name
"
      continue
    fi
    got=$(cksum < "$FROZEN_DIR/$name" | tr -s ' ' | tr ' ' '-')
    [ "$got" = "$want" ] || frozen_bad="$frozen_bad  MODIFIED $name
"
  done < "$FROZEN_MANIFEST"
  # Added: anything here the manifest does not pin is unfrozen and invisible above.
  # `find -type f` rather than a top-level *.md glob, because the glob let three
  # things through — sub/evil.md, .hidden.md and newthing.txt each passed while the
  # prose claimed any edit was rejected. A contributor porting guards into
  # skill-blocks/sub/ is the exact scenario this freeze exists to stop.
  # README.md is the one file this directory is allowed to grow.
  # Captured with $( ), not redirected to a file: `find | while` runs the body in a
  # subshell, so appending to frozen_bad inside it would be discarded — and routing
  # around that with a temp file is what C1 was.
  #
  # -type l as well as -type f: a plain `-type f` excludes symlinks, so dropping a
  # symlink named reflect.md into this directory was invisible. Its two siblings in
  # that class, sub/*.md and .hidden.md, each already have an assertion.
  untracked=$(find "$FROZEN_DIR" \( -type f -o -type l \) | while IFS= read -r f; do
    rel=${f#"$FROZEN_DIR"/}
    [ "$rel" = "README.md" ] && continue
    # -x, not a substring match: an unanchored search would miss a new file whose
    # name is a proper prefix of a pinned one.
    printf '%s\n' "$pinned_names" | "$GREP" -qxF "$rel" || printf '  UNTRACKED %s\n' "$rel"
  done)
  if [ -n "$untracked" ]; then
    frozen_bad="$frozen_bad$untracked
"
  fi
  if [ -n "$frozen_bad" ]; then
    red "platforms/shared/skill-blocks/ is frozen — nothing generates from it:"
    printf '%s' "$frozen_bad" | sed 's/^/   /'
    # The manifest's digests were generated on one machine. If EVERY pinned file
    # reports MODIFIED, a differing cksum implementation is far likelier than that
    # many simultaneous edits — and without this line the two are indistinguishable.
    n_mod=$(printf '%s' "$frozen_bad" | "$GREP" -c 'MODIFIED' || true)
    if [ "$pinned" -gt 1 ] && [ "$n_mod" -eq "$pinned" ]; then
      echo "       NOTE: all $pinned pinned files report MODIFIED. Suspect a differing"
      echo "       cksum implementation on this machine before suspecting $pinned edits."
    fi
    echo "       Nothing reads this directory (skills/setup/SKILL.md:1285 generates"
    echo "       from skill-sources/). See platforms/shared/skill-blocks/README.md."
    echo "       Intending this? Regenerate the manifest and say why in the commit:"
    echo "         for f in platforms/shared/skill-blocks/*.md; do \\"
    echo "           [ \"\$(basename \"\$f\")\" = README.md ] && continue; \\"
    echo "           printf '%s %s\\n' \"\$(cksum < \"\$f\" | tr -s ' ' | tr ' ' -)\" \"\${f##*/}\"; \\"
    echo "         done | sort > reference/skill-blocks.frozen"
  else
    # Counted from the manifest, not written as a literal. A hardcoded "16" would
    # still read 16 after a template and its manifest line were deleted together —
    # a number that does not come from counting the thing it names is the defect
    # this repo keeps finding.
    ok "$pinned frozen templates unchanged"
  fi
fi

echo "5. AGENTS.md is a symlink to CLAUDE.md, not a copy of it"
# WHY A SYMLINK AND WHY THIS IS GATED: CLAUDE.md carries the traps, the invariants
# and the divergence list, and only one runtime reads that filename. AGENTS.md makes
# it visible to the others. A COPY would be a second configuration surface that
# cannot see the first — which is the defect this repo already carries once, in
# read_config.sh versus ops/config.yaml. One inode, two names, and drift is not
# unlikely but impossible.
#
# Keyed on .claude-plugin/plugin.json, not on CLAUDE.md: guard-failure.test.sh
# builds synthetic roots that legitimately have neither, and a check that fails on
# every tree but this one is how check 4 broke that suite once already.
if [ ! -f "$ROOT/.claude-plugin/plugin.json" ]; then
  skip "not the plugin root — no agent surface expected"
elif [ ! -e "$ROOT/AGENTS.md" ]; then
  red "AGENTS.md is missing — the agent-facing surface is Claude-only again"
elif [ ! -L "$ROOT/AGENTS.md" ]; then
  red "AGENTS.md is a regular file, not a symlink — a copy drifts from CLAUDE.md silently"
elif [ "$(readlink "$ROOT/AGENTS.md")" != "CLAUDE.md" ]; then
  red "AGENTS.md points at $(readlink "$ROOT/AGENTS.md"), not CLAUDE.md"
else
  ok "AGENTS.md -> CLAUDE.md"
fi

echo "6. Wiki-link matchers do not interpolate a note name into the pattern"
# THE PROPERTY: a shell variable expanded directly after `\[\[` — the `$` in
# `grep -rl "\[\[$title\]\]"`. Every character of the interpolated title is then a
# REGEX, so a note named `a.b` also matches `axb` and one named `c++` is a syntax
# error. Measured on an eight-note fixture when divergence 6 was closed: that
# spelling scored a note with 2 incoming links as 0, a fenced link as 1, and `a.b`
# as 2 when the truth was 1 — wrong in both directions at once, which is why the
# orphan total came out identical before and after the fix. A check comparing
# totals would have called that fix cosmetic.
#
# WHY THE PATTERN IS BARE AND CARRIES NO COMMAND PREFIX:
# The interpolation is the defect; which command consumes it is incidental. The
# blind-spot comment this check replaces re-derived its count with a pattern that
# required an `-l` flag, so it could not see `rg -q` — the spelling of the site in
# generators/features/maintenance.md, which that comment consequently never listed
# in three revisions. Requiring a command spelling is how the enumeration went stale.
#
# WHY EVERY SCAN IN THIS FILE NOW INCLUDES `*.template`:
# Until this check was written they included only *.md and *.sh, which match
# NEITHER session-orient.sh.template nor its three siblings — so the highest-
# blast-radius site in this class was invisible to every check here, and a
# `grep -P` dropped into a hook template would have shipped unreported. The
# platforms/claude-code adapter READS those templates during generation
# (generator.md:27), so a construct there can reach a derived vault's hook.
# All five scans were widened together, after measuring the four templates
# clean for checks 1-3 first, so the widening could not turn CI red on a
# pre-existing defect and mask which change caused what.
#
# KNOWN LIMITATION — THE PROPERTY IS KEYED ON THE ESCAPED SPELLING `\[\[$`.
# A matcher written with UNescaped brackets, `grep -rlF "[[$q]]"`, interpolates
# just as dangerously and is not flagged. So does a pattern assembled in two
# steps, `pat="[[$q]]"` then `grep -rl "$pat"`. Neither occurs in the tree today,
# and both were measured rather than assumed. Worth knowing that the unescaped
# form is not merely unflagged but is a second defect: without -F, `[[Target]]`
# is a BRE bracket expression, so it matches any line containing one of those
# letters followed by `]` — verified matching a fixture it has no business
# matching. Widen from these two edges rather than rediscovering them.
#
# THIS CHECK DOES NOT HONOUR `portability-exempt`, and the check-2 comment above
# says why that marker's scope is stated rather than assumed: an allowlist entry
# carries a reason and is reviewed, a marker carries nothing. Two exemption
# mechanisms for one check is how they drift, so this one has exactly one.
#
# ALLOWLIST — "<path> <count> <reason>". Bidirectional, on check 4's model: an
# unlisted hit FAILS, and an entry whose file is gone or whose count no longer
# matches is STALE and also fails. The list drains rather than rots.
#
# WHY <path> <count> AND NOT <path>:<line>:
# Line numbers drift on every edit — CLAUDE.md's divergence 12 table still says
# session-orient.sh.template:149 for a site now at :160, and the comment this
# replaces gave "no line numbers here" as a deliberate choice for the same reason.
# A bare path without a count would let skills/health quietly grow a fourth site
# behind its three.
INTERP_ALLOW="
skills/architect/SKILL.md 1 link counts in evolution advice; nothing acts on the number
skills/health/SKILL.md 3 orphan, incoming and MOC counts; report-only, no threshold reads them
platforms/claude-code/hooks/session-orient.sh.template 1 runs on EVERY SessionStart, where sourcing a library turns a missing file into a broken session rather than a wrong number
reference/testing-milestones.md 1 a test SPEC's own example; teaching the pattern is not shipping it
generators/features/maintenance.md 1 a recipe emitted into a generated vault's docs; a recipe cannot source a library the way a fence can, so converting it changes what generation emits
"
# ONE PREDICATE, CALLED BY BOTH HALVES.
# The fence gate shipped exactly this defect and CLAUDE.md records it: absorption
# keyed on (letter, label) and ignored the entry's shell scope while the staleness
# half honoured it, so a zsh-only entry swallowed a bash failure and the gate
# printed PASS. Re-deriving the condition at the second site is how they came apart.
# Both halves below ask this one question and neither computes its own answer.
#
# -F is load-bearing: the paths contain `.`, which as a regex matches any character,
# so `SKILL.md` would also count a hit in `SKILLxmd`. Divergence 13 records the same
# flag being load-bearing for the same reason.
interp_hits_in() {         # interp_hits_in <relative-path> -> hit count in that file
  printf '%s\n' "$INTERP_RAW" | "$GREP" -cF "$ROOT/$1:" || true
}
# The rel-path parse, extracted rather than written a third time. Two identical
# copies is where the fence gate's absorption/staleness split began, and this
# check's own header says re-deriving a condition at a second site is how they
# came apart. Writing that and then inlining the same parse twice more is the
# defect the comment warns about, committed inside the comment's own file.
interp_files_hit() {       # interp_files_hit -> sorted unique relative paths with hits
  printf '%s\n' "$INTERP_RAW" | while IFS= read -r line; do
    [ -n "$line" ] || continue
    rel=${line#"$ROOT"/}; printf '%s\n' "${rel%%:*}"
  done | LC_ALL=C sort -u
}
interp_allowed_for() {     # interp_allowed_for <relative-path> -> declared count, or empty
  printf '%s\n' "$INTERP_ALLOW" | while IFS= read -r e; do
    [ -n "$e" ] || continue
    [ "${e%% *}" = "$1" ] || continue
    e=${e#* }; printf '%s' "${e%% *}"
  done
}
if INTERP_RAW=$(scan_or_die "interpolated wiki-link matcher scan" -rn \
                --include='*.md' --include='*.sh' --include='*.template' \
                -E '\\\[\\\[\$' "${SCAN[@]}"); then
  INTERP_RAW=$(printf '%s\n' "$INTERP_RAW" | "$GREP" -Ev "$EXEMPT_PATHS")
  interp_paths=$(printf '%s\n' "$INTERP_ALLOW" | while IFS= read -r e; do
                   [ -n "$e" ] || continue; printf '%s\n' "${e%% *}"; done)
  # WHY `printf | while` AND NOT `for p in $interp_paths`:
  # An unquoted parameter expansion in a `for` list word-splits under bash and does
  # NOT under zsh, where it stays one string — the fork class this guard exists to
  # catch, and one this file already carries a header comment about for $SCAN.
  interp_present=$(printf '%s\n' "$interp_paths" | while IFS= read -r p; do
                     [ -n "$p" ] || continue; [ -e "$ROOT/$p" ] && printf 'x\n'
                   done | "$GREP" -c . || true)
  interp_total=$(printf '%s\n' "$INTERP_RAW" | "$GREP" -c . || true)
  # THE THREE-OUTCOME DISCRIMINATOR, and it is keyed on the TREE, not on this script.
  # The allowlist is inline, so it is never absent; the files are what a tree either
  # has or does not. guard-failure.test.sh's mkroot() builds the nine shipped
  # directories empty to exercise the failure path, and a check that red()s there
  # fails on every tree but this one — which is how check 4 took that suite from
  # 19/19 to 16/3, breaking precisely the assertions proving this guard is not
  # vacuous. A tree carrying none of these files and no hits claims nothing.
  if [ "$interp_present" -eq 0 ] && [ "$interp_total" -eq 0 ]; then
    skip "no allowlisted file present and no interpolated matcher found — nothing here claims this property"
  else
    interp_bad=$(interp_files_hit | while IFS= read -r f; do
                   [ -n "$f" ] || continue
                   want=$(interp_allowed_for "$f")
                   got=$(interp_hits_in "$f")
                   if [ -z "$want" ]; then
                     printf '  UNLISTED %s (%s site(s)) — a new interpolated matcher, or one moved here\n' "$f" "$got"
                   elif [ "$want" != "$got" ]; then
                     printf '  COUNT CHANGED %s — allowlist declares %s, tree has %s\n' "$f" "$want" "$got"
                   fi
                 done)
    # THE OTHER DIRECTION. Without it the list rots instead of draining: a site
    # fixed in another branch leaves its entry behind, and the next reader treats a
    # closed defect as open. This is not hypothetical — it is what this check found
    # on introduction, in the comment it replaces.
    interp_stale=$(printf '%s\n' "$interp_paths" | while IFS= read -r f; do
                     [ -n "$f" ] || continue
                     [ "$(interp_hits_in "$f")" = "0" ] || continue
                     if [ -e "$ROOT/$f" ]; then
                       printf '  STALE %s — allowlisted but no longer matches; the site was fixed, so drop the entry\n' "$f"
                     elif [ "$interp_present" -gt 0 ]; then
                       # GONE is only meaningful in a tree that carries SOME of these
                       # files. $ROOT is an argument — this guard is run against
                       # fixture trees and can be run against a generated vault, and
                       # neither has any reason to hold skills/architect/SKILL.md.
                       # Reporting every entry GONE there buries a real UNLISTED hit
                       # under five lines of noise about files that were never
                       # expected. Full strength is retained where it matters: on a
                       # tree carrying even one of them, a deletion still fails.
                       printf '  STALE %s — allowlisted but the file is gone; drop the entry\n' "$f"
                     fi
                   done)
    if [ -n "$interp_bad" ] || [ -n "$interp_stale" ]; then
      red "interpolated wiki-link matcher allowlist does not match the tree:"
      [ -n "$interp_bad" ] && printf '%s\n' "$interp_bad"
      [ -n "$interp_stale" ] && printf '%s\n' "$interp_stale"
      echo "    Interpolating a note name makes every character of it a regex."
      echo "    Prefer reference/lib/link-extraction.sh; allowlist only with a stated reason."
    else
      # COUNTED, NOT WRITTEN. Check 4's comment states the principle this repo keeps
      # re-learning: a number that does not come from counting the thing it names is
      # the defect. A literal here would survive an entry being deleted.
      # COUNT THE FILES THAT CONTRIBUTED HITS, not the allowlist's length. Those
      # are equal on every tree that reaches this branch, but they are different
      # QUANTITIES, and reporting one under the other's name is the mislabel this
      # repo has now fixed in four places (skills/help, session-orient.sh,
      # skills/health, and check 4's own $pinned).
      interp_files=$(interp_files_hit | "$GREP" -c . || true)
      ok "$interp_total interpolated matcher(s) across $interp_files allowlisted file(s), all accounted for"
    fi
  fi
else
  red "interpolated matcher scan could not run (see stderr) — cannot conclude anything"
fi

# ---------------------------------------------------------------------------
# CHECK 7 — hand-rolled frontmatter parsing outside reference/lib/frontmatter.sh
#
# Spec G item 23, deferred there ("a ban on inlining a library that does not
# exist yet mandates nothing") and unbuilt when fix/spec-f-divergence-drain
# merged. CLAUDE.md divergence 15 records both halves.
#
# READ THE LINK-LIBRARY BAN'S HISTORY BEFORE TRUSTING THIS ONE. CLAIMED bans are
# how this repo got here: CLAUDE.md's gate table asserted for months that check 4
# caught inlined link matchers, and link-extraction.sh's own header said the
# same. BOTH WERE FALSE — inlined matchers sat in five skill-sources fences
# through four gates and a 127 KB review, and the commit that removed them added
# a sixth.
#
# THIS CHECK ALREADY SHIPPED THAT FAILURE ONCE, WHICH IS WHY THE PATTERN LOOKS
# LIKE THIS. Its first version required an `-r/-L/-l/-c/-q` flag between the
# command and the pattern, so `rg '^status: open' notes/` — no flag, same
# spelling, same defect — was invisible. It reported 39 where the property has
# 74, and among the 35 it missed was generators/features/methodology-knowledge.md,
# which CLAUDE.md names BY LINE as an open instance of this very class. That is
# divergence 12's finding ("every search string tried so far has been narrower
# than the class") reproduced inside the commit that cites it. The flag is gone.
#
# THE PROPERTY: no code outside reference/lib/frontmatter.sh may select or count
# notes by a frontmatter field using a line-anchored match. `grep -rl '^type: moc'`
# is a hand-rolled list_notes_by_field, and it matches a `type: moc` line
# ANYWHERE in the body, including inside a fenced block — the reason the library
# exists.
#
# SCOPE IS DECLARED, because an undeclared scope is a second way to be narrower
# than the class. FM_SCAN below is the same directory set the rest of this file
# scans, with ONE deliberate exclusion: methodology/. That tree is 249 atomic
# research claims; its recipes are illustrative prose inside claims about
# cognition, nothing there composes into a vault or runs, and including it would
# add 87 sites that no conversion would ever touch. generators/features/*.md is
# the contrasting case and IS scanned — those recipes compose into a generated
# vault's CLAUDE.md verbatim.
#
# BORN RED AT 74 ACROSS 25 FILES AND 16 FIELDS, and that is the point rather
# than a defect. The plan's Step 1 says count the copies first: if any exist,
# this is a conversion and not a gate. Converting 74 sites is not this task;
# making them visible and un-growable is. A GREEN RUN THEREFORE MEANS "no NEW
# hand-rolled parse", NEVER "none exists".
#
# THREE DIFFERENT QUANTITIES: 74 LINES match, carrying 77 FIELD REFERENCES (some
# lines name two), across 16 DISTINCT NAMES. Spec G framed this ban as being
# about `status:` alone; the spread is `type` 24, `description` 14, `status` 11,
# `topics` 8, `mined`/`methodology`/`created` 3 each, `source`/`category` 2 each,
# then seven singletons — 9 named + 7 = 16.
#
# THE RE-DERIVE COMMAND MUST USE THIS CHECK'S OWN DETECTOR, and the first version
# of this comment did not. It matched a BARE `'^field:'` with no command prefix,
# which yields 75/78/17 — it picks up reference/test/threshold-namespace.test.sh,
# where `'^self_evolution:'` is an argument to a test helper rather than a
# pattern given to grep. So the published derivation disagreed with the gated 74
# sitting three lines above it, inside the comment written to stop precisely
# that. Keep the `(grep|rg)` prefix; it is what makes the numbers one measurement.
#
#   find skills skill-sources reference generators platforms presets hooks agents scripts \
#        \( -name '*.md' -o -name '*.sh' -o -name '*.template' \) | while IFS= read -r f; do
#     case "$f" in reference/lib/*|reference/check-portability.sh|\
#                  reference/test/guard-failure.test.sh|reference/test/fence-isolation.test.sh)
#       continue;; esac
#     sed 's/#.*$//' "$f" | /usr/bin/grep -oE "(grep|rg) [^|]*'\^[a-z_]+:"
#   done | /usr/bin/grep -oE "'\^[a-z_]+:" | tr -d "'^:" | sort | uniq -c | sort -rn
#
# KNOWN LIMITATIONS, stated because the previous version's limitations section
# implied a guarantee it did not deliver:
#   * DOUBLE-QUOTED or UNANCHORED equivalents are not flagged. Neither occurs in
#     the scanned scope today; measured, not assumed.
#   * A copied-out awk/sed frontmatter parser is not detected at all. None occurs.
#   * An inlined copy of reference/lib/link-extraction.sh is NOT covered by this
#     or any check. That remains convention; divergences 12 and 13 own it.
#   * `#` comments are stripped before matching, so a comment describing the old
#     spelling is not a hit. Measured: this suppresses 13 lines in this tree and
#     every one is such a comment. `sed` only deletes, so it cannot CREATE a hit.
#   * methodology/ is out of scope, above.
#
# EXEMPT BY STRUCTURE, not by allowlist, because these must CONTAIN the pattern
# to do their jobs: the library itself, this guard, and the two suites that plant
# it into fixtures. Check 2's header makes the same distinction.
#
# SPELLED AS A `case`, NOT A LIST IN A VARIABLE, and this is not style. The first
# version was `FM_EXEMPT="a b c"` iterated with `for _fe in $FM_EXEMPT`, which
# word-splits under bash and NOT under zsh: zsh ran one iteration with the whole
# string as the pattern, so only the first entry was exempt and
# reference/test/fence-isolation.test.sh reported UNLISTED. bash rc 0, zsh rc 1,
# fm_exempt_p identifies paths excluded from the hand-rolled frontmatter parsing scan.
fm_exempt_p() { # fm_exempt_p <relative-path> -> rc 0 when structurally exempt
  case "$1" in
    reference/lib/*)                        return 0 ;;  # the library itself
    reference/check-portability.sh)         return 0 ;;  # this guard states the pattern
    reference/test/guard-failure.test.sh)   return 0 ;;  # plants it into fixtures
    reference/test/fence-isolation.test.sh) return 0 ;;  # assertion F's naive-parser arm
  esac
  return 1
}

# ALLOWLIST — "<path> <count> <reason>", bidirectional on check 4's and check 6's
# model: an unlisted hit FAILS, and an entry whose file is gone or whose count no
# longer matches is STALE and also fails. Path and COUNT, never line numbers —
# lines drift on every edit, and a bare path would let a file quietly grow a
# fourth site behind three.
FM_ALLOW="
generators/features/graph-analysis.md 10 recipe emitted into a generated vault's docs; a recipe cannot source the library the way a fence can, so converting it changes what generation emits
generators/features/maintenance.md 1 recipe emitted into a generated vault's docs
generators/features/methodology-knowledge.md 2 recipe emitted into a generated vault's docs; CLAUDE.md names :31 by line as a known-open instance of this class
generators/features/schema.md 6 recipe emitted into a generated vault's docs
generators/features/semantic-search.md 6 recipe emitted into a generated vault's docs
platforms/shared/skill-blocks/remember.md 1 FROZEN tree; check 4 pins it against a cksum manifest, so this cannot be fixed in place
platforms/shared/skill-blocks/rethink.md 2 FROZEN tree; check 4 pins it against a cksum manifest
platforms/shared/skill-blocks/stats.md 1 FROZEN tree; check 4 pins it against a cksum manifest
platforms/claude-code/hooks/session-orient.sh.template 3 BLOCKED, not merely undone: the plugin's own session-orient.sh WAS converted on Spec F and this was not, so it is a live plugin/template split. Divergence 12 states the blocker for this exact file - it runs on EVERY SessionStart, where a missing library turns a wrong number into a broken session
reference/components.md 1 PROSE describing the spelling; not code, and this check has no fence awareness
reference/semantic-vs-keyword.md 1 PROSE describing the spelling
reference/skill-authoring.md 1 PROSE counter-example describing the naive spelling
reference/validate-kernel.sh 3 primitives 3, 5 and 6 count MOCs, descriptions and topics naively; the same file sources the library for C1, so this is a conversion backlog inside one file
skill-sources/graph/SKILL.md 8 conversion backlog
skill-sources/next/SKILL.md 1 conversion backlog
skill-sources/refactor/SKILL.md 1 conversion backlog
skill-sources/remember/SKILL.md 1 conversion backlog
skill-sources/seed/SKILL.md 1 conversion backlog
skill-sources/stats/SKILL.md 9 conversion backlog; the largest single concentration
skills/architect/SKILL.md 3 conversion backlog
skills/ask/SKILL.md 1 conversion backlog
skills/health/SKILL.md 6 conversion backlog
skills/reseed/SKILL.md 1 conversion backlog
skills/setup/SKILL.md 2 conversion backlog
skills/upgrade/SKILL.md 2 conversion backlog
"

# Comment-stripped per file. Keying on the literal string instead would count
# every comment that DESCRIBES the old spelling — Spec F's own conversion count
# was taken that way and was meaningless.
#
# NOT scan_or_die: sed's stderr is discarded, so an unreadable FILE yields 0 hits
# and is indistinguishable from a clean one. Recorded rather than fixed here; the
# fm_hits_in counts hand-rolled frontmatter parsing patterns in a repository-relative file. It outputs the number of matching lines after removing comments.
fm_hits_in() { # fm_hits_in <relative-path> -> live hit count
  sed 's/#.*$//' "$ROOT/$1" 2>/dev/null \
    | "$GREP" -cE "(grep|rg) [^|]*'\^[a-z_]+:" || true
}

echo "7. No hand-rolled frontmatter parsing outside reference/lib/frontmatter.sh"

# DECLARED SCOPE. Kept as an explicit list rather than reusing $SCAN so the
# methodology/ exclusion is visible at the point of use instead of being an
# absence a reader has to notice.
# AN ARRAY, for the reason this file's own header gives for $SCAN and the reason
# fm_exempt_p is a `case`: an unquoted "$FM_SCAN" in a command argument position
# word-splits under bash and NOT under zsh, where find receives ONE nonexistent
# path, prints nothing, and this check reports PASS over an empty scan. That is
# exactly what the first version of this rewrite did — bash 74/25, zsh 0/0, both
# green — three paragraphs below a comment explaining the same trap.
FM_SCAN=(skills skill-sources reference generators platforms presets hooks agents scripts)
fm_scan_files=$(cd "$ROOT" 2>/dev/null && find "${FM_SCAN[@]}" \
                  \( -name '*.md' -o -name '*.sh' -o -name '*.template' \) 2>/dev/null | LC_ALL=C sort)

# THE THREE-OUTCOME DISCRIMINATOR, keyed on the TREE and not on this script —
# from check 6, whose comment records why: the allowlist is inline so it is never
# absent, but the FILES are what a tree either has or has not. guard-failure.test.sh
# builds empty fixture trees to exercise this guard's failure paths, and a check
# that red()s there fails on every tree except this repo — which is how check 4
# once took that suite from 19/19 to 16/3, breaking precisely the assertions that
# prove the guard is not vacuous. Check 7's first draft did it again, 49/6, all
# six being "clean tree still passes".
fm_present=$(printf '%s\n' "$FM_ALLOW" | while IFS= read -r e; do
               [ -n "$e" ] || continue
               f=$(printf '%s' "$e" | cut -d' ' -f1)
               [ -e "$ROOT/$f" ] && printf 'x\n'
             done | "$GREP" -c . || true)

fm_bad=""; fm_total=0; fm_files=0
if [ -n "$fm_scan_files" ]; then
  # A heredoc, not a pipe: under bash a piped `while` runs in a subshell and
  # every counter below resets to 0 on exit, which reads as a clean tree.
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    fm_exempt_p "$rel" && continue
    n=$(fm_hits_in "$rel")
    [ "${n:-0}" -gt 0 ] || continue
    fm_total=$((fm_total + n)); fm_files=$((fm_files + 1))
    listed=$(printf '%s\n' "$FM_ALLOW" | while IFS= read -r e; do
               [ -n "$e" ] || continue
               case "$e" in "$rel "*) printf '%s' "$e" | cut -d' ' -f2 ;; esac
             done)
    if [ -z "$listed" ]; then
      fm_bad="$fm_bad    UNLISTED $rel ($n hit(s))
"
    elif [ "$listed" != "$n" ]; then
      fm_bad="$fm_bad    COUNT    $rel — allowlist says $listed, tree has $n
"
    fi
  done <<EOF_FM
$fm_scan_files
EOF_FM
fi

# The staleness half. Without it a site fixed on another branch leaves its entry
# behind and the next reader treats a closed defect as open.
#
# "file gone" is reported ONLY where the tree carries some of these files, on
# check 6's model: $ROOT is an argument, so this guard runs against fixture trees
# and could be run against a generated vault, and neither has any reason to hold
# skill-sources/stats/SKILL.md.
fm_stale=$(printf '%s\n' "$FM_ALLOW" | while IFS= read -r e; do
  [ -n "$e" ] || continue
  f=$(printf '%s' "$e" | cut -d' ' -f1)
  if [ ! -e "$ROOT/$f" ]; then
    [ "$fm_present" -gt 0 ] && printf '    STALE    %s — allowlisted but file gone; drop the entry\n' "$f"
  elif [ "$(fm_hits_in "$f")" = "0" ]; then
    printf '    STALE    %s — allowlisted but no longer matches; site converted, so drop the entry\n' "$f"
  fi
done)

# INTERNAL CONSISTENCY, and it is the assertion that would have caught the zsh
# fork above. fm_present is computed from the allowlist against $ROOT directly;
# fm_total from the scan. If the allowlisted files ARE present but the scan found
# nothing, the scan is broken — the two disagree about the same tree, and "PASS 0"
# is the wrong answer to that. The stale half does not catch it, because it also
# reads $ROOT directly and so sees the hits the scan missed.
if [ "$fm_present" -gt 0 ] && [ "$fm_total" -eq 0 ]; then
  red "frontmatter scan found 0 hits while $fm_present allowlisted file(s) are present — the scan did not run"
elif [ "$fm_present" -eq 0 ] && [ "$fm_total" -eq 0 ]; then
  skip "no allowlisted file present and no hand-rolled frontmatter parse found — nothing here claims this property"
elif [ -n "$fm_bad" ] || [ -n "$fm_stale" ]; then
  red "hand-rolled frontmatter parsing does not match the allowlist:"
  [ -n "$fm_bad" ] && printf '%s' "$fm_bad"
  [ -n "$fm_stale" ] && printf '%s\n' "$fm_stale"
  echo "    A line-anchored '^field:' grep matches the BODY too, including inside a fence."
  echo "    Use reference/lib/frontmatter.sh; allowlist only with a stated reason."
else
  ok "$fm_total hand-rolled frontmatter parse(s) across $fm_files allowlisted file(s), all accounted for"
fi


echo
if [ "$fail" -eq 0 ]; then
  echo "PORTABILITY: PASS"; exit 0
else
  echo "PORTABILITY: FAIL"; exit 1
fi
