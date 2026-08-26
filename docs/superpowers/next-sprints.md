# Next sprints

Queued work, decided 2026-08-15 from a triage of the 28 open entries in
[`deferrals.md`](deferrals.md). Recorded here because a record that does not ship is not a
record — the same rule that governs the deferrals file itself.

**Order: B, then A.** Sprint C is not listed here because it is already specced, planned, and
in execution — see [In flight](#in-flight).

Numbers below are `deferrals.md` entry numbers. Re-derive an entry before acting on it: four
entries in that file were found asserting things that were no longer true, and the failure mode
is a plan written against a false premise.

---

## Sprint B — the generator→vault reach mechanism

**Entries:** 11 (core), with 15, 27 and 1 folded in as its first three consumers.

**Needs a full cycle: brainstorm → spec → plan → execute.**

This is not a judgment call. `docs/superpowers/specs/archive/2026-08-05-generator-vault-enforcement-gap-design.md:225`
already required it, verbatim:

> A design for that is its own spec.

Spec H closed the narrower half of divergence 16 and scoped the re-sync mechanism out
explicitly. That deferral is what this sprint collects.

**What it is.** A generated vault has three tiers of validation that do not connect, and a rule
added to this repo today reaches **new vaults only**. There is no mechanism by which a fix
reaches a vault that already exists. Entries 15, 27 and 1 are three separate consumers all
stalled on that one absence — guard reach, `/upgrade` baseline retention, and the
recipe-vs-library mechanism.

**What it buys.** It converts "we fixed it in the generator" from a statement about future
vaults into one about existing ones, and retires the standing caveat `CLAUDE.md` attaches to
every generator-side fix.

**Expect a spec, not shipped behaviour.** Its highest-probability output is the design
document. Specing the four together is the point — three partial mechanisms would be worse
than none.

---

## Sprint A — make the ledger true, kill the cheap silents

**Entries:** 3, 9, 14, 17 (close with drift records) · 22 (fix + assertion) · 28 (born-red
fixture) · 29 (pin the remaining `comm` sites, reword two stale rationales) · 25 (zsh loop
rewrite + posture pin) · 23 (`|`-idiom allowlist + entry-count assertion).

**Needs a plan only. No spec.** Every item is bounded, decision-free, and already carries its
own re-derivation command in `deferrals.md`. There is nothing to design. It suits
subagent-driven execution directly.

**One real defect ships in it:** entry 22 — `skill-sources/next` f02's JSON arm re-tests
`status == "pending"` after a prior clause set it `"done"`, so `completed` timestamps never
land on JSON-format queues. Preserved deliberately during the post-merge-hardening branch under
Rule 5 and annotated at its site; this is where it gets fixed.

**Sequencing note, recorded rather than acted on.** Entries 3, 9, 14 and 17 are currently
false — the defects they describe are fixed and their entries were never updated. That makes
them a precondition for planning anything else accurately, including Sprint B, whose spec would
otherwise be written against a backlog containing four untrue claims. Entry 9 is the sharpest
case: it asserts a coverage gap that Task 14 of the post-merge-hardening branch closed, and its
own re-derive command now returns 2 where the entry promises 0.

They are cheap, pure-write closures. Pulling them ahead of B was offered and B-first was
chosen; this paragraph exists so the cost is visible rather than rediscovered.

**A gate that would prevent the recurrence, not yet built.** Every deferral entry already
carries a ```bash re-derive block. Nothing runs them. A gate executing each entry's own command
and flagging any whose answer now indicates "fixed" would drain this file the way
`fence-isolation.test.sh`'s allowlist already drains itself — the mechanism exists in this repo
and is simply not pointed at this file. Belongs to the CI-hardening spec.

---

## In flight

**Sprint C — schema coherence over status and description. BLOCKED on a re-spec, decided
2026-08-15.** The plan below cannot be executed as written and its central task would damage the
field vault. A staleness audit against `main` @ `d146069` returned: T1 hold · T2 shifted ·
**T3 step 3 broke** · T4 hold · **T5 broke** · T6 hold · T7 shifted · T8 shifted/partly broke,
with 12 stale citations.

**T5 is the reason this stopped — but not for the reason first recorded here.** Its
read-modify-write reads through `frontmatter_field`, which strips balanced quotes, and emits the
value back **unquoted**. Against the live corpus that rewrites **1776** files without their
quotes and produces **invalid YAML on the 473 carrying a colon inside the value**, while its
"expect 1633" progress check reads as plausible forward motion throughout. Verified by executing
the plan's own fixture: it returns `A quoted one.` and the rewrite emits it unquoted.

**T3 step 3** gates promotion on `$VERIFY_FAIL_COUNT`, which exists nowhere in `verify`. Fences
are separate shell invocations, so it expands empty and promotion silently never fires.

### CORRECTION, 2026-08-15 — what this section claimed, and what refuted it

This section first read: *"The plan's normalizer targets bare `description:` scalars, assuming
1621 bare / 12 quoted. **The corpus has since inverted**"*, and concluded *"T5's stated purpose
(clear a 1621-note backlog) **has largely evaporated on its own**, with ~8 bare-with-period notes
remaining."*

**Both claims were false**, and the decision to re-spec was taken on them. Refuted by a forensic
pass over the vault's git history plus a direct census:

```bash
# quoted with trailing period 1776 · bare with trailing period 8 · TOTAL 1784
# quoted without 1000 · bare without 90
```

- **The corpus never inverted.** Descriptions have been written quoted at note creation since the
  April 2026 ingestion — 2588 of 2686 were already quoted before 2026-08-07.
- **The plan's `1621 bare / 12 quoted` was never a bare-vs-quoted census.** It was a
  *trailing-period* census taken through the quote-stripping `frontmatter_field` accessor, so
  every quoted value looked bare to it. The arithmetic matches exactly:
  `1621 = 1613 quoted-with-period + 8 bare-with-period`.
- **T5's purpose is intact and has grown**, from 1621 to 1784 targets — the increase is 187 new
  notes born quoted on 2026-08-14, not a rewrite. The constant `8` across both censuses is the
  tell: it was read as the residue of a finished job when it is a subset that was always tiny.

**What survives the correction:** T5's mechanism defect and T3's dead gate, both established
empirically and neither dependent on the misreading.

**Kept rather than rewritten**, per this repo's convention — a claim that went wrong is evidence
about how it went wrong, and this one shows a measurement artifact being mistaken for a change in
the world.

### Forensics result — no unattended rewriter exists

Run before the re-spec, on the premise that a spec written against a corpus something was
actively rewriting would race it. There is no such thing:

- **crontab empty**; the one loaded launchd agent (`com.second-brain.vault-embed-serve`) has zero
  write-opens and zero description references; the vault's other plists point at scripts that no
  longer exist and are not installed.
- **The plan's normalizer never ran** — bare counts are frozen at 98/8 across every August snapshot.
- **What IS live:** the note-creation pipeline, still writing quoted descriptions; the PostToolUse
  auto-commit hook; and agents stripping trailing periods opportunistically per the
  `/validate`–`/verify` convention.
- `3eabdea3` "Auto: 520 files" (2026-08-14) was a **link-enrichment sweep**, not a description
  normalization: 492 wiki-link additions against only 25 description edits, 23 of them plain
  period strips.
- **It was recorded** — `ops/health/2026-08-14-report-2.md:267` names the SHA and the sweep's
  origin — and evidently never read. `ops/changelog.md` has no 2026-08 entries at all.

**Method caveat carried from that investigation:** the rtk hook filtered at least one counting
pipeline mid-run (a `git show | grep -c` returned 0 against a diff containing 25 matches). Every
published count was re-derived inside a bash script file using `/usr/bin/grep`.

### Standing decision

**Re-measure Item 3's design premises first, then revise the plan** — not a full re-spec. The
design's conclusion holds, but the `1621` figure proved to be an artifact of *how* it was
measured rather than what was there, so the premises get re-derived before the plan is edited. If
re-measurement shows the design itself is unsound, escalate to a re-spec then; that path stays
open and this choice is the reversible one.

### Decisions taken 2026-08-15, for the re-spec to carry

These settle the three entries the source spec deferred out of itself. All three fire by their
own `Reopens if` conditions the moment Item 3 is revisited.

- **Entry 5 — the statusless notes: derive status from a checkable property.** MOC-referenced
  notes become `active`; orphans become `preliminary`. **This overrides the entry's own stated
  reasoning** — it argues that inferring status "from age or link count would assert a quality
  claim nothing checked." The distinction relied on: MOC membership is a structural fact a human
  actively created, not a proxy like age or raw link count. Record both sides when closing it,
  in the shape entry 19's closure uses. **The count is 698, not the entry's 681** — re-derive
  before acting. The rule for notes in neither category is still open.
- **Entry 6 — description length: `200` is canonical.** The majority spelling (three sites
  against two), and `~150` reads as a soft target rather than a constraint. The entry warns its
  own count is "at least" — a term-keyed survey cannot enumerate sites that omit the term — so
  the true site count must be re-derived, not inherited.
- **Entry 7 — off-enum statuses: adopt `superseded`, correct the other two.** `superseded` is a
  real lifecycle state the vault's own template declares and canonical lacks — the same dialect
  gap as `draft`, and the divergences 7–9 precedent says a value the vault's template declares is
  a gap rather than an error. `closed` (11) and `investigating` (1) are in neither enum: 12 vault
  notes to correct, not a generator change.

### The superseded plan and spec

Retained for reference; **do not execute the plan.**

- Spec: `docs/superpowers/specs/2026-08-08-corpus-wide-passes-design.md`, "Item 3 — the note lifecycle"
- Plan: `docs/superpowers/plans/archive/2026-08-08-note-convention-and-lifecycle.md` — 8 tasks

Measured coverage against the entries triage assigned to C: entries **8** (`open`'s semantics)
and **12** (`generators/` enum placeholders) are covered by that spec and plan. Entries **5**
(statusless notes / backfill rule), **6** (~150 vs 200 description length) and **7** (off-enum
vault statuses) return zero matches in either document and are genuinely uncovered — and they
are the three requiring a decision rather than an implementation.

The plan was last touched 2026-08-09 and 41 commits have merged since, so it needs re-deriving
against the current tree before execution rather than being run as written.

---

## Not on any sprint

Set aside deliberately during triage, so they are not rediscovered as neglected:

- **26, 30** — provenance and process records. History, not backlog.
- **4** — a measured negative decision, already made.
- **2, 18, 20** — accepted limitations with stated reasons.
- **13** — its residue is a recorded trade-off.
- **10, 21, 24** — routed to `docs/superpowers/specs/archive/2026-08-04-ci-hardening-design.md`.
  Do not plan these twice.
