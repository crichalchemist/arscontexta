# Spec D — Skill authoring reference, and the fossil that keeps attracting edits

**Date:** 2026-08-02
**Status:** proposed
**Branch:** `docs/skill-authoring-reference` (new — do **not** pile onto `fix/spec-c-primitive-10`)

---

## The request

> "Make sure we've refreshed every skill template included, and provide detailed reference for user
> skill creation and prose contracts."

Two halves. The first turns out to be already done — except for one directory where it should
never have been attempted. The second has no artifact at all today.

---

## Part 1 — "every skill template" is two populations, not one

### What is on the generation path, and is already refreshed

| Directory | Files | Fences | Gated? |
|---|---|---|---|
| `skill-sources/*/SKILL.md` | 16 | — | yes |
| `skills/*/SKILL.md` | 10 | — | yes |
| **combined** | **26** | **74** (71 run, 3 skipped) | `fence-isolation.test.sh` |

Measured on this checkout, both shells:

```
bash: files=26 fences=74 run=71 skipped=3 known-open=0 · H0 N0 U0 S0 · PASS
zsh:  files=26 fences=74 run=71 skipped=3 known-open=2 · H0 N0 U0 S0 · PASS
```

Both zsh entries are the documented non-matching-glob fork — `skill-sources/seed f01` and
`skills/health f08`, where zsh aborts the command on a glob that matches nothing and bash passes the
pattern through. **Every template on the generation path is refreshed and gated.** No work is owed
here.

### What is *not* on the generation path

`platforms/shared/skill-blocks/` — 16 files, ~27 bash fences, **zero consumers**.

Evidence, re-verified on this checkout rather than taken from the prior spec:

- `skills/setup/SKILL.md` is the generator. `grep -n 'skill-blocks\|platforms'` against it returns
  **0 matches**. The generation path enumerates `skill-sources/` and nothing else.
- `grep -rn 'platforms/' --include='*.sh' --include='*.md' --include='*.json' --include='*.yaml'
  skills/ generators/ hooks/ reference/ presets/` returns **empty**. No live code references the
  directory at any depth.
- Every surviving mention lives in prose *about* the directory — `CLAUDE.md:138`,
  `CONTRIBUTING.md:172`, and prior specs/plans.
- `docs/superpowers/specs/archive/2026-08-01-portability-link-correctness-design.md:73` already ruled it
  **"Verified vestigial … Explicitly out of scope"**, and
  `docs/superpowers/plans/archive/2026-08-01-portability-link-correctness.md:27` carried that forward as
  **"Do not modify `platforms/shared/skill-blocks/`."**

### But it is not a superseded predecessor — check this before deciding

The natural reading is "`skill-blocks` became `skill-sources`." **That is wrong, and the measurement
matters because it inverts the recommendation.**

- **Neither predates the other.** `git log --reverse -- <path>` returns `4be327e` for *both*. They
  were born in the same commit, the v0.8.0 initial release. Nothing was renamed or migrated.
- **`skill-blocks` is the *more* templated of the two — in all 10 full-template pairs, without
  exception:**

  | pair | `skill-sources` placeholders | `skill-blocks` placeholders |
  |---|---|---|
  | validate | 3 | **56** |
  | remember | 4 | **48** |
  | verify | 8 | **122** |
  | ralph | 15 | **139** |
  | pipeline | 16 | **71** |
  | seed | 19 | **62** |
  | rethink | 26 | **78** |
  | reweave | 111 | **165** |
  | reflect | 121 | **202** |
  | reduce | 131 | **154** |

  `skill-sources/reflect/SKILL.md` opens `name: reflect` with literal `notes`, `MOCs`, `ops/`.
  Its `skill-blocks` twin opens `name: {vocabulary.reflect}` with `{config.ops_dir}` throughout,
  under a header reading **"GENERATION TEMPLATE — Do not edit directly. This template is transformed
  by the derivation engine during /setup."**

- **That derivation engine does not exist.** `skills/setup/SKILL.md:1285` names
  `${CLAUDE_PLUGIN_ROOT}/skill-sources/` and says each template "must be read,
  **vocabulary-transformed**, and written" — the transformation is performed by the model consulting
  the derivation manifest, not by string substitution. Which is exactly why `skill-sources` can be
  partially concrete and still work.

So `platforms/shared/skill-blocks/` is not a fossil of a superseded predecessor. It is the **more
complete artifact of a mechanism that was never built** — deterministic placeholder substitution.
Nothing reads it because the engine it was written for does not exist.

### The finding: the fossil attracted edits, and got half-refreshed

`git log -- platforms/shared/skill-blocks/` shows it untouched from `4be327e` (v0.8.0) until
Spec C, when **four commits modified it** — `29dbb96`, `a5e1795`, `7765504`, `05e0a3b`. Those are
mine, from this session. They landed against a standing "do not modify" ruling that neither I nor
any gate re-surfaced at the time.

Worse than the rule-break: the port is **partial**, which is the one state strictly worse than
either full sync or no sync.

| | guarded fences | note |
|---|---|---|
| `skill-sources/reflect/SKILL.md` | f01 **and** f03 | lock guard + D1 count guard |
| `platforms/shared/skill-blocks/reflect.md` | f01 only | lock guard landed; **D1 count guard did not** |

A future reader diffing the two will find guards on both sides and reasonably conclude they are in
sync. They are not. That is this repo's signature defect — a plausible-looking result that is
wrong — reproduced in the very directory a prior spec fenced off to prevent exactly this.

### Decision D4 — what to do with the fossil

Three options, and one of them is a trap:

| Option | Effect | Verdict |
|---|---|---|
| **A — delete the directory** | the attractor disappears; the repo's most complete vocabulary-point markup goes with it | **no longer recommended** — see below |
| **B — freeze, gate, and cite it** | `check-portability.sh` fails on any modification; the reference names it as the vocabulary-point inventory | **recommended** |
| **C — finish the port, adopt into the gate** | 27 more fences gated | **rejected** — institutionalizes two live copies of every template, the drift hazard `CLAUDE.md:138` already names |

**The recommendation moved from A to B once the placeholder counts were measured.** My first pass
called this a fossil and proposed deleting it. That was wrong in a way worth stating plainly: I had
inferred "vestigial" from *has no consumer* and stopped there, without checking what was in it.

`skill-blocks` holds the only fully-marked-up copies of these ten skills — every point where a
string is vocabulary-variable, marked. That is a genuine asset, and specifically the asset **§3 of
the authoring reference needs**: the question "which strings in a template are vocabulary-variable?"
is answered more completely there than anywhere else in the repo. Deleting it to stop it attracting
edits would discard the answer to keep the filing cabinet tidy.

**B, with a stated purpose.** A frozen directory with no reason attached is just a fossil that a
future contributor deletes on sight. Give it a job — read-only reference inventory, cited from
`reference/skill-authoring.md` — and the freeze becomes legible instead of arbitrary.

One thing is not optional under any option: **the three half-ported files must stop claiming sync.**

---

## Part 2 — the authoring reference does not exist

### What exists today, and where it is scattered

| Surface | Covers | Gap |
|---|---|---|
| `CONTRIBUTING.md` INVARIANT 1 | fences are separate shells | no guard patterns |
| `CONTRIBUTING.md` INVARIANT 2 | "a failure must never be a number" | states the rule, shows no canonical fix |
| `CONTRIBUTING.md` "Prose is a contract" | 6 lines: change prose with code | does not say what makes a prose contract *verifiable* |
| `CLAUDE.md` | architecture, three generation paths | oriented at this repo's maintainers, not at skill authors |

Nothing documents the **frontmatter contract** (8 keys in use across 26 files), the **placeholder
families**, the **guard patterns the gate actually asserts**, or how to write a prose contract that
someone can later check.

### Design: `reference/skill-authoring.md`

Placement alongside `components.md` and `testing-milestones.md`. CONTRIBUTING.md's three sections
**point at it** rather than restate it — three surfaces that can disagree is divergence 2 in a new
costume.

Required contents:

1. **Which tree you are editing.** `skill-sources/` → copied into vaults, carries placeholders,
   becomes `/<name>`. `skills/` → the plugin's own `/arscontexta:<name>`, never copied, **no**
   placeholders. Getting this backwards ships one user's vocabulary to everyone.
2. **Frontmatter contract.** Measured across the 26 files: `name` (26), `description` (26),
   `allowed-tools` (26), `context` (25), `user-invocable` (21), `version` (17), `model` (17),
   `argument-hint` (14). Which are mandatory, which are optional, what each controls.
3. **Placeholder families.** `{vocabulary.*}` (from `vocabulary.yaml`), `{config.*}` (from
   `preset.yaml`), `{DOMAIN:*}` (from the derivation conversation), `{if …}{endif}`. Plus the fact
   that **the fence gate fails loud on an unmapped placeholder** rather than skipping the fence —
   an author who invents a new token gets a hard error naming it, not a silent pass.
4. **The fence rules, with canonical guards.** INVARIANT 1 restated as authoring guidance, and for
   each of the gate's four assertions the pattern that satisfies it — cited **by assertion letter
   (H/N/U/S)**, not re-derived. A guard example that drifts from what the gate asserts is worse
   than no example.
5. **Prose contracts** — see below.

### Authoring method: `superpowers:writing-skills` governs how this document gets written

Reviewed against that skill, an earlier draft of this spec failed it in three ways. Recording them
because the corrections are load-bearing, not cosmetic:

1. **Iron Law violation.** *No skill without a failing test first* — and the skill applies it to
   reference documents, tested by retrieval / application / gap scenarios. The draft went straight
   to six sections chosen by intuition. The fix is not to invent a baseline: **one already exists**,
   generated by the session that produced this spec (a frozen directory edited under a standing
   ruling; *vestigial* inferred from *no consumer* without reading contents; `grep -c` returning 0
   because `{` is a quantifier; the guard-vs-assertion-H collision). Every section must trace to one
   of those, or be cut.
2. **One form for four failure types.** The skill's table maps failure type to form and warns that
   prohibitions *measurably backfire* on shaping problems. §1 is a wrong-choice-under-ambiguity
   failure → a conditional on an observable predicate. §2 and §5 are omissions → structural required
   slots. §3 and §4 are wrong-shape → positive recipes. Only §6 is a discipline failure, and only it
   gets prohibitions and red flags.
3. **Narrative anti-pattern.** This spec is dense with `§5e`, commit hashes, and "the collision this
   repo hit once." Correct in a project record; the skill names it an anti-pattern in a reference.
   Each incident survives into the document as **at most one compressed line** stating the rule it
   produced.

The skill's own escape hatch also applies and is already taken: *"mechanical constraints — if it's
enforceable with regex or validation, automate it; save documentation for judgment calls."* Which is
why the frozen directory gets a gate rather than a paragraph, and why the reference's examples are
executed rather than proofread.

### Anti-rot: the doc's examples are gate fixtures

A new reference document is, structurally, more prose of the class this repo keeps catching itself
producing — two plans at 0/93 while fully executed; primitive 10 asserting presence, not
resolution. Writing another unverified document and hoping is not a plan.

The mechanism, using machinery that already exists:

- **Add `reference/skill-authoring.md` to the fence gate's scan set.** The gate extracts
  ` ```bash ` fences and runs each standalone against a healthy fixture and a missing-vault
  fixture. Every *good* example in the reference therefore has to pass H/N/U/S like any shipped
  fence. An example that rots fails CI.
- **Good examples go in ` ```bash `. Counter-examples go in ` ```text `.** The gate extracts only
  ` ```bash `, so a deliberately-broken illustration is invisible to it — and the doc states this
  rule explicitly so the next author knows which fence to reach for.

This costs one line at `fence-isolation.test.sh:255` and makes the document's examples
un-divergeable from the gate by construction.

### Prose contracts — the rule Task 5 paid for

A **prose contract** is an instruction to the model with no executable form. `skills/upgrade/SKILL.md`
§5e is the worked example: it deliberately forbids a bash block because `${CLAUDE_PLUGIN_ROOT}`
resolves for the model, and instructs Claude to copy a library file into the vault.

Task 5 established how it fails. The published plugin at
`~/.claude/plugins/cache/agenticnotetaking/arscontexta/0.8.0/` has **no `reference/lib/`** — §5e's
source file does not ship. The contract names a path that does not exist for any real user, the
skill silently no-ops, and no gate can catch it because CI cannot run prose.

The rule the reference must state, derived from that failure — a prose contract must declare:

| Clause | Why | Example from §5e |
|---|---|---|
| **(a) precondition, explicitly** | the thing most likely to be false at runtime | "`reference/lib/link-extraction.sh` exists in the plugin root" |
| **(b) failure signature** | so silence is distinguishable from success | "if absent: report it; do **not** create an empty file" |
| **(c) verifier and when** | CI will not do it; someone must | "checked by `/arscontexta:upgrade` run against a real vault" |

And one clause that converts an unverifiable contract into a verifiable one:

> **Every filesystem path named in a prose contract must exist in the packaged plugin.**

That is mechanically checkable. A script can extract paths from prose-contract blocks and assert
each resolves inside the plugin tree — catching precisely the §5e defect, which four gates, a
127 KB review and a live vault run all failed to catch until the skill was executed by hand.

Whether to build that checker now or record it is a scope call, taken in the plan.

---

## The version bump is not incidental — it is the fix for the `0.8.0` collision

Any of this ships a version bump, and that turns out to resolve the defect Task 5 surfaced rather
than merely accompanying it.

Task 5 found that the published plugin at
`~/.claude/plugins/cache/agenticnotetaking/arscontexta/0.8.0/` and this repo tree **both call
themselves `0.8.0`** while differing materially — the published `skills/upgrade/SKILL.md` is 395
lines with §5a–§5d; the repo's is 465 lines with §5a–§5g, and the published tree has no
`reference/lib/` at all. A version string that does not identify a unique artifact is the same
silent-failure class as everything else here: `0.8.0` looks like an answer and is not one.

Bumping is therefore not bookkeeping. It is what makes "which tree am I looking at?" answerable, and
it is a precondition for the §5 prose-contract path checker — you cannot assert "every path named in
a prose contract exists in the packaged plugin" while "the packaged plugin" is ambiguous.

Four declaration sites, all currently `0.8.0`:

| File | Line | Tracked? | Verdict |
|---|---|---|---|
| `.claude-plugin/plugin.json` | 3 | yes | **canonical** |
| `.claude-plugin/marketplace.json` | 10 | yes | keep |
| `.claude-plugin/marketplace.json` | 16 | yes | keep |
| `plugin.json` | 3 | no | **delete** |

**The root `plugin.json` is settled by precedent, not preference.** `/volumes/containers/superpowers`
is a mature multi-platform plugin: it keeps `.claude-plugin/{plugin.json,marketplace.json}` and has
**no root `plugin.json`**. Its root-level manifests belong to other ecosystems — `package.json`,
`gemini-extension.json` — and every other platform gets a dot-directory (`.codex-plugin/`,
`.cursor-plugin/`, `.kimi-plugin/`, `.pi/`, `.opencode/`). arscontexta's root file is a
**byte-identical duplicate** of the canonical one: no unique field, untracked, capable only of drift.

**The mechanism to adopt** is `.version-bump.json` — a declarative manifest of every version-carrying
`{path, field}`, with dotted paths for nested entries (`plugins.0.version`) and an `audit.exclude`
list. Its `scripts/bump-version.sh` provides `--check` (declared files agree) and `--audit`
(repo-wide grep for the old version anywhere outside the exclusions). That audit is the missing
mechanism: it catches a version string surviving in a file nobody remembered to list.

**And one place to improve on the source.** Superpowers has no `.github/workflows/` and no
pre-commit version hook — its script is a manual release tool, which is exactly how a stale version
survives. arscontexta already runs 11 CI steps; `--check` becomes step 12, and the drift cannot ship
rather than merely being detectable by someone who remembers to look.

**Recommendation: `0.9.0`.** Freezing a directory, adding a gated reference, and re-pointing three
prose surfaces is additive with one structural change — a minor bump, not a patch.

**Side finding, recorded not acted on:** superpowers answers the queued platform-adapter question
too. It carries `.pi/`, `.codex-plugin/`, `.cursor-plugin/`, `.kimi-plugin/`, `.opencode/` — one
dot-directory per platform, all versioned through the same `.version-bump.json`. When the Antigravity
and Pi adapters come off the queue, that is the shape, and adopting `.version-bump.json` now means
they inherit version coherence for free rather than adding two more sites to hand-sync.

## Out of scope
- **Divergence 1** (fence-gate allowlist keys on `(letter, label)`). Already recorded as a
  deliberate non-fix.
- **The README WIP** claiming Antigravity availability. Unrelated, still uncommitted, still the
  user's call.

---

## Success criteria

1. `platforms/shared/skill-blocks/` frozen, gated, and carrying a README that states its purpose
   **and** that guard-parity with `skill-sources/` is a non-goal — so the half-ported guards stop
   being a claim the directory cannot support.
2. The baseline is written down before the reference is written, and at least one planned section
   has been cut or rewritten because the control did not fail.
3. `reference/skill-authoring.md` exists, covers six sections, and each is in the form its failure
   type prescribes. No section names a commit hash or a date.
4. Its ` ```bash ` examples are extracted and run by `fence-isolation.test.sh`, passing H/N/U/S in
   **both** shells — with a planted-defect proof that the wiring is not vacuous.
5. ≥4 of 5 fresh subagents retrieve the document unprompted and produce a passing fence, and the
   five reps converge on the same fence shape. Divergent-but-passing reps mean the form is wrong.
6. CONTRIBUTING.md INVARIANT 1, INVARIANT 2 and "Prose is a contract" point at the reference
   instead of restating it.
7. Root `plugin.json` deleted, version moved off `0.8.0` at the three canonical sites via a
   `.version-bump.json` manifest, `--check` wired into CI as step 12, and a re-install confirming the
   published tree now matches the repo tree.
8. All five existing checks still pass, both shells, plus kernel validation unchanged at 15 PASS.
