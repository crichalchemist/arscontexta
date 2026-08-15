#!/bin/bash
# placeholder-count.test.sh — behavioral tests for check-placeholder-count.sh.
#
# WHY THIS EXISTS: the shipped allowlist is EMPTY, so every branch behind it is
# unexercised by any real run. That is precisely the condition under which the
# first draft's `set -- $e` bug survived — it clobbered the function's own
# positional parameters and nothing noticed, because the loop never executed. An
# empty list is not an absent mechanism, and a mechanism nothing runs is not a
# mechanism. The gate's own header claimed "exercised by a test that populates
# the list" one commit before that test existed; this file is that claim made true.
#
# WHY FIXTURES ARE REAL GIT REPOS: the gate's whole subject is a git RANGE — merge
# bases, renames, a base branch that moved ahead. None of that can be simulated
# with files on disk, and the two Criticals found in review (a two-dot range
# blaming untouched files; a rename escaping entirely) are both invisible to any
# test that does not build real history.
#
# WHY THE ALLOWLIST IS INJECTED BY COPYING THE SCRIPT: the alternative is an
# environment-variable override, which puts a testing backdoor into a gate. The
# fixture copies the script and substitutes the assignment, so production code
# carries no test-only path.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/../check-placeholder-count.sh"
[ -r "$GATE" ] || { echo "FAIL: cannot read $GATE"; exit 1; }

passed=0; failed=0
TMPDIRS=()
ok()   { passed=$((passed+1)); }
fail() { failed=$((failed+1)); printf 'FAIL: %s\n  expected [%s] got [%s]\n' "$1" "$2" "$3"; }
eq()   { if [ "$2" = "$3" ]; then ok; else fail "$1" "$2" "$3"; fi; }
cleanup() { local d; for d in "${TMPDIRS[@]:-}"; do [ -n "$d" ] && rm -rf "$d"; done; }
trap cleanup EXIT INT TERM

# A marker of each of the three families, so a fixture exercises the whole pattern
# rather than the one family the old inline check happened to match.
V='{vocabulary.notes}'
C='{config.processing}'
D='{DOMAIN:notes}'

mkrepo() {              # mkrepo -> path to a repo with a base commit on `base`
    local d; d=$(mktemp -d); TMPDIRS+=("$d")
    mkdir -p "$d/reference/lib" "$d/skill-sources/alpha" "$d/skill-sources/beta"
    cp "$GATE" "$d/reference/"
    # PLACEHOLDER_PAT is sourced from lib/placeholder-pattern.sh, not defined
    # inline in $GATE anymore -- every fixture repo needs its own copy or the
    # sourcing fails and the whole suite reports unbound-variable noise instead
    # of the specific behavior each test means to exercise.
    cp "$(dirname "$GATE")/lib/placeholder-pattern.sh" "$d/reference/lib/"
    # alpha is a REALISTIC template — ~60 lines of stable prose plus its markers.
    # A one-line fixture would defeat the rename test for a reason that has
    # nothing to do with the gate: `-M` scores similarity, and a single line
    # rewritten end to end has none left, so git reports A + D no matter what
    # threshold is passed. The size has to be at the BASE side to matter.
    { for i in $(seq 1 60); do echo "ordinary template prose line $i"; done
      printf 'alpha %s %s %s\n' "$V" "$C" "$D"; } > "$d/skill-sources/alpha/SKILL.md"
    printf 'beta %s %s\n' "$V" "$V" > "$d/skill-sources/beta/SKILL.md"
    ( cd "$d" && git init -q . && git config user.email t@t && git config user.name t \
      && git add -A && git commit -qm base && git branch -M base ) >/dev/null 2>&1
    # THE FIXTURE MUST ASSERT ITS OWN SETUP. Every setup block here ends in
    # `>/dev/null 2>&1`, so a git command that fails is INVISIBLE and the
    # assertion afterwards measures a tree that was never built — which reads as
    # a mysterious intermittent failure rather than as a broken fixture. Observed:
    # this suite went 30/30, 28/2, 29/1 across runs while the subject never
    # changed. Silent setup is the house defect, and a test suite is not exempt
    # from it just because it is the thing doing the checking.
    if ! ( cd "$d" && git rev-parse --verify base >/dev/null 2>&1 ) \
       || [ ! -f "$d/skill-sources/alpha/SKILL.md" ]; then
        printf 'FIXTURE SETUP FAILED (no base branch or missing file) in %s\n' "$d" >&2
        failed=$((failed+1))
    fi
    printf '%s' "$d"
}

# Assert a fixture reached the state its setup intended, BEFORE measuring it.
# Called after each setup block whose failure would otherwise be silent.
staged() {              # staged <repo> <expected-branch> [<file-that-must-exist>]
    local d="$1" want="$2" f="${3:-}"
    local got; got=$( cd "$d" && git rev-parse --abbrev-ref HEAD 2>/dev/null )
    if [ "$got" != "$want" ]; then
        printf 'FIXTURE NOT STAGED: %s is on [%s], expected [%s]\n' "$d" "$got" "$want" >&2
        failed=$((failed+1)); return 1
    fi
    if [ -n "$f" ] && [ ! -f "$d/$f" ]; then
        printf 'FIXTURE NOT STAGED: %s missing %s\n' "$d" "$f" >&2
        failed=$((failed+1)); return 1
    fi
    return 0
}
run()  { ( cd "$1" && bash reference/check-placeholder-count.sh "${2:-base}" 2>&1 ); }
rc_of(){ ( cd "$1" && bash reference/check-placeholder-count.sh "${2:-base}" >/dev/null 2>&1; echo $? ); }
allow(){ # allow <repo> <entries>  — substitute the allowlist in the repo's copy
    # Matches the WHOLE current assignment (PLACEHOLDER_ALLOW="...") via regex,
    # not a literal '""' — the shipped default is no longer empty (see
    # docs/superpowers/specs/archive/2026-08-08-vocabulary-schema-coverage-design.md's
    # one real allowlisted entry), and a literal-empty-string match would only
    # ever have worked for that one specific starting value. No entry, shipped
    # or test-supplied, contains an embedded double quote, so a non-greedy
    # [^"]* is a safe delimiter.
    python3 - "$1/reference/check-placeholder-count.sh" "$2" <<'PY'
import sys, re
p, entries = sys.argv[1], sys.argv[2]
s = open(p).read()
pat = re.compile(r'PLACEHOLDER_ALLOW="[^"]*"')
assert len(pat.findall(s)) == 1, "allowlist assignment not found — did the script change?"
open(p, 'w').write(pat.sub('PLACEHOLDER_ALLOW="\n%s\n"' % entries, s))
PY
}

bust(){ # bust <repo> <old> <new>  — patch the fixture's own script copy
    python3 - "$1/reference/check-placeholder-count.sh" "$2" "$3" <<'PY'
import sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p).read()
assert s.count(old) == 1, "bust anchor matched %d times: %r" % (s.count(old), old)
open(p, "w").write(s.replace(old, new))
PY
}

# --- the clean case, and it must not be vacuous ------------------------------
R=$(mkrepo); ( cd "$R" && git checkout -qb work && printf 'note\n' >> skill-sources/alpha/SKILL.md \
   && git commit -aqm "edit that adds no marker" ) >/dev/null 2>&1
staged "$R" work || true
eq "clean: an edit that keeps every marker passes"  "0" "$(rc_of "$R")"
eq "clean: and names the range it checked"        "yes" \
   "$(run "$R" | grep -q 'changed since the merge base' && echo yes || echo no)"

# --- a decrease, per family --------------------------------------------------
# The {DOMAIN:*} case is the one the check this gate replaced could not see at
# all: its pattern matched two families, so hardcoding a {DOMAIN:notes} produced
# no output whatsoever. Measured on the real tree at the time: 488 vs 616 markers.
for fam in "vocabulary:$V" "config:$C" "DOMAIN:$D"; do
    name=${fam%%:*}; marker=${fam#*:}
    R=$(mkrepo); ( cd "$R" && git checkout -qb work \
       && python3 -c "
import sys
p='skill-sources/alpha/SKILL.md'; m=sys.argv[1]
s=open(p).read(); assert m in s, 'fixture lacks '+m
open(p,'w').write(s.replace(m,'nodes/'))" "$marker" \
       && git commit -aqm "hardcode a $name marker" ) >/dev/null 2>&1
    staged "$R" work || true
    eq "decrease: hardcoding a {$name} marker fails"        "1" "$(rc_of "$R")"
    eq "decrease: and names the file and both counts"     "yes" \
       "$(run "$R" | grep -q 'HARDCODED A PLACEHOLDER: skill-sources/alpha/SKILL.md (3 -> 2)' && echo yes || echo no)"
done

# --- a base branch that moved ahead must not be blamed on us -----------------
# `git diff A..HEAD` compares TIPS, so a marker ADDED on the base reads as one
# REMOVED here. Reproduced against the shipped version: a branch that never
# touched beta/ reported `HARDCODED A PLACEHOLDER: beta/SKILL.md`, rc 1. CI's
# origin/main is routinely ahead, so this fired on ordinary branches.
R=$(mkrepo)
( cd "$R" && git checkout -qb work && printf 'unrelated\n' >> skill-sources/alpha/SKILL.md \
  && git commit -aqm "work touches alpha only" \
  && git checkout -q base && printf 'more %s\n' "$V" >> skill-sources/beta/SKILL.md \
  && git commit -aqm "base gains a marker in beta" && git checkout -q work ) >/dev/null 2>&1
staged "$R" work || true
eq "range: a base that moved ahead is not blamed on us"  "0" "$(rc_of "$R")"
eq "range: and beta/ is not named"                     "yes" \
   "$(run "$R" | grep -q 'beta' && echo no || echo yes)"

# THE SAME FILE ON BOTH SIDES — which the fixture above never exercises, because
# the branch touches alpha/ and the base touches beta/, so the file list and the
# base-side read can never disagree about one file. With them separated, reverting
# EITHER site alone leaves this suite green; only reverting both reproduces C1.
# Here the branch appends a harmless comment to the very file the base adds
# markers to, so the base-side read is exercised ON a file that is genuinely in
# the range. Reverting the base-read alone now yields rc 1 "(3 -> 3)"-style
# blame on an innocent edit.
R=$(mkrepo)
( cd "$R" && git checkout -qb work && printf 'a harmless comment\n' >> skill-sources/alpha/SKILL.md \
  && git commit -aqm "branch edits alpha harmlessly" \
  && git checkout -q base && printf 'more %s %s\n' "$V" "$V" >> skill-sources/alpha/SKILL.md \
  && git commit -aqm "base adds markers to THE SAME file" && git checkout -q work ) >/dev/null 2>&1
staged "$R" work || true
eq "range: base and branch touching ONE file is not blamed" "0" "$(rc_of "$R")"
eq "range: and alpha/ is not reported as a decrease"      "yes" \
   "$(run "$R" | grep -q 'HARDCODED' && echo no || echo yes)"

# --- a rename must not launder a hardcode ------------------------------------
# Without -M the new path has no base-side counterpart, so was=0 and ANY count
# clears it. Measured against the shipped version: renaming a file and hardcoding
# every marker in it reported `PASS 2 template(s) changed, no count decreased`.
# THE FIXTURE MUST BE A REALISTIC TEMPLATE, not a one-liner. `-M` pairs a rename
# with an edit only while the two sides stay similar: a 60-line template with
# every marker hardcoded still scores R098 and is caught, while a single-line
# file rewritten end to end has no similarity left and git reports A + D. Testing
# the one-liner would assert a property `-M` does not have and cannot get; the
# unpairable shape is covered by the deletion notice below instead.
R=$(mkrepo)
( cd "$R" && git checkout -qb work && git mv skill-sources/alpha/SKILL.md skill-sources/alpha/RENAMED.md \
  && python3 -c "
p='skill-sources/alpha/RENAMED.md'
s=open(p).read()
for m in ('{vocabulary.notes}','{config.processing}','{DOMAIN:notes}'): s=s.replace(m,'nodes/')
open(p,'w').write(s)" \
  && git add -A && git commit -qm "rename and hardcode everything" ) >/dev/null 2>&1
staged "$R" work || true
eq "rename: a rename plus a hardcode still fails"        "1" "$(rc_of "$R")"
eq "rename: and the message shows old -> new"          "yes" \
   "$(run "$R" | grep -q 'SKILL.md -> skill-sources/alpha/RENAMED.md' && echo yes || echo no)"

# THE UNPAIRABLE SHAPE MUST NOT BE SILENT. git reports A + D here, so the added
# path has no base-side count to fall short of and the comparison cannot happen.
# That is not a failure — deleting a template is legitimate — but a silent PASS
# over it would be the house defect. The gate names the deletion instead.
R=$(mkrepo)
( cd "$R" && git checkout -qb work && git rm -q skill-sources/alpha/SKILL.md \
  && git commit -qm "delete a template" ) >/dev/null 2>&1
staged "$R" work || true
eq "deletion: a deleted template does not fail the gate"  "0" "$(rc_of "$R")"
eq "deletion: but IS named rather than passed over"     "yes" \
   "$(run "$R" | grep -q 'NOTE template deleted, not compared: skill-sources/alpha/SKILL.md' && echo yes || echo no)"

# THE add+delete SHAPE — a rename git could not pair. Both halves must be legible
# TOGETHER, or the reader has to notice the pairing themselves. Still rc 0: this
# is legibility, not a verdict.
R=$(mkrepo)
# mkdir -p is load-bearing: `git rm` of the only file in a directory removes the
# DIRECTORY too, so writing the replacement into it fails — and the first version
# of this fixture did exactly that, silently, then asserted against a range that
# contained no add at all. staged() did not catch it because it was called
# without the file argument, which is the whole point of that argument.
( cd "$R" && git checkout -qb work && git rm -q skill-sources/alpha/SKILL.md \
  && mkdir -p skill-sources/alpha \
  && printf 'wholly new %s\n' "$V" > skill-sources/alpha/REPLACEMENT.md \
  && git add -A && git commit -qm "delete one, add another" ) >/dev/null 2>&1
staged "$R" work skill-sources/alpha/REPLACEMENT.md || true
eq "deletion: add+delete does not fail"                   "0" "$(rc_of "$R")"
eq "deletion: the deleted half is named"                "yes" \
   "$(run "$R" | grep -q 'NOTE template deleted, not compared: skill-sources/alpha/SKILL.md' && echo yes || echo no)"
eq "deletion: and the added half is named beside it"    "yes" \
   "$(run "$R" | grep -q 'added in the same range: skill-sources/alpha/REPLACEMENT.md' && echo yes || echo no)"

# --- the allowlist, both directions ------------------------------------------
# Every assertion below runs code that the shipped empty list never reaches.
R=$(mkrepo)
( cd "$R" && git checkout -qb work && python3 -c "
p='skill-sources/alpha/SKILL.md'; s=open(p).read()
open(p,'w').write(s.replace('{DOMAIN:notes}','nodes/'))" \
  && git commit -aqm "a decrease we will excuse" ) >/dev/null 2>&1
staged "$R" work || true
eq "allowlist: without an entry the decrease fails"      "1" "$(rc_of "$R")"
allow "$R" "skill-sources/alpha/SKILL.md 3->2 a deliberate, reviewed decrease"
eq "allowlist: a matching entry absorbs it"              "0" "$(rc_of "$R")"
eq "allowlist: and the absorbed decrease is PRINTED"   "yes" \
   "$(run "$R" | grep -q 'allowlisted decrease skill-sources/alpha/SKILL.md (3 -> 2)' && echo yes || echo no)"
# The summary must not deny what the line above just reported. The first version
# printed nothing and said "no count decreased" regardless — the unsupportable
# label defect this repo has fixed in four other places.
eq "allowlist: and the summary does not deny it"       "yes" \
   "$(run "$R" | grep -q 'no count decreased' && echo no || echo yes)"

R2=$(mkrepo)
( cd "$R2" && git checkout -qb work && python3 -c "
p='skill-sources/alpha/SKILL.md'; s=open(p).read()
open(p,'w').write(s.replace('{DOMAIN:notes}','nodes/'))" \
  && git commit -aqm "a decrease" ) >/dev/null 2>&1
allow "$R2" "skill-sources/alpha/SKILL.md 9->8 an entry whose counts no longer match"
staged "$R2" work || true
eq "allowlist: an entry that no longer matches is STALE" "1" "$(rc_of "$R2")"
eq "allowlist: and says so"                            "yes" \
   "$(run "$R2" | grep -q 'STALE allowlist entry' && echo yes || echo no)"
# EACH REMEDY WITH ITS OWN FINDING. A stale-only run used to print the hardcoding
# advice too, sending the reader to reverse a transform nobody performed.
#
# THIS NEEDS ITS OWN FIXTURE. R2 above carries BOTH a real decrease and a stale
# entry, so the hardcoding advice is correct there — asserting its absence
# against R2 tested nothing about the split and failed for the right reason.
# Stale-only means: the entry's file IS in the range (or staleness is scoped
# away) and shows NO decrease at all.
R5=$(mkrepo)
( cd "$R5" && git checkout -qb work && printf 'harmless\n' >> skill-sources/alpha/SKILL.md \
  && git commit -aqm "edit alpha without losing a marker" ) >/dev/null 2>&1
allow "$R5" "skill-sources/alpha/SKILL.md 3->2 a decrease this range does not show"
staged "$R5" work || true
eq "allowlist: a stale-only run fails"                   "1" "$(rc_of "$R5")"
eq "allowlist: a stale-only run does NOT print hardcoding advice" "yes" \
   "$(run "$R5" | grep -q 'reverse-transforms are mandatory' && echo no || echo yes)"
eq "allowlist: it prints the remedy that fits — delete the entry" "yes" \
   "$(run "$R5" | grep -q 'that is the list draining' && echo yes || echo no)"

# AN ENTRY MUST NOT REDDEN RANGES THAT DO NOT TOUCH ITS FILE. check 6's allowlist
# keys on TREE state, where "no longer matches" is true from every angle; this one
# is RANGE-relative, and the first version copied that shape without noticing.
# The result was that any entry made every unrelated branch red, so no entry could
# survive the merge of the change it excused — a mechanism punishing its own use.
R3=$(mkrepo)
( cd "$R3" && git checkout -qb work && printf 'x\n' >> README.md 2>/dev/null || true
  cd "$R3" && printf 'x\n' > unrelated.txt && git add -A && git commit -qm "touch nothing in skill-sources" ) >/dev/null 2>&1
allow "$R3" "skill-sources/alpha/SKILL.md 3->2 an entry for a file not in this range"
staged "$R3" work || true
eq "allowlist: an entry does not redden an unrelated range" "0" "$(rc_of "$R3")"

R4=$(mkrepo); ( cd "$R4" && git checkout -qb work && printf 'x\n' >> skill-sources/alpha/SKILL.md \
   && git commit -aqm edit ) >/dev/null 2>&1
allow "$R4" "skill-sources/alpha/SKILL.md this-is-not-a-count malformed on purpose"
eq "allowlist: a malformed entry is reported, not ignored" "yes" \
   "$(run "$R4" | grep -q 'MALFORMED allowlist entry' && echo yes || echo no)"

# --- the rc-2 states ---------------------------------------------------------
# "could not run" and "ran and found nothing" are different facts, and this repo
# has twice shipped a scan that matched nothing and reported green.
#
# THE SCRIPT HAS EIGHT rc-2 SITES AND THIS SECTION ONCE ASSERTED THREE, under a
# heading reading "the three rc-2 states" — a header describing the TEST rather
# than its SUBJECT. Three of the unasserted five arrived as fixes in the same
# round that added them, so each could be reverted with this suite green. Two
# guards fire only on conditions that cannot be staged from tree state alone (a
# `git diff` that fails, a non-numeric count); those are exercised by patching
# the fixture's own copy, which tests the wiring where the natural trigger cannot
# be arranged. `cd "$ROOT"` failing is NOT asserted, and is named here rather
# than left to be found later as a silent gap.
R=$(mkrepo)
eq "rc2: a base ref that does not resolve"               "2" "$(rc_of "$R" no-such-ref)"

R=$(mkrepo)
( cd "$R" && git checkout -q --orphan unrelated && git rm -rqf . >/dev/null 2>&1
  printf 'x\n' > x.txt && git add x.txt && git commit -qm orphan && git checkout -q base ) >/dev/null 2>&1
eq "rc2: a ref that resolves but shares no history"      "2" "$(rc_of "$R" unrelated)"
eq "rc2: and rev-parse alone would NOT have caught it" "yes" \
   "$( ( cd "$R" && git rev-parse --verify unrelated >/dev/null 2>&1 ) && echo yes || echo no)"

R=$(mkrepo)
# PLACEHOLDER_PAT lives in lib/placeholder-pattern.sh, sourced by $GATE -- not
# inline in $GATE itself anymore, so the mutation targets the file where the
# constant actually is.
python3 - "$R/reference/lib/placeholder-pattern.sh" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
i = s.index("PLACEHOLDER_PAT='")
j = s.index("'", i + len("PLACEHOLDER_PAT='"))
open(p,'w').write(s[:i] + "PLACEHOLDER_PAT='{zzz_no_such_marker}'" + s[j+1:])
PY
eq "rc2: an extractor that matches zero markers"         "2" "$(rc_of "$R")"
eq "rc2: and says the pattern is stale, not the tree clean" "yes" \
   "$(run "$R" | grep -q 'matched ZERO markers' && echo yes || echo no)"


# The set-DEFINING measurement. Reverting its guard to `|| true` — the shipped
# state one commit ago — makes an unrunnable diff print "PASS no skill-sources/
# templates ... nothing to check", rc 0: a positive claim about the tree from a
# measurement that did not run.
R=$(mkrepo); ( cd "$R" && git checkout -qb work && printf 'x\n' >> skill-sources/alpha/SKILL.md \
   && git commit -aqm edit ) >/dev/null 2>&1
bust "$R" 'git diff --name-status -M "$MB" HEAD 2>/dev/null' 'false'
eq "rc2: an unrunnable git diff"                         "2" "$(rc_of "$R")"
eq "rc2: and does not claim the tree is clean"         "yes" \
   "$(run "$R" | grep -q 'nothing to check' && echo no || echo yes)"

# A count that is not a number would make `[ "$now" -lt "$was" ]` error, and under
# the old `|| continue` it was swallowed entirely.
R=$(mkrepo); ( cd "$R" && git checkout -qb work && printf 'x\n' >> skill-sources/alpha/SKILL.md \
   && git commit -aqm edit ) >/dev/null 2>&1
bust "$R" '    /usr/bin/grep -o "$PLACEHOLDER_PAT" 2>/dev/null | /usr/bin/grep -c . || true' '    echo not-a-number'
eq "rc2: a non-numeric count is reported, not swallowed"  "2" "$(rc_of "$R")"

# skill-sources/ absent entirely — a moved layout, or the wrong root. This one is
# reachable from tree state, unlike the two above.
R=$(mkrepo); ( cd "$R" && git checkout -qb work && git rm -rq skill-sources \
   && git commit -qm "remove the whole tree" ) >/dev/null 2>&1
eq "rc2: skill-sources/ missing is not a clean run"       "2" "$(rc_of "$R")"
# THE rc ALONE CANNOT DISCRIMINATE HERE, and asserting it alone was a row that
# passed for the wrong reason: with the directory gone the extractor also matches
# zero markers, so removing THIS guard entirely still yields rc 2 via the next
# one. Two guards, one exit code. The message is what separates "the tree has no
# such directory" from "the pattern no longer matches anything", and those send a
# reader to different places.
eq "rc2: and says the DIRECTORY is missing, not the pattern" "yes" \
   "$(run "$R" | grep -q 'skill-sources/ does not exist in this tree' && echo yes || echo no)"

printf '\npassed=%s failed=%s\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
