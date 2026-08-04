#!/usr/bin/env bash
# validate-kernel.sh — Check a knowledge system against the 15 universal primitives
# Usage: ./validate-kernel.sh [path-to-vault]
# Defaults to current directory if no path given.

VAULT="${1:-.}"
PASS=0
WARN=0
FAIL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Source link-extraction library (fails loud if missing)
LINK_LIB="$(cd "$(dirname "$0")" && pwd)/lib/link-extraction.sh"
[ -r "$LINK_LIB" ] || {
  echo "error: link-extraction library not found '$LINK_LIB'" >&2
  echo " plugin structure broken or script moved?" >&2
  exit 1
}
. "$LINK_LIB"

pass() { echo -e "  ${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
warn() { echo -e "  ${YELLOW}WARN${NC} $1"; WARN=$((WARN + 1)); }
fail() { echo -e "  ${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# NOTE-BEARING DIRECTORY RESOLUTION
#
# A generated vault renames its directories -- reference/vocabulary-transforms.md
# exists precisely because it does. Hardcoding canonical names inside a validator
# for a generator whose entire purpose is renaming them is how primitive 2 spent
# its life printing `WARN No wiki links found to check` beside a PASS on every
# vault that took the rename. Derive the names from the vault; never list them.
#
# AUTHORITATIVE SOURCE: the vault's ops/derivation-manifest.md `vocabulary:`
# block. platforms/claude-code/generator.md states that skills read that file at
# runtime for vocabulary transformation, so it is the same mapping the vault's
# own commands already obey, and it is what /upgrade is told to preserve. If this
# validator disagreed with it, the validator would be the thing that is wrong.
#
# Order, first source that yields an EXISTING directory wins:
#   1. ops/derivation-manifest.md  `vocabulary:` -> notes:, inbox:   AUTHORITATIVE
#   2. ops/config.yaml             `vocabulary:` -> notes:, inbox:   fallback
#   3. shape scan: top-level directories holding *.md, minus infrastructure
#   4. nothing resolved -> the caller FAILs and says why. Never WARN, never PASS.
#
# A source that NAMES a directory which does not exist does not count as
# resolved; it falls through to the next source. Resolution means a usable
# directory, not a successfully parsed string. Those two look identical
# downstream, and treating a parsed-but-absent name as success would reproduce
# the original defect one layer up.
#
# WHICH VOCABULARY KEYS ARE READ, AND THE COVERAGE GAP THAT CREATES:
# only `notes:` and `inbox:` — the capture-then-refine pipeline, which is where
# the note graph lives. The field vault's vocabulary block also declares
# `projects:`, `archive:` and `ops:`. Those are excluded: `archive` is cold
# storage whose links are expected to dangle by the same argument as logs below,
# `ops` is operational record, and `projects` holds domain output written
# directly rather than notes reached through the pipeline.
#
# BE AWARE THIS MAKES THE TWO ROUTES DISAGREE, and the disagreement is real
# rather than theoretical. Measured on the field vault, 2026-08-03:
#
#   vocabulary route -> nodes, capture (+ self)                     = 3 dirs
#   shape scan       -> capture, docs, nodes, projects, self, workers = 6 dirs
#
# So two vaults identical but for the presence of a manifest get different
# coverage under the same green PASS. Neither set is obviously right: the
# vocabulary route misses `projects/` (41 unique link targets in the field
# vault), while the shape scan sweeps in `docs/` and `workers/`, which are
# plausibly not note directories at all. Reconciling them is a design question,
# not a bug fix, and it is NOT resolved here. What is fixed is the invisibility:
# every message from this primitive now prints `scanned: <basenames>`, so a
# reader can see which set produced the result instead of inferring it from the
# source label. Do not "just add projects" without deciding what the shape scan
# should do to match.
#
# WHAT IS DELIBERATELY OUT OF SCOPE: logs and operational records. The old list
# carried `04_meta/logs`, and the vocabulary names no logs directory, so a
# derived scan cannot restore it. That is a decision, not an oversight: a wiki
# link inside a session log or a changelog entry is a historical citation, not an
# assertion of graph structure, and it is *expected* to dangle once the note it
# cites is renamed. Counting those as dangling edges would make this primitive
# report a defect for a vault behaving correctly.
# ---------------------------------------------------------------------------

# _vocab_dir <file> <key> -> the directory name declared for <key>, or nothing.
# Reads the `vocabulary:` block: the first `<key>:` line indented under it, with
# optional surrounding quotes. Returns rc 1 when the file has no vocabulary
# block, no such key, or an empty value -- an absent key and a key set to the
# empty string must not look alike to the caller.
#
# The `:` is glued onto the key via -v rather than written as `$1 == key ":"`:
# awk gives concatenation LOWER precedence than comparison, so that spelling
# parses as `($1 == key) ":"` -- a non-empty string, hence always true, matching
# every line in the block.
#
# THE VALUE IS THE REST OF THE LINE, NOT `$2`. Reading `$2` truncated at the
# first space, so `notes: "my notes"` yielded `my`, the `-d` test on it failed,
# and resolution fell through to the shape scan -- silently bypassing the source
# this file's own header calls authoritative, with no error and a plausible
# result. The failure was invisible precisely because the fallback works.
#
# Single quotes are written as \047 rather than escaped through the shell: the
# whole awk program is inside a shell single-quoted string, and the '"'"' dance
# needed to embed one is where this kind of parser usually acquires its next bug.
_vocab_dir() {
    [ -r "$1" ] || return 1
    _vd_out=$(awk -v k="$2:" '
        /^vocabulary:[[:space:]]*$/ { inb = 1; next }
        inb && /^[^[:space:]]/     { inb = 0 }
        inb && $1 == k {
            v = $0
            sub(/^[[:space:]]*[^:]*:[[:space:]]*/, "", v)    # drop the key, keep the value
            if (v ~ /^"/)       { sub(/^"/, "", v);     sub(/".*$/, "", v) }
            else if (v ~ /^\047/) { sub(/^\047/, "", v); sub(/\047.*$/, "", v) }
            else                { sub(/[[:space:]]+#.*$/, "", v) }        # trailing comment
            sub(/[[:space:]]+$/, "", v)
            print v; exit
        }
    ' "$1" 2>/dev/null)
    [ -n "$_vd_out" ] || return 1
    case "$_vd_out" in *..*) return 1 ;; esac   # never let a mapping walk upward
    printf '%s' "$_vd_out"
}

# _dirs_from_vocab <vault> <file> -> existing note-bearing dirs named by <file>
_dirs_from_vocab() {
    _dv_found=""
    [ -r "$2" ] || return 1
    for _dv_key in notes inbox; do
        _dv_name=$(_vocab_dir "$2" "$_dv_key") || continue
        [ -d "$1/$_dv_name" ] || continue
        _dv_found="$_dv_found$1/$_dv_name
"
    done
    [ -n "$_dv_found" ] || return 1
    printf '%s' "$_dv_found"
}

# resolve_note_dirs <vault> -> rc 0 and, on stdout, the source label on line 1
# followed by one directory per line. rc 1 and no output when no source resolves
# an existing directory.
#
# WHY THE LABEL RIDES ON STDOUT INSTEAD OF A VARIABLE: every caller runs this
# inside $( ), which is a subshell, so a `NOTE_DIR_SOURCE=…` assigned in here is
# discarded before the parent ever reads it. The first draft of this function did
# exactly that and every message printed "directories via " with the name
# missing -- the same swallowed-in-a-subshell defect this repo has shipped six
# times. Returning the label through the one channel that does cross the boundary
# removes the trap rather than documenting it.
resolve_note_dirs() {
    if _rn_out=$(_dirs_from_vocab "$1" "$1/ops/derivation-manifest.md"); then
        printf 'ops/derivation-manifest.md vocabulary\n%s' "$_rn_out"; return 0
    fi
    if _rn_out=$(_dirs_from_vocab "$1" "$1/ops/config.yaml"); then
        printf 'ops/config.yaml vocabulary\n%s' "$_rn_out"; return 0
    fi

    # Shape scan. `find -mindepth 1 -maxdepth 1` rather than a "$1"/*/ glob:
    # an unmatched glob is an error under zsh's default nomatch, and this file
    # must survive being invoked as `zsh validate-kernel.sh` -- bump-version.sh
    # shipped a zsh fork for exactly that reason.
    # The `while` runs in a subshell, so it accumulates nothing in a variable;
    # its STDOUT is what the command substitution collects.
    _rn_out=$(find "$1" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while IFS= read -r _rn_d; do
        case "$(basename "$_rn_d")" in
            .*|node_modules|ops|04_meta|archive|templates|_templates) continue ;;
        esac
        [ -n "$(find "$_rn_d" -type f -name '*.md' 2>/dev/null | head -1)" ] || continue
        printf '%s\n' "$_rn_d"
    done)
    if [ -n "$_rn_out" ]; then
        printf 'shape scan (top-level directories containing *.md)\n%s\n' "$_rn_out"; return 0
    fi
    return 1
}

echo "=== Kernel Validation: $VAULT ==="
echo ""

# --- Primitive 1: Markdown files with YAML frontmatter ---
echo "1. Markdown files with YAML frontmatter"
md_files=$(find "$VAULT" -name "*.md" -not -path "*/.git/*" -not -path "*/node_modules/*" -not -name "README.md" -not -name "SKILL.md" -not -name "CLAUDE.md")
md_count=$(echo "$md_files" | grep -c . || true)

if [ "$md_count" -gt 0 ]; then
    yaml_count=$(echo "$md_files" | xargs -I{} head -1 {} 2>/dev/null | grep -c "^---$" || true)
    no_yaml=$((md_count - yaml_count))

    if [ "$no_yaml" -eq 0 ]; then
        pass "$md_count markdown files, all with YAML frontmatter"
    elif [ "$no_yaml" -lt "$((yaml_count / 5 + 1))" ]; then
        warn "$yaml_count with YAML, $no_yaml without (< 20% missing)"
    else
        fail "$no_yaml of $md_count files missing YAML frontmatter"
    fi
else
    fail "No markdown files found"
fi

# --- Primitive 2: Wiki links as graph edges ---
echo "2. Wiki links as graph edges"
link_files=$(grep -rl '\[\[' "$VAULT" --include="*.md" 2>/dev/null | grep -v ".git" | wc -l | tr -d ' ')
total_notes=$(echo "$md_count")
if [ "$total_notes" -eq 0 ]; then
    fail "No notes to check"
elif [ "$link_files" -gt "$((total_notes / 2))" ]; then
    pass "$link_files of $total_notes files contain wiki links"
else
    warn "Only $link_files of $total_notes files contain wiki links (< 50%)"
fi

# Build index of existing filenames for dangling link check
# Folds through the library's _fold_lower, NOT a bare `tr`. The library probes at
# load time and picks tr/awk/sed/ascii because GNU `tr` cannot fold non-ASCII case
# at all -- so a hardcoded `tr` here silently under-folds exactly the names the
# probe exists to handle, and the dangling-link comparison below then treats
# "Über" and "über" as different files.
#
# `xargs -I{}` is kept: it sets the delimiter to newline, so a filename containing
# spaces stays one argument. (The review comment that prompted this change also
# claimed xargs breaks on spaces; measured, it does not. Only the `tr` half was real.)
existing_files=$(find "$VAULT" -name "*.md" -not -path "*/.git/*" 2>/dev/null | xargs -I{} basename {} .md | _fold_lower | LC_ALL=C sort -u)

# Extract wiki links from note content (scan known note directories)
dangling=0
checked=0

# Collect links from note directories only (using recursive variant to handle subdirs).
# The directories are DERIVED from the vault -- see the resolution block near the
# top of this file. The list that used to sit here named canonical directories,
# all four of which are absent from any vault that renamed them, which is why
# this check reported "no wiki links" on a vault holding 2681 of them.
link_candidates=""
note_dirs_raw=$(resolve_note_dirs "$VAULT")
resolve_rc=$?
NOTE_DIR_SOURCE=""
note_dirs=""
if [ "$resolve_rc" -eq 0 ]; then
    NOTE_DIR_SOURCE=$(printf '%s\n' "$note_dirs_raw" | head -1)
    note_dirs=$(printf '%s\n' "$note_dirs_raw" | tail -n +2)
fi

SCANNED_NAMES=""
if [ "$resolve_rc" -eq 0 ]; then
    # Iterate with `while read`, not `for d in $note_dirs`: zsh does not
    # word-split unquoted expansions, so the `for` spelling would hand the whole
    # newline-joined list over as a single nonexistent path and scan nothing.
    while IFS= read -r d; do
        [ -z "$d" ] && continue
        SCANNED_NAMES="$SCANNED_NAMES$(basename "$d")
"
        new_links=$(extract_link_targets_recursive "$d")
        if [ -n "$new_links" ]; then
            link_candidates=$(printf '%s\n%s' "$link_candidates" "$new_links")
        fi
    done <<EOF
$note_dirs
EOF
    # The self space lives INSIDE the vault. `$VAULT/../self` resolved to a
    # sibling of the vault -- for a top-level vault, straight into $HOME -- and
    # so never matched, while primitive 8 finds the same space at $VAULT/self and
    # passes. Self is appended after resolution rather than being one of the
    # sources: its absence must not make resolution fail, and its presence must
    # not stand in for a notes directory.
    if [ -d "$VAULT/self" ]; then
        printf '%s' "$SCANNED_NAMES" | grep -qxF 'self' || SCANNED_NAMES="${SCANNED_NAMES}self
"
        new_links=$(extract_link_targets_recursive "$VAULT/self")
        [ -n "$new_links" ] && link_candidates=$(printf '%s\n%s' "$link_candidates" "$new_links")
    fi
fi
# Accumulated one name per LINE and joined per-record, not by rewriting spaces.
# The previous joiner was `sed 's/ /, /g'`, which turned a directory named
# `my notes` into `scanned: my, notes` -- a set that does not exist, shown to a
# reader whose whole reason for reading it is to learn which set produced the
# result. Correct counts, plausible message, no error: the house class, sitting
# inside the disclosure added to fix an earlier instance of it.
SCANNED_NAMES=$(printf '%s' "$SCANNED_NAMES" | grep -v '^$' \
    | awk '{ printf "%s%s", (NR > 1 ? ", " : ""), $0 } END { if (NR) print "" }')

# THE CAP IS GONE, and the reasoning that kept it is worth recording, because one
# premise inside it was never tested. This block used to explain why a `head -100`
# sample stayed: lifting it looked like it would cost a full per-link loop on top
# of an already-slow run, so the sample remained and the message disclosed its own
# scope instead. The untested premise was that the only alternative to sampling
# was a BIGGER LOOP. Replacing the loop with a set difference made the cap
# unnecessary rather than merely larger, and measured faster than the sample it
# replaced. The disclosure machinery that premise justified -- percentage checked,
# unchecked remainder -- is gone with it: a message stating a sample size would
# now describe a sample that does not exist, which is the same class of false
# statement the disclosure was added to prevent.
#
# `grep -v '^$'` is still load-bearing, and still not tidying. link_candidates is
# seeded empty and grown with `printf '%s\n%s'`, so it carries a leading empty
# line that survives sort -u. Under the old cap that blank ate one of the hundred
# slots and the field vault reported a 99-link sample from a `head -100`. There is
# no cap left to mis-fill, but the blank would still inflate every count below by
# one and be compared against existing_files as though it were a link target.
link_candidates=$(echo "$link_candidates" | grep -v '^$' | sort -u)
link_total=$(printf '%s\n' "$link_candidates" | grep -c . || true)

# EXHAUSTIVE, NOT SAMPLED -- and coverage was never the thing being traded away.
# This was `head -100` over ~2.7k links: a 3.7% sample whose PASS read as a
# statement about the whole graph. The fix is a set difference, NOT a larger cap.
# Measured on the field vault before changing it: the per-link loop took 32.0s to
# check all 2716 links and 1.0s to check 100, while `comm` checks all of them in
# under a second and returns the identical dangling count (30). The exhaustive
# version is therefore FASTER than the sample it replaces. There was no
# coverage/time tradeoff to defend -- only a loop shape. Re-derive with:
#   time (comm -23 <(...folded links...) <(...existing...) | grep -c .)
#
# BOTH SIDES MUST FOLD *AND* SORT THE SAME WAY -- two requirements, not one.
# Folding was already required (see existing_files above: a bare `tr` under-folds
# non-ASCII, so a real file reads as a dangling link). `comm` adds a second and
# sharper requirement the loop did not have: it consumes two SORTED streams and
# silently emits nonsense when their collations differ. Default `sort` is
# locale-dependent, so `existing_files` and this side both pin LC_ALL=C. Changing
# the sort on one side alone would make every non-ASCII name a spurious dangling
# link -- and it would do so quietly, which is this repo's whole failure mode.
link_folded=$(printf '%s\n' "$link_candidates" | _fold_lower | LC_ALL=C sort -u)
checked=$(printf '%s\n' "$link_folded" | grep -c . || true)
dangling=$(comm -23 <(printf '%s\n' "$link_folded") <(printf '%s\n' "$existing_files") \
           | grep -c . || true)

# THREE OUTCOMES, NOT TWO. "The check could not run" and "the check ran and
# found nothing" are different facts, and collapsing them into one WARN is the
# defect this primitive shipped: `WARN No wiki links found to check` sat directly
# beneath `PASS 3786 of 5253 files contain wiki links` -- two lines of one run
# contradicting each other -- and was read as a soft pass across several
# sessions. A check that never executed must never be reported as a warning.
if [ "$resolve_rc" -ne 0 ]; then
    fail "Dangling-link check did NOT run: no note-bearing directory could be resolved in '$VAULT' (tried ops/derivation-manifest.md vocabulary, then ops/config.yaml vocabulary, then a scan for top-level directories containing *.md). This is a failure, not a warning -- nothing was checked."
elif [ "$checked" -eq 0 ]; then
    warn "Resolved note directories via $NOTE_DIR_SOURCE, but they contain no wiki links to check [scanned: $SCANNED_NAMES]"
elif [ "$dangling" -eq 0 ]; then
    if [ "$link_total" -gt "$checked" ]; then
        # NOT A SAMPLE -- and this branch exists precisely to stop it reading as
        # one, because its previous occupant WAS a sample and said so here. The
        # scan is exhaustive now; `checked` sits below `link_total` only because
        # case-folding merges targets differing by case alone, and those resolve
        # to one file, so they are one check rather than two. Both arms below
        # therefore say "checked all". Neither prints a percentage or an
        # unchecked remainder, because there is no unchecked remainder to name.
        pass "No dangling wiki links (checked all $checked case-folded targets from $link_total raw links) [via $NOTE_DIR_SOURCE; scanned: $SCANNED_NAMES]"
    else
        pass "No dangling wiki links (checked all $checked unique links) [via $NOTE_DIR_SOURCE; scanned: $SCANNED_NAMES]"
    fi
else
    # Dangling links are common in mature vaults (examples, planned notes)
    # Report as info, not failure
    warn "$dangling unresolved wiki links out of $checked unique checked -- exhaustive scan, no sampling (may include examples) [via $NOTE_DIR_SOURCE; scanned: $SCANNED_NAMES]"
fi

# --- Primitive 3: MOC hierarchy ---
echo "3. MOC hierarchy for attention management"
moc_count=$(grep -rl '^type: moc' "$VAULT" --include="*.md" 2>/dev/null | grep -v ".git" | wc -l | tr -d ' ')
if [ "$moc_count" -eq 0 ]; then
    moc_like=$(grep -rl '## Core Ideas' "$VAULT" --include="*.md" 2>/dev/null | grep -v ".git" | wc -l | tr -d ' ')
    if [ "$moc_like" -gt 0 ]; then
        warn "$moc_like MOC-like files but none declare type: moc"
    else
        fail "No MOCs found"
    fi
elif [ "$moc_count" -lt 3 ]; then
    warn "$moc_count MOCs (minimum recommended: 3)"
else
    pass "$moc_count MOCs found"
fi

# --- Primitive 4: Tree injection / workspace map ---
echo "4. Tree injection at session start"
has_tree=false
[ -f "$VAULT/.claude/hooks/session-start.sh" ] && has_tree=true
[ -f "$VAULT/WORKSPACE-MAP.md" ] && has_tree=true
for ctx in "$VAULT/CLAUDE.md"; do
    [ -f "$ctx" ] && grep -qi "tree\|workspace.map\|orient" "$ctx" 2>/dev/null && has_tree=true
done
find "$VAULT" -name "session-orient.sh" -not -path "*/.git/*" 2>/dev/null | grep -q . && has_tree=true

if $has_tree; then
    pass "Tree injection mechanism found"
else
    warn "No tree injection mechanism detected"
fi

# --- Primitive 5: Description field ---
echo "5. Description field for progressive disclosure"
# Find notes in common locations
notes_dirs=""
for d in "notes" "01_thinking" "thinking" "knowledge"; do
    [ -d "$VAULT/$d" ] && notes_dirs="$notes_dirs $VAULT/$d"
done
[ -z "$notes_dirs" ] && notes_dirs="$VAULT"

desc_count=0
no_desc=0
for dir in $notes_dirs; do
    d=$(grep -rl '^description:' "$dir" --include="*.md" -l 2>/dev/null | grep -v ".git" | wc -l | tr -d ' ')
    n=$(find "$dir" -maxdepth 1 -name "*.md" -not -name "README.md" -not -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
    desc_count=$((desc_count + d))
    no_desc=$((no_desc + n - d))
done

total_n=$((desc_count + no_desc))
if [ "$total_n" -eq 0 ]; then
    warn "No notes found in expected directories"
elif [ "$no_desc" -le 0 ]; then
    pass "All $desc_count notes have description fields"
elif [ "$no_desc" -lt "$((total_n / 5 + 1))" ]; then
    warn "$desc_count with descriptions, $no_desc without (< 20% missing)"
else
    fail "$no_desc of $total_n notes missing description field"
fi

# --- Primitive 6: Topics footer ---
echo "6. Topics footer linking notes to MOCs"
topics_count=0
no_topics=0
for dir in $notes_dirs; do
    t=$(grep -rl '^topics:' "$dir" --include="*.md" 2>/dev/null | grep -v ".git" | wc -l | tr -d ' ')
    n=$(find "$dir" -maxdepth 1 -name "*.md" -not -name "README.md" -not -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
    topics_count=$((topics_count + t))
    no_topics=$((no_topics + n - t))
done

total_t=$((topics_count + no_topics))
if [ "$total_t" -eq 0 ]; then
    warn "No notes found in expected directories"
elif [ "$no_topics" -le 0 ]; then
    pass "All $topics_count notes have topics"
elif [ "$no_topics" -lt "$((total_t / 5 + 1))" ]; then
    warn "$topics_count with topics, $no_topics without (< 20% missing)"
else
    fail "$no_topics of $total_t notes missing topics"
fi

# --- Primitive 7: Schema enforcement ---
echo "7. Schema enforcement via validation"
has_templates=false
has_validation=false
for d in "templates" "04_meta/templates" "_templates"; do
    [ -d "$VAULT/$d" ] && has_templates=true && break
done
find "$VAULT" -name "validate-schema.sh" -o -name "validate.sh" -not -path "*/.git/*" 2>/dev/null | grep -q . && has_validation=true
find "$VAULT" -path "*/validate/SKILL.md" -o -path "*/verify/SKILL.md" 2>/dev/null | grep -q . && has_validation=true

if $has_templates && $has_validation; then
    pass "Templates and validation mechanism found"
elif $has_templates; then
    warn "Templates found but no validation mechanism"
elif $has_validation; then
    warn "Validation found but no template directory"
else
    fail "No templates or validation mechanism found"
fi

# --- Primitive 8: Self space (CONFIGURABLE) ---
echo "8. Self space for agent persistent memory (configurable)"
# Check for self/ in vault, sibling to vault, or common alternatives
self_dir=""
for candidate in "$VAULT/self" "$VAULT/../self" "$VAULT/self/memory"; do
    [ -d "$candidate" ] && self_dir="$candidate" && break
done

if [ -n "$self_dir" ]; then
    self_files=$(find "$self_dir" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    has_identity=false; [ -f "$self_dir/identity.md" ] && has_identity=true
    has_methodology=false; [ -f "$self_dir/methodology.md" ] && has_methodology=true
    has_goals=false; [ -f "$self_dir/goals.md" ] && has_goals=true

    if $has_identity && $has_methodology && $has_goals; then
        pass "self/ with $self_files files (identity, methodology, goals present)"
    elif [ "$self_files" -gt 0 ]; then
        warn "self/ exists with $self_files files but missing some core MOCs"
    else
        warn "self/ directory exists but is empty"
    fi
else
    # Self space is configurable — check for ops/ fallback
    if [ -f "$VAULT/ops/goals.md" ]; then
        pass "self/ disabled, ops/ fallback in use (ops/goals.md found)"
    elif [ -d "$VAULT/.claude/memory" ]; then
        warn "Memory mechanism found but no dedicated self/ space"
    else
        warn "No self/ directory found (configurable — off by default for research vaults)"
    fi
fi

# --- Primitive 9: Session rhythm ---
echo "9. Session rhythm: orient, work, persist"
has_rhythm=false
for ctx in "$VAULT/CLAUDE.md"; do
    [ -f "$ctx" ] && grep -qi "orient\|session start\|session end\|persist\|session rhythm" "$ctx" 2>/dev/null && has_rhythm=true
done
[ -f "$VAULT/.claude/hooks/session-start.sh" ] && has_rhythm=true
find "$VAULT" -name "session-orient.sh" -not -path "*/.git/*" 2>/dev/null | grep -q . && has_rhythm=true

if $has_rhythm; then
    pass "Session rhythm documented or automated"
else
    warn "No session rhythm pattern found"
fi

# --- Primitive 10: Semantic search (CONFIGURABLE) ---
echo "10. Semantic search capability (configurable)"
has_search=false
has_search_mcp=false
has_search_cli=false
has_search_docs=false

[ -f "$VAULT/.mcp.json" ] && grep -q '"qmd"' "$VAULT/.mcp.json" 2>/dev/null && grep -q '"mcp"' "$VAULT/.mcp.json" 2>/dev/null && has_search_mcp=true
command -v qmd &>/dev/null && has_search_cli=true
for ctx in "$VAULT/CLAUDE.md"; do
    [ -f "$ctx" ] && grep -qi "semantic search\|qmd" "$ctx" 2>/dev/null && has_search_docs=true
done

if $has_search_mcp || $has_search_cli; then
    has_search=true
fi

if $has_search; then
    details=""
    $has_search_mcp && details="${details}.mcp.json qmd server, "
    $has_search_cli && details="${details}qmd executable, "
    details=$(echo "$details" | sed 's/, $//')

    # qmd being INSTALLED is not the same as its tools RESOLVING, and this primitive
    # used to conflate them. qmd was on PATH throughout the entire period when 62 call
    # sites across 20 files named tools qmd had removed from its MCP surface: every call
    # failed, each skill's documented "fall back to rg" path silently stood in, semantic
    # search degraded to keyword grep in every vault — and this check reported PASS.
    #
    # A presence check cannot detect a surface change. Three states, kept distinct:
    #   qmd absent            -> the elif/else below (optional capability)
    #   qmd present, resolves -> PASS
    #   qmd present, does NOT -> FAIL
    qmd_exposed='mcp__qmd__query mcp__qmd__get mcp__qmd__multi_get mcp__qmd__status'
    qmd_hits=$(mktemp)
    # Scan only the LIVE tool surface, and scan the VAULT rather than the working
    # directory — this script validates a generated vault, not the plugin repo.
    #
    # ops/ is deliberately EXCLUDED. ops/skills-archive/ holds dated historical copies
    # of skills and ops/changelog.md records past migrations; both legitimately contain
    # retired tool names. An archived skill is a record, not a declaration — it is never
    # executed. Scanning it found 24 files in the field vault whose live skills declare
    # zero dead names, and would have made this check unfixable without rewriting history.
    #
    # The vault's root CLAUDE.md IS part of the live surface and is scanned: it is
    # always-loaded context whose Helper Functions section holds executable calls, so a
    # dead name there fails every session in the one file guaranteed to be read. Its
    # omission also contradicted this script's own model — has_search_docs above already
    # treats $VAULT/CLAUDE.md as a place semantic search is declared. Verified against the
    # field vault before adding: it contains zero mcp__qmd__* names, so this cannot
    # reintroduce the archive/changelog false positive the scoping exists to avoid.
    #
    # KNOWN FALSE POSITIVE, and the reason this file rather than the whole tree: the scan
    # matches a NAME, so it cannot tell a declaration from a deprecation notice. A vault
    # CLAUDE.md "Common Pitfalls" entry reading "do NOT use mcp__qmd__deep_search, use
    # mcp__qmd__query" FAILs this check while being correct guidance — and the field vault
    # does have a Common Pitfalls section, so this is foreseeable, not hypothetical. It is
    # accepted because it is cheaply recoverable (reword one line of one live file) where
    # the archive case was not (rewriting history), and because prose in an always-loaded
    # file is executed, so a dead name there is worth a second look either way.
    qmd_scan=()
    [ -d "$VAULT/.claude" ] && qmd_scan+=("$VAULT/.claude")
    [ -d "$VAULT/.agents" ] && qmd_scan+=("$VAULT/.agents")
    [ -f "$VAULT/.mcp.json" ] && qmd_scan+=("$VAULT/.mcp.json")
    [ -f "$VAULT/CLAUDE.md" ] && qmd_scan+=("$VAULT/CLAUDE.md")
    if [ ${#qmd_scan[@]} -eq 0 ]; then
        pass "Semantic search capability found (${details}); no live tool surface to verify"
        rm -f "$qmd_hits"
        qmd_rc=-1
    else
        rg -oIN 'mcp__qmd__[a-z_]+' "${qmd_scan[@]}" > "$qmd_hits" 2>/dev/null
        qmd_rc=$?
    fi
    # rg: 0=match, 1=no-match (a vault may legitimately declare none), 2=error.
    # Capture rg's status BEFORE sorting — `rg ... | sort` would yield sort's status,
    # which is the pipeline-discard defect this very check exists to catch.
    if [ "$qmd_rc" -lt 0 ]; then
        :   # no live tool surface; already reported above
    elif [ "$qmd_rc" -gt 1 ]; then
        fail "Semantic search: scan for qmd tool names failed (rg rc=$qmd_rc); this result is not evidence"
    else
        qmd_unknown=""
        for t in $(sort -u "$qmd_hits"); do
            case " $qmd_exposed " in
                *" $t "*) ;;
                *) qmd_unknown="$qmd_unknown $t" ;;
            esac
        done
        if [ -n "$qmd_unknown" ]; then
            fail "Semantic search: vault declares qmd tools that do not exist:$qmd_unknown"
        else
            pass "Semantic search capability found (${details}); declared qmd tool names resolve"
        fi
    fi
    rm -f "$qmd_hits"
elif $has_search_docs; then
    warn "Semantic search mentioned in docs but no qmd executable or .mcp.json qmd server config detected"
else
    pass "Semantic search not enabled (configurable)"
fi

# --- Primitive 10A: Filesystem graph database (unique-addresses) ---
echo "10A. Filesystem graph database (unique-addresses)"
has_graph_scripts=false
for d in "ops/scripts/graph" "04_meta/scripts/graph" "scripts/graph"; do
    [ -d "$VAULT/$d" ] && has_graph_scripts=true && break
done

if $has_graph_scripts; then
    pass "Graph analysis scripts directory found"
else
    warn "No ops/scripts/graph/ directory detected"
fi

# --- Primitive 11: Discovery-first quality gate ---
echo "11. Discovery-first quality gate"
has_discovery_section=false
has_discovery_skills=false

# Check context files for Discovery-First section
for ctx in "$VAULT/CLAUDE.md"; do
    [ -f "$ctx" ] && grep -qi "discovery.first" "$ctx" 2>/dev/null && has_discovery_section=true
done

# Check skills for discovery checks
skill_dirs=""
for d in ".claude/skills" "skills"; do
    [ -d "$VAULT/$d" ] && skill_dirs="$skill_dirs $VAULT/$d"
done
if [ -n "$skill_dirs" ]; then
    for dir in $skill_dirs; do
        grep -rqi "discovery\|findability" "$dir" 2>/dev/null && has_discovery_skills=true
    done
fi

if $has_discovery_section && $has_discovery_skills; then
    pass "Discovery-first gate in context file and skills"
elif $has_discovery_section; then
    warn "Discovery-first in context file but not in skills"
elif $has_discovery_skills; then
    warn "Discovery checks in skills but no context file section"
else
    warn "No discovery-first quality gate detected"
fi

# --- Primitive 12: Operational learning loop ---
echo "12. Operational learning loop"
has_obs_dir=false
has_tensions_dir=false
has_review_trigger=false
has_rethink=false

# Check for ops/observations/ and ops/tensions/ directories (or common variants)
for candidate in "ops/observations" "04_meta/logs/observations" "logs/observations" "observations"; do
    [ -d "$VAULT/$candidate" ] && has_obs_dir=true && break
done
for candidate in "ops/tensions" "04_meta/logs/tensions" "logs/tensions" "tensions"; do
    [ -d "$VAULT/$candidate" ] && has_tensions_dir=true && break
done

# Check context files for review trigger documentation
for ctx in "$VAULT/CLAUDE.md"; do
    [ -f "$ctx" ] && grep -qi "rethink\|review\|observations" "$ctx" 2>/dev/null && has_review_trigger=true
done

# Check for rethink command/skill
for d in ".claude/skills/rethink" "skills/rethink"; do
    [ -d "$VAULT/$d" ] && has_rethink=true && break
done
# Also check for rethink skill files directly
find "$VAULT" -path "*/rethink/SKILL.md" -not -path "*/.git/*" 2>/dev/null | grep -q . && has_rethink=true
find "$VAULT" -path "*/rethink.md" -not -path "*/.git/*" 2>/dev/null | grep -q . && has_rethink=true

checks_passed=0
$has_obs_dir && checks_passed=$((checks_passed + 1))
$has_tensions_dir && checks_passed=$((checks_passed + 1))
$has_review_trigger && checks_passed=$((checks_passed + 1))
$has_rethink && checks_passed=$((checks_passed + 1))

if [ "$checks_passed" -eq 4 ]; then
    pass "Operational learning loop: observations, tensions, review trigger, rethink mechanism"
elif [ "$checks_passed" -ge 2 ]; then
    details=""
    $has_obs_dir || details="${details}observations dir, "
    $has_tensions_dir || details="${details}tensions dir, "
    $has_review_trigger || details="${details}review trigger, "
    $has_rethink || details="${details}rethink mechanism, "
    details=$(echo "$details" | sed 's/, $//')
    warn "Partial learning loop ($checks_passed/4). Missing: $details"
else
    fail "No operational learning loop detected (need observations dir, tensions dir, review trigger, rethink mechanism)"
fi

# --- Primitive 13: Task stack ---
echo "13. Task stack"
has_tasks_md=false
has_queue_file=false

# Check for ops/tasks.md or common variants
for candidate in "ops/tasks.md" "04_meta/tasks/tasks.md"; do
    [ -f "$VAULT/$candidate" ] && has_tasks_md=true && break
done

# Check for queue file (JSON or YAML)
for candidate in "ops/queue/queue.json" "ops/queue/queue.yaml" "04_meta/tasks/queue.json" "04_meta/tasks/queue.yaml"; do
    [ -f "$VAULT/$candidate" ] && has_queue_file=true && break
done

if $has_tasks_md && $has_queue_file; then
    pass "Task stack: tasks.md and queue file found"
elif $has_tasks_md; then
    warn "tasks.md found but no queue file"
elif $has_queue_file; then
    warn "Queue file found but no tasks.md"
else
    warn "No task stack detected (ops/tasks.md + queue file)"
fi

# --- Primitive 14: Methodology folder ---
echo "14. Methodology folder"
has_methodology_dir=false
has_methodology_moc=false

for candidate in "ops/methodology" "04_meta/methodology"; do
    [ -d "$VAULT/$candidate" ] && has_methodology_dir=true
    [ -f "$VAULT/$candidate/methodology.md" ] && has_methodology_moc=true
    $has_methodology_dir && break
done

if $has_methodology_dir && $has_methodology_moc; then
    pass "Methodology folder with methodology.md MOC found"
elif $has_methodology_dir; then
    warn "ops/methodology/ exists but no methodology.md MOC inside"
else
    warn "No ops/methodology/ directory detected"
fi

# --- Primitive 15: Session capture ---
echo "15. Session capture"
has_sessions_dir=false

for candidate in "ops/sessions" "04_meta/sessions" "self/sessions"; do
    [ -d "$VAULT/$candidate" ] && has_sessions_dir=true && break
done

if $has_sessions_dir; then
    pass "Session capture directory found"
else
    warn "No ops/sessions/ directory detected"
fi

# --- Summary ---
echo ""
echo "=== Kernel Validation Summary ==="
echo -e "  ${GREEN}PASS:${NC} $PASS"
echo -e "  ${YELLOW}WARN:${NC} $WARN"
echo -e "  ${RED}FAIL:${NC} $FAIL"
echo ""

if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
    echo -e "${GREEN}All 15 primitives validated successfully.${NC}"
    exit 0
elif [ "$FAIL" -eq 0 ]; then
    echo -e "${YELLOW}Kernel present with warnings. $WARN primitive(s) need attention.${NC}"
    exit 0
else
    echo -e "${RED}$FAIL kernel primitive(s) missing. System may not function reliably.${NC}"
    exit 1
fi
