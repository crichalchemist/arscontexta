# Plan — Spec G: CI hardening

**Spec:** `docs/superpowers/specs/2026-08-04-ci-hardening-design.md`
**Branch:** cut fresh from `main` **after** `fix/spec-f-divergence-drain` merges. Two of Spec G's
subjects (the divergence list's numbering, the six matcher sites) are files that branch is actively
editing; racing it manufactures conflicts in the exact documents G2 exists to keep honest. If
Spec F stalls, re-derive every number in Task 1 against whatever tree this branch actually cuts
from — the counts below are the state at `4e2ed1d` and are expected to drift.
**Ledger:** `.superpowers/sdd/2026-08-04-ci-hardening/progress.md` — a working log, never a record.
**The ledger is gitignored.** Anything that must survive the branch goes in a tracked file, and each
task below says which.

---

## Global Constraints

- Every new gate and suite runs under **both bash and zsh** where its subject does. Shipped
  bash/zsh forks so far: `read -r path` (zsh's `PATH`-tied array), two non-matching-glob aborts,
  zero-padded octal arithmetic, and a hand-typed `zsh bump-version.sh`. Other zsh-special names to
  avoid as `read` targets: `status argv cdpath manpath module_path options prompt fignore psvar
  watch`.
- `grep` in a Claude Code session is ugrep; `grep -P` is unavailable on the CI image. Verify every
  pattern with `/usr/bin/grep` in a shell outside the session. Use `rg`, and route scans through
  `scan_or_die` or an equivalent that keeps exit 2 distinct from exit 1 — `xargs` collapses them.
- **A scan that matches nothing must fail loudly.** Every new check distinguishes three states —
  found / clean / could-not-run — and Task-level probes must reach each one, not just the clean one.
- **Assert that a mutation applied before trusting its result.** A `sed`/`perl` that matches
  nothing reports the same green as a robust assertion; Spec E shipped this twice.
- **Every mutation probe runs in a scratch copy or is reverted and the tree verified clean**
  (`git status --short` empty, or only the files this plan owns). Spec F's probes left the shipped
  tree byte-identical and said so; match that.
- **Prose and code move in the same commit.** Every CI step added by Tasks 2–4 changes the step
  count that Task 1's gate checks — so every one of those commits must update the documented counts
  it stales, and the gate going red in CI is the reminder, not the failure.
- Files under `skill-sources/` are **templates**; never substitute a placeholder.
  `platforms/shared/skill-blocks/` is **frozen and gated** — `testing-milestones.md:410`'s sibling
  sites in the frozen tree are out of reach and out of scope; do not touch the freeze.
- **Every "Done when" names a command whose output distinguishes fixed from broken.**
- **Execution model: implement directly, dispatch reviews on opus, reviewers in separate worktrees**
  (`isolation: worktree`). Never read a subagent's output file before the agent reports done.
- `~/second-brain` is **read-only** for this work; nothing in this plan needs it.

---

## Task 1 — G2: the documented-claims check, RED on the tree it is born into

The check is built *before* the documents are corrected, because the current tree is the RED
baseline: five live stale claims, enumerated in the spec's Reconciliation section. A check first
demonstrated against defects it was designed around is the only kind this repo trusts.

- [ ] **Step 1 — RED: record the five live instances by command, not by citation.**
      ```bash
      bash reference/test/guard-failure.test.sh | tail -1        # passed=34 — doc says 19/19
      grep -n 'passed=19' CONTRIBUTING.md                        # 2 hits, one is the stale one
      grep -n 'eleven CI steps' CONTRIBUTING.md                  # 2 hits
      grep -c '^      - ' .github/workflows/checks.yml           # 16 — CLAUDE.md:284 says 14
      grep -nE '^\*\*[0-9]+\.' CLAUDE.md | awk -F. '{print $1}' | sort | uniq -d   # duplicate number
      ```
      If any of the five has been fixed by the time this branch cuts, say so in the ledger and keep
      the remainder as the baseline; **if all five are gone, the RED baseline is a fabricated
      mutation instead — do not skip the RED step, replace it.**
- [ ] **Step 2 — Write `reference/check-doc-claims.sh`** with the three sub-checks from the spec:
      suite totals (run the four cheap suites under bash, compare against the expectation stated
      beside each command in CLAUDE.md's verification fence and CONTRIBUTING's block), step-count
      claims (stated claim list, compared against `grep -c '^      - '` on `checks.yml`),
      divergence-number uniqueness (zero extracted headers exits 2). Stated claim list, not
      discovery; a listed claim that no longer matches its document is ERROR. Exit codes: 0 clean,
      1 mismatch, 2 could-not-run — and the banner prints, every run, that this checks **declared
      claims only, bash-run totals only**.
- [ ] **Step 3 — Watch it fail on the baseline.** Run against the uncorrected tree; require at
      least the Step-1 instances to appear, each named with file and both numbers. A check that
      passes here is broken; stop and fix the check, not the docs.
- [ ] **Step 4 — Correct the documents.** CONTRIBUTING.md: the check inventory ("five"→current,
      "Four run in CI … each under both shells" → the true shape, `19/19` → measured, "eleven CI
      steps" ×2 → derived, and add "read the labels" beside the `15/15` line per Reconciliation
      item 5). CLAUDE.md:284: replace the two stale step counts — prefer stating the counting
      command over a bare number, the house "path count drifts" form. Renumber the second
      divergence 10 (CLAUDE.md:495) to **12** and update the two cross-references (:412, :620) to
      name 12. Coordinate with whatever Spec F's Task 7 has done to this list first.
- [ ] **Step 5 — Wire the CI step and prove both directions.** Add the step to `checks.yml` — which
      changes the step count, so the same commit updates the counts the gate checks; the gate red
      on its own introduction commit is the mechanism working, not an obstacle. Mutations, each
      reverted after: bump one documented total by one → rc 1 naming it; duplicate one divergence
      number → rc 1; break the claim-list extraction (point one claim at a reworded line) → rc 2,
      distinct message.

**Done when:**

```bash
bash reference/check-doc-claims.sh; echo rc=$?                   # banner + rc=0 on corrected tree
grep -nE '^\*\*[0-9]+\.' CLAUDE.md | awk -F. '{print $1}' | sort | uniq -d | grep -c .  # 0
grep -c 'passed=19 failed=0.*guard' CONTRIBUTING.md              # 0
```

and the Step-5 mutations each produced their named non-zero rc before being reverted.

**Tracked record for deferrals out of this task:** this plan's `## Deferrals` section.

---

## Task 2 — G1: the interpolated bracket-pattern check

- [ ] **Step 1 — RED: the property finds all six sites and nothing else.**
      ```bash
      rg -n '\\\[\\\[\$' skill-sources/ skills/ platforms/claude-code/ reference/ hooks/ \
        | grep -v 'lib/link-extraction.sh'
      ```
      Expect exactly the six sites divergence 12 (post-Task-1 numbering) lists. **More than six:**
      each extra is either a seventh live defect (record it, add an allowlist entry with reason) or
      a legitimate use the property mis-keys on — if the latter, the property is wrong; fix the
      pattern before shipping, do not allowlist a healthy site (`741b2b7` retired a check for
      exactly that). **Fewer than six:** in-flight work fixed some; the allowlist is seeded with
      what remains.
- [ ] **Step 2 — Add the check to `check-portability.sh`** as the next numbered check, through
      `scan_or_die`, scoped to the executable scan set plus `reference/` (the test-spec doc teaches
      the pattern; teaching it is shipping it), with `reference/lib/link-extraction.sh` excluded by
      path as the sanctioned implementation. Like check 1, it is deliberately strict about comments
      — reword a comment rather than weaken the check, and say so beside the exclusion.
- [ ] **Step 3 — Seed the bidirectional allowlist** with the surviving sites, one stated reason
      each (blast radius, per divergence 12 — the session-orient template entry's reason must name
      SessionStart). Behavior: a listed site that stops matching, or whose file is gone, fails as
      STALE; raw scan zero while the list is non-empty is STALE, not clean.
- [ ] **Step 4 — Prove both directions, then restore.** In a scratch copy: add a seventh
      `grep -rl "\[\[$X\]\]"` to any in-scope file → FAIL naming it; delete one allowlisted site's
      line → STALE naming the entry; restore → PASS with the six absorbed and printed. Then re-run
      `guard-failure.test.sh` in both shells — a new check in the shared guard changes what every
      caller sees, and this exact coupling took that suite from 19/19 to 16/3 once. Extend its
      assertions to cover the new check's failure path (mkroot fixtures carry no bracket-grep, so
      assert the clean path *and* add a fixture-level violation case).
- [ ] **Step 5 — Update the prose that this check changes.** CLAUDE.md's check-2 blind-spot
      sentence and divergence 12's "structurally blind" claim both stop being true; move them in
      this commit. Guard-failure's new total stales CLAUDE.md's `34/34` and Task 1's gate will say
      so — update in the same commit.

**Done when:**

```bash
bash reference/check-portability.sh; echo rc=$?                  # rc=0, new check listed, 6 absorbed
for s in bash zsh; do $s reference/test/guard-failure.test.sh | tail -1; done   # equal totals, failed=0
bash reference/check-doc-claims.sh; echo rc=$?                   # rc=0 — counts moved together
```

and the scratch-copy probes produced FAIL and STALE respectively before restoration.

---

## Task 3 — G3: the placeholder non-decrease gate

- [ ] **Step 1 — RED: reproduce the hazard in a scratch clone.** Commit a change substituting one
      `{vocabulary.notes}` in a `skill-sources/` template with `nodes/`; run the CONTRIBUTING.md:179
      manual check against it and record the `HARDCODED PLACEHOLDER` line. This is the failure the
      gate automates; a gate built without seeing it fire is built on the doc's word.
- [ ] **Step 2 — Write the gate script** (suggested: `reference/check-placeholder-count.sh`, taking
      the base ref as an argument so it is runnable locally against `main` and in CI against the
      merge base). Single definition of the marker pattern; CONTRIBUTING.md's inline copy becomes a
      pointer to the script in the same commit — two spellings of one command is the drift hazard,
      and this plan must not mint one.
- [ ] **Step 3 — Three exit states, each reached in a probe.** Clean range → 0 with an explicit
      "N templates changed, no count decreased" (or "no templates in range") line; decrease → 1
      naming file and both counts; no merge base / `git show` failure / extractor matching zero
      markers across all of `skill-sources/` → 2, message saying the result is not evidence.
- [ ] **Step 4 — Wire CI with history.** `actions/checkout` defaults to depth 1; the step needs
      `fetch-depth: 0` (or an explicit fetch of `origin/main`) and the gate must exit 2 — not 0 —
      when the merge base is unreachable. Prove it: run once in a depth-1 scratch clone and record
      the rc 2.
- [ ] **Step 5 — The escape that is not silence.** A legitimate decrease requires an allowlist
      entry (file, old→new, reason), bidirectional: stale once counts match again. Document beside
      it that rises are normal (the hybrid qmd query form legitimately doubles one placeholder).

**Done when:**

```bash
bash reference/check-placeholder-count.sh main; echo rc=$?       # rc=0 with explicit range line
# in the scratch clone carrying the Step-1 substitution:
bash reference/check-placeholder-count.sh main; echo rc=$?       # rc=1 naming file, 2 -> 1
# in a depth-1 clone:
bash reference/check-placeholder-count.sh origin/main; echo rc=$? # rc=2, "not evidence" message
```

---

## Task 4 — G4: the hooks/scripts suite

- [ ] **Step 1 — RED: demonstrate today's zero coverage.** Apply a scratch mutation reverting
      `820af90`'s dotted-key routing in `hooks/scripts/read_config.sh` (assert the mutation applied
      — a sed that matched nothing reports the same green); run every existing CI-equivalent gate.
      **Expected: all green.** That all-green run is the defect this task exists to close. Revert;
      verify the tree clean.
- [ ] **Step 2 — Write `reference/test/hook-config.test.sh`** on the `bump-version.test.sh` model
      (fixture tree, subject copied in, run under whichever shell the harness is in). Assertions,
      per the spec: `read_config.sh` three states (absent → default; parsed → value; unparseable →
      stderr + exit 1, **never** the default), section scoping (`other_section.…: 999` does not
      answer), bare keys unchanged against `.arscontexta`; `session-orient.sh` on a
      12-observation/6-tension fixture — config 10/5 fires both CONDITION lines, 99/99 fires
      neither; `vaultguard.sh` inertness without the marker (exit 0, no output — labelled in the
      suite as contract-pinning, not defect-derived). Every negative assertion gets a positive
      companion; run the suite's assertions once against an empty subject and justify each survivor
      in a comment, per the `eb485ac` probe.
- [ ] **Step 3 — Re-apply the Step-1 mutation and watch the suite fail.** The 10/5 and 99/99 rows
      must become identical and at least one assertion red, in both shells — this is `820af90`'s
      own "assertion that would have caught the original defect", now existing. Revert, verify
      clean, re-run green.
- [ ] **Step 4 — Wire two CI steps (bash, zsh)** and, in the same commit, widen the existing
      `Shell syntax check` step to every tracked `*.sh` with a count guard:
      `git ls-files '*.sh' | wc -l` greater than zero asserted before the loop, so an empty
      enumeration fails rather than vacuously passing. Same commit updates every count this stales;
      Task 1's gate enforces that this sentence was not optional.

**Done when:**

```bash
for s in bash zsh; do $s reference/test/hook-config.test.sh | tail -1; done   # equal totals, failed=0
grep -c '^      - ' .github/workflows/checks.yml                              # documented number, re-derived
```

and the Step-3 mutation produced red in both shells before being reverted.

---

## Task 5 — the record that survives, and the expectations handed to in-flight work

- [ ] **Step 1 — Name the expected gates in Spec F's carry-forward.** Spec G items 22 and 23 expect
      gates from Spec F Task 3's commits (the enum consistency assertion; the check-portability ban
      on inlining the frontmatter library once it exists). Add one line to the *Review* section of
      `docs/superpowers/plans/2026-08-03-ten-open-divergences.md` carrying that expectation into
      its final review — a tracked file that work already reads. If that branch has merged with
      Task 3 done and no such gates, file the gap as a new divergence entry instead; do not let the
      expectation live only here.
- [ ] **Step 2 — Fill this plan's `## Deferrals`** with the real list: item 18's contract-marker
      convention (landing place: the spec's "Deliberately not gated" section), and anything parked
      during Tasks 1–4. `none` is a legal value only if literally nothing was deferred.
- [ ] **Step 3 — Re-derive every number this plan and spec state**, dating the sweep — including
      the ones the branch itself changed. Spec G documents that this discipline has a half-life of
      one branch; Task 1's gate now covers the declared claims, and this step covers the rest.

**Done when:** `awk '/^## Deferrals/{f=1;next} /^## /{f=0} f&&NF' docs/superpowers/plans/2026-08-04-ci-hardening.md | grep -c .`
returns ≥ 1, and the line it counts is not the word `none` unless the ledger shows zero deferrals.

---

## Review

Two dispatches, both opus, both in **separate worktrees** (`isolation: worktree`). One after
Task 2 — it modifies the shared guard, the coupling that once took `guard-failure.test.sh` from
19/19 to 16/3, and a reviewer should see the guard change with the suite change beside it. One
whole-branch at the end. Reviewers get a diff file, never a pasted diff, and no pre-judgment of
findings.

Carry into the final review: the numerical-correctness gap (item 16 — still no gate asserts a
computed number is right; G1–G4 do not change that and their green must not be read as if they do),
and whether any Task-1 claim-list entry is already stale again.

---

## Deferrals

**Required section. One line per deferral naming the tracked file it landed in, or the literal word
`none`. An empty section is a failure, not a default.** `.superpowers/` is gitignored; a deferral
recorded only there does not exist.

Ten deferrals, all recorded in tracked files rather than only in the gitignored ledger. Each names
where it landed and what would reopen it.

```text
Item 18 (output-contract marker convention) — deferred to whoever next changes the template
  format. Tracked: docs/superpowers/specs/2026-08-04-ci-hardening-design.md, "Deliberately not
  gated", item 18. Needs an explicit contract marker in the templates before it is checkable.

From Task 2 (check-portability check 6):
  M-2  interp_hits_in is an unanchored -F substring match while the other half parses paths
       differently. Every divergence yields a false FAIL, never a false PASS. Tracked: the
       comment at that function in reference/check-portability.sh.
  M-5  the allowlist is whitespace-delimited, so a path containing a space mis-parses silently.
       No such path exists in the tree. Tracked: same comment block.
  M-3  the property is keyed on the ESCAPED spelling, so `grep -rlF "[[$q]]"` and a two-step
       `pat="[[$q]]"` interpolate and are not flagged. Tracked as a stated limitation in
       reference/check-portability.sh, with the next widening's starting edge named.

From Task 3 (check-placeholder-count):
  -M pairs a rename with an edit only while the sides stay similar, so a file renamed AND
       rewritten end to end arrives as add+delete and cannot be compared. Now NAMED at runtime
       ("NOTE template deleted, not compared") rather than silent. Tracked: the D* branch comment.
  allowlist staleness is scoped to files in the range, so a fully obsolete entry survives until
       some range touches its file again. The price of a range-relative key. Tracked: the
       staleness-loop comment.
  cd "$ROOT" failing is the one rc-2 site the suite does not assert. Tracked: named in
       reference/test/placeholder-count.test.sh's rc-2 section header.

From Task 4 (hook-config):
  auto-commit.sh and write-validate.sh still have zero coverage from any gate. Tracked: this
       line, and the coverage table in reference/test/hook-config.test.sh's header.
  count_notes_by_field returns 0 at rc 0 on an unreadable directory rather than failing — the
       same silent-failure class one layer down, which is why session-orient's scan-failure
       branch is unreachable. Tracked: the comment beside the threshold-0 assertions.
  bare keys fail SILENT where dotted keys fail LOUD on a present-but-empty value — an asymmetry
       between the two paths of one reader. Tracked: this line.
  the awk section/field names are interpolated into an ERE, so `self_evolution.obs.ervation`
       matches `obsXervation`, and a two-level key can return a three-level value. Tracked: this
       line. It was claimed as recorded in a commit message and had landed in NO tracked file —
       divergence 10's exact class, caught in review of the commit that made the claim.
  TMPDIRS+= inside a $( ) helper leaks fixture trees per run. House pattern, not new here:
       bump-version leaks 14, guard-failure 22, placeholder-count 20, hook-config 2. Tracked:
       this line.
```

**Not deferred, and worth distinguishing:** the numbers this branch moved are not on this list
because Task 1's gate now reads them. That is the difference between a deferral and a gap — a
deferral needs a human to remember it, and every count above is checked on every push.

---

## Verification (run before PR, both shells)

```bash
bash reference/check-portability.sh                      # exit 0 — now includes the G1 check
bash reference/check-prose-paths.sh                      # 0 missing (path count drifts)
bash reference/check-doc-claims.sh                       # exit 0 — banner states its scope
bash reference/check-placeholder-count.sh main           # exit 0 with explicit range line
for s in bash zsh; do
  $s reference/test/link-extraction.test.sh              # 19/19
  $s reference/test/guard-failure.test.sh                # 34/34 + Task 2's additions — re-derive
  $s reference/test/fence-isolation.test.sh              # PASS
  $s reference/test/bump-version.test.sh                 # 28/28 (Spec F Task 5 may have raised it)
  $s reference/test/kernel-note-dirs.test.sh             # 36/36
  $s reference/test/hook-config.test.sh                  # Task 4's total, failed=0
done
```

Counts above are the state at `4e2ed1d` on `fix/spec-f-divergence-drain`; Tasks 2 and 4 add
assertions and CI steps, so update these numbers — and the documents Task 1's gate watches — in the
same commit that moves them. The rule was violated once already (Spec E's plan said `32/32` after
`ce57b25` raised it); this branch is the one that finally makes CI say so.
