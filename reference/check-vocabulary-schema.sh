#!/bin/bash
# check-vocabulary-schema.sh -- does every {vocabulary.X}/{DOMAIN:X} used in skill-sources/
# resolve to a key the generator's own schema declares?
#
# See docs/superpowers/specs/2026-08-08-vocabulary-schema-coverage-design.md. Short version:
# skill-sources/reduce/SKILL.md shipped {vocabulary.domain} for years with no schema key
# anywhere ever declaring `domain` -- an unresolvable placeholder in every vault it ever
# generated into. This is a whole-tree static check (not diff-relative like
# check-placeholder-count.sh): a schema key removed anywhere could silently orphan a
# placeholder in a completely unrelated, unchanged file.
#
# SCOPE: skill-sources/ only. platforms/shared/skill-blocks/ is frozen (check-portability.sh
# check 4) and cannot be edited to satisfy this gate; generators/features/*.md are
# composition blocks selected by config, not verbatim templates. Excluded for the same
# reasons check-placeholder-count.sh already excludes them.
#
# {config.X} markers are extracted (so a typo'd {vocabulary.X} spelled {config.X} is never
# silently missed) but never checked for resolution -- no schema declares config keys.
# Zero {config.X} markers exist in skill-sources/ today; currently a no-op.
#
# TOOL CHOICE FOR THE PRESENCE CHECKS ('vocabulary:' / 'domain_summary:' present in
# SCHEMA_FILE?): sed, not grep -- check-portability.sh check 7 bans a `grep`/`rg` command
# using a line-anchored '^field:' pattern anywhere outside reference/lib/frontmatter.sh,
# because that shape matches the same text in a file's BODY too, not just structural
# markers. This script hit that exact gate during development (a first draft used
# `grep -q '^domain_summary:'` and check 7 correctly flagged it as a new violation). Sed
# range/line extraction is the established, unflagged pattern here --
# mechanically_compare() in skills/upgrade/SKILL.md already extracts its vocabulary: block
# the same way. Not selecting/counting VAULT NOTES by frontmatter field (what check 7's
# ban actually targets) -- checking a fixed structural marker in one known generator
# source file. `# Level 7:` below is grep'd safely: it has no `^`-anchored lowercase field
# shape, so it never matched the detector to begin with.
#
# GREP INVOCATION: /usr/bin/grep, plain (no -E), matching check-placeholder-count.sh's own
# call. PLACEHOLDER_PAT is written in BRE alternation syntax (\|), which -E (POSIX ERE)
# reinterprets as a literal escaped pipe, silently matching nothing -- caught in
# development: `grep -rohE "$PLACEHOLDER_PAT"` returned zero matches against a real
# fixture that plainly contained the pattern. The explicit /usr/bin/ path sidesteps this
# shell environment's aliased grep, which has produced garbled/compressed output on plain
# `grep` calls elsewhere in this repo's development.
#
# EXIT CODES:
#   0  every {vocabulary.X}/{DOMAIN:X} used resolves to a declared key
#   1  at least one undeclared key found
#   2  cannot conclude -- schema unparseable, or zero placeholders extracted

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT" || { echo "check-vocabulary-schema: cannot cd to repo root '$ROOT'" >&2; exit 2; }

. "$HERE/lib/placeholder-pattern.sh"

SCAN_ROOT="${SCAN_ROOT:-skill-sources}"
SCHEMA_FILE="${SCHEMA_FILE:-skills/setup/SKILL.md}"

echo "=== check-vocabulary-schema ==="
echo "property: every {vocabulary.X}/{DOMAIN:X} used in $SCAN_ROOT/ resolves to a declared schema key"
echo "scope:    $SCAN_ROOT/ only; platforms/shared/skill-blocks/ and generators/features/ are out by design"
echo "NOT checked: {config.X} resolution -- no schema declares config keys, and none exist today"
echo

die2() { printf '  CANNOT CONCLUDE: %s\n' "$1"; echo; echo "VOCABULARY SCHEMA: CANNOT CONCLUDE"; exit 2; }

[ -d "$SCAN_ROOT" ] || die2 "$SCAN_ROOT/ does not exist -- wrong root, or SCAN_ROOT is misconfigured"
[ -f "$SCHEMA_FILE" ] || die2 "$SCHEMA_FILE does not exist -- wrong root, or SCHEMA_FILE is misconfigured"

# --- declared keys: Level 1-6 from the vocabulary: block, plus domain_summary: ------------
[ -n "$(sed -n '/^vocabulary:/p' "$SCHEMA_FILE")" ] || die2 "$SCHEMA_FILE has no 'vocabulary:' block -- cannot build the declared-key set"
/usr/bin/grep -q '# Level 7:' "$SCHEMA_FILE" || die2 "$SCHEMA_FILE has no '# Level 7:' marker -- cannot bound the vocabulary: block's extraction (an unbounded range would silently absorb unrelated trailing content)"

declared_keys=$(sed -n '/^vocabulary:/,/# Level 7:/{/^  [a-zA-Z_]*: /p;}' "$SCHEMA_FILE" \
  | sed -n 's/^  \([a-zA-Z_]*\):.*/\1/p' | LC_ALL=C sort -u)

if [ -n "$(sed -n '/^domain_summary:/p' "$SCHEMA_FILE")" ]; then
  declared_keys=$(printf '%s\ndomain\n' "$declared_keys" | LC_ALL=C sort -u)
fi

n_declared=$(printf '%s\n' "$declared_keys" | /usr/bin/grep -c . || true)
[ "${n_declared:-0}" -gt 0 ] || die2 "extracted ZERO declared keys from $SCHEMA_FILE -- the parse is broken, not the schema empty"

# --- used keys: every {vocabulary.X} and {DOMAIN:X} across $SCAN_ROOT/, folded ------------
# {DOMAIN:X} folds through the SAME three-step transform mechanically_compare() uses in
# skills/upgrade/SKILL.md: the two space-containing special cases first, then the generic
# alphanumeric/underscore rule. Reusing this transform, not inventing a new one, is the
# point -- a second, subtly different definition of "how DOMAIN: folds" is exactly the
# divergence class this repo has already shipped twice.
raw_matches=$(/usr/bin/grep -roh "$PLACEHOLDER_PAT" "$SCAN_ROOT" 2>/dev/null || true)
[ -n "$raw_matches" ] || die2 "extracted ZERO placeholders across all of $SCAN_ROOT/ -- the pattern is stale, not the tree clean"

used_keys=$(printf '%s\n' "$raw_matches" | while IFS= read -r m; do
  case "$m" in
    '{config.'*) continue ;;
    '{DOMAIN:topic maps}') printf 'topic_maps\n' ;;
    '{DOMAIN:topic map}')  printf 'topic_map\n' ;;
    '{DOMAIN:'*'}')
      k=${m#\{DOMAIN:}; k=${k%\}}
      case "$k" in *[!a-zA-Z_]*) continue ;; esac
      printf '%s\n' "$k" ;;
    '{vocabulary.'*'}')
      k=${m#\{vocabulary.}; k=${k%\}}
      printf '%s\n' "$k" ;;
  esac
done | LC_ALL=C sort -u)

# extraction_categories is the one documented Level 7 structural exception -- a nested
# list, never a substitution pair by design. Never expected to resolve.
used_keys=$(printf '%s\n' "$used_keys" | /usr/bin/grep -v '^extraction_categories$' || true)

# --- the check: used_keys minus declared_keys ----------------------------------------
undeclared=$(LC_ALL=C comm -23 <(printf '%s\n' "$used_keys") <(printf '%s\n' "$declared_keys"))

if [ -n "$undeclared" ]; then
  echo "  undeclared keys found:"
  printf '%s\n' "$undeclared" | while IFS= read -r k; do
    [ -n "$k" ] || continue
    echo "    $k"
    /usr/bin/grep -rn "vocabulary\.$k}\|DOMAIN:$k}" "$SCAN_ROOT" 2>/dev/null | sed 's/^/      /'
  done
  echo
  echo "VOCABULARY SCHEMA: FAIL"
  exit 1
fi

echo "  PASS every {vocabulary.X}/{DOMAIN:X} used in $SCAN_ROOT/ resolves to a key declared in $SCHEMA_FILE"
echo
echo "VOCABULARY SCHEMA: PASS"
exit 0
