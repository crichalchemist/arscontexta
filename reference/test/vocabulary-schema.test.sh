#!/bin/bash
# vocabulary-schema.test.sh -- mutation tests for reference/check-vocabulary-schema.sh
#
# Every assertion below invokes the gate as `bash "$GATE"`, unconditionally, even when
# this test file itself is run under zsh -- so a `zsh` run of THIS suite proves the test
# harness is zsh-portable, not that check-vocabulary-schema.sh runs correctly when
# invoked as `zsh check-vocabulary-schema.sh` directly. Unlike guard-failure.test.sh's
# identical-looking `bash "$GUARD"` (which is correct because nothing anywhere ever
# invokes check-portability.sh by any other name), check-vocabulary-schema.sh has no
# such single-invocation guarantee -- CI runs it directly too. That direct zsh coverage
# belongs in CI's own step list (a `zsh reference/check-vocabulary-schema.sh` step,
# alongside the bash one), not duplicated inside every assertion here.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
GATE="$ROOT/check-vocabulary-schema.sh"
pass=0; fail=0
assert() { if [ "$1" = "$2" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $3 (expected [$2] got [$1])"; fi; }

fixture_schema() {
  cat > "$1" <<'EOF'
vocabulary:
  # Level 1: Folder names
  notes: "[domain term]"
  inbox: "[domain term]"
# Level 5: Process verbs
  reduce: "[domain term]"
# Level 6: Command names
  cmd_reduce: "[/domain-verb]"
# Level 7: Extraction categories
  extraction_categories:
EOF
}

# --- Assertion 1: positive control -- undeclared key FAILs ------------------------------
tmp1=$(mktemp -d); mkdir -p "$tmp1/scan"
fixture_schema "$tmp1/schema.md"
echo '{vocabulary.undeclared_thing}' > "$tmp1/scan/x.md"
SCAN_ROOT="$tmp1/scan" SCHEMA_FILE="$tmp1/schema.md" bash "$GATE" >/dev/null 2>&1
assert "$?" "1" "positive control: undeclared key fails"
rm -rf "$tmp1"

# --- Assertion 2: negative control -- only declared keys PASSes -------------------------
tmp2=$(mktemp -d); mkdir -p "$tmp2/scan"
fixture_schema "$tmp2/schema.md"
echo '{vocabulary.notes} {vocabulary.inbox} {vocabulary.reduce}' > "$tmp2/scan/x.md"
SCAN_ROOT="$tmp2/scan" SCHEMA_FILE="$tmp2/schema.md" bash "$GATE" >/dev/null 2>&1
assert "$?" "0" "negative control: only declared keys passes"
rm -rf "$tmp2"

# --- Assertion 3: the Level 7 exception is never flagged --------------------------------
tmp3=$(mktemp -d); mkdir -p "$tmp3/scan"
fixture_schema "$tmp3/schema.md"
printf '{vocabulary.notes} {DOMAIN:extraction_categories}\n' > "$tmp3/scan/x.md"
SCAN_ROOT="$tmp3/scan" SCHEMA_FILE="$tmp3/schema.md" bash "$GATE" >/dev/null 2>&1
assert "$?" "0" "Level 7 exception (extraction_categories) is not flagged"
rm -rf "$tmp3"

# --- Assertion 4: mutating the exception out of the gate turns it red -------------------
tmp4=$(mktemp -d); mkdir -p "$tmp4/scan"
fixture_schema "$tmp4/schema.md"
printf '{vocabulary.notes} {DOMAIN:extraction_categories}\n' > "$tmp4/scan/x.md"
sed "s/\^extraction_categories\\\$/^DUMMY_EXCEPTION_NAME\$/" "$GATE" > "$tmp4/mutated_gate.sh"
assert "$(grep -c 'DUMMY_EXCEPTION_NAME' "$tmp4/mutated_gate.sh")" "1" \
  "mutation actually applied to the mutated gate copy"
chmod +x "$tmp4/mutated_gate.sh"
# The mutated copy computes HERE from its OWN location and sources
# "$HERE/lib/placeholder-pattern.sh" relative to it -- same class of gap Task 1's
# mkrepo() had. Bring the real dependency along, or the mutation test fails on an
# unrelated "file not found" instead of exercising the mutation at all.
mkdir -p "$tmp4/lib"
cp "$ROOT/lib/placeholder-pattern.sh" "$tmp4/lib/placeholder-pattern.sh"
SCAN_ROOT="$tmp4/scan" SCHEMA_FILE="$tmp4/schema.md" bash "$tmp4/mutated_gate.sh" >/dev/null 2>&1
assert "$?" "1" "mutating away the exception makes extraction_categories flag (proves assertion 3 isn't vacuous)"
rm -rf "$tmp4"

# --- Assertion 5: the two special-cased space-containing DOMAIN: spellings resolve ------
# Written as its own fixture, not fixture_schema() + append: an append lands after the
# closing "# Level 7:" marker, outside the sed range that extracts declared keys --
# exactly the bug this assertion needs to NOT have, caught by this assertion itself
# failing during development (rc 1 instead of the expected 0) before this fix.
tmp5=$(mktemp -d); mkdir -p "$tmp5/scan"
cat > "$tmp5/schema.md" <<'EOF'
vocabulary:
  # Level 4: Navigation terms
  topic_map: "[domain term]"
  topic_maps: "[domain term]"
# Level 7: Extraction categories
  extraction_categories:
EOF
printf '{DOMAIN:topic map} {DOMAIN:topic maps}\n' > "$tmp5/scan/x.md"
SCAN_ROOT="$tmp5/scan" SCHEMA_FILE="$tmp5/schema.md" bash "$GATE" >/dev/null 2>&1
assert "$?" "0" "space-containing DOMAIN: spellings resolve via the same fold mechanically_compare uses"
rm -rf "$tmp5"

# --- Assertion 6: {config.X} is extracted but never flagged for resolution --------------
tmp6=$(mktemp -d); mkdir -p "$tmp6/scan"
fixture_schema "$tmp6/schema.md"
printf '{vocabulary.notes} {config.something_no_schema_declares}\n' > "$tmp6/scan/x.md"
SCAN_ROOT="$tmp6/scan" SCHEMA_FILE="$tmp6/schema.md" bash "$GATE" >/dev/null 2>&1
assert "$?" "0" "{config.X} markers are never checked for resolution"
rm -rf "$tmp6"

# --- Assertion 7: zero-extraction guard -------------------------------------------------
tmp7=$(mktemp -d); mkdir -p "$tmp7/scan"
fixture_schema "$tmp7/schema.md"
echo 'no placeholders in this file at all' > "$tmp7/scan/x.md"
SCAN_ROOT="$tmp7/scan" SCHEMA_FILE="$tmp7/schema.md" bash "$GATE" >/dev/null 2>&1
assert "$?" "2" "zero placeholders extracted -> cannot conclude, never a false-clean pass"
rm -rf "$tmp7"

# --- Assertion 8: schema file missing -> cannot conclude --------------------------------
tmp8=$(mktemp -d); mkdir -p "$tmp8/scan"
echo '{vocabulary.notes}' > "$tmp8/scan/x.md"
SCAN_ROOT="$tmp8/scan" SCHEMA_FILE="$tmp8/does-not-exist.md" bash "$GATE" >/dev/null 2>&1
assert "$?" "2" "missing schema file -> cannot conclude"
rm -rf "$tmp8"

# --- Assertion 9: schema missing the # Level 7: marker -> cannot conclude ---------------
tmp9=$(mktemp -d); mkdir -p "$tmp9/scan"
cat > "$tmp9/schema.md" <<'EOF'
vocabulary:
  notes: "[domain term]"
EOF
echo '{vocabulary.notes}' > "$tmp9/scan/x.md"
SCAN_ROOT="$tmp9/scan" SCHEMA_FILE="$tmp9/schema.md" bash "$GATE" >/dev/null 2>&1
assert "$?" "2" "schema with no bounding '# Level 7:' marker -> cannot conclude (unbounded range would silently absorb trailing content)"
rm -rf "$tmp9"

# --- Assertion 10: PLACEHOLDER_PAT exists in exactly one place -------------------------
# Scoped to these three named files, not a tree-wide search -- it proves the two
# scripts that consume the constant don't redefine it locally, not that no other
# file anywhere ever declares a same-named variable. reference/skill-authoring.md
# carries an inert, non-executing copy inside a ```text fence (a documented,
# deferred item), outside this assertion's scope by design; it never executes and
# a tree-wide grep would need its own reasoning about what "counts."
n_defs=$(/usr/bin/grep -rl "^PLACEHOLDER_PAT=" "$ROOT/check-placeholder-count.sh" "$ROOT/check-vocabulary-schema.sh" "$ROOT/lib/placeholder-pattern.sh" 2>/dev/null | wc -l | tr -d ' ')
assert "$n_defs" "1" "PLACEHOLDER_PAT is defined once among check-placeholder-count.sh/check-vocabulary-schema.sh/lib/placeholder-pattern.sh -- never redefined locally by either consumer"

# --- Assertion 11: n_used guards against a non-identifier {DOMAIN:X} silently ----------
# emptying used_keys, distinct from assertion 3's already-covered case (the
# documented extraction_categories exception). Added after a whole-branch review
# found this exact scenario had no assertion of its own -- only manually verified
# during Task 5's fix round, not covered by the shipped suite.
tmp11=$(mktemp -d); mkdir -p "$tmp11/scan"
fixture_schema "$tmp11/schema.md"
echo '{DOMAIN:not-a-valid-key}' > "$tmp11/scan/x.md"
SCAN_ROOT="$tmp11/scan" SCHEMA_FILE="$tmp11/schema.md" bash "$GATE" >/dev/null 2>&1
assert "$?" "2" "a sole non-identifier {DOMAIN:X} (e.g. containing a hyphen) leaves used_keys empty -> cannot conclude, never a false-clean pass"
rm -rf "$tmp11"

echo "$pass/$((pass+fail))"
[ "$fail" -eq 0 ]
