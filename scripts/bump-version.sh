#!/usr/bin/env bash
#
# bump-version.sh — move every declared version site together, and report the ones
# nobody declared.
#
#   bump-version.sh <new-version>   bump declared files, then audit for stragglers
#   bump-version.sh --check         declared files agree with each other
#   bump-version.sh --audit [ver]   scan the repo for a version string outside the
#                                   declared set (defaults to the current version)
#
# WHY THIS EXISTS: a published plugin and this tree once both called themselves
# 0.8.0 while differing materially — the published skills/upgrade/SKILL.md was 395
# lines against 465 here, and the published tree had no reference/lib/ at all. A
# version string that does not identify a unique artifact is the house failure
# class in a different costume: it looks like an answer and is not one.
#
# TWO DELIBERATE DIVERGENCES FROM THE SCRIPT THIS WAS PORTED FROM:
#
#   1. The source audits for the CURRENT version, and cmd_bump runs that audit
#      AFTER bumping — so it scans for the NEW string and structurally cannot find
#      a file still carrying the OLD one, which is the only thing an audit after a
#      bump is for. Here cmd_bump captures the old version first and audits for
#      that. `--audit` alone still defaults to current, for pre-bump use.
#   2. The source ends cmd_check with "in sync at ${versions[0]}". zsh arrays are
#      1-indexed, so that renders empty under zsh — a bash/zsh fork of exactly the
#      kind this repo has shipped twice. No indexed access here.
#
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$REPO_ROOT/.version-bump.json"

command -v jq >/dev/null 2>&1 || { echo "error: jq is required" >&2; exit 1; }
[ -f "$CONFIG" ] || { echo "error: .version-bump.json not found at $CONFIG" >&2; exit 1; }

# "plugins.0.version" -> ".plugins[0].version"
jq_path() { printf '.%s' "$1" | sed -E 's/\.([0-9]+)(\.|$)/[\1]\2/g'; }

read_json_field()  { jq -r "$(jq_path "$2")" "$1"; }
write_json_field() {
  tmp="$1.tmp.$$"
  jq "$(jq_path "$2") = \"$3\"" "$1" > "$tmp" && mv "$tmp" "$1"
}
declared_files() { jq -r '.files[] | "\(.path)\t\(.field)"' "$CONFIG"; }
declared_paths() { jq -r '.files[].path' "$CONFIG" | sort -u; }

# The version the declared files agree on, or the most common if they do not.
current_version() {
  declared_files | while IFS="$(printf '\t')" read -r path field; do
    [ -f "$REPO_ROOT/$path" ] && read_json_field "$REPO_ROOT/$path" "$field"
  done | sort | uniq -c | sort -rn | head -1 | awk '{print $2}'
}

cmd_check() {
  drift=0
  seen=""
  echo "Version check:"
  while IFS="$(printf '\t')" read -r path field; do
    if [ ! -f "$REPO_ROOT/$path" ]; then
      printf '  %-46s MISSING\n' "$path ($field)"; drift=1; continue
    fi
    ver=$(read_json_field "$REPO_ROOT/$path" "$field")
    printf '  %-46s %s\n' "$path ($field)" "$ver"
    seen="$seen$ver
"
  done <<EOF
$(declared_files)
EOF
  distinct=$(printf '%s' "$seen" | sort -u | grep -c . || true)
  if [ "$distinct" -gt 1 ]; then
    echo "DRIFT: declared files disagree —"
    printf '%s' "$seen" | sort | uniq -c | sed 's/^/    /'
    drift=1
  elif [ "$distinct" -eq 1 ]; then
    printf 'All declared files agree at %s\n' "$(printf '%s' "$seen" | sort -u)"
  else
    echo "error: no versions could be read" >&2; drift=1
  fi
  return $drift
}

cmd_audit() {
  want="${1:-$(current_version)}"
  [ -n "$want" ] || { echo "error: could not determine a version to audit" >&2; return 1; }
  printf "Audit: files outside the declared set containing '%s'\n" "$want"

  set -- -rn -F "$want" --binary-files=without-match
  while IFS= read -r pat; do
    [ -n "$pat" ] || continue
    set -- "$@" "--exclude=$pat" "--exclude-dir=$pat"
  done <<EOF
$(jq -r '.audit.exclude[]?' "$CONFIG")
EOF

  # grep exits 1 on no-match, which is the clean case, and >1 on a real error.
  # Collapsing those two would make a failed scan read as "all clear" — the exact
  # shape CONTRIBUTING.md INVARIANT 2 forbids.
  hits=$(cd "$REPO_ROOT" && grep "$@" . 2>/dev/null); rc=$?
  if [ "$rc" -gt 1 ]; then
    echo "  SCAN FAILED — this result is NOT evidence" >&2; return 1
  fi

  undeclared=$(printf '%s\n' "$hits" | while IFS= read -r line; do
    [ -n "$line" ] || continue
    f=${line%%:*}; f=${f#./}
    printf '%s\n' "$(declared_paths)" | grep -qxF "$f" || printf '  %s\n' "$line"
  done)

  if [ -z "$undeclared" ]; then
    echo "  none — every occurrence is in a declared file"
    return 0
  fi
  printf '%s\n' "$undeclared"
  echo "  Bump these too (add to .version-bump.json) or record why not (audit.exclude)."
  return 1
}

cmd_bump() {
  new="$1"
  printf '%s' "$new" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+' || {
    echo "error: '$new' is not X.Y.Z" >&2; exit 1; }
  old=$(current_version)
  printf 'Bumping declared files %s -> %s\n' "$old" "$new"
  while IFS="$(printf '\t')" read -r path field; do
    if [ ! -f "$REPO_ROOT/$path" ]; then printf '  SKIP (missing) %s\n' "$path"; continue; fi
    was=$(read_json_field "$REPO_ROOT/$path" "$field")
    write_json_field "$REPO_ROOT/$path" "$field" "$new"
    printf '  %-46s %s -> %s\n' "$path ($field)" "$was" "$new"
  done <<EOF
$(declared_files)
EOF
  echo
  # Audit the OLD version: what still says 0.8.0 after everything declared says 0.9.0.
  cmd_audit "$old" || true
}

case "${1:-}" in
  --check) cmd_check ;;
  --audit) shift; cmd_audit "${1:-}" ;;
  --help|-h|"")
    echo "Usage: bump-version.sh <new-version> | --check | --audit [version]"; exit 0 ;;
  --*) echo "error: unknown flag '$1'" >&2; exit 1 ;;
  *)   cmd_bump "$1" ;;
esac
