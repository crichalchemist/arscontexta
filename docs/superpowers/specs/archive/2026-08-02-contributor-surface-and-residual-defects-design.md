# Spec C — Contributor surface and residual defects

**Date:** 2026-08-02
**Status:** design approved; implementation not started
**Predecessors:** Spec A1 (portability/link correctness), Spec A2 (silent-failure hardening),
Spec B (stale contracts and dead configuration) — all implemented, CI green on `main`.

---

## Problem

Three specs' worth of defects were found in this repo over two days. Almost none of them were found
by reading the code. They were found because a *personal, untracked* `CLAUDE.md` told a reader where
to look and what this repo's failure mode is.

That file was never committed. It is not gitignored — it simply never entered git. So the single
artifact most responsible for every fix on `main` is invisible to anyone who clones the repository.
A contributor arriving today gets: no build, no test runner, no dependency manifest, no
`CONTRIBUTING.md`, and no explanation of why `grep` behaves differently inside a Claude Code session
than in their own shell.

The residual defects below share that root. Each is individually small. Collectively they are the
difference between a repo whose invariants are *enforced* and one whose invariants are *known to one
person*.

### Why this is urgent rather than tidy

This repo is a **generator**. Its output runs on other people's machines, and its characteristic
failure is a plausible number rather than an error. A contributor who does not know that will write
a bash block that reports `0` on failure, it will pass review because it looks correct, and it will
ship into every vault generated thereafter. The guidance is not documentation-for-politeness; it is
the mechanism that has been catching these.

---

## Scope — five items

### 1. Commit and maintain the agent-facing `CLAUDE.md`

Root `CLAUDE.md` becomes tracked. It already declares itself as such in its own header ("Tracked
repository guidance. Committed and shipped with the repo so every contributor and every fresh clone
gets it"), which was aspirational until now.

It has been refreshed as part of this spec: the "Known open divergences" section, which listed
`grep -P`, naive wiki-link parsing, the `/rethink` status split, the `self_evolution` gap and
`/learn`'s Exa tools — **all now fixed** — has been replaced with what actually remains, and the
Verification section now describes five checks rather than one.

**Constraint:** the file must state what is *currently* true or it becomes an active hazard. A stale
"known issues" list is worse than none, because it spends a reader's attention on solved problems
and implies the unsolved ones don't exist.

### 2. Write `CONTRIBUTING.md` — the human workflow

Distinct from item 1 by audience, per the dual-layer strategy the header already names: `CLAUDE.md`
carries agent-facing repository guidance; `CONTRIBUTING.md` carries the human contribution workflow.

Must cover, because each has already cost someone real time:

- **There is no hot reload.** Editing a skill and re-running it without cycling `/plugin
  uninstall` + `/plugin install` serves the cached copy. This is the most common way to "fix"
  something and observe no change.
- **`grep` inside a Claude Code Bash session is ugrep**, which accepts `-P`. `/usr/bin/grep` on
  macOS is BSD 2.6.0 and exits 2. Portability claims verified from inside the session are false
  negatives. Verify with `/usr/bin/grep` explicitly or from a non-Claude-Code shell.
- **`gh` on a fork silently queries upstream.** `gh run list` returns empty — which reads as "CI
  never ran" — when CI is in fact red. Always pass `--repo`.
- The five gates, and that all four CI gates run under **both** bash and zsh.
- The backport loop and its two mandatory reverse-transforms (vocabulary → canonical, concrete
  paths → placeholders).
- Commit and branch conventions as actually practised on `main`.

### 3. Make the plan artifacts tell the truth

`docs/superpowers/plans/archive/2026-08-01-portability-link-correctness.md` and
`…/2026-08-02-silent-failure-hardening.md` show **0 of 93 steps complete** while both are fully
executed and merged. The SDD ledgers under `.superpowers/sdd/` are accurate; the plans are not.

This is the repo's signature defect in a new location: a status artifact that reports what someone
remembered to update rather than what is true. Resolve by ticking the boxes against the ledger's
commit record, or by removing the checkboxes and pointing at the ledger as the record — but not by
leaving them.

### 4. Harden Kernel Primitive 10 to assert resolution, not presence

`validate-kernel.sh` checks that `qmd` is on `PATH`. qmd *was* on PATH throughout the entire period
when 62 references named tools removed from its MCP surface. The validator reported semantic search
satisfied while every call failed and each skill's documented "fall back to `rg`" path silently
stood in.

Three states must stay distinct — collapsing the last two into "not PASS" is what hid this:

| State | Verdict |
|---|---|
| qmd absent | WARN — semantic search is optional |
| qmd present, declared tool names resolve | PASS |
| qmd present, names do NOT resolve | **FAIL** |

Full step-by-step implementation, including the non-vacuity mutation, is already written as Task 5
of `docs/superpowers/plans/archive/2026-08-02-stale-contracts-and-dead-configuration.md`. This spec adopts
it rather than restating it.

### 5. Residual defects — decide, then either fix or record with a reason

Not one bucket; three different kinds of open, and conflating them is why they linger:

**5a. Blocked on a design decision, not on effort.**
- The 8 allowlisted fence defects. `seed` f01/f03/f04/f05 read `$FILE`, the invocation argument —
  the fix requires deciding whether each fence re-derives it or reads `$ARGUMENTS`. The N-class four
  (`next` f04, `reflect` f03, `health` f10, `help` f01) each render `0` on a missing notes directory;
  what a missing vault *should* mean is four separate calls, not one.
- The unbounded stale-lock retry in `reflect`/`reweave`. **`mkdir -p` is not the fix** — it returns 0
  when the lock exists and destroys the mutex. Bounding the wait changes shipped concurrency
  semantics.
- Canonical `open` vs `pending` for new observations. Readers accept both, so nothing is broken
  either way; writers still disagree.
- Unifying `.arscontexta` and `ops/config.yaml`. `read_config.sh` handles scalar top-level keys only
  and structurally cannot reach a nested key.

**5b. Verification that has never been run.**
`/arscontexta:upgrade` has never executed against a real vault, and now performs three repairs
(`ops/lib/`, `ops/queue/.locks/`, `self_evolution:`) that are prose contracts CI cannot exercise.
Running it against `~/second-brain` is the only way to learn whether the generator half works. It
mutates a live vault, so it is the owner's call.

**5c. Environmental, blocking verification.**
The development machine's boot volume is at 100%. Docker fails with an I/O error writing container
metadata, so Linux behavior cannot be reproduced locally and every Linux-affecting change costs a
CI round-trip. Three were spent this session on defects a local container would have caught in
seconds.

---

## Non-goals

- Adding a build system, test runner, or dependency manifest. The product is markdown, YAML and
  bash; "compiling" is Claude reading a template. Introducing tooling to make the repo look
  conventional would add a dependency to every contributor's machine for no gain.
- Adding `python3` anywhere. It is absent from the README prerequisite table and from every file
  under `skill-sources/`. `rg` is the blessed instrument.
- Fixing 5a items. This spec's job is to make each a *decision* with its consequences stated, not to
  decide them.

---

## Success criteria

1. `git ls-files CLAUDE.md` is non-empty, and the file's "Known open divergences" section matches
   what `rg` finds in the tree.
2. `CONTRIBUTING.md` exists and covers all six bullets in item 2.
3. No plan under `docs/superpowers/plans/` shows 0 complete while its ledger records completion.
4. `validate-kernel.sh` FAILS when a dead `mcp__qmd__*` name is reintroduced, and PASSES when it is
   removed — demonstrated by mutation, not asserted.
5. Every 5a item appears in `CLAUDE.md` with its consequence stated, so a contributor meets it as a
   known decision rather than a surprise.

---

## The risk this spec is really addressing

Every defect fixed across A1, A2 and B presented identically: **nothing happened, and nothing was
wrong.** A count of 0. An empty result. A fallback that fired. Exit 0.

The gates now catch that class *in shell*. Items 1–3 extend the same principle to the repository's
own status surface — the guidance file, the contribution docs, the plan checkboxes — because a
status artifact that reports what someone remembered rather than what is true is the identical
defect one level up. Item 4 closes the last place a validator still measures a proxy.
