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

**Sprint C — schema coherence over status and description.** Not queued here: its core already
has an active spec and plan.

- Spec: `docs/superpowers/specs/2026-08-08-corpus-wide-passes-design.md`, "Item 3 — the note lifecycle"
- Plan: `docs/superpowers/plans/2026-08-08-note-convention-and-lifecycle.md` — 8 tasks

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
