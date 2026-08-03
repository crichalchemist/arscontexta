#!/bin/bash
# bump-version.test.sh — failure-path tests for scripts/bump-version.sh.
#
# WHY THIS EXISTS: bump-version.sh rewrites release metadata across three declared
# sites and no gate touched it. Its own header records a zsh fork that shipped —
# the loops read into `path`, which is zsh's array tied to PATH, so
# `zsh bump-version.sh --check` set PATH to a JSON path and died at rc 127 finding
# no jq. Only the bash form was ever run. A script whose failure modes are
# described at length in a comment and exercised by nothing is the house defect
# wearing release metadata: the comment reads as assurance and asserts nothing.
#
# EVERY ASSERTION RUNS INSIDE A FIXTURE TREE, NEVER IN THIS REPO. bump-version.sh
# derives REPO_ROOT from its own location and reads $REPO_ROOT/.version-bump.json,
# so the only way to point it at fixture data is to copy the script into the
# fixture. That constraint is load-bearing rather than incidental: a test that
# bumped this repo's real version would be the worst possible failure here.
#
# THE FIXTURE VERSIONS ARE 7.7.7 AND 8.8.8 because neither string appears anywhere
# in bump-version.sh. Its header quotes 1.2.3 in four places while documenting the
# jq-injection and anchoring fixes, and cmd_bump's closing audit greps the whole
# fixture tree — including the copied script — so a fixture built on 1.2.3 would
# report its own documentation as an undeclared straggler.
#
# Run: bash reference/test/bump-version.test.sh   (and the same file under zsh)

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SRC="$ROOT/scripts/bump-version.sh"

# Unlike guard-failure.test.sh — which hardcodes `bash "$GUARD"` because
# check-portability.sh has a #!/bin/bash shebang and CI invokes it that way — this
# suite runs the script under the shell the harness is running as. That is the
# whole point: the $path fork reached a release precisely because only the bash
# form was ever executed, and a suite that also only ran bash would have missed it
# a second time.
if [ -n "${ZSH_VERSION:-}" ]; then SELF=zsh; else SELF=bash; fi

passed=0; failed=0
TMPDIRS=()

ok()   { passed=$((passed+1)); }
fail() { failed=$((failed+1)); printf 'FAIL: %s\n  expected [%s] got [%s]\n' "$1" "$2" "$3"; }
eq()   { if [ "$2" = "$3" ]; then ok; else fail "$1" "$2" "$3"; fi; }

# Preconditions are asserted, not assumed. Without the jq check a missing
# dependency renders as every assertion failing for an unrelated reason; without
# the uid check, the SCAN FAILED assertion below passes vacuously, because root
# reads a 000 directory and grep never reaches exit 2.
command -v jq >/dev/null 2>&1 || {
  echo "harness: jq is required — cannot conclude anything" >&2; exit 1; }
[ -f "$SRC" ] || { printf 'harness: no script at %s\n' "$SRC" >&2; exit 1; }
[ "$(id -u)" -ne 0 ] || {
  echo "harness: running as root — the chmod-based assertions cannot fail" >&2; exit 1; }

# Permissions are removed during these tests. Without this trap a failed assertion
# leaves a directory nothing can delete.
cleanup() {
  local d
  for d in "${TMPDIRS[@]:-}"; do
    [ -n "$d" ] || continue
    chmod -R u+rwX "$d" 2>/dev/null
    rm -rf "$d"
  done
}
trap cleanup EXIT INT TERM

# A fixture repo root: the script, a declaration, and three sites in two files.
# Shaped like the real .version-bump.json rather than minimally, so `plugins.0.version`
# exercises jq_path's index rewrite (".plugins[0].version") and the two-sites-in-one-file
# case is covered — a bump that clobbers its own earlier write would show up here.
mkfix() { # mkfix [version] -> fixture root
  local d v
  v="${1:-7.7.7}"
  d=$(mktemp -d)
  TMPDIRS+=("$d")
  mkdir -p "$d/scripts" "$d/pkg"
  cp "$SRC" "$d/scripts/bump-version.sh"
  chmod +x "$d/scripts/bump-version.sh"
  printf '{"version": "%s"}\n' "$v" > "$d/pkg/plugin.json"
  printf '{"metadata": {"version": "%s"}, "plugins": [{"version": "%s"}]}\n' "$v" "$v" \
    > "$d/pkg/marketplace.json"
  cat > "$d/.version-bump.json" <<'EOF'
{
  "files": [
    {"path": "pkg/plugin.json",      "field": "version"},
    {"path": "pkg/marketplace.json", "field": "metadata.version"},
    {"path": "pkg/marketplace.json", "field": "plugins.0.version"}
  ],
  "audit": { "exclude": [".git"] }
}
EOF
  printf '%s' "$d"
}

# Exit code only — no pipeline, because PIPESTATUS is bash-only and reads empty
# under zsh, which renders as a blank rather than an error.
rc_of()  { local d; d="$1"; shift; "$SELF" "$d/scripts/bump-version.sh" "$@" >/dev/null 2>&1; printf '%s' "$?"; }
out_of() { local d; d="$1"; shift; "$SELF" "$d/scripts/bump-version.sh" "$@" 2>&1; }

# --- --check on a healthy fixture -------------------------------------------
# THE REGRESSION PIN FOR THE $path FORK. Renaming `vpath` back to `path` in the
# fixture's copy takes this from 0 to 127 under zsh — verified by that mutation —
# while the bash run stays green, which is exactly how the defect shipped.
F=$(mkfix)
eq "check: agreeing files pass under $SELF"        "0"   "$(rc_of "$F" --check)"
eq "check: names the version they agree at"        "yes" \
   "$(out_of "$F" --check | grep -q 'All declared files agree at 7.7.7' && echo yes || echo no)"

# --- a MISSING row must not be summarised as agreement -----------------------
# The two readable sites still agree, so the naive summary is true of what it read
# and false of what it claims. The summary line is the one a reader skims.
F=$(mkfix); rm "$F/pkg/plugin.json"
eq "check: a missing declared file fails"          "1"   "$(rc_of "$F" --check)"
eq "check: the missing row is reported MISSING"    "yes" \
   "$(out_of "$F" --check | grep -q 'MISSING' && echo yes || echo no)"
eq "check: does NOT claim agreement over a MISSING row" "yes" \
   "$(out_of "$F" --check | grep -q 'All declared files agree' && echo no || echo yes)"

# --- a non-version value is rejected -----------------------------------------
# jq prints the string "null" at exit 0 for a field path that does not exist, so
# without the shape check three wrong paths agree at "null" and the script reports
# success. Verified by deleting the `case "$ver"` guard: BOTH assertions below go
# red and cmd_check prints "All declared files agree at null" at rc 0.
#
# ALL THREE SITES ARE BROKEN, not one. Breaking a single site left two readable
# rows at 7.7.7, so the run failed as DRIFT and the rc assertion passed without
# ever exercising the guard — green for a reason unrelated to what it claims to
# test. Caught by running the mutation rather than by reading the fixture.
F=$(mkfix)
printf '{"nothing": true}\n' > "$F/pkg/plugin.json"
printf '{"nothing": true}\n' > "$F/pkg/marketplace.json"
eq "check: a field path that does not exist fails" "1"   "$(rc_of "$F" --check)"
eq "check: jq's \"null\" is rejected as NOT A VERSION" "yes" \
   "$(out_of "$F" --check | grep -q 'NOT A VERSION: null' && echo yes || echo no)"

# --- genuine drift -----------------------------------------------------------
# The condition the script exists to detect. A suite covering every failure path
# except the primary one would be its own kind of green.
F=$(mkfix); printf '{"version": "9.9.9"}\n' > "$F/pkg/plugin.json"
eq "check: disagreeing files fail"                 "1"   "$(rc_of "$F" --check)"
eq "check: disagreement is reported as DRIFT"      "yes" \
   "$(out_of "$F" --check | grep -q 'DRIFT' && echo yes || echo no)"

# --- the version argument is anchored at BOTH ends ---------------------------
# Without the trailing `$`, each of these passed the shape test and was written
# verbatim into every manifest. The final assertion is the one that proves the
# rejection happened BEFORE any file was touched.
F=$(mkfix)
eq "bump: rejects 8.8.8junk"                       "1"   "$(rc_of "$F" 8.8.8junk)"
eq "bump: rejects 8.8.8.4"                         "1"   "$(rc_of "$F" 8.8.8.4)"
eq "bump: rejects 8.8.8-rc1"                       "1"   "$(rc_of "$F" 8.8.8-rc1)"
eq "bump: rejects a jq-injection payload"          "1"   "$(rc_of "$F" '8.8.8" as $v | halt_error(9) #')"
eq "bump: a rejected version writes nothing"       "7.7.7" "$(jq -r .version "$F/pkg/plugin.json")"

# --- SCAN FAILED is reachable, and is not 'all clear' ------------------------
# grep exits 1 on no-match — the clean case — and >1 on a real error. Collapsing
# the two would make a failed scan read as "every occurrence is in a declared
# file", which is the shape CONTRIBUTING.md INVARIANT 2 forbids. An unreadable
# directory is the cheapest way to reach exit 2; measured at rc 2 on this platform.
F=$(mkfix); mkdir -p "$F/locked"; printf '7.7.7\n' > "$F/locked/x.md"
chmod 000 "$F/locked"
scan_rc=$(rc_of "$F" --audit)
scan_out=$(out_of "$F" --audit)
chmod 755 "$F/locked"
eq "audit: an unreadable directory fails the scan"  "1"   "$scan_rc"
eq "audit: says the result is not evidence"         "yes" \
   "$(printf '%s\n' "$scan_out" | grep -q 'SCAN FAILED' && echo yes || echo no)"
eq "audit: does NOT report the tree clean"          "yes" \
   "$(printf '%s\n' "$scan_out" | grep -q 'every occurrence is in a declared file' && echo no || echo yes)"

# --- a real bump moves every declared site together --------------------------
F=$(mkfix)
eq "bump: rc 0 on a well-formed version"           "0"   "$(rc_of "$F" 8.8.8)"
eq "bump: pkg/plugin.json moved"                   "8.8.8" "$(jq -r .version "$F/pkg/plugin.json")"
eq "bump: metadata.version moved"                  "8.8.8" "$(jq -r .metadata.version "$F/pkg/marketplace.json")"
eq "bump: plugins[0].version moved"                "8.8.8" "$(jq -r '.plugins[0].version' "$F/pkg/marketplace.json")"
# SUCCESS PATH ONLY — `mv` consumes the temp whenever jq succeeds, so this cannot
# say anything about the `|| { rm -f "$tmp"; }` branch. Deleting that `rm` leaves
# this green. The failure path is asserted separately below; this line is here to
# catch a future change that stops moving the temp at all.
eq "bump: leaves no .tmp. behind when jq succeeds" ""    "$(find "$F" -name '*.tmp.*' | tr '\n' ' ' | sed 's/ *$//')"
eq "bump: --check agrees afterwards"               "0"   "$(rc_of "$F" --check)"

# --- a write that cannot complete fails loudly -------------------------------
# An unparseable declared file makes read_json_field fail on the SECOND site, after
# the first has already been rewritten.
#
# ASSERTED: the script does not report success. NOT ASSERTED: what it leaves on
# disk. The bump is partial — pkg/plugin.json keeps the new version while
# marketplace.json keeps the old — which manufactures precisely the drift this
# script exists to prevent. That is a real finding and is recorded as one; pinning
# the current on-disk state here would make an atomic-bump fix look like a
# regression, so this assertion holds whether the bump is made atomic or merely
# kept loud.
F=$(mkfix); printf 'not json\n' > "$F/pkg/marketplace.json"
bad_rc=$(rc_of "$F" 8.8.8)
eq "bump: an unparseable declared file is not reported as success" "yes" \
   "$([ "$bad_rc" -ne 0 ] && echo yes || echo no)"

# --- a jq that fails DURING the write leaves no temp -------------------------
# The branch the success-path assertion above cannot reach. `write_json_field`'s
# redirection creates $1.tmp.$$ before jq runs, so a jq that then fails skips the
# `mv` and the temp survives unless the `|| { rm -f "$tmp"; }` branch removes it.
# An orphaned .tmp.<pid> beside a manifest is a second copy of release metadata
# that nothing declares — the drift condition, spelled differently.
#
# REACHING IT TAKES A FIELD THAT READS BUT CANNOT BE ASSIGNED TO. cmd_bump calls
# read_json_field first and `set -e` aborts on its failure, so every way of
# breaking the *file* fails before any write. `version|length` splits the two:
# `jq -r '.version|length'` returns 5 at rc 0, while `.version|length = $v` is an
# invalid path expression and exits 5 — with the temp already on disk.
#
# Non-vacuity: deleting `rm -f "$tmp"` from write_json_field:55 turns this red in
# both shells and leaves every other assertion in the file green.
F=$(mkfix)
cat > "$F/.version-bump.json" <<'EOF'
{
  "files": [
    {"path": "pkg/plugin.json", "field": "version|length"}
  ],
  "audit": { "exclude": [".git"] }
}
EOF
tmp_rc=$(rc_of "$F" 8.8.8)
eq "bump: a write-time jq failure is not reported as success" "yes" \
   "$([ "$tmp_rc" -ne 0 ] && echo yes || echo no)"
eq "bump: a write-time jq failure leaves no .tmp. behind" ""   \
   "$(find "$F" -name '*.tmp.*' | tr '\n' ' ' | sed 's/ *$//')"

# --- argument handling -------------------------------------------------------
F=$(mkfix)
eq "an unknown flag is rejected"                   "1"   "$(rc_of "$F" --nope)"
eq "no argument prints usage and succeeds"         "0"   "$(rc_of "$F")"

printf '\npassed=%s failed=%s\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
