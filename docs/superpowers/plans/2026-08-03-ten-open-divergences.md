# Plan — Spec F: the ten open divergences

**Spec:** `docs/superpowers/specs/2026-08-03-ten-open-divergences-design.md`
**Branch:** cut fresh from `main` at `769c221`.
**Ledger:** `.superpowers/sdd/2026-08-03-ten-open-divergences/progress.md` — authoritative over the
checkboxes below. **The ledger is gitignored.** It is a working log, never a record. Anything that
must survive the branch goes in a tracked file, and each task below says which. Spec E learned this
twice; see Task 7.

---

## Global Constraints

- Files under `skill-sources/` are **templates**. Never substitute a placeholder with a concrete
  value. `skills/` are the plugin's own commands and carry none.
  `platforms/shared/skill-blocks/` is **frozen and gated** — do not touch it. That is why D4 is
  reclassified rather than fixed.
- Every gate runs under **both bash and zsh**. Shipped bash/zsh forks so far: `read -r path` (zsh's
  `PATH`-tied array), two non-matching-glob aborts, and a hand-typed `zsh bump-version.sh`. Other
  zsh-special names to avoid as `read` targets: `status argv cdpath manpath module_path options
  prompt fignore psvar watch`.
- Each ```bash fence in a `SKILL.md` is **its own shell invocation**. Nothing crosses a fence
  boundary — not a variable, not a sourced function. Re-source and re-guard in every fence.
- `grep` in a Claude Code session is ugrep. Patterns containing `{` or `}` need `-F`; `grep -P` is
  unavailable on the CI image. Verify with `/usr/bin/grep`.
- **Prose and code move in the same commit.** Every count written into prose must be re-derivable by
  a command stated beside it.
- **Every "Done when" names a command whose output distinguishes fixed from broken.** Not a claim
  about state that a passing run cannot confirm.
- **Assert that a mutation applied before trusting its result.** A `sed`/`perl` that matches nothing
  reports the same green as a robust assertion. Spec E shipped this twice, and a tail-keyed sweep
  also ate two correct `stat` chains — so assert both that the target changed *and* that nothing else
  did.
- **Execution model: implement directly, dispatch reviews.** Sonnet exploratory agents die of
  autocompact thrashing here; dispatch any subagent on opus. Reviewers have found a Critical the
  author missed, three times now.
- **Dispatch parallel reviewers in separate worktrees** (`isolation: worktree`). Spec E ran two on one
  shared tree while both mutation-tested it.
- **Never read a subagent's output file before the agent reports done.**
- Backports from `~/second-brain` reverse two transforms: vocabulary → canonical
  (`reference/vocabulary-transforms.md`), and concrete paths → `{vocabulary.*}` placeholders.
- `~/second-brain` is **read-only** for this work. Copy it if you need to mutate it, and delete the
  copy when done — Spec E left 5.5 GB of scratch behind.

---

## Task 1 — D1: teach the kernel validator to read the vault it was given

The centrepiece. This is the only entry actively reporting a false pass on every generated vault.

- [ ] **Step 1 — Reproduce the soft pass first.** Run `./reference/validate-kernel.sh ~/second-brain`
      and capture the two consecutive lines (`PASS … files contain wiki links` /
      `WARN No wiki links found to check`). A fix with no recorded "before" cannot be shown to have
      changed anything.
- [ ] **Step 2 — Confirm the root cause, not the symptom.** For each of `01_thinking`, `notes`,
      `00_inbox`, `04_meta/logs` and `$VAULT/../self`, record PRESENT/ABSENT against the field vault.
      Expect all five ABSENT. Then show the real directory yields work:
      `. reference/lib/link-extraction.sh && extract_link_targets_recursive ~/second-brain/nodes | grep -c .`
      → expect **2681**.
- [ ] **Step 3 — Do NOT add `nodes/` to the list.** That makes this vault pass and the next one fail.
      Derive the notes directory from the vault itself. Candidate sources, in preference order:
      the vault's `ops/derivation-manifest.md` vocabulary mapping (authoritative — it is what
      `/upgrade` 5b is told to preserve), then `ops/config.yaml`, then a shape-based scan. State in
      the script's header which source is authoritative and what happens when it is absent.
- [ ] **Step 4 — Fix `$VAULT/../self` too.** It resolves outside the vault; primitive 8 finds the self
      space at `$VAULT/self` and passes. Same bug, same line.
- [ ] **Step 5 — Prove it on a fixture with an arbitrary directory name**, not on `~/second-brain`.
      Build a vault whose notes live in `zzz-arbitrary/`, containing one note with a valid link, one
      with a dangling link, and one link inside a fenced code block that must NOT count. A fix
      verified only against the field vault proves the list now contains `nodes/`.
- [ ] **Step 6 — Make "never ran" impossible to print as a pass.** If the notes directory cannot be
      resolved, the primitive must FAIL with the reason, not WARN. `WARN No wiki links found to
      check` beside `PASS 3786 of 5253 files contain wiki links` is the defect.

**Done when:** on the fixture, `validate-kernel.sh` reports exactly 1 dangling link and 0 for the
fenced one; deleting the fixture's notes directory turns the primitive FAIL (not WARN); and the field
vault's two contradictory lines no longer both appear.

---

## Task 2 — D6: remove the last inlined wiki-link matcher

- [ ] **Step 1 — Count both trees before touching anything.**
      `grep -cF 'grep -rl "\[\[' skill-sources/graph/SKILL.md` → 1;
      `git show 5a4ab28:skill-sources/graph/SKILL.md | grep -cF 'grep -rl "\[\['` → 2.
- [ ] **Step 2 — Confirm the library is sourced in that fence.** Line 434 sits in a fence that must
      source `ops/lib/link-extraction.sh` itself. If it does not, the fix is to add the sourcing and
      guard, not to reach across the boundary.
- [ ] **Step 3 — Replace the loop**, matching how the orphan loop was converted in Spec E.
- [ ] **Step 4 — Prove the change is behavioural, not cosmetic.** Build a fixture where the naive form
      and the library disagree: a note whose **body** contains `[[Target]]` inside a fenced block, and
      a link differing only by case. Record both counts before and after.
- [ ] **Step 5 — Then correct the prose.** CLAUDE.md's closed entry and divergence 6 both describe
      this as open; both must move in this commit.

**Done when:** the fixture's naive count and library count differ, the shipped fence produces the
library count, and `grep -cF 'grep -rl "\[\['` over `skill-sources/` returns 0.

---

## Task 3 — D7 + D8 (absorbing D9): one frontmatter parser, one status vocabulary

- [ ] **Step 0 — RED: build the discriminating fixture and watch the current code fail on it.**
      Before writing a parser, create the four-note case from Step 5 and run today's
      `grep -rl '^status:'` against it. Record the number. It must be **1** where the true answer is
      **2** — the body-fenced `status: pending` is counted as frontmatter. **If it returns 2, the
      naive form is not broken on this fixture and the fixture is wrong; fix the fixture before
      writing the parser.** A parser built without a failing baseline cannot be shown to have fixed
      anything.
- [ ] **Step 1 — Enumerate the status vocabulary by command, not by reading.** Spec B's enumeration
      was incomplete, which is how D7 survived. Produce a single command that lists every declared
      `status` value across `generators/` with its file and line, and paste its output into the
      commit. Expect the `schema.md` / `atomic-notes.md` disagreement to appear in it.
- [ ] **Step 2 — Resolve the enum in one direction and say which.** `schema.md:30` and `:137` include
      `open`; `atomic-notes.md:94` does not. Pick one, change the other, and state why in the file
      that changes.
- [ ] **Step 3 — Build the shared frontmatter-field extractor.** One implementation, alongside
      `reference/lib/link-extraction.sh`, versioned the same way, failing loud the same way. It must
      distinguish a frontmatter field from a same-named line in the body — including inside a fenced
      block.
- [ ] **Step 4 — Convert the three naive sites**: `OBS_COUNT`, `TENSION_COUNT`, and `skills/health`.
      Assert each mutation applied *and* that nothing else changed.
- [ ] **Step 5 — Grow the fence-gate fixture in the same commit (this is D9).** Add to
      `reference/test/fence-isolation.test.sh` a discriminating set in the **notes** directory: one
      note with `status: active`; one whose body carries `status: pending` inside a fenced block; one
      nested a directory down with `status: archived`; one with no frontmatter at all. True answer for
      "notes missing a status field" is **2**. Against it the correct parser returns 2, the naive
      `grep -rl` returns 1, and a wrong-field parser returns 4.
- [ ] **Step 6 — Record that D8 was latent, not manifest.** All 14 matching files in the field vault
      carry the line inside frontmatter. The fix is right; the claim "this was producing wrong
      numbers" would not be.

**Done when:** the three-way fixture returns 2 / 1 / 4 for correct / naive / wrong-field, in both
shells, and no `grep -rl '^status:'` remains in `skill-sources/` or `skills/`.

---

## Task 4 — D5: pick one namespace for the self-evolution thresholds

Parked twice. This task resolves it or states, in a tracked file, why it cannot be.

- [ ] **Step 1 — Record the live contradiction before changing anything.** In the field vault: 14 open
      observations, 8 open tensions; `/rethink` reads `maintenance.conditions.*` (20/10) and stays
      silent; `/next` and `/remember` read `self_evolution.*` (10/5) and both fire. Capture that.
- [ ] **Step 2 — Decide, with the reader's limit as an input.** `read_config.sh` resolves **one** level
      of nesting. `maintenance.conditions.*` is three. Choosing it means deepening the reader or
      accepting the hook cannot read it; choosing `self_evolution.*` means the field vault's tuned
      20/10 keeps losing to a seeded 10/5. Neither is free — state the trade-off taken.
- [ ] **Step 3 — Whatever is chosen, the generator must emit only that namespace.** The split exists
      because two generations disagreed. Check `generators/` and `skills/setup` for what is written at
      generation time.
- [ ] **Step 4 — Update `/upgrade` 6c to match.** It currently reports `[split]` and refuses to act.
      Once one namespace is authoritative, 6c should migrate rather than merely report — but it must
      still never overwrite a tuned value with a default.
- [ ] **Step 5 — If the decision cannot be made here, park it in `CLAUDE.md`**, not in the ledger,
      with the trade-off written out.

**Done when:** one namespace is read by `/next`, `/remember`, `/rethink` and the hook; a vault
configured to 20/10 produces the same threshold behaviour from all four; and the field vault's
contradiction is reproducible as a before-state and absent as an after-state.

---

## Task 5 — D2: make the version bump atomic

- [ ] **Step 1 — Reproduce the partial bump.** Make `pkg/marketplace.json` unparseable, run
      `bump-version.sh 8.8.8`, and record that `pkg/plugin.json` moved while `marketplace.json` did
      not.
- [ ] **Step 2 — Write all declared sites to temps, then commit them together.** A failure anywhere
      leaves every site unchanged.
- [ ] **Step 3 — Do not pin on-disk state in the existing assertions.**
      `reference/test/bump-version.test.sh` deliberately asserts only that the run does not *report
      success*, so that an atomic fix does not read as a regression. Add new assertions for the
      atomic property rather than tightening the old ones.
- [ ] **Step 4 — Assert no temp files survive either path** — success or failure. Spec E shipped a
      vacuous version of exactly this assertion, which passed because the branch it named was
      unreachable.

**Done when:** the reproduction from Step 1 leaves **both** files at the old version, no `.tmp.`
files remain, and `bump-version.test.sh` passes in both shells with the new assertions failing if the
temp-and-commit logic is reverted.

---

## Task 6 — D3: the three thresholds declared nowhere

- [ ] **Step 1 — Decide whether each threshold should be configurable at all.** `SESS_COUNT ≥ 5`,
      `INBOX_COUNT ≥ 3`, `DAYS_STALE ≥ 30`. Inventing config keys nobody asked for is its own defect;
      so is a hardcoded number that three surfaces disagree about. Answer per threshold.
- [ ] **Step 2 — Do not merge the two 30s.** `DAYS_STALE` is methodology-notes-behind-config drift;
      `/next`'s `stale_notes` is "not modified in 30+ days". Same number, different subject. If both
      become configurable they need different keys.
- [ ] **Step 3 — Whatever is decided, one surface owns each threshold**, and grepping its value finds
      it in exactly one place.

**Done when:** for each of the three, either a config key exists and the hook reads it, or the file
states in a comment that it is deliberately fixed and why — and `CLAUDE.md` divergence 3 matches.

---

## Task 7 — D10 + D4: make a deferral land somewhere it survives, and stop listing what cannot be done

- [ ] **Step 0 — RED: capture the baseline verbatim before writing any guidance.** The failure has
      occurred twice and was never recorded in the form that would let anyone check a fix. Extract
      both instances: `git log --format=%B` for `741b2b7` and for the Spec E review-fix commit,
      quoting the exact sentence each uses ("Recorded in the ledger rather than…", "recorded for the
      whole-branch review"). Then show what a reader would find: `git log --stat` for each, proving
      no tracked file changed. **If both commits turn out to have touched a tracked record, there is
      no failure here and this task collapses to Step 3 — stop and say so.**
- [ ] **Step 1 — Annotate plan Task 2 Step 4 in the Spec E plan.** It is ticked `[x]` for a check that
      mis-fired on `graph`, `next` and `remember` and was never shipped. Annotate it the way that
      plan's other superseded steps were annotated, and correct its done-when.
- [ ] **Step 2 — Fix this STRUCTURALLY, not with a prose rule.**

      **The form matters and the first draft of this plan got it wrong.** Classified against
      `superpowers:writing-skills` → *Match the Form to the Failure*, this is
      **"omits a required element from something they already produce"** — the author does produce a
      commit message and a ledger entry; the tracked record is what goes missing. That row prescribes
      **"structural: a REQUIRED field or slot in the template they fill in"** and names
      **"prose reminders near the template"** as the wrong form. A prose rule in `CONTRIBUTING.md`
      saying records must be tracked is itself an untracked-by-enforcement record — and both people
      who made this mistake already knew `.superpowers/` was scratch.

      So:

      1. **Add a `## Deferrals` section to this plan file and to the plan template**, with a required
         value — either one line per deferral naming the tracked file it landed in, or the literal
         word `none`. An empty section is a failure, not a default.
      2. **Prefer a gate over prose if one is cheap.** `superpowers:writing-skills` also says: *if a
         constraint is enforceable with validation, automate it — save documentation for judgment
         calls.* Assess whether "a commit message containing the word *recorded* must also touch a
         tracked file" is checkable in a pre-commit hook. **If it produces false positives on ordinary
         commits, do not ship it** — say so in the report and fall back to the structural slot alone.
         A gate that cries wolf is worse than the prose it replaced.
      3. Only after 1 and 2, write prose — and only to explain *why* the slot exists.
- [ ] **Step 3 — Reclassify D4 as won't-fix.** `platforms/shared/skill-blocks/stats.md:94-95` is in a
      frozen tree that generates nothing and is gated by `check-portability.sh` check 4. Move it out
      of "Known open divergences" into a stated won't-fix with the reason. Do not touch the file.
- [ ] **Step 4 — Re-derive every remaining number in the divergence list**, as Spec E's Task 7 did,
      and update the header date. The list drifted three ways in one week: a live-vault count moved,
      a repo count moved because a branch changed it, and an entry described a defect fixed in the
      files it named while live in one it did not.

**Done when:** these four commands produce these outputs —

```bash
# 1. The Deferrals slot exists and is non-empty in this plan.
awk '/^## Deferrals/{f=1;next} /^## /{f=0} f&&NF' \
    docs/superpowers/plans/2026-08-03-ten-open-divergences.md | grep -c .   # >= 1

# 2. No divergence entry lacks a re-derivation command. Each numbered entry must
#    contain a backticked command or a ```bash block before the next entry.
#    Expected: every numbered entry accounted for, zero without.

# 3. D4 is out of the open list and in a won't-fix section naming the freeze.
grep -c 'stats.md:94-95' CLAUDE.md                                          # >= 1
awk '/^## Known open divergences/,/^### Closed on/' CLAUDE.md \
  | grep -c 'stats.md:94-95'                                                # 0

# 4. Spec E's Task 2 Step 4 no longer reads as a shipped check.
grep -A2 'Step 4 — Add the assertion' \
    docs/superpowers/plans/2026-08-03-fourteen-open-items.md | grep -ci 'not shipped\|superseded'
```

A gate, if Step 2.2 concludes one is viable, must additionally fail on a fabricated commit message
containing "recorded" with no tracked-file change, and pass on the last 20 real commits — **both
directions measured, not asserted.**

---

## Review

Two dispatches, both opus, both in **separate worktrees** (`isolation: worktree`) — Spec E ran two
reviewers on one shared tree while both mutation-tested it. One after Task 1, because it is the
centrepiece and the only entry whose current state is a false pass. One whole-branch at the end.
Reviewers get a diff file, never a pasted diff, and no pre-judgment of findings.

Carry into the final review: the numerical-correctness gap (no gate asserts a computed number is
correct — now stated in `CLAUDE.md`, still unbuilt), and any Minor findings parked along the way.

---

## Deferrals

**Required section. One line per deferral naming the tracked file it landed in, or the literal word
`none`. An empty section is a failure, not a default** — that is Task 7's entire subject, and this
slot is the fix for it. `.superpowers/` is gitignored; a deferral recorded only there does not exist.

This section is itself a tracked file, so "recorded here" is a valid answer where a deferral has no
better home. It is not a valid answer for a *defect*, which belongs in `CLAUDE.md`'s divergence list
where the next contributor will actually read it.

```text
1. check-prose-paths.sh SCOPE omits hooks/scripts/session-orient.sh and
   platforms/claude-code/hooks/session-orient.sh.template, so cross-references added to
   those two files are checked by nothing. Scope is a stated list by design (a shrinking
   discovered scope must not read as clean), so widening it is a deliberate edit, not an
   oversight to correct. Recorded in CLAUDE.md, the check-prose-paths paragraph.
2. No CI gate exercises bump-version.sh's COMMIT FAILED branch: forcing a git commit to
   fail needs chflags (macOS) or chattr +i (Linux), neither portable nor available to the
   CI runner without root. Recorded here.
3. Task 2's title says "atomic"; what shipped is the weaker and accurate property "no
   declared file is modified unless every site staged". Retitle the entry — do not build a
   journal to make the stronger word true. Recorded here; the entry to retitle is in this
   plan.
4. Converting the generators/ status recipes to the shared parser moves a count 13 -> 12
   over ops/methodology/, and the whole difference is one field-vault file with an unclosed
   frontmatter block. Which answer is right (fix the file, or let the library tolerate an
   unclosed block) is a decision with a different owner, not a port. Recorded in CLAUDE.md,
   the D7/D8/D9 remainder paragraph, with both re-derivation commands.
5. Nothing on this branch has run on Linux. Every measurement in CLAUDE.md and in this plan
   was taken on darwin, against BSD coreutils and a grep that is ugrep in-session. CI
   covers the gates on ubuntu; the hand-run numbers are not covered. Recorded here.
6. skills/architect/SKILL.md:179 still inlines a wiki-link matcher. Out of scope for Task 6,
   which closed the class inside skill-sources/ only. Recorded in CLAUDE.md, divergence 12's
   table of executable sites.
7. The commit-message gate assessed in Step 2.2 is NOT shipped, and the plan-file gate that
   would replace it is deferred to the CI-hardening spec. Measurements and reasoning in this
   plan, under Task 7 Step 2.2's outcome below.
```

**Step 2.2 outcome — the gate is not viable, measured both directions.**

The literal proposal ("a commit message containing *recorded* must also touch a tracked file")
cannot be tested in the failing direction, because that state is not constructible: git will not
produce a commit with no tracked change without `--allow-empty`. A check that cannot be made to
fail is not a gate.

The nearest checkable variant — *must touch `CLAUDE.md` or `docs/superpowers/`* — was measured over
the 60 commits ending at **`8218b4a`**, this task's base: 27 mention "record", 3 would fail. **All
three are classified below, because printing three failures and accounting for two invites the
reading that the unnamed one was the inconvenient one.** Exactly one is a true positive
(`741b2b7`).
The second is a false positive (`4c827a6`, whose message says a code comment "records it as an
accepted defect" — the verb, not a claim of having made a record). **So is the third**: `acb1ecf`
says "Recorded for the whole-branch review" while touching only `skills/upgrade/SKILL.md`, but the
namespace decision it deferred *did* ship afterwards, in `1d19542`, and is in `CLAUDE.md`'s
divergence 5 today. The real ratio is therefore **1 true positive to 2 false**, which strengthens
the rejection rather than weakening it — a gate wrong twice as often as it is right. And decisively,
the variant **passes** `c122d9e`, the second and harder known instance, which did touch a plan file
while the three findings it claimed to record went only to scratch.

```bash
git merge-base --is-ancestor acb1ecf 1d19542 && echo 'the deferred record shipped later'
grep -n 'maintenance.conditions' CLAUDE.md | head -3    # where it landed: divergence 5
```

Note the consequence for wording elsewhere: this scan surfaces **three** commits matching the
pattern, while D10 and `CONTRIBUTING.md` both speak of "the two instances". Two is the count of
*genuine* failures, not of matches — and the gap between those two numbers is the entire reason the
gate is not shippable. A gate that greens the harder of the two
instances it exists to catch is asserting a proxy, not the property — the exact failure this
repo's gate inventory spends its length warning about. Re-derive:

```bash
for c in $(git log --format=%h 8218b4a~60..8218b4a); do          # PINNED, not -60
  git log -1 --format=%B "$c" | grep -qi 'record' || continue
  git show --name-only --format='' "$c" | grep -q '^CLAUDE.md$\|^docs/superpowers/' \
    || echo "would FAIL: $c $(git log -1 --format=%s "$c")"
done                                    # 741b2b7 (true), acb1ecf, 4c827a6 (false positive)
git show --name-only --format='' c122d9e   # touches a plan file; the variant passes it
```

**The range is pinned to `8218b4a` on purpose, and the first draft of this measurement was not.**
It said `-60`, a window relative to a moving `HEAD`, so `a46cc54` — a commit of *this* task, whose
message contains the word "record" — slid into the window and the published `27` read `28` five
lines below the number. Re-pinning is the fix rather than writing `28`, which would re-break on the
next commit and again at merge. The conclusion does not move either way: `3 would fail` is stable
across the shift, and `c122d9e` still passes the variant, which is the fact the rejection rests on.
Verify the shift itself is real rather than taking it on trust:

```bash
for c in $(git log --format=%h 8218b4a~60..8218b4a); do git log -1 --format=%B "$c"; done \
  | grep -ci '^.*record' >/dev/null; \
  printf 'pinned:   %s\n' "$(for c in $(git log --format=%h 8218b4a~60..8218b4a); do \
    git log -1 --format=%B "$c" | grep -qi record && echo x; done | grep -c .)"   # 27
printf 'moving:   %s\n' "$(for c in $(git log --format=%h -60); do \
  git log -1 --format=%B "$c" | grep -qi record && echo x; done | grep -c .)"     # 28 and rising
```

One gate **is** viable and is deferred rather than dropped: *every file in
`docs/superpowers/plans/*.md` must contain a `## Deferrals` section with at least one non-blank
line.* It keys on document structure rather than on a word's sense, so it has no false-positive
surface. It is not built here for two reasons. Gate design is assigned to
`docs/superpowers/plans/2026-08-04-ci-hardening.md` and `CLAUDE.md` says not to bolt one on
elsewhere. And it would fail today on the six older plans, whose only fix would be retrofitting
`none` into plans nobody has audited for deferrals — manufacturing records to satisfy a check,
which is the defect this task exists to close.

Propagation of the slot, meanwhile, is empirical rather than enforced: the two most recent plans
(this one and `2026-08-04-ci-hardening.md:255`) both carry it, and a plan here is written by
copying the shape of the last one. **This task added the slot to exactly one plan** — the other was
added by `a1665b7`, which predates the branch. Two of eight, and the six older plans are left alone
on purpose.

**Step 2.1's second clause — "and to the plan template" — is unsatisfiable, and saying so here is
the point.** Step 2.2's gate clause got a full section arguing it was defective as written while
this one was silently dropped, and inconsistent disclosure is worse than either outcome: a reader
comparing the two concludes the template was simply forgotten. There is no plan template in this
repo to edit. `docs/superpowers/` contains `plans/` and `specs/` and nothing else; no file matching
`*template*` exists anywhere in it; and plans here are produced by the `superpowers:writing-plans`
skill, which lives in the plugin marketplace cache outside every path this repo can commit to.
Editing it would change the author's machine, not the repository, and would not survive a plugin
update. Verify both halves rather than taking the claim:

```bash
find docs/superpowers -iname '*template*' | grep -c .   # 0: no template to add a slot to
ls docs/superpowers                                     # plans, specs -- that is all
```

What replaces it is the two-of-eight propagation above and the deferred structural gate. If a plan
template is ever vendored into this repo, the slot belongs in it and this clause becomes live.

---

## Verification (run before PR, both shells)

```bash
bash reference/check-portability.sh                      # exit 0
bash reference/check-prose-paths.sh                      # 0 missing
for s in bash zsh; do
  $s reference/test/link-extraction.test.sh              # 19/19
  $s reference/test/guard-failure.test.sh                # 34/34
  $s reference/test/fence-isolation.test.sh              # PASS
  $s reference/test/bump-version.test.sh                 # 41/41
  $s reference/test/kernel-note-dirs.test.sh             # 36/36
  $s reference/test/threshold-namespace.test.sh          # 52/52
done
./reference/validate-kernel.sh ~/second-brain            # read the LABELS, not the total
```

Counts above were `769c221`'s state when this plan was written; they are now re-derived at Task 7 and
match the run above. Tasks 3 and 5 added assertions, so update these numbers in the same commit that
adds them. That rule was violated once already — Spec E's plan still said `32/32` and `26/26` after
`ce57b25` raised them, and this plan still said `28/28` after Task 5 raised it to `41`. Two suites
were also missing from this fence entirely: `kernel-note-dirs` arrived with Task 1 and
`threshold-namespace` with Task 5, and a verification list that omits a suite is a weaker lie in the
same family as one that misstates its count.
