# Spec F — the ten open divergences, and the two that should not be on the list at all

**Status:** design
**Date:** 2026-08-03
**Predecessor:** `2026-08-03-fourteen-open-items-design.md` (Spec E, merged at `769c221`)

---

## What this is

Spec E closed fourteen items and, in doing so, opened five more. The divergence list in `CLAUDE.md`
now carries ten entries. This spec drains it.

**Two of the ten do not belong there**, and saying so is part of the work. One cannot be actioned
without a larger decision (D4, frozen tree). One has no live subject and only becomes real as a
consequence of another entry's fix (D9). A list of open work that contains items nobody can act on
degrades the same way a status file does — the reader stops trusting the labels and starts reading
the count.

**The list found its own defect this session.** Asked what remained, it said five. The true answer
was ten: four review findings and one misplaced entry had been written only to
`.superpowers/sdd/.../progress.md`, which is **gitignored**. Two separate commits claimed those
records existed. That is the failure this spec must not repeat, and it is why D10 exists.

---

## The centrepiece — one entry is actively reporting a false pass

### D1 — `validate-kernel.sh` soft-passes the dangling-link primitive

Two consecutive lines of a real run against the field vault:

```text
PASS 3786 of 5253 files contain wiki links
WARN No wiki links found to check
```

`reference/validate-kernel.sh:74` scans a hardcoded list — `01_thinking`, `notes`, `00_inbox`,
`04_meta/logs`, plus `$VAULT/../self`. Measured: **all five absent** from the field vault, whose
notes directory is `nodes/` (2,686 files). Pointing `extract_link_targets_recursive` at the real
directory yields **2,681 link candidates**. `$VAULT/../self` is the same bug twice: for a top-level
vault that resolves to `~/self`, while the vault's self space is at `$VAULT/self`.

**The root cause is not the list's contents, and fixing the contents reproduces the defect.**
Adding `nodes/` makes this vault pass and the next one fail. The rule is general:

> **A validator for a generator must not name a canonical path literally.**

`reference/vocabulary-transforms.md` exists *because* vaults rename directories. The validator does
not read it, and neither does anything else that names a path literally. This is the same root cause
as the primitive-10 defect closed on `fix/spec-c-primitive-10` — canonical names hardcoded inside a
validator for a generator whose whole purpose is renaming them.

**Highest blast radius on the list:** this is the kernel contract, run against every generated vault,
and it has been reporting a soft pass on a check that never executed. `15 PASS / 2 WARN / 0 FAIL` has
been read as acceptable across several sessions by reading totals rather than labels.

**Acceptance is a fixture, not the field vault.** A fix verified only against `~/second-brain` proves
the list now contains `nodes/`. The check must work against a vault whose notes directory has an
arbitrary name.

---

## The correctness set

### D6 — `graph`'s authority loop still inlines the naive matcher

`skill-sources/graph/SKILL.md:434` runs `grep -rl "\[\[$NAME\]\]"` — counting matches inside fenced
code blocks, no case folding. Base had two such sites; Spec E fixed the orphan loop and left this one,
while `741b2b7` claimed the spelling was "gone from executable code in both files".

Not bundled with D1: this under-counts a **ranking input**, not a contract. It is wrong, but nothing
downstream reports a pass because of it.

`check-portability.sh` check 2 does not catch it — it matches greedy-dot capture patterns, not a
fixed-name `grep -rl` — and it carries no `portability-exempt` marker.

### D7 — the `status` enum disagrees between its two generator sources

`generators/features/schema.md:30` and `:137` give `preliminary, open, active, archived`;
`generators/features/atomic-notes.md:94` gives `preliminary | active | archived` — no `open`. Notes
are generated from the template, so a vault can emit a value one document calls valid and the other
rejects.

This sits directly adjacent to the Spec B status-vocabulary work (`open` vs `pending`) and was **not
on its list**. That is the finding: Spec B's enumeration was incomplete, so the next enumeration
should be produced by a command rather than by reading.

### D8 — no shared frontmatter-field parser (absorbs D9)

`check-portability.sh` forbids inlining copies of the *link* library and `reference/skill-authoring.md`
§3 says to source it. **There is no equivalent for frontmatter extraction.** `OBS_COUNT`,
`TENSION_COUNT` and `skills/health` each use `grep -rl '^status:'`, which matches body text as well as
frontmatter.

**Latent in the directories the threshold counts actually read; the "14" below was the wrong
quantity.** Measured: `ops/observations/` has **38** files matching `^status:` and **0** where the
match is body-only; `ops/tensions/` **27** and **0**. So no shipped count was ever wrong there.

**14 is the count of `status: open|pending` observations, not of files matching `^status:`** — a
different measurement, correct where this spec uses it for the threshold contradiction in D5 and
wrong here, where "matching" means the naive parser's own pattern. Same number, two subjects, one
document. That is the conflation `CLAUDE.md` already warns about for the two unrelated `30`s
(`DAYS_STALE` versus `stale_notes`), reproduced while writing the spec that catalogues it.

**And "latent" is too strong once you look outside the converted scope.** The field vault has
body-only `^status:` matches elsewhere, including in `ops/methodology/` — which
`generators/features/methodology-knowledge.md:31` instructs generated vaults to scan with
`rg '^status: active'`. The class is therefore live in the **generator recipes**, which a shared
library cannot fix, because a recipe is text telling a vault what command to run and cannot source
anything. That is a follow-up, not part of D8.

(Exact vault-wide body-only count is under verification: two measurements disagree, 15/2 versus 14/1,
using different awk. The disagreement is about method, not direction — both find nonzero matches in
`ops/methodology/`.)

**D9 folds in here as an acceptance criterion, not a separate task.** The fence-gate fixture
(`reference/test/fence-isolation.test.sh:170-172`) builds five notes with no `status:` field, so an
absence-count against it is unfalsifiable. Standalone that is a fixture edit with nothing to verify
against — no fence scans notes for `status:` today, and `schema.md` marks the field optional. But a
shared parser will be exercised against notes, which makes the gap live the moment D8 lands. So the
fixture must grow a discriminating case **as part of** D8, not before it and not after.

A ready-made fixture design exists: `.superpowers/sdd/2026-08-03-fourteen-open-items/task-6-e12-artifact.md`
records a four-note fixture with a true answer of 2 — one note with `status: active`, one whose *body*
carries `status: pending` inside a fenced block, one nested a directory down, one with no frontmatter.
Against it, a correct parser returns 2, the naive `grep -rl` returns 1, and a wrong-field parser
returns 4. **That file is gitignored** — copy the design into the plan rather than relying on it.

---

## The configuration set

### D5 — the `self_evolution.*` / `maintenance.conditions.*` namespace split

**This spec resolves it rather than parking it again.** It has been parked twice.

The field vault declares `maintenance.conditions.pending_observations_threshold: 20` and
`pending_tensions_threshold: 10`; `/rethink` reads those. `/next` and `/remember` read
`self_evolution.observation_threshold: 10` / `tension_threshold: 5`. Both pairs are live in one file,
thirteen lines apart. At 14 open observations and 8 open tensions, `/rethink` reports the threshold
unmet while `/next` and `/remember` recommend running it. **The vault's own tools disagree today.**

The vault diagnosed this on 2026-07-25 and recommended the skills conform to the existing
`maintenance.conditions.*` structure rather than a `self_evolution` namespace be invented (Rule 12).
That recommendation is input, not a mandate — it was addressed to the vault, and this is the
generator. But the generator writes `ops/config.yaml`, so it must pick one namespace and emit it
consistently; the split exists because two generations disagreed.

Constraint that shapes the answer: `read_config.sh` resolves **one** level of nesting.
`maintenance.conditions.*` is three levels and is therefore unreachable by the hook as written.
Choosing that namespace means either deepening the reader or accepting that the hook cannot read it.

### D3 — three thresholds declared in no config file

`SESS_COUNT ≥ 5`, `INBOX_COUNT ≥ 3`, `DAYS_STALE ≥ 30` in `session-orient.sh`. Left hardcoded by
Spec E rather than given invented config keys, so "one surface owns each threshold" is not yet true of
them. The `DAYS_STALE` 30 is methodology-notes-behind-config drift — **not** the same 30 as `/next`'s
`stale_notes` ("not modified in 30+ days"). Same number, different subject; whatever this spec does
must not merge them.

---

## The release-tooling set

### D2 — `bump-version.sh` can leave a partial bump

`cmd_bump` calls `write_json_field` unguarded under `set -e`, so a failure on the second declared site
aborts with the first already rewritten. Reproduced: with `pkg/marketplace.json` unparseable,
`bump-version.sh 8.8.8` leaves `pkg/plugin.json` at `8.8.8` and `marketplace.json` at the old version
— the drift the tool exists to prevent.

`reference/test/bump-version.test.sh` asserts the run does not *report success*, deliberately without
pinning on-disk state, so that an atomic fix does not look like a regression. A proper fix writes all
sites to temps and commits them together.

---

## The record-keeping set

### D10 — a ticked plan step for a check that was built and never shipped

Plan Task 2 Step 4 is `[x]` for an assertion that mis-fired on three healthy templates and was
deliberately dropped. `741b2b7` says it was "recorded in the ledger"; the ledger is `.superpowers/`,
which is gitignored.

**The same mistake was then made by the commit that fixed it**, whose message said three review
findings were "recorded for the whole-branch review" when they had gone to the same gitignored file.
Entries 6–10 exist only because that was caught on re-reading the list.

So D10 is not one ticked box. It is a missing rule:

> **A step that builds a check and finds it mis-fires must have a stated landing place in a tracked
> file.** If a plan does not say where a deferral gets written, the next one goes to the ledger again.

### D4 — reclassify, do not fix

`platforms/shared/skill-blocks/stats.md:94-95` documents unfiltered counts under the label "Pending".
That tree is **frozen** by a `cksum` manifest enforced by `check-portability.sh` check 4, generates
nothing, and is a read-only inventory of vocabulary points.

Fixing it means breaking the freeze — a larger decision than this spec should make. It moves out of
"Known open divergences" into a stated **won't-fix**, with the reason. An entry that cannot be
actioned, sitting in a list of open work, is the same noise problem as entry 6's misplacement,
inverted.

---

## Corrections found while building this list

- **The list said five; it was ten.** Four review findings plus one misplaced entry existed only in a
  gitignored ledger. Both the original commit and the commit that fixed the original made the same
  "recorded" claim.
- **Entry 6 was written down accurately, in the wrong place** — inside the "Closed on" section, where
  nobody scanning open work would see it. Correct content, non-functioning record.
- **D9 is narrower than first stated.** Where the threshold counts actually read `status:` —
  observations, tensions, queue — the fence fixture *does* carry it. Only the notes directory lacks it,
  and nothing scans notes for it today.
- **D8's supporting number was mislabelled, and "latent" was too strong.** The original text said
  "all 14 matching files carry the line inside frontmatter". Measured: the directories the threshold
  counts read are `ops/observations/` (**38** matching, **0** body-only) and `ops/tensions/`
  (**27**, **0**) — so no shipped count was wrong, which is what the claim was reaching for. But
  **14** is the count of *open* observations, a different quantity, correct elsewhere in this spec
  and wrong there. And body-only matches do exist outside that scope, including in
  `ops/methodology/`, which a generator recipe tells vaults to scan — so the class is live in the
  recipes, where no library can reach it. Found by the Task 3 implementer, who also warned the
  figure might be quoted in other briefs; it is not.

---

## Success criteria

1. `validate-kernel.sh` reports a real dangling-link result against a fixture vault whose notes
   directory has an **arbitrary name**, and no line of its output claims a pass for a check that did
   not run.
2. No executable code in `skill-sources/` inlines a wiki-link matcher.
3. One command enumerates every declared `status` value across `generators/`, and its output is
   internally consistent.
4. Frontmatter field extraction has one implementation, and the fence-gate fixture can tell a correct
   parser from a broken one on the notes directory.
5. One namespace owns the self-evolution thresholds, and the reader can reach it.
6. `bump-version.sh` either bumps every declared site or leaves them all unchanged.
7. Every remaining divergence entry is actionable, and every non-actionable one is labelled won't-fix
   with its reason.
8. A deferral written during this work lands in a **tracked** file, and the plan says which.

---

## Explicitly out of scope

- **Breaking the `platforms/shared/skill-blocks/` freeze.** D4 is reclassified, not fixed.
- **A numerical-correctness gate.** Still absent, still stated in `CLAUDE.md`'s Verification section;
  building it means per-fence expected-output fixtures, which is a project, not a task.
- **Re-running `/arscontexta:upgrade` as a slash command.** Structurally impossible against another
  tree; the hand-execution evidence stands.
- **The `README.md` Antigravity claim.** The user's uncommitted change; theirs to decide.
