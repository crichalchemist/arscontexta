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

**Spec:** `docs/superpowers/specs/2026-08-02-stale-contracts-and-dead-configuration-design.md`

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

### Task 5: Harden Kernel Primitive 10 so this cannot recur silently

**Files:**
- Modify: `reference/kernel.yaml` (primitive `semantic-search`, its `validation.check`)
- Modify: `reference/validate-kernel.sh`

**Interfaces:**
- Consumes: nothing from Tasks 1-4.
- Produces: a primitive-10 check that fails when qmd is present but its tools do not resolve.

**Why this task exists.** Primitive 10 currently checks that **qmd is on `PATH`**. qmd was on PATH
throughout the entire period when all 61 of its call sites named tools that had been removed. The
validator reported the primitive satisfied while semantic search was silently degrading to keyword
grep in every vault. A presence check cannot detect a surface change; only a resolution check can.

- [ ] **Step 1: Establish the control — confirm the current check passes on a broken config**

```bash
cd /Volumes/Containers/arscontexta
rg -n -A6 'id: semantic-search' reference/kernel.yaml
rg -n 'qmd' reference/validate-kernel.sh
```

Expected: the check tests for the qmd binary only. Record the exact lines — you are replacing them.

- [ ] **Step 2: Write the failing assertion first**

Add to `reference/validate-kernel.sh`, in the primitive-10 section. It must distinguish three
states, because collapsing them is what caused the defect:

```bash
# Primitive 10 has three distinct states and they must not collapse into two.
# qmd absent            -> WARN  (semantic search optional; documented in CLAUDE.md)
# qmd present, resolves -> PASS
# qmd present, does NOT -> FAIL  (the state that went undetected for 61 call sites)
if ! command -v qmd >/dev/null 2>&1; then
  warn "semantic-search: qmd not installed (optional)"
else
  # Every qmd MCP tool named anywhere in the repo must be one qmd actually exposes.
  declared=$(rg -o 'mcp__qmd__[a-z_]+' --glob '!*.diff' . | sed 's/.*://' | sort -u)
  exposed='mcp__qmd__query mcp__qmd__get mcp__qmd__multi_get mcp__qmd__status'
  unknown=""
  for t in $declared; do
    case " $exposed " in *" $t "*) ;; *) unknown="$unknown $t" ;; esac
  done
  if [ -n "$unknown" ]; then
    fail "semantic-search: repo names qmd tools that do not exist:$unknown"
  else
    pass "semantic-search: qmd present, all declared tools resolve"
  fi
fi
```

`$exposed` is a hardcoded list and that is a known cost — it must be updated when qmd's surface
changes. That is the point: the update becomes a deliberate act with a failing test attached,
instead of a silent divergence.

- [ ] **Step 3: Prove it goes red — non-vacuity**

A check never seen red is not known to work. Two verification steps on the predecessor branch were
found to be vacuous, one because a `sed` silently matched nothing.

```bash
# Reintroduce one dead name, confirm FAIL, restore, confirm PASS
perl -i -pe 's/mcp__qmd__query/mcp__qmd__deep_search/ if $. == 8' skills/ask/SKILL.md
git diff --quiet -- skills/ask/SKILL.md && { echo "MUTATION DID NOT APPLY — vacuous"; exit 9; }
./reference/validate-kernel.sh . 2>&1 | rg 'semantic-search'   # expect FAIL naming the tool
git checkout -- skills/ask/SKILL.md
./reference/validate-kernel.sh . 2>&1 | rg 'semantic-search'   # expect PASS
```

- [ ] **Step 4: Update `reference/kernel.yaml`**

Change primitive 10's `validation.check` so the YAML and the script agree. A primitive in the YAML
whose check does not exist in the script is aspirational, not enforced.

- [ ] **Step 5: Gates**

```bash
bash reference/check-portability.sh                      # exit 0
for s in bash zsh; do
  $s reference/test/link-extraction.test.sh | tail -1    # 19/19
  $s reference/test/guard-failure.test.sh   | tail -1    # 19/19
  $s reference/test/fence-isolation.test.sh | tail -1    # PASS
done
./reference/validate-kernel.sh ~/second-brain            # 15/15, WARN only where documented
```

- [ ] **Step 6: Commit**

```bash
git add reference/kernel.yaml reference/validate-kernel.sh
git commit -m "Assert qmd tool names resolve, not merely that qmd is installed

Primitive 10 checked for the qmd binary. qmd was installed throughout the
entire period when all 61 of its call sites named tools that had been
removed from the MCP surface, so the validator reported semantic search
satisfied while it silently degraded to keyword grep in every vault.

A presence check cannot detect a surface change. This asserts that every
mcp__qmd__* name the repo declares is one qmd actually exposes, and keeps
'qmd absent' (WARN) distinct from 'qmd present but broken' (FAIL).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Not in this plan

Deliberately excluded, each recorded with its reason in the spec so none reads as an oversight:
canonical `open` vs `pending` for new observations (D1); unifying the `.arscontexta` and
`ops/config.yaml` surfaces (D6); the 8 allowlisted fence defects; bounding the stale-lock retry in
`reflect`/`reweave` — where `mkdir -p` is *not* the fix, because it returns 0 when the lock exists
and destroys the mutex.
