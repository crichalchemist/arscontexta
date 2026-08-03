# Spec E — the fourteen open items, and the agent surface that should have caught four of them

**Date:** 2026-08-03
**Branch to cut from:** `main`, after `docs/skill-authoring-reference` merges
**Predecessors:** Spec C (`fix/spec-c-primitive-10`), Spec D (`docs/skill-authoring-reference`)

---

## What this is

Every open item in the repository, in one place, with a fix specified for each. Fourteen of them.
They are not a grab-bag: **eleven are the same defect class** this project keeps finding — a check,
count, or claim that produces a plausible answer while measuring nothing — and the remaining three are
the absence of the infrastructure that would have surfaced them earlier.

The list is closed. It was built by sweeping the divergence list, the final whole-branch review, the
execution ledgers, and the field vault, then measuring each candidate rather than trusting its
description. Two entries changed on measurement and one was deleted as already-fixed (see
*Corrections found while building this list*).

---

## The two that ship to users

These are the only entries that reach a machine we will never see. They rank first for that reason
alone.

### E1 — the claim counter is capped at 999 in every generated vault

`skill-sources/reduce/SKILL.md:897` says only *"NNN is the claim number, starting from
`next_claim_start`"*. There is no width rule. The field vault hit this on 2026-08-02: its counter
passed 999 and it now holds `…-1000.md` through `…-1020.md`. It was fixed **there** and never
backported — `~/second-brain/.claude/skills/extract/SKILL.md:904` carries a Width paragraph the
template does not:

> `NNN` is seven digits minimum (raised from three at the author's direction), and wider numbers pass through
> unchanged. Never truncate to three, and never pad to a fixed wider width: re-padding would rename
> every existing claim and break every reference to it.

The re-padding warning is the load-bearing half. A naive fix that widens to four digits renames
`…-042.md` to `…-0042.md` and breaks every wiki link pointing at it — wiki links resolve by filename.
`skill-sources/seed/SKILL.md` needs the matching validator change: it must scan width-agnostically
(three **or more** digits) and recognise a claim by its `# claim-NNN` heading, so timestamped and
arXiv-ID filenames stay out of the numbering scan.

**This is the backport loop failing exactly as CLAUDE.md warns.** The fix existed in the field for a
day and could not reach a single user.

### E2 — `/next` promises eight state fields and computes five

Divergence 2. `skill-sources/next/SKILL.md` assigns `INBOX_COUNT NOTE_COUNT OBS_COUNT SESSION_COUNT
TENSION_COUNT` and its output contract reads
`Inbox | Notes | Orphans | Dangling | Stale | Obs | Tensions | Queue`. **Orphans, Dangling, Stale and
Queue are assigned nowhere**, verified by enumerating every assignment in the file, and no helper is
sourced. `queue` is named 21 times and computed zero. `skill-sources/graph/SKILL.md` references
orphans with zero `ORPHAN_COUNT=` occurrences.

Claude reads the contract, emits the line, and invents four numbers. Deferred once already because
four definitions of "stale" are in play — **that is the decision this spec must make, not defer
again**: pick one definition per field, or delete the field from the contract. A contract with an
unbacked field is worse than a shorter contract.

Whatever is computed must use `reference/lib/link-extraction.sh` and its `*_recursive` variants, not
an inlined `grep -rl "[[$NAME]]"` — the naive spelling counts links inside fenced blocks, does not
case-fold, and matches the wrong direction for orphans. It is a documented accepted defect in two
templates already; a third is not acceptable.

---

## The gate-integrity set — checks that cannot fail for the right reason

### E3 — the fence-gate allowlist can absorb an unrelated failure

Divergence 1, and it ranks high because it is the entry that lets others recur unseen. Absorption in
`reference/test/fence-isolation.test.sh` keys on `(letter, label)` alone, ignoring both the entry's
stated reason and its `ZSH ONLY:` scope. An entry listed for one reason silently swallows a different
failure on the same fence — measured, in the shell its own reason excludes.

Nothing is masked on the shipped tree today. The defect is the keying, and it was demonstrated at an
intermediate state during Spec C. The fix is a design decision: either entries key on reason as well
as `(letter, label)`, or the shell filter that already governs the stale-entry table also gates
absorption. **Decide and implement; do not record it a third time.**

### E4 — `29/29` is not branch coverage

The final review mutation-tested the ten check-4 assertions and found the DELETED branch unpinned:
replacing `if [ ! -f "$FROZEN_DIR/$name" ]` with `if false` leaves the suite **green**, because
`cksum < <missing>` yields an empty digest and the file reports MODIFIED instead. The outcome is
caught; that branch is not. One assertion that distinguishes DELETED from MODIFIED closes it.

### E5 — the zsh suite never runs the guard under zsh

`guard-failure.test.sh`'s `rc_of` and `out_of` hardcode `bash "$GUARD"`. Running the suite under zsh
exercises the harness under zsh and always invokes `check-portability.sh` under bash. Given that
file's `#!/bin/bash` shebang this is defensible — **but it must be a decision, not an accident**, and
it sits directly beside E6. A gate that looks like it covers both shells for its subject and does not
is this repo's signature shape.

### E6 — `scripts/bump-version.sh` has no test coverage at all

It is new, it writes to every version manifest, and no gate exercises it. CI runs `--check` only,
which is the one path that does not mutate anything. Its short life already produced four defects the
review had to find by hand: a zsh `PATH` collision that exited 127, an unreachable error branch under
`set -e`, an unanchored version regex that let a jq injection through, and a "null" version reported
as agreement. **A script that rewrites release metadata deserves the same failure-path suite
`guard-failure.test.sh` gives the portability guard.**

---

## The configuration and display set

### E7 — two configuration surfaces that cannot see each other

Divergence 3. `hooks/scripts/read_config.sh` reads the top-level `.arscontexta` marker and handles
**scalar top-level keys only**, so it structurally cannot reach a nested `ops/config.yaml` key. The
SessionStart hook therefore carries hardcoded thresholds while three skills read `self_evolution.*`
from `config.yaml`. Three sources currently disagree: skills 10/5, plugin hook 10/5, the field vault's
patched hook 20/10.

Surfaced deliberately rather than averaged, twice. **Resolve it**: either teach `read_config.sh` one
level of nesting, or move the thresholds to where it can already read them, and make the losing
surface fail loudly rather than carry a stale default.

### E8 — display counts that merge or omit a status filter

Divergence 4. `skills/help:49` counts observations and methodology notes as one total;
`platforms/shared/skill-blocks/stats.md:94-95` documents unfiltered counts under the label "Pending".
Both are presentation decisions rather than clear defects — **but the same mislabel in
`session-orient.sh` and `skills/health` WAS a defect**, because those numbers drive a threshold. The
fix is to make each display state what it counts, so the next reader does not have to re-derive
whether a filter applies.

---

## The verification set

### E9 — `/arscontexta:upgrade` has never been run against a real vault

It now performs three repairs (`ops/lib/`, `ops/queue/.locks/`, `self_evolution:`) that are prose
contracts CI cannot exercise. It is the one command whose failure mode is silently not repairing a
user's vault. Needs one real run against a copy of the field vault, with before/after evidence.

### E10 — the prose-contract path rule is enforced by nothing

`reference/skill-authoring.md` §4 requires every filesystem path named in a prose contract to exist in
the packaged plugin. A defect of that shape survived four gates, a 127 KB review, and a live vault
run. A checker was deliberately declined because "the packaged plugin" is not a defined build target.

**That reasoning stands, and this spec does not reverse it** — but it should be re-examined once, with
the narrower question asked: can the weaker property (*every path named in prose exists in the repo*)
be checked without pretending to be the stronger one? If yes it is worth building under an honest
name. If no, the entry closes permanently rather than recurring.

### E11 — a divergence entry that is itself stale

CLAUDE.md divergence 5 states *"the two older plans in `docs/superpowers/plans/` show 0 of 93 steps
complete while being fully executed."* **Measured today: 16 of 16 and 22 of 22 ticked, none
unchecked.** The plans were fixed; the entry describing them was not. A status file lying about status
is this project's named defect — and the divergence list that names it is now doing it.

### E12 — the reference document's discoverability is verified at n=1

Task 4's done-when required ≥4 of 5 fresh agents to find `reference/skill-authoring.md` unprompted. The
only clean pre-change baseline was one agent, which did not find it. One clean post-change agent did —
**but by listing `reference/`, not via the pointer that was added**, so the remedy is unverified. Three
further agents retrieved it while straddling the change and are unattributable.

The determinant looks like search strategy: an agent that enumerates the directory finds it; one that
greps its task's keywords does not, because the document contains none of them. **Test that
hypothesis** — the cheap fix is keywords a searcher would actually use, and it needs one clean rep
against a frozen tree to confirm.

---

## The workspace surface — and why it belongs in this list

Three entries, and they are the reason the other eleven took this long to find.

### E13 — the agent-facing surface is Claude-only

`CLAUDE.md` is 18.9 KB of hard-won guidance: the three traps, both invariants, the backport
reverse-transforms, the divergence list. **No other runtime can see any of it.** There is no
`AGENTS.md`, no `GEMINI.md`, no `.agents/`, no `.gemini/`. My standing workspace rule requires exactly
that surface and it was never built here.

`/Volumes/Containers/superpowers` is the model, and the mechanism it uses is the point:

| file | mechanism | why that one |
|---|---|---|
| `AGENTS.md` | **symlink → `CLAUDE.md`** | one inode, two names. Drift is not unlikely, it is *impossible*. |
| `GEMINI.md` | small pointer file of `@./path` includes | Gemini needs different tool references, so content genuinely differs |
| `.agents/plugins/marketplace.json` | cross-runtime discovery | one manifest other runtimes read |
| `.codex-plugin/`, `.cursor-plugin/`, `.kimi-plugin/`, `.pi/`, `.opencode/` | per-platform `plugin.json`, all pointing at the same `./skills/` | platform metadata varies; the skills do not |

**Symlink, not copy — and this is E7 in a different costume.** A copied `AGENTS.md` is a second
configuration surface that cannot see the first, which is precisely the defect E7 exists to fix. The
repo already knows this pattern is dangerous; it should not create a new instance of it while fixing
the old one.

Scope discipline: adopt `AGENTS.md`, `GEMINI.md` and `.agents/`. **Do not** create dot-dirs for
platforms that are queued rather than built — Antigravity and Pi are queued, and a `plugin.json`
claiming otherwise is E14's defect in advance.

### E14 — nothing runs before CI

No `.pre-commit-config.yaml`. Every gate in this repo runs only after a push, which is how CI went red
for two pushes behind a `gh`-on-a-fork false negative. `check-portability.sh` takes under a second and
would have caught several entries above at commit time.

Related and unresolved, flagged rather than fixed here because it is the author's call: the
uncommitted `README.md` change marks **"Antigravity CLI plugin | Available"** in the feature table
while the platform is queued. If a pre-commit gate had existed, an availability claim with no adapter
behind it is exactly what it should refuse.

---

## Corrections found while building this list

Recorded because a list assembled by trusting its own sources would reproduce their errors.

- **E11 was found by measuring a divergence entry rather than reading it.** It described a defect that
  no longer exists.
- **The `max_count=999` framing does not match the code.** No `max_count` symbol exists in either
  repository; the ceiling is the `NNN` filename width. The reported symptom was real and the named
  cause was not, which is why E1 is specified against measured filenames.
- **One candidate was dropped.** "Older plans show 0 of 93 steps" appeared to be two items (the plans,
  and the divergence entry). It is one: the plans are fixed, only the entry is stale.

---

## Success criteria

1. `skill-sources/reduce` and `skill-sources/seed` carry the width rule and a width-agnostic
   validator, and a generated vault numbers past 999 without renaming anything below it.
2. `/next`'s output contract and its computed variables match exactly — every promised field backed,
   or removed from the contract. Same for `graph`.
3. The fence-gate allowlist cannot absorb a failure its entry's stated reason does not cover.
4. Mutating any branch of check 4 turns at least one assertion red.
5. `bump-version.sh` has a failure-path suite; its shell coverage is a stated decision.
6. One configuration surface owns the thresholds; the others read it or fail loudly.
7. Every displayed count states what it counts.
8. `/arscontexta:upgrade` has been run against a real vault with recorded evidence.
9. `AGENTS.md` is a symlink to `CLAUDE.md`; `.agents/` and `GEMINI.md` exist; **no dot-dir claims a
   platform that is not built.**
10. `.pre-commit-config.yaml` runs `check-portability.sh` before commit.
11. Every claim in CLAUDE.md's divergence list re-derives from a command in the entry.
12. All gates green in both shells; `validate-kernel.sh` 15/15 against the field vault.

## Explicitly out of scope

- Building Antigravity or Pi adapters. They are queued; this spec only forbids claiming them.
- Reversing E10's decision. It gets one re-examination under a narrower question, not a rebuild.
- Any change to `platforms/shared/skill-blocks/`. It is frozen and gated.
