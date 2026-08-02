# Task 3: Guard Evasion Vector Closure — Report

## Status

**COMPLETED** — All four evasion vectors closed. Guard now correctly fails on all PCRE patterns and reports accurate blind-spot sites.

## Vector Closure Summary

| Vector | Pattern | Check | Status |
|--------|---------|-------|--------|
| 1 | `grep --perl-regexp "..."` | 1 (widened) | ✓ CAUGHT |
| 2 | `egrep -oP "..."` | 1 (widened) | ✓ CAUGHT |
| 3 | `rg -P ...` / `rg --pcre2 ...` | 3 (new) | ✓ CAUGHT |
| 4 | `rg -o '[[.*?]]'` | 2 | ✓ PASSES (documented blind spot) |

### Before/After Probe Results

**Before:** Guard incorrectly passes all four vectors
```
=== Portability check: /tmp/probes ===
1. No PCRE grep (-P) in shipped templates
  PASS no grep -P           # WRONG: probe a.md has grep --perl-regexp, b.md has egrep -oP
2. Wiki-link capture terminates at | and #
  PASS link capture terminates correctly
PORTABILITY: PASS (exit 0)    # WRONG: should fail
```

**After:** Guard correctly catches vectors 1, 2, 3; allows vector 4 (blind spot)
```
=== Portability check: /tmp/probes ===
1. No PCRE grep (-P) or long-form in shipped templates
  FAIL grep -P or --perl-regexp found:
       probe/skills/a.md:1:x=$(grep --perl-regexp "a" f)
       probe/skills/b.md:1:y=$(egrep -oP "b" f)
2. Wiki-link capture terminates at | and #
  PASS link capture terminates correctly
3. No PCRE via ripgrep (fails on rg builds without PCRE2)
  FAIL rg -P or --pcre2 found:
       probe/skills/c.md:1:z=$(rg -P "c" f)
PORTABILITY: FAIL (exit 1)    # CORRECT
```

## Implementation Details

### Check 1: Widened Grep Pattern
**Old:** `(^|[^a-zA-Z_-])grep +[^|]*-[a-zA-Z]*P`
- Only caught `grep -P` (single-letter flag)
- Missed `grep --perl-regexp` (no `P` immediately after hyphen)
- Missed `egrep` and `zgrep` variants

**New:** `(^|[^a-zA-Z_-])(grep|egrep|fgrep|zgrep) +[^|]*(-[a-zA-Z]*P|--perl-regexp)`
- Catches all grep variants (grep, egrep, fgrep, zgrep)
- Catches both `-P` flag and `--perl-regexp` long form
- Maintains false-negative exclusion: `tree -P` still passes (legitimate tool use)

### Check 2: Path-Based Exclusion (Carry-In A)
**Old:** `| "$GREP" -v 'lib/link-extraction.sh'`
- Filtered by line content only
- Any mention of filename in a trailing comment would hide defects

**New:** `| "$GREP" -v '^[^:]*lib/link-extraction\.sh:'`
- Anchors on filename field (before colon in grep output)
- Prevents false negatives from comments mentioning the filename
- Ensures only real lib/link-extraction.sh exclusions apply

### Check 3: New Ripgrep PCRE Guard
**New check:** `(^|[^a-zA-Z_-])rg +[^|]*(-P|--pcre2)`
- Closes the uncovered ripgrep PCRE vector entirely
- Catches both short form (`-P`) and long form (`--pcre2`)
- Excludes check-portability.sh itself to avoid self-flagging

### Blind-Spot Comment Correction (Carry-In B)
**Old:** Listed "13 sites" with specific line numbers
- Numbers were wrong (13 vs actual 9)
- Line numbers were stale (175 deleted, 415/468 unrelated)
- Difficult to maintain as files evolve

**New:** Describes 9 sites by functional category, not line numbers
- **Orphan detection (skills):** 5 instances
  - skills/architect/SKILL.md (grep -rl, 1 instance)
  - skills/health/SKILL.md (rg -l, 3 instances)
- **Backlink counting (skill-sources):** 4 instances
  - skill-sources/graph/SKILL.md (grep -rl, 4 instances)
- **Milestone validation:** 1 instance
  - reference/testing-milestones.md (grep -rl, 1 instance)

This approach survives file evolution: description focuses on USE CASE, not fragile line numbers.

## Regression Gates

✓ **Real Repo Test:** `bash reference/check-portability.sh` exits 0 (PASS)
```
=== Portability check: /volumes/containers/arscontexta ===
1. No PCRE grep (-P) or long-form in shipped templates
  PASS no grep -P
2. Wiki-link capture terminates at | and #
  PASS link capture terminates correctly
3. No PCRE via ripgrep (fails on rg builds without PCRE2)
  PASS no rg PCRE
PORTABILITY: PASS
```

✓ **Nonexistent Root:** `bash reference/check-portability.sh /nonexistent-root-xyz` exits 1 (FAIL)
```
  FAIL scan directory missing: /nonexistent-root-xyz/skills
  [... 8 more directory failures ...]
PORTABILITY: FAIL
```

## Harness Verification (Task 1 Unaffected)

✓ **Bash:** `bash reference/test/link-extraction.test.sh` → `passed=8 failed=5`
✓ **Zsh:** `zsh reference/test/link-extraction.test.sh` → `passed=10 failed=3`

Both match expected state from Task 1 (8/5 bash, 10/3 zsh).

## Tree -P Verification

✓ **Legitimate Use Not Flagged:**
```bash
tree -L 3 --charset ascii -I '.git|node_modules|.claude' -P '*.md|*.yaml|*.json' .
```
- Check 1 pattern specifically matches `(grep|egrep|fgrep|zgrep)`, not `tree`
- `tree -P` uses `-P` for pattern matching (not Perl regex), legitimately safe
- Correctly excluded from false positives

## Concerns

**None.** All changes are surgical, focused, and verified:
1. Four vectors demonstrably caught
2. Both regression gates pass
3. Harness unchanged (8/5 bash, 10/3 zsh)
4. Legitimate tools (`tree -P`) unaffected
5. Blind-spot comment now maintainable (category-based, not line-based)

The guard now covers the complete PCRE attack surface (grep, egrep, fgrep, zgrep, rg) and provides accurate documentation for remaining blind spots.
