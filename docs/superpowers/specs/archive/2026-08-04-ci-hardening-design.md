# Spec G — CI hardening: gate the failure modes the repo documents but does not check

**Status:** design
**Date:** 2026-08-04
**Predecessor:** `2026-08-03-ten-open-divergences-design.md` (Spec F, in flight on
`fix/spec-f-divergence-drain`)

---

## What this is

This repo's contributor documents are an unusually complete catalogue of its own failure modes —
CLAUDE.md's divergence list, CONTRIBUTING.md's invariants and traps, `reference/skill-authoring.md`,
and forty-five commit messages that each state what the failure *looked like*. What does not exist
anywhere is the inventory of that catalogue mapped against what mechanically catches each entry.
This spec builds that inventory, reconciles the places where the sources disagree about it, and then
draws a line: **four gates proposed, twelve documented failure modes deliberately left ungated**,
each with the reason.

The line is the real work. Every gate below satisfies four constraints this repo has learned the
hard way, and several obvious candidates fail them:

1. It runs under both bash and zsh where its subject does, and uses no `grep -P` — ugrep in a
   Claude Code session masks that flag's absence from the CI image (CONTRIBUTING.md Trap 2).
2. **A scan that matches nothing fails loudly, never reports clean.** Shipped here at least twice:
   the word-split PCRE scan that printed the all-clear having scanned nothing, and the BSD-sed
   `\033` strip that made every colour-stripped assertion silently match nothing (`d384094`).
3. It keys on the property, not one spelling of it. Divergence 10 exists because a defect class was
   tracked by the string `grep -rl "\[\[` while six live sites spell the same defect `xargs grep -l`
   and `-exec grep -l`. A born-dead assertion pinned to a superseded message string shipped on this
   very branch (`ed3c9c0`).
4. It is provable by mutation. Every fix in `9b1016b` is pinned by a mutation that turns an
   assertion red; a check that cannot fail is worse than absent.

And one constraint of this spec's own: **a gate whose green means less than a reader will assume is
worse than no gate.** `reference/check-prose-paths.sh` is the house example of handling that
honestly — its name, header, and every-run banner all say `checkout only — packaging unverified`.
Each gate below states what its green does *not* mean, and the two that need a banner get one.

---

## The inventory

Every failure mode this repo documents, against what mechanically catches a fresh occurrence.
Re-derived from CLAUDE.md, CONTRIBUTING.md, `reference/skill-authoring.md`,
`.github/workflows/checks.yml`, the two guard scripts, the five test suites, and
`git log main~40..HEAD` (45 commits). Grouped by gate status, because that is the axis this spec
acts on.

### Group I — documented and gated (11)

Listed for completeness and so the proposal below is legible as a delta, not a replacement.

| # | Failure mode | Instance | Gate |
|---|---|---|---|
| 1 | `grep -P` in shipped templates — BSD grep exits 2, pipes into `wc -l`, renders 0, never an error | 8 sites shipped exactly this | `check-portability.sh` check 1 (+ check 3 for `rg -P`), also pre-commit |
| 2 | Greedy / unterminated wiki-link capture regex | the naive-parsing family (closed) | check 2, parts A and B |
| 3 | Any edit, deletion, or unpinned addition in the frozen `platforms/shared/skill-blocks/` | four commits of guard-porting into files that execute nowhere | check 4 (`cksum` manifest; SKIP ≠ PASS; MALFORMED row fails) |
| 4 | `AGENTS.md` drifting into a copy of `CLAUDE.md` | the first draft of `0a78d1f` copied `marketplace.json`; lasted a minute | check 5 (mode 120000 asserted) |
| 5 | Prose naming a repo path that resolves nowhere in this checkout | the class §4 describes, weaker half | `check-prose-paths.sh` (stated file list; missing in-scope file is ERROR; zero extractions exit 2) |
| 6 | Link-library failure rendering as a number | "a failure must never be a number" | `link-extraction.test.sh`, 19 assertions, both shells |
| 7 | The portability guard's own failure paths going quiet | unwritable-ROOT PASS on a modified template (`74bc88e`) | `guard-failure.test.sh`, 34 assertions, both shells |
| 8 | A fence reading a variable or sourced function from a different fence; a missing vault directory counted as 0; a missing tool's 127 read as a defect | seed's four `$FILE` fences; the four N-class zeros | `fence-isolation.test.sh` — 75 fences, 27 files, H/N/U/S, bidirectional allowlist |
| 9 | Version manifests disagreeing between declared sites | two artifacts both calling themselves 0.8.0 while differing materially | `bump-version.sh --check` in CI |
| 10 | The release tool's failure paths — MISSING summarised as agreement, jq's `"null"` at rc 0, unanchored version, the zsh `$path` fork | F3–F7 in `a200b8b` | `bump-version.test.sh`, 28 assertions, both shells |
| 11 | The kernel validator scanning canonical directory names a vault renamed; "never ran" printed as anything softer than FAIL | divergence 1 — `PASS 3786 of 5253 files contain wiki links` directly above `WARN No wiki links found to check` | `kernel-note-dirs.test.sh`, 36 assertions, both shells — the only gate that executes `validate-kernel.sh` |

The bash/zsh fork class (`$path` tied to `PATH`, `nomatch` glob aborts, `PIPESTATUS` empty, octal
zero-padded arithmetic) is gated *for tested code* by every suite running under both shells. It is
**not** gated for `hooks/scripts/`, which has no suite at all — that is proposed gate G4.

### Group II — documented, ungated, proposed (4)

| # | Failure mode | Documented at | Proposed gate |
|---|---|---|---|
| 12 | A note name interpolated into a bracket-matching grep pattern — the naive-matcher class under any spelling. Six live sites; check 2 is structurally blind to all of them | CLAUDE.md divergence 10 | **G1** |
| 13 | The contributor documents' verification numbers drifting from measured reality — expected suite totals, CI step counts, divergence-entry numbering. Five live instances *right now* | CLAUDE.md:270–287, the "re-derive, don't carry forward" rule | **G2** |
| 14 | A template edit hardcoding a `{vocabulary.*}` / `{config.*}` placeholder — one user's layout shipped to everyone. The mandatory check exists in CONTRIBUTING.md and runs only when a human remembers | CONTRIBUTING.md "Backporting", the non-decrease command | **G3** |
| 15 | Behavioral regressions in `hooks/scripts/` — five shipped shell files, zero suite coverage. The config-routing fix (`820af90`) names, in its own message, "the assertion that would have caught the original defect", and that assertion exists nowhere in the tree | CLAUDE.md divergence 3; `820af90` | **G4** |

### Group III — documented, deliberately not gated (12)

The defense of each line is in [Deliberately not gated](#deliberately-not-gated) below.

16. Numerical correctness of what a fence prints (CLAUDE.md:77–89).
17. §4's packaged-plugin path property (`check-prose-paths.sh` header; `cc641ce`).
18. Output-contract fields promised but never assigned (`741b2b7`; divergence 10, first of the two
    entries so numbered).
19. Plan checkboxes lying about status (CONTRIBUTING.md "Keep plan checkboxes honest").
20. Commit messages claiming "recorded" with no tracked write (divergence 10; `769c221`).
21. `kernel.yaml` ↔ `validate-kernel.sh` primitive sync (CLAUDE.md:196–200).
22. The `status` enum disagreeing between generator sources (divergence 7).
23. Inlined frontmatter-field parsing (divergence 8).
24. The `gh`-on-fork and no-hot-reload traps (CONTRIBUTING.md Traps 1 and 3).
25. The 66 contributor-doc fences the fence gate does not execute (`a200b8b` F10).
26. Vacuous assertions inside the test suites themselves (`eb485ac`, `83abd8e`).
27. The partial-bump on-disk state (divergence 2).

---

## Reconciliation — where the sources disagree

The house rule is surface conflicts, never average them. Five found, all resolved; every number
below was re-derived from a command on 2026-08-04, and the settling command is stated. **Two of the
five are live defects in the current tree** — they are what proposed gate G2 exists to catch, and
they are its RED baseline.

**1. How many checks exist and how many run in CI.** CONTRIBUTING.md:84 says "run all five" and
:86 says "Four run in CI on every push, **each under both bash and zsh**". CLAUDE.md:49 says "eight
executable checks. Seven run in CI." **CLAUDE.md is correct; CONTRIBUTING.md is stale by one full
spec cycle** — its list omits `bump-version.test.sh`, `kernel-note-dirs.test.sh`, and
`check-prose-paths.sh` entirely. Its "each under both shells" is additionally wrong for the four it
does name: `check-portability.sh` runs bash-only, a stated decision CLAUDE.md:91–96 records.
Settled by `.github/workflows/checks.yml`, which runs seven of the eight (kernel validation needs a
generated vault), and by CLAUDE.md's own list at :55–64.

**2. The expected guard-failure total.** CONTRIBUTING.md:102–103 says
`# expect: passed=19 failed=0` for `guard-failure.test.sh`. Measured:

```bash
bash reference/test/guard-failure.test.sh | tail -1   # passed=34 failed=0
```

The 19 predates `74bc88e` (+10), `0a78d1f` (+ check-5 coverage), and `9b1016b`/`ce57b25` (+5).
`link-extraction.test.sh` genuinely is 19 — the two suites' totals coincided once, which is
probably why the stale one survived reading.

**3. The CI step count — wrong in two documents, two different ways.** CONTRIBUTING.md:113 and
:274 both say "all eleven CI steps". CLAUDE.md:284 says CI is green on "`main` across all **11**
steps — and **14** on this branch". Measured, using the counting rule CLAUDE.md itself teaches
(count step items `^      - `, because `actions/checkout` carries no `name:`):

```bash
grep -c '^      - ' .github/workflows/checks.yml                    # 16  (15 named) — this branch
git show main:.github/workflows/checks.yml | grep -c '^      - '    # 14  (13 named) — main
```

So CONTRIBUTING's "eleven" is two spec cycles stale, and CLAUDE.md's sentence is stale in both
halves: `main` gained Spec E's three steps when it merged, and this branch's `d384094` added the two
kernel-note-dir steps *after* the sentence was written. **The sentence that teaches the counting
trap is itself miscounted** — and it sits under a header dated 2026-08-03 promising every number was
re-derived. That is not carelessness to scold; it is the demonstration that a dated-sweep discipline
cannot keep a number current between sweeps. A number that changes when the tree changes must be
checked by the tree's own CI or not stated as a number.

**4. Two divergence entries are both numbered 10.** CLAUDE.md:445 (`A ticked plan step for a check
that was built and never shipped`) and CLAUDE.md:495 (`The inlined-matcher search string is a proxy
for the class`), with entry 11 between them. Settled by seniority and by in-flight references: the
ticked-plan entry was numbered 10 at `769c221`, and Spec F's task list refers to it as D10; the
matcher entry was added by `4e2ed1d`, whose message calls it "new divergence 10" — it should be
**12** (11 is taken by the sample-cap entry). The cross-references at CLAUDE.md:412 and :620
("see divergence 10", meaning the matcher entry) go stale-by-ambiguity either way until the
renumber lands. Not renumbered by this spec — the tree is under active review — but the fix is one
header digit and two cross-references, and G2's numbering check is deliberately born red on it.

**5. What "15/15" is a count of.** CONTRIBUTING.md:107 says `# expect 15/15` for
`validate-kernel.sh`. CLAUDE.md:150–156 explains at length that the summary counts result lines,
not primitives — 17 lines for 15 primitives on the field vault — and that finding the target number
in the total is a coincidence of arithmetic. Not a contradiction (a criterion versus a warning
about how to read it), but CONTRIBUTING still teaches reading the total, which is precisely the
reading CLAUDE.md documents as having hidden a violated criterion for several sessions. The
CONTRIBUTING line should carry the same "read the labels" instruction.

No conflict was left unresolved. One adjacent claim was left **unverified**: whether `main`'s CI is
currently green. Verifying it from a fork requires `--repo <you>/arscontexta` (Trap 3), and this
work had no need to — no proposal below depends on it.

---

## The four gates

Format per gate: the failure mode, **the instance from this repo's own history it would have
caught**, the design that satisfies the four constraints, and what it deliberately does not cover.

### G1 — the interpolated bracket-pattern check

**Failure mode.** A note name interpolated into a grep pattern that matches wiki links:
`grep -rl "\[\[$NAME\]\]"` and its `xargs grep -l` / `-exec grep -l` spellings. Wrong three ways at
once, measured on the eight-note fixture in `4e2ed1d`: counts links inside fenced code blocks, does
not case-fold either side, and interpolates the name into a **regex**, so `a.b` is "linked" by any
`[[axb]]` — wrong in both directions simultaneously, with totals that can come out identical before
and after a fix.

**The instance.** Divergence 6 tracked this class by one spelling; `741b2b7` claimed the spelling
was "gone from executable code in both files" while six sites survived under spellings the search
string could not see. All six are live now: `skill-sources/graph/SKILL.md:145`, `:693`,
`skill-sources/stats/SKILL.md:257`, `skills/architect/SKILL.md:179`,
`platforms/claude-code/hooks/session-orient.sh.template:149`, `reference/testing-milestones.md:410`.
`check-portability.sh` check 2 is structurally blind to every one — it keys on a negated class
being *present*, and a fixed-name bracket grep contains no negated class at all.

**Design.** A new numbered check in `check-portability.sh`, keyed on the property rather than any
grep spelling: an occurrence of `\[\[` immediately followed by a `$` interpolation inside a
double-quoted string, in the executable scan set. The escape is the tell — *writing* a link
interpolates into unescaped `[[…]]`; only a pattern being handed to a regex engine escapes the
brackets. That is why the check catches `grep -rl`, `xargs grep -l`, and `-exec grep -l` alike
without enumerating commands, and will catch the next spelling too.

Born red on six sites, by design. It carries a **bidirectional allowlist** in the fence-gate style:
each of the six gets an entry with a stated reason, an entry whose site starts passing or vanishes
fails the check as STALE, so the list drains rather than rots. This is deliberate sequencing —
divergence 10 says the six sites need *separate* review (the session-orient template runs on every
SessionStart, where a fail-loud library guard turns a wrong number into a broken session), and a
gate that waits for all six fixes protects nothing meanwhile. The allowlist ships the protection
against a *seventh* site now.

Loudness: the scan runs through the existing `scan_or_die` path (rg error ≠ no-match), and if the
raw scan finds zero occurrences while the allowlist is non-empty, that is STALE, not clean — the
positive control is the allowlist itself, for as long as it has entries. When the list drains to
zero, the check keeps a fixture-free positive control: it must still *fail* on a mutation
(see plan Task 3's probe) before each release of the check itself.

Mutations that must go red: adding a seventh `"\[\[$` site anywhere in the scan set; fixing an
allowlisted site without removing its entry.

**Deliberately does not cover:** `grep -F "[[$NAME]]"` spellings — `-F` closes the regex hole but
keeps the fence and case-fold defects; extending the property to unescaped brackets would flag
every legitimate link-*writing* site, and a gate that fails healthy templates teaches people to
ignore it (`741b2b7` retired a check for exactly that). Also not covered: a site that sources the
library and misuses it, and everything about whether the resulting count is *right* (see item 16).

### G2 — the documented-claims check

**Failure mode.** The contributor documents state verification numbers — expected suite totals, CI
step counts, divergence numbering — and those numbers drift the moment the tree changes, because
nothing re-derives them between manual sweeps. A stale expected total is worse than none: a
contributor who runs a suite, sees `passed=34`, and trusts the doc's `19/19` concludes something is
wrong — or worse, learns that the documented expectations are decorative.

**The instances — five live in the current tree**, enumerated in Reconciliation above:
CONTRIBUTING's `19/19` against a measured 34; "eleven CI steps" twice against 16 items; CLAUDE.md's
"11 on main / 14 on this branch" against 14/16; two divergence entries both numbered 10. Plus the
class's history: Spec E's plan still said `32/32` and `26/26` after `ce57b25` raised them
(fable I1), and "six checks above" against seven (opus M-1/M-2). This gate would have gone red the
moment each of those was made stale, in the commit that staled it.

**Design.** A new script, `reference/check-doc-claims.sh`, run as one CI step, with three
sub-checks over a **stated claim list** — the `check-prose-paths.sh` scope pattern, because a
discovered scope shrinks silently:

1. **Suite totals.** For each cheap suite named in CLAUDE.md's verification fence and
   CONTRIBUTING's block (`link-extraction`, `guard-failure`, `bump-version`, `kernel-note-dirs`),
   parse the documented expectation beside the command, run the suite once under bash, compare with
   its actual summary line. The fence gate is excluded: its expectation is the word `PASS`, not a
   count, and it costs two minutes per shell.
2. **Step counts.** Any claim in the two documents matching the stated claim-list patterns for
   "all N (CI) steps" is compared against `grep -c '^      - '` on `checks.yml` — items, not names,
   per the counting rule CLAUDE.md:287 states.
3. **Divergence numbering.** Extract `^\*\*N\.` headers between `## Known open divergences` and the
   first `### Closed on`; require the numbers unique. Zero headers extracted exits 2 — the section
   is never legitimately empty.

Loudness: a claim on the stated list that no longer matches its document is ERROR (stale claim
list), not skip — the same rule that keeps prose-paths' shrinking scope from reading as clean. A
sub-check that extracts zero claims where the list says one exists exits 2, distinct from 1 for a
genuine mismatch.

**The banner.** This gate checks *declared claims only*, and prints that every run: it does not
verify arbitrary numbers in prose (fence counts, marker tallies, live-vault figures — those remain
the dated-sweep discipline, and several are documented as "drifts" on purpose), and it runs the
suites under bash only, relying on the CI steps beside it for the both-shell property. A reader who
takes its green as "all numbers in CLAUDE.md are current" has been misled, and the banner is where
that is prevented.

**On constraint 3** — this gate is necessarily coupled to the documents' wording, which looks like
the born-dead-assertion trap. The difference is that the coupling is *declared and bidirectional*:
the claim list names each site, and a site that stops matching fails loudly instead of silently
checking nothing. A rewording costs one claim-list edit in the same commit, surfaced by CI, which
is the intended behavior — the alternative, a gate that quietly stops matching reworded claims, is
`ed3c9c0`'s born-dead assertion as a service.

Mutations that must go red: bump one documented total; add one step to `checks.yml` without
touching the docs; duplicate one divergence number (the current tree already proves this one).

**Deliberately does not cover:** numbers in `docs/superpowers/plans/*` — plan verification blocks
are dated snapshots ("state at `769c221`") and checking them would fail history for being
historical; numbers describing the field vault, which drift as the vault grows; and any claim not
on the stated list.

### G3 — the placeholder non-decrease gate

**Failure mode.** An edit to a `skill-sources/` template replaces a `{vocabulary.*}` or
`{config.*}` placeholder with a concrete value — compiles fine, passes every gate, and silently
ships one user's vocabulary or layout to every future generated system. CONTRIBUTING.md calls the
two reverse-transforms **mandatory** and supplies the exact non-decrease command; it runs only when
a human remembers to run it.

**The instance.** The class has been stopped only by hand, twice on one branch: `7765504`'s plan
specified the literal `ops/` where the three skill-blocks twins carry `{config.ops_dir}` — executing
it as written would have substituted a placeholder; and `a3942c7` records that Task 4's literal code
block "would have destroyed a `{config.ops_dir}` placeholder". Both were caught because the
implementer ran the manual check. This gate is that check made non-optional; the honest statement
is that no *shipped* instance exists in this repo precisely because the manual step has so far
always been run — a defense with no mechanical backstop, in the repo whose CLAUDE.md documents what
happens to defenses like that.

**Design.** A CI step comparing HEAD against the merge base with `origin/main`: for each changed
file under `skill-sources/`, count placeholder markers before and after (the CONTRIBUTING.md:181
pattern becomes the gate's single definition, and CONTRIBUTING points at the gate rather than
carrying a second copy — two copies of one command is the skill-sources/skill-blocks drift hazard
in miniature). Three exit states, all reachable and all distinct:

- `0` — no template changed in the range (stated, not silent), or every changed template's count
  is ≥ its base count;
- `1` — a count decreased, naming the file and both counts;
- `2` — the comparison could not run: no merge base (shallow checkout — `actions/checkout` defaults
  to depth 1, so the workflow must fetch history, and the gate must fail loudly if it did not),
  `git show` failing, or the extractor matching zero markers across the whole of `skill-sources/`
  (positive control: the tree carries markers today, so zero means the pattern broke, not that the
  tree is clean).

A legitimate decrease (a template section deleted outright) needs an escape that is not silence: a
bidirectional allowlist entry naming file, old→new counts, and reason — stale the moment counts
match again. Rises are normal and pass (the hybrid qmd query form legitimately doubles one
placeholder; CONTRIBUTING documents this).

Mutations that must go red: substitute one `{vocabulary.notes}` with `nodes/` in a scratch commit;
run with a depth-1 clone and no fetched main (must exit 2, not 0).

**Deliberately does not cover:** the vocabulary→canonical reverse-transform (whether a template
says `reduce` or `extract` is judgment about words, not counts — a gate cannot tell a renamed
concept from a synonym); `skills/`, which legitimately carries no placeholders and would only add
`0 → 0` noise; and the frozen tree, which cannot appear in a diff.

### G4 — the hooks/scripts suite

**Failure mode.** `hooks/scripts/` — `vaultguard.sh`, `read_config.sh`, `session-orient.sh`,
`auto-commit.sh`, `write-validate.sh` — ships in the plugin and runs on users' machines at every
SessionStart, and has **zero suite coverage**. Every behavioral guarantee it currently honors is
verified by nothing: a regression reverting `820af90`'s config routing would pass all sixteen CI
steps.

**The instance.** The hook structurally could not read a configured threshold — `read_config.sh`
read `.arscontexta` while the thresholds live in `ops/config.yaml` — so a user who set
`observation_threshold: 20` got the skills honoring it and the hook firing at its hardcoded 10,
silently, for the lifetime of the defect. The field vault proves the blast radius: its owner
hand-patched the hook because that was the only lever. `820af90` fixed it and wrote down its own
missing gate: *"config 10/5 → both CONDITION lines fire; config 99/99 → neither fires. If the fix
had not landed, the first two rows would be identical. That is the assertion that would have caught
the original defect."* Those assertions were run by hand and committed nowhere. This gate is that
paragraph, made a file.

**Design.** `reference/test/hook-config.test.sh`, both shells, two CI steps, following
`bump-version.test.sh`'s convention (the subject is copied into a fixture tree; the suite runs the
script under whichever shell the harness is in, because a human typing `zsh` is exactly how the
`$path` fork shipped). Assertions:

- `read_config.sh` three-state contract: key absent → default, quietly; present and parsed → the
  value; present but unparseable → **stderr and exit 1**, never the default — returning the default
  is exactly how the hardcoded 10 stayed invisible. Plus section scoping
  (`other_section.observation_threshold: 999` must not answer for `self_evolution`) and bare keys
  still reading `.arscontexta` unchanged.
- `session-orient.sh` threshold behavior on a fixture vault with 12 observations and 6 tensions:
  config 10/5 fires both CONDITION lines, config 99/99 fires neither — the discriminator from
  `820af90`, verbatim.
- `vaultguard.sh` inertness: absent `.arscontexta` marker → exit 0, no output. This is the contract
  CLAUDE.md:21–23 rests "you can write freely in this repo" on. No historical defect — stated as
  contract-pinning, not defect-derived, so its assertion is not oversold.

Plus one rider on the existing CI `Shell syntax check` step: widen `bash -n` from its current three
files to every tracked `*.sh`, with a file-count-greater-than-zero guard so an empty enumeration
fails rather than passing vacuously. Syntax-only, and labeled as such — its green means "parses",
nothing more.

Mutations that must go red: revert the dotted-key routing in `read_config.sh` (the 10/5 vs 99/99
rows become identical → red); make an unparseable value return the default (red); drop the marker
gate from `vaultguard.sh` (red).

**Deliberately does not cover:** the full orientation output of `session-orient.sh` (only the two
threshold CONDITION lines are load-bearing and documented; pinning the rest couples the suite to
wording, the fence-gate-allowlist mistake this branch already declined once); `auto-commit.sh` and
`write-validate.sh` beyond marker-gated inertness — their substantive behavior mutates a vault and
wants fixture design this spec does not do on the side; and the three thresholds divergence 3
leaves hardcoded — that is Spec F Task 6's decision, and a gate must not pre-empt it.

---

## Deliberately not gated

The other half of the line, item by item. The recurring reasons: no defined target to check
against, a false-positive rate that teaches people to ignore the gate, a check whose green would
assert nothing, or an in-flight fix that the gate belongs *with* rather than before.

- **16 — numerical correctness of fence output.** No gate asserts a computed number is right, and
  every correctness defect fixed on the spec-e branch passed every gate in both shells before and
  after its fix. Building this means per-fence expected-output fixtures — a project, not a task.
  Already stated honestly at CLAUDE.md:77–89, which is the interim deliverable. Reaffirmed, not
  re-decided.
- **17 — §4's packaged-plugin property.** "The packaged plugin" is not a build target; a checker
  could only compare prose against whatever `/plugin install` last copied, so green would assert
  nothing while looking like assurance. Decided in `cc641ce`, half-built honestly as
  `check-prose-paths.sh`. The live proof the halves differ: `reference/lib/link-extraction.sh`
  resolves here and was absent from the installed 0.8.0. The human release-time diff remains the
  only check on the full rule.
- **18 — output-contract fields without assignments.** The check was built and mis-fired on three
  healthy templates (`graph`, `next`, `remember`) because `[N]` appears in prose and examples, not
  only contracts; it was rightly dropped — a gate that fails healthy templates teaches people to
  ignore it. Precise detection needs an explicit contract marker in 26 templates: a design change
  to the generation surface, owned by whoever next touches the template format. **Deferral landing
  place:** the plan's `## Deferrals` section names this spec section as the tracked record.
- **19 — plan checkboxes lying.** The authoritative ledger is gitignored by design, so CI cannot
  compare claim against record. And the repo deliberately preserves one lying plan (0/29, complete
  ledger, deliverable on disk) *as standing evidence* — a consistency gate would demand destroying
  the evidence or allowlisting it forever. Spec F's structural fix (the required `## Deferrals`
  slot) is the right form; a gate is not.
- **20 — "recorded" claims in commit messages.** Messages are not re-checkable state, and Spec F
  Task 7 Step 2.2 already owns the assessment of a pre-commit gate for this, with the right
  criterion (ship only if zero false positives on the last 20 real commits). Not duplicated here —
  two plans carrying one task is the drift hazard by which Spec C superseded Spec B's Task 5.
- **21 — kernel.yaml ↔ validator sync.** An existence check ("every primitive has a numbered check
  in the script") has no historical instance — the documented failure was a check that *existed and
  asserted a proxy* (primitive 10 checking PATH presence), which an existence check passes. Gating
  existence would manufacture exactly the confidence CONTRIBUTING's one-rule-to-carry warns about.
  Stays prose, with the sync rule stated at CLAUDE.md:196–200.
- **22 and 23 — the status enum and the frontmatter parser.** Both have in-flight fixes (Spec F
  Tasks 3, D7/D8/D9). The right gates — an enum consistency assertion, and a check-portability ban
  on inlining the frontmatter library in the style of the existing link-library ban — belong in the
  commits that create the single enum and the library, because a ban on inlining a library that
  does not exist yet mandates nothing. Named here so those commits know a gate is expected of them.
- **24 — the gh-fork and hot-reload traps.** Local workflow states CI cannot observe. The
  pre-commit hook already covers the half of the fork trap that matters (a local gate has no
  upstream to silently query). Documentation is the correct form.
- **25 — the 66 unexecuted contributor-doc fences.** CLAUDE.md's and CONTRIBUTING's fences name the
  live field vault and repo-root state that CI cannot fixture; the house escape for
  non-runnable examples (` ```text `) plus §5's stated scan set is the honest handling. Extending
  the fence gate to them would either fail on unreachable paths or demand fixturing this repo
  inside itself.
- **26 — vacuous assertions in the suites.** The working discipline is suite-internal: mutation
  probes per fix, every negative grep paired with a positive companion, and the empty-subject probe
  `eb485ac` wrote down (8 of 28 survive an empty validator, each surviving one justified). A
  generic CI detector for vacuity would be a heuristic with a false-positive rate — the class of
  gate item 18 already retired.
- **27 — the partial-bump on-disk state.** Deliberately unpinned in `bump-version.test.sh` so an
  atomic fix does not read as a regression; the fix is Spec F Task 5, and the new assertions belong
  to it. A gate here now would be a bet on the fix's shape.

---

## Corrections found while building this list

- **The dated-sweep discipline has a half-life of one branch.** CLAUDE.md's divergence header
  promises every number re-derived on 2026-08-03; the step-count sentence two paragraphs below it
  was stale again by the same branch's fourth commit, because `d384094` added two CI steps after
  the sweep. G2 exists because a sweep is a snapshot and CI is the only thing that runs on every
  change.
- **Two suites' totals colliding hid a stale expectation.** CONTRIBUTING's `19/19` for
  guard-failure reads plausibly because link-extraction's true total is also 19. A reader checking
  one suite against the doc's other line would see agreement.
- **The teammate brief for this spec said "14 steps" and "10 divergence entries"; both were already
  stale when briefed** (16 steps; 12 entries under 11 distinct numbers). Re-deriving inherited
  numbers found drift in the *assignment itself*, which is this repo's thesis performing itself.

---

## Success criteria

1. `check-portability.sh` gains a check that fails on a seventh interpolated bracket-pattern site,
   absorbs exactly the six known sites via a bidirectional allowlist, and reports STALE when an
   entry's site is fixed or gone.
2. `check-doc-claims.sh` exists, runs in CI, and its RED baseline is the current tree: it must fail
   on the five live instances named in Reconciliation before the docs are corrected, and pass after.
3. The five stale claims in CONTRIBUTING.md and CLAUDE.md are corrected, and the duplicate
   divergence number is resolved to 12 with both cross-references updated.
4. A placeholder-count decrease in a changed `skill-sources/` template fails CI naming the file and
   counts; a shallow checkout fails loudly rather than passing vacuously.
5. `hook-config.test.sh` exists, runs in CI under both shells, and reverting `820af90`'s routing
   turns it red.
6. Every gate added is proven by mutation in both directions, and every mutation probe's result is
   recorded in the commit that adds the gate.
7. The twelve deliberately-ungated items are recorded in this spec with their reasons, and the two
   that expect gates from in-flight work (22, 23) are named in that work's plan or its review notes.

---

## Explicitly out of scope

- **Fixing the six allowlisted matcher sites.** Divergence 10 states they need separate review with
  different blast radii; G1 ships protection against the seventh site, not fixes for the six.
- **A numerical-correctness gate** (item 16). Still a project; still stated in CLAUDE.md.
- **The packaged-plugin checker** (item 17). Still no build target; the decision in `cc641ce`
  stands.
- **The contract-marker convention** (item 18). A template-format design change, not a CI task.
- **Anything in `platforms/shared/skill-blocks/`.** Frozen; `testing-milestones.md:410` is the one
  allowlisted matcher site in `reference/` and is handled by allowlist, not by edit, until its own
  review.
- **Spec F's remaining tasks.** D2 through D10 stay theirs; this spec's gates are sequenced to
  coexist with that branch's in-flight work, not to race it.
