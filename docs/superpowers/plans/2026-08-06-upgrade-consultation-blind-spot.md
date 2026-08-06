# Plan — Spec I: `/upgrade`'s modification test is blind to committed local patches

Spec: `docs/superpowers/specs/2026-08-06-upgrade-consultation-blind-spot-design.md`

## Global Constraints

- **Execution model:** implement directly; dispatch reviews on opus, reviewers in separate
  worktrees (`isolation: worktree`). Implementer subagents have died of autocompact thrashing in
  this repo 3/3; reviewers survive large packages.
- **`~/second-brain` is READ-ONLY.** Copies and fixtures only, deleted after use. No task here
  writes to it. Every fixture below is built fresh under a temp dir, never against the live vault.
- **No git tags exist in this repo** (`git tag` returns empty). Task 4's "no OLD-rendering
  available" branch is not a workaround for a temporary gap — it is the real behavior every
  invocation of `/upgrade` gets today, and stays that way until a separate tagging effort lands
  (deferred; see below).
- **The defect class is silent failure.** Any halt this plan adds must name the skill and the
  exact missing lookup — never a bare skip, never "if available" with no else-branch.
- **Both bash and zsh.** `reference/test/fence-isolation.test.sh` already extracts fences from
  `skills/` as well as `skill-sources/` (`find skill-sources skills -name SKILL.md`), so
  `skills/upgrade/SKILL.md` is already in its scope — no new discovery logic is needed, only new
  fixture coverage for the fences this plan adds or changes.
- **`grep` in a Claude Code session is ugrep.** Spell `/usr/bin/grep` in any new gate-facing bash.
- **Mutate the DEFECT, not the line.** Assert every mutation applied (`cmp -s`) before reading its
  result, and check *which* assertions reddened, not merely that some did.
- **Step 1 of every task is: measure the premise.**
- **Correction to the spec, recorded here rather than silently fixed in place:** Spec I's fix
  section describes resolving "`canonical_name → vault_name` by inverting the `vocabulary:`
  block." That direction needs no inversion — the block is keyed by canonical name, so
  `canonical → vault_name` is a direct lookup. The inversion is needed for the *other* direction,
  `vault_name → canonical_name`, which is what Step 1 actually needs first: its loop walks
  `.claude/skills/*/`, and those directory names are the vault's *derived* names. Task 1 below
  builds the correct direction.

---

## Task 1 — the vocabulary-inversion lookup (deterministic half of `render_current_template`)

- [ ] **Step 1 — measure the premise.** Read a real `vocabulary:` block (use the shape already
      confirmed against `~/second-brain/ops/derivation-manifest.md` — folder-level keys like
      `notes`, then skill-verb keys like `reduce`, `reflect`, `reweave`, `verify`, `rethink`,
      `topic_map`, each `canonical: "derived"`). Confirm at least one non-identity mapping exists
      (`reduce: "extract"`) to test the inversion against — an identity-only fixture (`reduce:
      "reduce"`) would pass even with the direction backwards.
- [ ] **Step 2 — write the lookup as a bash fence in `skills/upgrade/SKILL.md`.** Given a vault
      directory name from Step 1's `for dir in .claude/skills/*/` loop, build the reverse map from
      `ops/derivation-manifest.md`'s `vocabulary:` block (parse `^  <key>: "<value>"` lines under
      that block only — do not let a folder-level key collide with a skill-verb key; the fixture in
      Task 5 must include both kinds with visibly different names to catch a namespace collision) and
      emit the canonical name. **No match → halt, name the vault directory that couldn't be
      resolved, and do not treat it as a match against itself** (a vault-authored skill with no
      `skill-sources/` counterpart is a real, expected case — see Task 4's Deferrals note on
      `pipeline`/`ralph`/`seed`, and do not conflate "no template" with "template says no changes").
- [ ] **Step 3 — decide `render_current_template`'s placement and state the decision in the file.**
      Recommend: **inline** in `skills/upgrade/SKILL.md`, not a third `reference/lib/` file.
      Nothing else calls it yet, and a new library means a version constant, a Step 6a row, and a
      `skills/setup` copy-step change for a function with exactly one caller. Revisit only if a
      second caller appears — do not build that generality speculatively now.

**Done when:**
```bash
/usr/bin/grep -n "vocabulary:" skills/upgrade/SKILL.md   # the new lookup step is present
# fixture check happens in Task 5, once the fence-isolation fixture exists
```

---

## Task 2 — the render step (agent-judgment half of `render_current_template`)

- [ ] **Step 1 — write the substitution instruction, not a script.** `skills/setup/SKILL.md:637`
      is explicit that vocabulary transformation is "LLM-based contextual replacement, NOT string
      find-replace," with a Structural Marker Protection rule (`:702`): YAML field names stay
      universal, only values and prose transform. Point `/upgrade`'s render step at the same rule
      rather than restating or re-deriving it — a second, slightly different description is how
      the two mechanisms drift.
- [ ] **Step 2 — define the halt contract precisely.** On a missing plugin-side
      `skill-sources/<canonical>/SKILL.md` (installed plugin predates this skill, or the name
      resolved in Task 1 doesn't exist in `skill-sources/`), report exactly which canonical name
      and which lookup failed, mirroring Step 6a's existing tag style (`plugin copy absent
      [skipped — plugin older than this step]`). Never fall through to treating the vault's
      installed copy as current-when-unresolvable.

**Done when:**
```bash
/usr/bin/grep -n "Structural Marker Protection\|skills/setup" skills/upgrade/SKILL.md
```
(A prose-review check, not a fixture check — see Task 5's explicit statement of what this task
cannot have gated.)

---

## Task 3 — rewire Step 1's modification test onto the primitive

- [ ] **Step 1 — replace the `git status --porcelain` check** (`skills/upgrade/SKILL.md:99-104`
      as of Spec I) with: resolve canonical name (Task 1), render (Task 2), diff against the
      vault's installed file. Non-empty diff → `MODIFIED`.
- [ ] **Step 2 — preserve the inventory table's output shape.** The `Modified` column keeps its
      `yes`/`no` values; only the *derivation* changes. Do not touch Step 4's presentation format —
      Step 2's existing "check user modifications" branch (`:169-173`) starts firing correctly as a
      direct consequence of this fix; it needs no separate edit.

**Done when:**
```bash
/usr/bin/grep -n "git status --porcelain" skills/upgrade/SKILL.md   # gone
/usr/bin/grep -n "MODIFIED" skills/upgrade/SKILL.md                  # still present, new source
```

---

## Task 4 — rewire Step 5b, and make option (b) honest with no OLD-rendering available

- [ ] **Step 1 — Step 5b's "generation block."** Replace "read the skill's generation block from
      the plugin (if available)" with an explicit reference to Task 1+2's primitive. Drop "if
      available" — the halt contract from Task 2 Step 2 replaces the silent skip that phrase
      currently licenses.
- [ ] **Step 2 — Step 3's Side-by-Side section, the no-OLD-rendering case.** Per the Global
      Constraints note above, no OLD-rendering is retrievable today (no git tags) for *any* skill,
      not a corner case. When it can't be resolved, offer only options (a) keep and (c) replace
      (archived), and state plainly why (b) merge isn't offered — never present all three and let
      (b) fail silently or produce a guessed merge.
- [ ] **Step 3 — do not build the true three-way merge here.** That needs release-tagged history,
      which doesn't exist (deferred below). This task's scope is: be honest about (b)'s current
      unavailability, not simulate availability.

**Done when:**
```bash
/usr/bin/grep -n "generation block" skills/upgrade/SKILL.md            # old phrase gone
/usr/bin/grep -n "Option (b)\|no OLD-rendering\|not offered" skills/upgrade/SKILL.md
```

---

## Task 5 — fixtures and fence-gate coverage, with an explicit statement of what isn't covered

- [ ] **Step 1 — build the fixture.** Extend `reference/test/fence-isolation.test.sh`'s
      fixture-vault builder with: a `.claude/skills/extract/SKILL.md` (derived name) whose content
      diverges from a stub `skill-sources/reduce/SKILL.md` (canonical), and an
      `ops/derivation-manifest.md` `vocabulary:` block mapping `reduce: "extract"` alongside at
      least one folder-level key with a visibly different derived name, to catch the namespace
      collision named in Task 1 Step 2.
- [ ] **Step 2 — assert the three success criteria from Spec I** against that fixture: (a) the
      diverged skill reports `MODIFIED`; (b) an unresolvable vocabulary entry halts naming the
      exact skill and lookup; (c) a fresh fixture with zero divergence reports `MODIFIED: no` for
      every skill (regression check — nothing before this plan should start reporting differently
      on an unmodified vault).
- [ ] **Step 3 — run in both shells**, per the Global Constraints glob hazard: guard any new glob
      (e.g. over `.claude/skills/*/`) the same way `skill-sources/seed f01` and `skills/health f08`
      already had to, rather than rediscovering that zsh `nomatch` trap a third time.
- [ ] **Step 4 — state the boundary of this task's proof, in the test file's own header.** This
      gate proves Task 1's deterministic lookup and Task 3's diff-based test. It cannot prove Task
      2's prose-substitution step is *correct* — only that the skill file contains the instruction.
      Say so explicitly; a green fence gate here must not be read as "the primitive works," only
      as "its bash half does."

**Done when:**
```bash
for s in bash zsh; do $s reference/test/fence-isolation.test.sh | tail -1; done
```

---

## Task 6 — vault index hygiene (final task, only after Tasks 1-5 are committed)

- [ ] **Step 1 — `qmd update`.** Re-indexes collections against the current state of whatever
      `qmd` has configured on this machine (confirmed: a real subcommand, "Re-index collections
      (optionally git pull first)" — not shorthand for `qmd embed`).
- [ ] **Step 2 — `qmd embed`, once Step 1 completes.** Generates/refreshes vector embeddings for
      anything Step 1's re-index found. Run after, not instead of, Step 1 — embedding stale index
      state re-embeds nothing new.

**Done when:**
```bash
qmd status   # confirms 0 documents pending embedding after both commands
```

---

## Review

(Populated during execution — one entry per task-review round, per this repo's subagent-driven
workflow.)

---

## Deferrals

Every item below is Spec I's own "Deliberately not in scope," carried forward rather than
re-decided. Each names the tracked file it landed in — Spec I is a committed, tracked file, not a
gitignored ledger, so pointing at it satisfies the "one line per deferral naming the tracked file"
requirement.

- True historical-version retrieval for a real three-way merge (needs release git tags; none exist
  in this repo today) — tracked in
  `docs/superpowers/specs/2026-08-06-upgrade-consultation-blind-spot-design.md`, "Deliberately not
  in scope."
- Root-causing why `pipeline`/`ralph`/`seed` have never been archived once — tracked in the same
  file.
- Refreshing `ops/generation-manifest.yaml`'s stale top-level `plugin_version` /
  `skills_generated_from` fields after a successful upgrade cycle — tracked in the same file.
- This repo's divergence 16 (no automatic trigger ever invokes `/upgrade` against an existing
  vault) — already tracked in this repo's own `CLAUDE.md`; not re-filed here, since fixing
  `/upgrade`'s correctness once invoked is a different problem from building a scheduler.

---

## Known hazards, carried forward

- **Zsh `nomatch` on a glob with nothing to match** is this repo's most-repeated fence defect
  (`skill-sources/seed f01`, `skills/health f08`, both already allowlisted for the same reason).
  Any glob Task 1/Task 5 adds over `.claude/skills/*/` or `ops/skills-archive/*` needs the same
  guard those two already needed, not a fresh rediscovery.
- **The vocabulary block mixes two key namespaces** (folder-level: `notes`, `inbox`; skill-verb
  level: `reduce`, `reflect`) in one flat `vocabulary:` map. Task 1's inversion must not assume
  they're disjoint by construction — Task 5's fixture exists specifically to catch a collision
  between them.
- **Task 5's green fence gate is not proof the whole primitive is correct** — restated from Task 5
  Step 4 because it is exactly the kind of thing a later reader skims past. This gate proves the
  bash half only.
