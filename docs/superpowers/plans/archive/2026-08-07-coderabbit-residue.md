# Plan — the CodeRabbit PR #3 residue

Spec: `docs/superpowers/specs/archive/2026-08-07-coderabbit-residue-design.md`

## Global Constraints

- **Execution model:** implement directly; dispatch reviews on a model matched to each task's risk
  (see Model Selection in `superpowers:subagent-driven-development`), reviewers in separate
  worktrees (`isolation: worktree`). Implementer subagents have died of autocompact thrashing in
  this repo 3/3; reviewers survive large packages — this pattern held across all of Spec H and
  Spec I and is not being re-litigated here.
- **`~/second-brain` is READ-ONLY.** No task below writes to it. Any fixture referencing real vault
  shape (Task 9's tension enum, Task 2's threshold values) is built fresh under a temp dir.
- **`grep` in a Claude Code session is ugrep.** Spell `/usr/bin/grep` in any new gate-facing bash,
  matching every existing site in `reference/`.
- **Mutate the DEFECT, not the line.** Assert every mutation applied (`cmp -s`, or an explicit
  before/after diff) before reading its result, and check *which* assertions reddened, not merely
  that some did. Every task below that touches a gate script or test suite must reproduce its own
  bug empirically before fixing it, and reproduce the fix's effect after — not trust the spec's
  description alone.
- **Both bash and zsh, everywhere a suite runs under both today.** Do not add coverage that only
  one shell exercises without a stated reason (see `CLAUDE.md`'s own account of why
  `check-portability.sh` is the one gate that legitimately runs bash-only).
- **This plan does not touch `docs/superpowers/plans/archive/2026-08-04-ci-hardening.md` or its design
  spec, anywhere, for any reason.** Both are closed records. If a task below tempts you to update a
  number in either file, stop — that number belongs to a different, completed plan.
- **Any fix that changes a gated count (assertion total, allowlist size, fence total) must update
  every document `reference/check-doc-claims.sh` checks against it, in the same commit.** Two fixes
  already on this branch produced exactly this drift (a heading edit that reflowed a paragraph and
  broke a sed anchor; a new test assertion that moved a suite's total by one) and both were caught
  only by re-running the gate after the fix, not by inspection. Run
  `bash reference/check-doc-claims.sh` after every task, not only at the end.
- **A finding's severity as stated in the spec is not a license to skip its mutation test.**
  "Low-severity" findings (Task 6's `fm_hits_in`/`fm_stale` half) still need the same "reproduce
  broken, reproduce fixed" discipline as "real bug" findings — severity affects priority, not rigor.

---

## Task 1 — fix the tension-recipe silent-scan-failure bug (`generators/features/graph-analysis.md` ×2, `schema.md` ×1)

- [ ] **Step 1 — measure the premise.** Reproduce both directions of the current bug against a
      scratch fixture: (a) a `list_notes_by_field` traversal failure (permission-denied subdirectory)
      piped into the current `while read` shape reads as "0 matching tensions," not an error; (b) a
      perfectly healthy scan whose *last* matched file is neither `pending` nor `open` returns
      nonzero from the pipeline today, which would become a **false positive failure** if `pipefail`
      were bolted on naively — confirm this before touching anything, since it is the reason
      CodeRabbit's own suggested fix (`set -o pipefail`) is wrong for this shape.
- [ ] **Step 2 — restructure to the established codebase idiom**, not a flag. Match
      `skill-sources/rethink/SKILL.md:180-186` and `skills/architect/SKILL.md:271-274`: capture
      `list_notes_by_field`'s output via `$(...)`, check its exit status explicitly and halt/report
      on failure, then iterate the captured text. Apply identically at all three sites
      (`graph-analysis.md` lines ~38-42 and ~143-147, `schema.md` ~73-80).
- [ ] **Step 3 — do not touch `reference/check-doc-claims.sh`'s `TENSION_RECIPES=3` pin.** The count
      of recipe sites is unchanged; only their internal shape changes.

**Done when:**
```bash
for f in generators/features/graph-analysis.md generators/features/schema.md; do
  /usr/bin/grep -c 'list_notes_by_field.*| *while' "$f"   # expect 0 at all three prior sites
done
bash reference/check-doc-claims.sh   # TENSION_RECIPES=3 still matches — recipe count unchanged
```

---

## Task 2 — fix "pending"-alone threshold triggers (`self-evolution.md`, `claude-md.md`, `rethink/SKILL.md:21-22`)

- [ ] **Step 1 — measure the premise.** Confirm the exact current wording at all three sites
      (`generators/features/self-evolution.md:191-192,194`, `generators/claude-md.md:242-245`,
      `skill-sources/rethink/SKILL.md:21-22`) still reads "pending" alone, and confirm the rule they
      contradict is still stated at `self-evolution.md:96-117`/`:227-249` — line numbers drift, verify
      by content not position.
- [ ] **Step 2 — fix all three to "pending or open," identically worded.** Do not paraphrase
      differently at each site; a fourth spelling of the same rule is how this drifted apart from
      itself in the first place. Confirm `blocked` is not accidentally swept in at any of the three —
      it is correctly excluded elsewhere and must stay excluded here.

**Done when:**
```bash
/usr/bin/grep -n "pending observations\|pending tensions" generators/features/self-evolution.md \
  generators/claude-md.md skill-sources/rethink/SKILL.md
# every match above should now read "pending or open", not "pending" alone
```

---

## Task 3 — resolve `/rethink`'s four-action-list vs. six-disposition incoherence (`self-evolution.md:194-198`)

- [ ] **Step 1 — this is a judgment call, not a mechanical fix.** The spec names two options and
      states both are individually wrong as CodeRabbit proposed them:
      (a) expand the four-action list to name all six dispositions (PROMOTE, IMPLEMENT, METHODOLOGY,
      ARCHIVE, BLOCKED, KEEP PENDING), matching what `skill-sources/rethink/SKILL.md`'s actual triage
      table already does; or
      (b) explicitly scope the "Operational Learning Loop" summary to observations only, and point
      readers at the full Tension Status lifecycle section (already correct, ~227-249) for tensions.
      Pick one and state why in the commit message — do not silently split the difference by writing
      a vaguer five-item list.
- [ ] **Step 2 — verify no other site in `generators/` repeats the stale four-action framing** once
      the chosen fix lands (a fresh grep for "one of four actions" or equivalent, since a single
      un-updated copy would leave the same incoherence one level removed).

**Done when:**
```bash
/usr/bin/grep -n "PROMOTE\|IMPLEMENT\|METHODOLOGY\|ARCHIVE\|BLOCKED\|KEEP PENDING" \
  generators/features/self-evolution.md | head -20
# the chosen list (four or six items, per Step 1's decision) must match
# skill-sources/rethink/SKILL.md's actual triage table exactly
```

---

## Task 4 — propagate directory-discovery resolver failures in `reference/validate-kernel.sh`

- [ ] **Step 1 — measure the premise.** Reproduce the current ambiguity directly: build a vault
      fixture with a permission-denied ops directory reachable only through a vocabulary-declared
      custom name, run `resolve_ops_dir` against it, and confirm it returns identically (rc 1, no
      diagnostic) to a fixture where that directory simply doesn't exist.
- [ ] **Step 2 — introduce a third state.** `resolve_ops_dir_name`, `resolve_ops_dir`, and
      `resolve_note_dirs` (lines ~69-97, ~241-278) each capture `find`'s own exit status separately
      from `head -1`'s output — not via a bash-only `pipefail` idiom; this script explicitly avoids
      those for portability. On a `find` failure, return a distinct code from "not found."
- [ ] **Step 3 — thread the new state through every caller.** C1's loop (~899-920, 4 call sites),
      primitive 12's two `has_*_dir` checks (~774-775), and primitive 2's existing two-state
      `resolve_rc` branch (~444-465, which needs a third arm) must all distinguish "resolver error"
      from "genuinely absent" and fail loud on the former rather than falling through to a soft WARN.
- [ ] **Step 4 — build the fixture.** A non-root fixture (root-aware SKIP guard matching the existing
      pattern in `reference/test/kernel-note-dirs.test.sh:555-587`) combining a vocabulary-declared
      custom ops-dir name with an unreadable path, asserting C1 **fails**, not warns, on it.
- [ ] **Step 5 — confirm no regression on the healthy path.** Every existing `kernel-note-dirs.test.sh`
      assertion must still pass; this task adds a state, it does not change existing resolution
      behavior for present, readable directories.

**Done when:**
```bash
for s in bash zsh; do $s reference/test/kernel-note-dirs.test.sh | tail -1; done
./reference/validate-kernel.sh ~/second-brain 2>&1 | grep -E '^ +(PASS|WARN|FAIL) '
# re-derive the current pass/warn/fail counts per CLAUDE.md's own convention — do not
# hardcode an expected number here, since it drifts as the vault grows
```

---

## Task 5 — harden `check-doc-claims.sh`'s TENSION validation against ambiguous or empty declarations

- [ ] **Step 1 — measure the premise.** Reproduce both gaps directly: add a second matching
      `status:...dissolved` line to a scratch `generators/` fixture and confirm `tenum` silently
      picks the first one; move a recipe's `"$s" = "..."` comparison one line further than the
      current lookahead expects and confirm the recipe reports "ok" having checked nothing.
- [ ] **Step 2 — mirror the `NOTE_ENUM_DECLS` guard for `tenum`.** Count matching declarations,
      require exactly one, error otherwise — same shape as the sibling NOTE-enum check five lines
      above it.
- [ ] **Step 3 — guard the per-recipe extraction.** A zero-value extraction from the lookahead line
      is an error (increment the existing error counter), not a silent "ok."
- [ ] **Step 4 — add mutation fixtures.** No test file currently exists for this script; add one
      (or extend the nearest existing coverage) exercising both mutations from Step 1, confirming
      each now fails loud.

**Done when:**
```bash
bash reference/check-doc-claims.sh   # still PASS on the healthy tree
# plus whichever fixture/test Step 4 adds, run standalone, both directions
```

---

## Task 6 — three related hardening gaps in `check-portability.sh`'s frontmatter-parsing gate

- [ ] **Step 1 — measure the premise, all three.** (a) Rename one `FM_SCAN` root temporarily and
      confirm the scan silently produces a partial file list with no diagnostic. (b) `chmod 000` an
      allowlisted file and confirm `fm_hits_in` returns 0 indistinguishable from clean. (c) Construct
      the "every remaining site converted in one branch" state (`fm_total` 0, `fm_present` positive,
      `fm_stale` non-empty) and confirm the wrong branch fires first.
- [ ] **Step 2 — fix (a), the real bug.** Capture `find`'s exit status separately in `FM_SCAN`/
      `fm_scan_files` (~698-701); `red()` and fail the check on any root's traversal failure, matching
      this file's own `scan_or_die()` idiom.
- [ ] **Step 3 — fix (b), `fm_hits_in`.** Return a distinct UNREADABLE sentinel when the target file
      exists but cannot be read; route it through `red()` rather than a silent 0.
- [ ] **Step 4 — fix (c), branch ordering.** Check `fm_stale` non-emptiness before the "scan did not
      run" diagnostic, so a converted-allowlist state reports the true, actionable story.

**Done when:**
```bash
bash reference/check-portability.sh   # still PASS on the healthy tree
# plus Step 1's three reproductions, re-run after each corresponding fix, each now correctly
# diagnosed (not silently absorbed) — confirm the FIX applied via a content diff before reading
# the mutation's result, per this repo's "failed mutations look green" hazard
```

---

## Task 7 — `reference/lib/frontmatter.sh`: variable scoping and duplicated find-and-check logic

- [ ] **Step 1 — add missing `local` declarations.** `_fm_list`/`_fm_find_rc` in `list_notes_by_field`
      and `count_notes_missing_field` (~216, ~276-289). No behavior change for any conforming caller
      — confirmed no external reference to either name exists outside `reference/lib/`.
- [ ] **Step 2 — extract the duplicated `find -H ...; rc=$?` block into `_fm_find_md`.** Both call
      sites must assign as two statements — `_fm_list=$(_fm_find_md "$dir"); rc=$?` — never
      `local x=$(_fm_find_md "$dir")`, which swallows the substitution's exit status. This exact trap
      is already documented in this file's own `count_notes_by_field` comment (~249-251); do not
      reintroduce it while fixing the scoping gap.
- [ ] **Step 3 — do not bump `FRONTMATTER_VERSION`.** Its own header scopes bumps to behavior
      changes; this task changes neither delimiter rules, key matching, quote stripping, nor
      recursion semantics.

**Done when:**
```bash
for s in bash zsh; do $s reference/test/fence-isolation.test.sh | tail -1; done
# assertion F (the frontmatter parser three-way fixture) must still discriminate correctly:
# correct parser 2, naive grep 1, wrong-field parser 4 — unchanged by this refactor
/usr/bin/grep -c "FRONTMATTER_VERSION=" reference/lib/frontmatter.sh   # still 1, still =3
```

---

## Task 8 — `platforms/claude-code/hooks/write-validate.sh.template`: doc gaps plus the guard they were masking

- [ ] **Step 1 — fix the SCOPE LIMIT doc first**, and only first — the FILE-existence guard in Step 3
      below is unreachable until this lands, so fixing Step 3 before Step 1 verifies nothing live.
      Name both real constraints: the `hooks.json` tool-matcher, and the unsubstituted
      `{{NOTES_DIR:-notes}}/*` marker that currently makes the guard match no real path.
- [ ] **Step 2 — remove the false "only two numbers" claim** on the PREV_BYTES/NOW_BYTES comment;
      name the third, separate link-loss condition, matching the non-template hook's own already-
      corrected wording at `hooks/scripts/write-validate.sh:131-138`.
- [ ] **Step 3 — add the FILE-existence guard**, mirroring the non-template hook's early exit
      (`[ -z "$FILE" ] && exit 0`, `[ ! -f "$FILE" ] && exit 0`) right after `FILE=` is assigned,
      before any git/size/link logic runs.
- [ ] **Step 4 — note explicitly, in the commit message, that this task does not fix the
      `{{NOTES_DIR:-notes}}` substitution itself** — whether/how `/init`-time substitution reaches
      this template is a separate, larger question this task's scope does not include. Fixing the
      *documentation* of the gap and the guard that becomes reachable once it's fixed elsewhere are
      this task's boundaries.

**Done when:**
```bash
/usr/bin/grep -n "only two numbers\|SCOPE LIMIT" platforms/claude-code/hooks/write-validate.sh.template
/usr/bin/grep -n 'FILE=.*TOOL_INPUT_PATH' -A3 platforms/claude-code/hooks/write-validate.sh.template
# the FILE assignment must be followed by an existence guard before any git/wc logic
```

---

## Task 9 — fix blocked-tension discovery in `skill-sources/rethink/SKILL.md`

- [ ] **Step 1 — measure the premise.** Build a fixture tension with `status: blocked` and confirm
      it is currently absent from both `TENSION_PENDING` and `TENSION_COUNT` — not merely excluded
      from the count as the design intends.
- [ ] **Step 2 — fix `list_open_items`** to also match `blocked`, so blocked tensions populate
      `TENSION_PENDING`.
- [ ] **Step 3 — subtract blocked-status entries when computing `TENSION_COUNT` specifically**, so
      the existing threshold-counting rule (line ~296) still holds — a blocked tension must be
      visible to discovery but must not itself trip the threshold.
- [ ] **Step 4 — confirm this is outside `check-doc-claims.sh`'s existing coverage**, and do not
      assume the gate will catch a regression here; this task's own fixture is the only coverage
      this fix gets, per the spec's explicit note.

**Done when:**
```bash
# fixture-based: a status:blocked tension appears in TENSION_PENDING, is excluded from TENSION_COUNT
```

---

## Task 10 — fix `docs/superpowers/plans/archive/2026-08-05-generator-vault-enforcement-gap.md`'s own acceptance-script mechanics

- [ ] **Step 1 — confirm this is in scope**, per the design spec's explicit reasoning: this task
      touches the plan's embedded *verification script*, not its recorded decisions or Deferrals
      content. Do not touch anything in that file except the three items below.
- [ ] **Step 2 — fix the Deferrals validation heuristic** (~162-173): parse only literal `none` or
      real Markdown table rows (matching `^\|\s*\d+\s*\|`), extract the "Landed in" cell, and run
      `git ls-files --error-unmatch` on it only when it looks like a path — skip legitimate non-path
      references ("this row", "spec § ...") the section's own rules already sanction.
- [ ] **Step 3 — fix the acceptance commands** (~108-112): replace the literal `<suite>` placeholder
      with the concrete suite it should name, `reference/test/kernel-note-dirs.test.sh`. Capture and
      print the suite's real exit status before the final `tail -1` line, rather than letting the
      pipeline discard it.
- [ ] **Step 4 — fix the six MD031 blank-line violations**, low priority, while the file is open for
      the other two fixes. **NOT SHIPPED — claim verified false.** Checked exhaustively against
      the current file (`a138126`'s own commit message has the method and the count): the target
      plan has exactly 5 "Done when" fenced blocks, not 6, and all 10 fence markers across those 5
      pairs are correctly blank-line-separated on both sides. No MD031 violation exists to fix.
      Per this repo's own CLAUDE.md divergence 10 ("a record that does not ship is not a record" —
      a prior version of this exact defect class lived only in a commit message and a gitignored
      ledger), the falsification is annotated here rather than left in `a138126` alone.
- [ ] **Step 5 — explicitly do NOT touch the canonical-name resolver contract wording** at lines
      44-52 (or the matching spec design doc's lines 59-61) — the spec names this as already moot,
      and editing it now would be exactly the retroactive retcon this task's own Step 1 is careful to
      avoid for the rest of the file.

**Done when:**
```bash
/usr/bin/grep -n '<suite>' docs/superpowers/plans/archive/2026-08-05-generator-vault-enforcement-gap.md
# expect 0 — placeholder resolved
# run the Deferrals validation block against the plan's own real Deferrals table and confirm
# zero false-positive flags on legitimate prose/table rows
```

---

## Review

(Populated during execution — one entry per task-review round, per this repo's subagent-driven
workflow.)

---

## Deferrals

- **A CI gate detecting "an automated comment-generation pass destroyed prose rationale."** Named in
  the design spec's "Deliberately not in scope" — real gap this whole plan's origin incident exposed,
  but its own design question (what counts as "destroyed" vs. "improved"?), not a natural extension
  of any task here.
- **Whether/how `platforms/claude-code`'s `{{NOTES_DIR:-notes}}`-style placeholders get substituted
  at `/init` time.** Task 8 explicitly stops short of this — tracked in
  `docs/superpowers/specs/archive/2026-08-07-coderabbit-residue-design.md`, Task 8's own Step 4 note.
  Related to this repo's own `CLAUDE.md` divergence 3's discussion of the same placeholder family
  never being substituted anywhere in this repo — not re-filed here, since fixing the doc and the
  guard is a smaller, independent step from building the substitution mechanism itself.
- **`generators/features/self-evolution.md`'s Task 3 decision (four-item vs. six-item disposition
  list)** is deliberately left to the implementer rather than pre-decided in this plan — tracked in
  Task 3 itself, which states both options and requires the choice be recorded in the commit message.

---

## Known hazards, carried forward

- **A prose count is a claim that rots the moment the file it counts changes — gated or not.** This
  plan's own origin (two self-inflicted `check-doc-claims.sh` regressions on `fix/spec-h-enforcement-
  gap`, found only by re-running the gate after a heading edit and a new test assertion) is the
  concrete proof, not a hypothetical. Every task above that touches a counted quantity must re-run
  `check-doc-claims.sh`, not merely eyeball the diff.
- **Editing a paragraph can silently break a same-line sed anchor elsewhere in the tree**, if the
  file uses a strict wrap width and the edit reflows text past it. Confirmed exactly this happened
  during this plan's own predecessor work (`reference/skill-authoring.md`, `fix/spec-h-enforcement-
  gap`). Any task above editing prose in a file `check-doc-claims.sh` anchors into should re-run that
  gate immediately after the edit, not batch it with other changes.
- **Zsh `nomatch` on a glob with nothing to match** remains this repo's most-repeated fence defect.
  Any new glob Task 4 or Task 9 adds needs the same guard `skill-sources/seed f01` and
  `skills/health f08` already needed, not a fresh rediscovery.
- **CodeRabbit's ASSERTIVE review profile finds real things and sometimes misdescribes them.** Three
  of the seven investigations behind this plan found it citing line ranges that had already moved
  (self-evolution.md, twice) or proposing a mechanically wrong remedy (the `pipefail` suggestion,
  Task 1). Verify against current code before implementing any comment's literal suggestion, even
  when the underlying finding is confirmed real.
