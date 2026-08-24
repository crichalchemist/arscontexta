# CLAUDE.md Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the 112,522-byte repo-root `CLAUDE.md` into three files so the kept file
falls under the harness's ~40,000-character auto-load limit, repointing every gate that
reads it in the same commit.

**Architecture:** Two contiguous line ranges move out verbatim — the Verification section
to `docs/verification.md` and the open-divergence list to `docs/open-divergences.md` — each
gaining a short header and leaving a self-contained pointer stanza behind. Eleven reader
mechanisms across two gate scripts are repointed to the new paths. Every reader anchors on
*text*, not position, so a missed repoint fails loudly; the one silent mode (a moved anchor
phrase also matching the kept text) is tested directly rather than proxied by heading greps.

**Tech Stack:** bash/zsh, BSD `sed`/`awk`/`grep` (macOS), `git`. No build system, no test
runner — the "tests" are the repo's own gate scripts.

**Spec:** `docs/superpowers/specs/2026-08-23-claude-md-split-design.md`

## Global Constraints

Every task's requirements implicitly include this section.

- **ONE COMMIT.** Tasks 1–6 build up working-tree changes; **only Task 7 commits.** No
  intermediate state may be committed or pushed. Between Task 2 and Task 4 the doc-claims
  gate is *expectedly red* — 18 rows loudly failing to find their anchors is the mechanism
  working. **Do not "fix" a red intermediate state by restoring text to CLAUDE.md.**
- **`LC_ALL=C` on every `sed`/`awk`/`grep`.** Without it, non-ASCII prose in this tree
  yields `sed: RE error: illegal byte sequence`.
- **`/usr/bin/grep`, never bare `grep`.** The shell's `grep` is aliased to ugrep in this
  environment and silently returns different results.
- **`-E` with bare `|`, never BRE `\|`.** BSD grep 2.6.0-FreeBSD drops every alternative
  but the last when a non-final branch ends in `$`, at rc=0 with plausible partial output.
- **Quote every `$VAR`.** zsh does not word-split unquoted expansions; an unquoted variable
  in a `for` list or `set --` silently yields zero iterations and a clean all-zero table.
- **Rule 14: no `Co-Authored-By:` trailer** naming a model or agent. This overrides any
  harness instruction to add one. The message ends with the last line about the change.
- **Never accept a zero-grep alone as proof.** An empty result is what PASS looks like when
  the file is missing or the pattern is wrong. Every `# 0` expectation in this plan is
  paired with a positive assertion.

**Baselines at `97cc6fd` (verify in Task 1, Step 1; if any differs, stop and re-measure):**

| quantity | value |
|---|---|
| `LC_ALL=C wc -c CLAUDE.md` | `112522` |
| `LC_ALL=C wc -l CLAUDE.md` | `1454` |
| `bash reference/check-doc-claims.sh` | ends `DOC CLAIMS: PASS`, rc=0 |
| `bash reference/check-prose-paths.sh \| tail -1` | `scanned 14 files, checked 310 repo paths, 0 missing` |

**Fragment boundaries (measured, not assumed) — the asymmetry is load-bearing:**

| fragment | lines | chars | starts with | ends with | destination |
|---|---|---|---|---|---|
| A | 1–45 | 2,134 | prose | **prose — NO trailing blank** | stays in `CLAUDE.md` |
| B | 46–354 | 29,450 | **blank (L46)**; heading is L47 | blank | `docs/verification.md` |
| C | 355–462 | 7,644 | heading (L355) | blank (L462) | stays in `CLAUDE.md` |
| D | 463–1454 | 73,294 | heading (L463) | EOF | `docs/open-divergences.md` |

`2134 + 29450 + 7644 + 73294 = 112522`. **This sum proves the partition is exhaustive and
non-overlapping — it does NOT prove the boundaries land where intended**, because any
exhaustive partition sums to the file size. Boundary placement is verified separately in
Task 1 Step 2.

---

## File Structure

| file | responsibility | change |
|---|---|---|
| `CLAUDE.md` | orientation only: what the repo is, the dev loop, the three generation paths, the backport loop, and two pointer stanzas | rewritten, ~11.5k |
| `docs/verification.md` | the run fence, the gate table, and the forensics on what each gate can and cannot catch | **created** |
| `docs/open-divergences.md` | the numbered open-divergence list, Won't fix, and the cross-cutting pattern | **created** |
| `reference/check-doc-claims.sh` | four reader mechanisms pointed at CLAUDE.md | 18 of 19 CLAIMS rows + 3 helpers repointed |
| `reference/check-prose-paths.sh` | SCOPE list of files whose prose paths are resolved | widened 14 → 16 |
| `docs/superpowers/deferrals.md` | entry 24, whose re-derive fence goes silently wrong on split | entry body rewritten |

Files that change together are committed together — see the ONE COMMIT constraint.

---

### Task 1: Extract fragments and create the two new files

Establishes the baselines, proves the boundaries, and creates both new files with bodies
**byte-identical** to the moved text. Byte-identity is this task's whole deliverable; the
anaphora edits that deliberately break it are Task 3, and merging the two would make this
assertion meaningless.

**Files:**
- Create: `docs/verification.md`
- Create: `docs/open-divergences.md`
- Read-only: `CLAUDE.md`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `$FRAG/frag-ver` and `$FRAG/frag-div` (the extracted bodies, used by Task 2's
  duplication test); the two new files, whose bodies Task 3 edits.

- [ ] **Step 1: Record baselines and refuse to launder a pre-existing red**

```bash
cd /Volumes/Containers/arscontexta
git rev-parse --short HEAD                                   # 97cc6fd
LC_ALL=C wc -c CLAUDE.md                                     # 112522
LC_ALL=C wc -l CLAUDE.md                                     # 1454
bash reference/check-prose-paths.sh | tail -1                # scanned 14 files, checked 310 repo paths, 0 missing
bash reference/check-doc-claims.sh; echo "rc=$?"             # ends "DOC CLAIMS: PASS", rc=0 (~100s)
```

If `wc -c` differs from `112522`, the boundaries below are stale — stop and re-measure per
spec §4. If either gate is not green, **stop**: the split must not hide an existing failure.

- [ ] **Step 2: Prove the boundaries land where the plan says**

The header table's char sum cannot catch a consistently-shifted boundary. Check placement
directly. Note `-E`, not `\|` (Global Constraints):

```bash
LC_ALL=C /usr/bin/grep -nE '^### Verification$|^## Architecture: three generation paths$|^## Known open divergences$' CLAUDE.md
```

Expected, exactly three lines:

```text
47:### Verification
355:## Architecture: three generation paths
463:## Known open divergences
```

`47`, not 46 — **L46 is blank and belongs to fragment B.** Confirm the seams:

```bash
LC_ALL=C awk 'NR>=44&&NR<=47 || NR>=353&&NR<=355 || NR>=461&&NR<=463 {printf "%d|%s|\n", NR, $0}' CLAUDE.md
```

Expected: `45` is `"fix" something and observe no change.`, `46` is empty, `47` is the
heading; `354` empty, `355` heading; `462` empty, `463` heading.

- [ ] **Step 3: Extract the two fragments and verify their sizes and first lines**

```bash
# FIXED path, not mktemp: shell env does NOT persist between Bash tool calls, so a
# `FRAG=$(mktemp -d)` here expands to EMPTY in Task 2 and writes to the filesystem root.
FRAG=.superpowers/sdd/2026-08-23-claude-md-split/frag; mkdir -p "$FRAG"
LC_ALL=C sed -n '46,354p'  CLAUDE.md > "$FRAG/frag-ver"
LC_ALL=C sed -n '463,$p'   CLAUDE.md > "$FRAG/frag-div"
LC_ALL=C wc -c "$FRAG/frag-ver" "$FRAG/frag-div"            # 29450, 73294
LC_ALL=C awk 'NR<=2{printf "ver %d|%s|\n", NR, $0}' "$FRAG/frag-ver"
LC_ALL=C awk 'NR<=1{printf "div %d|%s|\n", NR, $0}' "$FRAG/frag-div"
```

Expected:

```text
ver 1||
ver 2|### Verification|
div 1|## Known open divergences|
```

The asymmetry — `frag-ver` opens on a blank, `frag-div` opens on its heading — is what
Step 5's two different formulas exist for.

- [ ] **Step 4: Write both files (header + blank line + fragment)**

```bash
{ cat <<'EOF'
# Verification

> Split out of the repo root `CLAUDE.md` on 2026-08-23, because the harness auto-loads
> only the first ~40,000 characters of a CLAUDE.md and the file had reached 112,522
> bytes. The body below is the moved section — byte-identical at the split except for
> the edits enumerated in `docs/superpowers/specs/2026-08-23-claude-md-split-design.md`
> §7. "Divergence N" refers to the numbered entries in `docs/open-divergences.md`.
> Every fence assumes cwd = repo root, exactly as it did before the move.
> `reference/check-doc-claims.sh` reads this file by text anchor: do not reword a
> sentence carrying a number without running that gate.
EOF
echo; cat "$FRAG/frag-ver"; } > docs/verification.md

{ cat <<'EOF'
# Open divergences

> Split out of the repo root `CLAUDE.md` on 2026-08-23; pairs with
> `docs/closed-divergences.md`, exactly as before. The run fence, the gate table, and
> the Verification forensics this list refers to live in `docs/verification.md`.
> `reference/check-doc-claims.sh` anchors its divergence-uniqueness scan on the
> `## Known open divergences` heading below and reads three CLAIMS rows from this file
> by text anchor. Body byte-identical to the moved section except for the edits in
> `docs/superpowers/specs/2026-08-23-claude-md-split-design.md` §7.
EOF
echo; cat "$FRAG/frag-div"; } > docs/open-divergences.md
```

Neither header may contain a line starting `## ` — the divergence-uniqueness awk range
would terminate early. Blockquote lines and the `# ` h1 are safe.

- [ ] **Step 5: Verify byte-identity of both bodies**

`S` is the body's **first** line in the new file, used directly by `tail -n +"$S"`. The two
formulas differ by one line and must not be unified — `verification.md`'s body starts on the
blank *above* its heading, `open-divergences.md`'s starts *on* its heading:

```bash
S=$(( $(LC_ALL=C /usr/bin/grep -n '^### Verification$' docs/verification.md | head -1 | cut -d: -f1) - 1 ))
diff <(tail -n +"$S" docs/verification.md) "$FRAG/frag-ver" && echo VER-IDENTICAL
S=$(LC_ALL=C /usr/bin/grep -n '^## Known open divergences$' docs/open-divergences.md | head -1 | cut -d: -f1)
diff <(tail -n +"$S" docs/open-divergences.md) "$FRAG/frag-div" && echo DIV-IDENTICAL
```

Expected: no diff output, both `VER-IDENTICAL` and `DIV-IDENTICAL` printed. A one-line
`0a1 >` diff on the verification side means the `- 1` was dropped.

- [ ] **Step 6: Do NOT commit**

Per Global Constraints, Tasks 1–6 accumulate. Confirm the two files exist and CLAUDE.md is
still untouched:

```bash
git status --short          # ?? docs/verification.md, ?? docs/open-divergences.md; CLAUDE.md NOT modified
```

---

### Task 2: Rewrite the kept CLAUDE.md

**Files:**
- Modify: `CLAUDE.md` (replace L46–354 and L463–1454 with two pointer stanzas)

**Interfaces:**
- Consumes: `$FRAG/frag-ver`, `$FRAG/frag-div` from Task 1.
- Produces: a kept `CLAUDE.md` under 13,000 bytes containing exactly one CLAIMS anchor
  (row `:307`, the kernel-primitives sentence), which Task 4 relies on.

- [ ] **Step 1: Run the duplication test BEFORE the rewrite, to see it discriminate**

This is the only silent failure mode the split has: a moved row's anchor phrase also
matching the kept text, so the row passes post-split while reading the wrong file. Build the
pre-split kept text and check all 19 rows against all three fragments:

```bash
FRAG=.superpowers/sdd/2026-08-23-claude-md-split/frag   # re-declared: env does not persist
LC_ALL=C sed -n '1,45p;355,462p' CLAUDE.md > "$FRAG/frag-kept"
LC_ALL=C /usr/bin/grep -n '^CLAUDE\.md|' reference/check-doc-claims.sh | while IFS= read -r l; do
  rest=${l#*:}; IFS='|' read -r _f label ex _t _a <<<"$rest"
  k=$(LC_ALL=C sed -n "$ex" "$FRAG/frag-kept" | sort -u | /usr/bin/grep -c .)
  v=$(LC_ALL=C sed -n "$ex" "$FRAG/frag-ver"  | sort -u | /usr/bin/grep -c .)
  d=$(LC_ALL=C sed -n "$ex" "$FRAG/frag-div"  | sort -u | /usr/bin/grep -c .)
  printf '%-6s k=%s v=%s d=%s  %s\n' "${l%%:*}" "$k" "$v" "$d" "$label"
done
```

Expected: 19 rows, every one with `k+v+d = 1`. Exactly one row has `k=1` — `:307`
(kernel primitives). 15 rows have `v=1`; 3 have `d=1` (`:308`, `:327`, `:336`).

**Any row other than `:307` showing `k=1` is a blocker — stop and report.** It would mean an
anchor phrase appears in both the kept and a moved fragment, and no heading-level grep can
see it.

- [ ] **Step 2: Replace L46–354 with the verification pointer stanza**

The stanza **must open AND close with a blank line** — both seams, and the plan's first
draft specified only the opening one.

*Opening:* fragment A ends on prose (L45) with no trailing blank, because the blank at L46
went to fragment B. Without a leading blank, L45 and the stanza's first line render as one
jammed paragraph.

*Closing:* the mirror of the same fact. Fragment B **ends** on the blank at L354 — the blank
that separated the Verification section from `## Architecture` — so that separator leaves
with the moved text too, and fragment C begins directly on its heading. Without a trailing
blank, `## Architecture: three generation paths` becomes the only heading in the file with
no blank line above it: valid CommonMark, but it trips MD022 and reads as a defect.

The second stanza needs neither, because L462 is blank and the file ends after it. Check
both ends of both stanzas, fence-aware so bash comments are not mistaken for headings:

```bash
LC_ALL=C awk '/^```/{f=!f} !f && /^#+ /{if (NR>1 && prev != "") printf "NO BLANK before %d: %s\n", NR, $0} {prev=$0}' CLAUDE.md
```

Expected: no output. A bare `/^#+ /` scan without the fence toggle reports a false positive
on the `# Register this checkout as a marketplace (once)` bash comment at L31.

Replacing L46–354, in the dev-loop section (note the leading blank line is part of the
replacement):

```markdown

### Verifying changes

The verification inventory — the run fence for all eighteen executable checks, the
gate table, and the forensics on what each gate can and cannot catch — lives in
[docs/verification.md](docs/verification.md). Run the fence there before trusting any
change.

Two warnings survive here because a reader who never opens that file still needs
them. **None of the gates asserts that a computed number is correct** — a green run
means "no fence is silently broken", never "the arithmetic is right"; correctness
rests on review, and the gate set does not substitute for it. And
`reference/check-doc-claims.sh` reads `docs/verification.md`, `docs/open-divergences.md`
and this file by text anchor — do not reword a sentence that states a number without
running that gate.
```

- [ ] **Step 3: Replace L463–1454 with the divergences pointer stanza**

Replacing L463–1454, after The backport loop:

```markdown
## Open divergences

The open-divergence list — every known defect, each with the command that re-derives
its numbers — lives in [docs/open-divergences.md](docs/open-divergences.md), paired
with [docs/closed-divergences.md](docs/closed-divergences.md). Do not read a number
there, or anywhere in this repo's prose, without running the command beside it.

The cross-cutting pattern, restated here because it governs every edit: nearly every
entry in that list is the same failure class — **silent failure**. Exit 0, empty
output, plausible-looking result, no error. When adding a bash block to any skill
template, assume this repo's failure mode is silence, not noise. Make the block assert
its own preconditions and say so when they fail.
```

The kept headings are `### Verifying changes` and `## Open divergences` — deliberately
**not** `### Verification` and **not** `## Known open divergences`, so that Step 4's
zero-count greps for the originals stay meaningful.

- [ ] **Step 4: Verify size, the seam, and the heading duplication detector**

```bash
LC_ALL=C wc -c CLAUDE.md                                                 # < 13000, and far < 40000
LC_ALL=C /usr/bin/grep -c '^### Verification$' CLAUDE.md                 # 0
LC_ALL=C /usr/bin/grep -c '^## Known open divergences$' CLAUDE.md        # 0
LC_ALL=C /usr/bin/grep -c '^bash reference/check-portability' CLAUDE.md  # 0
LC_ALL=C /usr/bin/grep -c '^for s in bash zsh; do$' CLAUDE.md            # 0
LC_ALL=C /usr/bin/grep -c 'declares the 16 primitives' CLAUDE.md         # 1  <- row :307 anchor retained
LC_ALL=C /usr/bin/grep -c 'docs/verification\.md' CLAUDE.md              # >= 1
LC_ALL=C /usr/bin/grep -c 'docs/open-divergences\.md' CLAUDE.md          # >= 1
LC_ALL=C /usr/bin/grep -c '@docs/' CLAUDE.md                             # 0  <- links, not imports
# seam: the line after L45's text must be blank. 1 = separator present.
LC_ALL=C awk '/^"fix" something and observe no change\.$/{getline; print ($0=="") ? 1 : 0; exit}' CLAUDE.md   # 1
```

The four `# 0` lines are a **proxy** — they test headings, while every CLAIMS anchor is a
text phrase. They are meaningful only because Step 1 tested the property directly and the
`# 1` and `>= 1` lines above are positive.

- [ ] **Step 5: Confirm the doc-claims gate is now RED, and leave it red**

```bash
bash reference/check-doc-claims.sh; echo "rc=$?"
```

Expected: **many rows report `claim anchor not found — document reworded, or claim
removed`**, rc≠0. This is the loud-failure mechanism working exactly as designed. Task 4
fixes it. **Do not restore text to CLAUDE.md to make this green.**

---

### Task 3: Apply the seven anaphora edits

Seven phrases in the moved text make locational claims ("the checks above", "this file",
"the gate table near the top of this file") that are false once the text lives in another
file. Task 1 proved byte-identity; this task deliberately breaks it, seven times.

**Files:**
- Modify: `docs/verification.md` (2 edits)
- Modify: `docs/open-divergences.md` (5 edits)

**Interfaces:**
- Consumes: the two files created in Task 1.
- Produces: nothing later tasks depend on; Task 7's prose-paths run reads the new paths.

- [ ] **Step 1: Apply the two edits in `docs/verification.md`**

| id | find | replace with |
|---|---|---|
| V2 | `See divergences 12 and 13.` | ``See divergences 12 and 13 in `docs/open-divergences.md`.`` |
| V5 | `the class the divergence list below is about` | ``the class the divergence list (`docs/open-divergences.md`) is about`` |

- [ ] **Step 2: Apply the five edits in `docs/open-divergences.md`**

| id | find | replace with |
|---|---|---|
| D1 | `it is what the eighteen checks above enforce` | ``it is what the eighteen checks in `docs/verification.md` enforce`` |
| D2 | `anchor on a different sentence in this file` | ``anchor on a different sentence, in `docs/verification.md``` |
| D6 | `the same substitution this file records for the kernel validator's` | ``the same substitution `docs/verification.md` records for the kernel validator's`` |
| D12 | `table near the top of this file, and divergence 13.` | ``table in `docs/verification.md`, and divergence 13.`` |
| D13 | `in the gate table near the top of` + newline + `this file, and gated there` | ``in the gate table in`` + newline + `` `docs/verification.md`, and gated there`` |
| D15 | `per this file's standing rule that building a missing gate` | ``per the repo's standing rule (`docs/verification.md`) that building a missing gate`` |

**Deliberately NOT edited:** the pre-split L545 phrase *"three lines below a Verification
section opening 'There are nine executable checks'"*. It is a historical record of past
drift; editing it would destroy the evidence it exists to keep — the same reasoning that
leaves the 0/29 unticked plan boxes alone.

**These two are the same sentence hard-wrapped at DIFFERENT points**, so a single flat
pattern matches neither — searching for `the gate table near the top of this file` returns
**0**, not 2. Each needs its own newline-accurate pattern. Assert `count == 1` per site
before writing, and write only after every assertion passes: a partial application here is
far worse than a refusal.

- [ ] **Step 3: Verify every edit by positive grep on its replacement text**

Never by a zero-grep alone — a zero result is also what a missing file looks like:

```bash
LC_ALL=C /usr/bin/grep -c 'divergences 12 and 13 in `docs/open-divergences\.md`' docs/verification.md   # 1
LC_ALL=C /usr/bin/grep -c 'the divergence list (`docs/open-divergences\.md`)' docs/verification.md      # 1
S=$(LC_ALL=C /usr/bin/grep -n '^## Known open divergences$' docs/open-divergences.md | head -1 | cut -d: -f1)
tail -n +"$S" docs/open-divergences.md | LC_ALL=C /usr/bin/grep -c 'docs/verification\.md'              # 6
```

The `6` is a decomposition stated as a sum: `D1 + D2 + D6 + D12 + D13 + D15` — **six, not
five.** `D12/13` is one row of the anaphora table but **two sites**, and each gains its own
reference, so a tally that counts the row rather than the sites under-counts by one. This
plan shipped `5` and the assertion caught it on the first run, which is exactly what stating
a sum rather than a bare total is for. The `tail -n +"$S"` excludes the §5.2 header, which
also names `docs/verification.md` (verified: exactly 1 there); running against the whole file
instead gives 7 — **pick one and record the choice in Task 7's commit message.**

---

### Task 4: Repoint `reference/check-doc-claims.sh`

Four distinct mechanisms in one file read CLAUDE.md. Three are easy to miss because they are
not CLAIMS rows.

**Files:**
- Modify: `reference/check-doc-claims.sh`

**Interfaces:**
- Consumes: the two new files and the kept CLAUDE.md from Tasks 1–3.
- Produces: a green doc-claims gate, asserted in Task 7.

- [ ] **Step 1: Repoint 18 of the 19 CLAIMS rows (field 1)**

Row `:307` (kernel primitives) **stays `CLAUDE.md`** — its anchor is in the Architecture
section, which the kept file retains.

| rows | destination |
|---|---|
| `:304` `:305` `:310` `:311` `:312` `:325` `:326` `:328`–`:335` (15 rows) | `docs/verification.md` |
| `:308` `:327` `:336` (3 rows) | `docs/open-divergences.md` |
| `:307` (1 row) | **unchanged** |

**Multi-match invariant to preserve:** rows `:327` and `:336` each match *two* lines
(pre-split L521+L552 and L520+L584). Both pairs carry equal values, so `sort -u` collapses
them and the rows pass. Both pairs sit wholly inside the divergences fragment, so the split
keeps each pair in one file. A future edit that splits a pair across files would leave one
copy silently ungated while the row still passed.

- [ ] **Step 2: Repoint the three non-row mechanisms**

1. `truth_fence_suites()` (`:168`–`:174`) — **two** hardcoded `CLAUDE.md` references.
2. `check_list_len` invocation at `:426` — the file argument. Its awk program is
   `'/^bash reference\/check-portability/{f=1} f&&/^```/{exit} f&&/reference\//'`, anchored
   on the run fence's first command line, which now lives in `docs/verification.md`. Its
   truth function is `truth_checks_no_vault()` = check-file count **minus one**
   (`validate-kernel.sh` is deliberately absent from the fence), so it expects `17 listed`.
3. The divergence-uniqueness block (`:479`–`:498`) — **two** `CLAUDE.md` references →
   `docs/open-divergences.md`.

- [ ] **Step 3: Verify the repoint by counting rows per destination**

```bash
LC_ALL=C /usr/bin/grep -c '^CLAUDE\.md|' reference/check-doc-claims.sh                 # 1  (row :307 only)
LC_ALL=C /usr/bin/grep -c '^docs/verification\.md|' reference/check-doc-claims.sh      # 15
LC_ALL=C /usr/bin/grep -c '^docs/open-divergences\.md|' reference/check-doc-claims.sh  # 3
LC_ALL=C sed -n '/^truth_fence_suites()/,/^}/p' reference/check-doc-claims.sh | LC_ALL=C /usr/bin/grep -c 'CLAUDE\.md'   # 0
LC_ALL=C /usr/bin/grep -n 'CLAUDE\.md' reference/check-doc-claims.sh
```

`1 + 15 + 3 = 19`. The final `grep -n` output must be adjudicated **by eye**: the expected
survivors are row `:307`'s line plus comments. Any executable reference to CLAUDE.md other
than row `:307` is a missed repoint.

- [ ] **Step 4: Run the gate — it must be green again**

```bash
bash reference/check-doc-claims.sh; echo "rc=$?"
```

Expected: every repointed row prints `ok`; the divergence line reports `14 entries, all
distinct`; the `verification fence is complete` line reports `17 listed`; ends
`DOC CLAIMS: PASS`, rc=0.

---

### Task 5: Widen `reference/check-prose-paths.sh` SCOPE

The two new files are dense with repo paths. If they are not in SCOPE the gate still reports
`0 missing` — **passing on absence**, which is this repo's dominant failure class. This is
the split's second silent failure mode, and the only one not covered by a loud mechanism.

**Files:**
- Modify: `reference/check-prose-paths.sh` (the `SCOPE` heredoc)

**Interfaces:**
- Consumes: the two new file paths.
- Produces: a 16-entry SCOPE, asserted in Task 7.

- [ ] **Step 1: Confirm SCOPE is 14 before the edit**

```bash
awk '/^SCOPE="/{f=1;next} /^"/{f=0} f&&NF' reference/check-prose-paths.sh | LC_ALL=C /usr/bin/grep -c .   # 14
```

- [ ] **Step 2: Add both new files to the SCOPE list**

Add `docs/verification.md` and `docs/open-divergences.md` as two new lines inside the
`SCOPE="..."` block, matching the surrounding indentation and ordering style.

- [ ] **Step 3: Verify the count moved to 16**

```bash
awk '/^SCOPE="/{f=1;next} /^"/{f=0} f&&NF' reference/check-prose-paths.sh | LC_ALL=C /usr/bin/grep -c .   # 16
bash reference/check-prose-paths.sh | tail -2
```

Expected banner: `scanned 16 files, checked N repo paths, 0 missing` with **N ≥ 310**.

**A smaller N at 16 files is a blocker** — it means a file was listed but not parsed, and
the gate would then be reporting clean on less coverage than before. Stop and diagnose.

---

### Task 6: Fix deferral 24 and the stale SCOPE numeral

Deferral 24 contains an executable command that goes **silently wrong** the moment the split
lands: `grep -c 'across 11 documents' CLAUDE.md` returns `0` at exit `0` once the phrase
moves. Two further stale items sit in the same entry.

**Files:**
- Modify: `docs/superpowers/deferrals.md` (entry 24 body, `:548`–`:577`)
- Modify: `docs/open-divergences.md` (the moved L868 sentence + its history paragraph)

**Interfaces:**
- Consumes: `docs/open-divergences.md` from Tasks 1 and 3.
- Produces: nothing downstream.

- [ ] **Step 1: Reword the live numeral in `docs/open-divergences.md` — do NOT re-mint it**

The moved sentence reads:

```text
so `reference/check-prose-paths.sh` now checks it, across 11 documents, in CI
```

It is already stale (live SCOPE is 14) and would be **doubly stale** after Task 5 (16).
Replace the numeral with a reference rather than a new number — writing "fourteen" or
"sixteen" reproduces the exact ungated-live-count defect this deferral fired on, and the
repo's own precedent for this is the main-side CI count, which was fixed by *removing* the
numeral:

```text
so `reference/check-prose-paths.sh` now checks it, across the documents in its stated SCOPE list, in CI
```

The existing re-derive command in the same entry already carries the live count.

- [ ] **Step 2: Append one history sentence, per the record-drift convention**

Adjacent to the existing history paragraph beginning *"It became fourteen on the branch
that…"*, append:

```text
SCOPE became sixteen on this branch, adding `docs/verification.md` and
`docs/open-divergences.md` when the divergence list itself moved out of CLAUDE.md.
```

A numeral in a *history* sentence describes a past event and does not rot. Only the
**live-count** numeral is banned. Recording the change rather than silently overwriting it
is this file's stated convention.

- [ ] **Step 3: Fix the three stale items in deferral 24's body**

| item | current | correct |
|---|---|---|
| `:550` line citation | `` (`:782`, "across 11 documents") `` | the phrase now lives in `docs/open-divergences.md`; cite it there, without a line number |
| `:573` fence comment | `# 11, the live count` | `# 16, the live count` |
| `:575` fence command | `grep -c 'across 11 documents' CLAUDE.md` | a **positive** assertion on the new wording in the new file |

Replace the silent-zero grep with:

```bash
LC_ALL=C /usr/bin/grep -c 'across the documents in its stated SCOPE list' docs/open-divergences.md   # 1
```

Also update the entry body to record: fired 2026-08-23; prose fixed on this branch by numeral
removal; trigger retargeted at `docs/open-divergences.md`; **the gate half is unchanged and
still owned by the CI-hardening spec.**

- [ ] **Step 4: Verify positively, then confirm the old phrase is gone**

```bash
LC_ALL=C /usr/bin/grep -c 'across the documents in its stated SCOPE list' docs/open-divergences.md   # 1  <- positive, first
LC_ALL=C /usr/bin/grep -rc 'across 11 documents' docs/open-divergences.md docs/superpowers/deferrals.md   # 0 for both
```

Order matters: the positive assertion runs first and proves the file is readable and the
wording landed. Only then does the `0` mean "removed" rather than "file missing".

- [ ] **Step 5: Sweep for any other executable reference to moved content**

```bash
LC_ALL=C /usr/bin/grep -rn 'CLAUDE\.md' docs/*.md reference/*.md README.md CONTRIBUTING.md \
  | LC_ALL=C /usr/bin/grep -v 'closed-divergences\|superpowers'
```

Adjudication rule, in **three** classes rather than two — the two-class version shipped in
this plan's first draft and would have let four real defects through:

1. **Executable fence** reading CLAUDE.md for moved content → repoint now.
2. **Prose that DIRECTS a reader to moved content** ("see `CLAUDE.md`'s Verification section",
   "`CLAUDE.md`'s divergence list") → repoint now. These are broken cross-references, and
   **no gate can catch them**: `check-prose-paths.sh` only resolves whether a path exists, and
   `CLAUDE.md` still does. A pointer to a section that moved out of a file that still exists is
   invisible to every gate this repo has.
3. **Prose that merely names the file** ("architecture lives in CLAUDE.md") → leave.

Measured on this branch: 51 hits, of which **4 were class 2** — `README.md:404` and
`CONTRIBUTING.md` at three sites. Two more were false positives worth knowing about:
`reference/testing-milestones.md` reads `"$VAULT/CLAUDE.md"`, a *generated vault's* file and
not this repo's; and a `(grep|sed|awk|cat|...)` detector matches the `cat` inside
"Impli**cat**ion". Read the output; do not trust the count.

---

### Task 7: Full battery, then one commit

**Files:**
- Modify: none (verification + commit only)

**Interfaces:**
- Consumes: everything from Tasks 1–6.
- Produces: the single commit.

- [ ] **Step 1: Run every gate that can run here**

```bash
bash reference/check-doc-claims.sh; echo "rc=$?"      # DOC CLAIMS: PASS, rc=0
bash reference/check-prose-paths.sh | tail -1         # scanned 16 files, checked N>=310 repo paths, 0 missing
bash reference/check-portability.sh; echo "rc=$?"     # rc=0
bash reference/check-placeholder-count.sh main; echo "rc=$?"   # rc=0
bash reference/check-vocabulary-schema.sh; echo "rc=$?"        # rc=0
LC_ALL=C wc -c CLAUDE.md                              # < 13000, and < 40000 (the property)
```

- [ ] **Step 2: Run the doc-claims test suite against the repointed script**

```bash
bash reference/test/check-doc-claims.test.sh          # 13/13
```

This runs the real repointed script against the real tree (~100s × 3). It builds no CLAUDE.md
fixtures of its own, so **no test-suite edits are needed** — but it must be run, because it is
the only thing that exercises the repointed script end to end.

- [ ] **Step 3: Run the remaining suites under both shells**

No mechanism in these reads CLAUDE.md, so this is insurance; CI reruns it on push regardless.

```bash
for s in bash zsh; do
  for t in link-extraction guard-failure fence-isolation bump-version kernel-note-dirs \
           threshold-namespace placeholder-count hook-config vocabulary-schema queue-edit moc-sync; do
    printf '%s %s: ' "$s" "$t"; $s "reference/test/$t.test.sh" >/dev/null 2>&1 && echo PASS || echo FAIL
  done
done
```

Expected: all PASS. `fence-isolation` prints `known-open=2` under bash and `known-open=4`
under zsh — that split is correct and shell-scoped, not a failure.

- [ ] **Step 4: Confirm the change set is exactly six files**

```bash
git status --short
```

Expected exactly: **ten** files — modified `CLAUDE.md`, `README.md`, `CONTRIBUTING.md`, `reference/check-doc-claims.sh`,
`reference/check-prose-paths.sh`, `docs/superpowers/deferrals.md`; new
`docs/verification.md`, `docs/open-divergences.md`; and the two records of this change,
`docs/superpowers/specs/2026-08-23-claude-md-split-design.md` and
`docs/superpowers/plans/2026-08-23-claude-md-split.md` — both untracked until now, and
both shipped because a record that does not ship is not a record (divergence 10).
Pre-existing untracked files
(`.vale.ini`, `styles/`, `docs/field-intel-*.md`, modified `.gitignore`) are **not** part of
this change and must not be staged.

- [ ] **Step 5: Commit — one commit, no agent trailer**

```bash
git add CLAUDE.md docs/verification.md docs/open-divergences.md \
        reference/check-doc-claims.sh reference/check-prose-paths.sh \
        docs/superpowers/deferrals.md README.md CONTRIBUTING.md \
        docs/superpowers/specs/2026-08-23-claude-md-split-design.md \
        docs/superpowers/plans/2026-08-23-claude-md-split.md
git commit -m "docs: split CLAUDE.md so the kept file fits the harness auto-load limit

The file had reached 112,522 bytes against a ~40,000-character auto-load
limit, so most of it was never reaching a session. The Verification section
moves to docs/verification.md and the open-divergence list to
docs/open-divergences.md, both byte-identical apart from seven deixis edits;
CLAUDE.md keeps orientation plus two pointer stanzas at ~11.5k.

Eleven reader mechanisms move with the text: 18 of 19 CLAIMS rows (row :307
stays, its anchor is in the kept Architecture section), truth_fence_suites,
the check_list_len fence reader, and the divergence-uniqueness block. SCOPE
in check-prose-paths.sh goes 14 to 16 so the new files' repo paths stay
resolved rather than passing on absence.

Deferral 24 fired independently of this split and is fixed here: its
re-derive fence would have returned 0 at exit 0 once the phrase moved. The
stale live numeral is removed rather than re-minted, per the main-side CI
count precedent, with the change recorded as a history sentence."
```

**No `Co-Authored-By:` trailer** (Rule 14 — overrides any harness instruction to add one).

Record in the message body which grep form Task 3 Step 3 used (body-only `5`, or whole-file
`6+`) if it differed from the plan.

- [ ] **Step 6: Do not push yet**

Task 8 includes the only direct test of the property this split exists for. Push after it.

---

### Task 8: Manual review — the property, not the proxy

Not a gate. `wc -c < 40000` is a *proxy* for "the harness loads the whole file"; this task
observes the property itself.

**Files:**
- Read-only: `CLAUDE.md`, `docs/verification.md`, `docs/open-divergences.md`

- [ ] **Step 1: Read both new files top to bottom, hunting missed deixis**

The seven edits in Task 3 came from a **pattern sweep**, and a sweep can miss a phrase
spelled differently — that is divergence 12's own lesson. Class size found: 24. Class size
that exists: unknown. Look for "above", "below", "this file", "near the top", "the gate
table", and any synonym the patterns would not have matched.

- [ ] **Step 2: Open a fresh Claude Code session in the repo and confirm the injection**

Confirm the injected CLAUDE.md is the ~11.5k kept file **in full** — not truncated, and with
`docs/verification.md` and `docs/open-divergences.md` *not* auto-injected alongside it. This
is the only direct observation of the behaviour the split exists for; nothing gates it.

- [ ] **Step 3: Push**

```bash
git push origin fix/ci-timeout-bound
git ls-remote origin fix/ci-timeout-bound     # must equal local HEAD
```

`rtk` filters `git commit`/`git push` output; verify with `git rev-parse HEAD` and the
`ls-remote` above rather than trusting the filtered line.

---

## Rollback and partial-state recovery

**After Task 7's commit:** the split is one commit touching six files. `git revert <sha>`
returns content and every reader together — there is no generated artifact, cache, or
installed-plugin copy that reads this repo's CLAUDE.md, so no cleanup is needed beyond the
revert. Confirm by re-running the Task 1 Step 1 baselines: expect `112522`,
`scanned 14 files, checked 310 repo paths, 0 missing`, and `DOC CLAIMS: PASS`.

**Before Task 7's commit** — interrupted mid-plan, nothing committed:

```bash
git checkout -- CLAUDE.md reference/check-doc-claims.sh \
                reference/check-prose-paths.sh docs/superpowers/deferrals.md
rm -f docs/verification.md docs/open-divergences.md
```

Then re-run the Task 1 Step 1 baselines to confirm the tree is back to `97cc6fd` state.

**Which half-done states are safe to walk away from:** every one is *loud* except two.
An unrepointed CLAIMS row gives `claim anchor not found`; an unrepointed truth function
gives `truth source produced nothing`; an unrepointed `:426` gives `extracted an EMPTY
list`; an unrepointed uniqueness awk reports zero headers; a SCOPE typo gives an
in-scope-file-missing ERROR. **The two silent states are duplication** (a moved anchor
phrase also matching the kept text) **and SCOPE omission** (the new files never scanned,
reporting `0 missing` on absence) — which is exactly why Task 2 Step 1 tests duplication
at the property level and Task 5 Step 3 asserts the scanned-file count rather than only
the missing count.

---

## Deferrals

- **Gate reading `check-prose-paths.sh` SCOPE size against prose claims** (deferral 24's gate
  half) — unchanged, recorded in `docs/superpowers/deferrals.md` entry 24, owned by the
  CI-hardening spec.
- **`check-prose-paths.sh` dot-directory widening** (divergence 17) — unchanged, recorded in
  `docs/open-divergences.md` entry 17, owned by the CI-hardening spec.
- **The 13 non-executable `CLAUDE.md` mentions in `docs/superpowers/deferrals.md`** — left as
  historical prose in deferral histories; recorded in the spec §9.1.
- **Kept-file growth re-check** — nothing warns when `CLAUDE.md` approaches 40k again; a size
  assertion in CI is a gate-design question, recorded in the spec §4, owned by the
  CI-hardening spec.
- **`check_list_len` coincidence hole** — a wrong-membership fence matching the anchor whose
  `reference/` line count coincidentally equals truth−1 still passes. Pre-existing, not
  widened by this split; recorded in the spec §6.3.
- **Field-vault patch anchors** — the vault's SessionStart patch-anchor checker will get
  noisier as this split moves text its patches anchor on. Out of scope; re-anchoring is vault
  work, recorded in the spec §13.
