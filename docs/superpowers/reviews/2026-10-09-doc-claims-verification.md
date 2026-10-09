# Doc-claims verification: every checkable claim in the project docs, against the tree

**Date:** 2026-10-09
**Tree:** `develop` @ `9ea6c65`, verified in a clean worktree (branch `docs/refresh-verified-claims`)
**Method:** three verification workflows (core docs; status ledgers; `reference/`, `platforms/`,
host maps and INSTALL docs). Each doc slice got one verifier that extracted every checkable claim —
counts, paths, `file:NN` pointers, commands with stated output, symbol values, behavior, status,
cross-doc pointers — and re-derived it read-only; every STALE/DANGLING finding then went to an
independent skeptic told to refute it. Findings that were applied were re-measured a third time by
the orchestrator with marker-free commands before editing. Suite totals come from a serial baseline
run of the full fence under `/opt/local/bin/bash` and zsh (all rc=0; fence gate
`files=27 fences=92 run=86 skipped=6 known-open=3` bash / `known-open=5` zsh).

**Why this file exists:** `reference/check-doc-claims.sh` pins 37 declared claims in its CLAIMS
table (plus its enum and numbering scans), and it was green at the start. Every finding below is a
claim outside that table. A green doc-claims run says nothing
about them.

**Scope excluded, with reasons:** `methodology/` (research claims, not checkable against code);
templates, fixtures and presets (not documentation); gitignored `docs/field-intel-*.md`; archived
plans, specs and reviews (dated records).

## Applied

| Unit | Commit | What |
|---|---|---|
| core docs | see `git log` | `CLAUDE.md`, `README.md`, `CONTRIBUTING.md`, `docs/verification.md`, plus the two code comments those docs defer to (`check-portability.sh` check-7 header, `queue-edit.test.sh` header) |
| install / hosts / platforms | see `git log` | `.codex-plugin`, `.opencode`, `.pi` INSTALL docs, `reference/hosts/opencode-tools.md`, `reference/skill-authoring.md`, every `platforms/**/README.md`, `platforms/claude-code/generator.md` |
| ledgers | see `git log` | number and pointer fixes in `docs/open-divergences.md`, `docs/superpowers/deferrals.md`, `docs/superpowers/next-sprints.md` — see "Ledger decisions" below |
| agent rules | see `git log` | `.claude/CLAUDE.md` created, and `GEMINI.md` imports it (see below) |

**`.claude/CLAUDE.md` now exists.** `CLAUDE.md:6` had always named it as the home of agent
execution rules, but no commit on any ref had ever created it. By owner decision it now holds the
execution rules that previously lived only in session memory: running the gates on macOS, tool
output that cannot be taken at face value, and git/PR conventions. Each rule was re-measured on
2026-10-09, but three were still wrong as first written (see "Review of these edits"). Nothing
moved out of the root `CLAUDE.md`, so `AGENTS.md`, a symlink to it, still serves Codex in full.

## Ledger decisions

The ledgers are dense with dated narrative, so every confirmed ledger finding was screened a second
time by a drafter under a stated policy, then by the orchestrator. Policy: **KEEP** anything scoped
to a date, branch, sweep or commit; **APPLY** only a runnable command's stated output, a pointer
the reader is told to follow, or an unscoped present-tense claim about the current tree; and give
an entry whose whole work item is finished a dated `**Status 2026-10-09:**` line in place. Finished
entries are not moved; that was an owner decision. 92 findings: 76 edits applied, 4 of them status
lines (divergence 15, and Sprint C, the standing decision and the 2026-08-15 decisions in
`next-sprints.md`), and these kept:

- **W2-2** (`open-divergences.md` preamble, "the class is still 7"): a sweep record. A lead from
  the drafter, not verified here: `skill-sources/stats/SKILL.md:118` still carries a capture-form
  `rg -o -r '$1' '^\s*-\s*"\[\[([^\]|#]+)'`, so divergence 13's `2 = 0 + 2` may be off by one.
- **W2-5** (divergence 3, the vault's hook and `config.yaml` "now disagree"): the two agree today
  at 10/5. The clause is the evidentiary tail of a dated reversal, and a truthful repair is a
  rewrite of that reversal, not a number swap.
- **W2-59** (deferral 12, "Why not now"): the rationale is false, because
  `check-placeholder-count.sh` scopes to `skill-sources/` only. But the entry's dated 2026-08-24
  amendment already supersedes it, and correcting it means rewriting the argument.
- **W2-28** (divergence 5's `check-prose-paths.sh` SCOPE paragraph, "warning messages a user reads at SessionStart"):
  neither hook prints a repo path in a warning today. The present tense explains why the two files
  were added to SCOPE on that branch, so it stays.
- **W2-11 and W2-14** (two doc-volatile totals) were re-measured at this branch's final state, not
  at the drafter's. Each command matches documentation, including this file.

## Review of these edits

A second pass reviewed all 125 hunks of the four commits above against a frozen snapshot of the
branch tip: one reviewer per commit, then an independent skeptic who tried to refute each finding
by re-measuring it. It raised 28 findings. 12 were upheld (7 false claims, 5 layout defects), 1
was refuted, and 15 were notes; all 12 and 9 of the notes were fixed in a follow-up commit. The
false claims were introduced or re-asserted by this pass itself:

- `docs/verification.md` said a CI step for `check-doc-claims.test.sh` would move a gated count
  "that compares against `main` and rots on merge". No gated count does: the main-side row was
  removed for exactly that rot. The same clause in the `docs/open-divergences.md` preamble was
  fixed with it.
- `platforms/claude-code/generator.md` said a vault's skills never read the plugin directory at
  runtime. The `refactor` template does (`${CLAUDE_PLUGIN_ROOT}/reference/`).
- `.claude/CLAUDE.md` had three rules that came from session memory and were not re-measured:
  - Four scripts fail to parse under bash 3.2, not three: `validate-kernel.sh` was missing.
  - The failing construct is a `case … ;;` inside `$(…)`, not a one-line `case`.
  - `gh` on this clone resolves to `origin` (`remote.origin.gh-resolved=base`), not `upstream`.
- Divergence 15's re-pointed `schema.md:142` contradicted the entry's own dated amendment, which
  quotes `:137`. It is now annotated, and the same sentence's `self-evolution.md:195`, already
  blank at the base, is re-pointed to `:226`. In `next-sprints.md`, the Sprint C coverage
  sentence overstated where entries 5–7 appear.

The six notes left unfixed were judged harmless or need a decision (the features Layer column).
The reviewers also listed 29 items they could not check read-only: external host behaviour, and
historical figures inside dated records.

## Judgment items — not edited, need an owner
- **Setup takes "~20 minutes" (`README.md:33`, `:112`) or "about 5 minutes"
  (`skills/setup/SKILL.md:136`).** Both figures are estimates and both date from the initial
  release (`4be327e`), so neither has drifted. They simply disagree.
- **Codex "has never been run at all" (`README.md:59-60`).** `.codex-plugin/INSTALL.md:39-42`
  records that the install mechanics were measured on `codex-cli 0.146.0` (`244ea41`, 2026-08-17).
  It also records that whether Codex's agent then discovers the skills was not measured. The README
  sentence was written a day later (`d2727f7`) and likely means the second. As worded, it reads as
  the first.
- **The three host tool maps omit `mcp__qmd__*`.** 5 of 10 `skills/` declare qmd MCP tools in
  `allowed-tools:`. No map row covers them. Two skeptics ruled this an omission rather than a false
  claim, because no map claims to be exhaustive. One skeptic disagreed. Adding a row is new content,
  not a refresh.

## Flags — real drift outside the doc scope (code comments and templates)

- **The GNU `stat -f %m` "succeeds / exits 0" wording.** Measured on `gstat` 9.12, it exits 1 after
  printing the filesystem block. `CONTRIBUTING.md` is fixed; the same wording remains in
  `hooks/scripts/session-orient.sh:360`, `skill-sources/next/SKILL.md:275`,
  `skill-sources/rethink/SKILL.md:90` and `skills/health/SKILL.md:561`. Template edits need a
  plugin reinstall and a fence-gate run, so they belong in their own change.
- **`.claude-plugin/marketplace.json` describes `methodology/` as 249 research claims.** It holds
  213 research claims among 249 notes. Fixing it is a manifest edit, not a doc edit.
- **`platforms/shared/features/README.md` had no source for the "Layer" column.** The new
  `methodology-knowledge.md` row says `not declared` rather than inventing a layer.

## Deferred A — plugin knowledge-base docs (105 findings, not applied)

These files are read by `skills/` at run time (`/setup`, `/ask`, `/architect`, `/reseed` …), so an edit changes what the plugin tells users and what it generates. Many need authoring, not a number swap — e.g. moving a worked example from "15/15 PASS" to 16 primitives asserts an outcome nobody has measured. Each finding below survived one verifier and one adversarial skeptic; **none was re-measured by the orchestrator** — re-derive before acting.

### `reference/claim-map.md` (10)

- **W4-50** `reference/claim-map.md:9` (count, STALE)
  - claim: Entry point to all research. Six topic areas within the knowledge-work domain.
  - stated: Six topic areas
  - measured: 7 Research Areas listed in methodology/index.md (graph-structure, agent-cognition, discovery-retrieval, processing-workflows, note-design, maintenance-patterns, design-dimensions)
  - suggested: Entry point to all research. Seven research areas in the hub; this map covers six of them (design-dimensions is mapped in dimension-claim-map.md).
  - re-derive:

    ```text
    sed -n '10,19p' methodology/index.md | /usr/bin/grep -c '^- \[\['
    ```

- **W4-51** `reference/claim-map.md:16` (path, DANGLING)
  - claim: | processing-workflow | Throughput, sessions, handoffs, pipeline |
  - stated: processing-workflow
  - measured: methodology/processing-workflows.md (plural); no processing-workflow.md
  - suggested: processing-workflows
  - re-derive:

    ```text
    git -c core.quotePath=false ls-files methodology | /usr/bin/grep -E '/processing-workflow'
    ```

- **W4-52** `reference/claim-map.md:18` (path, DANGLING)
  - claim: | maintenance-evolution | Reweaving, gardening, health over time |
  - stated: maintenance-evolution
  - measured: methodology/maintenance-patterns.md only; no maintenance-evolution.md anywhere in the tree
  - suggested: maintenance-patterns
  - re-derive:

    ```text
    git -c core.quotePath=false ls-files methodology | /usr/bin/grep -E 'maintenance'
    ```

- **W4-53** `reference/claim-map.md:89` (path, DANGLING)
  - claim: ## processing-workflow
  - stated: processing-workflow
  - measured: No such file; hub is methodology/processing-workflows.md
  - suggested: ## processing-workflows
  - re-derive:

    ```text
    ls methodology/processing-workflow.md
    ```

- **W4-54** `reference/claim-map.md:139` (path, DANGLING)
  - claim: ## maintenance-evolution
  - stated: maintenance-evolution
  - measured: No such file; nearest hub is methodology/maintenance-patterns.md
  - suggested: ## maintenance-patterns
  - re-derive:

    ```text
    ls methodology/maintenance-evolution.md
    ```

- **W4-55** `reference/claim-map.md:166` (cross-doc, DANGLING)
  - claim: | ... | agent-cognition, processing-workflow |  (Topics column of the Cross-Topic Bridge table)
  - stated: processing-workflow, maintenance-evolution
  - measured: lines 166, 167, 170, 171, 172 name topics processing-workflow and/or maintenance-evolution; neither exists as a methodology/ hub (see lines 16/18)
  - suggested: processing-workflows, maintenance-patterns on lines 166, 167, 170, 171, 172 (edit with lines 16, 18, 89, 139 in one pass)
  - re-derive:

    ```text
    /usr/bin/grep -nE 'processing-workflow|maintenance-evolution' reference/claim-map.md
    ```

- **W4-56** `reference/claim-map.md:167` (path, DANGLING)
  - claim: [[fresh context per task preserves quality]]
  - stated: fresh context per task preserves quality
  - measured: 0 exact; file is 'fresh context per task preserves quality better than chaining phases.md'
  - suggested: [[fresh context per task preserves quality better than chaining phases]]
  - re-derive:

    ```text
    /usr/bin/grep -cxF 'fresh context per task preserves quality' <(git -c core.quotePath=false ls-files methodology | sed -e 's#^methodology/##' -e 's#\.md$##')
    ```

- **W4-57** `reference/claim-map.md:168` (path, DANGLING)
  - claim: [[inline links carry richer relationship data]]
  - stated: inline links carry richer relationship data
  - measured: No such file; exists as 'inline links carry richer relationship data than metadata fields.md'
  - suggested: [[inline links carry richer relationship data than metadata fields]]
  - re-derive:

    ```text
    ls 'methodology/inline links carry richer relationship data.md'
    ```

- **W4-58** `reference/claim-map.md:169` (path, DANGLING)
  - claim: [[faceted classification treats notes as multi-dimensional objects]]
  - stated: faceted classification treats notes as multi-dimensional objects
  - measured: No such file; exists as '... rather than folder contents.md'
  - suggested: [[faceted classification treats notes as multi-dimensional objects rather than folder contents]]
  - re-derive:

    ```text
    ls 'methodology/faceted classification treats notes as multi-dimensional objects.md'
    ```

- **W4-59** `reference/claim-map.md:172` (path, DANGLING)
  - claim: [[skills encode methodology]]
  - stated: skills encode methodology
  - measured: No such file; exists as 'skills encode methodology so manual execution bypasses quality gates.md'
  - suggested: [[skills encode methodology so manual execution bypasses quality gates]]
  - re-derive:

    ```text
    ls 'methodology/skills encode methodology.md'
    ```

### `reference/conversation-patterns.md` (10)

- **W4-130** `reference/conversation-patterns.md:66` (path, DANGLING)
  - claim: `light-processing.md` — included (processing = light)
  - stated: a feature block file `light-processing.md` exists and is included
  - measured: No such file or directory, rc=1; control processing-pipeline.md present; 17 blocks in generators/features/; git log for the path is empty (never existed in history)
  - suggested: Delete the line.
  - re-derive:

    ```text
    ls generators/features/light-processing.md; printf 'rc=%s\n' "$?"; ls generators/features/processing-pipeline.md; ls generators/features/*.md | awk 'END{print NR}'; git log --format='%h %ad %s' --date=short -- generators/features/light-processing.md
    ```

- **W4-135** `reference/conversation-patterns.md:75` (behavior, STALE)
  - claim: `processing-pipeline.md` — excluded (processing = light)
  - stated: the processing-pipeline block is excluded when processing = light
  - measured: generators/claude-md.md:159 = "4. processing-pipeline (always — full automation from day one)"; presets/personal/preset.yaml lines 18-19 list processing-pipeline and schema under blocks.always
  - suggested: Move the line to the pattern's Active Feature Blocks list as: - `processing-pipeline.md` — included (always; light processing sets the pipeline depth in ops/config.yaml, it does not drop the block)
  - re-derive:

    ```text
    sed -n '159p' generators/claude-md.md; /usr/bin/grep -n -E 'processing-pipeline|schema' presets/personal/preset.yaml
    ```

- **W4-137** `reference/conversation-patterns.md:77` (behavior, STALE)
  - claim: `schema.md` — excluded (schema = minimal)
  - stated: the schema block is excluded when schema density is minimal
  - measured: generators/claude-md.md:161 = "6. schema (always — schema enforcement is an invariant)"; schema appears under blocks.always in all three preset.yaml files
  - suggested: Move the line to the pattern's Active Feature Blocks list as: - `schema.md` — included (always; schema = minimal)
  - re-derive:

    ```text
    sed -n '161p' generators/claude-md.md; /usr/bin/grep -n -E '^\s+- schema' presets/*/preset.yaml
    ```

- **W4-131** `reference/conversation-patterns.md:158` (path, DANGLING)
  - claim: `light-processing.md` — included (processing = light)
  - stated: feature block `light-processing.md` exists and is included
  - measured: No such file or directory, rc=1
  - suggested: Delete the line.
  - re-derive:

    ```text
    ls generators/features/light-processing.md; printf 'rc=%s\n' "$?"
    ```

- **W4-136** `reference/conversation-patterns.md:168` (behavior, STALE)
  - claim: `processing-pipeline.md` — excluded (processing = light)
  - stated: the processing-pipeline block is excluded when processing = light
  - measured: generators/claude-md.md:159 = "processing-pipeline (always — full automation from day one)"; presets/personal/preset.yaml:18 lists it under always
  - suggested: Move the line to the pattern's Active Feature Blocks list as: - `processing-pipeline.md` — included (always; light processing sets the pipeline depth in ops/config.yaml, it does not drop the block)
  - re-derive:

    ```text
    sed -n '159p' generators/claude-md.md; /usr/bin/grep -n -E 'processing-pipeline' presets/personal/preset.yaml
    ```

- **W4-138** `reference/conversation-patterns.md:170` (behavior, STALE)
  - claim: `schema.md` — excluded (moderate schema is handled by template, not a dedicated feature block)
  - stated: schema block excluded; moderate schema handled by template only
  - measured: generators/claude-md.md:161 = "schema (always — schema enforcement is an invariant)"; presets/personal/preset.yaml:19 lists schema under always
  - suggested: Move the line to the pattern's Active Feature Blocks list as: - `schema.md` — included (always; schema = moderate)
  - re-derive:

    ```text
    sed -n '161p' generators/claude-md.md; /usr/bin/grep -n -E '^\s+- schema' presets/personal/preset.yaml
    ```

- **W4-132** `reference/conversation-patterns.md:251` (path, DANGLING)
  - claim: `light-processing.md` — excluded (processing = heavy)
  - stated: feature block `light-processing.md` exists (and is excluded here)
  - measured: No such file or directory, rc=1
  - suggested: Delete the line.
  - re-derive:

    ```text
    ls generators/features/light-processing.md; printf 'rc=%s\n' "$?"
    ```

- **W4-133** `reference/conversation-patterns.md:355` (path, DANGLING)
  - claim: `light-processing.md` — excluded (processing = moderate)
  - stated: feature block `light-processing.md` exists (and is excluded here)
  - measured: No such file or directory, rc=1
  - suggested: Delete the line.
  - re-derive:

    ```text
    ls generators/features/light-processing.md; printf 'rc=%s\n' "$?"
    ```

- **W4-139** `reference/conversation-patterns.md:357` (behavior, STALE)
  - claim: `schema.md` — excluded (moderate schema handled by template)
  - stated: schema block excluded for the therapy pattern
  - measured: generators/claude-md.md:161 = "schema (always — schema enforcement is an invariant)"; presets/personal/preset.yaml:19 lists schema under always
  - suggested: Move the line to the pattern's Active Feature Blocks list as: - `schema.md` — included (always; schema = moderate)
  - re-derive:

    ```text
    sed -n '161p' generators/claude-md.md; /usr/bin/grep -n -E '^\s+- schema' presets/personal/preset.yaml
    ```

- **W4-134** `reference/conversation-patterns.md:443` (path, DANGLING)
  - claim: `light-processing.md` — excluded (processing = moderate)
  - stated: feature block `light-processing.md` exists (and is excluded here)
  - measured: No such file or directory, rc=1
  - suggested: Delete the line.
  - re-derive:

    ```text
    ls generators/features/light-processing.md; printf 'rc=%s\n' "$?"
    ```

### `reference/derivation-validation.md` (25)

- **W4-102** `reference/derivation-validation.md:3` (path, DANGLING)
  - claim: Run these after any changes to init.md, interaction-constraints.md, or tradition-presets.md.
  - stated: init.md exists alongside interaction-constraints.md and tradition-presets.md
  - measured: init.md: 0 tracked now, 0 in the v0.8.0 initial release (control: tradition-presets.md = 1); the derivation conversation lives at skills/setup/SKILL.md
  - suggested: Run these after any changes to skills/setup/SKILL.md, reference/interaction-constraints.md, or reference/tradition-presets.md.
  - re-derive:

    ```text
    git -c core.quotePath=false ls-files | /usr/bin/grep -c 'init\.md$'; git ls-tree -r --name-only 4be327e | /usr/bin/grep -c 'init\.md$'; git ls-tree -r --name-only 4be327e | /usr/bin/grep -c 'tradition-presets.md'  # positive control
    ```

- **W4-104** `reference/derivation-validation.md:32` (count, STALE)
  - claim: Kernel (all 15 primitives): YES — vault has all 15
  - stated: 15
  - measured: 16 primitive ids in kernel.yaml (unique-addresses is the 16th); validate-kernel.sh header: 'not the primitive count, which is 16'
  - suggested: Kernel (all 16 primitives): YES — vault has all 16 (self space disabled by default for research, but primitive still passes as CONFIGURABLE)
  - re-derive:

    ```text
    /usr/bin/grep -cE '^  - id: ' reference/kernel.yaml; sed -n '4,7p' reference/validate-kernel.sh
    ```

- **W4-105** `reference/derivation-validation.md:33` (symbol, DANGLING)
  - claim: inbox-processing: YES (processing = heavy ≥ moderate)
  - stated: a feature named inbox-processing
  - measured: 17 feature blocks, none named inbox-processing; 0 references anywhere else in the repo (control: processing-pipeline = 1); inbox handling is inside processing-pipeline.md / maintenance.md / session-rhythm.md
  - suggested: Delete line 33 and change line 34 to: '- processing-pipeline: YES (processing = heavy) — vault has 00_inbox/, /ralph, /pipeline, full 6R pipeline'
  - re-derive:

    ```text
    ls generators/features/; /usr/bin/grep -rnE 'inbox-processing' reference generators skills skill-sources presets hooks docs CLAUDE.md README.md | /usr/bin/grep -v derivation-validation; /usr/bin/grep -rlE 'processing-pipeline' generators | awk 'END{print NR}'  # positive control
    ```

- **W4-106** `reference/derivation-validation.md:36` (symbol, DANGLING)
  - claim: hooks-blueprint: YES (automation ≥ convention)
  - stated: a feature named hooks-blueprint
  - measured: 0 feature blocks named hooks-blueprint; the only other mention is prose in reference/tradition-presets.md:183 (same legacy name); hooks are generated by processing-pipeline.md (the only block referencing hooks.json/PostToolUse)
  - suggested: - Self-extension blueprints (Building Hooks; generators/claude-md.md, always included; runtime hooks via hooks/hooks.json): YES — vault has .claude/hooks/ with 10+ hooks
  - re-derive:

    ```text
    ls generators/features/ | /usr/bin/grep -c hooks-blueprint; /usr/bin/grep -rnE 'hooks-blueprint' reference generators skills skill-sources presets hooks docs | /usr/bin/grep -v derivation-validation
    ```

- **W4-107** `reference/derivation-validation.md:37` (symbol, DANGLING)
  - claim: validation-hooks: PARTIAL — vault has PostToolUse validation hooks
  - stated: a feature named validation-hooks
  - measured: 0 feature blocks named validation-hooks; the validation hook is described in generators/features/self-evolution.md and shipped as hooks/scripts/write-validate.sh
  - suggested: - PostToolUse write-validate hook (hooks/hooks.json → hooks/scripts/write-validate.sh): YES — vault has PostToolUse validation hooks (automation trending beyond convention)
  - re-derive:

    ```text
    ls generators/features/ | /usr/bin/grep -c validation-hooks; /usr/bin/grep -liE 'write-validate|validation hook' generators/features/*.md
    ```

- **W4-108** `reference/derivation-validation.md:83` (cross-doc, STALE)
  - claim: | reduce | process |  (Research → Therapy vocabulary mapping)
  - stated: reduce → process
  - measured: vocabulary-transforms.md: 'extract / reduce' → Therapy 'surface'; '/reduce' → '/surface'. This file's own Test 7 (line 400) also says reduce → surface
  - suggested: | reduce | surface |
  - re-derive:

    ```text
    sed -n '14p' reference/vocabulary-transforms.md; sed -n '63p' reference/vocabulary-transforms.md
    ```

- **W4-109** `reference/derivation-validation.md:84` (cross-doc, STALE)
  - claim: | inbox | captures |  (Research → Therapy vocabulary mapping)
  - stated: inbox → captures
  - measured: vocabulary-transforms.md: 'inbox' → Therapy 'journaling'; folder 'inbox/' → 'journal/'. This file's Test 7 (line 404) says inbox → journal
  - suggested: | inbox | journal |
  - re-derive:

    ```text
    sed -n '21p' reference/vocabulary-transforms.md; sed -n '54p' reference/vocabulary-transforms.md
    ```

- **W4-110** `reference/derivation-validation.md:123` (count, STALE)
  - claim: Kernel validation prediction: 15/15 PASS (or 14 PASS + 1 WARN on semantic search if not configured)
  - stated: 15/15
  - measured: 16 primitives; validate-kernel.sh has 16 header sections (1-15 plus 10A) and its summary counts result lines, not primitives — it deliberately prints no 'N/N' figure
  - suggested: **Kernel validation prediction:** 16/16 PASS (or 15 PASS + 1 WARN on semantic search if not configured)
  - re-derive:

    ```text
    /usr/bin/grep -cE '^  - id: ' reference/kernel.yaml; /usr/bin/grep -nE '^# --- Primitive' reference/validate-kernel.sh | awk 'END{print NR}'; sed -n '1128,1134p' reference/validate-kernel.sh
    ```

- **W4-111** `reference/derivation-validation.md:205` (count, STALE)
  - claim: Kernel validation prediction: 15/15 PASS (assuming semantic search is configured)
  - stated: 15/15
  - measured: 16
  - suggested: **Kernel validation prediction:** 16/16 PASS (assuming semantic search is configured)
  - re-derive:

    ```text
    /usr/bin/grep -cE '^  - id: ' reference/kernel.yaml
    ```

- **W4-112** `reference/derivation-validation.md:255` (count, STALE)
  - claim: Kernel validation prediction: 15/15 PASS
  - stated: 15/15
  - measured: 16
  - suggested: **Kernel validation prediction:** 16/16 PASS
  - re-derive:

    ```text
    /usr/bin/grep -cE '^  - id: ' reference/kernel.yaml
    ```

- **W4-113** `reference/derivation-validation.md:257` (cross-doc, DANGLING)
  - claim: The five composition rules (from the composable-knowledge-architecture blueprint) hold
  - stated: a 'composable-knowledge-architecture blueprint' that states five composition rules
  - measured: 0 files named composable-knowledge-architecture; nearest is methodology/'composable knowledge architecture builds systems from independent toggleable modules not monolithic templates.md', which contains 'five' 0 times and enumerates no composition rules
  - suggested: The five composition rules hold: (delete '(from the composable-knowledge-architecture blueprint)'; do not point at either methodology note — one has no rules, the other states a different five)
  - re-derive:

    ```text
    git -c core.quotePath=false ls-files | /usr/bin/grep -c 'composable-knowledge-architecture'; /usr/bin/grep -rli composable methodology | head -3; /usr/bin/grep -c 'five' 'methodology/composable knowledge architecture builds systems from independent toggleable modules not monolithic templates.md'
    ```

- **W4-114** `reference/derivation-validation.md:268` (count, STALE)
  - claim: Can all 15 kernel primitives be satisfied on a platform with no hooks...
  - stated: 15
  - measured: 16
  - suggested: **Question:** Can all 16 kernel primitives be satisfied on a platform with no hooks, no skills, and no subagent support — using only a context file and filesystem access?
  - re-derive:

    ```text
    /usr/bin/grep -cE '^  - id: ' reference/kernel.yaml
    ```

- **W4-115** `reference/derivation-validation.md:285` (count, STALE)
  - claim: Kernel primitive mapping table rows 1-15 (lines 285-306): 15 rows; row 8 Semantic search, 9 Self space, 10 Session rhythm
  - stated: 15 primitives, with semantic search at 8, self space at 9, session rhythm at 10, and no unique-addresses row
  - measured: kernel.yaml order: 8 self-space, 9 session-rhythm, 10 semantic-search, 11 unique-addresses; validate-kernel.sh headers: 8 Self space, 9 Session rhythm, 10 Semantic search, 10A Filesystem graph database (unique-addresses). The table omits unique-addresses entirely and swaps rows 8-10
  - suggested: Append one row after row 15 (no reordering): '| 16 | Filesystem graph database (unique-addresses) | Context file instructs agent to treat notes as graph nodes and wiki links as edges, answering backlink/orphan queries with grep in place of ops/scripts/graph/ | YES (degraded) |'
  - re-derive:

    ```text
    /usr/bin/grep -nE '^  - id: ' reference/kernel.yaml | sed -n '8,11p'; /usr/bin/grep -nE '^# --- Primitive (8|9|10|10A):' reference/validate-kernel.sh
    ```

- **W4-116** `reference/derivation-validation.md:308` (count, STALE)
  - claim: Result: 15/15 PASS. Every kernel primitive has a viable convention-only implementation.
  - stated: 15/15
  - measured: 16 (the table above it covers 15 and never maps unique-addresses)
  - suggested: **Result: 16/16 PASS.** Every kernel primitive has a viable convention-only implementation.
  - re-derive:

    ```text
    /usr/bin/grep -cE '^  - id: ' reference/kernel.yaml
    ```

- **W4-117** `reference/derivation-validation.md:323` (count, STALE)
  - claim: Kernel validation prediction: 15/15
  - stated: 15/15
  - measured: 16
  - suggested: **Kernel validation prediction:** 16/16
  - re-derive:

    ```text
    /usr/bin/grep -cE '^  - id: ' reference/kernel.yaml
    ```

- **W4-118** `reference/derivation-validation.md:378` (count, STALE)
  - claim: Kernel validation prediction: 15/15 (corrected configuration satisfies all primitives)
  - stated: 15/15
  - measured: 16
  - suggested: **Kernel validation prediction:** 16/16 (corrected configuration satisfies all primitives)
  - re-derive:

    ```text
    /usr/bin/grep -cE '^  - id: ' reference/kernel.yaml
    ```

- **W4-119** `reference/derivation-validation.md:437` (count, STALE)
  - claim: Kernel validation prediction: 15/15
  - stated: 15/15
  - measured: 16
  - suggested: **Kernel validation prediction:** 16/16
  - re-derive:

    ```text
    /usr/bin/grep -cE '^  - id: ' reference/kernel.yaml
    ```

- **W4-121** `reference/derivation-validation.md:483` (count, STALE)
  - claim: Kernel validation prediction: 15/15 at all growth stages
  - stated: 15/15
  - measured: 16
  - suggested: **Kernel validation prediction:** 16/16 at all growth stages
  - re-derive:

    ```text
    /usr/bin/grep -cE '^  - id: ' reference/kernel.yaml
    ```

- **W4-122** `reference/derivation-validation.md:551` (behavior, STALE)
  - claim: Session-start orientation surfaces the suggestion: "12 pending observations and 6 pending tensions exceed review thresholds. Consider running /rethink."
  - stated: a single combined sentence with different wording
  - measured: session-orient.sh emits two separate lines: 'CONDITION: $OBS_COUNT pending observations (of $OBS_TOTAL total). Consider /rethink.' and 'CONDITION: $TENS_COUNT unresolved tensions (of $TENS_TOTAL total). Consider /rethink.' (thresholds default 10 and 5, read from self_evolution.*)
  - suggested: **Expected behavior:** Session-start orientation surfaces two CONDITION lines: "CONDITION: 12 pending observations (of N total). Consider /rethink." and "CONDITION: 6 unresolved tensions (of N total). Consider /rethink."
  - re-derive:

    ```text
    sed -n '261,271p' hooks/scripts/session-orient.sh
    ```

- **W4-123** `reference/derivation-validation.md:555` (behavior, STALE)
  - claim: Each pending observation receives one of four dispositions: Promote / Implement / Archive / Keep pending
  - stated: four dispositions
  - measured: /rethink's disposition table has six rows: PROMOTE, IMPLEMENT, METHODOLOGY, ARCHIVE, BLOCKED (tensions only), KEEP PENDING — five apply to observations
  - suggested: Each pending observation receives one of five dispositions (Promote, Implement, Methodology, Archive, Keep pending; tensions add Blocked): — and add a table row '| Methodology | Friction pattern that should change how the agent operates | `implemented` | Create or update a note in ops/methodology/, link back to observation |'
  - re-derive:

    ```text
    sed -n '231,236p' skill-sources/rethink/SKILL.md | cut -c1-40
    ```

- **W4-124** `reference/derivation-validation.md:613` (count, STALE)
  - claim: Kernel validation prediction: 15/15
  - stated: 15/15
  - measured: 16
  - suggested: **Kernel validation prediction:** 16/16
  - re-derive:

    ```text
    /usr/bin/grep -cE '^  - id: ' reference/kernel.yaml
    ```

- **W4-125** `reference/derivation-validation.md:615` (behavior, STALE)
  - claim: the four-disposition triage model (promote, implement, archive, keep) provides clear action paths for every observation
  - stated: four dispositions
  - measured: 6 disposition rows in /rethink (METHODOLOGY and BLOCKED added)
  - suggested: the six-disposition triage model (promote, implement, methodology, archive, blocked, keep) provides clear action paths for every observation and tension
  - re-derive:

    ```text
    /usr/bin/grep -cE '^\| (PROMOTE|IMPLEMENT|METHODOLOGY|ARCHIVE|BLOCKED|KEEP PENDING) \|' skill-sources/rethink/SKILL.md
    ```

- **W4-126** `reference/derivation-validation.md:623` (count, STALE)
  - claim: Overall Validation Summary table, 'Kernel Passes' column (lines 623-631): 15/15 on eight rows, 14-15/15 on the Therapy row
  - stated: 15/15 (and 14-15/15)
  - measured: 16 primitives; '15/15' appears on 17 lines of this file, 9 of them in this table
  - suggested: Replace every '15/15' in the Kernel Passes column with '16/16' and '14-15/15' (line 624) with '15-16/16'
  - re-derive:

    ```text
    /usr/bin/grep -cE '^  - id: ' reference/kernel.yaml; /usr/bin/grep -c '15/15' reference/derivation-validation.md
    ```

- **W4-127** `reference/derivation-validation.md:643` (count, STALE)
  - claim: The minimal platform test (Test 5) proves that all 15 primitives can be satisfied through context file instructions alone.
  - stated: 15
  - measured: 16
  - suggested: The minimal platform test (Test 5) proves that all 16 primitives can be satisfied through context file instructions alone.
  - re-derive:

    ```text
    /usr/bin/grep -cE '^  - id: ' reference/kernel.yaml
    ```

- **W4-128** `reference/derivation-validation.md:649` (count, STALE)
  - claim: The 15 kernel primitives provide a universal base.
  - stated: 15
  - measured: 16
  - suggested: The 16 kernel primitives provide a universal base.
  - re-derive:

    ```text
    /usr/bin/grep -cE '^  - id: ' reference/kernel.yaml
    ```

### `reference/dimension-claim-map.md` (11)

- **W4-60** `reference/dimension-claim-map.md:23` (path, DANGLING)
  - claim: | associative ontologies beat hierarchical taxonomies | ...
  - stated: associative ontologies beat hierarchical taxonomies
  - measured: 0 exact; prefix of 'associative ontologies beat hierarchical taxonomies because heterarchy adapts while hierarchy brittles.md'
  - suggested: associative ontologies beat hierarchical taxonomies because heterarchy adapts while hierarchy brittles
  - re-derive:

    ```text
    /usr/bin/grep -cxF 'associative ontologies beat hierarchical taxonomies' <(git -c core.quotePath=false ls-files methodology | sed -e 's#^methodology/##' -e 's#\.md$##')
    ```

- **W4-61** `reference/dimension-claim-map.md:25` (path, DANGLING)
  - claim: | navigational vertigo emerges in pure association systems | ...
  - stated: navigational vertigo emerges in pure association systems
  - measured: No such file; exists as '... without local hierarchy.md'
  - suggested: navigational vertigo emerges in pure association systems without local hierarchy
  - re-derive:

    ```text
    ls 'methodology/navigational vertigo emerges in pure association systems.md'
    ```

- **W4-62** `reference/dimension-claim-map.md:26` (path, DANGLING)
  - claim: | faceted classification treats notes as multi-dimensional objects | ...
  - stated: faceted classification treats notes as multi-dimensional objects
  - measured: No such file; exists as '... rather than folder contents.md'
  - suggested: faceted classification treats notes as multi-dimensional objects rather than folder contents
  - re-derive:

    ```text
    ls 'methodology/faceted classification treats notes as multi-dimensional objects.md'
    ```

- **W4-63** `reference/dimension-claim-map.md:38` (path, DANGLING)
  - claim: | concept-orientation beats source-orientation | ...
  - stated: concept-orientation beats source-orientation
  - measured: No such file; exists as '... for cross-domain connections.md'
  - suggested: concept-orientation beats source-orientation for cross-domain connections
  - re-derive:

    ```text
    ls 'methodology/concept-orientation beats source-orientation.md'
    ```

- **W4-64** `reference/dimension-claim-map.md:39` (path, DANGLING)
  - claim: | controlled disorder engineers serendipity through semantic linking | ...
  - stated: controlled disorder engineers serendipity through semantic linking
  - measured: Only 'controlled disorder engineers serendipity through semantic rather than topical linking.md'; the cited wording is not a prefix of it
  - suggested: controlled disorder engineers serendipity through semantic rather than topical linking
  - re-derive:

    ```text
    /usr/bin/grep -iE 'controlled disorder' <(git -c core.quotePath=false ls-files methodology)
    ```

- **W4-65** `reference/dimension-claim-map.md:53` (path, DANGLING)
  - claim: | every knowledge domain shares a four-phase processing skeleton | ...
  - stated: every knowledge domain shares a four-phase processing skeleton
  - measured: No such file; exists as '... that diverges only in the process step.md'
  - suggested: every knowledge domain shares a four-phase processing skeleton that diverges only in the process step
  - re-derive:

    ```text
    ls 'methodology/every knowledge domain shares a four-phase processing skeleton.md'
    ```

- **W4-66** `reference/dimension-claim-map.md:79` (path, DANGLING)
  - claim: | incremental formalization happens through repeated touching | ...
  - stated: incremental formalization happens through repeated touching
  - measured: No such file; exists as '... of old notes.md'
  - suggested: incremental formalization happens through repeated touching of old notes
  - re-derive:

    ```text
    ls 'methodology/incremental formalization happens through repeated touching.md'
    ```

- **W4-67** `reference/dimension-claim-map.md:109` (path, DANGLING)
  - claim: | four abstraction layers separate platform-agnostic from platform-dependent | ...
  - stated: four abstraction layers separate platform-agnostic from platform-dependent
  - measured: No such file; exists as '... knowledge system features.md'
  - suggested: four abstraction layers separate platform-agnostic from platform-dependent knowledge system features
  - re-derive:

    ```text
    ls 'methodology/four abstraction layers separate platform-agnostic from platform-dependent.md'
    ```

- **W4-68** `reference/dimension-claim-map.md:111` (path, DANGLING)
  - claim: | methodology development should follow documentation to skill to hook | ...
  - stated: methodology development should follow documentation to skill to hook
  - measured: Only 'methodology development should follow the trajectory from documentation to skill to hook as understanding hardens.md'; cited wording is not a prefix
  - suggested: methodology development should follow the trajectory from documentation to skill to hook as understanding hardens
  - re-derive:

    ```text
    /usr/bin/grep -iE 'documentation.*skill.*hook' <(git -c core.quotePath=false ls-files methodology)
    ```

- **W4-69** `reference/dimension-claim-map.md:122` (path, DANGLING)
  - claim: | Granularity → Linking | configuration dimensions interact | ...  (Claim column, lines 122-126)
  - stated: configuration dimensions interact
  - measured: No such file; exists as 'configuration dimensions interact so choices in one create pressure on others.md' — same abbreviation on lines 122, 123, 124, 125, 126
  - suggested: configuration dimensions interact so choices in one create pressure on others (lines 122, 123, 124, 125, 126)
  - re-derive:

    ```text
    ls 'methodology/configuration dimensions interact.md'
    ```

- **W4-70** `reference/dimension-claim-map.md:127` (path, DANGLING)
  - claim: | Volume → Navigation | small-world topology requires hubs | ...
  - stated: small-world topology requires hubs
  - measured: No such file; exists as 'small-world topology requires hubs and dense local links.md'
  - suggested: small-world topology requires hubs and dense local links
  - re-derive:

    ```text
    ls 'methodology/small-world topology requires hubs.md'
    ```

### `reference/evolution-lifecycle.md` (9)

- **W4-148** `reference/evolution-lifecycle.md:74` (behavior, STALE)
  - claim: Full automation is the default — PostToolUse hooks log friction automatically
  - stated: PostToolUse hooks log friction automatically
  - measured: write-validate=0 auto-commit=0 orient=14 (positive control). The only PostToolUse hooks (hooks/hooks.json, and the four generated scripts named at skills/setup/SKILL.md:1456) are write-validate.sh/validate-note.sh and auto-commit.sh; neither logs friction. Friction is captured by the Stop hook (session-capture.sh.template) and counted by the SessionStart hook.
  - suggested: Full automation is the default — the stop hook captures session transcripts automatically, and session-start hooks check pending observation counts against thresholds
  - re-derive:

    ```text
    cd /Volumes/Containers/arscontexta/.claude/worktrees/docs-refresh && printf 'write-validate=%s auto-commit=%s orient=%s\n' "$(/usr/bin/grep -ci 'friction\|observation' hooks/scripts/write-validate.sh)" "$(/usr/bin/grep -ci 'friction\|observation' hooks/scripts/auto-commit.sh)" "$(/usr/bin/grep -ci 'observation' hooks/scripts/session-orient.sh)"; /usr/bin/grep -n '"PostToolUse"' -A 12 hooks/hooks.json | /usr/bin/grep command
    ```

- **W4-146** `reference/evolution-lifecycle.md:150` (behavior, STALE)
  - claim: /architect allows users to toggle optional features (semantic search, self space) without regenerating
  - stated: /architect toggles optional features
  - measured: [toggle] 0, [disable] 0, [self_space] 0, [self space] 2 (positive control: line 89 feature table, line 321 '4d. Self Space' which only READS self/ for friction evidence). skills/architect/SKILL.md has no enable/disable/toggle path; its only write path is 'On User Approval' (line 537) implementing a proposed recommendation.
  - suggested: Optional features can be changed through an /architect recommendation the user approves; no dedicated toggle command ships in skills/architect/SKILL.md
  - re-derive:

    ```text
    cd /Volumes/Containers/arscontexta/.claude/worktrees/docs-refresh && for w in toggle disable self_space 'self space'; do printf '[%s] %s\n' "$w" "$(/usr/bin/grep -ci "$w" skills/architect/SKILL.md)"; done
    ```

- **W4-147** `reference/evolution-lifecycle.md:188` (behavior, STALE)
  - claim: Users can disable optional features (semantic search, self space, processing pipeline) via /architect.
  - stated: disable via /architect
  - measured: 0 'disable' matches; the seven phases are Locate / Read Derivation / Health Analysis / Read Friction / Consult Research / Generate Recommendations / Present to User — no feature-toggle phase.
  - suggested: Users can ask /architect to recommend disabling optional features (semantic search, self space, processing pipeline); it implements only approved recommendations and ships no disable command.
  - re-derive:

    ```text
    cd /Volumes/Containers/arscontexta/.claude/worktrees/docs-refresh && /usr/bin/grep -ci 'disable' skills/architect/SKILL.md; /usr/bin/grep -nE '^## PHASE' skills/architect/SKILL.md
    ```

- **W4-140** `reference/evolution-lifecycle.md:222` (count, STALE)
  - claim: The 15 kernel primitives (markdown-yaml, wiki-links, ... methodology-folder, session-capture)
  - stated: 15
  - measured: 16 (the parenthetical on this very line enumerates 16 ids, including unique-addresses)
  - suggested: The 16 kernel primitives (markdown-yaml, wiki-links, ... methodology-folder, session-capture)
  - re-derive:

    ```text
    cd /Volumes/Containers/arscontexta/.claude/worktrees/docs-refresh && /usr/bin/grep -c '^  - id:' reference/kernel.yaml
    ```

- **W4-141** `reference/evolution-lifecycle.md:224` (count, STALE)
  - claim: validate that all 15 kernel primitives remain intact ... these 15 primitives are foundational
  - stated: 15 (twice on this line)
  - measured: 16
  - suggested: all 16 kernel primitives remain intact ... these 16 primitives are foundational
  - re-derive:

    ```text
    cd /Volumes/Containers/arscontexta/.claude/worktrees/docs-refresh && /usr/bin/grep -c '^  - id:' reference/kernel.yaml
    ```

- **W4-145** `reference/evolution-lifecycle.md:268` (behavior, STALE)
  - claim: | /next reconciliation | When user asks "what next" | Staleness + coverage gaps | 5-10 seconds |
  - stated: Staleness + coverage gaps
  - measured: next=0 rethink=5 (positive control); skill-sources/next/SKILL.md:71 defines only `methodology_drift` = config.yaml mtime vs newest ops/methodology/ note mtime (staleness). No feature-enumeration / coverage-gap check exists in /next.
  - suggested: | /next reconciliation | When user asks "what next" | Staleness only (methodology_drift mtime comparison) | 5-10 seconds |  — and at line 274 change '/next reconciliation (coverage check)' to '/next reconciliation (staleness check)'
  - re-derive:

    ```text
    cd /Volumes/Containers/arscontexta/.claude/worktrees/docs-refresh && printf 'next=%s rethink=%s\n' "$(/usr/bin/grep -ci 'coverage' skill-sources/next/SKILL.md)" "$(/usr/bin/grep -ci 'coverage' skill-sources/rethink/SKILL.md)"; /usr/bin/grep -n 'methodology_drift' skill-sources/next/SKILL.md
    ```

- **W4-143** `reference/evolution-lifecycle.md:295` (count, STALE)
  - claim: Claims included: 21
  - stated: 21
  - measured: 22 (the 'Three types of drift' claim at line 250 was added after the count was written)
  - suggested: Claims included: 22
  - re-derive:

    ```text
    cd /Volumes/Containers/arscontexta/.claude/worktrees/docs-refresh && /usr/bin/grep -c '^#### ' reference/evolution-lifecycle.md
    ```

- **W4-142** `reference/evolution-lifecycle.md:297` (cross-doc, STALE)
  - claim: `kernel.yaml` (15 invariant primitives)
  - stated: 15 invariant primitives
  - measured: 16 primitives, 14 invariant (self-space and semantic-search are `enforcement: configurable`)
  - suggested: `kernel.yaml` (16 primitives, 14 invariant)
  - re-derive:

    ```text
    cd /Volumes/Containers/arscontexta/.claude/worktrees/docs-refresh && printf '%s %s\n' "$(/usr/bin/grep -c '^  - id:' reference/kernel.yaml)" "$(/usr/bin/grep -c 'enforcement: invariant' reference/kernel.yaml)"
    ```

- **W4-149** `reference/evolution-lifecycle.md:297` (cross-doc, DANGLING)
  - claim: `methodology.md` (Gall's Law, self-extension principle)
  - stated: methodology.md covers Gall's Law
  - measured: methodology.md=0 evolution-lifecycle.md=3 (positive control); methodology.md:259 '## Self-Extension Principle' exists, Gall's Law does not appear anywhere in reference/methodology.md
  - suggested: `methodology.md` (self-extension principle)
  - re-derive:

    ```text
    cd /Volumes/Containers/arscontexta/.claude/worktrees/docs-refresh && printf 'methodology.md=%s evolution-lifecycle.md=%s\n' "$(/usr/bin/grep -ci 'gall' reference/methodology.md)" "$(/usr/bin/grep -ci 'gall' reference/evolution-lifecycle.md)"; /usr/bin/grep -n 'Self-Extension' reference/methodology.md
    ```

### `reference/failure-modes.md` (1)

- **W4-160** `reference/failure-modes.md:212` (cross-doc, DANGLING)
  - claim: When generating a context file in Step 5b, include a "Common Pitfalls" section
  - stated: Step 5b
  - measured: setup has Steps 1-16 plus 5f, 5g, 7b; no Step 5b exists. The context file is '#### Step 3: Context File' (skills/setup/SKILL.md:617). Positive control: setup:423 and generators/claude-md.md:325-327 do consume failure-modes.md for Common Pitfalls.
  - suggested: When generating a context file (setup PHASE 5, Step 3: Context File), include a "Common Pitfalls" section:
  - re-derive:

    ```text
    /usr/bin/grep -nE '^#### Step [0-9]+[a-z]?' skills/setup/SKILL.md
    ```

### `reference/interaction-constraints.md` (3)

- **W4-161** `reference/interaction-constraints.md:142` (count, STALE)
  - claim: These constraints apply to the 15 kernel primitives
  - stated: 15
  - measured: 16 ids in kernel.yaml (unique-addresses is the 11th); CLAUDE.md:98 and README.md:110,353,421 say 16
  - suggested: These constraints apply to the 16 kernel primitives
  - re-derive:

    ```text
    /usr/bin/grep -cE '^\s+- id: ' reference/kernel.yaml; /usr/bin/grep -nE '\b(15|16) (kernel )?primitives' CLAUDE.md README.md
    ```

- **W4-162** `reference/interaction-constraints.md:155` (symbol, STALE)
  - claim: `wiki_links == false` (Primitive 3)
  - stated: Primitive 3
  - measured: validate-kernel.sh:420 '# --- Primitive 2: Wiki links as graph edges ---'; :581 '# --- Primitive 3: MOC hierarchy ---'. wiki-links is 2nd in kernel.yaml at every revision. The other four numbers in this section (7, 13, 14, 15) match the validator.
  - suggested: `wiki_links == false` (Primitive 2)
  - re-derive:

    ```text
    /usr/bin/grep -nE '^# --- Primitive [0-9]+' reference/validate-kernel.sh | sed -n '2,3p'; git show 4be327e:reference/kernel.yaml | /usr/bin/grep -E '^\s+- id:' | sed -n '2,3p'
    ```

- **W4-163** `reference/interaction-constraints.md:163` (symbol, STALE)
  - claim: preset == "personal_assistant"
  - stated: personal_assistant
  - measured: presets/personal/preset.yaml:1 'name: personal-assistant' (directory presets/personal/); the only occurrence of personal_assistant in the tree is this file. Positive control: line 160's preset == "research" matches presets/research/preset.yaml:1 'name: research'.
  - suggested: preset == "personal-assistant"
  - re-derive:

    ```text
    /usr/bin/grep -m1 -n '^name:' presets/personal/preset.yaml; /usr/bin/grep -rln personal_assistant reference presets skills generators
    ```

### `reference/open-questions.md` (5)

- **W4-164** `reference/open-questions.md:3` (behavior, STALE)
  - claim: the architect command references it when proposing evolution paths
  - stated: architect references it
  - measured: 0 hits in architect; its reference list (lines 356-365) names 10 reference files, none open-questions.md. The only skill referencing this file is skills/ask/SKILL.md:117. The same command shows setup also has 0 hits.
  - suggested: and the ask command lists it among its reference documents.
  - re-derive:

    ```text
    /usr/bin/grep -c 'open-questions' skills/architect/SKILL.md; /usr/bin/grep -noE 'reference/[a-z-]+\.(md|yaml)' skills/architect/SKILL.md | sort -u; /usr/bin/grep -rn 'open-questions' skills/ generators/
    ```

- **W4-167** `reference/open-questions.md:103` (behavior, STALE)
  - claim: The init wizard currently asks 3-5 follow-up questions ... the arbitrary "3-5 questions" heuristic
  - stated: 3-5
  - measured: setup:250 'After the opening response, ask 1-3 follow-up questions targeting:'; setup:145 '## PHASE 2: Understanding (2-4 conversation turns)'
  - suggested: The setup conversation currently asks 1-3 follow-up questions ... the arbitrary "1-3 questions" heuristic.
  - re-derive:

    ```text
    sed -n '250p' skills/setup/SKILL.md; sed -n '145p' skills/setup/SKILL.md
    ```

- **W4-168** `reference/open-questions.md:147` (count, STALE)
  - claim: derivation-validation.md runs 4 worked tests (self-derivation, cross-domain, novel domain, multi-domain composition)
  - stated: 4
  - measured: 9 (Tests 1-4 as listed, plus 5 Minimal Platform, 6 Interaction Constraint Violation Recovery, 7 Vocabulary Transformation Fidelity, 8 Progressive Configuration Validation, 9 Operational Learning Loop Integration)
  - suggested: Evaluation is manual — derivation-validation.md runs 9 worked tests (self-derivation, cross-domain, novel domain, multi-domain composition, minimal platform, constraint-violation recovery, vocabulary-transformation fidelity, progressive configuration, operational-learning-loop integration).
  - re-derive:

    ```text
    /usr/bin/grep -c '^## Test' reference/derivation-validation.md; /usr/bin/grep -nE '^## Test' reference/derivation-validation.md
    ```

- **W4-170** `reference/open-questions.md:262` (behavior, STALE)
  - claim: The derivation engine references this document in three situations: (1) user asks about a deferred feature, (2) Architect command encounters an open question, (3) Reseed considers open research
  - stated: setup, architect and reseed all reference this document
  - measured: 0, 0, 0; the only reference in skills/ or generators/ is skills/ask/SKILL.md:117. Positive control: setup references interaction-constraints.md at :20,:332,:383 and failure-modes.md at :21,:423.
  - suggested: The derivation engine is intended to reference this document in three situations (today only the ask command lists it among its references; none of the three paths below is wired):
  - re-derive:

    ```text
    /usr/bin/grep -c 'open-questions' skills/setup/SKILL.md skills/architect/SKILL.md skills/reseed/SKILL.md; /usr/bin/grep -rn 'open-questions' skills/ generators/
    ```

- **W4-172** `reference/open-questions.md:277` (cross-doc, STALE)
  - claim: See `derivation-validation.md` for the 4 worked tests that validate the derivation engine today.
  - stated: 4
  - measured: 9
  - suggested: See `derivation-validation.md` for the 9 worked tests that validate the derivation engine today.
  - re-derive:

    ```text
    /usr/bin/grep -c '^## Test' reference/derivation-validation.md
    ```

### `reference/self-space.md` (3)

- **W4-154** `reference/self-space.md:7` (behavior, STALE)
  - claim: The toggle is available via /architect during or after init.
  - stated: toggle via /architect
  - measured: [toggle] 0, [disable] 0, [enable] 1 — the single 'enable' hit (line 607) is 'to enable friction-based evolution', unrelated. No self-space toggle exists in skills/architect/SKILL.md; the setup conversation sets self_space from presets/*/preset.yaml (research false, personal true, experimental user_choice).
  - suggested: Self space is set from the preset during init; no toggle command ships, and changing it afterwards is a manual migration that /architect can recommend but does not automate.
  - re-derive:

    ```text
    cd /Volumes/Containers/arscontexta/.claude/worktrees/docs-refresh && for w in toggle disable enable; do printf '[%s] %s\n' "$w" "$(/usr/bin/grep -ci "$w" skills/architect/SKILL.md)"; done; /usr/bin/grep -n 'enable' skills/architect/SKILL.md
    ```

- **W4-152** `reference/self-space.md:193` (behavior, STALE)
  - claim: - Session-start hook reads self/ files in identity-first order
  - stated: identity-first order
  - measured: goals.md read at :98 before identity.md/methodology.md at :107 (same in platforms/claude-code/hooks/session-orient.sh.template :21 vs :99)
  - suggested: - Session-start hook reads self/goals.md, then self/identity.md and self/methodology.md (identity-first order is the stated convention; the shipped hooks do not yet follow it)
  - re-derive:

    ```text
    cd /Volumes/Containers/arscontexta/.claude/worktrees/docs-refresh && /usr/bin/grep -nE 'cat (self|ops)/(goals|identity|methodology)\.md' hooks/scripts/session-orient.sh
    ```

- **W4-155** `reference/self-space.md:197` (behavior, STALE)
  - claim: **Toggle mechanism:** /architect allows toggling self space during or after init. Toggling ON creates self/ with generated content ... Toggling OFF moves goals to ops/goals.md and removes the self/ directory
  - stated: /architect toggles self space on/off with content migration
  - measured: rc=1 (no matches); positive control: /usr/bin/grep -c 'self' skills/architect/SKILL.md > 0. Neither the create-self/ nor the migrate-goals-and-remove-self/ behavior exists in the architect skill.
  - suggested: **Toggle mechanism:** no toggle ships in skills/architect/SKILL.md; self_space is fixed by the preset at init. Changing it afterwards is a manual migration (goals between self/goals.md and ops/goals.md; methodology is already in ops/methodology/) that /architect can recommend but does not automate.
  - re-derive:

    ```text
    cd /Volumes/Containers/arscontexta/.claude/worktrees/docs-refresh && /usr/bin/grep -nEi 'toggl|ops/goals|remove.*self/|self_space' skills/architect/SKILL.md; printf 'rc=%s\n' $?
    ```

### `reference/semantic-vs-keyword.md` (2)

- **W4-174** `reference/semantic-vs-keyword.md:116` (symbol, DANGLING)
  - claim: The recite and verify skills search by vector similarity alone to test description findability
  - stated: a `recite` skill distinct from `verify`
  - measured: 0 / 0 / 0 — no `recite` skill in skill-sources/, in the field-test vault, or in the v0.8.0 initial tree; recite is Step 1 inside skill-sources/verify/SKILL.md (line 82 '### Step 1: RECITE (cold-read prediction test)', frontmatter line 3 'Combined verification — recite ... + validate')
  - suggested: The verify skill's recite step searches by vector similarity alone to test description findability
  - re-derive:

    ```text
    cd /Volumes/Containers/arscontexta/.claude/worktrees/docs-refresh && ls skill-sources/ | /usr/bin/grep -c '^recite$'; ls ~/second-brain/.claude/skills/ | /usr/bin/grep -c '^recite$'; git ls-tree --name-only 4be327e skill-sources/ | /usr/bin/grep -c recite; /usr/bin/grep -n 'RECITE' skill-sources/verify/SKILL.md | head -2
    ```

- **W4-173** `reference/semantic-vs-keyword.md:288` (count, STALE)
  - claim: - Claims included: 23
  - stated: 23
  - measured: 22 curated-claim (H4) headings
  - suggested: - Claims included: 22
  - re-derive:

    ```text
    cd /Volumes/Containers/arscontexta/.claude/worktrees/docs-refresh && /usr/bin/grep -c '^#### ' reference/semantic-vs-keyword.md
    ```

### `reference/session-lifecycle.md` (3)

- **W4-151** `reference/session-lifecycle.md:42` (behavior, STALE)
  - claim: For systems with hooks: the session-start hook loads self/ files in identity-first order.
  - stated: identity-first order (identity -> methodology -> goals)
  - measured: hooks/scripts/session-orient.sh: goals.md at :98/:101, identity.md+methodology.md at :107. platforms template: goals.md at :21/:26, identity.md at :99, methodology.md at :104. Both shipped hooks read goals FIRST, then identity, then methodology.
  - suggested: For systems with hooks: the session-start hook must read self/identity.md and self/methodology.md before self/goals.md (the shipped hooks/scripts/session-orient.sh and session-orient.sh.template currently read goals first and need reordering).
  - re-derive:

    ```text
    cd /Volumes/Containers/arscontexta/.claude/worktrees/docs-refresh && /usr/bin/grep -nE 'cat (self|ops)/(goals|identity|methodology)\.md' hooks/scripts/session-orient.sh platforms/claude-code/hooks/session-orient.sh.template
    ```

- **W4-153** `reference/session-lifecycle.md:192` (behavior, STALE)
  - claim: The stop hook saves the session transcript with a timestamp filename to ops/sessions/ and creates a mining task.
  - stated: stop hook creates a mining task
  - measured: task=0 sessions=6 (positive control). Template line 24: '# The session file becomes a target for /remember --mine-sessions.' — it writes ops/sessions/<TIMESTAMP>.json and commits; it creates no task. The mining task is created by /next when its `unprocessed_sessions` condition (skill-sources/next/SKILL.md:67) exceeds threshold.
  - suggested: The stop hook saves the session transcript with a timestamp filename to ops/sessions/; /next's unprocessed_sessions condition creates the mining task.
  - re-derive:

    ```text
    cd /Volumes/Containers/arscontexta/.claude/worktrees/docs-refresh && printf 'task=%s sessions=%s\n' "$(/usr/bin/grep -ci 'task' platforms/claude-code/hooks/session-capture.sh.template)" "$(/usr/bin/grep -c 'ops/sessions' platforms/claude-code/hooks/session-capture.sh.template)"; sed -n '24p' platforms/claude-code/hooks/session-capture.sh.template; /usr/bin/grep -n 'unprocessed_sessions' skill-sources/next/SKILL.md
    ```

- **W4-144** `reference/session-lifecycle.md:286` (count, STALE)
  - claim: Claims included: 22
  - stated: 22
  - measured: 23
  - suggested: Claims included: 23
  - re-derive:

    ```text
    cd /Volumes/Containers/arscontexta/.claude/worktrees/docs-refresh && /usr/bin/grep -c '^#### ' reference/session-lifecycle.md
    ```

### `reference/testing-milestones.md` (17)

- **W4-84** `reference/testing-milestones.md:3` (count, STALE)
  - claim: Seven validation milestones for the Ars Contexta v1.6 plugin
  - stated: Seven
  - measured: 8 (Milestone 1, 2, 3, 4, 5, 5b, 5c, 6)
  - suggested: Eight validation milestones
  - re-derive:

    ```text
    /usr/bin/grep -c '^## Milestone' reference/testing-milestones.md
    ```

- **W4-85** `reference/testing-milestones.md:3` (status, STALE)
  - claim: the Ars Contexta v1.6 plugin
  - stated: v1.6 plugin
  - measured: plugin.json version 0.10.0; tags v0.8.0 v0.9.0 v0.9.5 v0.9.6 v0.9.7 v0.9.9 v0.10.0 (no v1.6); docs/superpowers/deferrals.md:601 records stamps moved from arscontexta-v1.6 to arscontexta-0.10.0
  - suggested: the Ars Contexta plugin (v1.6 specification)
  - re-derive:

    ```text
    /usr/bin/grep -o '"version": *"[^"]*"' .claude-plugin/plugin.json; git tag
    ```

- **W4-86** `reference/testing-milestones.md:3` (behavior, STALE)
  - claim: from kernel correctness through vocabulary transformation to cross-platform parity
  - stated: a milestone ending in cross-platform parity
  - measured: 'platform' appears only at lines 3 and 880; no milestone section tests platform parity — the last milestone (6) is Preset Validation
  - suggested: from kernel correctness through vocabulary transformation to preset validation
  - re-derive:

    ```text
    /usr/bin/grep -n 'platform' reference/testing-milestones.md; /usr/bin/grep -n '^## Milestone' reference/testing-milestones.md
    ```

- **W4-87** `reference/testing-milestones.md:51` (cmd-output, STALE)
  - claim: Expected output lines 51-56: '8. Semantic search capability' / '9. Self space for agent persistent memory' / '10. Session rhythm: orient, work, persist'
  - stated: 8 = Semantic search, 9 = Self space, 10 = Session rhythm
  - measured: 685: '8. Self space for agent persistent memory (configurable)'; 717: '9. Session rhythm: orient, work, persist'; 732: '10. Semantic search capability (configurable)'
  - suggested: 8. Self space for agent persistent memory (configurable) PASS self/ with N files (identity, methodology, goals present) 9. Session rhythm: orient, work, persist PASS Session rhythm documented or automated 10. Semantic search capability (configurable) PASS Semantic search capability found (qmd executable); declared qmd tool names resolve
  - re-derive:

    ```text
    /usr/bin/grep -nE 'echo "(8|9|10)\. ' reference/validate-kernel.sh
    ```

- **W4-88** `reference/testing-milestones.md:57` (cmd-output, STALE)
  - claim: 10A. Unique addresses (wiki links as INVARIANT reference form) / PASS All internal references use wiki links, filenames are unique
  - stated: header 'Unique addresses (wiki links as INVARIANT reference form)', PASS 'All internal references use wiki links, filenames are unique'
  - measured: header '10A. Filesystem graph database (unique-addresses)'; pass 'Graph analysis scripts directory found'; warn 'No ops/scripts/graph/ directory detected'
  - suggested: 10A. Filesystem graph database (unique-addresses) / PASS Graph analysis scripts directory found
  - re-derive:

    ```text
    sed -n '833,843p' reference/validate-kernel.sh
    ```

- **W4-89** `reference/testing-milestones.md:63` (cmd-output, STALE)
  - claim: Lines 63-68: '13. Task stack for work prioritization / PASS Task stack mechanism found (ops/tasks/ or equivalent)', '14. Methodology folder for vault self-knowledge / PASS ops/methodology/ exists with linked notes', '15. Session capture for automatic transcript persistence / PASS Session transcripts saved to ops/sessions/, mining tasks auto-created'
  - stated: longer headers and different PASS messages
  - measured: 941 '13. Task stack' → pass 956 'Task stack: tasks.md and queue file found'; 966 '14. Methodology folder' → pass 977 'Methodology folder with methodology.md MOC found'; 985 '15. Session capture' → pass 993 'Session capture directory found'
  - suggested: 13. Task stack / PASS Task stack: tasks.md and queue file found; 14. Methodology folder / PASS Methodology folder with methodology.md MOC found; 15. Session capture / PASS Session capture directory found
  - re-derive:

    ```text
    /usr/bin/grep -nE 'echo "(13|14|15)\. ' reference/validate-kernel.sh; /usr/bin/grep -nE '^\s*pass "' reference/validate-kernel.sh | awk -F: '$1>=941 && $1<=1000'
    ```

- **W4-90** `reference/testing-milestones.md:95` (behavior, STALE)
  - claim: FAIL on primitive 8 (self space) | self/ directory not created when enabled
  - stated: primitive 8 can FAIL
  - measured: 699 pass, 701 warn, 703 warn, 708 pass, 710 warn, 712 warn — no fail call in primitive 8; the missing-self/ case emits warn 'No self/ directory found (configurable — off by default for research vaults)'
  - suggested: | WARN on primitive 8 (self space) while self space is enabled | self/ directory not created when enabled — the script emits WARN ('No self/ directory found…'), never FAIL, for this primitive | Check that /setup creates self/identity.md, self/methodology.md, self/goals.md when self space is enabled |
  - re-derive:

    ```text
    /usr/bin/grep -nE '^\s*(pass|warn|fail)\b' reference/validate-kernel.sh | awk -F: '$1>=685 && $1<=716'
    ```

- **W4-91** `reference/testing-milestones.md:100` (behavior, STALE)
  - claim: Lines 100-102: FAIL on primitive 13 (task stack) / FAIL on primitive 14 (methodology folder) / FAIL on primitive 15 (session capture)
  - stated: primitives 13, 14, 15 can FAIL
  - measured: 13: 956 pass, 958/960/962 warn; 14: 977 pass, 979/981 warn; 15: 993 pass, 995 warn — none of the three primitives has a fail path (positive control: primitive 12 has fail at 925 and 937, primitive 3 at 589)
  - suggested: | WARN on primitive 13 (task stack) | Missing ops/tasks.md and/or ops/queue/queue.json (or .yaml) — the script WARNs, never FAILs, here | Ensure /setup creates task stack infrastructure | | WARN on primitive 14 (methodology folder) | Missing ops/methodology/ or its methodology.md MOC | Ensure /setup creates ops/methodology/ with a methodology.md MOC | | WARN on primitive 15 (session capture) | Mis
  - re-derive:

    ```text
    /usr/bin/grep -nE '^\s*(pass|warn|fail)\b' reference/validate-kernel.sh | awk -F: '$1>=941 && $1<=1000'
    ```

- **W4-92** `reference/testing-milestones.md:131` (symbol, STALE)
  - claim: Required sections list (lines 125-135) and expected PASS lines 180-184 include "Note Design", "Quality Standards", "Constraints"
  - stated: seven required sections, all PASS on success
  - measured: 0 such headings in the composition spec or setup's block order (skills/setup/SKILL.md:641-658 lists 17 blocks, none titled so); control: '## Common Pitfalls' = 2 in generators/claude-md.md; field vault ~/second-brain/CLAUDE.md: Note Design=0, Quality Standards=0, Constraints=0 while Session Rhythm=2, Discovery-First=1, Common Pitfalls=1, System Evolution=2
  - suggested: Remove "Note Design", "Quality Standards" and "Constraints" from the `for section in` list (lines 128-135) and the matching three `PASS:` lines in the expected-output block (lines 180-184), leaving Session Rhythm, Discovery-First, Common Pitfalls, System Evolution.
  - re-derive:

    ```text
    /usr/bin/grep -rn '^## .*\(Note Design\|Quality Standards\|Constraints\)' generators/ skills/setup/SKILL.md | awk 'END{print NR}'; /usr/bin/grep -rn '^## Common Pitfalls' generators/claude-md.md | awk 'END{print NR}'; for s in 'Note Design' 'Quality Standards' 'Constraints'; do /usr/bin/grep -ci "$s" ~/second-brain/CLAUDE.md; done
    ```

- **W4-94** `reference/testing-milestones.md:555` (cmd-output, STALE)
  - claim: Expected session-orient.sh output ends with '**Remember:** Read self/identity.md and self/goals.md to orient.'
  - stated: a '**Remember:** Read self/identity.md and self/goals.md to orient.' trailer
  - measured: Remember=0 (control: Workspace Structure=1); the hook cats self/goals.md (or ops/goals.md) and self/identity.md + self/methodology.md directly into stdout instead of emitting a reminder line
  - suggested: ## Workspace Structure [tree output] --- [contents of self/goals.md (or ops/goals.md)] [contents of self/identity.md and self/methodology.md, when self/ is enabled] [recent ops/methodology/ headers and maintenance signals]
  - re-derive:

    ```text
    /usr/bin/grep -c 'Remember' hooks/scripts/session-orient.sh; /usr/bin/grep -c 'Workspace Structure' hooks/scripts/session-orient.sh; sed -n '95,110p' hooks/scripts/session-orient.sh
    ```

- **W4-95** `reference/testing-milestones.md:717` (symbol, DANGLING)
  - claim: Active feature blocks match the preset's `active_blocks` list
  - stated: `active_blocks` key
  - measured: active_blocks=0; blocks=3 (each preset has `blocks:` with always/conditional/optional/disabled sub-lists)
  - suggested: 4. Active feature blocks match the preset's `blocks` map — its `always` list plus whichever `conditional`/`optional` entries were enabled (17 blocks available)
  - re-derive:

    ```text
    cat presets/*/preset.yaml | /usr/bin/grep -c '^ *active_blocks:'; cat presets/*/preset.yaml | /usr/bin/grep -c '^ *blocks:'
    ```

- **W4-96** `reference/testing-milestones.md:723` (path, DANGLING)
  - claim: PRESETS=("research" "personal-assistant" "experimental") combined with presets/$PRESET/preset.yaml (lines 779, 800, 828) and the `personal-assistant)` case at 747
  - stated: a presets/personal-assistant/ directory
  - measured: presets/ holds experimental/ personal/ research/; presets/personal-assistant/preset.yaml MISSING; presets/personal/preset.yaml has name: personal-assistant
  - suggested: PRESETS=("research" "personal" "experimental") and `personal)` in the case arm (the directory is presets/personal/; its `name:` field is personal-assistant)
  - re-derive:

    ```text
    ls presets/; test -e presets/personal-assistant/preset.yaml && echo EXISTS || echo MISSING; /usr/bin/grep -n '^name:' presets/personal/preset.yaml
    ```

- **W4-97** `reference/testing-milestones.md:779` (symbol, DANGLING)
  - claim: GRAN=$(grep 'granularity:' "presets/$PRESET/preset.yaml" ...)
  - stated: `granularity:` key
  - measured: granularity=0; atomicity=3 (presets/research/preset.yaml:5 'atomicity: 0.8')
  - suggested: GRAN=$(grep 'atomicity:' "presets/$PRESET/preset.yaml" | awk '{print $2}')
  - re-derive:

    ```text
    cat presets/*/preset.yaml | /usr/bin/grep -c '^ *granularity:'; cat presets/*/preset.yaml | /usr/bin/grep -c '^ *atomicity:'
    ```

- **W4-98** `reference/testing-milestones.md:800` (symbol, DANGLING)
  - claim: ACTIVE_BLOCKS=$(grep -A50 'active_blocks:' "presets/$PRESET/preset.yaml" | grep '^ *-' ...)
  - stated: `active_blocks:` flat list
  - measured: active_blocks=0; the key is `blocks:` with nested `always:`/`conditional:`/`optional:`/`disabled:` lists — a grep -A50 on 'blocks:' would also sweep in the disabled list
  - suggested: ACTIVE_BLOCKS=$(sed -n '/^  always:/,/^  conditional:/p' "presets/$PRESET/preset.yaml" | grep '^ *-' | sed 's/^ *- *//')
  - re-derive:

    ```text
    cat presets/*/preset.yaml | /usr/bin/grep -c '^ *active_blocks:'; sed -n '13,33p' presets/research/preset.yaml
    ```

- **W4-99** `reference/testing-milestones.md:828` (symbol, DANGLING)
  - claim: WARMTH=$(grep 'warmth:' "presets/$PRESET/preset.yaml" ...) then compared numerically with bc
  - stated: numeric `warmth:` key
  - measured: warmth=0; presets carry `personality: "neutral-analytical"` (research) as a string label, no numeric warmth dimension
  - suggested: PERSONALITY=$(grep '^personality:' "presets/$PRESET/preset.yaml" | awk '{print $2}' | tr -d '"') case "$PERSONALITY" in warm-supportive) # Warm label — identity should feel warm ...
  - re-derive:

    ```text
    cat presets/*/preset.yaml | /usr/bin/grep -c '^ *warmth:'; cat presets/*/preset.yaml | /usr/bin/grep -n '^ *personality:'
    ```

- **W4-100** `reference/testing-milestones.md:858` (count, STALE)
  - claim: all active blocks (from 16 available) produce output in context file
  - stated: 16
  - measured: 17 (and line 717 of the same file already says 17)
  - suggested: (from 17 available)
  - re-derive:

    ```text
    ls generators/features/*.md | awk 'END{print NR}'
    ```

- **W4-101** `reference/testing-milestones.md:880` (behavior, STALE)
  - claim: # 1. Generate test vaults for each preset and platform
  - stated: vaults generated per preset and per platform
  - measured: no milestone varies by platform; the run list that follows (lines 883-890) runs only per preset
  - suggested: # 1. Generate test vaults for each preset
  - re-derive:

    ```text
    /usr/bin/grep -n 'platform' reference/testing-milestones.md
    ```

### `reference/three-spaces.md` (2)

- **W4-80** `reference/three-spaces.md:55` (behavior, STALE)
  - claim: /architect enable self    # Creates self/ with identity.md, methodology.md, goals.md /architect disable self   # Migrates goals to ops/goals.md, archives self/
  - stated: `/architect enable self` creates self/; `/architect disable self` migrates goals to ops/goals.md and archives self/
  - measured: 0 matches in skills/architect/SKILL.md for 'enable self', 'disable self' or 'toggle'. Its argument-hint (line 8) is '[optional: specific area to focus on, e.g. schema, processing, MOC structure]' and lines 622-625 use $ARGUMENTS only to weight findings toward a focus area; its description says 'Never auto-implements — proposals require your approval'. The `/architect enable self` / `/architect disable self` syntax occurs nowhere in the repo except three-spaces.md:55-56.
  - suggested: Smaller than the verifier's: keep line 53 and lines 58-59, and replace only the fence (54-57) with one prose line: 'Ask `/architect` to enable or disable self space (e.g. `/architect self space`); it proposes the change and applies it only after your approval. Enabling creates self/ with identity.md, methodology.md, goals.md; disabling migrates goals to ops/goals.md and archives self/.' This match
  - re-derive:

    ```text
    /usr/bin/grep -nE 'enable self|disable self|toggle' skills/architect/SKILL.md; sed -n '8p;622,625p' skills/architect/SKILL.md; /usr/bin/grep -rnE 'enable self|disable self' --include='*.md' . | grep -v worktrees
    ```

- **W4-82** `reference/three-spaces.md:97` (cross-doc, STALE)
  - claim: ### Structural Constants (from the kernel) / These hold across all generated systems: | Flat folder | No subfolders for organization | ... | Prose-sentence titles | ...
  - stated: All five structural constants come from the kernel and hold across all generated systems
  - measured: kernel.yaml declares 16 primitive ids; none is a flat-folder or prose-title primitive. 'flat'/'subfolder' match 0 lines; 'prose' matches only the operational-learning-loop observation description (line 170). The derivation manifest template at skills/setup/SKILL.md:1132 offers `organization: [flat | hierarchical]`, i.e. folder flatness is a derivation dimension, not a kernel constant. Three of the five rows (MOC navigation -> moc-hierarchy, Wiki links -> wiki-links, Topics footer -> topics-foote
  - suggested: Keep the table; change the heading and lead sentence only: '### Structural Constants' / 'These hold across all generated systems. Three are kernel primitives (`moc-hierarchy`, `wiki-links`, `topics-footer`); flat folders and prose-sentence titles are derivation defaults (`organization: flat` in the derivation manifest), not kernel primitives.' This is smaller than the verifier's heading rewrite an
  - re-derive:

    ```text
    /usr/bin/grep -nE '^  - id:' reference/kernel.yaml; /usr/bin/grep -niE 'flat|subfolder|prose' reference/kernel.yaml; sed -n '1131,1133p' skills/setup/SKILL.md
    ```

### `reference/tradition-presets.md` (3)

- **W4-176** `reference/tradition-presets.md:155` (cross-doc, STALE)
  - claim: ## Use-Case Presets — table with seven columns: Research | Life Mgmt | Learning | Relationships | Therapy | Creative | Companion
  - stated: seven use-case presets
  - measured: 3 shipped presets (experimental, personal, research); reference/use-case-presets.md line 7 reads '## Three Use-Case Presets'; 0 mentions of Companion/Therapy in it. Both presets/ and use-case-presets.md have been unchanged since 4be327e (v0.8.0), so the seven-column section has never matched the shipped set
  - suggested: Retitle line 155 to '## Use-Case Starting Positions' and extend line 157 to: 'These are derived from tradition presets, adapted for specific use cases. Each cell shows the recommended starting position. Only research and personal-assistant ship as presets (`presets/`, `reference/use-case-presets.md`); the other columns are per-use-case affinities with no shipped preset.'
  - re-derive:

    ```text
    cd /Volumes/Containers/arscontexta/.claude/worktrees/docs-refresh && ls presets/ | awk 'END{print NR}'; ls presets/; sed -n '7p' reference/use-case-presets.md; /usr/bin/grep -c -E 'Companion|Therapy' reference/use-case-presets.md
    ```

- **W4-177** `reference/tradition-presets.md:181` (cross-doc, STALE)
  - claim: **Why convention automation for all:** ... all systems start at convention level (and the table row 'Automation | convention' x7, plus line 183 'The presets above are the floor')
  - stated: every use case starts at convention-level automation; hooks are an opt-in upgrade
  - measured: presets/research/preset.yaml: automation 0.8, description 'Full automation from day one'; personal: automation 0.6; experimental: automation null. skills/setup/SKILL.md line 427: 'All generated systems ship with full automation from day one. There are no tiers'
  - suggested: Table row: '| Automation | full | full | full | full | full | full | full |'. Replace lines 181-183 with: '**Why full automation for all:** All generated systems ship with full automation from day one (setup Step 3g; `presets/*/preset.yaml` automation 0.8 research, 0.6 personal). Following Gall\'s Law, users opt DOWN to convention or manual at friction points via `ops/config.yaml` rather than addi
  - re-derive:

    ```text
    cd /Volumes/Containers/arscontexta/.claude/worktrees/docs-refresh && /usr/bin/grep -n -E '^description|automation' presets/research/preset.yaml presets/personal/preset.yaml presets/experimental/preset.yaml; sed -n '427p' skills/setup/SKILL.md | cut -c1-120
    ```

- **W4-175** `reference/tradition-presets.md:189` (symbol, DANGLING)
  - claim: When a user selects "Custom / Mixed" in the init wizard, present traditions as reference points
  - stated: a 'Custom / Mixed' option in the init wizard
  - measured: 0 matches for 'Custom / Mixed' or 'mixed'; setup's third menu option is 'Experimental — Build your own from first principles' (lines 113-116), and reference/use-case-presets.md line 138 heads it '### Experimental / Build Your Own'
  - suggested: When a user selects "Experimental" (build your own from first principles) in the init wizard, present traditions as reference points:   — and apply the same relabel at reference/vocabulary-transforms.md:106
  - re-derive:

    ```text
    cd /Volumes/Containers/arscontexta/.claude/worktrees/docs-refresh && /usr/bin/grep -n -i -E 'custom / mixed|mixed' skills/setup/SKILL.md | awk 'END{print NR}'; sed -n '113,116p' skills/setup/SKILL.md
    ```

### `reference/vocabulary-transforms.md` (1)

- **W4-49** `reference/vocabulary-transforms.md:91` (cross-doc, DANGLING)
  - claim: ### In the init wizard (Step 5b):
  - stated: init wizard Step 5b
  - measured: skills/setup/SKILL.md has no Step 5b (Step 5 at 751 is self/methodology.md; sub-steps present are 5f:781 and 5g:839). Vocabulary transformation is applied at generation Step 3 (Context File, line 617; sub-item 'b. Apply vocabulary transformation' at 637) and Step 9 (Skills, vocabulary-transformed, line 1301). The only 'Step 5b' in the repo is skills/upgrade/SKILL.md:667 '5b. Generate Updated Skill', which is not the init wizard. This file's section dates from the v0.8.0 initial release (4be327e)
  - suggested: ### In the init wizard (`/setup` generation Step 3, Context File, and Step 9, Skills):
  - re-derive:

    ```text
    cd /Volumes/Containers/arscontexta/.claude/worktrees/docs-refresh && /usr/bin/grep -n 'Step 5b\|^#### Step 5\|^#### Step 3\|^#### Step 9' skills/setup/SKILL.md; git log --format='%h' -S'Step 5b' -- skills/setup/SKILL.md | awk 'END{print NR}'   # 0: never existed in setup's history; positive control: Step 5f/5g at 781/839
    ```


## Deferred B — closed records (24 findings, kept by policy)

`docs/closed-divergences.md` and the Closed section of `docs/superpowers/deferrals.md` are dated records: a number that has moved since the record was written is not stale, it is history. These are listed so a reader who takes a "today" in them as current is not misled; none was edited.

- **W2-101** `deferrals.md (CLOSED) / closed-divergences.md:892` (cmd-output, STALE)
  - claim: `/usr/bin/grep -n 'interp_hits_in' reference/check-portability.sh          # 436, 484, 497` (same numbers in the filed What: at L863: `(`:436`, used at `:484` and `:497`)`)
  - stated: 436, 484, 497
  - measured: 444 492 505
  - suggested: `/usr/bin/grep -n 'interp_hits_in' reference/check-portability.sh          # 444, 492, 505 — cbcd48f moved them (436, 484, 497 as filed)`; leave the What: at L863 untouched per the closure note.
  - re-derive:

    ```text
    /usr/bin/grep -n 'interp_hits_in' reference/check-portability.sh | cut -d: -f1
    ```

- **W2-102** `deferrals.md (CLOSED) / closed-divergences.md:973` (status, STALE)
  - claim: `### 31. README.md declares the version but bump-version.sh cannot manage it` — sits under `## Closed` with no CLOSED marker and no closure record, while every sentence reads as live open work
  - stated: (no closure line; body says the tool cannot manage the site)
  - measured: 61f86d9 2026-08-25 'feat: version-sync text sites, and reconcile the stamps to 0.10.0'; declared_text() :85, read_text_field() :105, stage_text_field() :116; README count 1; entry has been below `## Closed` since filing (833/936 at c74915c, 841/973 at HEAD)
  - suggested: Verifier's suggestion stands as written (heading suffix ` — CLOSED`, closure paragraph citing 61f86d9 2026-08-25, 41 → 53, reopen trigger fired, entry preserved as filed).
  - re-derive:

    ```text
    git log --format='%h %ad %s' --date=short -- scripts/bump-version.sh .version-bump.json | head -1; /usr/bin/grep -n '^[a-z_]*text[a-z_]*()' scripts/bump-version.sh; /usr/bin/grep -c README .version-bump.json; for c in c74915c HEAD; do rtk proxy git show $c:docs/superpowers/deferrals.md | awk '/^## Closed$/{c=NR} /^### 31\. /{e=NR} END{print c,e}'; done
    ```

- **W2-103** `deferrals.md (CLOSED) / closed-divergences.md:975` (line-ref, STALE)
  - claim: `README.md:12` carries `**v0.9.9** · Claude Code plugin · MIT`
  - stated: **v0.9.9**
  - measured: **v0.10.0** · Claude Code plugin · MIT; plugin.json "version": "0.10.0"
  - suggested: Preserve as filed under the closure paragraph (idx 1); no edit to this line.
  - re-derive:

    ```text
    sed -n '12p' README.md; /usr/bin/grep -o '"version": *"[^"]*"' .claude-plugin/plugin.json
    ```

- **W2-104** `deferrals.md (CLOSED) / closed-divergences.md:976` (behavior, STALE)
  - claim: `bump-version.sh` is **JSON-only**: every read and write goes through `jq` … a markdown badge cannot be added to `.files` at all. Its `--audit` correctly reports the site on every run and cannot fix it (L976-979; also the comments at L999 `# every site read/write is jq` and L1000 `# reports README every run`)
  - stated: JSON-only; badge cannot be added; --audit reports it every run
  - measured: read_json_field :53, stage_json_field :66, declared_text :85, read_text_field :105, stage_text_field :116; .version-bump.json has `"text": [ { "glob": "README.md", "prefix": "**v", "suffix": "**" }, …skills/*/SKILL.md…, …skill-sources/*/SKILL.md… ]` (L1000 reasoned from code, not run: a declared text site is not an undeclared audit hit)
  - suggested: Preserve as filed under the closure paragraph; if the re-derive block is refreshed: L998 `# 1 — declared under text since 61f86d9 (0 as filed)`, and mark L999-1000 `(as filed; text sites landed in 61f86d9)` rather than deleting them.
  - re-derive:

    ```text
    /usr/bin/grep -n '^[a-z_]*text[a-z_]*()\|^stage_[a-z_]*()\|^read_[a-z_]*()' scripts/bump-version.sh; sed -n '8,12p' .version-bump.json
    ```

- **W2-105** `deferrals.md (CLOSED) / closed-divergences.md:981` (count, STALE)
  - claim: a tool whose 41-assertion suite exists because it once shipped a partial bump
  - stated: 41
  - measured: bump-version-bash passed=53 failed=0; bump-version-zsh passed=53 failed=0
  - suggested: Leave `41-assertion` as filed under the closure paragraph (which states 41 → 53); do not edit the body.
  - re-derive:

    ```text
    /usr/bin/grep -E 'bump-version' …/scratchpad/baseline/summary.txt
    ```

- **W2-106** `deferrals.md (CLOSED) / closed-divergences.md:998` (cmd-output, STALE)
  - claim: `/usr/bin/grep -c 'README' .version-bump.json          # 0 — undeclared`
  - stated: 0 — undeclared
  - measured: 1
  - suggested: `# 1 — declared under text since 61f86d9 (0 as filed)`
  - re-derive:

    ```text
    /usr/bin/grep -c 'README' .version-bump.json
    ```

- **W2-107** `deferrals.md (CLOSED) / closed-divergences.md:1014` (cross-doc, DANGLING)
  - claim: Both re-derive commands below are scoped to `skill-sources/ generators/ skills/` and so could not see nine of the twelve; the tree-wide form is in the block at the end of this entry.
  - stated: the block at the end of this entry
  - measured: fences at 1021 1028 1048 1051 — the tree-wide `git ls-files -z | xargs -0 grep -ln '~150'` block is 1021-1028 (immediately below this sentence); the block at the end (1048-1051) is the scoped pair
  - suggested: `the tree-wide form is in the block directly below`
  - re-derive:

    ```text
    awk 'NR>=1006 && NR<=1056 && /^```/{printf "%d ", NR}' docs/superpowers/deferrals.md
    ```

- **W2-108** `deferrals.md (CLOSED) / closed-divergences.md:1049` (cmd-output, STALE)
  - claim: `/usr/bin/grep -rn '~150' skill-sources/ generators/ skills/   # 3 = 2 generators + 1 unrelated`
  - stated: 3 = 2 generators + 1 unrelated
  - measured: 1 (skills/architect/SKILL.md, the 'line ~150' line number)
  - suggested: `# 1 after closure (the unrelated line number); was 3 = 2 generators + 1 unrelated`
  - re-derive:

    ```text
    /usr/bin/grep -rn '~150' skill-sources/ generators/ skills/ | awk 'END{print NR}'
    ```

- **W2-109** `deferrals.md (CLOSED) / closed-divergences.md:1050` (cmd-output, STALE)
  - claim: `/usr/bin/grep -rn '200 char\|max 200\|<=200\|<= 200' generators/ skill-sources/ | wc -l   # 8`
  - stated: 8
  - measured: 10
  - suggested: `# 10 after closure — the two generators sites joined (8 at the audit)`
  - re-derive:

    ```text
    /usr/bin/grep -rn '200 char\|max 200\|<=200\|<= 200' generators/ skill-sources/ | awk 'END{print NR}'
    ```

- **W2-110** `deferrals.md (CLOSED) / closed-divergences.md:1101` (count, STALE)
  - claim: Statusless is now **0 of 2874**.
  - stated: 0 of 2874
  - measured: 13 statusless of 4955 nodes/*.md — all thirteen are `*-hub.md` (e.g. nodes/monomotapa-empire-hub.md)
  - suggested: `Statusless was **0 of 2874** at the migration commit; re-derived 2026-10-09 it is 13 of 4955, all `*-hub.md` graph hubs created after the backfill.`
  - re-derive:

    ```text
    /usr/bin/grep -rL '^status:' ~/second-brain/nodes/ | /usr/bin/grep -c .; find ~/second-brain/nodes -name '*.md' -type f | awk 'END{print NR}'
    ```

- **W2-111** `deferrals.md (CLOSED) / closed-divergences.md:1114` (cmd-output, STALE)
  - claim: `/usr/bin/grep -rL '^status:' ~/second-brain/nodes/ | grep -c .   # 0`
  - stated: 0
  - measured: 13
  - suggested: `# 0 at closure; 13 post-migration hub notes on 2026-10-09`
  - re-derive:

    ```text
    /usr/bin/grep -rL '^status:' ~/second-brain/nodes/ | /usr/bin/grep -c .
    ```

- **W2-112** `deferrals.md (CLOSED) / closed-divergences.md:1191` (cross-doc, DANGLING)
  - claim: **From:** CLAUDE.md divergence 5
  - stated: CLAUDE.md divergence 5
  - measured: CLAUDE.md no longer carries the divergence list (moved by dc96489, 2026-08-23); divergence 5 is at docs/open-divergences.md:268 and names check-prose-paths/session-orient 8 times
  - suggested: `**From:** divergence 5 (then in CLAUDE.md, now `docs/open-divergences.md`)` — and apply the same form to L135 and L151 for consistency.
  - re-derive:

    ```text
    /usr/bin/grep -c 'divergence 5' CLAUDE.md; /usr/bin/grep -n '^\*\*5\. ' docs/open-divergences.md; sed -n '268,482p' docs/open-divergences.md | /usr/bin/grep -c 'check-prose-paths\|session-orient'
    ```

- **W2-113** `deferrals.md (CLOSED) / closed-divergences.md:1200` (line-ref, STALE)
  - claim: The entry cited line 50; the fix is at line 56 and the content differs, so anchor on the phrase.
  - stated: line 56
  - measured: 57:WORK="/tmp/fence-isolation-gate-$SELF-$(printf '%s' "$$" | tr '0-9' 'abcdefghij')"
  - suggested: `the fix is at line 57 (56 when this closed)`
  - re-derive:

    ```text
    /usr/bin/grep -n 'WORK=' reference/test/fence-isolation.test.sh
    ```

- **W2-114** `deferrals.md (CLOSED) / closed-divergences.md:73` (cmd-output, STALE)
  - claim: docs/closed-divergences.md: `for s in bash zsh; do $s reference/test/kernel-note-dirs.test.sh | tail -1; done   # 37/37, was 36/36`
  - stated: 37/37
  - measured: kernel-note-dirs-bash passed=76 failed=0; kernel-note-dirs-zsh passed=76 failed=0
  - suggested: `# 76/76 today; 37/37 on this branch, was 36/36`
  - re-derive:

    ```text
    /usr/bin/grep -E 'kernel-note-dirs' …/scratchpad/baseline/summary.txt
    ```

- **W2-115** `deferrals.md (CLOSED) / closed-divergences.md:140` (count, STALE)
  - claim: docs/closed-divergences.md: **The three declared sites live in two files, and two of them are the same file** — `.claude-plugin/plugin.json` (`version`) and `.claude-plugin/marketplace.json` twice
  - stated: three declared sites in two files
  - measured: `files` has 4 entries in 3 files (+ `.codex-plugin/plugin.json` `version`, added 7d5f66a 2026-08-16) and `text` has 3 globs (README.md, skills/*/SKILL.md, skill-sources/*/SKILL.md; 61f86d9 2026-08-25)
  - suggested: `**The three declared sites lived in two files when this branch closed (four JSON sites in three files plus three text globs today), and two of them were the same file**`
  - re-derive:

    ```text
    sed -n '2,12p' .version-bump.json; git log --format='%h %ad %s' --date=short -- .version-bump.json | head -2
    ```

- **W2-116** `deferrals.md (CLOSED) / closed-divergences.md:164` (cmd-output, STALE)
  - claim: docs/closed-divergences.md: `for s in bash zsh; do $s reference/test/bump-version.test.sh | tail -1; done   # 41/41, was 28/28`
  - stated: 41/41
  - measured: passed=53 failed=0 under both shells
  - suggested: `# 53/53 today; 41/41 on this branch, was 28/28`
  - re-derive:

    ```text
    /usr/bin/grep -E 'bump-version' …/scratchpad/baseline/summary.txt
    ```

- **W2-117** `deferrals.md (CLOSED) / closed-divergences.md:269` (cross-doc, DANGLING)
  - claim: docs/closed-divergences.md: The class is live there; that recipe is among the unconverted ones noted in the open list above.
  - stated: the open list above
  - measured: nothing 'above' in this file names it; the open list is docs/open-divergences.md, where line 814 (inside divergence 15, which starts at 800) names `methodology-knowledge.md:31`
  - suggested: `noted in the open list in `docs/open-divergences.md`, under the divergences 7–9 stub ('What is still open, and was never in these three entries')`
  - re-derive:

    ```text
    /usr/bin/grep -n 'methodology-knowledge' docs/closed-divergences.md docs/open-divergences.md
    ```

- **W2-118** `deferrals.md (CLOSED) / closed-divergences.md:323` (line-ref, STALE)
  - claim: docs/closed-divergences.md: The queue-file greps (`skill-sources/stats:329-330`, `tasks:86-87`, `next:215`) are also unconverted
  - stated: stats:329-330, tasks:86-87, next:215
  - measured: stats:328-329 (330 is `elif`); tasks:86-87 holds; next has NO status grep on its queue file — :215 is the `exit 1` of a no-queue-file error, and its only queue grep is `grep -c .` at :369
  - suggested: `(`skill-sources/stats:328-329`, `tasks:86-87`, `next:368-369`)`
  - re-derive:

    ```text
    /usr/bin/grep -n "grep -c 'status: \(pending\|done\)'" skill-sources/stats/SKILL.md skill-sources/tasks/SKILL.md skill-sources/next/SKILL.md; sed -n '213,217p' skill-sources/next/SKILL.md
    ```

- **W2-119** `deferrals.md (CLOSED) / closed-divergences.md:361` (line-ref, STALE)
  - claim: docs/closed-divergences.md: leaving two survivors (`skills/health/SKILL.md:661` and `reference/testing-milestones.md:425`). Divergence 12's residual table adds two sites … (`skill-sources/graph/SKILL.md:789`, `:794`)
  - stated: health:661, graph:789, graph:794
  - measured: health:661 is a report-table row (`| All {vocabulary.topic_maps} in 5-50 range …`); the `rg '^\s*- \[\['` shape matcher is at :670. graph:789 is `Supported query patterns:`; the `rg '^topics:.*\[\[X\]\]'` row is at :798 and the query table spans :797-803. testing-milestones:425 still holds `grep -rl "\[\[$TITLE\]\]"`
  - suggested: `skills/health/SKILL.md:670` … `skill-sources/graph/SKILL.md:798`, `:803`. (docs/open-divergences.md divergence 12's table at 651-655 carries the same 661/789/794 and should move with it.)
  - re-derive:

    ```text
    sed -n '661p;670p' skills/health/SKILL.md; sed -n '789p' skill-sources/graph/SKILL.md; /usr/bin/grep -n 'topics:.*\\[\\[X' skill-sources/graph/SKILL.md; sed -n '425p' reference/testing-milestones.md
    ```

- **W2-120** `deferrals.md (CLOSED) / closed-divergences.md:364` (count, STALE)
  - claim: docs/closed-divergences.md: for **four** residual sites total, only two of them executable (and L435-436: `four residual today, only two of them executable — the other two are documentation-table rows`)
  - stated: four
  - measured: divergence 12 now states `The decomposition is 9 = 2 + 1 + 1 + 5` and `Those last five arrived with moc-sync.test.sh and took this count from 4 to 9`; its table has 5 rows, the fifth `reference/test/moc-sync.test.sh ×5`
  - suggested: L364: `for **four** residual sites when that round closed (divergence 12 now decomposes **9 = 2 + 1 + 1 + 5**, the five being `moc-sync.test.sh` assertions)`; L435-436: `nine residual today per divergence 12's `9 = 2 + 1 + 1 + 5` — two documentation-table rows, two executable (one non-interpolating, one interpolating) and five `moc-sync.test.sh` assertions`
  - re-derive:

    ```text
    sed -n '647p;655p' docs/open-divergences.md; sed -n '587,738p' docs/open-divergences.md | /usr/bin/grep -n 'from 4 to 9'
    ```

- **W2-121** `deferrals.md (CLOSED) / closed-divergences.md:415` (status, STALE)
  - claim: docs/closed-divergences.md: Whether to lift the cap is open; see divergence 11.
  - stated: is open
  - measured: open-divergences.md:581 `**11. The dangling-link check sampled 100 links and did not scan them all — FIXED on …`; the closure is this file's first entry (L16, `Closed on fix/exhaustive-dangling-scan`)
  - suggested: `Whether to lift the cap was left open here; it was lifted on `fix/exhaustive-dangling-scan` — see divergence 11 above.`
  - re-derive:

    ```text
    /usr/bin/grep -n '^\*\*11\. ' docs/open-divergences.md; /usr/bin/grep -n 'divergence 11' docs/closed-divergences.md | head -1
    ```

- **W2-122** `deferrals.md (CLOSED) / closed-divergences.md:423` (cross-doc, DANGLING)
  - claim: docs/closed-divergences.md: See the Verification section above for the residual that was left open on purpose.
  - stated: the Verification section above
  - measured: the only 'Verification' in this file is this sentence (line 423); the fence-gate allowlist residual (two `ZSH ONLY:` entries, known-open=3 bash / 5 zsh) is documented in docs/verification.md around lines 153-186
  - suggested: `See the fence-isolation notes in `docs/verification.md` (the Verification section, moved out of CLAUDE.md) for the residual that was left open on purpose.`
  - re-derive:

    ```text
    /usr/bin/grep -n 'Verification' docs/closed-divergences.md; /usr/bin/grep -n 'ZSH ONLY' docs/verification.md | head -2
    ```

- **W2-123** `deferrals.md (CLOSED) / closed-divergences.md:451` (count, STALE)
  - claim: docs/closed-divergences.md: **28 was that branch's number; the suite is at 41 today**
  - stated: 41 today
  - measured: passed=53 under both shells
  - suggested: `the suite is at 53 today` (and 'raised by divergence 2's fix' → 'raised by divergence 2's fix and then by the text-site work in 61f86d9')
  - re-derive:

    ```text
    /usr/bin/grep -E 'bump-version' …/scratchpad/baseline/summary.txt
    ```

- **W2-124** `deferrals.md (CLOSED) / closed-divergences.md:453` (count, STALE)
  - claim: docs/closed-divergences.md: a reader who takes it as current will be 13 assertions behind
  - stated: 13
  - measured: 25
  - suggested: `25 assertions behind`
  - re-derive:

    ```text
    printf '%d\n' $((53-28))
    ```

## Not verifiable in the tree (61)

Claims about GitHub, CI runs, external tools or host runtimes. Listed, not judged.

- **W1-8** `README.md:58` — Codex's has never been run at all. _(Claim is about an external runtime event; the tree can only show nothing contradicts it. OpenCode 1.14.24 and pi 0.84.1 measurements on lines 59-63 counted HISTORICAL (opencode version is recorded at )_
- **W1-18** `README.md:254` — [qmd](https://github.com/tobi/qmd) ... `npm install -g @tobilu/qmd` (lines 254, 262, 264, 308) _(External URL and npm package name; no network. The two spellings (tobi vs tobilu) cannot be reconciled from the tree.)_
- **W1-19** `README.md:299` — [Claude Code] v1.0.33+ | Yes | Plugin host _(No in-tree artifact states or enforces a minimum Claude Code version, so the figure can be neither confirmed nor contradicted.)_
- **W1-20** `README.md:454` — | Multi-agent processing | In progress | _('In progress' describes intent, which line 458 says this table does not do; nothing in the tree marks it as either underway or shipped. Could not decide; flag for the author.)_
- **W1-21** `README.md:474` — Built on [Tools for Thought for Agents](https://github.com/agenticnotetaking) research. _(External link; no network. The org name matches .claude-plugin/marketplace.json `name: agenticnotetaking` and LICENSE `Copyright (c) 2026 agenticnotetaking`.)_
- **W1-26** `CONTRIBUTING.md:99` — bash reference/check-doc-claims.sh ; expect rc=0 _(baseline pending (brief forbids running the gate).)_
- **W1-27** `CONTRIBUTING.md:102` — bash reference/check-skillevaluator.sh ; expect rc=0 (rc=2 = precondition missing) _(baseline pending; also needs NVIDIA_API_KEY and scanners, which are outside the tree.)_
- **W1-28** `CONTRIBUTING.md:103` — bash reference/test/check-doc-claims.test.sh | tail -1  # expect: passed=13 failed=0 _(baseline pending; static count agrees with 13, failed=0 not provable without a run. Bash-only claim is CURRENT (header lines 28-32, guard at line 66).)_
- **W1-29** `CONTRIBUTING.md:35` — `grep -P` works in the Claude Code Bash tool — you are seeing ugrep, not /usr/bin/grep (table rows 35 and 64: 'ugrep (shell function)', 'works, exit 1') _(Environment claim, not a tree claim; it depends on the session's shell snapshot and CLAUDE_CODE_EXECPATH. The wrapper mechanism exists; the observed behavior differs here.)_
- **W1-30** `CONTRIBUTING.md:72` — Trap 3 — `gh run list --branch` on a fork returns EMPTY; `gh api repos/<you>/arscontexta/actions/runs --jq .total_count` is the truth _(GitHub state; consistent with memory note 'gh resolves forks to upstream'.)_
- **W1-31** `CONTRIBUTING.md:120` — ./reference/validate-kernel.sh <your-vault>  # expect: every primitive PASSes _(Requires a generated vault; lines 129-154 themselves qualify it with permitted WARNs.)_
- **W1-32** `CONTRIBUTING.md:122` — all CI steps pass _(GitHub run state.)_
- **W1-33** `CONTRIBUTING.md:138` — C1 ... FAILs on the field vault today _(needs a validate-kernel run against ~/second-brain.)_
- **W1-34** `CONTRIBUTING.md:150` — the maintainer's own vault currently WARNs on primitive 1 (frontmatter coverage) and primitive 2 (unresolved wiki links) _(baseline pending / run forbidden.)_
- **W1-35** `CONTRIBUTING.md:159` — gh api .../jobs --jq '[.jobs[].steps[]|select(.conclusion!="success")]|length'   # expect 0 _(GitHub state. Note the jq query also counts runner-injected steps (Set up job, Post checkout, Complete job), so 'thirty-two' is the workflow-defined count, not what `.jobs[].steps[]` returns.)_
- **W1-53** `docs/verification.md:3` — the harness auto-loads only the first ~40,000 characters of a CLAUDE.md _(Also dated to the 2026-08-23 split; the 112,522-byte figure is HISTORICAL.)_
- **W1-54** `docs/verification.md:23` — bash reference/check-doc-claims.sh                       # exit 0 (declared claims only) _(baseline pending. The gate is forbidden to run here (it runs 17 suites, ~270s).)_
- **W1-55** `docs/verification.md:26` — bash reference/check-skillevaluator.sh                   # exit 0; 2 = a precondition is missing _(The exit-2 semantics (die2, CANNOT CONCLUDE, incomplete_scans) are CURRENT in the script.)_
- **W1-56** `docs/verification.md:86` — skillspector flags 13 HIGH findings against a repo whose purpose is writing skills _(Consistent with the script; not re-measurable offline.)_
- **W1-57** `docs/verification.md:94` — the field vault holds 16 notes that any one of the three competing section maps would have dropped ... ~40 entries would otherwise be destroyed _(Reads as a dated field measurement; leave as-is unless WF2 wants it tagged with a date.)_
- **W1-62** `docs/verification.md:260` — primitive 2, `8 unresolved wiki links out of 2716 unique checked` _(Message format `N unresolved wiki links out of M unique checked` confirmed at validate-kernel.sh (warn in primitive 2 block), so the shape is current; only the numbers are unverified.)_
- **W1-63** `docs/verification.md:295` — ./reference/validate-kernel.sh ~/second-brain ... | grep -E '^ +(PASS|WARN|FAIL) '   # 18 result lines _(Baseline has no validate-kernel log (baseline pending).)_
- **W2-15** `docs/open-divergences.md:266` — `/arscontexta:upgrade` has no recorded slash-command invocation against a real vault
- **W2-29** `docs/open-divergences.md:391` — with a complete ledger (16 completion lines, `final-review.md`) _(In the 'Measured 2026-08-03' column so dated/HISTORICAL by the brief; recorded only because the pointer cannot be resolved anywhere on disk.)_
- **W2-42** `docs/open-divergences.md:671` — a bracket-counting `rg -o '\[\['` that was never the extraction class to begin with, and that class is now empty _(Could not decide without a judgment call. stats:118 was added by a5e127e on 2026-08-01 — the commit that converted stats to the shared library — so it predates entry 13's closure claim and was evident)_
- **W2-60** `docs/superpowers/deferrals.md:170` — that is the plan which shipped this vocabulary, as PR #9 _(The plan file itself exists at docs/superpowers/plans/archive/2026-08-15-note-lifecycle-and-description-convention.md; only the PR number is unverifiable.)_
- **W2-68** `docs/superpowers/deferrals.md:229` — **From:** `2026-08-08-link-edge-map.md` final whole-branch review _(A review event, not a section anchor; nothing in the tree confirms or contradicts it.)_
- **W2-69** `docs/superpowers/deferrals.md:293` — On the field vault C1 reports 13 violations and names 5. _(Present-tense field-vault measurement from the 2026-08-05 plan; re-deriving requires running validate-kernel.sh against ~/second-brain.)_
- **W2-70** `docs/superpowers/deferrals.md:328` — **From:** task 12a (`.superpowers` report, promoted here per divergence 10 ...) _(Outside the tree by design (divergence 10's own subject). The tracked half of the pointer resolves: plans/archive/2026-08-09-post-merge-hardening.md `## Deferrals` at :1671 lists Task 12a at :1722.)_
- **W2-82** `docs/superpowers/deferrals.md:433` — **From:** Task 14 (`.superpowers/sdd/2026-08-09-post-merge-hardening/task-14-report.md`) — also cited at line 491 _(Provenance pointer to a deliberately untracked ledger (divergence 10's subject); not resolvable from any clone. Not a DANGLING verdict because it is the documented convention, but readers of a clean c)_
- **W2-84** `docs/superpowers/deferrals.md:541` — **From:** Task 15 (`.superpowers/sdd/2026-08-09-post-merge-hardening/task-15-brief.md`) — same for :581 task-19-brief.md, :634 task-11-report.md, :681 final-triage.md _(By design outside the tree (entry 28 itself calls the task-11 report 'gitignored'). Not DANGLING in the repo sense; no edit suggested.)_
- **W2-91** `docs/superpowers/deferrals.md:606` — no vault has reported customization lost to the replace path
- **W2-99** `docs/superpowers/deferrals.md:725` — **From:** `.superpowers/sdd/2026-08-09-post-merge-hardening/final-triage.md` _(Gitignored session ledger, by the entry's own description; outside the tree, nothing to refresh.)_
- **W2-100** `docs/superpowers/deferrals.md:822` — the measured guard matrix is in the branch's ledger _(Historical by context (the script is deleted at HEAD); only the pointer's target is unreachable from this tree.)_
- **W2-137** `docs/superpowers/next-sprints.md:206` — 10, 21, 24 — routed to docs/superpowers/specs/archive/2026-08-04-ci-hardening-design.md. Do not plan these twice.
- **W4-3** `.codex-plugin/INSTALL.md:29` — The install lands in `$CODEX_HOME/plugins/cache/<marketplace>/<plugin>/<version>/` and is a copy of the whole repository _(Out of the lens (host runtime, not a repo artifact); the sentence is framed by line 40 as measured on codex-cli 0.146.0.)_
- **W4-4** `.codex-plugin/INSTALL.md:185` — `codex plugin marketplace upgrade <name>` refreshes a Git marketplace snapshot, then `codex plugin add` installs the refreshed version; re-running `marketplace add` reports `alreadyAdded: true` (line  _(Covers lines 123-124 and 185-191. The text itself says 'Neither upgrade path was measured'. Out of the lens.)_
- **W4-5** `reference/hosts/codex-tools.md:28` — it is absent from the tool-mapping conventions this document mirrors _(Pointer to an unnamed external source; cannot resolve inside the tree.)_
- **W4-8** `reference/hosts/opencode-tools.md:27` — the convention this file mirrors ships no OpenCode tool-mapping document at all _(Also phrased as a present-tense claim about a third-party repo; it will rot without any diff here. Consider dating it ("as of 2026-08") so it reads as HISTORICAL.)_
- **W4-11** `.pi/INSTALL.md:125` — **Do not substitute `/reload`.** It is documented for extensions, and this install registers no extension — whether it re-runs package discovery is not established here _(Pi-runtime claim, outside the repo lens; recorded because the sentence's premise ('documented for extensions') is narrower than the local Pi docs. Every other Pi-side claim in both files (convention `)_
- **W4-15** `platforms/README.md:28` — During plugin packaging (Section 18 of the PRD), the build process references `platforms/`
- **W4-22** `platforms/claude-code/generator.md:70` — Vocabulary changes via /reseed take effect immediately.
- **W4-30** `platforms/claude-code/hooks/README.md:72` — Hooks ... can be modified by /architect or /reseed
- **W4-37** `platforms/shared/features/README.md:47` — Each block has a defined layer, dependencies, and platform requirements
- **W4-71** `reference/AUDIT-REPORT.md:5` — **PRD Section:** 15 — Reference Document Structural Template
- **W4-83** `reference/three-spaces.md:143` — | `user-overrides.md` | User customizations that reseed must preserve as immutable | Semi-permanent ... | (also in the ops/ layout at line 269) _(Out of the lens strictly (vault layout rather than a repo artifact), so left UNVERIFIABLE rather than STALE; the measurement is included so the parent can decide.)_
- **W4-120** `reference/derivation-validation.md:454` — In v1.6, all vaults ship with full automation from day one. _('v1.6' is an upstream methodology-version label (also in reference/evolution-lifecycle.md:148,152 and vault stamps `arscontexta-v1.6`); it maps to nothing in this tree. Recurs at line 485.)_
- **W4-129** `reference/derivation-validation.md:9` — Test 1 and Test 4 describe 'our actual vault' (01_thinking/, 00_inbox/, 03_twitter/people/, 04_meta/logs/, Cornelius/Heinrich dual operators, qmd with 4 collections, .claude/hooks/ with 10+ hooks) _(Out of the lens by design (vault, not repo artifact); recorded once so the parent knows they were seen and not judged. Lines 9-47, 241-252.)_
- **W4-156** `reference/evolution-lifecycle.md:116` — Every generated system must include ops/user-overrides.md ... The reseed process reads user-overrides.md first and treats its contents as hard constraints _(Phrased as 'must', so not STALE under the DSL; reported because the artifact it names is never generated.)_
- **W4-157** `reference/evolution-lifecycle.md:246` — The vault's reconcile.sh is idempotent and side-effect-free. (also line 54 'system-changelog.md pattern', line 76 '5+ observations trigger review', line 140 'infrastructure-ideas.md pattern')
- **W4-158** `reference/session-lifecycle.md:76` — Vault /review skill (line 76); 00_inbox/ (line 96); 04_meta/logs/ (line 266); 'checkpoint during traversal' and 'handling discoveries during work' working techniques (lines 86, 214); Vault `.claude/ho
- **W4-159** `reference/self-space.md:124` — The vault's self/memory/ uses the same atomic note + MOC structure as 01_thinking/ (line 124); The vault's CLAUDE.md places critical session instructions in the first 20% of the file (line 166); Vault
- **W4-166** `reference/open-questions.md:47` — The local MCP server (`npx arscontexta-mcp`) works for v1 (and line 45: provides arscontexta_query/_recommend/_dimensions tools) _(If the npm package does not exist, lines 39, 41, 45 and 47 all describe a component this repo does not ship; verify off-network before editing.)_
- **W4-169** `reference/open-questions.md:233` — Our vault's CLAUDE.md is ~30KB. Generated context files are 5-15KB depending on feature blocks. _(If the sentence is meant to describe the field-test vault, ~83KB is the current figure.)_
- **W4-178** `reference/tradition-presets.md:183` — tier-1 platforms (Claude Code) should prompt the user about adding hooks-blueprint and validation-hooks _(Cannot show the names were ever concrete artifacts, so not DANGLING; and setup Step 3g says all hooks are generated for everyone, so the 'prompt to add' framing is likely stale alongside line 181.)_
- **W4-179** `reference/tradition-presets.md:171` — Research → primarily Zettelkasten, with Cornell processing phases (the 6 Rs) _(Reported only because it is an intra-file contradiction (line 95 vs 171); no repo artifact decides it.)_
- **W4-180** `reference/semantic-vs-keyword.md:268` — **Source:** Vault CLAUDE.md "Which mode for which skill" table _(Source attribution to a vault file; outside the repo-artifact lens, flagged because the repo has a direct equivalent it could point at.)_
- **W4-181** `reference/semantic-vs-keyword.md:150` — The vault's Phase 0 freshness check pattern should be adapted … The Phase 0 freshness check was added after search results missed recently created notes (also line 202: 'The vault's Phase 0 freshness  _(Vault-state claim, outside the artifact lens; no repo artifact carries a freshness check by that name.)_
- **W4-182** `reference/semantic-vs-keyword.md:17` — Tier-1 (Claude Code with MCP) … Tier-2 (CLI tools) … Tier-3 (convention only) _(Skill-sources' 'Tier 1/2' are tool-fallback tiers (MCP → CLI → grep) and still exist; it is the platform-tier concept that setup contradicts itself on.)_
- **W4-183** `reference/semantic-vs-keyword.md:287` — - Sources reviewed: 22
- **W4-184** `reference/personality-layer.md:259` — emotional_awareness: emotionally_attentive  # task-focused | emotionally_attentive (in the ops/derivation.md encoding block, lines 254-266) _(Not STALE: the two YAML blocks describe different files and derivation.md has no pinned schema; flagged so the editor can decide whether to unify the enum spelling.)_

## Refuted by the skeptic (35)

Flagged by a verifier, overturned on re-measurement or as dated/scoped. Kept here so the next pass does not re-raise them.

- **W1-0** `CLAUDE.md:6` — Agent execution rules belong in `.claude/CLAUDE.md` — _The sentence is normative ("belong in"), not a path claim, and sits in a blockquote describing where each kind of guidance goes. The target is not "gone or moved" (brief's DANGLING definition): it has never existed on any ref, including 49b64e9 (2026-08-02), t_
- **W1-2** `CLAUDE.md:18` — There is no build, no test runner, no dependency manifest. — _In this repo's own vocabulary "test runner" means runner tooling, and none exists: no `make test`, no script that loops over the suites (the only iteration over reference/test/*.test.sh is check-doc-claims.sh:146, which counts them for an inventory check), and_
- **W1-6** `README.md:32` — Answer 2-4 questions about your domain (~20 minutes -- token-intensive but one-time) — _The two docs really do disagree (README '~20 minutes' vs skills/setup/SKILL.md:136 'about 5 minutes'), but that is a cross-doc inconsistency, not a STALE README claim. STALE requires a measurement contradicting the doc; no command in the tree can derive the se_
- **W1-7** `README.md:108` — The whole process takes about 20 minutes. It's token-intensive because the engine reads research claims — _Same contradiction as idx 0, second occurrence. The sentence is at README.md:112 in this tree, not 108 (line 108 is the Derivation table row). The skill's 'about 5 minutes' on the Phase 1.5 onboarding screen is an estimate, not a measurement, and both figures _
- **W1-9** `README.md:218` — There is no `Stop` hook and no `session-capture.sh` — _The sentence is scoped by its section. README:207-209 opens '## Hooks' with 'Three hooks are registered in `hooks/hooks.json`:', and the clause continues '; `hooks/scripts/` also holds `vaultguard.sh` and `read_config.sh`' -- the subject throughout is the plug_
- **W1-12** `README.md:300` — | `tree` | Yes | Workspace structure injection | — _The verifier measured one consumer (the SessionStart hook) and generalised. The plugin's own install procedures treat `tree` as a hard prerequisite: .pi/INSTALL.md:62-69, .codex-plugin/INSTALL.md:51-60 and .opencode/INSTALL.md:85-92 each loop `for t in rg tree_
- **W1-58** `docs/verification.md:218` — The eighth check is kernel validation, which does **not** run in CI, because it needs a generated vault to run against. — _The claim is correct under the doc's own gated definition of 'run in CI'. `truth_ci_run_checks` (reference/check-doc-claims.sh:240) counts unique `run: (bash|zsh) reference/...` targets; reproducing that grep yields exactly 16 of the 19 check files, and `valid_
- **W1-60** `docs/verification.md:250` — `13 of 34 outcome-status notes name no target` ... `13 = 6 implemented + 7 promoted` ... misses its field 7 times in 8, against 6 in 26 for `implemented` — _HISTORICAL, not STALE. The paragraph is branch-scoped by its own lead-in at line 247 ('Re-measured on `fix/exhaustive-dangling-scan`: `15 PASS / 2 WARN / 1 FAIL`'), and lines 254-256 say the figures 'drift; re-derive with the command below rather than quoting _
- **W1-61** `docs/verification.md:259` — primitive 1, frontmatter coverage — `5128 with YAML, 163 without` — _HISTORICAL, not STALE, for the same reason as idx 2: line 259 ('The two survivors are primitive 1 ... `5128 with YAML, 163 without`') continues the measurement block that line 247 scopes to `fix/exhaustive-dangling-scan`, and the section tells the reader to re_
- **W2-4** `docs/open-divergences.md:40` — each run already costs three invocations of the ~100s script it tests — _Not confirmable as a doc defect under the brief's rule. Wall-clock is an environment property, not a tree property; I am barred from running the gate so I have no measurement of my own, and the baseline is a single sample taken while the whole gate/suite batch_
- **W2-21** `docs/open-divergences.md:326` — list_notes_by_field ~/second-brain/ops/observations status pending open | grep -c .   # 14 — _Measured 84 open observations (verifier's 84 confirmed), so the figure has moved — but the doc already scopes it as a snapshot: line 301 says 'measured at 14 open observations and 8 open tensions', the table column is headed 'At 14 / 8', and the fence header o_
- **W2-22** `docs/open-divergences.md:327` — list_notes_by_field ~/second-brain/ops/tensions status pending open | grep -c .   #  8 — _Measured 4 open tensions (verifier's 4 confirmed). Same scoping as idx 5: 'measured at … 8 open tensions' (line 301) and the fence header's 'all four figures drift' flag the comment as a dated snapshot that the table's reasoning is built on. HISTORICAL; no edi_
- **W2-48** `docs/open-divergences.md:846` — the tension enum is now `:218` with eight values — _HISTORICAL, not DANGLING. Line 846 is inside the paragraph headed `**AMENDED 2026-08-05 —` and is explicitly branch-scoped ('changed by Task 1 of this branch'); it was authored by a3019ee (2026-08-05) on fix/spec-h-enforcement-gap. At that branch's commits of _
- **W2-85** `docs/superpowers/deferrals.md:560` — (`git tag` returns 0, still true) — _Measurement agrees with the verifier (7 tags), but the claim is already a dated record: entry 27's addendum at :596-598 is headed 'Evidence stale as of 2026-08-26' and states '`git tag` now returns 7, not 0 ... backfilled 2026-08-25', with its own `# 7` bash l_
- **W2-87** `docs/superpowers/deferrals.md:585` — git tag | wc -l   # 0 — no release tags — _Measurement agrees (7), but :585 is the original evidence block that the entry's dated addendum (:596, 'Evidence stale as of 2026-08-26') explicitly supersedes with its own `git tag | wc -l   # 7` at :609. Per the doc's stated convention (entry 28, :647-648: o_
- **W2-90** `docs/superpowers/deferrals.md:591` — | sort | uniq -c   # 10 x arscontexta-v1.6, of 16 skills; the other 6 carry no stamp line — _Measurement agrees with the verifier: the field vault's 16 skills all carry `generated_from: "arscontexta-0.10.0"` and 0 are unstamped. But :591 is in the original evidence block that the dated addendum (:596-600) explicitly declares moved: 'The stamps are no _
- **W2-92** `docs/superpowers/deferrals.md:616` — `hooks/scripts/session-orient.sh:159` computes `TENS_TOTAL` with `find -H` ... `OBS_TOTAL`'s (`:158`) — _Measurement agrees (OBS_TOTAL at :194, TENS_TOTAL at :195, a third find -H at :177), but entry 28's own addendum at :645-649 is headed 'Line citations stale as of 2026-08-26', states 'Every :158 and :159 above now reads :194 and :195', and explicitly says 'The_
- **W2-93** `docs/superpowers/deferrals.md:638` — /usr/bin/grep -n 'find -H ops/' hooks/scripts/session-orient.sh   # :158 observations, :159 tensions — _Same as idx 9: the `# :158 observations, :159 tensions` comment is in the original block whose addendum (:645-654) supersedes it with `# :177 loop, :194 obs, :195 tensions` and states the originals are left standing by design. Measurement agrees (194/195) but _
- **W4-2** `reference/hosts/codex-tools.md:3` — The plugin's ten skills declare `allowed-tools:` using Claude Code's tool names. [mapping table lists Read, Write, Edit, Bash, Grep, Glob, AskUserQuestion only] — _Measurement matches the verifier's numbers (5 of 10 skills declare `mcp__qmd__query`; 4 of those also `mcp__qmd__get`/`mcp__qmd__multi_get`; no `qmd` or `mcp__` string in reference/hosts/, with `Read` as positive control in all 3 files), but no sentence in the_
- **W4-7** `reference/hosts/opencode-tools.md:6` — The mapping table (lines 6-13) presents itself as covering what the ten skills' `allowed-tools:` say, but omits `mcp__qmd__query`, `mcp__qmd__get`, `mcp__qmd__m — _Omission, not contradiction. The measurement is right (6 of 10 skills declare mcp__qmd__* in allowed-tools: architect, ask, health, recommend, reseed, and health declares only mcp__qmd__query — my count also gives 6), but no sentence in the doc is contradicted_
- **W4-44** `reference/skill-authoring.md:46` — Four families. ... and `{if …}` … `{endif}` for conditional blocks. — _The verifier's measurement is wrong: `{endif}` is not confined to two frozen headers. It appears in 10 of the 16 frozen platforms/shared/skill-blocks/ files, 29 markers in total, as real conditional blocks (reflect.md 7, verify.md 6, reduce.md 5, reweave.md 3,_
- **W4-72** `reference/AUDIT-REPORT.md:61` — The following files exist in `reference/` but are not among the 16 PRD-specified documents: (claim-map.md, components.md, methodology.md) — _HISTORICAL. reference/AUDIT-REPORT.md is headed '**Auditor:** Heinrich … **Date:** 2026-02-13' (lines 3-4) and nothing in the repo references it (0 referrers), so it is a dated audit snapshot, not a live inventory; the brief says dated records are true-as-of-t_
- **W4-73** `reference/AUDIT-REPORT.md:69` — Additionally, the following non-document items exist in `reference/`: templates/ ... validate-kernel.sh — _HISTORICAL, same dated-report basis as idx 22. The two named items (templates/, validate-kernel.sh) still exist; the list is non-exhaustive today (15 non-.md entries) but describes the 2026-02-13 tree._
- **W4-74** `reference/AUDIT-REPORT.md:104` — Also includes use-case presets table, mixing rules, and preset selection algorithm.  (tradition-presets.md) — _HISTORICAL / UNVERIFIABLE. The report is dated 2026-02-13; tradition-presets.md was first committed 2026-02-16 (4be327e) and even that first committed version has 0 'algorithm' hits, so the sentence never matched any committed tree, but I cannot see the 02-13 _
- **W4-75** `reference/AUDIT-REPORT.md:174` — **What it has:** Seven use-case presets (Research, Therapy, PM, Creative, Learning, Companion, Relationships) — _HISTORICAL / UNVERIFIABLE on the same basis as idx 24: use-case-presets.md already had '## Three Use-Case Presets' (Research, Personal Assistant, Experimental / Build Your Own) in its first commit 4be327e, three days after the report's date, so the seven-prese_
- **W4-76** `reference/AUDIT-REPORT.md:186` — It is referenced by 5+ other reference documents.  (three-spaces.md) — _HISTORICAL (dated report). Measurement confirms 4 other reference docs mention three-spaces today (both a loose 'three.spaces?' and a literal 'three-spaces' grep give the same four), so '5+' is not true of this tree, but the sentence is part of the 2026-02-13 _
- **W4-77** `reference/AUDIT-REPORT.md:192` — It is referenced by session-lifecycle.md, self-space.md, and use-case-presets.md.  (personality-layer.md) — _HISTORICAL (dated report). Measurement confirms the verifier: today personality-layer is referenced by open-questions.md, self-space.md, session-lifecycle.md, three-spaces.md and not by use-case-presets.md (0 hits, also 0 at 4be327e). Still a 2026-02-13 ration_
- **W4-78** `reference/AUDIT-REPORT.md:224` — use-case-presets.md references tradition-presets.md directly — _HISTORICAL / UNVERIFIABLE on the same basis as idx 24/25: use-case-presets.md contains no 'tradition-presets' string now or at its first commit 4be327e (its only .md reference is interaction-constraints.md at line 266; positive control: 'tradition' appears as _
- **W4-79** `reference/components.md:216` — ## Sleep Skill — Nightly Processing Pipeline / **Conditional component:** Enabled when processing >= moderate AND platform supports scheduling. — _Out-of-lens. reference/components.md is a blueprint document (line 3: 'How to build each component of a knowledge system... Blueprints teach understanding so agents can self-extend'); the Sleep Skill section (214-236) has no 'How to implement' block and never _
- **W4-81** `reference/three-spaces.md:9` — **Enforcement:** Configurable. Off by default for research vaults, on by default for personal assistant vaults. Toggled via /architect. — _The verifier read 'Toggled via /architect' as claiming a dedicated toggle path; the sentence only says the toggle goes through /architect, which is how the skill works: it generates recommendations and, on approval, implements them (SKILL.md:52 'Present to use_
- **W4-93** `reference/testing-milestones.md:202` — only emit semantic-search section when `search >= 0.5` — _Out of lens. Line 202 is the Fix column of a 'Common failure modes' table — a remediation recommendation for a hypothetical 'block included unconditionally' bug, not a claim that a `search >= 0.5` rule exists. The verifier's 'no such rule anywhere' is true but_
- **W4-103** `reference/derivation-validation.md:12` — Use case: Research & Academic ... Derived configuration (from use-case preset) — _Not a claim about the preset's name. 'Research & Academic' is a live domain label in this repo — methodology/'prevent domain-specific failure modes through the vulnerability matrix.md' line 195 is the heading '### Research & Academic'. Line 12 states the use c_
- **W4-150** `reference/evolution-lifecycle.md:297` — `components.md` (self-extension principle and hook/skill blueprints) — _Refuted. The verifier grepped only the noun phrase 'self-extension'; components.md states the principle in verb form at line 3: 'Blueprints teach understanding so agents can self-extend.' (`grep -ci 'self-extend'` = 1). That is the self-extension principle (me_
- **W4-165** `reference/open-questions.md:31` — Currently focused on Claude Code as the sole supported platform. — _Out-of-lens. Read in context (lines 28-32), deferred item 3 is 'Supporting additional agent platforms beyond Claude Code, with shared notes/ and self/' for generated vaults, and the flagged sentence sits inside its 'Why deferred' paragraph. That scope is still_
- **W4-171** `reference/open-questions.md:268` — the reseed audit mode flags it — _Verifier's measurement is wrong on a load-bearing point: skills/reseed/SKILL.md DOES declare an argument-hint at line 7, '[optional: --analysis-only to see drift report without implementing]', honoured at lines 269-271 ('If --analysis-only was specified: Stop _
