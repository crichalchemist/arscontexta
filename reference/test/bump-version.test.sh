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

# The pattern every "leaves no temp behind" assertion searches for. Single-sourced on
# purpose: five assertions depend on it matching what bump-version.sh actually names
# its staged temps, and that dependency used to exist only as the same string typed
# into two files and checked in neither. Renaming the suffix in the script left all
# five green — including a run that genuinely orphaned temps. The assertion below
# ties this pattern to a filename the script itself prints.
TMP_GLOB='*.tmp.*'

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
# SUCCESS PATH ONLY — the commit phase's `mv` consumes each staged temp whenever
# every site stages cleanly, so this cannot say anything about the rollback branch.
# Deleting the rollback leaves this green. The failure paths are asserted separately
# below; this line is here to catch a future change that stops moving the temp at all.
eq "bump: leaves no .tmp. behind when jq succeeds" ""    "$(find "$F" -name "$TMP_GLOB" | tr '\n' ' ' | sed 's/ *$//')"
eq "bump: --check agrees afterwards"               "0"   "$(rc_of "$F" --check)"
# LINE 176 IS THE SAME-FILE PIN, and it is worth naming because it looks redundant
# beside 177. pkg/marketplace.json is declared twice, so staging is keyed on path:
# the plugins.0.version edit is staged FROM the metadata.version temp. Staging both
# from the original file instead — the obvious shape for an "atomic" fix — makes the
# second temp carry only its own edit, and committing it discards metadata.version.
# Verified by mutation: that change turns 176 red and leaves 175 and 177 green.

# --- $TMP_GLOB matches what the script actually names its temps --------------
# TWO CONTROLS, AND THEY PROVE DIFFERENT THINGS. Four assertions in this file expect
# `find -name "$TMP_GLOB"` to come back empty, and an empty result is what a satisfied
# negative check looks like AND what a misspelled glob, a wrong root, or a find that
# never ran looks like.
#
# The first control below plants a file and proves the SEARCH works — the root is
# right and the pattern can match. That is all it proves. It observes nothing about
# bump-version.sh, and on its own it left a real defect invisible: renaming the temp
# suffix in the script (`.tmp.` -> `.stg.`, behaviour-identical) kept the whole suite
# green at 38/38 in both shells, and so did the same rename with the rollback deleted,
# which genuinely orphans staged temps beside the manifests.
#
# The second control closes that. On an abort the script now PRINTS each temp it
# discards, so the filename crossing the boundary is one the script built rather than
# one this file typed. Asserting $TMP_GLOB matches that name couples the pattern to
# the subject: rename the suffix in the script and this goes red.
F=$(mkfix); : > "$F/pkg/plugin.json.tmp.99999"
eq "harness: the temp search finds a temp that is there" "$F/pkg/plugin.json.tmp.99999" \
   "$(find "$F" -name "$TMP_GLOB" | tr '\n' ' ' | sed 's/ *$//')"

F=$(mkfix); printf 'not json\n' > "$F/pkg/marketplace.json"
# `.work` names are excluded deliberately. The abort branch loops over both `$tmp` and
# `$tmp.work`, and the four assertions this control underwrites search for the STAGED
# TEMP — so pinning the glob against a `.work` name would still match, still go red
# under a suffix rename, and still not be pinning the thing they look for. Today only
# the staged temp survives to that branch (stage_json_field removes `.work` on failure
# and `mv` consumes it on success), so the filter is a no-op; the count assertion below
# is what makes a change in that invariant visible instead of silently absorbed.
disc_all=$(out_of "$F" 8.8.8 | sed -n 's/^  discarded: //p')
disc=$(printf '%s\n' "$disc_all" | grep -v '\.work$' | head -1)
eq "harness: the aborted run discards exactly one staged temp" "1" \
   "$(printf '%s\n' "$disc_all" | grep -c . || true)"
# Positive half first: a discarded name was actually reported. Without it the glob
# assertion below would pass on an empty string under some shells' pattern rules, and
# would certainly pass for the wrong reason if the script stopped printing the line.
eq "harness: an aborted run reports the temp it discarded" "yes" \
   "$([ -n "$disc" ] && echo yes || echo no)"
# The oracle is `find` with $TMP_GLOB — the same tool and the same pattern the four
# assertions use, not a shell `case`. That is deliberate on two counts: it removes any
# gap between what this control validates and what they rely on, and `case "$x" in
# $GLOB)` is not portable here — it matched under bash and did not under zsh, which is
# the fork class this repo keeps shipping.
probe=$(mktemp -d); : > "$probe/$(basename "$disc")"
eq "harness: \$TMP_GLOB matches the name the script itself built" "$probe/$(basename "$disc")" \
   "$(find "$probe" -name "$TMP_GLOB" | tr '\n' ' ' | sed 's/ *$//')"
rm -rf "$probe"

# --- a write that cannot complete fails loudly -------------------------------
# An unparseable declared file makes read_json_field fail on the SECOND site, after
# the first has already been rewritten.
#
# THIS BLOCK USED TO ASSERT ONLY THE rc, and said so: the bump was partial —
# pkg/plugin.json kept the new version while marketplace.json kept the old — which
# manufactured precisely the drift this script exists to prevent, and pinning that
# on-disk state would have made an atomic-bump fix look like a regression. cmd_bump
# now stages every site before committing any, so the on-disk state IS the property
# and is pinned below. The rc assertion is left exactly as it was rather than
# tightened, so it keeps holding whether the bump is atomic or merely loud.
F=$(mkfix); printf 'not json\n' > "$F/pkg/marketplace.json"
bad_rc=$(rc_of "$F" 8.8.8)
eq "bump: an unparseable declared file is not reported as success" "yes" \
   "$([ "$bad_rc" -ne 0 ] && echo yes || echo no)"
# The rc assertion above is unchanged and deliberately still only says "not success".
# What follows is the atomicity property, added rather than folded into it: BEFORE the
# two-phase rewrite this run left pkg/plugin.json at 8.8.8 and marketplace.json at the
# old version — measured, not inferred. Non-vacuity: deleting the rollback loop from
# cmd_bump leaves the version assertion green and turns the temp assertion red;
# reverting the stage/commit split turns the version assertion red.
eq "bump: inter-file failure leaves the FIRST site unmoved" "7.7.7" \
   "$(jq -r .version "$F/pkg/plugin.json")"
eq "bump: inter-file failure leaves no .tmp. behind" "" \
   "$(find "$F" -name "$TMP_GLOB" | tr '\n' ' ' | sed 's/ *$//')"

# --- a failure BETWEEN two fields of the SAME file ---------------------------
# THE CASE A FILE-TO-FILE COMPARISON CANNOT SEE. pkg/marketplace.json is declared
# twice, so a failure on the third site used to commit metadata.version and leave
# plugins.0.version behind — one file disagreeing with itself. `--check` does catch
# that state, because it iterates declared SITES rather than files (measured: DRIFT,
# rc 1); what it defeats is any file-level diff, and the defect is that the bump
# produced it at all.
#
# `plugins.0.version|length` reaches the third site's WRITE specifically: `jq -r
# '.plugins[0].version|length'` returns 5 at rc 0, so staging gets past the read, while
# `.plugins[0].version|length = $v` is an invalid path expression and exits 5. The two
# sites before it stage cleanly, which is the point — the abort has something to roll
# back. Measured before the fix: metadata.version 8.8.8, plugins[0].version 7.7.7.
F=$(mkfix)
cat > "$F/.version-bump.json" <<'EOF'
{
  "files": [
    {"path": "pkg/plugin.json",      "field": "version"},
    {"path": "pkg/marketplace.json", "field": "metadata.version"},
    {"path": "pkg/marketplace.json", "field": "plugins.0.version|length"}
  ],
  "audit": { "exclude": [".git"] }
}
EOF
intra_rc=$(rc_of "$F" 8.8.8)
eq "bump: same-file failure is not reported as success" "yes" \
   "$([ "$intra_rc" -ne 0 ] && echo yes || echo no)"
eq "bump: same-file failure leaves metadata.version unmoved" "7.7.7" \
   "$(jq -r .metadata.version "$F/pkg/marketplace.json")"
eq "bump: same-file failure leaves plugins[0].version unmoved" "7.7.7" \
   "$(jq -r '.plugins[0].version' "$F/pkg/marketplace.json")"
eq "bump: same-file failure leaves the OTHER declared file unmoved" "7.7.7" \
   "$(jq -r .version "$F/pkg/plugin.json")"
eq "bump: same-file failure leaves no .tmp. behind" "" \
   "$(find "$F" -name "$TMP_GLOB" | tr '\n' ' ' | sed 's/ *$//')"

# --- a SKIP survives a later abort -------------------------------------------
# REGRESSION PIN, and the regression was introduced by the atomicity fix itself.
# Moving the per-site rows into a buffer printed after the commit was right for the
# "old -> new" rows, which would otherwise claim moves that had not happened — but it
# swallowed `SKIP (missing)` too, so a declared file that was absent vanished from the
# output on exactly the runs that aborted. A SKIP is a statement about the tree, not a
# claim about a write; it prints immediately. Verified by mutation: buffering it into
# $report again turns this red while every other assertion stays green.
F=$(mkfix)
cat > "$F/.version-bump.json" <<'EOF'
{
  "files": [
    {"path": "pkg/absent.json",      "field": "version"},
    {"path": "pkg/marketplace.json", "field": "metadata.version|length"}
  ],
  "audit": { "exclude": [".git"] }
}
EOF
skip_out=$(out_of "$F" 8.8.8)
eq "bump: a missing declared file is still reported when a later site aborts" "yes" \
   "$(printf '%s\n' "$skip_out" | grep -q 'SKIP (missing) pkg/absent.json' && echo yes || echo no)"
eq "bump: that run still aborts loudly" "yes" \
   "$(printf '%s\n' "$skip_out" | grep -q 'ABORTED' && echo yes || echo no)"

# --- a jq that fails DURING the write leaves no temp -------------------------
# The branch the success-path assertion above cannot reach. `stage_json_field`'s
# redirection creates the .work file before jq runs, so a jq that then fails skips
# the `mv` and that file survives unless the `|| { rm -f "$work"; }` branch removes
# it. An orphaned temp beside a manifest is a second copy of release metadata that
# nothing declares — the drift condition, spelled differently.
#
# REACHING IT TAKES A FIELD THAT READS BUT CANNOT BE ASSIGNED TO. cmd_bump calls
# read_json_field first and `set -e` aborts on its failure, so every way of
# breaking the *file* fails before any write. `version|length` splits the two:
# `jq -r '.version|length'` returns 5 at rc 0, while `.version|length = $v` is an
# invalid path expression and exits 5 — with the temp already on disk.
#
# Non-vacuity: deleting `rm -f "$work"` from stage_json_field turns this red in both
# shells and leaves every other assertion in the file green. Re-run that mutation if
# the helper is renamed again — a non-vacuity note naming a function that no longer
# exists is a record of a check nobody has performed.
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
   "$(find "$F" -name "$TMP_GLOB" | tr '\n' ' ' | sed 's/ *$//')"

# --- argument handling -------------------------------------------------------
F=$(mkfix)
eq "an unknown flag is rejected"                   "1"   "$(rc_of "$F" --nope)"
eq "no argument prints usage and succeeds"         "0"   "$(rc_of "$F")"

printf '\npassed=%s failed=%s\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
