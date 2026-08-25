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
# AND ONE THIS PORT INTRODUCED WHILE CLAIMING TO HAVE REMOVED THE CLASS: the loops
# read into `path`, which is zsh's array tied to PATH. `zsh bump-version.sh --check`
# set PATH=.claude-plugin/plugin.json and died at rc 127 with "command not found:
# jq". Renamed to `vpath`. The lesson is not "avoid $path" — it is that writing a
# comment about removing a bug class is not the same as removing it, and only CI
# ran the bash form. Other zsh-special names to avoid as read targets: status,
# argv, cdpath, manpath, module_path, options, prompt, fignore, psvar, watch.
#
set -eu

# Captured once at top level. Staged temps are named from it and removed by name,
# and `$$` read inside a subshell is not guaranteed to be the same number in every
# shell — the staging and rollback loops must agree on the filename.
BUMP_PID=$$

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$REPO_ROOT/.version-bump.json"

command -v jq >/dev/null 2>&1 || { echo "error: jq is required" >&2; exit 1; }
[ -f "$CONFIG" ] || { echo "error: .version-bump.json not found at $CONFIG" >&2; exit 1; }

# "plugins.0.version" -> ".plugins[0].version"
jq_path() { printf '.%s' "$1" | sed -E 's/\.([0-9]+)(\.|$)/[\1]\2/g'; }

read_json_field()  { jq -r "$(jq_path "$2")" "$1"; }
# stage_json_field <source> <field> <value> <destination>
# Reads $1, sets $2 to $3, leaves the result at $4. Nothing else on disk moves.
#
# --arg, not string interpolation: splicing $3 into the jq program makes a value
# containing a quote into jq source. `bump-version.sh '1.2.3" as $v | halt_error(9) #'`
# exited 9.
#
# THE .work INTERMEDIATE IS NOT REDUNDANT WITH $4. Two of the three declared sites
# are fields in the SAME file, so the second edit is staged FROM the first edit's
# temp — $1 and $4 are then the same path, and redirecting straight into $4 would
# truncate the file jq is reading. The rm keeps a failed jq from leaving a .work
# behind, since the redirection creates it before jq runs and && skips the mv.
stage_json_field() {
  work="$4.work"
  jq --arg v "$3" "$(jq_path "$2") = \$v" "$1" > "$work" && mv "$work" "$4" || { rm -f "$work"; return 1; }
}
declared_files() { jq -r '.files[] | "\(.path)\t\(.field)"' "$CONFIG"; }

# TEXT SITES: version strings that are not JSON fields. README carries a `**v0.9.9**`
# badge and every SKILL.md carries `generated_from: "arscontexta-<ver>"`; neither can be
# addressed by a jq path, and both drifted for exactly that reason -- the stamps were set
# in the initial release and never moved again while the manifests went 0.8.0 -> 0.9.9.
#
# A site is declared by LITERAL prefix and suffix, not by a regex. Patterns would live in
# JSON, where every backslash doubles, and a mis-escaped pattern matches nothing while
# reporting the same success as a correct one.
#
# Globs are expanded with `find -path` rather than a shell glob: zsh aborts a command on a
# non-matching glob where bash passes the pattern through, and neither shell word-splits
# the result the same way. `find` yields one path per line and a while-read consumes it
# without splitting at all.
declared_text() {
  jq -r '.text[]? | "\(.glob)\t\(.prefix)\t\(.suffix)"' "$CONFIG" |
  while IFS="$(printf '\t')" read -r glob pre suf; do
    [ -n "$glob" ] || continue
    find "$REPO_ROOT" -path "$REPO_ROOT/$glob" -type f 2>/dev/null | sort |
    while IFS= read -r abs; do
      printf '%s\t%s\t%s\n' "${abs#"$REPO_ROOT"/}" "$pre" "$suf"
    done
  done
}

# THE VERSION SHAPE IS THE GUARD, and it is the whole reason this reads a value before
# rewriting it. `skills/setup/SKILL.md` carries seven `generated_from: "arscontexta-{version}"`
# lines that setup substitutes at generation time; they match the same prefix and suffix as
# a real stamp. Rewriting one would replace the mechanism with a frozen literal and every
# vault generated afterwards would carry this repo's version instead of its own -- silently,
# because the result still looks like a stamp. A value that is not version-shaped is not a
# site, and both readers below skip it.
VERSION_SHAPE='^v?[0-9]+(\.[0-9]+)+$'

read_text_field() {   # read_text_field <file> <prefix> <suffix> -> first version-shaped value
  awk -v pre="$2" -v suf="$3" -v shape="$VERSION_SHAPE" '
    index($0, pre) == 1 {
      rest = substr($0, length(pre) + 1)
      p = index(rest, suf)
      if (p > 0) { v = substr(rest, 1, p - 1); if (v ~ shape) { print v; exit } }
    }' "$1"
}

# rc 3 means "no version-shaped site in this file" -- not a failure. setup is placeholder-only
# and must stage cleanly as a no-op; collapsing that into rc 1 would abort every bump.
stage_text_field() {  # stage_text_field <src> <prefix> <suffix> <new> <out>
  work="$5.work"; rm -f "$work"
  awk -v pre="$2" -v suf="$3" -v new="$4" -v shape="$VERSION_SHAPE" '
    { line = $0
      if (index(line, pre) == 1) {
        rest = substr(line, length(pre) + 1)
        p = index(rest, suf)
        if (p > 0) {
          v = substr(rest, 1, p - 1)
          if (v ~ shape) { line = pre new substr(rest, p); changed++ }
        }
      }
      print line
    }
    END { if (changed == 0) exit 3 }
  ' "$1" > "$work"
  rc=$?
  if [ "$rc" -eq 3 ]; then rm -f "$work"; return 3; fi
  [ "$rc" -eq 0 ] || { rm -f "$work"; return 1; }
  mv "$work" "$5" || { rm -f "$work"; return 1; }
  return 0
}

declared_paths() { { jq -r '.files[].path' "$CONFIG"; declared_text | cut -f1; } | sort -u; }

# The version the declared files agree on, or the most common if they do not.
current_version() {
  declared_files | while IFS="$(printf '\t')" read -r vpath field; do
    [ -f "$REPO_ROOT/$vpath" ] && read_json_field "$REPO_ROOT/$vpath" "$field"
  done | sort | uniq -c | sort -rn | head -1 | awk '{print $2}'
}

cmd_check() {
  drift=0
  seen=""
  echo "Version check:"
  while IFS="$(printf '\t')" read -r vpath field; do
    if [ ! -f "$REPO_ROOT/$vpath" ]; then
      printf '  %-46s MISSING\n' "$vpath ($field)"; drift=1; continue
    fi
    ver=$(read_json_field "$REPO_ROOT/$vpath" "$field")
    # jq prints the string "null" at exit 0 for a field path that does not exist,
    # so an unvalidated read lets three wrong paths agree at "null" and report
    # success. A version must look like a version.
    case "$ver" in
      [0-9]*.[0-9]*.[0-9]*) ;;
      *) printf '  %-46s NOT A VERSION: %s\n' "$vpath ($field)" "$ver"; drift=1; continue ;;
    esac
    printf '  %-46s %s\n' "$vpath ($field)" "$ver"
    seen="$seen$ver
"
  done <<EOF
$(declared_files)
EOF
  while IFS="$(printf '\t')" read -r vpath pre suf; do
    [ -n "$vpath" ] || continue
    if [ ! -f "$REPO_ROOT/$vpath" ]; then
      printf '  %-46s MISSING\n' "$vpath (text)"; drift=1; continue
    fi
    ver=$(read_text_field "$REPO_ROOT/$vpath" "$pre" "$suf")
    # Empty means no version-shaped value in the file -- a placeholder-only template such
    # as setup. Not a site, not drift, and not worth a row: reporting it would put a
    # permanent non-finding in the output every reader has to learn to ignore.
    [ -n "$ver" ] || continue
    printf '  %-46s %s\n' "$vpath (text)" "$ver"
    seen="$seen$ver
"
  done <<EOF
$(declared_text)
EOF
  distinct=$(printf '%s' "$seen" | sort -u | grep -c . || true)
  if [ "$distinct" -gt 1 ]; then
    echo "DRIFT: declared files disagree —"
    printf '%s' "$seen" | sort | uniq -c | sed 's/^/    /'
    drift=1
  elif [ "$distinct" -eq 1 ] && [ "$drift" -eq 0 ]; then
    printf 'All declared files agree at %s\n' "$(printf '%s' "$seen" | sort -u)"
  elif [ "$distinct" -eq 1 ]; then
    # The readable entries agree, but a row above said MISSING or NOT A VERSION.
    # "All declared files agree" over such a row contradicts the thing it summarises,
    # and the summary is the line a reader skims.
    printf 'INCOMPLETE: the readable entries agree at %s, but a row above did not read\n' \
      "$(printf '%s' "$seen" | sort -u)"
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
  # `hits=$(...); rc=$?` does NOT work under `set -e`: they are two commands, and a
  # failing substitution in an assignment aborts the shell before rc is ever read,
  # so the branch below was unreachable and a real scan error exited 2 with only a
  # header printed. `|| rc=$?` keeps the assignment inside a list, which suspends
  # set -e and lets the status be inspected.
  rc=0
  hits=$(cd "$REPO_ROOT" && grep "$@" . 2>/dev/null) || rc=$?
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
  # Anchored at both ends. Without the $, "1.2.3junk", "1.2.3.4" and "1.2.3-rc1"
  # all passed and were written verbatim into every manifest.
  printf '%s' "$new" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' || {
    echo "error: '$new' is not X.Y.Z" >&2; exit 1; }
  old=$(current_version)
  printf 'Bumping declared files %s -> %s\n' "$old" "$new"

  # TWO PHASES, AND THE BARRIER BETWEEN THEM IS THE WHOLE POINT. Every declared site
  # is rewritten into a temp first; no declared file is modified until every site has
  # staged successfully. Before this, cmd_bump called the write helper unguarded under
  # `set -e`, so a failure on a later site aborted with the earlier ones already
  # rewritten — the script manufacturing the exact drift it exists to prevent. Measured
  # on a three-site fixture: an unparseable second file left the first at the new
  # version and the second at the old one.
  #
  # STAGING IS KEYED ON PATH, NOT ON SITE, and that distinction is load-bearing rather
  # than tidy. .claude-plugin/marketplace.json is declared TWICE (metadata.version and
  # plugins.0.version), so the second edit is staged from the first edit's temp. Staging
  # both from the original file instead would leave the second temp carrying only its
  # own edit, and committing it would silently discard metadata.version — a fix that
  # looks atomic and loses data. That mutation is pinned: it turns the
  # "marketplace metadata.version moved" assertion red.
  staged_paths=""
  stage_fail=""
  report=""
  while IFS="$(printf '\t')" read -r vpath field; do
    [ -n "$vpath" ] || continue
    # Printed immediately, unlike the per-site rows below. A SKIP is a statement about
    # the tree, not a claim about a write, so it stays true whatever a later site does
    # — and buffering it into $report meant a missing first site vanished from the
    # output whenever a later site aborted, which is the one run where you most want
    # to know a declared file was absent.
    if [ ! -f "$REPO_ROOT/$vpath" ]; then printf '  SKIP (missing) %s\n' "$vpath"; continue; fi
    tmp="$REPO_ROOT/$vpath.tmp.$BUMP_PID"
    # THE SOURCE IS CHOSEN BY WHAT THIS RUN HAS STAGED, NOT BY WHAT IS ON DISK. Chain
    # onto our own temp so a file with two declared fields keeps both edits — but a
    # temp we did NOT write is debris, and reading it would bump a stale base and say
    # nothing. `$$` is recycled by the OS, so a temp bearing our PID can be the
    # leftover of an earlier run that was killed before it could roll back.
    # -x and -F are both load-bearing below: a path is appended once, and matching must
    # be whole-line and literal. Plain `grep -F` would treat an already-staged path as
    # covering any path it is a substring of, and never stage the second file.
    if printf '%s\n' "$staged_paths" | grep -qxF "$vpath"; then
      src="$tmp"; already_staged=yes
    else
      src="$REPO_ROOT/$vpath"; rm -f "$tmp" "$tmp.work"; already_staged=no
    fi
    was=$(read_json_field "$src" "$field") || {
      stage_fail="$vpath ($field) could not be read"; break; }
    stage_json_field "$src" "$field" "$new" "$tmp" || {
      stage_fail="$vpath ($field) could not be written"; break; }
    [ "$already_staged" = yes ] || staged_paths="$staged_paths$vpath
"
    report="$report$(printf '  %-46s %s -> %s' "$vpath ($field)" "$was" "$new")
"
  done <<EOF
$(declared_files)
EOF

  # Text sites stage into the SAME temps and join the SAME staged_paths list, so the
  # rollback and commit phases below cover them without knowing they are a different kind
  # of site. Skipped entirely if JSON staging already failed -- the barrier is the point.
  if [ -z "$stage_fail" ]; then
  while IFS="$(printf '\t')" read -r vpath pre suf; do
    [ -n "$vpath" ] || continue
    if [ ! -f "$REPO_ROOT/$vpath" ]; then printf '  SKIP (missing) %s\n' "$vpath"; continue; fi
    tmp="$REPO_ROOT/$vpath.tmp.$BUMP_PID"
    if printf '%s\n' "$staged_paths" | grep -qxF "$vpath"; then
      src="$tmp"; already_staged=yes
    else
      src="$REPO_ROOT/$vpath"; rm -f "$tmp" "$tmp.work"; already_staged=no
    fi
    was=$(read_text_field "$src" "$pre" "$suf")
    # `|| trc=$?` and not `; trc=$?`: under set -e a non-zero return aborts the shell
    # before the status is ever read, which is the trap cmd_audit documents at length.
    trc=0
    stage_text_field "$src" "$pre" "$suf" "$new" "$tmp" || trc=$?
    # rc 3 is "nothing version-shaped here" -- a no-op, not a failure.
    if [ "$trc" -eq 3 ]; then
      [ "$already_staged" = yes ] || rm -f "$tmp" "$tmp.work"
      continue
    fi
    [ "$trc" -eq 0 ] || { stage_fail="$vpath (text) could not be written"; break; }
    [ "$already_staged" = yes ] || staged_paths="$staged_paths$vpath
"
    report="$report$(printf '  %-46s %s -> %s' "$vpath (text)" "$was" "$new")
"
  done <<EOF
$(declared_text)
EOF
  fi

  if [ -n "$stage_fail" ]; then
    # Discard every staged temp. One left beside a manifest is a second copy of release
    # metadata that nothing declares — the drift condition again, spelled differently.
    printf 'ABORTED: %s\n' "$stage_fail" >&2
    echo '  no declared file was modified; every staged write was discarded' >&2
    while IFS= read -r spath; do
      [ -n "$spath" ] || continue
      # Named, not merely removed. A cleanup nobody can see is indistinguishable from
      # one that did not happen — and printing the real filename is the only place the
      # script's own temp naming is observable from outside, which is what lets a test
      # confirm its `find` pattern matches what this script actually writes.
      for dead in "$REPO_ROOT/$spath.tmp.$BUMP_PID" "$REPO_ROOT/$spath.tmp.$BUMP_PID.work"; do
        [ -e "$dead" ] || continue
        rm -f "$dead" && printf '  discarded: %s\n' "${dead#"$REPO_ROOT"/}" >&2
      done
    done <<EOF
$staged_paths
EOF
    return 1
  fi

  # COMMIT. A sequence of renames, not a transaction — each temp is already a complete,
  # valid file in the same directory as its target, so a failure here is ENOSPC/EROFS/
  # EACCES and not anything about the version. If one does fail, name the paths that did
  # not land rather than reporting a bump that half happened.
  commit_fail=""
  while IFS= read -r spath; do
    [ -n "$spath" ] || continue
    # STOP AT THE FIRST FAILURE. Continuing would move MORE declared files away from
    # the state they share with the one that failed, maximising the divergence instead
    # of bounding it.
    mv "$REPO_ROOT/$spath.tmp.$BUMP_PID" "$REPO_ROOT/$spath" || { commit_fail="$spath"; break; }
  done <<EOF
$staged_paths
EOF
  if [ -n "$commit_fail" ]; then
    printf 'COMMIT FAILED: %s could not be moved into place\n' "$commit_fail" >&2
    echo '  stopped at the first failure; any declared path earlier in this run already moved' >&2
    # EVERY SURVIVING TEMP IS DISCARDED HERE, and that is not tidiness. A staged temp
    # beside a manifest is a complete, undeclared copy of the release metadata — the
    # same drift condition the rollback above exists to prevent — and `--check`, which
    # this message goes on to recommend, iterates declared SITES and cannot see it. A
    # remedy blind to the wreckage its own branch created is worse than no remedy.
    # Each temp is redundant with the file it did not replace, so nothing is lost.
    while IFS= read -r spath; do
      [ -n "$spath" ] || continue
      dead="$REPO_ROOT/$spath.tmp.$BUMP_PID"
      [ -e "$dead" ] || continue
      rm -f "$dead" && printf '  discarded: %s\n' "${dead#"$REPO_ROOT"/}" >&2
    done <<EOF
$staged_paths
EOF
    echo '  the tree is partially bumped; run --check' >&2
    return 1
  fi

  # Printed only now. Reporting a site during staging would claim a move that had not
  # happened, which is the failure mode this rewrite exists to remove.
  printf '%s' "$report"
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
