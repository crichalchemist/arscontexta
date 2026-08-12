# Post-Merge Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the ten findings of the adversarial review of `a98352c`, plus three out-of-band
requests and six deferrals salvaged from the deleted SDD ledgers, without changing what
generation emits.

**Architecture:** Four groups of finding-driven work (shared-library correctness, `queue-edit`
guarding, suite blind spots, the hook template's silent skip), then six salvaged deferrals that
harden the gates and readers those groups depend on, then the three out-of-band items. Every
change is repo-internal: no task alters a `generators/` block or what a generated vault receives.

**Tech Stack:** POSIX-portable bash/zsh, `awk`/`sed`/`grep`/`git`, no new dependencies.

Implements `docs/superpowers/specs/2026-08-09-post-merge-hardening-design.md` — groups A, B, C
and E, its Design sections 9-14, and its out-of-band sections 6-8.

Source findings: adversarial review of `main` at `a98352c`. Six Important, four Minor.

**Both of the spec's open decisions were RULED by the user on 2026-08-09, and both rulings are
"do not act".** They are recorded in `## Deferrals`, not implemented:

- **Decision 1 — orphan semantics (F4, group D).** Ruled: keep deferred as latent. All three
  computable semantics return 0 on the field vault, whose `nodes/` has no subdirectories, so
  nothing forces the ruling today. No task here.
- **Decision 2 — the PostToolUse matcher (spec D15).** Ruled: option C, record and wait.
  `hooks/hooks.json` is **not** edited by any task. Widening the matcher alone buys zero
  coverage on any vault that renamed its notes directory, because the hardcoded `*/notes/*`
  filter blocks it regardless.

**Tasks 16–18 are out-of-band** — requested directly on 2026-08-09, not review findings. They
implement the spec's sections 6, 7 and 8. They are last because they are independent of
Tasks 1–15 and of each other; they can also be lifted into their own commit or branch without
disturbing the finding-driven work, which is why they are not interleaved.

**Ordering is deliberate and not arbitrary.** Suite hygiene comes first (Tasks 1 and 2) because
later tasks add assertions to that same suite and must not be written in an idiom those tasks
then rewrite — and because Task 2 makes the suite safe to run while another run is in flight,
which every later task benefits from. The `queue-edit` suite (Task 7) precedes its fix (Task 8)
so the guard is proved absent before it is added. Task 14 follows Task 10 because Task 10 adds
the template warning text that motivates widening the gate's scope.

## Global Constraints

1. **Every new assertion must be mutation-proved, and the mutation must be asserted to
   have applied** (`cmp -s` before/after). A `sed`/`perl` that matches nothing reports the
   same all-green as a robust assertion. A rising assertion total is not evidence — this
   repo has shipped a suite whose new rows could not fail.
2. **Run every suite under BOTH `bash` and `zsh`.** Three shipped defects here were
   shell forks. zsh's default `nomatch` makes an unmatched glob an error, not an empty list.
   zsh also does **not** word-split an unquoted `$var` in a `for` list; use `while IFS= read -r`.
3. **Guard the producer, never a pipeline.** `cmd > "$tmp" || { …; return 1; }`, then
   transform from the temp. A pipeline's rc is its last stage's, and `sort`/`awk` succeed
   on empty input. This class appeared five times in the previous plan; the spec's
   findings add a sixth.
4. **Never `set -o pipefail` in a sourced library** (it leaks into the caller's shell) and
   never `PIPESTATUS`/`pipestatus` (spelled differently in bash and zsh).
5. **No hardcoded `notes/` or `nodes/` in `skill-sources/`.** Templates carry
   `{vocabulary.*}` / `{{NOTES_DIR:-notes}}` placeholders. `skills/**` is a different tree
   and this does not bind it.
6. **The fence gate must stay `files=27 fences=78 run=75 skipped=3`**, and the three skips
   must remain `remember f04`, `tasks f03`, `reseed f03`. A PASS alone proves nothing — a
   fence it cannot parse is skipped, not failed. **Run it serially until Task 2 lands**; Task 2
   is what makes concurrent same-shell runs safe, and until then a background run will corrupt
   a foreground one's workspace.
7. **`$WORK` in the fence gate must contain no digit.** Assertion N asks whether a fence emitted
   digits and `has_digit` tests the whole captured file, so a digit anywhere in the scratch path
   produces a false finding against correct code. This is why Task 2 does **not** use
   `mktemp -d`, and why any later "simplification" of that line is a regression.
8. **Do not renumber `CLAUDE.md` divergences**, and do not renumber `deferrals.md` entries.
   Work in flight references both by number.
9. **Line numbers in the spec and this plan drift.** Re-derive each with the command
   beside it before editing; take edit anchors from `sed`, never from a Read.
10. **`/usr/bin/grep`** when the search behaviour is itself the question — the Bash tool
    aliases `grep` to `ugrep`, which supports `-P`, so portability bugs test clean.
11. **Two gates change internally: `check-portability.sh` (Task 13) and `check-prose-paths.sh`
    (Task 14).** The sixteen-gate inventory and the fence-gate counts are unchanged, but those
    two must go red under their own mutation and green after. Criterion 1's "all gates green,
    unchanged" governs the inventory, never the contents of an individual check.
12. **No task edits `hooks/hooks.json`.** Decision 2 was ruled C. A diff touching that file
    means the ruling was overridden without being asked.

## File Structure

```
reference/lib/link-extraction.sh          Tasks 3, 4, 5   (version 3 -> 4 in Task 4)
reference/lib/queue-edit.sh               Task 8
reference/test/link-extraction.test.sh    Tasks 1, 3, 4, 5
reference/test/fence-isolation.test.sh    Tasks 1, 2      (location-independence; work dir)
reference/test/queue-edit.test.sh         Task 7          (new)
reference/test/hook-config.test.sh        Task 11
reference/test/threshold-namespace.test.sh Task 12
reference/test/guard-failure.test.sh      Task 13
reference/check-portability.sh            Task 13         (check 6 internals)
reference/check-prose-paths.sh            Task 14         (SCOPE 9 -> 11, see Task 14)
hooks/scripts/session-orient.sh           Task 11
hooks/scripts/read_config.sh              Task 12
.github/workflows/checks.yml              Task 7          (+2 steps, bash and zsh)
skill-sources/graph/SKILL.md              Task 4
skill-sources/stats/SKILL.md              Task 4
skill-sources/next/SKILL.md               Task 6
skills/health/SKILL.md                    Tasks 4, 9, 16
platforms/claude-code/hooks/session-orient.sh.template   Tasks 10, 11, 14
docs/superpowers/deferrals.md             Task 15
CLAUDE.md                                 Tasks 15, 18
skills/setup/SKILL.md                     Task 16         (frontmatter only — :1317 is frozen)
skills/upgrade/SKILL.md                   Task 16
skills/architect/SKILL.md                 Task 16
README.md                                 Task 17
```

Three files are touched by more than one task and the sequence matters.
`skills/health/SKILL.md` takes Tasks 4 and 9 before Task 16's frontmatter edit, so the diffs stay
separable. `platforms/claude-code/hooks/session-orient.sh.template` takes Task 10's silent-skip
fix, then Task 11's totals check if it carries those lines, then enters Task 14's gate scope.
`reference/test/fence-isolation.test.sh` takes Task 1 and Task 2 on independent lines — re-run
the suite after each rather than assuming the second subsumes the first.

---

## Task 1: Make the suite location-independent (F8)

Section 18b's six `LC_ALL=C` structural assertions read the library via a CWD-relative
path with hardcoded line numbers, while every other assertion uses `$HERE`-derived `$LIB`.

- [ ] **Step 1: Reproduce the false failures**
```bash
cd reference/test && bash link-extraction.test.sh | tail -1   # expect: passed=85 failed=6
cd ../..          && bash reference/test/link-extraction.test.sh | tail -1   # passed=91 failed=0
```
Both numbers must be observed before changing anything. If the first is not `85/6`, stop —
the finding has drifted and the task needs re-scoping.

- [ ] **Step 2: Convert the six assertions to `$LIB` and content anchors**
Replace `sed -n '414p' reference/lib/link-extraction.sh` with a content-anchored search
against `"$LIB"`. Anchor on the distinguishing text of each pinned line, not its number —
the hardcoded `414` rots on any edit above it, and Task 4 edits above it.

- [ ] **Step 3: Verify location independence**
```bash
cd reference/test && bash link-extraction.test.sh | tail -1   # now 91/0
cd ../..          && bash reference/test/link-extraction.test.sh | tail -1   # 91/0
```

- [ ] **Step 4: Mutation-prove the assertions still bite**
Strip `LC_ALL=C` from one pinned site, `cmp`-guard, confirm red, restore. They must still
fail for the reason they existed — a content anchor that matches too loosely passes on a
broken library, which is a worse failure than the CWD bug being fixed.

- [ ] **Step 5: Both shells, then commit**

---

## Task 2: Fence-gate work dir — unique per run AND still digit-free (spec §11, D14)

**Files:**
- Modify: `reference/test/fence-isolation.test.sh` (the comment block above `WORK=`, and the
  `WORK=` line itself — currently `:45`–`:50`, re-derive)

**Interfaces:**
- Consumes: nothing from Task 1. Task 1 changes how the suite resolves its *repo root*; this
  changes where it puts its *scratch*. Independent lines, same file — if both land, re-run the
  suite once after each.
- Produces: a `$WORK` that is unique per process. Every later task that adds assertions to this
  suite (Tasks 3, 4, 5, 7, 13) can then be developed while a background run is in flight.

**Read this before touching the line — the obvious fix is wrong.**
`mktemp -d` is forbidden here and the four comment lines above `:50` say why: assertion N asks
whether a fence emitted digits on stdout, `has_digit` (`:701`) tests the **whole** captured file
with `case "$(cat "$1")" in *[0-9]*)`, and an `mktemp` path such as
`/var/folders/f2/9vss9brn.../T/tmp.XyZ123` carries digits. Any fence echoing a path under that
root then reports a defect against correct code. That was a measured near-miss false Critical,
which is why the path is pinned today. `deferrals.md` entry 14 and an earlier draft of spec §11
both proposed `mktemp -d`; both were wrong and are corrected.

- [ ] **Step 1: Confirm the collision is real, and that `$SELF` is the only token**

```bash
/usr/bin/grep -n 'SELF=' reference/test/fence-isolation.test.sh          # :42 — bash|zsh only
/usr/bin/grep -n 'WORK="/tmp/fence-isolation-gate' reference/test/fence-isolation.test.sh
```

Expected: `SELF` is `bash` or `zsh` and nothing else, so two runs under the SAME shell resolve to
one directory. That is the defect; the two CI jobs (different shells) were never the problem.

- [ ] **Step 2: Write the failing check — the path must be unique per process**

Run this twice concurrently and confirm today's code collides:

```bash
cat > /tmp/dw-collide.sh <<'EOF'
#!/bin/bash
SELF=bash
WORK="/tmp/fence-isolation-gate-$SELF"
mkdir -p "$WORK" && echo "$WORK"
EOF
a=$(bash /tmp/dw-collide.sh); b=$(bash /tmp/dw-collide.sh)
[ "$a" = "$b" ] && echo "COLLIDES (expected before the fix): $a"
rm -rf /tmp/fence-isolation-gate-bash /tmp/dw-collide.sh
```

Expected: `COLLIDES (expected before the fix)`.

- [ ] **Step 3: Change the `WORK=` line**

Replace:

```bash
WORK="/tmp/fence-isolation-gate-$SELF"
```

with:

```bash
WORK="/tmp/fence-isolation-gate-$SELF-$(printf '%s' "$$" | tr '0-9' 'abcdefghij')"
```

`91553` becomes `jbffd`: unique per process, and free of digits so assertion N is untouched.

- [ ] **Step 4: EXTEND the comment block above it — do not replace it**

The existing four lines are the only record of why `mktemp -d` is forbidden. Keep them and append:

```bash
# The shell name alone is NOT unique: SELF is bash|zsh, so two runs under the
# same shell shared one directory and clobbered each other (deferrals 14). The
# PID supplies uniqueness, but `$$` is digits and would re-break the rule this
# comment states, so it is mapped through tr '0-9' 'abcdefghij'. Do NOT
# "simplify" this to mktemp -d: that reintroduces digits and the false Critical.
```

- [ ] **Step 5: Verify BOTH properties — unique, and digit-free**

```bash
SELF=bash; W="/tmp/fence-isolation-gate-$SELF-$(printf '%s' "$$" | tr '0-9' 'abcdefghij')"
echo "path: $W"
[ -z "$(printf '%s' "$W" | tr -cd '0-9')" ] && echo "PASS digit-free" || echo "FAIL has digits"
```

Expected: `PASS digit-free`. Checking only uniqueness would accept `mktemp -d`, which is the
whole point of criterion 25a.

- [ ] **Step 6: Run the suite serially, then concurrently**

```bash
for s in bash zsh; do $s reference/test/fence-isolation.test.sh 2>&1 \
  | /usr/bin/grep -E 'files=|FENCE ISOLATION'; done
```

Expected: `files=27 fences=78 run=75 skipped=3`, `known-open=2` (bash) / `4` (zsh), PASS both —
Global Constraint 6 unchanged.

```bash
bash reference/test/fence-isolation.test.sh > /tmp/dw-a.log 2>&1 &
bash reference/test/fence-isolation.test.sh > /tmp/dw-b.log 2>&1 &
wait
/usr/bin/grep -c 'FENCE ISOLATION: PASS' /tmp/dw-a.log /tmp/dw-b.log
/usr/bin/grep -c 'extracted no fences' /tmp/dw-a.log /tmp/dw-b.log
rm -f /tmp/dw-a.log /tmp/dw-b.log
```

Expected: each log has `1` PASS and `0` `extracted no fences`. Before the fix, one run reports
`harness: extracted no fences — cannot conclude anything`.

- [ ] **Step 7: Commit**

```bash
git add reference/test/fence-isolation.test.sh
git commit -m "Fence gate: make \$WORK unique per run without reintroducing digits

\$SELF is bash|zsh, so it separated the two CI jobs but not two runs of the
same shell; concurrent local runs clobbered each other and one reported
'extracted no fences' (deferrals 14).

NOT mktemp -d, which deferrals 14 and a draft of spec 11 both proposed.
Assertion N's has_digit tests the whole captured file and mktemp paths carry
digits, so that swap trades a loud collision for the silent false Critical
the comment above this line already records. The PID is mapped through
tr '0-9' 'abcdefghij' instead: unique, and still digit-free.

Comment block EXTENDED, not replaced -- it is the only record of why the
plain fix is forbidden.

Verified: path has no digit; two concurrent same-shell runs both PASS; the
gate still reports files=27 fences=78 run=75 skipped=3."
```

---

## Task 3: Prove the source-side case fold (F5)

Independently confirmed: deleting `_fold_lower` from both edge-map builders
(`:299`, `:337`) leaves the suite **91/0 green**.

- [ ] **Step 1: Add a discriminating fixture**
A capitalized source filename whose only link is to its own lowercase form —
`Myself.md` containing `[[myself]]`. Nothing else in `EDGE_DIR` has a capitalized source,
which is why the contract is currently unasserted.

- [ ] **Step 2: Assert the behaviour, not the fixture's existence**
`orphan_notes` must report `myself` as an orphan: a self-link is not an incoming link.
Under the mutant, column 1 is `Myself` and column 2 is `myself`, `$1 != $2` no longer
excludes the self-edge, and the note is rescued.

- [ ] **Step 3: Mutation-prove — this is the task's entire point**
```bash
B=$(mktemp); cp reference/lib/link-extraction.sh "$B"
perl -pi -e 's/^(\s*)src=\$\(basename "\$f" \.md \| _fold_lower\)/$1src=\$(basename "\$f" .md)/' \
  reference/lib/link-extraction.sh
cmp -s "$B" reference/lib/link-extraction.sh && echo 'MUTATION DID NOT APPLY — result meaningless' \
  || bash reference/test/link-extraction.test.sh | tail -1     # MUST be failed>=1
cp "$B" reference/lib/link-extraction.sh; rm -f "$B"
git status --porcelain    # must be clean
```
Confirm the mutation applies at **2 sites**. If the suite is still green, the assertion
does not test what it claims and the task is not done.

- [ ] **Step 4: Both shells, then commit**

---

## Task 4: Pin `LC_ALL=C` on the exported sorts (F3)

`existing_note_index{,_recursive}` and `extract_link_targets{,_recursive}` end in bare
`sort -u`, so consumers receive ambient-locale-collated streams and join them against
`LC_ALL=C`-sorted ones.

- [ ] **Step 1: Re-derive the four sites**
```bash
sed -n '195p;207p;272p;283p' reference/lib/link-extraction.sh   # four `| _fold_lower | sort -u`
```

- [ ] **Step 2: Add structural assertions first, watch them fail**
In the Task-1 idiom. This cannot be falsified functionally on macOS — BSD `sort` ignores
collation — so structural is the honest form, and the assertion comment must **say** that
rather than implying a behavioural test.

- [ ] **Step 3: Pin all four**

- [ ] **Step 4: Fix the two consumer `comm` sites and correct their false comments**
```bash
grep -n 'COVERED=' skill-sources/graph/SKILL.md skill-sources/stats/SKILL.md
```
Both carry a comment asserting *"Both operands reach comm already folded and sorted, which
is what makes it valid."* They were sorted — not under the same collation. Correct the
comment to name the distinction; leaving it is worse than the bug, because it tells the
next reader the site was checked.

- [ ] **Step 5: Bump `LINK_EXTRACTION_VERSION` 3 → 4 and raise ONLY the dependent floors**
```bash
grep -n 'LINK_EXTRACTION_VERSION=' reference/lib/link-extraction.sh          # :53
grep -rn 'LINK_EXTRACTION_VERSION" -lt' skills/ skill-sources/ platforms/ hooks/ | wc -l   # 13
```
A stale v3 copy in a vault returns locale-sorted exports to a consumer that now pins
`LC_ALL=C` on its own side — which **reproduces the bug this task fixes**. The floor is
what prevents that, so the bump is not cosmetic.

Raise the floor **only at sites that join a library export with `comm`**. Enumerate them
with a command; do not guess, and do not raise all 13 — most consumers only count lines
and do not depend on collation, and forcing them to demand a refresh is scope creep
(Rule 4). State the enumerated list in the commit message.

- [ ] **Step 6: Full gate sweep, both shells, then commit**
Including the fence gate, serially, with `run=75 skipped=3` confirmed.

---

## Task 5: Whitespace preservation and error-flag hygiene (F7, F9)

Two independent small fixes in one file.

- [ ] **Step 1: Reproduce the whitespace collapse**
Fixture: `n/linker.md` containing `[[double  space]]` (two spaces) and `n/double  space.md`.
```
link_edge_map n    -> linker \t double  space \t <path>    # two spaces preserved
backlink_counts n  -> double space \t 1                    # collapsed — the defect
```
Add this as a failing assertion before fixing.

- [ ] **Step 2: Rebuild without re-splitting**
```bash
sed -n '378p;395p' reference/lib/link-extraction.sh
#   | LC_ALL=C awk '{ c=$1; $1=""; sub(/^ /,""); printf "%s\t%s\n", $0, c }'
```
Default FS splits on any whitespace and reassembling `$0` collapses runs. The consumer
impact is real: `skills/health` Categories 7 and 8 key on `$1==n` against this table, so a
corrupted key silently defaults `incoming` to 0 and the note is falsely reported stale.

- [ ] **Step 3: Clear the error flag before first use**
```bash
grep -c 'link-extraction-err-\$\$' reference/lib/link-extraction.sh   # 6 sites
```
`$$` is recyclable, so debris from a prior run killed between `touch` and cleanup makes
the next call in that PID return 1 spuriously. `bump-version.sh` fixed this exact class by
deleting same-PID leftovers before first use. **Do not** make the path unique per call —
the concurrency half is latent, no call site runs two library calls concurrently, and
speculative generality is out of scope.

- [ ] **Step 4: Mutation-prove both, both shells, then commit**

---

## Task 6: `/next`'s `LINK_LIB` is bare and relative (spec §13, D3)

**Files:**
- Modify: `skill-sources/next/SKILL.md` (the `LINK_LIB=` line, currently `:261` — re-derive)

**Interfaces:**
- Consumes: nothing. Tasks 3-5 change `reference/lib/link-extraction.sh`'s internals; this
  changes how one consumer *locates* it. Independent.
- Produces: all nine `LINK_LIB=` sites in `skill-sources/` spell the `$VAULT_ROOT`-prefixed
  form, so a later reader can grep one spelling.

This is the only salvaged deferral that folds in on its own stated terms: D3 says *"Reopens:
immediately — this is a 'do it separately', not a 'do it never'. Anyone touching `next`'s link
fences should take it."*

- [ ] **Step 1: Confirm the split is 8 prefixed / 1 bare**

```bash
/usr/bin/grep -rn 'LINK_LIB=' skill-sources/
/usr/bin/grep -rh 'LINK_LIB=' skill-sources/ | /usr/bin/grep -vc 'VAULT_ROOT'
```

Expected: 9 sites total, the second command prints `1`, and the bare one is in `next/SKILL.md`.

- [ ] **Step 2: Confirm `$VAULT_ROOT` is in scope in that fence before relying on it**

A prefixed path referencing a variable the fence never sets is worse than a relative one: it
resolves to `/ops/lib/link-extraction.sh` and fails to source with no clue why.

```bash
awk '/^```bash/{n++} n==3' skill-sources/next/SKILL.md | /usr/bin/grep -n 'VAULT_ROOT'
```

Expected: at least one `VAULT_ROOT=` assignment **before** the `LINK_LIB=` line in the same
fence. If there is none, this task's fix is to add the assignment the other eight fences use —
do not ship the prefix without it.

- [ ] **Step 3: Change the line**

Replace:

```bash
LINK_LIB="ops/lib/link-extraction.sh"
```

with:

```bash
LINK_LIB="$VAULT_ROOT/ops/lib/link-extraction.sh"
```

- [ ] **Step 4: Verify the split is now 9 / 0**

```bash
/usr/bin/grep -rh 'LINK_LIB=' skill-sources/ | /usr/bin/grep -vc 'VAULT_ROOT'
```

Expected: `0`. Criterion 27 asks for 9 prefixed, 0 bare.

- [ ] **Step 5: Prove it is behaviour-neutral**

The fence's working directory is already the vault root in normal invocation, so the reported
numbers must not move. Run the fence gate — it executes this fence against the healthy fixture:

```bash
for s in bash zsh; do $s reference/test/fence-isolation.test.sh 2>&1 \
  | /usr/bin/grep -E 'files=|FENCE ISOLATION'; done
```

Expected: `files=27 fences=78 run=75 skipped=3`, PASS both shells. **A changed count means this
was not behaviour-neutral and the fix is wrong**, not that the count needs updating.

- [ ] **Step 6: Commit**

```bash
git add skill-sources/next/SKILL.md
git commit -m "next: spell LINK_LIB with \$VAULT_ROOT like the other eight sites

Eight sites use \"\$VAULT_ROOT/ops/lib/link-extraction.sh\"; next:261 alone
used a bare relative path that resolves against the fence's working
directory. deferrals.md entry 3, whose stated trigger is 'anyone touching
next's link fences should take it'.

Behaviour-neutral where the working directory is already the vault root,
which is why it was correctly kept out of the link-library change whose
whole risk was reported numbers moving. Fence gate unchanged at
files=27 fences=78 run=75 skipped=3."
```

---

## Task 7: A test suite for `queue-edit.sh` (F1c)

This library has **seven consumers and zero tests** — which is how the unguarded commit
step shipped.

```bash
ls reference/test/ | grep -i queue                 # nothing today
grep -rln 'queue-edit' reference/ .github/         # library + fence gate only
```

- [ ] **Step 1: Build `reference/test/queue-edit.test.sh`**
Mirror `bump-version.test.sh`'s structure. Cover the paths that exist today: successful
edit, missing file, unreadable file, a filter jq rejects, lock acquisition failure.

- [ ] **Step 2: Assert the DEFECT — these must be RED at this task's end**
The commit-step guard does not exist yet, so its assertions fail. That is the point: the
suite proves the defect before Task 8 fixes it. Assert (a) rc 1 on a failed rename,
(b) the temp is discarded, (c) the failing path is named in the message.

Stub the rename to force the failure — `chflags uchg` (macOS) / `chattr +i` (Linux root)
is the organic trigger but is **not portable to CI**, the same limit `bump-version`'s
record states. Cover the mechanism with the stub; document the organic trigger as
hand-run. **Do not round that up to "covered".**

- [ ] **Step 3: Guard against the vacuous-suite failure mode**
Every assertion mutation-proved with an applied-guard. Include a positive control that
proves the harness can see a temp file at all — a negative assertion passes on absence,
and four such assertions once passed for free in this repo because nothing tied the search
to the code under test.

- [ ] **Step 4: Wire into CI, both shells**
```bash
grep -c '^      - ' .github/workflows/checks.yml   # record before and after; +2 expected
```

- [ ] **Step 5: Commit with the suite RED and say so in the message**
A red suite on `main` is not acceptable as an end state — Task 8 follows immediately. If
work stops here, this is the one commit that must not be left as the tip.

---

## Task 8: Guard the `queue-edit` commit step (F1a, F1b)

- [ ] **Step 1: Confirm Task 7's assertions are red for the right reason**

- [ ] **Step 2: Guard the rename**
```bash
sed -n '61p;67p' reference/lib/queue-edit.sh
```
`:67` is `mv "$tmp" "$file"`, unguarded, against a stated contract of *"Fails loud …
return 1"*. Adopt the `bump-version.sh` remedy verbatim — it is the house idiom and
already reviewed: guard the rename, **discard the temp**, name the path that could not
move. Leaving the temp is not neutral; it is an undeclared second copy of the queue, the
same wreckage `bump-version`'s record documents cleaning up.

- [ ] **Step 3: Surface jq's diagnostic**
`:61` runs jq with `2>/dev/null`, discarding the real error for a generic message.

- [ ] **Step 4: Verify the consumer contract holds**
All seven call sites branch on the exit status:
```bash
grep -rn 'queue_edit ' skill-sources/ skills/ | grep -v '^.*#'   # expect 7
```
A caller marking a task `done` must not proceed believing a failed write landed.

- [ ] **Step 5: Suite green, both shells, then commit**

---

## Task 8a: Guard the `queue-edit` *target*, not just the rename (spec §2e)

**Added 2026-08-11.** Task 8 guards the rename. On a YAML-queue vault the rename is not the
problem — the target is. Every call site writes to a `queue.json` that is not the live queue,
silently, at rc 0, because it is valid JSON and jq succeeds on it.

**Interfaces**
- **Consumes:** Task 7's suite (`reference/test/queue-edit.test.sh`) and Task 8's guarded commit.
- **Produces:** a precondition in `reference/lib/queue-edit.sh`. **No `skill-sources/` edits** — that
  boundary is what keeps this inside the plan's "without changing what generation emits" constraint.

- [ ] **Step 1: Write the two failing assertions first**
  Add to `queue-edit.test.sh`: (a) `queue_edit` handed a nonexistent path exits 1 and names it;
  (b) handed `…/queue.json` with a sibling `…/queue.yaml` present, exits 1 and names **both**.
  Use a digit-free fixture dir — `mktemp` paths carry digits and void any "no digits" assertion.

- [ ] **Step 2: Run them — see them fail for the right reason**
  Both must fail because the function *succeeds*, not because the fixture is malformed. Print the
  observed rc; a fixture error and a missing guard both look like "not green".

- [ ] **Step 3: Reproduce the field condition, so the guard is not written against a guess**
```bash
ls -la ~/second-brain/ops/queue/    # queue.yaml 440999B live; queue.json 636B, Jul 7 — the tombstone
grep -n 'ops/queue/queue\.json' skill-sources/next/SKILL.md   # :50 prose format-aware; :98,:130,:154 not
```

- [ ] **Step 4: Add the precondition**
  In `queue_edit`, before staging: if the file does not exist → exit 1 naming it. If it ends
  `.json` and a sibling `queue.yaml` exists → exit 1 naming both. Do **not** create, migrate, or
  fall back — a fallback is a write to a file the caller did not name.

- [ ] **Step 5: Run — see both pass**

- [ ] **Step 6: Mutation-prove each assertion separately**
  Delete the sibling check → assertion (b) red and **only** (b). Delete the existence check →
  (a) red and only (a). Assert each mutation applied (`cmp -s`) before reading the result: a
  `sed`/`perl` that matches nothing reports the same all-green as a robust assertion.

- [ ] **Step 7: Prove the emission boundary held**
```bash
git diff --stat -- skill-sources/    # must be EMPTY for this task
```

- [ ] **Step 8: Suite green in both shells, then commit**

---

## Task 9: `/health` Category 9 must vouch for all three libraries (F6)

- [ ] **Step 1: Re-derive the gap**
```bash
grep -n 'check_lib ' skills/health/SKILL.md      # 2 lines: link-extraction, frontmatter
grep -c 'queue-edit' skills/health/SKILL.md      # 0
grep -n 'QUEUE_EDIT_VERSION' reference/lib/queue-edit.sh   # :23 — exists, unread
```

- [ ] **Step 2: Add the third `check_lib` line**
Category 9's stated purpose is to report a broken library *"instead of leaving the user to
discover it the next time they run a command."* For `queue-edit` the user currently
discovers it exactly that way — every queue write in `/next`, `/verify`, `/reduce`,
`/reflect`, `/reweave` exits 1 while `/health` reports clean.

- [ ] **Step 3: Verify the fence still runs standalone**
Fence gate serially: `run=75 skipped=3`. A Category 9 fence that stops parsing would be
**skipped, not failed**, and the gate would still print PASS.

- [ ] **Step 4: Commit**

---

## Task 10: The hook template must not skip silently (F10)

- [ ] **Step 1: Re-derive, and read the NESTING — a flat `grep` gets this wrong**
```bash
sed -n '163p;185p;195p' platforms/claude-code/hooks/session-orient.sh.template   # if / if / fi
grep -rn '{{NOTES_DIR' generators/ skills/     # no substitution site exists
```
`:185`'s `-gt 0` test is **inside** the `[ -d ]` block spanning `:163`–`:195`, so a failed
guard skips the threshold test entirely and the signal is **omitted**, not fabricated.
`ORPHAN_COUNT=0` at `:162` is dead initialisation on that path.

A draft of the spec claimed the opposite from `grep -n 'ORPHAN_COUNT'`, which returns
`:162 :183 :185 :186` and shows no nesting. Verify structure with `sed` over a range, not
by line adjacency.

- [ ] **Step 2: Add the else arm — and leave `ORPHAN_COUNT=0` alone**
Warn on stderr, omit the signal, say why. **Do not** also "stop pre-initialising the
count": on the skip path it is never consulted, so removing it edits dead code on a false
premise and touches a line the finding does not implicate (Rule 5).

- [ ] **Step 3: Do NOT substitute the placeholder**
Out of scope, stated in the spec. `{{NOTES_DIR}}` joins `{{OBS_THRESHOLD}}` /
`{{TENSION_THRESHOLD}}` as knobs that look configurable and are not — already recorded as
divergence 14. Wiring them changes what generation emits and belongs to the
generator/vault enforcement-gap track.

- [ ] **Step 4: Verify by extraction**
Nothing automated executes this template — `hook-config.test.sh` runs the plugin's own
hook, not this file. Extract the block, substitute `{{NOTES_DIR:-notes}}` → a name that
does not exist, and confirm the warning fires and no signal is emitted. State in the
commit message that this was hand-verified, because no gate covers it.

- [ ] **Step 5: Commit**

---

## Task 11: `session-orient` totals must count recursively (spec §10, D17)

**Files:**
- Modify: `hooks/scripts/session-orient.sh` (`OBS_TOTAL=` / `TENS_TOTAL=`, currently `:154`–`:155`)
- Test: `reference/test/hook-config.test.sh` (the only suite that executes this hook)

**Interfaces:**
- Consumes: `count_notes_by_field` from `ops/lib/frontmatter.sh`, already sourced by this hook.
- Produces: `OBS_TOTAL`/`TENS_TOTAL` computed over the same file set as `OBS_COUNT`/`TENS_COUNT`.
  Task 10 changes this hook's *template*; this changes the plugin's *own* hook. Two files, and
  divergence 16 is exactly about them drifting — if Task 10's template gains the same totals
  line, apply this there too and say so in the commit.

`:151` counts open items with `count_notes_by_field`, which recurses. `:154`–`:155` compute the
totals with `ls -1 ops/observations/*.md`, which does not. `:207` prints both in one sentence, so
a vault with an open item under `ops/observations/archive/` can report a count larger than its
own total.

**It gates nothing today** — the threshold compares `OBS_COUNT` alone — so this is a correctness
fix to a display line, not a threshold change. Do not let it become one.

- [ ] **Step 1: Build a fixture that exposes the mismatch**

```bash
T=$(mktemp -d); mkdir -p "$T/ops/observations/archive"
printf -- '---\nstatus: open\n---\nbody\n' > "$T/ops/observations/archive/a.md"
printf -- '---\nstatus: archived\n---\nbody\n' > "$T/ops/observations/b.md"
( cd "$T" && ls -1 ops/observations/*.md 2>/dev/null | wc -l | tr -d ' ' )   # 1  <- flat total
find "$T/ops/observations" -name '*.md' | wc -l | tr -d ' '                   # 2  <- true total
echo "$T"
```

Expected: `1` then `2`. The open item lives in `archive/`, so the flat total (`1`) is smaller
than the recursive open count (`1`) is equal — and with a second open file under `archive/` the
count exceeds the total outright. Keep `$T`; the next steps reuse it.

- [ ] **Step 2: Write the failing assertion in `hook-config.test.sh`**

Add beside the existing `session-orient.sh` cases:

```bash
# D17: the total must cover the same file set as the open count. A flat `ls -1`
# total with a recursive open count can print "2 pending observations (of 1
# total)" -- a sentence that cannot be true.
t=$(mktemp -d); mkdir -p "$t/ops/observations/archive" "$t/ops/lib"
cp "$ROOT/../hooks/scripts/"*.sh "$t/ops/lib/" 2>/dev/null || true
printf -- '---\nstatus: open\n---\n'  > "$t/ops/observations/archive/a.md"
printf -- '---\nstatus: open\n---\n'  > "$t/ops/observations/archive/b.md"
printf -- '---\nstatus: archived\n---\n' > "$t/ops/observations/c.md"
flat=$(cd "$t" && ls -1 ops/observations/*.md 2>/dev/null | wc -l | tr -d ' ')
deep=$(find "$t/ops/observations" -name '*.md' | wc -l | tr -d ' ')
assert "$flat" "1" "fixture: flat total sees only the top level"
assert "$deep" "3" "fixture: recursive total sees all three"
rm -rf "$t"
```

- [ ] **Step 3: Run it and confirm the fixture discriminates**

Run: `for s in bash zsh; do $s reference/test/hook-config.test.sh | tail -1; done`
Expected: both pass with two more assertions than before. These pin the fixture, not the fix —
Step 5 adds the assertion that actually fails against today's hook.

- [ ] **Step 4: Change the two total lines**

Replace:

```bash
OBS_TOTAL=$(ls -1 ops/observations/*.md 2>/dev/null | wc -l | tr -d ' ')
TENS_TOTAL=$(ls -1 ops/tensions/*.md 2>/dev/null | wc -l | tr -d ' ')
```

with:

```bash
# RECURSIVE, to match count_open_items above it. A flat `ls -1` total beside a
# recursive open count printed "N pending (of M total)" with N > M whenever an
# open note lived in a subdirectory (deferrals 17). `find` is already required
# by this repo; -type f keeps a stray directory named *.md out of the count.
OBS_TOTAL=$(find ops/observations -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
TENS_TOTAL=$(find ops/tensions -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
```

- [ ] **Step 5: Add the assertion that fails before the change and passes after**

```bash
# The invariant the sentence at :207 depends on: total >= open count, always.
t=$(mktemp -d); mkdir -p "$t/ops/observations/archive"
printf -- '---\nstatus: open\n---\n' > "$t/ops/observations/archive/a.md"
printf -- '---\nstatus: open\n---\n' > "$t/ops/observations/archive/b.md"
tot=$(cd "$t" && find ops/observations -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
assert "$tot" "2" "D17: OBS_TOTAL counts notes in subdirectories"
rm -rf "$t"
```

Mutation-proof it: revert the `OBS_TOTAL=` line to the `ls -1` form, assert the revert applied
with `cmp -s`, re-run, and confirm **this** assertion reddens and reports `0` rather than `2`.

- [ ] **Step 6: Run the suite under both shells**

Run: `for s in bash zsh; do $s reference/test/hook-config.test.sh | tail -1; done`
Expected: both pass, with three more assertions than the baseline.

- [ ] **Step 7: Check whether Task 10's template needs the same change**

```bash
/usr/bin/grep -n 'OBS_TOTAL=\|TENS_TOTAL=' platforms/claude-code/hooks/session-orient.sh.template
```

If the template carries the same flat spelling, fix it here too and say so — divergence 16 is
precisely these two files drifting. If it does not carry the lines at all, say **that** in the
commit rather than leaving it unstated.

- [ ] **Step 8: Commit**

```bash
git add hooks/scripts/session-orient.sh reference/test/hook-config.test.sh
git commit -m "session-orient: count totals recursively, matching the open count

:151 counted open items with count_notes_by_field (recursive) while
:154-155 computed totals with ls -1 (flat), and :207 printed both in one
sentence -- so an open note in a subdirectory could produce 'N pending
observations (of M total)' with N > M. deferrals.md entry 17.

Consistent until now only because no archive subdirectory in the field
vault holds an open item. Gates nothing: the threshold compares OBS_COUNT
alone, so this is a display-correctness fix and not a threshold change.

Assertion mutation-proved -- reverting the OBS_TOTAL line to ls -1 reddens
it and reports 0 where 2 is required."
```

---

## Task 12: `read_config.sh`'s two bare-vs-dotted asymmetries (spec §9, D16)

**Files:**
- Modify: `hooks/scripts/read_config.sh` (the dotted-path `awk`, currently `:63`–`:68`; the
  bare-path `grep -E` and its empty-value branch, currently `:107`–`:113`)
- Test: `reference/test/threshold-namespace.test.sh` (the only suite that executes this reader)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: one reader whose two paths agree on (i) what a present-but-empty value means and
  (ii) that a key is matched as a fixed string. No caller signature changes: `read_config.sh
  <key> [default]`, stdout is the value, rc 1 with a stderr line where it cannot conclude.

Two asymmetries in one 113-line reader:

**(a) present-but-empty.** The dotted path distinguishes *absent* (`[ -n "$LINE" ]` → default,
rc 0) from *present but unparseable* (`[ -z "$VALUE" ]` → stderr, rc 1). The bare path collapses
both: `VALUE=$(grep -E …)` empty → `$DEFAULT`, rc 0, silent. Returning the default for a key the
user actually wrote is verbatim how divergence 3's hardcoded `10` stayed invisible.

**(b) regex interpolation.** Both paths interpolate the key into a regex — the dotted path into
two awk EREs, the bare path into `grep -E "^${KEY}:"`. A `.` in a key therefore matches any
character. Bare keys never contain a dot (the `*.*` case routes those away), but `[`, `*` and `+`
are not filtered on either path.

- [ ] **Step 1: Reproduce both asymmetries against the current reader**

```bash
T=$(mktemp -d); cd "$T"
printf 'observation_threshold:\n' > .arscontexta
mkdir -p ops && printf 'self_evolution:\n  observation_threshold:\n' > ops/config.yaml
G=/Volumes/Containers/arscontexta/hooks/scripts/read_config.sh
CLAUDE_PROJECT_DIR="$T" bash "$G" observation_threshold 99; echo "bare rc=$?"
CLAUDE_PROJECT_DIR="$T" bash "$G" self_evolution.observation_threshold 99; echo "dotted rc=$?"
cd - >/dev/null
```

Expected **before** the fix: bare prints `99` at `rc=0` (silent default for a key the user
wrote); dotted prints a stderr line at `rc=1`. That difference is asymmetry (a).

- [ ] **Step 2: Re-measure the safety claim before changing behaviour**

Criterion 22 requires this measured now, not inherited from the spec: no shipped bare key is
written-but-empty in a real `.arscontexta`, so making the bare path loud breaks no caller.

```bash
/usr/bin/grep -rho 'read_config\.sh[" ]*[a-z_.]*' hooks/ skills/ skill-sources/ \
  | awk '{print $2}' | sort -u | /usr/bin/grep -v '\.' | /usr/bin/grep .
```

Record the bare keys this returns. If any vault ships one with an empty value, this task stops
and the finding is reported — do not proceed on the spec's sentence alone.

- [ ] **Step 3: Write the failing assertions in `threshold-namespace.test.sh`**

```bash
# D16(a): a bare key PRESENT but EMPTY must fail loud, exactly as the dotted
# path already does. Returning the default for a key the user wrote is how the
# hardcoded 10 stayed invisible (divergence 3).
t=$(mktemp -d); printf 'observation_threshold:\n' > "$t/.arscontexta"
out=$(CLAUDE_PROJECT_DIR="$t" bash "$RC" observation_threshold 99 2>/dev/null); rc=$?
assert "$rc"  "1"  "D16a: bare present-but-empty exits 1, not the default"
assert "$out" ""   "D16a: bare present-but-empty prints no value"
rm -rf "$t"

# D16(b): the key is matched as a FIXED STRING. With a regex match, the key
# `a.c` finds a line spelling `aXc`.
t=$(mktemp -d); printf 'aXc: 7\n' > "$t/.arscontexta"
out=$(CLAUDE_PROJECT_DIR="$t" bash "$RC" a.c 42 2>/dev/null)
assert "$out" "42" "D16b: a dot in a key does not match an arbitrary character"
rm -rf "$t"
```

`a.c` contains a dot, so it routes to the **dotted** path and reads `ops/config.yaml`; with no
such file the correct answer is the default `42`. Add the section-level twin too:

```bash
t=$(mktemp -d); mkdir -p "$t/ops"
printf 'selfXevolution:\n  obs: 7\n' > "$t/ops/config.yaml"
out=$(CLAUDE_PROJECT_DIR="$t" bash "$RC" self.evolution.obs 42 2>/dev/null)
assert "$out" "42" "D16b: a dot in the SECTION name does not match arbitrarily"
rm -rf "$t"
```

- [ ] **Step 4: Run them and confirm they fail**

Run: `for s in bash zsh; do $s reference/test/threshold-namespace.test.sh | tail -1; done`
Expected: FAIL — the bare case returns `99` at rc 0, and the section case matches
`selfXevolution` and returns `7`.

- [ ] **Step 5: Fix (b) — match the key with `index()`, not a regex**

Replace the dotted path's `awk`:

```bash
    LINE=$(awk -v sec="$SECTION" -v fld="$FIELD" '
      {
        # FIXED-STRING section header: `sec:` at column 0, rest blank or comment.
        # Was an interpolated ERE, so a `.` in the key matched any character.
        if (index($0, sec ":") == 1) {
          rest = substr($0, length(sec) + 2)
          sub(/^[[:space:]]*/, "", rest)
          if (rest == "" || substr(rest, 1, 1) == "#") { insec = 1; next }
        }
        if ($0 ~ /^[^[:space:]#]/) { insec = 0 }
        if (insec) {
          bare = $0; sub(/^[[:space:]]+/, "", bare)
          if (bare != $0 && index(bare, fld ":") == 1) { print; exit }
        }
      }
    ' "$NESTED" 2>/dev/null)
```

`bare != $0` preserves the original requirement that the field line be indented, so a
column-0 key of the same name is not picked up.

- [ ] **Step 6: Fix (a) and (b) together on the bare path**

Replace `VALUE=$(grep -E "^${KEY}:" …)` and its `if [ -z "$VALUE" ]` branch with:

```bash
# FIXED-STRING key match, and ABSENT vs PRESENT-BUT-EMPTY kept apart -- the
# dotted path above already draws both distinctions and this one did not.
LINE=$(awk -v k="$KEY" 'index($0, k ":") == 1 { print; exit }' "$CONFIG_FILE" 2>/dev/null)

[ -n "$LINE" ] || { echo "$DEFAULT"; exit 0; }

VALUE=$(printf '%s\n' "$LINE" \
  | sed 's/^[^:]*:[[:space:]]*//' \
  | sed 's/^["'"'"']//;s/["'"'"']$//' \
  | sed 's/[[:space:]]*$//')

if [ -z "$VALUE" ]; then
  printf 'read_config: %s is set in %s but its value could not be read: %s\n' \
    "$KEY" "$CONFIG_FILE" "$LINE" >&2
  exit 1
fi
echo "$VALUE"
```

- [ ] **Step 7: Run the suite and confirm the new assertions pass**

Run: `for s in bash zsh; do $s reference/test/threshold-namespace.test.sh | tail -1; done`
Expected: both pass, four more assertions than the 52 baseline.

- [ ] **Step 8: Mutation-prove each new assertion separately**

Per Global Constraint 1, assert the mutation applied before reading the result:

| mutation | must redden |
|---|---|
| restore `grep -E "^${KEY}:"` on the bare path | the D16b bare assertion |
| restore `[ -z "$VALUE" ] && echo "$DEFAULT"` on the bare path | both D16a assertions |
| restore the ERE `$0 ~ "^"sec":…"` section test | the D16b section assertion |

```bash
S=hooks/scripts/read_config.sh; B=$(mktemp); cp $S $B
perl -pi -e 's/index\(\$0, k ":"\) == 1/\$0 ~ "^"k":"/' $S
cmp -s $B $S && echo 'MUTATION DID NOT APPLY — result meaningless' || \
  for s in bash zsh; do $s reference/test/threshold-namespace.test.sh | tail -1; done
cp $B $S
```

- [ ] **Step 9: Confirm the four real consumers still agree**

The suite's threshold sweep is what proves this reader did not change meaning for real keys.

Run: `for s in bash zsh; do $s reference/test/threshold-namespace.test.sh | tail -1; done`
Expected: the sweep assertions are unchanged — same verdicts per reader as the 52-assertion
baseline. A moved verdict means this task changed threshold behaviour, which it must not.

- [ ] **Step 10: Commit**

```bash
git add hooks/scripts/read_config.sh reference/test/threshold-namespace.test.sh
git commit -m "read_config: make the bare path loud on empty, and match keys as fixed strings

Two asymmetries in one reader (deferrals.md entry 16).

(a) A present-but-empty value failed LOUD on the dotted path and SILENTLY
returned the default on the bare path. Returning the default for a key the
user actually wrote is verbatim how divergence 3's hardcoded 10 stayed
invisible while config.yaml said otherwise.

(b) Both paths interpolated the key into a regex, so a '.' matched any
character: section 'self.evolution' found 'selfXevolution'. Both now match
with awk index(), the same fixed-string idiom frontmatter.sh uses.

Re-measured before changing behaviour: no shipped bare key is
written-but-empty, so the new loud arm breaks no caller. That measurement is
in the task, not inherited from the spec.

Each new assertion mutation-proved with the mutation asserted to have
applied; the threshold sweep's per-reader verdicts are unchanged, which is
what shows this did not alter meaning for real keys."
```

---

## Task 13: check 6's substring match and whitespace-split allowlist (spec §12, D19)

**Files:**
- Modify: `reference/check-portability.sh` (`INTERP_ALLOW`, currently `:422`–`:425`;
  `interp_hits_in`, currently `:436`; the two `${e%% *}` parses at `:451` and `:461`)
- Test: `reference/test/guard-failure.test.sh` (the suite that exercises this guard's failure path)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `interp_hits_in` counts only lines whose path prefix matches at column 1, and
  `INTERP_ALLOW` is `|`-delimited so a path containing a space parses as one field. The
  allowlist's **contents** are unchanged — same two entries, same counts.

**This task changes a gate's internals, which criterion 1 does not cover.** Criterion 26a is
explicit: check-portability must go red under mutation and green after. `check-portability.sh`
is invoked as `bash reference/check-portability.sh` everywhere (CI, `.pre-commit-config.yaml`,
`CLAUDE.md`), and `guard-failure.test.sh` asserts that; do not change the invocation.

- [ ] **Step 1: Reproduce the substring defect**

`interp_hits_in` is `printf '%s\n' "$INTERP_RAW" | "$GREP" -cF "$ROOT/$1:"` — unanchored, so a
path that is a substring of another line's path counts against the shorter one.

```bash
R=/Volumes/Containers/arscontexta
RAW="$R/skills/health/SKILL.md:661:x
$R/skills/health/SKILL.md.bak:12:x"
printf '%s\n' "$RAW" | /usr/bin/grep -cF "$R/skills/health/SKILL.md:"   # 1 — correct here
printf '%s\n' "$RAW" | /usr/bin/grep -cF "$R/skills/health"             # 2 — the shape that bites
```

The second is the failure mode: any prefix that is not a whole path counts every line beneath it.
It fails toward false FAIL, never false PASS, which is why it was deferrable.

- [ ] **Step 2: Reproduce the whitespace defect**

```bash
e="path with space.md 1 the reason"
echo "path parsed as: [${e%% *}]"     # [path] — wrong; should be the whole filename
```

Expected: `[path]`. The parse takes everything before the **first** space.

- [ ] **Step 3: Write the failing assertions in `guard-failure.test.sh`**

```bash
# D19(a): interp_hits_in must anchor at column 1. A prefix that is not a whole
# path must not absorb the lines beneath it.
raw="/r/skills/health/SKILL.md:661:x
/r/skills/health/SKILL.md.bak:12:x"
n=$(printf '%s\n' "$raw" | awk -v p="/r/skills/health/SKILL.md:" 'index($0,p)==1{c++} END{print c+0}')
assert "$n" "1" "D19a: anchored match counts only the exact path"

# D19(b): a `|`-delimited allowlist entry whose path contains a space parses whole.
e='dir/a path.md|1|reason text here'
assert "${e%%|*}" "dir/a path.md" "D19b: pipe-delimited path survives a space"
```

- [ ] **Step 4: Run and confirm the second fails against the current parse**

Run: `for s in bash zsh; do $s reference/test/guard-failure.test.sh | tail -1; done`
Expected: the D19b assertion passes trivially (it tests the new delimiter directly), the D19a
assertion passes as written. **These two pin the technique, not the guard.** Step 7 adds the
assertion that actually exercises `check-portability.sh` end-to-end.

- [ ] **Step 5: Anchor `interp_hits_in`**

Replace:

```bash
interp_hits_in() {         # interp_hits_in <relative-path> -> hit count in that file
  printf '%s\n' "$INTERP_RAW" | "$GREP" -cF "$ROOT/$1:" || true
}
```

with:

```bash
interp_hits_in() {         # interp_hits_in <relative-path> -> hit count in that file
  # ANCHORED at column 1 and still a FIXED string. `grep -cF` matched anywhere
  # in the line, so a prefix that is not a whole path absorbed every line
  # beneath it (deferrals 19). awk index()==1 keeps the fixed-string semantics
  # -- a path full of regex metacharacters must not become a pattern -- while
  # requiring the match to start the line.
  printf '%s\n' "$INTERP_RAW" \
    | awk -v p="$ROOT/$1:" 'index($0, p) == 1 { c++ } END { print c+0 }'
}
```

`awk` already prints `0` for no matches, so the `|| true` is no longer load-bearing and is gone.

- [ ] **Step 6: Switch the allowlist to `|` and update both parses**

Replace the `INTERP_ALLOW` block's two entries with `|`-delimited fields — **same paths, same
counts, same reasons**:

```bash
INTERP_ALLOW="
reference/testing-milestones.md|1|a test SPEC's own example; teaching the pattern is not shipping it
generators/features/maintenance.md|1|a recipe emitted into a generated vault's docs; a recipe cannot source a library the way a fence can, so converting it changes what generation emits
"
```

Then change the two parses. At `:451`:

```bash
    [ "${e%%|*}" = "$1" ] || continue
    e=${e#*|}; printf '%s' "${e%%|*}"
```

and at `:461`:

```bash
    [ -n "$e" ] || continue; printf '%s\n' "${e%%|*}"
```

- [ ] **Step 7: Add the end-to-end assertion — the guard still allowlists both entries**

```bash
# The allowlist must still resolve to the same two paths after the delimiter
# change. A parse that silently yields nothing turns check 6 into a no-op that
# reports PASS, which is the failure this repo has shipped twice.
out=$(bash "$GUARD" 2>&1); rc=$?
assert "$rc" "0" "D19: guard still green after the delimiter change"
n=$(printf '%s\n' "$out" | /usr/bin/grep -c 'testing-milestones\|maintenance\.md' || true)
[ "$n" -ge 0 ] && pass=$((pass+1))
```

- [ ] **Step 8: Mutation-prove both fixes**

| mutation | must redden |
|---|---|
| restore `"$GREP" -cF "$ROOT/$1:"` in `interp_hits_in` | the D19a assertion |
| restore a space delimiter in one `INTERP_ALLOW` row while the parse expects `\|` | the D19 end-to-end assertion |

```bash
S=reference/check-portability.sh; B=$(mktemp); cp $S $B
perl -pi -e 's/index\(\$0, p\) == 1/index(\$0, p) > 0/' $S
cmp -s $B $S && echo 'MUTATION DID NOT APPLY — result meaningless' || \
  for s in bash zsh; do $s reference/test/guard-failure.test.sh | tail -1; done
cp $B $S
```

- [ ] **Step 9: Run the guard and its suite, and confirm the allowlist size is unchanged**

```bash
bash reference/check-portability.sh; echo "rc=$?"
/usr/bin/grep -A3 'INTERP_ALLOW=' reference/check-portability.sh | /usr/bin/grep -c '|'
for s in bash zsh; do $s reference/test/guard-failure.test.sh | tail -1; done
```

Expected: `rc=0`; the allowlist still has **2** entries; the suite passes under both shells with
the new assertions added. A shrunken allowlist means the parse broke and check 6 is now
reporting on fewer files, not on cleaner ones.

- [ ] **Step 10: Commit**

```bash
git add reference/check-portability.sh reference/test/guard-failure.test.sh
git commit -m "check 6: anchor the hit count, and delimit the allowlist with |

deferrals.md entry 19, two findings.

interp_hits_in used 'grep -cF \"\$ROOT/\$1:\"' -- unanchored, so a prefix
that is not a whole path absorbed every line beneath it. Now awk
index(\$0,p)==1: still a fixed string, since an allowlisted path full of
regex metacharacters must not become a pattern, but required to start the
line. Failed toward false FAIL rather than false PASS, which is why it was
deferrable and not urgent.

The allowlist was whitespace-delimited and '\${e%% *}' takes everything
before the FIRST space, so a path containing one mis-parsed silently. Now
pipe-delimited, with both parse sites updated. Contents unchanged: same two
entries, same counts, same reasons.

Both mutation-proved with the mutation asserted to have applied. Allowlist
still resolves to 2 entries -- a parse that quietly yields nothing turns
check 6 into a no-op that reports PASS."
```

---

## Task 14: widen `check-prose-paths.sh`'s stated scope by two files (spec §14, D9)

**Files:**
- Modify: `reference/check-prose-paths.sh` (the `SCOPE` heredoc, currently `:44`–`:53`)

**Interfaces:**
- Consumes: Task 10's edits to `platforms/claude-code/hooks/session-orient.sh.template`. **Run
  this task after Task 10**, because Task 10 adds the warning text that motivates the widening,
  and a path it introduces must be caught by this gate rather than by the next reader.
- Produces: an eleven-file SCOPE (baseline was 9 as of 2026-08-11, not 8). No interface for later tasks.

`hooks/scripts/session-orient.sh` and `platforms/claude-code/hooks/session-orient.sh.template`
both name repo paths — in comments and in warning text a user reads at SessionStart — and
neither is in the gate's eight-file scope, so a path that rots in either is checked by nothing.

**This is a deliberate widening, not a patched oversight, and the distinction is the point.**
D9's trigger is "whenever someone is editing that gate anyway" and this spec edits the gate's
*subject*, not the gate. A **stated** list is what makes a shrinking scope impossible to mistake
for a clean result, so growing one is an explicit edit that needs its reason recorded. The
reason: Task 10 adds path-naming warning text to the template, increasing the unchecked surface.

- [ ] **Step 1: Confirm the current scope and that neither file is in it**

```bash
awk '/^SCOPE="/{f=1;next} /^"/{f=0} f&&NF' reference/check-prose-paths.sh | /usr/bin/grep -c .
/usr/bin/grep -c 'session-orient' reference/check-prose-paths.sh
```

Expected: `8` and `0`.

- [ ] **Step 2: Confirm both files actually name repo paths — do not widen on faith**

```bash
/usr/bin/grep -c 'reference/\|hooks/\|skill-sources/\|ops/lib/' \
  hooks/scripts/session-orient.sh \
  platforms/claude-code/hooks/session-orient.sh.template
```

Expected: both non-zero. A zero means the file names no repo path and adding it to SCOPE buys
nothing — report that instead of widening.

- [ ] **Step 3: Add the two files to the SCOPE heredoc**

```bash
SCOPE="
CLAUDE.md
docs/closed-divergences.md
CONTRIBUTING.md
README.md
reference/skill-authoring.md
reference/testing-milestones.md
reference/vocabulary-transforms.md
reference/use-case-presets.md
platforms/shared/skill-blocks/README.md
hooks/scripts/session-orient.sh
platforms/claude-code/hooks/session-orient.sh.template
"
```

**`docs/closed-divergences.md` is already in SCOPE — do not add it, and do not be surprised by
it.** It arrived on 2026-08-11 with the `CLAUDE.md` archive split, which moved the four "Closed
on …" sections out of the always-loaded file. **This task therefore takes SCOPE from 9 to 11, not
8 to 10.** Re-derive the baseline before editing rather than trusting either number:

```bash
awk '/^SCOPE="/{f=1;next} /^"/{f=0} f&&NF' reference/check-prose-paths.sh | /usr/bin/grep -c .
```

**Add them by name. No glob, no discovery** — a discovered scope cannot distinguish "shrank
because a file was deleted" from "shrank because the pattern stopped matching", which is the
property the stated list exists to preserve.

- [ ] **Step 4: Run the gate and read the extracted-path count, not just the exit code**

```bash
bash reference/check-prose-paths.sh; echo "rc=$?"
```

Expected: `rc=0`. If it reports missing paths, those are **real findings in the two newly scanned
files** — fix the paths they name, do not remove the files from SCOPE. If it exits `2`, the
extractor matched nothing and the gate is broken rather than the prose clean; that is the
distinction its own header draws.

- [ ] **Step 5: Prove the widening took effect — the count must move 8 → 10**

```bash
awk '/^SCOPE="/{f=1;next} /^"/{f=0} f&&NF' reference/check-prose-paths.sh | /usr/bin/grep -c .
/usr/bin/grep -c 'session-orient' reference/check-prose-paths.sh
```

Expected: `10` and `2`. A green gate with an unchanged count means the edit did not land where
the gate reads it.

- [ ] **Step 6: Plant a rotted path in each new file and confirm the gate catches it**

A widened scope that cannot fail is decoration. Do this once per file:

```bash
F=hooks/scripts/session-orient.sh; B=$(mktemp); cp $F $B
printf '\n# reference/this-path-does-not-exist.sh\n' >> $F
bash reference/check-prose-paths.sh >/dev/null 2>&1; echo "planted -> rc=$? (want 1)"
cp $B $F
bash reference/check-prose-paths.sh >/dev/null 2>&1; echo "restored -> rc=$? (want 0)"
```

Repeat with `F=platforms/claude-code/hooks/session-orient.sh.template`. Both must give
`rc=1` planted, `rc=0` restored.

- [ ] **Step 7: Commit**

```bash
git add reference/check-prose-paths.sh
git commit -m "check-prose-paths: add the two session-orient files to SCOPE (9 -> 11)

hooks/scripts/session-orient.sh and its platforms/ template both name repo
paths, in comments and in warning text a user reads at SessionStart, and
neither was scanned -- so a path rotting in either was checked by nothing.
deferrals.md entry 9.

A DELIBERATE widening, not a patched oversight. D9's trigger is 'whenever
someone is editing that gate anyway' and this branch edits the gate's
SUBJECT, not the gate; the reason it is taken now is that Task 10 adds
path-naming warning text to the template and so increases the unchecked
surface. Recorded because a stated list is what keeps a SHRINKING scope
from reading as a clean result, which makes growing one an explicit act.

Added by name -- no glob, no discovery. Verified by planting a
non-existent path in each new file: rc=1 planted, rc=0 restored."
```

---

## Task 15: Records (deferral 13, `CLAUDE.md`)

- [ ] **Step 1: Amend deferral 13 — amend, do not reopen**
Its trigger is *"a second failure mode … that can empty `$tgts` or `$idx` without tripping
an earlier guard."* F10 trips the `[ -d "$NOTES_DIR" ]` guard at `:162` and skips the
block, which is a different route to the same outcome. **The trigger is not tripped.**

What changes is the entry's premise: on any vault whose notes directory is not literally
`notes/`, the block it defends never executes, so its "rare failure" framing understates
the case. Cross-reference Task 10. Do not move it to Closed.

- [ ] **Step 2: Update `CLAUDE.md` numerals this work moved**
The gate count, the CI step count, and the library version. Every numeral gets its
re-derivation command beside it, per house convention.

- [ ] **Step 3: Record the 46-vs-35 provenance**
PR #7 merged 46 commits; the link-edge-map plan produced 35. Eleven commits of earlier
backport work rode along undescribed by the PR body, including an entire third library.
Two of this plan's findings live in that undescribed half. This belongs in the tracked
record — a record that does not ship is not a record.

- [ ] **Step 4: `check-doc-claims.sh` green**
It reads a git range and rots on merge with no diff to notice. Run it before the final
commit, not after.

- [ ] **Step 5: Full sweep, both shells, then commit**

---

## Task 16: Four plugin skills run inline (spec §6, out-of-band)

Implements spec section 6. **No test can cover this** — nothing in the repo reads the
`context:` key, so the verification below is state assertion, not a gate. Say so in the
commit message rather than implying coverage.

- [ ] **Step 1: Record the before-state, so "unchanged" is checkable afterwards**

```bash
/usr/bin/grep -rn '^context: fork' skills/ | tee /tmp/fork-before.txt | wc -l   # 9
md5 -q skills/setup/SKILL.md > /tmp/setup-before.md5      # macOS; md5sum on Linux
sed -n '1317p' skills/setup/SKILL.md                       # the prescription line — memorise it
```

- [ ] **Step 2: Delete `context:` and `model:` from the four — one file at a time**

Sites, to be re-derived rather than trusted (**they drift**, and `setup`'s two differ from
the other three by one line):

```bash
for s in setup upgrade architect health; do
  printf -- '-- %s\n' "$s"; /usr/bin/grep -n '^context:\|^model:' "skills/$s/SKILL.md"
done      # setup 4,5 · upgrade 7,8 · architect 7,8 · health 6,7
```

**Do not use a repo-wide `sed`.** `skills/setup/SKILL.md` contains the string
`context: fork` **twice**: at `:4` as its own frontmatter (delete) and at `:1317` inside
prose that tells *generated vault skills* to set it (**keep, byte-identical**). Edit by
explicit anchor, per file.

**Delete both keys, not just `context:`.** `skills/help` — the only inline skill today —
declares neither, and matching it is the whole basis for dropping `model:`. Leaving
`model:` behind ships a knob whose effect this repo cannot verify, which is the
divergence-14 pattern.

**Change nothing else in these frontmatter blocks.** They are not uniform: `setup` has no
`version:`/`user-invocable:`, `health` has no `user-invocable:`, `architect` and `health`
carry `argument-hint:`. Normalising them is a different change (Rule 5).

- [ ] **Step 3: Verify the change, the non-change, and the blast radius**

```bash
/usr/bin/grep -c '^context:' skills/setup/SKILL.md skills/upgrade/SKILL.md \
    skills/architect/SKILL.md skills/health/SKILL.md          # 0 0 0 0
/usr/bin/grep -c '^model:'   skills/setup/SKILL.md skills/upgrade/SKILL.md \
    skills/architect/SKILL.md skills/health/SKILL.md          # 0 0 0 0
/usr/bin/grep -rc '^context: fork' skills/ | /usr/bin/grep -v ':0'   # 5 files, the untouched ones
/usr/bin/grep -c 'context: fork' skills/setup/SKILL.md               # 1 — :1317 survives
sed -n '1317p' skills/setup/SKILL.md                                 # unchanged prose
```

The `grep -c '^context: fork'` and `grep -c 'context: fork'` pair is deliberate: the first
is anchored and must be 0 for `setup`, the second is unanchored and must be 1. **One
command cannot express both halves**, and a single unanchored count would read as a
surviving defect.

- [ ] **Step 4: Full gate sweep, both shells**

Expect **no gate to move** — none reads this key. A gate that *does* change means the
edit hit something unintended; investigate before committing.

---

## Task 17: README claim audit (spec §7, out-of-band)

Implements spec section 7. Nine claims verified correct; **one fix.**

- [ ] **Step 1: Re-verify the nine before changing anything**

They were measured at `a98352c` and this branch moves numbers. Re-run the spec §7 table's
commands; if one has drifted, fix that too and say so.

- [ ] **Step 2: Add `check-vocabulary-schema.sh` to the `reference/` block**

Insert one line in the Project Structure tree (`README.md` ~`:323-326`), keeping the
existing `|   |-- ` prefix and the `# comment` column.

**Placement: immediately after `check-placeholder-count.sh`, last in the family.** The
block is **not** alphabetical — it mirrors `CLAUDE.md`'s Verification section order exactly
(portability → prose-paths → doc-claims → placeholder-count → vocabulary-schema), and
alphabetical placement would put it in the wrong slot while looking deliberate. Verify the
convention before inserting rather than trusting this paragraph:

```bash
sed -n '322,326p' README.md                              # README's order
/usr/bin/grep -n 'bash reference/check-' CLAUDE.md | head -5   # the same order, 5 entries
```

**This is a completeness fix, not a listing expansion.** `reference/` holds 33 entries and
the block lists 11; eliding is correct and stays. The defect is narrower: four `check-*.sh`
sit consecutively with no ellipsis, reading as the whole family when there are five. Do not
"finish" any other elided group in the same edit — that would mint a fresh completeness
claim beside the one being fixed.

- [ ] **Step 3: Leave two regions alone, deliberately**

- **`:156-169` (`### Fresh Context Per Phase`) is correct and must not be touched.** It
  describes `/ralph` and the generated pipeline, not the plugin skills Task 16 changes.
  Editing it would introduce an error. This step exists because the opposite is the
  natural assumption.
- **`:383`'s wording is load-bearing.** `check-doc-claims.sh:299` extracts the kernel
  primitive count from that line by regex. Inserting a line above it is safe; rewording it
  breaks the gate.

- [ ] **Step 4: Both gates that read README**

```bash
bash reference/check-prose-paths.sh      # the added path must resolve
bash reference/check-doc-claims.sh       # :383 anchor intact
git diff --stat README.md                # expect 1 insertion, 0 deletions
```

The `--stat` assertion is the real guard here: it fails loudly if Step 3's restraint
slipped.

---

## Task 18: `CLAUDE.md:307` — a claim Task 16 makes false (spec §8)

- [ ] **Step 1: Fix the parenthetical in the same commit as Task 16, or immediately after**

`CLAUDE.md:307` says *"Both use SKILL.md frontmatter (`context: fork`, `model:`,
`allowed-tools:`)"*. After Task 16 that is false for 4 of 10 `skills/`. **This rots on
this commit, not on merge** — so it is not a Task 15 record item and must not be deferred
into one.

Re-derive the line, which drifts:

```bash
/usr/bin/grep -n 'context: fork`, `model:`' CLAUDE.md
```

State the split rather than a bare number: the sentence's subject is what the two trees
share, and the honest form is that `allowed-tools:` is common to both while `context:`/
`model:` now appear on a subset. Give it a re-derivation command, per house convention.

- [ ] **Step 2: `check-doc-claims.sh` green, then commit**

---

## Task 19: Divergence 16's "structural" claim (spec §15)

**Added 2026-08-11.** Prose only — two sentences in `CLAUDE.md` and one annotation in
`skills/upgrade/SKILL.md`. Nothing executable changes, and option (b) stays withheld.

**Interfaces**
- **Consumes:** nothing. Independent of every other task; may land in any order.
- **Produces:** corrected prose. No interface for later tasks.

- [ ] **Step 1: Re-derive all three measurements yourself — do not inherit the spec's numbers**
```bash
grep -rho 'generated_from:.*' ~/second-brain/.claude/skills/*/SKILL.md | sort | uniq -c
ls -1 ~/second-brain/ops/skills-archive/ | grep -c '2026-08-09'
git tag | wc -l
ls -1 ~/.claude/plugins/cache/agenticnotetaking/arscontexta/
```
Expected: 13×`0.9.7` + 3×`0.8.0`; 8 archived; **0** tags; five cached baselines. The cache is
**version-partitioned** — a `find -maxdepth 4` for `plugin.json` returns nothing and reads as
"cache is empty", which is wrong. Descend into a version directory.

- [ ] **Step 2: Locate the sentence by text, not by line number**
```bash
/usr/bin/grep -n 'never been invoked as a slash command' CLAUDE.md
```
Line numbers in this repo drift; the `CLAUDE.md` archive split moved several hundred on
2026-08-11 alone.

- [ ] **Step 3: Rewrite the claim — and stay inside the evidence**
  Replace "structurally, since a slash command runs in the session's working directory and cannot
  be pointed at another tree" with the accurate reason: a session whose cwd **is** the vault
  invokes it natively, so the gap is **undone, not structural**. **Do not write that the slash
  command has been invoked** — the stamps and archives establish that an upgrade *operation* ran,
  not its vehicle. Over-claiming here reproduces the exact defect being corrected.

- [ ] **Step 4: Annotate `skills/upgrade/SKILL.md:592`**
  Its "no release tags to recover it" is **true**; its conclusion that no baseline exists is not.
  Record the cached-baseline path beside it. **Leave option (b) withheld** — restoring it is
  deferred (see Deferrals), because a wrong merge corrupts a user's customized skills.

- [ ] **Step 5: Verify the emission boundary and the divergence numbering**
```bash
git diff --stat -- skill-sources/ generators/     # must be EMPTY
bash reference/check-doc-claims.sh | tail -3      # divergence numbers still unique
```

- [ ] **Step 6: `check-prose-paths.sh` and `check-doc-claims.sh` green, then commit**

---

## Deferrals

*(One line per deferral, naming the tracked file it landed in, or the literal word `none`.
Required for every plan from `fix/spec-e-fourteen-items` forward — see `CLAUDE.md`
divergence 10.)*

- **Group D — orphan-semantics unification across five surfaces (F4).** **RULED by the user on
  2026-08-09: keep deferred as latent.** Not deferred by omission and no longer merely blocked —
  the spec's Decision 1 was put to the user and answered. Measured as latent: all three
  computable semantics return 0 on the field vault, whose `nodes/` has zero subdirectories, so
  nothing forces the ruling today. Recorded in
  `docs/superpowers/specs/2026-08-09-post-merge-hardening-design.md` under "The open decisions".
  **Reopening trigger:** the first vault whose notes directory gains a subdirectory, at which
  point the three semantics stop agreeing and the counts in five shipped commands diverge.
- **The PostToolUse matcher stays `Write` (spec Decision 2, `deferrals.md` entry 15).** **RULED
  by the user on 2026-08-09: option C, record and wait.** No task edits `hooks/hooks.json`;
  Global Constraint 12 makes a diff there a signal that the ruling was overridden unasked.
  Widening the matcher alone buys zero coverage on any vault that renamed its notes directory,
  because the hardcoded `*/notes/*` filter blocks the guard regardless — so option A would cost
  a hook invocation on every edit everywhere and close nothing. **Reopening trigger:** that path
  filter becoming vocabulary-aware, at which point the matcher is the only thing left stopping
  the guard from firing. Lands in `docs/superpowers/deferrals.md` entry 15.
- **The thirteen deferrals that did not fold into the spec.** Enumerated by number with their
  individual blocking reasons in the spec's `## Deliberately not in scope`. They remain in
  `docs/superpowers/deferrals.md`; this plan does not restate them, because a second copy of a
  deferral list is a second thing to keep in sync.
- **No rule for which skills fork (Task 16).** After Task 16 the split is 5 inline / 5
  forked with nothing stating why. Two candidate rules were tested and falsified; the
  selection was the request. Recorded in the spec under `## Deliberately not in scope`
  rather than resolved, because inventing a principle to fit four named skills is
  reverse-engineered rationale. **Reopening trigger:** a third skill moving in either
  direction — at that point the rule has to be written down.
- **`reference/skill-authoring.md` documents neither `context:` nor `model:`.** Found
  while establishing what Task 16 changes. Real gap; widening that document is its own
  change. Lands in `docs/superpowers/deferrals.md` if not picked up during execution.
- **A false claim in commit `162ab8b`'s message, corrected here rather than amended.** That
  message says this plan "spells seven of its twelve task headings as `## 3:` rather than
  `## Task 3:`, which task-brief's `^#+[ \t]+Task[ \t]+[0-9]+` cannot extract". **That is
  wrong.** All twelve headings carried the word `Task` and all twelve extracted correctly —
  verified by running the real `task-brief` script against tasks 3, 5, 7, 10 and 12, each of
  which produced a brief. The claim came from reading **compressed tool output** in which the
  word `Task` had been elided from the heading, not from the file. Not amended, following the
  precedent already in `deferrals.md` for `f07b9eb`'s "Nine assertions" — a history rewrite for
  a message error is worse than the error. **The reason to refresh this plan was always the six
  new spec sections, and that reason stands unaffected.**
- Any deferral arising during execution lands in `docs/superpowers/deferrals.md` with a
  stated, observable reopening trigger, and is named here.

**Added 2026-08-11**, from a cross-check of the field vault's `ops/` record against this repo's
specs and plans. The first two are measured and re-verified against this checkout; the last two
rest on that review's own evidence and are **not independently verified** — stated per entry
rather than left for a reader to assume, because the same review's `/upgrade` headline was found
overstated when checked.

- **Dual-format queue support — teaching `queue-edit.sh` to read YAML and converting the 23
  files (spec §2e).** Deferred because it **changes what generation emits**, which this plan's
  Goal excludes; Task 8a takes the in-scope half (fail loud) instead. Not a design problem —
  `skill-sources/seed/SKILL.md:66,307,318,401` already carries the dual-format pattern to copy.
  Measured 2026-08-11: 23 files / 43 lines carry the literal path, and all seven `queue_edit`
  sites pass it as a **literal, not a variable**, so no configuration reaches them. Field
  evidence is the open vault observation
  `ops/observations/pipeline-skills-hardcode-queue-json-….md`. Lands in
  `docs/superpowers/deferrals.md`. **Reopening trigger:** Task 8a's guard firing against a real
  vault — at that point the loud refusal is the entire behavior, and a user with a YAML queue has
  no working `queue_edit` at all.

- **Restoring `/upgrade` option (b), the customization-preserving merge (spec §15).** Deferred
  because it is a behavior change to a plugin skill where a wrong merge **corrupts a user's
  customized skills** — a worse failure than the withholding it repairs. Task 19 corrects the
  prose only. The blocker is now gone rather than merely restated: five complete baselines sit in
  `~/.claude/plugins/cache/agenticnotetaking/arscontexta/` (`0.8.0 0.9.0 0.9.5 0.9.6 0.9.7`, 16
  `skill-sources/` each), including **both** versions the field vault is stamped with, so a merge
  baseline is recoverable and a merge would be fact rather than guess. Needs its own spec. Lands
  in `docs/superpowers/deferrals.md`. **Reopening trigger:** any vault reporting a customization
  lost to an `/upgrade` replace — the cost of withholding then exceeds the risk of merging.

- **`/next`'s `context: fork` (`skill-sources/next:7`) — 0-for-4 in the field.**
  `ops/observations/next-subagent-forks-die-to-growing-context-reinjection-….md` (open) records
  four fork deaths, zero successes, and three rounds of verified skill fixes changing nothing;
  the posited remedy is dropping the exact frontmatter key the template ships. Deferred because
  removing it **changes what generation emits**, and because `## Deliberately not in scope`
  already parks the fork/inline rule pending a third skill moving. **Not independently
  verified** — the count comes from the vault's record, not from a run reproduced here. The cheap
  half is *not* deferred: cite this observation where that section states its trigger, so the
  evidence stops sitting uncited one tree over. Lands in `docs/superpowers/deferrals.md`.
  **Reopening trigger:** the third skill moving in either direction, which the spec already
  names — this observation is the evidence that trigger was waiting for.

- **Four vault-behavior findings with no home in this plan** — `/reweave` performing a second
  forward pass rather than a backward one; the systematic verbing of sibling relations as
  hierarchies (with its open tension on edge direction); `/rethink` exempting its own `drift-*`
  output from the provenance fields it enforces; and every extraction stub carrying
  `semantic_neighbor: null`. All four are generation-surface or vault-content questions, none is
  reachable by a task in this plan, and **none was independently verified here**. Grouped rather
  than split because they share one destination and one verification debt. Land in
  `docs/superpowers/deferrals.md`. **Reopening trigger:** each becomes actionable only once
  re-derived against this checkout — treat the vault's record as a lead, not a finding.
