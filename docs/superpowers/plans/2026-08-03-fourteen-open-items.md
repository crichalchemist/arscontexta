# Plan — Spec E: the fourteen open items

**Spec:** `docs/superpowers/specs/2026-08-03-fourteen-open-items-design.md`
**Branch:** cut fresh from `main` after `docs/skill-authoring-reference` merges.
**Ledger:** `.superpowers/sdd/2026-08-03-fourteen-open-items/progress.md` — authoritative over the
checkboxes below. Tick as you go, or this plan becomes E11.

---

## Global Constraints

- Files under `skill-sources/` are **templates**. Never substitute a placeholder with a concrete
  value. `skills/` are the plugin's own commands and carry none.
  `platforms/shared/skill-blocks/` is **frozen and gated** — do not touch it.
- Every gate runs under **both bash and zsh**. Three shipped defects here were bash/zsh forks; the
  most recent was `read -r path`, which is zsh's `PATH`-tied array. Other zsh-special names to avoid
  as `read` targets: `status argv cdpath manpath module_path options prompt fignore psvar watch`.
- `grep` in a Claude Code session is ugrep. Patterns containing `{` or `}` need `-F`; `grep -P` is
  unavailable on the CI image. Verify with `/usr/bin/grep`.
- **Prose and code move in the same commit.** Every count written into prose must be re-derivable by
  a command stated beside it.
- **Execution model: implement directly, dispatch reviews.** Measured this session: 4 of 5 sonnet
  exploratory agents died of autocompact thrashing; the same prompt on opus completed.
  **Dispatch any subagent on opus.** Reviewers have found a Critical the author missed, twice.
- **Never read a subagent's output file before the agent reports done** — a rep overwrote 0 citations
  with 7, and the early read was recorded as a measurement. Freeze the tree for the duration of any
  measurement.
- Backports from `~/second-brain` reverse two transforms: vocabulary → canonical
  (`reference/vocabulary-transforms.md`), and concrete paths → `{vocabulary.*}` placeholders.

---

## Task 1 — E1: lift the 999 ceiling out of the field vault and into the templates

**Files:** `skill-sources/reduce/SKILL.md`, `skill-sources/seed/SKILL.md`.

Ships to every generated vault. Do this first.

- [x] **Step 1 — Read the field fix, then reverse both transforms.**
      `~/second-brain/.claude/skills/extract/SKILL.md:898-918`. The vault says `extract`; the template
      is `reduce`. The vault names `nodes/`; the template says `{vocabulary.notes}`. A verbatim
      copy-paste ships one user's vocabulary to everyone.
- [x] **Step 2 — Add the Width rule to `reduce`** after the `NNN is the claim number` line (`:897`).
      Seven digits minimum (author-directed; the spec text said three before that call), wider through unchanged. **Carry the re-padding warning** — it is
      the half that matters: widening `…-042.md` to `…-0042.md` renames the file and breaks every wiki
      link to it, because links resolve by filename.
- [x] **Step 3 — Make `seed` validate width-agnostically.** It must accept three **or more** digits
      and recognise a claim by its `# claim-NNN` heading rather than by filename shape, so timestamped
      and arXiv-ID files stay out of the numbering scan.
- [x] **Step 4 — Prove it on a fixture**, not by reading. Build a temp vault holding `x-998.md`,
      `x-999.md`, `x-1000.md` and a timestamped file. Confirm the `seed` scan sees the first three,
      excludes the fourth, and that nothing renames `x-042.md`.

**Done when:** a numbering scan crosses 999 without truncating, without re-padding, and without
absorbing a timestamped filename — demonstrated on the fixture, pasted into the commit message.

---

## Task 2 — E2: make `/next`'s contract and its code agree

**Files:** `skill-sources/next/SKILL.md`, `skill-sources/graph/SKILL.md`.

- [x] **Step 1 — Decide per field, and record the decision.** Four promised fields are unbacked:
      Orphans, Dangling, Stale, Queue. For each: compute it, or delete it from the contract. **Do not
      defer again** — the deferral is why it shipped. "Stale" has four definitions in play; pick the
      one `/health` already uses or drop the field.
- [x] **Step 2 — Source the library for anything link-shaped.**
      `reference/lib/link-extraction.sh`, `*_recursive` variants. An inlined
      `grep -rl "[[$NAME]]"` counts links inside fenced blocks, does not case-fold, and matches the
      wrong direction for orphans — an accepted defect in two templates already.
- [x] **Step 3 — Same audit for `graph`**, which references orphans with zero `ORPHAN_COUNT=`.
- [x] **Step 4 — Add the assertion that would have caught this.** Every `[A-Z_]*` field named in an
      output-format contract must have an assignment in the same file. This is mechanically checkable
      and generalises past these two templates.

**Done when:** enumerating assignments in each file accounts for every field its output contract
names, and Step 4's check fails when a field is removed from the code but left in the prose.

---

## Task 3 — E13 + E14: build the agent surface, symlinked

**Files:** `AGENTS.md` (symlink), `GEMINI.md`, `.agents/plugins/marketplace.json`,
`.pre-commit-config.yaml`, `reference/check-portability.sh`.

Placed third because from here on it protects the rest of the work.

- [x] **Step 1 — `ln -s CLAUDE.md AGENTS.md`.** A symlink, never a copy. A copied file is a second
      configuration surface that cannot see the first, which is E7 — do not create a new instance of
      the defect while fixing the old one. Verify with `ls -la` that git records a symlink
      (`git ls-files -s AGENTS.md` should show mode `120000`).
- [x] **Step 2 — `GEMINI.md` as a pointer file**, not a symlink: it needs different tool references.
      Model on `/Volumes/Containers/superpowers/GEMINI.md`, which is two `@./path` include lines.
- [x] **Step 3 — `.agents/plugins/marketplace.json`** for cross-runtime discovery, mirroring
      `.claude-plugin/marketplace.json`. ~~**Add it to `.version-bump.json`**~~ — *superseded during
      execution:* it was built as a **symlink** to `.claude-plugin/marketplace.json`, so declaring it
      would put two rows on one file and `--check` would compare a file against itself. Correctly
      absent. The plan text was written assuming a copy.
- [x] **Step 4 — `.pre-commit-config.yaml`** running `bash reference/check-portability.sh` (under a
      second) on every commit. Not the full gate set — the fence sweep takes two minutes and would be
      abandoned.
- [x] **Step 5 — Do NOT create `.pi/` or an Antigravity dot-dir.** Both platforms are queued, not
      built. A `plugin.json` claiming a platform that does not exist is the availability defect this
      spec forbids. Note the uncommitted `README.md` change marking *"Antigravity CLI plugin |
      Available"* for the author.
- [x] **Step 6 — Extend `check-portability.sh`** with a check that `AGENTS.md` is a symlink resolving
      to `CLAUDE.md`. Prove it non-vacuous: replace the symlink with a copy, confirm the check fails,
      restore. **Then re-run all four gates** — `guard-failure.test.sh` invokes
      `check-portability.sh`, and a new check that fails on synthetic roots broke it once already.

**Done when:** `git ls-files -s AGENTS.md` shows mode `120000`, pre-commit rejects a PCRE-carrying
commit, and all four gates pass in both shells with the new check present.

---

## Task 4 — E3 + E4 + E5 + E6: the gate-integrity set

**Files:** `reference/test/fence-isolation.test.sh`, `reference/test/guard-failure.test.sh`,
`reference/test/bump-version.test.sh` (new).

- [x] **Step 1 — E3, decide the allowlist keying.** Either entries key on stated reason as well as
      `(letter, label)`, or the shell filter that governs the stale-entry table also gates absorption.
      Reproduce the masking first (the probe is recorded in CLAUDE.md divergence 1), then fix, then
      confirm the probe now reports the failure.
- [x] **Step 2 — E4, pin the DELETED branch.** `if [ ! -f … ]` → `if false` currently leaves the suite
      green because `cksum < <missing>` yields an empty digest and reports MODIFIED. Add an assertion
      distinguishing the two, and **verify by mutation** that it goes red.
- [x] **Step 3 — E5, decide the shell question and write it down.** `rc_of` hardcodes
      `bash "$GUARD"`. Either that is correct given the `#!/bin/bash` shebang — in which case say so in
      a comment — or the suite should invoke the guard under the shell it is running as.
- [x] **Step 4 — E6, give `bump-version.sh` a failure-path suite.** It rewrites release metadata and
      no gate touches it. Assert: zsh and bash both reach rc 0 on `--check`; a `MISSING` row does not
      report agreement; a non-version value is rejected; an unanchored version string is rejected; the
      `SCAN FAILED` branch is reachable; a bump moves all declared sites together and leaves no
      `.tmp.` file. Wire into CI beside the others, **both shells**.

**Done when:** each of the four has a mutation that turns an assertion red, pasted into the commit.

---

## Task 5 — E7 + E8: configuration and display

**Files:** `hooks/scripts/read_config.sh`, `hooks/scripts/session-orient.sh`, `skills/help/SKILL.md`,
three skills reading `self_evolution.*`.

- [x] **Step 1 — E7, pick the owner.** Either teach `read_config.sh` one level of nesting, or move the
      thresholds where it can already read them. **Whichever loses must fail loudly** rather than
      carry a stale default — a hardcoded 10/5 beside a configured 20/10 is how three sources came to
      disagree.
- [x] **Step 2 — Reconcile the three values** (skills 10/5, plugin hook 10/5, field vault 20/10) and
      record which is canonical and why.
- [x] **Step 3 — E8, make each count state what it counts.** `skills/help:49` merges observations and
      methodology notes. Note the same mislabel in `session-orient.sh` and `skills/health` WAS a
      defect because those numbers drove a threshold; these do not, so the fix is labelling, not
      arithmetic.

**Done when:** one surface owns each threshold, and `grep`ing for a threshold value finds it in one
place.

---

## Task 6 — E9 + E12: the two things only a real run can settle

- [x] **Step 1 — E9, run `/arscontexta:upgrade` against a copy of the field vault.** DONE with a
      corrected verb: it was **carried out by hand**, not invoked — a slash command runs in the
      session cwd and cannot be pointed at another tree. As-is + damaged halves. Six defects, five
      fixed (`acb1ecf`); namespace question left open. Original text follows. Never done. Copy
      `~/second-brain` to a scratch path first — **do not run it against the live vault.** Record
      before/after for all three repairs (`ops/lib/`, `ops/queue/.locks/`, `self_evolution:`).
- [x] **Step 2 — E12, one clean discoverability rep.** DONE. Retrieved `reference/skill-authoring.md`
      unprompted as its 2nd file, "load-bearing throughout" — found via the pointer, not a directory
      listing. Entry closes. Probe artifact reverted, saved to the workspace. Original text follows. Frozen tree, opus, prompt identical to Task 4's
      in the previous plan, output file read only after the agent reports done. Test the hypothesis
      that search strategy is the determinant: if it greps task keywords and misses, add keywords a
      searcher would use; if it lists the directory and finds it, the pointer is not the mechanism and
      the entry closes.

**Done when:** `/upgrade` has recorded evidence from a real vault, and discoverability has one clean
data point against a frozen tree.

---

## Task 7 — E10 + E11: close the two documentation entries

- [x] **Step 1 — E11, correct the stale divergence entry.** DONE — and the correction proposed here
      was itself mis-aimed. `93` = portability(42)+silent-failure(51), both since ticked; the "16/16 and
      22/22" replacement names two *other* fully-ticked plans. The live liar is
      `2026-08-02-skill-authoring-reference.md` at 0/29, named by neither. Rewritten as three states.
      All other numbers re-derived from commands. Original text follows. CLAUDE.md divergence 5, "Verification gaps in the loop itself" (numbering shifts as entries open and close — match on the title) claims two plans
      show 0 of 93 steps complete. Measured: 16/16 and 22/22 ticked. Delete that half of the entry.
      **Then re-derive every other number in the divergence list** — the entry that names
      status-files-that-lie was one.
- [x] **Step 2 — E10, re-examine the prose-contract checker once** — BUILT, not closed.
      `reference/check-prose-paths.sh`, in CI, banner says `checkout only — packaging unverified` every
      run. Original text follows., under the narrower question: can
      *every path named in prose exists in the repo* be checked without pretending to be *exists in
      the packaged plugin*? Build it under an honest name, or close the entry permanently. Do not
      leave it recurring.

**Done when:** every claim in the divergence list re-derives from a command in its own entry, and E10
is either built or closed.

---

## Review

Two dispatches, both **opus**: one after Task 4 (the gate work is where a silent no-op hides), one
whole-branch at the end. Reviewers get a diff file from `scripts/review-package`, never a pasted diff.
Ask each to adjudicate deliberate deviations rather than pre-judging them.

## Verification (run before any PR, both shells)

```
bash reference/check-portability.sh                    # rc 0
for s in bash zsh; do
  $s reference/test/link-extraction.test.sh            # 19/19
  $s reference/test/guard-failure.test.sh              # 32/32
  $s reference/test/fence-isolation.test.sh            # PASS
  $s reference/test/bump-version.test.sh               # 26/26
  $s scripts/bump-version.sh --check                   # rc 0
done
./reference/validate-kernel.sh ~/second-brain          # 15/15
```

Baseline at the time of writing, so "unchanged" has evidence behind it:

```
bash: portability rc=0 · link 19/19 · guard 29/29 · fence files=27 fences=75 known-open=0 · version rc=0
zsh : portability rc=0 · link 19/19 · guard 29/29 · fence files=27 fences=75 known-open=2 · version rc=0
```
