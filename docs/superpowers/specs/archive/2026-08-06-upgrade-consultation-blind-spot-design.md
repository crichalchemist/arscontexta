# Spec I — `/upgrade`'s modification test is blind to committed local patches

## What this is

The first real, non-simulated invocation of `/arscontexta:upgrade` against a live vault
(`~/second-brain`) since divergence 5 opened it as an unexercised path — halted before Step 5
completed. This spec is grounded in the vault's own `ops/generation-manifest.yaml` and
`ops/skills-archive/`, not a transcript: none exists. `~/second-brain/ops/sessions/*.md` is a
shared session-capture sink written by that vault's own hooks for *any* Claude Code session with
the vault as cwd — it is not `/upgrade`-specific, and grepping it for "Step 5" surfaced only
unrelated hits from this repo's own CI work. That dead end is recorded so the next reader doesn't
re-walk it.

Read-only investigation throughout: nothing in `~/second-brain` was written or modified to produce
this spec, per the standing rule that vault is copies-only, read-only ground truth.

## The evidence

1. **`ops/generation-manifest.yaml` documents its own workaround for the defect this spec fixes.**
   All 16 vault skills are `locally_modified: all-16` (18–354 changed lines vs. plugin source
   each), patched and committed in one batch on 2026-07-27 (record:
   `ops/sessions/20260727-direction-audit-apply-complete.md`). Its own header states the fix this
   spec independently arrives at: *"the modification test that works is diff-vs-plugin/
   skill-sources/ — `git status .claude/skills/` false-negatives on committed customizations."*
   That is exactly the mechanism `skills/upgrade/SKILL.md` Step 1 uses today (`:99–104`,
   `git status --porcelain "$file"`).

2. **`ops/skills-archive/` proves Step 5 is not universally broken, and bounds the actual blast
   radius.** 22 archived files cover 13 of the vault's 16 skills, dated 2026-03-21 through
   2026-07-11 — nothing since. `pipeline`, `ralph`, and `seed` have never been archived once.
   `ops/changelog.md` records exactly one completed upgrade cycle, ever: `/upgrade (stats v1.3,
   next v1.1)`, preceding an `/architect` run.

3. **`skills/upgrade/SKILL.md:292`'s "read the skill's generation block from the plugin" names an
   artifact that exists nowhere.** Grepped the full tree (`skill-sources/`, `generators/`,
   `reference/`, `platforms/`); the phrase occurs at exactly that one line. Nothing defines what a
   "generation block" is, where it lives, or what an agent should do when it can't be resolved.

4. **This repo has no git tags** (`git tag` returns empty). Relevant to the Deferrals section
   below, not to the core fix.

## The causal chain

Step 1's `git status` check reports 0 modified skills — a false negative, since all 16 are
actually modified relative to the plugin. That silences Step 2's "check user modifications"
branch (`:169–173`) for every skill. Step 4 presents a plan and gates on approval correctly — not
part of the defect. Step 5b, believing no skill needs the preserve/merge safeguard, then hits an
undefined "generation block" instruction with nothing standing between it and 18–354 lines of
hand-maintained, evidence-backed local patches per skill. Halting there was the right instinct by
whatever ran it. It should not have taken three silent steps and an undefined instruction to
surface — Step 1 should have said so immediately.

## The fix: one shared primitive, used twice

Findings 1 and 3 are not independent. Both need the same missing capability: reproduce what the
plugin's *current* `skill-sources/<canonical-name>/SKILL.md` would render to, in *this vault's*
vocabulary. Call it `render_current_template(canonical_name)`:

1. Resolve `canonical_name → vault_name` by inverting `ops/derivation-manifest.md`'s `vocabulary:`
   block (e.g. `vocabulary.reduce: "extract"` gives `reduce → extract`). No new per-skill field is
   needed — the data already exists in every generated vault.
2. Read `${CLAUDE_PLUGIN_ROOT}/skill-sources/<canonical_name>/SKILL.md`.
3. Apply vocabulary transformation the way `/setup` already does it — **not** a shell
   string-substitute. `skills/setup/SKILL.md:637` is explicit this is "LLM-based contextual
   replacement, NOT string find-replace," and its Structural Marker Protection rule (`:702`) says
   YAML field names stay universal; only values and prose transform. Reuse that mechanism rather
   than inventing a second, parallel one that can drift from it.
4. If step 1 or 2 fails to resolve — no vocabulary entry, no plugin-side file — **halt and report
   which skill and which lookup failed.** Never fall through to treating the vault's copy as
   current-when-unresolvable. This mirrors the discipline Step 6a already applies to the two
   shared libraries ("if file absent, halt this row and report it — do not treat it as version
   `0`").

**Finding 1 fix.** Step 1's modification test becomes: `render_current_template` the skill, diff
against the vault's installed copy. Non-empty diff = modified. This also, as a direct consequence,
correctly triggers Step 2's existing preserve/merge branch — no separate code change is needed
there; it is downstream of Finding 1, not an independent defect.

**Finding 3 fix.** Step 5b's "generation block" becomes, explicitly, the output of
`render_current_template` for this skill. Drop "if available" — the halt-and-report above replaces
the silent skip that phrase currently licenses.

**Finding 4 fix, partial.** Step 3's "merge the user's customizations into the updated skill" for
option (b) gets a bounded procedure: diff the OLD rendering (this skill's `generated_from:`
version, zero local patches) against the vault's current file to isolate the user's patch as a
diff; apply that diff to the NEW rendering. Clean apply → that is the merge. Conflict → fall back
to the existing side-by-side (options a/b/c), presenting the conflicting hunk rather than silently
picking a side. This is *partial* because it needs an OLD rendering — see the first deferral below.

## Deliberately not in scope (high-value deferrals)

This repo's convention reserves "Deferral" for a plan-level record naming the tracked file a
skipped item landed in; a design spec's equivalent is "deliberately not in scope," decided before
any execution rather than discovered during it. Named here in both senses on purpose — surfaced now
so a later plan for this spec doesn't have to re-derive them, and each one states why it isn't
folded into this spec's fix.

- **True historical-version retrieval for Finding 4's OLD rendering.** The bounded merge above
  needs "what `skill-sources/<name>/SKILL.md` looked like at this skill's `generated_from`
  version" — retrievable only if the plugin's release process tags versions in git. It doesn't:
  `git tag` returns nothing in this repo today. Building that (a tag on every `bump-version.sh`
  run, or an equivalent snapshot mechanism) is its own piece of infrastructure and a genuine
  prerequisite for a *real* three-way merge — not this spec's narrower fix. Until it exists,
  option (b) without a resolvable OLD rendering must degrade to the existing side-by-side flow,
  never fabricate one.
- **Root-causing why `pipeline`/`ralph`/`seed` have never been archived.** Two explanations fit the
  evidence and this spec does not distinguish them: Step 2 may have genuinely found nothing to
  improve in three skills across five months (plausible — they sit further from the
  research-methodology graph than the others), or a second, separate defect stalls them
  specifically. Coupling an unverified hypothesis to this spec's verified one would make both
  harder to review. Worth its own investigation.
- **`ops/generation-manifest.yaml`'s top-level `plugin_version` / `skills_generated_from` fields.**
  Step 5d already updates each skill's *own* `generated_from:` and its per-skill manifest entry;
  nothing refreshes these two top-level fields after a successful cycle, so they stay frozen at
  whatever version first generated the vault — currently a stale `"0.8.0"` against an installed
  `0.9.0`. Small and touches the same file this spec's fix already reads, so folding it in later is
  cheap — but it's a distinct, separately-verifiable claim, named here rather than silently
  bundled into Finding 1's diff.
- **This repo's own divergence 16** (three disconnected validation tiers; no gate reaches an
  already-generated vault automatically) is untouched on purpose. Fixing `/upgrade`'s correctness
  once invoked does not build a trigger that invokes it automatically, and does not touch
  `platforms/claude-code/hooks/session-orient.sh.template`'s already-tracked, separate staleness
  (divergence 3). Different problem, already has an owner — not this spec.

## Success criteria

- Step 1, run read-only against a copy of `~/second-brain` (never the vault itself — no writes),
  reports all 16 skills `MODIFIED`, matching `ops/generation-manifest.yaml`'s own count. Needs a
  dry-run mode for Step 1 in isolation, since the live skill has no such mode today.
- `render_current_template`, given a canonical name with no `vocabulary.*` entry in a fixture
  manifest, halts and names the exact skill and the exact missing lookup — never emits a partial
  or best-guess render.
- Regression check against a freshly-generated fixture vault (zero local patches): Step 1's new
  diff-based test and the old `git status` test agree, since there's nothing for a real vs.
  git-tracked modification to disagree about.
- `render_current_template` is exercised against at least one skill whose vault-local name differs
  from its canonical name (e.g. `reduce → extract`), proving the vocabulary-inversion lookup, not
  just the identity case.

## Open question for the plan that follows this spec

Whether `render_current_template` belongs in `reference/lib/` as a third versioned shared
primitive (alongside `frontmatter.sh` and `link-extraction.sh`) — it would need its own version
constant and a Step 6a row — or stays inline inside `skills/upgrade/SKILL.md` since, unlike the two
existing libraries, nothing else currently calls it. Recommend deferring that placement decision to
the plan itself rather than settling it here, per this repo's own norm of separating what a spec
decides from what a plan executes.
