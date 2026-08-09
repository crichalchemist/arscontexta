# Plan — Skill authoring reference, and the vestigial template directory

**Spec:** `docs/superpowers/specs/archive/2026-08-02-skill-authoring-reference-design.md`
**Branch:** `docs/skill-authoring-reference`, cut fresh from `main` — **not** stacked on
`fix/spec-c-primitive-10` (9 commits, complete, unpushed; keep it reviewable on its own).

---

## Global Constraints

- Files under `skill-sources/` and `platforms/shared/skill-blocks/` are **templates**. Never
  substitute a placeholder with a concrete value. `skills/` are the plugin's own commands and carry
  **no** placeholders.
- Every gate runs under **both** `bash` and `zsh`. A single-shell run has twice shipped a defect
  here. "Passes" means passes in both.
- `grep` in this session is ugrep. Any pattern containing `{` or `}` needs `grep -F`, and PCRE
  (`grep -P`) is unavailable on the CI image — `check-portability.sh` enforces this.
- **Execution model: implement directly, dispatch reviews.** Implementer subagents have died 3/3 in
  this repo (autocompact thrashing, harness-named). Reviewer subagents survive 127 KB packages and
  have found defects four gates missed. Do not re-litigate this at Task 1.
- Prose and code move in the **same commit**. A narrow table beside a widened bash line is the same
  defect in a different font.

---

## Decision D4 — the vestigial directory (needs the user's call before Task 1)

`platforms/shared/skill-blocks/` has **no consumer**: `skills/setup/SKILL.md` (the generator) has
zero references to it, and no `.sh`/`.md`/`.json`/`.yaml` under `skills/ generators/ hooks/
reference/ presets/` mentions `platforms/` at all. A prior spec ruled it *"Verified vestigial …
Explicitly out of scope"* and a prior plan carried *"Do not modify."*

Spec C then modified it in four commits, leaving it **half-refreshed** —
`platforms/shared/skill-blocks/reflect.md` has the lock guard but not the D1 count guard its
`skill-sources` twin carries.

**It did not "become" `skill-sources`.** Both directories were created in the same commit
(`4be327e`), and `skill-blocks` is the **more** templated of the two in all 10 pairs — `validate`
3 vs 56 placeholders, `verify` 8 vs 122, `ralph` 15 vs 139. Its header names a *"derivation engine"*
that was never built; `skills/setup/SKILL.md:1285` instead has the model vocabulary-transform
`skill-sources/` directly. It is the more complete artifact of an abandoned mechanism, not a
superseded predecessor.

| Option | Action | Recommendation |
|---|---|---|
| **A** | Delete the 16 files | **withdrawn** — discards the repo's most complete vocabulary-point markup |
| **B** | Freeze at current state, gate the path in `check-portability.sh`, and **cite it** in the reference as the vocabulary-point inventory | **recommended** |
| **C** | Finish the port, adopt into the fence gate | **rejected** — two live copies of every template |

**B, with a stated purpose.** A freeze with no reason attached is a fossil the next contributor
deletes on sight; a freeze with a job ("read-only inventory, cited by §3") is legible. Doing nothing
is not on the list — the directory has now attracted four commits that changed no shipped behavior.

---

## Task 1 — Resolve `platforms/shared/skill-blocks/` per D4

**Files:** `platforms/shared/skill-blocks/README.md` (new), `reference/check-portability.sh`,
`CLAUDE.md:138`, `CONTRIBUTING.md:172,179`. The 16 template files themselves are **not** edited.

- [ ] **Step 1 — Re-verify the vestigial claim at execution time, not from this plan.** Run both
      searches and paste the results into the commit message. If either returns a hit, **halt**:
      the directory is live and D4 is void.
      ```
      grep -n 'skill-blocks\|platforms' skills/setup/SKILL.md            # expect: 0 matches
      grep -rn 'platforms/' --include='*.sh' --include='*.md' \
        --include='*.json' --include='*.yaml' \
        skills/ generators/ hooks/ reference/ presets/                    # expect: empty
      ```
- [ ] **Step 2 — Freeze at HEAD. Do not revert.** Reverting was the right move only while the
      directory's job was "stay in sync with `skill-sources`." Under B its job is **inventory of
      vocabulary points**, and against that purpose guard-parity is explicitly a *non-goal* — so the
      half-ported guards stop being a lie the moment the purpose is written down. Reverting them
      would also have to thread around `29dbb96`, which migrated qmd tool names correctly and must
      not be undone.
- [ ] **Step 3 — Write `platforms/shared/skill-blocks/README.md`.** This is what makes the freeze
      legible rather than arbitrary, and it is the step most likely to be skipped as busywork. Four
      sentences: nothing reads this directory; `skills/setup/SKILL.md:1285` generates from
      `skill-sources/` instead; these files carry the most complete `{vocabulary.*}` / `{config.*}`
      markup in the repo and exist to answer "which strings are vocabulary-variable"; **guard and
      logic parity with `skill-sources/` is not maintained and is not a defect.**
- [ ] **Step 4 — Gate it.** Add a rule to `check-portability.sh` that fails when
      `git diff --name-only` shows any
      path under the directory. The rule must point at the README in its output ("frozen — see
      platforms/shared/skill-blocks/README.md"), or the next contributor deletes the rule instead of
      the edit.
- [ ] **Step 5 — Correct the three prose sites** in the same commit. `CLAUDE.md:138` currently tells
      contributors the directory "can drift from `skill-sources/`; **check both when editing a
      shared behavior**" — that instruction is what produced the four Spec C commits, and it is now
      exactly backwards. `CONTRIBUTING.md:172,179` name it as a placeholder-carrying tree that
      contributors edit; it is a placeholder-carrying tree they must **not** edit.

**Done when:** the directory carries a README stating its purpose and its non-goals, a gate rejects
modification and names the README, and no prose anywhere tells a contributor to edit it.

---

## Task 2 — RED: harvest the baseline before writing a word

**Files:** `.superpowers/sdd/<plan>/baseline-failures.md` (ledger, git-ignored).

`superpowers:writing-skills` states the Iron Law — *no skill without a failing test first* — and
applies it to reference skills, tested by **retrieval / application / gap** scenarios. An earlier
draft of this plan went straight to authoring six sections chosen by intuition. That is writing
production code before the test.

**The baseline does not need to be manufactured. It already happened, in the session that produced
this plan, and was never written down:**

| Observed failure | What the author actually did |
|---|---|
| Edited a frozen directory | Modified `platforms/shared/skill-blocks/` in 4 commits under a standing "do not modify" ruling that no gate surfaced |
| Inferred structure from absence | Concluded *vestigial* from *no consumer* without reading contents; the directory is the **more** templated of the two |
| `grep -c 'FILE="${ARGUMENTS:-}"'` → 0 | `{` is a regex quantifier in this shell's grep; needed `-F`. Nearly concluded correct edits had not landed |
| Wrong cache path | Checked the plugin cache one level too high, missing the version dir; got a false "NO reference/" |
| Guard-vs-gate collision | Applied the D1 fail-loud guard where assertion H forbids stderr+non-zero; H went 0 → 3 failing |

- [ ] **Step 1 — Write these up as scenarios**, each as *what an author was trying to do* and *what
      they concluded*, stripped of who and when. These are the failures §1–§6 must prevent. Any
      section that maps to no row is a section written from intuition — cut it or find its row.
- [ ] **Step 2 — Add one control.** Dispatch a subagent, no reference document, asked to add a
      counting bash fence to `skill-sources/next/SKILL.md`. Record verbatim what it produces. If it
      already guards correctly and picks the right tree, **that section is not needed** — the skill
      is explicit that a control which does not exhibit the failure means there is nothing to fix.

**Done when:** every planned section traces to a recorded failure, and at least one planned section
has been cut or rewritten because the control did not fail.

---

## Task 3 — GREEN: write `reference/skill-authoring.md`

**Files:** `reference/skill-authoring.md` (new).

**Placement note.** This is a `reference/` document, not `skills/<name>/SKILL.md`. Every entry in
`skills/` here is a user-facing `/arscontexta:<name>` command; an internal guidance skill would break
that convention (and the repo's own "match the conventions" rule). The cost is real and worth
stating: `reference/` is found only by someone reading CLAUDE.md, where a skill would be surfaced
automatically by description match. Revisit if the repo ever grows non-command skills.

**Form follows failure — the skill's table, applied per section:**

| Section | Baseline failure type | Required form |
|---|---|---|
| §1 which tree | wrong choice under ambiguity | **conditional on an observable predicate** — "does the file contain `{vocabulary.`?" not "remember which tree is which" |
| §2 frontmatter | omits a required element | **structural** — a REQUIRED-field table an author fills in |
| §3 placeholders | wrong shape / invented tokens | **positive recipe**, plus the gate's own hard error as the backstop |
| §4 guards | wrong shape (guard that collides with H) | **recipe: state what the guard IS**, not a list of don'ts |
| §5 prose contracts | omits required element | **structural** — three named clauses, absent = incomplete |
| §6 which fence | discipline (will bypass under pressure) | **prohibition + red flags** — the one place the skill sanctions that form |

Sections still grounded in measurements from this checkout, not recollection:

- [ ] **§1 Which tree am I editing.** `skill-sources/` (16) → copied into vaults, carries
      placeholders, becomes `/<name>`. `skills/` (10) → the plugin's own `/arscontexta:<name>`,
      never copied, no placeholders. Include the reverse-transform rule for backports from a field
      vault (vocabulary → canonical; concrete paths → placeholders), because that is the mistake
      with the widest blast radius: it ships one user's vocabulary to everyone.
- [ ] **§2 Frontmatter contract.** Measured across all 26 files: `name` 26, `description` 26,
      `allowed-tools` 26, `context` 25, `user-invocable` 21, `version` 17, `model` 17,
      `argument-hint` 14. State which are mandatory, what each controls, and that `context: fork`
      means the skill runs with the plugin repo as cwd — the Task 5 finding that
      `/arscontexta:upgrade` cannot be pointed at a vault.
- [ ] **§3 Placeholder families.** `{vocabulary.*}` from `vocabulary.yaml`; `{config.*}` from
      `preset.yaml`; `{DOMAIN:*}` from the derivation conversation (an older spelling, still live in
      `skill-sources/seed`); `{if …}{endif}`. Document that the fence gate **fails loud on an
      unmapped placeholder** — `map_value()` returns 1, the harness prints the token and exits 1. An
      author inventing a token gets a named error, never a skipped fence.
      **Cite `platforms/shared/skill-blocks/` here** as the read-only inventory of vocabulary
      points — it marks up 56 placeholders in `validate` where `skill-sources` marks 3, 122 in
      `verify` where `skill-sources` marks 8. An author asking "is this string vocabulary-variable?"
      gets a better answer there than anywhere else. State in the same breath that it is frozen and
      generates nothing, so the citation cannot be misread as an invitation to edit it.
- [ ] **§4 Fence rules and canonical guards.** INVARIANT 1 as authoring guidance, then one
      canonical guard per gate assertion, **cited by letter**:
      | Letter | The gate asserts | Guard that satisfies it |
      |---|---|---|
      | H | no non-zero exit that also writes stderr or carries a computed number | establish every path the fence reads *inside that fence* |
      | N | never `rc 0` with digits when the notes dir is absent | `[ -d "$DIR" ] \|\| { echo "error: …" >&2; exit 1; }` before any count |
      | U | no read of a variable defined in another fence | re-declare, or take it from `$ARGUMENTS` |
      | S | no stale allowlist entry | if you fix a listed fence, delete its line |
      Cite the letters; do not restate what the gate asserts in your own words — a guard example
      that drifts from the gate is worse than no example.
      **§4 must also state when the guard fires**, or it teaches the H/N collision. H fails a fence
      that exits non-zero *and* writes stderr; the N guard does exactly that. There is no conflict
      because the guard fires only when its precondition is genuinely absent — which on a healthy
      vault is never, so H never sees it. Omit that sentence and an author will apply the pattern
      unconditionally to a fence that runs on the healthy fixture, reproducing the D2-vs-H collision
      this repo already hit once and resolved by changing the fixture.
- [ ] **§5 Prose contracts.** Definition, the §5e worked example, and the three required clauses
      (precondition / failure signature / verifier-and-when) from the spec. Plus the checkable rule:
      **every filesystem path named in a prose contract must exist in the packaged plugin.**
- [ ] **§6 Which fence to use.** Good examples go in ` ```bash ` and are executed by the gate.
      Counter-examples go in ` ```text ` and are invisible to it. State this rule in the document
      itself — it is the only thing keeping Task 3 from failing on deliberately-broken illustrations.

**No narrative.** `writing-skills` names *Narrative Example* an anti-pattern: "In session X we found
Y" is too specific to reuse. This spec and plan are dense with `§5e`, commit hashes, and "the
collision this repo hit once" — correct in a project record, poison in a reference. Each incident
gets **at most one compressed line** stating the rule it produced. If a paragraph cannot survive
having its date and commit hash deleted, it belongs in `ops/observations/`, not here.

**Done when:** all six sections exist, each in the form its row prescribes, every count in §2/§3
matches a command a reader can re-run, no section restates something CONTRIBUTING.md or the gate
already defines, and no section names a commit hash or a date.

---

## Task 4 — GREEN: verify the reference against fresh agents

**Files:** ledger only.

Executing examples (Task 5) proves they *run*. It does not prove the document can be **found**,
**applied**, or that it **covers** the common case — the three scenario types `writing-skills`
prescribes for reference skills. Task 2's control is re-run here with the document present.

- [ ] **Retrieval:** subagent, given the repo and "add a counting fence to `skill-sources/next/`",
      is asked what it consulted. If it never opens `reference/skill-authoring.md`, the pointers
      from CONTRIBUTING.md and CLAUDE.md (Task 6) are not doing their job — fix the pointers, not
      the document.
- [ ] **Application:** the same subagent's fence must pass H/N/U/S first try, both shells.
- [ ] **Gap:** ask it what it needed and could not find. Its answer is the next section, or the
      evidence that none is needed.
- [ ] **5+ reps, and read every result manually.** The skill is explicit that single samples lie and
      that automated scoring overstates both failure and success. **Variance is the metric** — if
      five reps produce five different fence shapes, the guidance is not binding and the form is
      wrong, regardless of whether each one passes.

**Done when:** ≥4 of 5 reps retrieve the document unprompted and produce a passing fence, and the
gap answers have either been folded in or recorded as deliberate omissions.

---

## Task 5 — Make the reference's examples gate fixtures

**Files:** `reference/test/fence-isolation.test.sh`.

- [ ] **Step 1 — Extend the scan set, `else` branch only.** `:250-256` is a two-branch
      construct. The `TARGET` branch (`[ -f "$ROOT/$TARGET" ]`) already accepts **any** path, not
      just `SKILL.md` — so a scoped run `$SELF reference/skill-authoring.md` works today with no
      edit, and that is what makes Step 3's non-vacuity proof a 20-second run instead of a
      five-minute sweep. **Edit only the unscoped `else` at :255**, appending the doc to the
      `find` output. Leave `TARGET` alone.
      Then check two downstream consumers of `FILES`: the `files=` count at `:584`
      (`printf '%s\n' "$FILES" | grep -c .` — must read 27) and the slug derivation at `:259`,
      which strips `/SKILL\.md$` and maps `/` → `--`. A file not named `SKILL.md` keeps its
      extension, giving the label `reference--skill-authoring.md f01`. That is usable; confirm it
      rather than assume, and widen the `sed` only if it is not.
- [ ] **Step 2 — Run and iterate.** Every ` ```bash ` example must pass H/N/U/S against both the
      full and hollow fixtures, in both shells. An example that cannot pass is either wrong (fix it)
      or a counter-example (move it to ` ```text `).
- [ ] **Step 3 — Prove the wiring is not vacuous.** Plant a defect in one example (drop its
      `[ -d ]` guard), confirm the gate **fails**, restore it, confirm the gate passes. Paste both
      results into the commit message. Without this the extension may be scanning nothing — the
      exact defect primitive 10 shipped for months.

**Done when:** `files=` in the gate header has incremented, the non-vacuity proof is in the commit
message, and both shells pass.

---

## Task 6 — Re-point the existing prose surfaces

**Files:** `CONTRIBUTING.md` (INVARIANT 1 §116, INVARIANT 2 §133, "Prose is a contract" §189),
`CLAUDE.md`.

- [ ] Replace restatement with a pointer to `reference/skill-authoring.md` in each of the three
      sections. Keep the invariant *statement* in CONTRIBUTING.md — a contributor must still meet
      the rule on first read — and move only the **how-to** into the reference. Three surfaces that
      can disagree is divergence 2 in a new costume; two surfaces with one direction of reference
      is not.
- [ ] Add the reference to CLAUDE.md's supporting-layers list beside `methodology/` and
      `reference/vocabulary-transforms.md`.

---

## Task 7 — Bump the version, and close the `0.8.0` collision while doing it

**Files:** `.claude-plugin/plugin.json:3`, `.claude-plugin/marketplace.json:10,16`, `plugin.json:3`.

The bump is not bookkeeping. Task 5 of Spec C found the published plugin and this repo tree **both
calling themselves `0.8.0`** while differing materially — published `skills/upgrade/SKILL.md` is 395
lines (§5a–§5d), the repo's is 465 (§5a–§5g), and the published tree has no `reference/lib/` at all.
A version string that does not identify a unique artifact is the same silent-failure class as
everything else here.

**The root `plugin.json` question is settled — delete it.** Researched against
`/volumes/containers/superpowers`, a mature multi-platform plugin:

- It has `.claude-plugin/{plugin.json,marketplace.json}` and **no root `plugin.json`**. Root-level
  manifests there belong to *other* ecosystems — `package.json` (npm), `gemini-extension.json`
  (Gemini) — and every other platform gets its own dot-directory: `.codex-plugin/`,
  `.cursor-plugin/`, `.kimi-plugin/`, `.pi/`, `.opencode/`.
- arscontexta's root `plugin.json` is a **byte-identical duplicate** of `.claude-plugin/plugin.json`.
  It carries no field the canonical file lacks, is untracked, and can only ever drift. It is not a
  second manifest; it is a copy someone left behind.

- [ ] **Delete the untracked root `plugin.json`.** `.claude-plugin/plugin.json` is canonical.
- [ ] **Adopt superpowers' `.version-bump.json` pattern.** A root config declaring every
      version-carrying file and field, dotted paths supported for nested entries:
      ```json
      { "files": [
          { "path": ".claude-plugin/plugin.json",      "field": "version" },
          { "path": ".claude-plugin/marketplace.json", "field": "plugins.0.version" }
        ],
        "audit": { "exclude": ["ops/changelog.md", ".git"] } }
      ```
      Port `scripts/bump-version.sh` — it offers `--check` (declared files agree) and `--audit`
      (repo-wide grep for the old version string anywhere outside the exclude list, which is the
      mechanism that would have caught `0.8.0` surviving in an unlisted file).
- [ ] **Improve on the source: wire `--check` into CI.** Superpowers has **no `.github/workflows/`
      at all** and no pre-commit version hook — its script is a manual release tool, which is
      precisely why a stale version can survive there. arscontexta already runs 11 CI steps, so
      `bump-version.sh --check` becomes step 12 and the drift cannot ship.
- [ ] **Move all sites together** to `0.9.0` — minor, not patch: additive work plus one structural
      change (a directory frozen and gated).
- [ ] **Re-install and diff.** `/plugin uninstall` + `/plugin install`, then confirm the cache
      directory is now `0.9.0/` and that `skills/upgrade/SKILL.md` line counts match between trees.
      If they still differ, the bump exposed a packaging defect rather than fixing one — record it
      and stop, because that is the real finding.

---

## Task 8 — Decide the prose-contract path checker

**Files:** none, or `reference/check-prose-contracts.sh` (new) + `.github/workflows/checks.yml`.

The spec's §5 rule — *every path named in a prose contract must exist in the packaged plugin* — is
mechanically checkable and would have caught the §5e defect that four gates, a 127 KB review, and a
live vault run all missed.

- [ ] **Decide:** build it now, or record it as a known gap with the §5e defect named as the
      motivating case. **Recommendation: record, don't build — even after Task 5.** The bump makes
      the two trees *distinguishable*, which is necessary but not sufficient: the checker needs
      "the packaged plugin" to be a defined build target, and this repo has no build step at all.
      Task 5's re-install diff is the honest interim check — a human comparing two trees once, at
      release. Building an automated checker against a target that is still only "whatever
      `/plugin install` happened to copy" produces a green check that proves nothing, which is the
      failure this whole plan exists to prevent.
- [ ] Whichever way: the decision and its reason go in the plan and in `CLAUDE.md`'s divergence
      list, not only in a commit message.

---

## Verification (run before any PR, both shells)

```
bash reference/check-portability.sh                       # rc 0
for s in bash zsh; do
  $s reference/test/link-extraction.test.sh               # 19/19
  $s reference/test/guard-failure.test.sh                 # 19/19
  $s reference/test/fence-isolation.test.sh               # PASS, files= incremented
done
./reference/validate-kernel.sh ~/second-brain             # 15 PASS / 0 FAIL, unchanged
```

Baseline recorded before any edit, so "unchanged" is a claim with evidence behind it:

```
bash: files=26 fences=74 run=71 skipped=3 known-open=0 · H0 N0 U0 S0 · PASS
zsh:  files=26 fences=74 run=71 skipped=3 known-open=2 · H0 N0 U0 S0 · PASS
KNOWN_OPEN table: 2 entries, both `~H~ZSH ONLY:` (skill-sources/seed f01, skills/health f08).
Both fire under zsh only — hence known-open=0 vs 2. `files=` must increment after Task 5.
```

The four gates verify the reference's examples **execute**. They cannot verify it is findable,
applicable, or complete — that is Task 4, and it is not optional. A document whose examples all pass
and which no agent ever opens is a green check that proves nothing, which is the defect class this
whole plan is about.

---

## Review

One reviewer dispatch after Task 5 (the gate wiring is where a silent no-op would hide), and one
whole-branch review at the end on the most capable model. Reviews get a diff file, never a pasted
diff. Do not pre-judge findings in the prompt.

**Task 4's subagents are not reviewers and must not be dispatched as such.** They are test subjects:
they get the repo and a task, never the plan, never the reference by path, never any hint that the
document exists. A subject told where to look has answered the wrong question — retrieval is the
thing being measured.

---

## Out of scope

- Divergence 1 (allowlist keys on `(letter, label)`). Recorded as a deliberate non-fix.
- The uncommitted README claiming Antigravity availability. Still the user's call.
- Pushing or opening a PR for `fix/spec-c-primitive-10`. Not authorized.
