# Stale Contracts and Dead Configuration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or
> superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.
>
> **Checkbox state in this file is kept honest.** Tasks 1-4 are marked `[x]` because they are
> merged and CI-green; each names its commit. The sibling plans in this directory show 0 of 93
> steps complete while being fully executed — a status file that lies about status is the exact
> defect class this plan exists to remove, so do not let that happen here. Tick as you go.

**Goal:** Remove the class of defect where a capability is declared, documented, wired in, and
inert — failing as *nothing happening* rather than as an error.

**Spec:** `docs/superpowers/specs/archive/2026-08-02-stale-contracts-and-dead-configuration-design.md`

**Architecture:** Fixes land in generators and templates, never in the consumers that read them.
Prose contracts move with the code they describe — in this repo Claude executes prose tables, so a
narrow table beside a widened bash line is the same defect in a different font.

**Tech Stack:** Markdown templates, bash, YAML. No build. Gates are
`reference/check-portability.sh` plus three harnesses under `reference/test/`, each run under
**both bash and zsh**.

## Global Constraints

- Files under `skill-sources/` and `platforms/shared/skill-blocks/` are TEMPLATES. Never substitute
  a concrete value for a `{vocabulary.*}` or `{config.*}` placeholder — that ships one user's
  vocabulary to every generated system.
- `skill-sources/` speaks canonical command names; the vault speaks its derived dialect. Reverse
  both transforms when porting a field fix (`reference/vocabulary-transforms.md`).
- Every gate must pass under bash AND zsh. Two defects on the predecessor branch were shell forks.
- Verify the property, not a proxy for it. A name check that passes while the capability is broken
  is worse than no check — it manufactures confidence.
- `gh` on a fork silently queries upstream. Always pass `--repo crichalchemist/arscontexta`.

---

### Task 1: Observation status vocabulary — COMPLETE (`68aea69`)

**Files:** `skills/architect`, `skill-sources/{rethink,next,stats}`,
`platforms/claude-code/hooks/session-orient.sh.template`,
`platforms/shared/skill-blocks/rethink.md`, `hooks/scripts/session-orient.sh`, `skills/health`

- [x] **Step 1:** Widen the observation matcher at 6 code sites to `'^status: pending\|^status: open'`,
      matching the tension line already beside it in each file.
- [x] **Step 2:** Widen the 4 prose contracts that stated the narrow rule (`rethink:318`, `next:64`,
      `next:127`, the shared skill-block).
- [x] **Step 3:** Filter the 2 sites that counted every file while labelling the total "pending"
      (`session-orient.sh`, `skills/health`); report open-of-total so the difference is visible.
- [x] **Step 4:** Verify against the live vault — observations 0 → 21 of 38, tensions 8 of 13,
      matching what that vault's field-fixed hook already reported.

### Task 2: `self_evolution` generator gap — COMPLETE (`15852ec`)

**Files:** `skills/setup/SKILL.md`, `skills/upgrade/SKILL.md`

- [x] **Step 1:** Emit `self_evolution:` with `observation_threshold: 10` and `tension_threshold: 5`
      in setup's `config.yaml` template — the defaults all five readers already document.
- [x] **Step 2:** Assert the section in Kernel Primitive 12 (operational-learning-loop), the
      primitive these thresholds govern, so a vault missing it FAILS validation.
- [x] **Step 3:** Add `/upgrade` §5g to seed the section into existing vaults without overwriting a
      tuned value.
- [x] **Step 4:** Record the three-way threshold disagreement (skills 10/5, plugin hook 10/5
      hardcoded, field vault 20/10) rather than averaging it.

### Task 3: `/learn` deep tier — COMPLETE (`b15f98d`)

**Files:** `skill-sources/learn/SKILL.md`, `platforms/shared/skill-blocks/learn.md`, `skills/setup/SKILL.md`

- [x] **Step 1:** Re-map `deep` onto `web_search_exa` → `web_fetch_exa` (batch `urls` array), not
      one fetch per URL.
- [x] **Step 2:** Update the provenance row to record `exa_urls`; drop `exa_research_id`/`exa_model`,
      which described a polling API that no longer exists. Drop `get_code_context`.
- [x] **Step 3:** Fix setup's research-tier probe to name tools that exist, ending the silent
      `primary: web-search` downgrade.

### Task 4: qmd `query` migration — COMPLETE (`fix/qmd-query-migration`)

**Files:** 20 files, 62 occurrences, 13 of them `allowed-tools:` declarations

- [x] **Step 1:** Verify the target schema with live calls before rewriting anything — `searches`
      array, `collections` **plural array**, `rerank` **defaults true**.
- [x] **Step 2:** Migrate `allowed-tools:` and JSON `autoapprove` lists to `mcp__qmd__query`.
- [x] **Step 3:** Rewrite invocation sites per the mapping — `search` → lex + `rerank=false`;
      `vector_search` → vec + `rerank=false`; `deep_search` → lex+vec with rerank at its default.
- [x] **Step 4:** Re-express `reference/semantic-vs-keyword.md`, whose claims were anchored to the
      old tool boundaries; state explicitly that omitting `rerank=false` reintroduces the exact LLM
      inference the description test exists to exclude.
- [x] **Step 5:** Confirm no `{vocabulary.*}` placeholder was hardcoded, by comparing placeholder
      counts against `main` file by file.

---

### Task 5: Harden Kernel Primitive 10 so this cannot recur silently — MOVED

**Superseded.** This task now lives as **Task 1** of
`docs/superpowers/plans/archive/2026-08-02-contributor-surface-and-residual-defects.md`, where Spec C owns
it alongside the rest of the residual-defect work.

Moved rather than copied. Two plans carrying the same task would drift — the identical hazard as
`skill-sources/` versus `platforms/shared/skill-blocks/`, which this repo already documents. The
canonical copy is the one linked above.

Implementation notes that only emerged during execution, recorded here so this stub is not
mistaken for "nothing happened":

- The check must scan the **live tool surface** (`.claude/`, `.agents/`, `.mcp.json`), NOT the whole
  vault. Scanning everything flagged 24 files in the field vault whose live skills declare zero dead
  names — all hits were `ops/skills-archive/` copies and changelog entries, which legitimately
  record retired names.
- It must scan `$VAULT`, not the working directory. This script validates a generated vault, not
  the plugin repo.
- `declared=$(rg … | sort -u); rc=$?` captures **`sort`'s** status, not `rg`'s. Capture rg's status
  before sorting, or the check silently loses its own error branch — the pipeline-discard defect,
  inside the check written to catch that class.

## Not in this plan

Deliberately excluded, each recorded with its reason in the spec so none reads as an oversight:
canonical `open` vs `pending` for new observations (D1); unifying the `.arscontexta` and
`ops/config.yaml` surfaces (D6); the 8 allowlisted fence defects; bounding the stale-lock retry in
`reflect`/`reweave` — where `mkdir -p` is *not* the fix, because it returns 0 when the lock exists
and destroys the mutex.
