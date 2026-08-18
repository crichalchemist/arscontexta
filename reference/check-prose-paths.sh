#!/bin/bash
# check-prose-paths.sh — every repo path named in prose exists IN THIS CHECKOUT.
#
# ─────────────────────────────────────────────────────────────────────────────
# WHAT THIS CHECKS, AND WHAT IT DELIBERATELY DOES NOT
#
# CHECKS:     a path named in prose that begins with a repo top-level directory
#             resolves in the working tree.
# DOES NOT:   verify that path exists in the *packaged plugin* — the property
#             `reference/skill-authoring.md` §4 actually states.
#
# Those are different claims and the difference is the whole reason this script
# has this name. "The packaged plugin" is not a defined build target here: this
# repo has no build step, so a checker could only compare prose against whatever
# `/plugin install` last happened to copy. A green result would assert nothing
# while looking like assurance. That checker was considered and rejected.
#
# This one is the honest subset. It cannot catch the §4 defect class on its own
# — a path can resolve here and still be missing from an install, which is
# exactly what happened to `reference/lib/link-extraction.sh` (present in this
# checkout at 0.9.0, absent from the installed 0.8.0). It catches the strictly
# easier error: prose naming a path that does not exist at all.
#
# "0.9.0"/"0.8.0" ABOVE ARE A PINNED HISTORICAL COMPARISON, not a live version
# claim -- the checkout genuinely was at 0.9.0 when this discrepancy was found,
# and bumping either number to match a later release would misdate the anecdote
# rather than correct it. Excluded from bump-version.sh's audit accordingly
# (`.version-bump.json`'s `audit.exclude`), by filename, with this comment as
# the stated reason.
#
# Read the run banner, not this header, for what a given run checked. The banner
# prints every time for that reason.
# ─────────────────────────────────────────────────────────────────────────────

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || { echo "check-prose-paths: cannot cd to repo root" >&2; exit 2; }

# ── Scope: a STATED file list, not a discovered one ──────────────────────────
# Discovery would make this a fourth answer to "which tree am I in". These are
# the documents that make prose claims about repo layout. A file listed here and
# missing is an ERROR, never a skip — a shrinking scope must not read as clean.
SCOPE="
CLAUDE.md
docs/closed-divergences.md
CONTRIBUTING.md
README.md
reference/skill-authoring.md
reference/testing-milestones.md
reference/vocabulary-transforms.md
reference/use-case-presets.md
platforms/shared/skill-blocks/README.md
hooks/scripts/session-orient.sh
platforms/claude-code/hooks/session-orient.sh.template
.opencode/INSTALL.md
.pi/INSTALL.md
"

# Repo top-level directories. A path must start with one of these to be treated
# as a repo path. This is what separates `reference/lib/x.sh` (ours) from
# `ops/observations/` (a generated vault's), `/next` (a command), `10/5` (a
# ratio) and `fix/spec-e` (a branch). Derived from the tree, then pinned here so
# a new top-level directory is a deliberate edit rather than a silent widening.
PREFIXES="agents docs generators hooks methodology platforms presets reference scripts skill-sources skills .github"

fail=0
scanned=0
found=0
missing=0

printf '=== check-prose-paths ===\n'
printf 'property: repo paths named in prose resolve in THIS CHECKOUT\n'
printf 'NOT checked: presence in the packaged plugin (no build target exists)\n\n'

for f in $SCOPE; do
  if [ ! -r "$f" ]; then
    printf 'ERROR  %s is in scope but missing or unreadable\n' "$f"
    fail=1
    continue
  fi
  scanned=$((scanned + 1))

  # Backticked path-shaped tokens. ERE only -- PCRE mode is unavailable on CI's
  # grep, and in a Claude Code session `grep` is ugrep, so a PCRE pattern here
  # would test clean locally and fail in Actions. (Naming the flag literally in
  # this comment trips check-portability.sh check 1, which cannot distinguish a
  # comment from code and is deliberately strict about it -- so it is not named.)
  raw=$(grep -o '`[^`]*`' "$f" 2>/dev/null | tr -d '`')

  # -f: word-splitting below is intentional, pathname expansion is not. Without it
  # a backticked token containing a glob metacharacter is expanded before the case
  # filter that would have rejected it. No false MISSING is reachable either way
  # (a glob that matches yields real paths; one that does not stays literal and is
  # filtered), but it inflates the `found` tally, and a count that drifts for a
  # reason nobody can reconstruct is how the numbers in this repo go bad.
  set -f
  for tok in $raw; do
    # A skill may name a path relative to the plugin root. Strip that prefix so
    # the remainder can be tested -- this is the §4 shape.
    case "$tok" in
      '${CLAUDE_PLUGIN_ROOT}/'*) tok=${tok#'${CLAUDE_PLUGIN_ROOT}/'} ;;
    esac

    # Must contain a slash, no placeholders, no shell/glob metacharacters.
    case "$tok" in
      */*) ;;
      *) continue ;;
    esac
    case "$tok" in
      # `<name>` and `<skill>` are metavariables, not paths -- CLAUDE.md writes
      # `skill-sources/<name>/SKILL.md` to describe a shape, not a file.
      *'{'*|*'}'*|*'$'*|*'*'*|*' '*|*'('*|*'|'*|*'<'*|*'>'*|http*) continue ;;
    esac

    # Must begin with a known repo top-level directory.
    ok=no
    for p in $PREFIXES; do
      case "$tok" in "$p"/*) ok=yes; break ;; esac
    done
    [ "$ok" = yes ] || continue

    # Strip a trailing colon-and-line-range ("file.sh:74", "stats.md:94-95") and
    # any trailing punctuation prose leaves attached.
    path=${tok%%:*}
    path=${path%.}
    path=${path%,}

    found=$((found + 1))
    if [ ! -e "$path" ]; then
      printf 'MISSING  %-58s named in %s\n' "$path" "$f"
      missing=$((missing + 1))
      fail=1
    fi
  done
done

# ── Non-vacuity. This is not decoration. ─────────────────────────────────────
# A scan that matches nothing exits 0 with no output, which is byte-identical to
# a clean run. This repo has shipped that exact failure more than once -- a
# mutation that silently matched nothing, and a grep over an undefined variable
# that went green having read zero records. If the extractor breaks, or the
# prefix list stops matching, or the scope empties, that must be LOUD.
if [ "$scanned" -eq 0 ]; then
  printf '\nFAIL: scope is empty -- no files scanned. This is a broken check, not a clean repo.\n'
  exit 2
fi
if [ "$found" -eq 0 ]; then
  printf '\nFAIL: scanned %d files and extracted ZERO repo paths.\n' "$scanned"
  printf '      A zero-failure result here means the extractor is broken, not that prose is clean.\n'
  exit 2
fi

printf '\nscanned %d files, checked %d repo paths, %d missing\n' "$scanned" "$found" "$missing"
if [ "$fail" -eq 0 ]; then
  printf 'PROSE PATHS: PASS (checkout only -- packaging unverified)\n'
else
  printf 'PROSE PATHS: FAIL\n'
fi
exit "$fail"
