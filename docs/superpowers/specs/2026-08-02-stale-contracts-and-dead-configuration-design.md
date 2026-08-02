# Spec B — Stale contracts and dead configuration

**Status:** B1, B2, B3 and the qmd migration are implemented. This document is written after the
fact, deliberately: the findings were verified one at a time and the shape of the problem only
became clear once all four were in view. It is the record of what the defect class *is*, so the
remaining items can be judged against it rather than re-derived.

**Date:** 2026-08-02
**Branches:** `fix/observation-status-vocabulary` (B1-B3), `fix/qmd-query-migration` (B4)

---

## Problem

Four unrelated-looking defects turned out to be one class. In each, a capability was **declared,
documented, wired in, and inert** — and the failure presented to the user as *nothing happening*,
never as an error.

| # | Capability | Why it never worked |
|---|---|---|
| B1 | `/rethink` observation threshold | matched `^status: pending`; every vault writes `status: open`. Counted 0 of 21 forever. |
| B2 | `self_evolution.*` thresholds | 5 skills read the keys, **0 generators write them**. Documented, undiscoverable, permanently at defaults. |
| B3 | `/learn` deep research tier | built entirely on `deep_researcher_start`/`_check`, removed from the Exa MCP surface. |
| B4 | Semantic search (Kernel Primitive 10) | 61 references to `mcp__qmd__search`/`__vector_search`/`__deep_search` across 19 files. None exist. |

### Why none of this was caught

Each had a **status check that measured a proxy** rather than the property:

- `session-orient.sh` counted *files* and called the total "pending" — so triage could never reduce it.
- `validate-kernel.sh` primitive 10 checks that **qmd is on `PATH`**. qmd was on PATH the entire
  time. The primitive reported satisfied while every call to it failed.
- setup's research-tier probe tested for a tool that had been removed, so it always failed and every
  vault silently recorded `primary: web-search` — the *better* tool written in as the fallback.

And each had a **fallback that absorbed the failure**: skills document "fall back to `rg` if MCP is
unavailable". MCP was not unavailable. The tool name was wrong, the call failed, the fallback fired,
and keyword grep quietly stood in for semantic search in every vault.

### The generator amplifies it

This repo is a generator. A stale name in a template is not one broken call — it is one broken call
in every vault ever generated from it, including vaults whose owners will never read this repo.

---

## Decisions

**D1 — Readers accept both status spellings; writers are not unified.** `pending` and `open` both
count. This conforms each file to its own adjacent convention: the *tension* line in all six files
already accepted both, and only the *observation* line beside it did not. Which spelling is
canonical for NEW observations is left open — it is a vocabulary choice, not a defect.

**D2 — Emit configuration keys even at their defaults.** A key absent from every generated config is
undiscoverable. Correct fallback behavior is not sufficient; the user must be able to see the knob.

**D3 — Degrade loudly, never silently.** Where a capability genuinely is unavailable, warn on stderr
and continue. Do not hard-exit (it bricks the common case) and do not degrade quietly (that is the
defect class itself).

**D4 — Re-map removed capabilities onto tools that exist; do not silently drop them.** `/learn`'s
deep tier became search-for-breadth then fetch-in-full. Full page text vs snippets is a real
difference in evidence quality, so the documented capability survives honestly.

**D5 — Migrations that change call shape are rewrites, not renames.** `deep_search` → `query` changes
the parameter shape to a typed `searches` array and moves reranking from the tool *name* into a
**flag defaulting to `true`**. Mechanical substitution would have silently added reranking to the
calls that deliberately avoided it.

**D6 — Two configuration surfaces are surfaced, not bridged.** `read_config.sh` reads the top-level
`.arscontexta` marker and handles scalar keys only, so it cannot reach a nested `ops/config.yaml`
key. The hook therefore keeps its own thresholds. Unifying the surfaces is a design change; it is
recorded, not performed.

---

## Scope

**In:** the four defects above, in generators and templates, with prose contracts updated alongside
code — in this repo prose *is* executable, and a narrow prose table beside a widened bash line is
just the same defect in a different font.

**Out, and named so it is not mistaken for oversight:**

- canonical `open` vs `pending` for new observations (D1)
- unifying `.arscontexta` and `ops/config.yaml` (D6)
- the 8 allowlisted fence defects (own work, allowlist is bidirectional so it drains)
- bounding the stale-lock retry in `reflect`/`reweave`

---

## Verification

Every claim in this spec was measured, not inferred. Three specific traps were hit and are worth
recording because each produced a *confident wrong answer*:

1. **`gh run list` on a fork silently queries upstream.** It returned empty, which reads as "CI never
   ran". CI was red. Always pass `--repo <fork>`.
2. **A locale *name* probe is not a folding probe.** It found `C.utf8` on Ubuntu and folding still
   failed — GNU `tr` is byte-oriented in every locale.
3. **A CLI subcommand is not an MCP tool.** `qmd --help` still lists `search` and `vsearch`, which is
   almost certainly why the dead MCP names survived. Only the MCP surface dropped them.

Standing requirement from all three: **verify the property, not a proxy for it.** Where a check
exists to guarantee a capability, it should exercise that capability on a known input.

---

## Follow-up this spec creates

`validate-kernel.sh` primitive 10 checks that qmd is *installed*. That check passed throughout the
entire period when all 61 of its call sites were broken. Until it asserts that the tool names
actually resolve, this exact failure recurs invisibly the next time a provider changes its surface —
and the validator will report the primitive satisfied while it does.
