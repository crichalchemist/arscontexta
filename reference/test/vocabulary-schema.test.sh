#!/bin/bash
# vocabulary-schema.test.sh -- mutation tests for reference/check-vocabulary-schema.sh
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

echo "$pass/$((pass+fail))"
[ "$fail" -eq 0 ]
