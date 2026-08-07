#!/bin/bash
# frontmatter.sh — the single definition of reading a YAML frontmatter field.
#
# Sourced by skill templates and by the plugin's own skills. Do NOT inline copies
# of these functions anywhere.
#
# THAT SENTENCE IS NOW ENFORCED FOR THIS LIBRARY, AND STILL IS NOT FOR THE LINK
# ONE — do not read the two as equivalent. check-portability.sh runs seven checks
# — PCRE grep, wiki-link capture using negated classes, PCRE via ripgrep, the
# frozen skill-blocks manifest, AGENTS.md being a symlink, interpolated wiki-link
# matchers, and (check 7) hand-rolled frontmatter parsing outside this file.
#
# WHAT CHECK 7 ACTUALLY COVERS, stated narrowly because the previous version of
# this paragraph was a claim nobody had verified and it was false for months: it
# flags a line-anchored `'^field:'` grep used to select or count notes — a
# hand-rolled list_notes_by_field. It does NOT detect a copied-out awk parser,
# an unanchored or double-quoted equivalent, or an inlined copy of
# link-extraction.sh, which remains convention only.
#
# It is born red at 71 allowlisted sites, so a green run means "no NEW
# hand-rolled parse", not "none exists". (That phrase is on ONE line on purpose:
# check-doc-claims gates the number, and a sed anchor cannot span a hard wrap.) The residue is owned by the CI-hardening spec. That 71 is GATED — see
# the check-7 rows in check-doc-claims.sh, which read this file too; the number
# stood at 39 here for one commit after the detector was widened, then at 74
# until three sites converted to this library's own `list_notes_by_field` on
# fix/spec-h-enforcement-gap, which is why it moves again here.
#
# Writing or editing a SKILL.md? Read reference/skill-authoring.md first.
#
# WHY THIS EXISTS
# ---------------
# Three sites each spelled frontmatter extraction as `grep -rl '^status: pending'`
# over a directory of notes. That form answers a DIFFERENT question than the one
# its callers ask: it matches a line-anchored `status:` ANYWHERE in the file,
# including inside a fenced code block in the body. A note documenting the schema
# by showing `status: pending` in a ```yaml example counts as a pending note.
#
# Measured on a four-note fixture (one frontmatter `status`, one body-fenced
# `status` at column 0, one nested with frontmatter `status`, one with no
# frontmatter at all), the true count of notes MISSING the field is 2 and the
# naive form yields 1. That fixture lives in reference/test/fence-isolation.test.sh
# and is asserted three ways on every run.
#
# WHAT COUNTS AS FRONTMATTER HERE — the rules, all deliberate:
#   1. STRICT DELIMITERS. Frontmatter is the block between a `---` on line 1 and
#      the next `---`. A file whose first line is not `---` has no frontmatter, and
#      neither does one that opens a block and never closes it. Leniency (treating
#      a leading run of `key: value` lines as frontmatter) would reintroduce exactly
#      the ambiguity this library removes, and it would misclassify the "no
#      frontmatter at all" case that the fixture depends on.
#   2. TOP-LEVEL KEYS ONLY. The key must start at column 0. An indented `status:`
#      is a member of some parent mapping, not the note's own field.
#   3. NO REGEX ON THE FIELD NAME. Matching uses index(), so a field name
#      containing regex metacharacters cannot silently change what is matched.
#   4. LAST DECLARATION WINS if a key appears twice. YAML calls duplicate keys an
#      error; this library does not fail on them, it resolves them, and says so
#      rather than leaving the behavior undiscovered.
#   5. RECURSIVE BY DEFAULT. The directory helpers scan a tree, because a vault
#      directory with no subdirectories today may grow one tomorrow and a flat scan
#      under-reports silently rather than failing. This is the lesson already
#      written into link-extraction.sh; it applies here unchanged.
#
# NOT HANDLED, on purpose: trailing YAML comments (`status: open # why`) are part
# of the value, and multi-line/flow values are returned verbatim. No caller needs
# either, and guessing at them would add failure modes without adding a user.
#
# TWO NAMED SEMANTIC CHANGES vs the `grep -rl '^status: pending'` form this replaced.
# Both are deliberate. Both are stated here because a converted caller inherits them
# whether or not whoever converted it noticed, and one of them is LIVE on real data.
#
#   A. VALUES MATCH EXACTLY, where the naive form matched prefixes. `^status: pending`
#      also matches `pending-review`; this library compares with `=`. Measured on the
#      field vault: no disagreement (observations 14/14, tensions 8/8), because no value
#      in use is a prefix of another. Latent, but real.
#
#      Re-derive BOTH halves. Note the `find` -- these helpers are recursive, and an
#      earlier version of this list was taken with a flat `"$d"/*.md` glob, which missed
#      ops/tensions/archive/ entirely and omitted `promoted`. A flat probe of a recursive
#      function is the same class of error this library exists to remove:
#
#        . reference/lib/frontmatter.sh
#        for d in ~/second-brain/ops/observations ~/second-brain/ops/tensions; do
#          printf '%-14s naive=%s lib=%s\n' "$(basename "$d")" \
#            "$(grep -rl '^status: pending\|^status: open' "$d" | wc -l | tr -d ' ')" \
#            "$(count_notes_by_field "$d" status pending open)"
#          find "$d" -type f -name '*.md' | while IFS= read -r f; do
#            frontmatter_field "$f" status; done
#        done | sort | uniq -c
#        # observations naive=14 lib=14; tensions naive=8 lib=8
#        # values: open 22, implemented 22, promoted 8, archived 8, resolved 5
#
#   B. AN UNCLOSED FRONTMATTER BLOCK IS NOT FRONTMATTER (rule 1 above), where the
#      naive form did not care. **This one changes a count on real data today.**
#      `~/second-brain/ops/methodology/prioritize-dissenting-viewpoints.md` opens
#      `---` at line 1, never closes it, and carries `status: active` at line 7.
#      `generators/features/methodology-knowledge.md:31` ships
#      `rg '^status: active' ops/methodology/` to generated vaults for exactly that
#      directory: the recipe counts 13 files, this library counts 12, and that file is
#      the whole difference.
#
#      So converting those generator recipes is NOT a relocation. It is a behavior
#      change that will move a number, and the number moves because a real file is
#      malformed. Whoever takes it decides which answer is right -- fix the file, or
#      have the library tolerate an unclosed block -- and should not discover the
#      question by watching a count drop. Re-derive:
#
#        . reference/lib/frontmatter.sh
#        rg -l '^status: active' ~/second-brain/ops/methodology/ | wc -l   # 13
#        count_notes_by_field ~/second-brain/ops/methodology status active # 12

# Contract version. Bump on any BEHAVIOR change (delimiter rules, key matching,
# quote stripping, recursion semantics). Callers and /arscontexta:upgrade read it.
FRONTMATTER_VERSION=3

# _fm_require_deps_and_dir validates required commands and confirms that the directory exists, is readable, and is traversable.
_fm_require_deps_and_dir() { # _fm_require_deps_and_dir <dir>
  local dir="$1"
  if ! command -v awk >/dev/null 2>&1; then
    echo "error: frontmatter: requires 'awk', not found in PATH" >&2
    return 1
  fi
  if ! command -v find >/dev/null 2>&1; then
    echo "error: frontmatter: requires 'find', not found in PATH" >&2
    return 1
  fi
  if [ -z "$dir" ] || [ ! -d "$dir" ]; then
    echo "error: frontmatter: not a directory: '${dir:-<empty>}'" >&2
    return 1
  fi
  # EXISTENCE IS NOT ACCESS, and the difference is a silent wrong answer. `-d`
  # succeeds on a directory this process cannot read or traverse; `find` then
  # prints "Permission denied" to stderr and exits 0, so every counting function
  # here returned rc 0 with ZERO matches — a scan that could not run, reported
  # as a scan that found nothing. Callers that check the rc (validate-kernel's
  # C1) were made dead code by it. This is the same defect as testing `[ -f ]`
  # for a config file the process cannot open, fixed in read_config.sh for the
  # same reason: the two states are indistinguishable downstream.
  if [ ! -r "$dir" ] || [ ! -x "$dir" ]; then
    echo "error: frontmatter: directory not readable: '$dir'" >&2
    echo "       refusing to report a count over a directory this process cannot scan" >&2
    return 1
  fi
  return 0
}

# frontmatter_field <file> <field> -> value on stdout
#   rc 0  field present in frontmatter (value may be the empty string)
#   rc 1  no frontmatter, unclosed frontmatter, or field absent
#
# The three rc-1 cases are deliberately NOT distinguished: every caller so far asks
# "does this file declare <field> as <value>", for which all three answer no.
frontmatter_field() {
  local file="$1" field="$2"
  if [ -z "$field" ]; then
    echo "error: frontmatter: frontmatter_field requires a field name" >&2
    return 1
  fi
  if [ -z "$file" ] || [ ! -r "$file" ]; then
    echo "error: frontmatter: not a readable file: '${file:-<empty>}'" >&2
    return 1
  fi
  awk -v key="$field" '
    BEGIN { sq = sprintf("%c", 39) }          # single quote, unquotable in this program
    NR == 1 { if ($0 !~ /^---[[:space:]]*$/) exit 1; in_fm = 1; next }
    in_fm && /^---[[:space:]]*$/ { in_fm = 0; closed = 1; exit }
    in_fm && index($0, key ":") == 1 {
      v = substr($0, length(key) + 2)
      sub(/^[[:space:]]+/, "", v)
      sub(/[[:space:]]+$/, "", v)
      q = substr(v, 1, 1)
      if (length(v) > 1 && (q == "\"" || q == sq) && substr(v, length(v), 1) == q)
        v = substr(v, 2, length(v) - 2)
      val = v; found = 1
    }
    END { if (!closed || !found) exit 1; print val }
  ' "$file"
}

# list_notes_by_field <dir> <field> <value>... -> matching file paths, one per line
# Recursive. Emits nothing and returns 0 when the tree holds no match.
# list_notes_by_field recursively prints Markdown file paths whose frontmatter field matches any supplied value.
# It returns a nonzero status if the field or values are missing or the directory tree cannot be fully scanned.
# The field and values are provided after the directory path.
list_notes_by_field() {
  _fm_require_deps_and_dir "$1" || return 1
  local dir="$1" field="$2" errf p fm_val want
  shift 2
  if [ -z "$field" ] || [ $# -eq 0 ]; then
    echo "error: frontmatter: list_notes_by_field needs <dir> <field> <value>..." >&2
    return 1
  fi
  errf="/tmp/frontmatter-err-$$"
  rm -f "$errf"

  # The loop runs in a subshell, so it cannot set a variable the caller reads --
  # a failure signalled by a flag inside it would be discarded and the caller would
  # see a short list as a legitimately short list. The touch-file is how
  # link-extraction.sh solves the same problem; the alternative is silence.
  # -H FOLLOWS A SYMLINK GIVEN ON THE COMMAND LINE, and without it this function
  # certifies a path it then does not scan. Both directory-scanning functions in
  # this file carry it. `test -r`/`-x` dereference, so a
  # symlinked directory passes the guard above; `find <symlink>` without -H does
  # NOT descend, so the scan returned 0 notes at rc 0 — a plausible zero over a
  # directory that has content. Measured on a 2-note fixture: real dir 2,
  # symlink to it 0. Every caller inherits it, and validate-kernel's C1 would
  # print its green "no note has reached an outcome status yet" over a vault
  # whose observations directory is a symlink.
  #
  # FIND'S OWN rc IS CHECKED, because an unreadable SUBdirectory is not the case
  # the touch-file below covers. That mechanism catches unreadable FILES; a
  # directory one level down that cannot be traversed makes find print
  # "Permission denied" to stderr and exit non-zero, while the pipeline's status
  # is the `while`'s — so the count came back short at rc 0. The guard at the top
  # of this function checks the ROOT only, and its message claimed more than that.
  # Measured: 2-note fixture with one note under a chmod-000 subdirectory
  # returned count=1 rc=0.
  _fm_list=$(find -H "$dir" -type f -name '*.md' 2>/dev/null); _fm_find_rc=$?
  if [ "$_fm_find_rc" -ne 0 ]; then
    rm -f "$errf"
    echo "error: frontmatter: cannot fully traverse '$dir' (find rc=$_fm_find_rc)" >&2
    echo "       refusing to report a count that would silently be short" >&2
    return 1
  fi
  printf '%s\n' "$_fm_list" | while IFS= read -r p; do
    [ -n "$p" ] || continue
    if [ ! -r "$p" ]; then
      touch "$errf"
      continue
    fi
    fm_val=$(frontmatter_field "$p" "$field" 2>/dev/null) || continue
    for want in "$@"; do
      if [ "$fm_val" = "$want" ]; then
        printf '%s\n' "$p"
        break
      fi
    done
  done

  if [ -e "$errf" ]; then
    rm -f "$errf"
    echo "error: frontmatter: unreadable file under '$dir'; refusing to report a count" >&2
    return 1
  fi
  return 0
}

# count_notes_by_field <dir> <field> <value>... -> integer
count_notes_by_field() {
  local out
  # Declared first, assigned second, ON PURPOSE. `local out=$(f)` yields `local`'s
  # exit status, which is 0 even when f failed -- so a failed scan would be read as
  # a count of zero, the exact silent failure this library exists to remove.
  out=$(list_notes_by_field "$@") || return 1
  if [ -z "$out" ]; then
    printf '0'
  else
    printf '%s\n' "$out" | wc -l | tr -d ' '
  fi
}

# count_notes_missing_field <dir> <field> -> integer
# Files under <dir> that do NOT declare <field> in frontmatter -- which includes
# files with no frontmatter at all. This is the dual of count_notes_by_field, and
# it is the function the three-way fixture assertion keys on: only a parser that
# actually reads the requested FIELD NAME can distinguish "missing status" from
# "missing some-field-nothing-declares".
count_notes_missing_field() {
  _fm_require_deps_and_dir "$1" || return 1
  local dir="$1" field="$2" errf missing p
  if [ -z "$field" ]; then
    echo "error: frontmatter: count_notes_missing_field needs <dir> <field>" >&2
    return 1
  fi
  errf="/tmp/frontmatter-err-$$"
  rm -f "$errf"

  # -H AND THE find-rc CHECK, same as list_notes_by_field. This function did NOT
  # get them when v3 landed, and v3's own comment said "Every caller inherits it"
  # — false for the function 45 lines below it in the same file. Measured before
  # this fix, on a 2-note fixture: symlinked dir 0 (truth 1), note under a
  # chmod-000 subdirectory counted short at rc 0.
  _fm_list=$(find -H "$dir" -type f -name '*.md' 2>/dev/null); _fm_find_rc=$?
  if [ "$_fm_find_rc" -ne 0 ]; then
    rm -f "$errf"
    echo "error: frontmatter: cannot fully traverse '$dir' (find rc=$_fm_find_rc)" >&2
    echo "       refusing to report a count that would silently be short" >&2
    return 1
  fi
  missing=$(printf '%s\n' "$_fm_list" | while IFS= read -r p; do
    [ -n "$p" ] || continue
    if [ ! -r "$p" ]; then
      touch "$errf"
      continue
    fi
    frontmatter_field "$p" "$field" >/dev/null 2>&1 || printf 'x\n'
  done | wc -l | tr -d ' ')

  if [ -e "$errf" ]; then
    rm -f "$errf"
    echo "error: frontmatter: unreadable file under '$dir'; refusing to report a count" >&2
    return 1
  fi
  printf '%s' "$missing"
}
