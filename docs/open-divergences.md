# Open divergences

> Split out of the repo root `CLAUDE.md` on 2026-08-23; pairs with
> `docs/closed-divergences.md`, exactly as before. The run fence, the gate table, and
> the Verification forensics this list refers to live in `docs/verification.md`.
> `reference/check-doc-claims.sh` anchors its divergence-uniqueness scan on the
> `## Known open divergences` heading below and reads three CLAIMS rows from this file
> by text anchor. Body byte-identical to the moved section except for the edits in
> `docs/superpowers/specs/2026-08-23-claude-md-split-design.md` §7.

## Known open divergences

Every number below was **re-derived from a command on 2026-08-03**, not carried forward from the
previous revision. Ranked by blast radius. Not an exhaustive audit — the point is the shape of the
problem and where to look.

That sweep is not ceremony: it found the list's own entries drifting in three different ways. A count
measured against the live vault had moved (`3784 of 5251` → `3786 of 5253`) because the vault gains
files. A count measured against this repo had moved because *this branch changed it* (CI steps).
And one entry described a defect that had since been fixed in the files it named while remaining
live in a file it did not — see divergence 5. **A divergence list is itself a status file, and this
one had begun to lie in the way it warns about.**

The end-of-branch sweep repeated the exercise and found the same three shapes again, which is the
argument for doing it every time rather than once. The live-vault count moved a third time, to
`3792 of 5263`; frontmatter coverage moved with it, `5094` → `5104` files with YAML against a
stationary `159` without. The CI step count moved because *this* branch changed it again. And a
count that stated a defect class — divergence 13's seven inlined extractions — was re-derived
against a broader pattern that returns **9**, of which two are a different operation: `graph:569`
and `stats:397` spell `rg -o '\[\['` to *count* brackets rather than capture a target, so the class
is still 7 and the decomposition `9 = 7 + 2` is now published with it rather than left to be
rediscovered as a number that grew. **Do not read a number here without running the command beside
it.**

**Everything previously listed here is FIXED** (`grep -P` on 8 sites, naive wiki-link parsing, the
`/rethink` status split, the `self_evolution` generator gap, `/learn`'s removed Exa tools). That is
not a claim you should take on trust: it is what the eighteen checks in `docs/verification.md` enforce — sixteen of them
in CI, as defined by the thirty-two steps in `.github/workflows/checks.yml`. The other two are
`validate-kernel.sh`, which needs a generated vault to run against, and
`reference/test/check-doc-claims.test.sh`, deliberately not CI-wired — each run already costs
three invocations of the ~100s script it tests, and a step here would also move the gated CI-step
counts below, one of which compares against `main` and rots on merge.

**THE NUMERALS ARE GONE FROM THIS SENTENCE ON PURPOSE, AND THE FIRST ATTEMPT AT THIS PARAGRAPH
RE-MINTED THEM ONE LINE LATER.** It carried four that had gone stale, and the correction spelled all
four out again while claiming they had been removed — an ungated restatement inside the sentence
asserting there was none. Both are gone now.

Two counts survive above as words, and **they are not gated either**: the gate's rows for those
quantities anchor on a different sentence, in `docs/verification.md`, and a gate that reads one phrasing does not
protect a synonym — which is what this entry exists to say. The step count is not restated at all,
because "`main` carries N" is a claim about another branch that goes stale on MERGE with no diff to
notice. Read them from the tree:

```bash
ls reference/check-*.sh reference/test/*.test.sh reference/validate-kernel.sh | wc -l
grep -c '^      - ' .github/workflows/checks.yml
```

**These four numbers were stale by four, one, five and six respectively until 2026-08-05, in the
paragraph introducing a list about numbers going stale.** They read ten / nine / 19 / 18 against a
true 13 / 12 / 24 / 24, three paragraphs above this file's own explanation that a claim about `main`
rots on merge. They were UNGATED while the gated spellings of the same three quantities — "thirteen
executable checks", "Twelve run in CI", `# 24` — sat correct in the same file. A gate that reads one
phrasing does not protect a synonym, and prose is where the synonyms live. Re-derive all four:

```bash
ls reference/check-*.sh reference/test/*.test.sh reference/validate-kernel.sh | wc -l   # 18
grep -c '^      - ' .github/workflows/checks.yml                                        # 32
git show main:.github/workflows/checks.yml | grep -c '^      - '                        # NO NUMERAL
```

**The main-side count is deliberately undeclared, and that is a fix rather than an omission.**
Any literal here is wrong in one of the two states a merge passes through: before it, `main`
carries the old count; after it, the same unchanged line is false, with no diff to notice and
no signal until `main`'s own CI run goes red. It was gated, and the gate could only ever catch
the staleness it created — the PR ran green and `main` reddened on merge, so every branch that
touched CI owed a follow-up commit. `check-doc-claims.sh` now asserts the RELATIONSHIP instead
(`main`'s count ≤ this tree's), which is true on both sides and still catches a branch that
*deletes* CI steps. Run the command; do not re-mint the numeral.

That third line read `# 28` until the PR #8 merge on 2026-08-15 equalised the two. It was
missed by the same merge-day edit that corrected its twin twenty lines below — **two sites,
one pattern, and only the gate saw the second.** That is the finding, not the numeral: this
paragraph exists to warn that a gate reading one phrasing does not protect a synonym, and the
two spellings here are not even synonyms — they are the same command, wrapped differently.

**A claim about `main` rots on MERGE, not on edit, which is why it needs a gate rather than care.**
Nothing in a working tree changes when a branch lands, so `# 14` sat here correct-when-written and
wrong-by-merge with no diff to notice. `check-doc-claims.sh` now reads all three of the numbers
below and fails when a document and the tree disagree.

That "seven" stood here until the end-of-branch sweep, three lines below a Verification section
opening "There are nine executable checks", and the two never agreed. It is the cheapest kind of
drift to catch and it survived anyway, because nobody reads a prose numeral as a claim to check.
Counting the CI steps takes the same care: `grep -c '^      - name:'` returns one fewer than the true
count, because `actions/checkout` carries no `name:`. Count step *items* (`^      - `), not names:

```bash
grep -c '^      - ' .github/workflows/checks.yml                      # 32, this tree
git show main:.github/workflows/checks.yml | grep -c '^      - '      # NO NUMERAL — read it,
                                                                      # do not re-mint it. This
                                                                      # line carried one through
                                                                      # four corrections; the
                                                                      # fourth is what removed it.
                                                                      # No value is green on both
                                                                      # sides of a merge, so the
                                                                      # gate now asserts the
                                                                      # RELATIONSHIP (main <= this
                                                                      # tree) rather than a count.
                                                                      # They were equal as of the PR #8
                                                                      # merge on 2026-08-15,
                                                                      # which carried the
                                                                      # queue-edit suite's two
                                                                      # steps into main.
                                                                      #
                                                                      # This read "# 28, main
                                                                      # ... this branch is now
                                                                      # 2 ahead again" until
                                                                      # that merge: correct
                                                                      # when written, wrong by
                                                                      # merge, with no diff to
                                                                      # notice. That is the
                                                                      # exact rot the sentence
                                                                      # above describes, and
                                                                      # this line is the third
                                                                      # time it has been
                                                                      # corrected — which is
                                                                      # why the gate reads it
                                                                      # rather than trusting
                                                                      # anyone to remember
ls reference/check-*.sh reference/test/*.test.sh reference/validate-kernel.sh | wc -l   # 18
```

What follows is what remains.

**1. `validate-kernel.sh` soft-passed the dangling-link primitive — FIXED on
`fix/spec-f-divergence-drain`.** Kept in place, and kept numbered, because the entries below are
referenced by number from work in flight; renumbering them would invalidate those references. Full
record in [Closed on `fix/spec-f-divergence-drain`](docs/closed-divergences.md#closed-on-fixspec-f-divergence-drain).

**2. `bump-version.sh` could leave a partial bump — the drift it exists to prevent — FIXED on
`fix/spec-f-divergence-drain`.** Kept in place and kept numbered, for the same reason as 1: the
entries below are referenced by number from work in flight. Full record in
[Closed on `fix/spec-f-divergence-drain`](docs/closed-divergences.md#closed-on-fixspec-f-divergence-drain).

**3. Thresholds the hook cannot read are still undeclared — but the `self_evolution.*` half is
fixed.** The entry that stood here was wrong on its own facts, which is worth recording: it claimed
"three sources currently disagree (skills 10/5, plugin hook 10/5, the field vault's patched hook
20/10)". Measured — the first two *agree*, and the third is a hand-patch inside one vault, which is
evidence of the defect rather than an instance of the disagreement. The real defect was narrower and
worse: the hook **structurally could not read a configured value**, because `read_config.sh` reads
`.arscontexta` and the thresholds live in `ops/config.yaml`. Nesting was never the axis; the file
was. A user who set `observation_threshold: 20` got the three skill templates honouring it and the
hook still firing at its hardcoded 10, silently. The field vault proves it: someone wanted 20/10,
hand-patched the hook because that was the only lever, and that vault's hook and its own
`config.yaml` now disagree.

`read_config.sh` now routes **dotted** keys to `ops/config.yaml` (one level, which is all
`self_evolution.*` needs) while bare keys read `.arscontexta` unchanged, and `session-orient.sh`
reads both thresholds instead of hardcoding them. A key that is present but unparseable exits 1 and
says so rather than returning the default — returning the default is exactly how the hardcoded 10
stayed invisible.

**The other half — three thresholds declared in no config file — is now DECIDED rather than open.**
`SESS_COUNT ≥ 5`, `INBOX_COUNT ≥ 3` and `DAYS_STALE ≥ 30` in `session-orient.sh` stay hardcoded, and
`hooks/scripts/session-orient.sh` states why in the file itself, under the greppable heading
`DELIBERATELY FIXED, NOT MERELY UNDECLARED` (`:212` as of this commit — grep the heading, since
adding that very comment drifted every line number this entry originally cited). The reason is
deliberately *not*
"nobody asked", which rots the moment someone does: `self_evolution.*` earned its keys because **four
independent consumers** read it — `next`, `remember`, `rethink` and the hook, each deciding on its own
whether to recommend `/rethink` — so a wrong value makes a vault's own tools contradict each other
about it. These three have **no second independent consumer**: a wrong value mistimes a nudge and
cannot produce that contradiction, because there is no other decision-maker to contradict. The comment
carries a falsifiable trigger rather than a preference, quoted here verbatim from the hook: *if a
second **INDEPENDENT CONSUMER** — a distinct decision-maker, not another copy of this same SessionStart
hook — ever compares against one of these numbers, that one becomes a config key.*

**"Independent" is load-bearing, and this entry is the reason it had to be.** The trigger first read
"a second surface", which the very next paragraph refutes by naming the template as exactly that — the
entry contained both the claim and its refutation. The distinction that resolves it, and that governs
the whole entry: **two copies of ONE consumer can DRIFT**, which a cross-reference fixes; **two
DISTINCT consumers can DISAGREE**, which only a shared config key fixes. Different defects, different
remedies — which is why the template below gets a cross-reference and not a key.

**What that decision does not buy is single ownership, and the entry says so rather than claiming it.**
Measured: `DAYS_STALE`'s 30 has **one** declaration repo-wide; `SESS_COUNT`'s 5 and `INBOX_COUNT`'s 3
have **two each** — the plugin's own hook (`:271`, `:274`) and
`platforms/claude-code/hooks/session-orient.sh.template:143,149`. Both sites now name each other,
because a cross-reference is the only thing that stops an edit to one from silently splitting them.

**The mechanism is worth stating precisely, because "the hook a generated vault gets" — what this
entry said first — is imprecise in a way that changes the claim.** No skill copies that template.
`platforms/claude-code/generator.md:27` points Claude at `platforms/claude-code/hooks/` for *"hook
template documentation"*, so it is reference material the adapter **reads** during generation;
nothing under `skills/` or `generators/` names the `platforms/` tree at all. What reaches a vault is
therefore whatever Claude **derives**, which is not a copy and is arguably worse — a copy at least
tracks its source. The field vault proves the difference: its hook is **179 lines to the template's
200**, contains **none** of these three checks, and hardcodes its own `-gt 20` observation threshold.
So a generated vault may or may not inherit these two values verbatim, and the duplication is a
**drift** hazard between two declarations rather than two copies that ship together. This does not
contradict divergence 12's "runs on **every** SessionStart" — that is about what a *derived* hook
does once it exists, not about the template being copied verbatim.

```bash
# 9 = 3 CLAUDE.md + 5 docs/superpowers/ + 1 the hook's own comment. ZERO are code that reads or
# copies the template — that, not the total, is the claim. (The line below does not self-match:
# its dots are escaped, so it matches a literal `.` and not the `\.` it is written with.)
grep -rn 'session-orient\.sh\.template' --include='*.md' --include='*.sh' --include='*.json' .
grep -rln 'platforms/claude-code' skills/ generators/            # no hits, rc 1 — nothing generates from that tree
grep -nE 'hooks/|\.template' platforms/claude-code/generator.md  # :27 names the directory as documentation
```

**Do not "fix" that duplication with a generation placeholder** — the obvious move, matching the
neighbouring `{{OBS_THRESHOLD:-10}}` and `{{TENSION_THRESHOLD:-5}}`, would ship two more knobs that
look configurable and are not: **nothing in this repo substitutes either placeholder.** Found while
closing this entry; it is a live instance of this file's own cross-cutting pattern (a plausible-looking
surface that does nothing) and is recorded here rather than fixed, because wiring or removing them is
a change to what generation emits.

Also measured, and the reason Step 2's warning stands: there are **five** literal 30s across **two**
subjects, not two. Four are note staleness (`skill-sources/next:242`, `skill-sources/reweave:130`,
`skills/health:469`, `platforms/shared/skill-blocks/reweave.md:144`); only `session-orient.sh:292` is
methodology-notes-behind-config drift. Same number, different subject — **do not merge them.**
**Read the decomposition below, not the totals — and note why it is a decomposition.** Each command
matches the very prose that states its result, so the commit that states a count is the commit that
changes it. This entry first shipped `5 / 5 / 4`: true when taken, stale the moment they landed.
Fixed by stating sums rather than by adding `grep` exclusions, per the idiom divergence 12 already
uses — an exclusion rots silently and can quietly match nothing (shipped here twice), whereas a sum
fails loudly the moment it stops adding up:

| | total | = real | + self-match / added prose |
|---|---|---|---|
| cmd1 | **6** | 5 declarations | 1 — the command's own line in the hook comment |
| cmd2 | **6** | 5 declarations | 1 — the command's own line in the hook comment |
| cmd3 | **10** | 2 placeholder declarations (`template:120,126`) + 2 same-named shell variable, **not** a substitution (`session-orient.sh:200,206`) | 6 — this entry, the hook's decision comment, the template's cross-reference |

**Substitutions found: ZERO.** That, not any total, is the figure the placeholder claim rests on.

```bash
grep -rn -- '-ge 30\|-gt 30\|mtime +30' skill-sources/ skills/ platforms/ hooks/
grep -rn 'SESS_COUNT" -ge\|INBOX_COUNT" -ge\|DAYS_STALE" -ge' hooks/ platforms/ skill-sources/ skills/
grep -rn 'OBS_THRESHOLD\|TENSION_THRESHOLD' . --exclude-dir=.git --exclude-dir=.superpowers
```

**4. Display counts that merge or omit a status filter — the live half is FIXED, the frozen half is
reclassified won't-fix.** Kept in place and kept numbered, for the same reason as 1 and 2. `skills/help`
is fixed: its merged observations-plus-methodology total was named `obs_count` and displayed as
*"N pending observations — approaching /rethink threshold"*, two claims it could not support, since
methodology notes are not observations and no status filter ran. Renamed to `learning_file_count` and
relabelled; the arithmetic is deliberately unchanged, because /help is orientation and that number
gates nothing. The *same* mislabel in `session-orient.sh` and `skills/health` WAS a defect, because
those numbers cross a threshold. The one remaining instance is in the frozen tree and cannot be
fixed there — see [Won't fix](#wont-fix).

```bash
grep -c 'learning_file_count' skills/help/SKILL.md         # >= 1: the rename shipped
grep -c 'obs_count' skills/help/SKILL.md                   # 1 -- and it is a comment, not a use
sed 's/#.*$//' skills/help/SKILL.md | grep -c 'obs_count'  # 0: no live site remains
```

The two `obs_count` numbers differ on purpose, and the decomposition is the point: `1 = 0 live + 1
comment`, the comment being the line that records what the old name claimed. Reading the raw count
as a surviving defect is the error; deleting the comment to make one command suffice would delete
the only in-file account of why the rename happened.

**5. Verification gaps in the loop itself.** `/arscontexta:upgrade` **has no recorded slash-command
invocation against a real vault, and that gap is undone, not structural.** This entry used to give a
structural reason — a slash command runs in the session's working directory and cannot be pointed at
another tree — which is true of a session sitting in this repo and false where it matters: a session
whose cwd *is* the vault invokes the command natively. The field vault's `ops/skills-archive/`
carries dated archive events, the footprint of upgrade *operations* — but an archive proves an
operation ran, not that this command was its vehicle, so neither direction is established. Its three
repairs (`ops/lib/`, `ops/queue/.locks/`, `self_evolution:`) remain prose contracts CI cannot
exercise.

A later branch on this same skill (Spec I) added a comparably sized prose contract to a different
part of it — Step 1's modification check, Steps 2-4's divergence handling, and the Final Report's
per-skill tallies — and it inherits the identical gap. Assertion M in `fence-isolation.test.sh`
verifies `mechanically_compare` itself, at the bash-function level, against a fixture built on a
real vocabulary collision. Nothing verifies the agent-level prose around it: that an agent reading
its stdout correctly tallies `{modified_count}`/`{skipped_count}`, routes a `skipped` skill through
Steps 2-4 without fabricating a divergence verdict for it, or reports it correctly at the end. Those
are prose CI cannot exercise, for the same structural reason the three repairs above cannot be.

What has now happened is narrower and worth the distinction: those steps were **carried out by hand**
against an `rsync -a` copy of the field vault, in an as-is state and again with all three repairs
deliberately damaged. That found **six defects, five now fixed** (`acb1ecf`) — the repairs were
unreachable when no upgrade was approved; 5e downgraded a newer vault library on any version
mismatch and reported it as `[refreshed]`; it had no behavior for a missing plugin-side file, which
is the state of the *installed* plugin; it restores one file of five and claimed `/stats` and
`/graph` source it when no vault skill references it at all; and 5g performed the resolution the
field vault had explicitly rejected, seeding the `10/5` defaults beneath that vault's configured
`20/10` because its "do not reset a tuned one" guard tested only for `self_evolution:`. That last one
was made load-bearing by divergence 3's own fix on this branch — the hook now reads the key 5g
writes.

**Closed from that run: `self_evolution.*` is authoritative, and 6c now reconciles instead of
reporting.** Both pairs were declared thirteen lines apart in one `ops/config.yaml`, and the field
vault had **three** readers, not two — measured at 14 open observations and 8 open tensions:

| Field-vault surface | Reads | Threshold | At 14 / 8 |
|---|---|---|---|
| its generated `/rethink` | `maintenance.conditions.pending_*_threshold` | 20 / 10 | silent |
| `/next`, `/remember` | `self_evolution.*` | 10 / 5 | **FIRES** |
| its SessionStart hook | **neither** — hardcoded `-gt 20` / `-gt 10` | 20 / 10 | silent |

So the live split was **2 firing, 2 silent**, not three against one. That hook is the hand-patched one
divergence 3 describes: it names no config key at all, which is *why* divergence 3 exists.

**Get the direction right — the natural phrasing is wrong in two places, and each shipped here once.**
Both errors are the same move: a clause true of this repo's files, kept while the sentence's subject
changed to the vault.

- **The reader.** It is the *vault's* `/rethink` that reads the legacy pair; this repo's
  `skill-sources/rethink` template has always read `self_evolution.*`. "`next`/`remember`/`rethink`
  read `self_evolution.*`" is true of the templates and false of the vault — and self-refuting
  besides, since at 10/5 fourteen open observations *fires*, so a `/rethink` on that pair could not
  have been the silent one.
- **The hook.** This repo's `hooks/scripts/session-orient.sh` **does** read `self_evolution.*` —
  divergence 3's fix on this branch made it do so. The *vault's* hook reads neither namespace. Writing
  "and the hook read `self_evolution.*`" of the vault contradicts divergence 3 two entries below.

Re-derive the counts and both directions (all four figures drift):

```bash
. reference/lib/frontmatter.sh
list_notes_by_field ~/second-brain/ops/observations status pending open | grep -c .   # 14
list_notes_by_field ~/second-brain/ops/tensions      status pending open | grep -c .   #  8
# Scope must include hooks/, or the command cannot reach the clause about the hook:
grep -rn 'maintenance\.conditions\|self_evolution' \
     ~/second-brain/.claude/skills/ ~/second-brain/.claude/hooks/    # skills only; hooks: no match
# Anchor on the variable, not on the number: `… | grep -E '20|10'` also matches the
# unrelated capture-count line, because the LINE NUMBER `104:` contains "10".
grep -nE 'PENDING_(OBS|TEN)" -gt' ~/second-brain/.claude/hooks/session-orient.sh   # 2 lines: 20, 10
```

The vault's own write-up recommended the skills
conform to `maintenance.conditions.*` rather than a namespace be invented (Rule 12); that was sound
advice *to a vault*, and this is the generator, where three measurements point the other way:
`read_config.sh` resolves one level of nesting so the three-level key is structurally unreachable by
the hook (deepening it means the general bash YAML parser its own header rejects); no generator here
has ever emitted the legacy pair; and it is not a live iterated namespace — the other seven keys under
`maintenance.conditions:` have zero readers in the field vault, and the `maintenance_conditions` that
`/next` iterates is a section of the **queue** file, a different structure in a different file.
Re-derive both (the reader counts drift as the vault grows; the emission count should stay 0, and a
non-zero result means a generator has started writing the legacy pair again):

```bash
grep -rn 'maintenance\.conditions\.' generators/ skills/setup/            # 0 — never emitted here
for k in orphan_nodes_threshold dangling_links_threshold draft_age_days \
         draft_age_threshold unprocessed_captures_threshold \
         stale_active_nodes_days stale_active_nodes_threshold; do
  printf '%-32s %s\n' "$k" \
    "$(grep -rl "$k" ~/second-brain/.claude ~/second-brain/.agents 2>/dev/null | wc -l)"
done                                                                     # 0 readers each
```

The cost, which is real: a vault that tuned `maintenance.conditions.*` gains nothing until the value
is carried across, so `/upgrade` 6c now ends in a write — copying the tuned pair into
`self_evolution:` and **leaving the old pair in place**, so an un-regenerated `/rethink` keeps reading
its own key and agrees rather than falling back to a default. That is reconciliation, not
deduplication: two declarations survive and can re-diverge if a user later edits one. They are fully
deduplicable only once that vault's `/rethink` has been regenerated.

```bash
bash reference/test/threshold-namespace.test.sh   # 57/57; before-state disagrees, after-state agrees
```

**57 is the total, not the discriminating count, and the difference is the point.** The 20 threshold
sweep assertions were reviewed as *tautologies* in their first form: they compared one reader's
verdict against the other's, and both had already been pinned to the same literal two lines above, so
inverting the comparison function left every one of them green. They now pin each reader to a literal
expected verdict. Measured against the two mutations that exposed the defect: inverting `fires`
reddens all 20; replacing it with a constant `FIRES` reddens 12, the other 8 being the assertions that
legitimately expect `FIRES`. **An assertion counted in a total is not evidence it can fail** — that is
the same substitution `docs/verification.md` records for the kernel validator's `PASS: 15`.

**What is not verified, since 6c is prose Claude executes:** the suite proves the reconciliation
*operation* produces agreement across all four readers, and that the repo names one namespace. That
Claude performs it when asked is not checked by anything, and is not claimed to be.

**Separately — a status file that lies about status, and the entry describing it had itself gone
stale in three different directions.** Worth spelling out, because a number swap would have hidden
all three:

| | Plan(s) named | Measured 2026-08-03 |
|---|---|---|
| What this entry used to claim | "two older plans … 0 of 93 steps" | `93` = portability (42) + silent-failure-hardening (51). Both now **42/42** and **51/51** — ticked since. |
| What the fix plan proposed instead | "Measured: 16/16 and 22/22" | Correct, but about *different* plans (stale-contracts, contributor-surface) that were never the subject of the `93`. |
| What is **actually** still lying | named by neither | `2026-08-02-skill-authoring-reference.md` at **0/29** — with a complete ledger (16 completion lines, `final-review.md`) and its 181-line deliverable `reference/skill-authoring.md` on disk. |

```bash
for p in docs/superpowers/plans/*.md docs/superpowers/plans/archive/*.md; do
  printf '%-58s %s/%s\n' "$(basename "$p")" \
    "$(grep -c '^- \[x\]' "$p")" "$(grep -c '^- \[[x ]\]' "$p")"
done
```

So the entry named two plans that got fixed, its correction named two others that were never the
subject, and the live instance is in a third file neither mentions. **Those 29 boxes are deliberately
left unticked** — retro-ticking them would destroy the only standing evidence of the defect, and it
is a write to a file this work does not own.

**The prose-contract rule, now half-checked — under a name that says which half.**
`reference/skill-authoring.md` §4 requires that every filesystem path named in a prose contract exist
in the *packaged* plugin. A checker for **that** claim is still deliberately not built, for the reason
it always was: "the packaged plugin" is not a defined build target, because this repo has no build
step. A script could only compare prose against whatever `/plugin install` last happened to copy, so a
green result would assert nothing while looking like assurance — the proxy-for-property failure this
file spends most of its length warning about, added to the gate set that warns about it.

Asked a narrower question, though, a real answer exists: *does every repo path named in prose resolve
in this checkout?* That is a strictly weaker property and it is honestly checkable, so
`reference/check-prose-paths.sh` now checks it, across the documents in its stated SCOPE list, in CI. **Its name, its
header and its every-run banner all say `checkout only — packaging unverified`**, because a gate whose
green is read as the stronger claim is worse than no gate.

It cannot catch the §4 defect class alone, and the live proof is in divergence 5: `${CLAUDE_PLUGIN_ROOT}/reference/lib/link-extraction.sh`
**resolves here and is absent from the installed 0.8.0.** This gate passes that path. It catches the
strictly easier error — prose naming something that exists nowhere.

Two design choices worth keeping if it is ever extended. Scope is a **stated file list**, not a
discovered one, and an in-scope file that goes missing is an `ERROR` rather than a skip — a shrinking
scope must not read as clean. And extracting **zero** paths exits `2` with "the extractor is broken,
not that prose is clean", distinct from `1` for a genuine miss: this repo has twice shipped a scan
that matched nothing and reported green.

**The stated list was nine documents until `fix/post-merge-hardening` widened it to eleven — not
eight to eleven, though this very paragraph claimed "eight" from 2026-08-11 (when
`docs/closed-divergences.md` joined SCOPE and the prose was never updated to follow) until this
branch corrected it. That stale "eight" is what this task inherited, not the tree's true count; the
commit trailer (`9 -> 11`) is the correct record. Keeping both numbers here — nine true, eight
claimed — is deliberate, per this file's own convention of recording drift rather than silently
overwriting it. `hooks/scripts/session-orient.sh` and
`platforms/claude-code/hooks/session-orient.sh.template` are now in it.** Both name repo paths in
comments and in warning messages a user reads at SessionStart,
which is why they were added on this branch: a path that rots in either is now checked by this gate
rather than by the next reader. Widening a *stated* list is a deliberate edit, which is the property
that makes a shrinking scope impossible to mistake for a clean one — re-derive it rather than trust
either number:

```bash
awk '/^SCOPE="/{f=1;next} /^"/{f=0} f&&NF' reference/check-prose-paths.sh   # the 16 in scope
grep -c 'session-orient' reference/check-prose-paths.sh                    # 2: both now listed
```

**It became fourteen on the branch that rewrote `.opencode/INSTALL.md` and added
`.pi/INSTALL.md` and `.codex-plugin/INSTALL.md`, all three as procedures a host's own
model executes.** That shape makes them dense with repo paths — `skills/`,
`reference/hosts/codex-tools.md`, `.opencode/plugins/arscontexta.js`,
`reference/hosts/pi-tools.md` — so all three were added to SCOPE in the same change.
Recorded here rather than silently corrected, per the paragraph
above; the count in the fence moved with them, and it is still ungated, so the command
remains the only thing to trust.

**SCOPE became sixteen on the branch that split this list out of `CLAUDE.md`**, adding
`docs/verification.md` and `docs/open-divergences.md` — the file you are reading — because a
gate that does not scan a document reports `0 missing` for it, which is passing on absence.
The same change removed the live numeral from the sentence above rather than re-minting it as
"fourteen" or "sixteen": that numeral had already gone stale once at eleven, and the entry it
belongs to exists precisely because nothing gates it. A numeral in a history sentence like
this one describes a past event and does not rot; only the live-count form is banned.

**One of those example paths is gone.** The Pi extension this repository shipped
under `.pi/` was deleted on `fix/pi-package-route`, once Pi's own packages
documentation established that a package shipping no `pi` manifest has its `skills/`
directory auto-discovered — the extension's entire body registered that same
directory. The example above now names a path that still exists; SCOPE itself is
unchanged, and the command above remains the only thing to trust for its size. The
deleted path is deliberately not spelled as a path here — prose asserting a file that
does not exist is the property `check-prose-paths.sh` rejects, though see divergence
17 for why that gate could not currently see it.

The scope count itself is not gated — `check-doc-claims.sh` reads a different sentence in this file
for a different quantity, and a gate that reads one phrasing does not protect a synonym, per this
file's own opening paragraph on that subject. Filed as a deferral rather than fixed here, since
wiring it in is a change to that gate, not to this one.

The human diff of the two trees at release remains the only check on the full §4 rule.

**6. `graph`'s authority loop still inlines the naive matcher — FIXED on
`fix/spec-f-divergence-drain`.** Kept in place and kept numbered, because entries below reference
these numbers and work is in flight; renumbering would invalidate those references. Full record in
[Closed on `fix/spec-f-divergence-drain`](docs/closed-divergences.md#closed-on-fixspec-f-divergence-drain).

**Read divergence 12 before concluding anything from this.** What was fixed is two *loops*; what the
entry's title implied — that the naive-matcher class is gone — is still false, and the search string
this entry shipped as its own reproduce command is what made that hard to see.

**7, 8 and 9 — the `status` enum split, the missing frontmatter parser, and the fence gate that
could not falsify either — FIXED on `fix/spec-f-divergence-drain`.** Kept in place and kept numbered,
because entries below reference these numbers and work is in flight; renumbering would invalidate
those references. Full record in
[Closed on `fix/spec-f-divergence-drain`](docs/closed-divergences.md#closed-on-fixspec-f-divergence-drain).

They are collapsed into one entry because they were one defect wearing three hats: no shared parser
(8), so no single place for the vocabulary to be right (7), and a fixture that could not tell a
correct parser from a broken one (9), which is why 7 and 8 survived every gate.

**What is still open, and was never in these three entries:** `generators/features/graph-analysis.md:39,141`,
`generators/features/schema.md:74` and `generators/features/methodology-knowledge.md:31` emit
line-anchored `rg '^status: …'` as *recipes into a generated vault's documentation*. Same defect
class, not converted here — a recipe cannot source a library the way a fence can, so fixing it is a
design change to what generation emits.

**Whoever takes this: it is not a relocation, and it will move a number.** The library treats an
unclosed frontmatter block as no frontmatter; the recipes do not care.
`~/second-brain/ops/methodology/prioritize-dissenting-viewpoints.md` opens `---` at line 1, never
closes it, and carries `status: active` at line 7 — so for `ops/methodology/` the shipped recipe
counts **13** and the library counts **12**, and that one file is the entire difference. The real
decision is which answer is right (fix the malformed file, or have the library tolerate an unclosed
block), and it should be made deliberately rather than discovered as a count that dropped. Re-derive:

```bash
grep -rn 'status' generators/ --include='*.md'          # every declaration and recipe
. reference/lib/frontmatter.sh
rg -l '^status: active' ~/second-brain/ops/methodology/ | wc -l    # 13, the recipe
count_notes_by_field ~/second-brain/ops/methodology status active  # 12, the library
```

The field vault also carries `status: implemented` on observations — a value declared in no generator
enum at all. Reported, not fixed: this task reconciled the generators *with each other*, which is what
its evidence supports; reconciling them with one vault's practice is a separate decision with a
different owner.

**10. A ticked plan step for a check that was built and never shipped.**
`docs/superpowers/plans/archive/2026-08-03-fourteen-open-items.md` Task 2 Step 4 is `[x]` for an assertion —
"every `[A-Z_]*` field named in an output-format contract must have an assignment in the same file" —
that mis-fired on three healthy templates (`graph`, `next`, `remember`) and was deliberately dropped.
Commit `741b2b7` says it was "recorded in the ledger"; the ledger is `.superpowers/`, which is
**gitignored**, so nothing shipped. Precise detection needs an explicit contract marker in the
templates; without one the check cannot distinguish a documented-but-computed-elsewhere field from a
stale one.

**This entry is the reason to distrust the phrase "recorded" in this repo's commit messages.** The
same mistake was made twice: once by `741b2b7`, and again by `c122d9e`, whose message said three
review findings were "recorded for the whole-branch review" when they had been written only to that
same gitignored ledger. Entries 6–10 exist because that was caught on re-reading this
list, not because the earlier claims were true. **A record that does not ship is not a record.**

The two instances differ in a way worth keeping, because it is what defeats the obvious gate.
`741b2b7` touched no tracked record at all — only two `skill-sources` templates. `c122d9e` **did**
touch a tracked file, `docs/superpowers/plans/archive/2026-08-03-fourteen-open-items.md`, and its diff is
seven lines ticking two Task 6 checkboxes; not one of the three findings appears in it. So the
checkable proposition is not "did a tracked file change" — one instance passes that — but "is the
record *in* the change", which needs a reader. Re-derive both:

```bash
git show --stat --format='' 741b2b7   # skill-sources/graph, skill-sources/next: no record anywhere
git show --format='' c122d9e          # a plan file, 7 lines, two checkbox ticks, zero findings
```

**Two structural repairs shipped on `fix/spec-f-divergence-drain`; the assertion itself is still
not built.** `CONTRIBUTING.md` used to say the git-ignored `.superpowers/sdd/` ledgers "are the
authoritative record" — a false licence, since both authors already knew the directory was ignored
and the tracked guidance told them that was fine. That sentence now says the opposite and names
where a record actually goes. And **every plan written from this branch forward** carries a required
`## Deferrals` slot whose value is one line per deferral naming the tracked file it landed in, or
the literal word `none`.

**That is forward-binding, not a description of the directory — it is 9 of 15 today.** The six older
plans have no such section, and retrofitting `none` into plans nobody has audited for deferrals
would manufacture the exact kind of record this entry exists to stop. The wording here first read
"every plan under `docs/superpowers/plans/` now carries", which was false by one command inside the
commit whose subject is records not matching reality:

```bash
for p in docs/superpowers/plans/*.md docs/superpowers/plans/archive/*.md; do
  printf '%s  %s\n' "$(grep -c '^## Deferrals' "$p")" "$(basename "$p")"
done                                    # 9 of 15 carry it; the other six predate the convention
``` A commit-message gate was assessed and **rejected**, measured in both
directions — the reasoning and the numbers are in
`docs/superpowers/plans/archive/2026-08-03-ten-open-divergences.md` under Task 7's Deferrals section. The
plan-file gate that would replace it is deferred to the CI-hardening spec. The original subject of
this entry — an assertion tying contract fields to assignments — still needs a contract marker in
the templates and is deferred to `docs/superpowers/plans/archive/2026-08-04-ci-hardening.md`, item 18. The
Spec E plan step is now annotated `not shipped` rather than reading as a delivered check.

**11. The dangling-link check sampled 100 links and did not scan them all — FIXED on
`fix/exhaustive-dangling-scan`.** Kept in place and kept numbered, for the same reason as 1, 2, 4, 6
and 7–9: entries are referenced by number from work in flight, and renumbering invalidates those
references. Full record in
[Closed on `fix/exhaustive-dangling-scan`](docs/closed-divergences.md#closed-on-fixexhaustive-dangling-scan).

**12. The matcher class outlives `skill-sources/`, and every search string tried so far has been
narrower than the class.** This entry has now been wrong twice about its own scope, which is the part
worth keeping.

Divergence 6 tracked the matcher through `grep -rl "\[\[`. That string returns 0 across
`skill-sources/`, and it never meant what it was read to mean: the same matcher ships as
`xargs grep -l`, `-exec grep -l`, `rg -l`, `grep -r`, and single-quoted. The first widening of this
entry listed "six sites" — also wrong, because that regex still required a **double** quote and so
missed `skill-sources/reweave/SKILL.md` and `skill-sources/reflect/SKILL.md`, both single-quoted, both
inside the governed tree. A criterion written specifically to stop a narrow search being reported as
class-wide was itself narrow, and its blind spot landed inside the tree it governed.

**Match the property, not a spelling.** What separates a matcher from the library's extraction is a
*closed* `\]\]`: extraction captures with a negated class and never closes the brackets. So key on
that, and the pattern stops caring about command, flags, or quote style:

```bash
grep -rnE '(grep|rg)[^|]*\\\[\\\[.*\\\]\\\]' skill-sources/ skills/ platforms/claude-code/ reference/
```

**The property this entry is measured against**, stated here rather than cited, because a definition
that lives only in a plan file does not ship and cannot be recovered by a reader: *no **executable**
code in `skill-sources/` may inline a wiki-link matcher* — where "executable" means inside a
` ```bash ` fence or a shipped script, and deliberately **excludes** documentation tables and
comments, which are prose about matchers rather than matchers that run. That word is load-bearing in
both directions: drop it and the claim below is false by the entry's own arithmetic; widen it to all
text and the entry would have to flag its own explanatory prose.

**The command above must carry the gate exclusion, and the reason is that this entry's own number
ratcheted without it.** `check-portability.sh` and `reference/test/guard-failure.test.sh` have to
*contain* matcher text to do their jobs — the guard states the patterns it searches for, and the
suite plants them into fixtures. `check-portability.sh` applies exactly this exclusion to itself via
`EXEMPT_PATHS` and says why in its header. The published command did not, so writing about matchers
inside a gate incremented the count: `fix/ci-hardening` took it from **10 to 12** (`check-portability.sh`
1→2, `guard-failure.test.sh` 0→1) purely by adding check 6 and its coverage. Measured with the
exclusion, the same branch moved it **9 → 9**. A count that rises when a gate is documented is
measuring the documentation — and the count has since fallen further still, as sites that branch
counted were converted to the library rather than merely written about:

```bash
/usr/bin/grep -rnE '(grep|rg)[^|]*\\\[\\\[.*\\\]\\\]' \
    skill-sources/ skills/ platforms/claude-code/ reference/ \
  | /usr/bin/grep -Ev 'reference/+(check-portability\.sh|test/guard-failure\.test\.sh):'   # 4
```

**`/+` is doing two jobs and both are load-bearing.** `grep -r` emits `reference//check-portability.sh`
with a doubled slash, so the guard's own `reference/(…)` spelling matches nothing here and returns the
unfiltered count — a wrong answer that looks plausible. `/+` absorbs the extra slash. It also keeps the
exclusion **directory-anchored**, which a basename match is not: `-Ev '(check-portability|guard-failure\.test)\.sh:'
reads correct and silently drops a real hit in any file named to resemble a gate — verified with a
planted decoy under `skills/` whose basename ended in `-check-portability.sh`, which vanished from the
count. (Named by shape rather than by path on purpose: `check-prose-paths.sh` resolves every repo path
in this file, and a deleted probe file cited by name fails that gate — as this sentence did on its
first draft.) That is the one-rename evasion
`check-portability.sh`'s own header describes rejecting for `--exclude`, and it was reintroduced here in
prose before this line was fixed.

Verified against the tree, not remembered: **9 hits**, and the claim worth making is what they are
not: zero of the seven are executable code that inlines a matcher inside `skill-sources/` — the
governed property above holds, and holds more tightly than the `9 = 7 + 2` split this entry used to
publish. The decomposition is `9 = 2 + 1 + 1 + 5`, not a bare total:

| Site | Role | Why it survives |
|---|---|---|
| `skill-sources/graph/SKILL.md:789` | documentation-table row | `rg '^topics:.*\[\[X\]\]'`, outside any fence — prose about a matcher, not one that runs |
| `skill-sources/graph/SKILL.md:794` | documentation-table row | same table, `rg '^source:.*\[\[X\]\]'` |
| `skills/health/SKILL.md:661` | shape matcher | `rg '^\s*- \[\[' \| grep -v ' — '` — takes no note title at all; carries `portability-exempt` |
| `reference/testing-milestones.md:425` | test spec | `grep -rl "\[\[$TITLE\]\]"` — a test SPEC's own worked example, not shipped code |
| `reference/test/moc-sync.test.sh` ×5 | assertion on rendered output | fixed-name greps for `[[broken-note]]`, `[[orphan-note]]`, `[[deleted-note]]`, `[[pending-note]]` and `[[promoted-note]]` — the first three asserting a note is **not** placed, the last two asserting one **is** in a MOC the suite just rendered. They match a literal slug the same file wrote, interpolate nothing, and read a `$BODY` string rather than selecting notes from a vault |

**Those last five arrived with `moc-sync.test.sh` and took this count from 4 to 9, in two steps (3 with the suite, 2 more when the final-review fix wave added end-to-end coverage for `pending` and `promoted`) — recorded as a
decomposition rather than a corrected total, because that is what the rest of this entry is about.**
They do not weaken the governed property, which is scoped to *executable code in `skill-sources/`*:
they are test assertions in `reference/test/`. The gated numeral moved, so the gate caught it; the
property did not.

Two are documentation-table rows, never executable at all. One interpolates nothing, so it was never
a check-6 candidate — a matcher with no `$` after `\[\[` regexes nothing but its own literal text. The
last is `testing-milestones.md`'s own MOC-ref check, teaching the pattern rather than shipping it.
**Zero executable interpolating sites remain in `skill-sources/`.**

**Divergence 13 also publishes a decomposition of its own residual count — do not merge the two.**
Divergence 12's residue here is two documentation rows, a non-interpolating shape check, and a test
spec's worked example; divergence 13's residue is a different operation entirely — a bracket-counting
`rg -o '\[\['` that was never the extraction class to begin with, and that class is now empty. Read
the subject, not the sum.

**What closed the other five rows this table used to carry — three files, five declarations** —
`skills/health/SKILL.md:132,467,520`, `skills/architect/SKILL.md:179` and
`platforms/claude-code/hooks/session-orient.sh.template:160` — **is the library, not documentation.**
Each was converted to `reference/lib/link-extraction.sh`'s functions, one commit at a time, and the
library gained three callers built for exactly this: `link_edge_map` (and its `_recursive` variant)
builds the full edge set once; `backlink_counts` derives per-note incoming counts from it;
`orphan_notes` derives the zero-incoming set. `LINK_EXTRACTION_VERSION` is now 4 (was 3 when this
paragraph was written; bumped by the F3 `LC_ALL=C` pin task), and a third column,
`source_path`, was added to the edge map's output specifically to disambiguate two notes that fold to
the same lowercased basename in different directories — a real collision hit during this conversion,
not a hypothetical one.

**Known limitation of even this pattern:** `[^|]*` fails on any site where a pipe sits between the
command and its pattern. No current site does. Start the next widening from that edge rather than
rediscovering it.

**The line numbers in that table drift** — the table above was re-derived fresh, not carried forward,
because the previous table's line numbers had already moved once by the time they were checked. Do
not trust a number here without re-running the pattern above; check 6's allowlist deliberately keys
on file and count rather than line for exactly this reason.

**Of the four, exactly one is check-6-gated, and the other three were never candidates.** Check 6 keys
on the *interpolation* — a `$` expanded directly after `\[\[`, which makes every character of a note
name a regex. Only `reference/testing-milestones.md:425` carries one; the two `graph` documentation
rows spell a literal `X`, and `skills/health/SKILL.md:661` takes no title at all. Check 6's allowlist
carries a **second** entry, `generators/features/maintenance.md` — but that site's matcher lives at
line 20, inside `generators/`, which sits outside the four trees this entry's own scan covers
(`skill-sources/ skills/ platforms/claude-code/ reference/`). It is a real site, found by check 6's
broader scan, but it is not one of the four hits above; its extraction-site counterpart at line 29 is
divergence 13's subject, not this entry's.

**Check 6's own allowlist drained from five entries to two as sites converted.** Introduced
together in commit `b89e3de` with `skills/architect/SKILL.md`, `skills/health/SKILL.md` (count
3), `platforms/claude-code/hooks/session-orient.sh.template`, `reference/testing-milestones.md`
and `generators/features/maintenance.md`, it lost the first three as each site converted to the
library — leaving the two survivors this entry already names above
(`reference/testing-milestones.md`, `generators/features/maintenance.md`). Re-derive:

```bash
git show b89e3de:reference/check-portability.sh | grep -A6 'INTERP_ALLOW='   # 5 entries
grep -A3 'INTERP_ALLOW=' reference/check-portability.sh                     # 2 entries
```

**Still ungated, and the distinction matters:** check 2 flags a link capture whose negated class omits
the `|`/`#` terminators — it keys on `[^` being *present*, and a fixed-name bracket grep has no
negated class at all. So a matcher that interpolates nothing (`grep -l '[[Index]]'`) is caught by
neither check — which is exactly why the two `graph` documentation rows above are unreachable by
either gate and rely on this entry's own scan instead. `skills/health/SKILL.md:661` is a different
case: it *does* carry a negated class (`[^]]*`), so check 2 part A reaches it, and it is excluded only
by its explicit `portability-exempt` marker — `check-portability.sh` prints `NOTE: 1 site(s) exempt via
portability-exempt marker`, and the guard's own SCOPE comment (`reference/check-portability.sh:134-138`)
names `skills/health/SKILL.md` as the reason that marker exists. Reached-and-exempted is not the same
claim as unreachable. And nothing enforces "do not inline the library's functions" — see the gate
table in `docs/verification.md`, and divergence 13. Both belong to the CI-hardening spec.

**What remains unconverted is now deliberate, not merely undone.** `reference/testing-milestones.md`
teaches the matcher pattern inside a test spec's worked example, and `generators/features/maintenance.md`
emits a matcher as a recipe into a generated vault's own documentation — a recipe cannot source a
library the way a fence can, so converting either changes what generation emits or teaches, not what
ships as executable matching code today. `session-orient.sh.template`, `skills/architect` and
`skills/health` no longer belong in that category: they were the previous divergence in this family,
and they are now converted, not merely documented as risky. What changed structurally is that the
list can no longer rot silently — an entry whose site is fixed, or whose count moves, now fails the
gate.

**13. The extraction class is closed within `skill-sources/` and `skills/` — not closed everywhere,
and this entry now says which scope, not a bare "closed."** `reference/lib/link-extraction.sh` used
to expose directory-scoped functions only — `count_links`, `extract_link_targets`,
`existing_note_index` and their `_recursive` variants — which answered nothing about per-file or
per-target questions. Every caller that needed backlinks, per-note incoming counts, or "what does
this SET of files link to" re-inlined the same three-stage pipeline: `_strip_fences` →
`rg -o '\[\[([^\]|#]+)' -r '$1'` → `_fold_lower`.

**Closure was the library gaining functions, not the callers being rewritten around the old
pipeline.** `link_edge_map` (and `_recursive`), `backlink_counts` (and `_recursive`), and
`orphan_notes` (and `_recursive`) now exist — `LINK_EXTRACTION_VERSION` moved to 3 on that branch
(now 4, bumped again by the F3 `LC_ALL=C` pin task), and a third
output column, `source_path`, was added to the edge map specifically to disambiguate two notes whose
lowercased basenames collide across directories, a real collision hit during the conversion, not a
hypothetical one. Every site that inlined the pipeline for a per-file or per-target question inside
these two trees now calls one of these functions instead.

**Re-derive it, and expect 2, not 9 — what remains is a different operation, and was never this
class.** The distinguishing property is the *capture*: this class extracts a target with
`([^\]|#]+)' -r '$1'`. A bare `rg -o '\[\['` counts bracket occurrences and captures nothing, which
is a link **count**, a different operation with none of the per-target problem this entry describes.
Two such sites exist (`skill-sources/graph/SKILL.md:552`, `skill-sources/stats/SKILL.md:386`), so
`2 = 0 + 2`. **Divergence 12 now publishes `9 = 2 + 1 + 1 + 5` for a different set** — there the residue
is two documentation-table rows, a non-interpolating shape matcher and a test spec's worked example;
here it is only the bracket counters, a different operation entirely. Same "publish the
decomposition" idiom, different subject; do not merge them. Match the capture, not the brackets:

```bash
grep -rnF "rg -o '\[\["      skill-sources/ skills/ | wc -l   # 2, both operations
grep -rnF "rg -o '\[\[([^"   skill-sources/ skills/ | wc -l   # 0, this class
grep -rnF "rg -o '\[\[' "    skill-sources/ skills/ | wc -l   # 2, the bracket counters
```

`-F` is load-bearing in all three. Without it the middle pattern's `[^` opens a bracket expression;
the *bare* command errors (`grep: brackets ([ ]) not balanced`, rc 2), but piped through `| wc -l`
that error is swallowed and the pipeline reports `0` at rc 0 — a wrong answer that looks like a
plausible result rather than a failure, which is this repo's failure mode exactly. The trailing space
in the third pattern is also load-bearing: it is what separates `'\[\['` from `'\[\[([^…'`.

**The scope qualifier is load-bearing, because the class survives one line outside it.**
`generators/features/maintenance.md:29` spells `rg -oNI '\[\[([^\]|#]+)' {DOMAIN:notes/} -r '$1'` — a
recipe emitted into a generated vault's own documentation, not code that runs here, but the identical
capture pattern this entry is about. It is missed by the verification commands above for **two
independent reasons**, not one: first, `generators/` is outside the two trees those commands scan
(`skill-sources/ skills/`); second, even a scan that reached it would miss it as spelled, because it
uses `rg -oNI` and the fixed-string pattern above is `"rg -o '\[\[([^"` — the `-oNI` never matches
`-o '`. That second reason is divergence 12's own lesson recurring inside this entry: a search string
narrower than the class it claims to measure. It is not converted for the same reason
`generators/features/maintenance.md`'s matcher (divergence 12's second check-6 entry, at line 20 in
the same file) is not: a recipe cannot source a library the way a fence can, so fixing it changes what
generation emits rather than what ships as executable code today.

Note the interaction with divergence 12's matcher-class pattern: because the bracket-counter sites use
`rg -o` with no closing `\]\]`, that class-wide matcher pattern correctly does
**not** flag them. They are a separate defect, not a residue of the same one.

**14 — pointer, not a new entry: the platform hook template's two threshold placeholders are
substituted by nothing in this repo** — knobs that look configurable and are not. Filed inside
divergence 3 (which is where it was found and where its evidence lives) rather than given an entry of
its own; this line exists so a reader scanning headings finds it at all.

**15. Two gates a merged branch was expected to leave behind do not exist, and the expectation lived
only in a plan.** `docs/superpowers/specs/archive/2026-08-04-ci-hardening-design.md` items 22 and 23 carry
forward an expectation from Spec F's Task 3: that closing the `status` enum split would be followed
by (a) an assertion that the enum stays consistent across `generators/`, and (b) a
`check-portability.sh` ban on inlining `reference/lib/frontmatter.sh`, once that library existed.
`fix/spec-f-divergence-drain` has since **merged** — `820af90` is on `main` — and neither gate was
built. The expectation was recorded in a plan file, which is a record nobody re-reads; this entry is
it moved somewhere a reader arrives at by accident.

**The fix HELD; it is the gate that is missing, and the distinction is the entry.** Measured: the
note-status enum is currently *consistent* across all three files that declare it —
`generators/features/atomic-notes.md:94`, `schema.md:137` and `templates.md:30` all read
`preliminary | open | active | archived`. The other `status:` values in `generators/` are **different
fields sharing a name** (`self-evolution.md:195` is `pending | resolved | dissolved` for tensions;
`methodology-knowledge.md:31` is `active` for methodology notes), which the closed record for
divergences 7-9 already documents. So nothing is broken today. What is absent is anything that would
notice if it broke — and Spec F's own closing note said the enum had been split across those files
once already.

```bash
# (a) BUILT on fix/spec-h-enforcement-gap -- now names check-doc-claims.sh
for f in reference/check-*.sh reference/test/*.test.sh; do
  /usr/bin/grep -lE 'generators/.*status|atomic-notes|schema\.md' "$f"; done
# (b) BUILT on the same branch -- check 7; was 0, now non-zero
/usr/bin/grep -c 'frontmatter' reference/check-portability.sh
# The note-status declarations, which must agree. Normalise the spelling first:
# the same enum is written three ways (`a | b`, `[a, b]`, and backticked table
# cells), so a bare sort -u returns 3 and reads as a split that is not there.
/usr/bin/grep -rho 'preliminary[^]]*archived' generators/ \
  | tr -d '`|,' | tr -s ' ' | sed 's/^ *//;s/ *$//' | sort -u        # 1 line
/usr/bin/grep -rl 'preliminary' generators/ | wc -l                   # 3 FILES
/usr/bin/grep -rc 'preliminary' generators/ | /usr/bin/grep -v ':0'   # 4 DECLARATIONS
```

**AMENDED 2026-08-05 — both gates now exist, and this entry was wrong about its own subject in two
ways.** Amended rather than superseded, because it is referenced by number.

**It counts FILES where the unit is DECLARATIONS, and the two differ.** The entry names
`atomic-notes.md:94`, `schema.md:137` and `templates.md:30` — three files, and it misses
`schema.md:30`, a fourth declaration in a table row inside a file it already lists. Its own
verification command is `grep -rl … | wc -l`, which counts files, so it structurally could not have
seen it. **A file-to-file comparison cannot see two fields of ONE file disagree** — verbatim the
blind spot `bump-version.test.sh` exists for, one tree over. The gate compares declarations; both
commands are above so the discrepancy is visible rather than inferable.

**Its tension-enum citation is stale in address and in content.** It reads "`self-evolution.md:195`
`pending | resolved | dissolved`"; the tension enum is now `:218` with eight values, changed by
Task 1 of this branch. An entry citing a line AND a value set has two things that rot, which is why
neither is quoted here without the command beside it.

**What each gate does and does not cover** — the honest half, since (a)'s design question was real:
`check-doc-claims.sh` asserts cross-declaration agreement for the NOTE enum, which is the only one
declared more than once. That property is **vacuous** for the observation and tension enums, declared
once each. The tension enum is covered a different way — its three recipe CONSUMERS in `generators/`
must only match values it declares, which is the C3 defect this branch shipped and caught. The
observation enum is **not covered**: its consumer is the SessionStart hook, outside that gate's tree.
No authority decision was needed, because the gate reports a split without naming a winner.

(b) is `check-portability.sh` check 7. Its size is stated once, in the gate table in
`docs/verification.md`, and gated there — see that row rather than a second copy here, because this entry already
demonstrates what a duplicated count does. What belongs here is the SHAPE: it was written first with
a detector narrower than the property, missing the flagless spelling `rg '^status: open' dir/`
entirely, and one of the sites it missed is named by line in the closed record for divergences 7-9.
That is divergence 12's finding reproduced inside the commit that cites it, and it is the second
reason this entry exists. A green run means "no NEW hand-rolled parse", never "none exists". It does
NOT cover a copied-out awk parser, an unanchored or double-quoted equivalent, or an inlined copy of
`link-extraction.sh` — which remains convention only, so divergences 12 and 13 are unaffected.

**16. A generated vault has THREE tiers of validation and they do not connect — and no gate closes
this, because every gate this repo has reads THIS repo.** Filed 2026-08-05 from
`fix/spec-h-enforcement-gap`. Distinct from every entry above: those are defects with a fix. This is
a structural property of the generator/vault relationship, and it is recorded because a reader who
does not know it will keep writing rules that cannot arrive.

| tier | example in the field vault | reachable from here? |
|---|---|---|
| generated, thin | `.claude/hooks/validate-note.sh` — 42 lines; checks `description`, `topics` | **only in a NEW vault**; no re-sync mechanism exists |
| hand-written, enforced | `.claude/hooks/validate-node-schema.py` — 299 lines, wired PostToolUse, **blocks commits** | **never — it has no generator counterpart at all** |
| prompt-based, soft | `/validate` reading `_schema` | ships, but fires only on invocation and only if the agent complies |

**The consequence, stated plainly: a rule added to this repo today reaches new vaults only, and
cannot reach an existing vault's real gate by any path.** "Fix it in the generator" fixes it
*forward*. That is not pessimism — it is the difference between a spec that closes a class and one
that believes it did.

**This branch produced a clean instance rather than an argument.** Spec F converted
`hooks/scripts/session-orient.sh` to the frontmatter library — it sources `ops/lib/frontmatter.sh`,
fails loud when absent, and counts with `count_notes_by_field`. The template a generated vault
derives from, `platforms/claude-code/hooks/session-orient.sh.template`, was **not** converted and
still reads `grep -rl '^status: pending\|^status: open'`, silently, with no library and no guard. So
the plugin's own hook is frontmatter-strict and what vaults get is not. It is the same file pair
divergence 3 already flags for the threshold duplication — **two independent defects, one pair of
files, neither reachable by any gate.** Check 7 allowlists it with the blocker stated; it is not
merely undone.

```bash
# the plugin's own hook: sources the library, fails loud
/usr/bin/grep -n 'frontmatter\|count_notes_by_field' hooks/scripts/session-orient.sh
# what a vault derives from: neither
sed 's/#.*$//' platforms/claude-code/hooks/session-orient.sh.template \
  | /usr/bin/grep -n "grep -r[Llcq]* '\^status"
```

**A SECOND live instance arrived on the same branch, from work that was not even in its plan.** The
content-destruction guard in `hooks/scripts/write-validate.sh` compares a written note against its
last committed version. Measured: nothing under `skills/` or `generators/` names `write-validate` at
all — the only code reference in the tree is `hooks/hooks.json`, which wires the PLUGIN's own copy.
So the vault template beside it is reference material Claude reads while generating, exactly the
mechanism this entry's neighbour (divergence 3) describes for `session-orient.sh.template`: what
reaches a vault is whatever Claude *derives*, which is not a copy and tracks nothing. And the plugin
copy is gated behind a hardcoded `*/notes/*` case filter, so on the field vault — `nodes/`, the vault
whose defect motivated the guard — it cannot fire either. A guard that reaches neither side is the
three-tier gap in miniature, built by someone who had just written this entry.

```bash
/usr/bin/grep -rln 'write-validate' skills/ generators/     # no hits, rc 1
/usr/bin/grep -n 'notes/' hooks/scripts/write-validate.sh | head -2   # the hardcoded filter
```

**`/arscontexta:upgrade` is the nearest thing to a mechanism, and divergence 5 records that it has
no recorded slash-command invocation against a real vault** — a gap that is undone, not structural,
since a session whose cwd is the vault invokes it natively. Its repairs were
hand-executed against an `rsync` copy once, which found six defects. A design for real re-sync is its
own spec and is explicitly out of scope for Spec H.

**What would close this is not a check.** It is a generated-artifact refresh mechanism, plus a
generator counterpart for the enforced tier that today exists only as hand-written vault code. Both
are generation-surface changes. Until then, every "we fixed it in the generator" in this file should
be read as "we fixed it for vaults not yet created".

**17. `check-prose-paths.sh` cannot see any path under a dot-directory, and widening it is
NOT a one-token fix.** Filed 2026-08-18 from `fix/pi-package-route`. `PREFIXES` lists eleven
top-level names plus `.github`; `.pi`, `.opencode`, `.codex-plugin`, `.claude-plugin` and
`.agents` are absent, so a path naming any of those trees fails the prefix filter and is
counted in neither `found` nor `missing`. The three host INSTALL docs were added to SCOPE
precisely because they are dense with repo paths — and the adapter paths they and `README.md`
name are exactly the ones the filter drops. This branch deleted a file that `CLAUDE.md` then
named in prose, and the gate reported `0 missing`: it passed on absence, not on correctness.

**Measured by probe, and the result is why this is deferred rather than fixed.** Adding the
five dot-prefixes moves the check from `309 paths, 0 missing` to `330 paths, 3 missing`.
**Only one of the three was a real defect** — this branch's own, fixed before commit. The
other two are `.pi/settings.json`, named twice in `.pi/INSTALL.md`, which is **a user's
project config file, not a file in this repository**. That is the design problem in one line:
`.pi/`, `.opencode/` and `.codex-plugin/` each name both a directory here and the
conventional per-project config directory on the host, so a prefix match cannot separate a
repo path from a host path, and a naive widening turns correct prose into a FAIL. Any real
fix needs a per-prefix rule about which side of that line a token falls on.

Deferred to the CI-hardening spec, per the repo's standing rule (`docs/verification.md`) that building a missing gate
is a gate-design question and does not get bolted on to the branch that finds it. Re-derive —
the probe is a copy with the prefixes prepended, run from inside `reference/` because the
script resolves its scope relative to its own location and fails loudly when that scope comes
out empty:

```bash
/usr/bin/grep -n '^PREFIXES=' reference/check-prose-paths.sh    # .pi and friends absent
bash reference/check-prose-paths.sh | tail -2                   # 0 missing -- dot-paths unseen
```

### Closed divergences

Four sections recording work that was found, fixed and verified — `fix/exhaustive-dangling-scan`,
`fix/spec-f-divergence-drain`, `fix/spec-e-fourteen-items` and `fix/spec-c-primitive-10` — now live
in `docs/closed-divergences.md`. They are referenced by number from the open list above and were
moved so that completed work stops loading into every session. The content is unchanged.

### Won't fix

Distinct from both lists above, and the distinction is what the section is for. An **open**
divergence is work someone should do. A **closed** one is work someone did. A won't-fix is a real
defect that will not be repaired, with the reason stated — and it sits here rather than in the open
list because an entry nobody may act on, left among entries that invite action, is a standing
invitation to try. Removing it entirely would be worse: the next reader finds the defect, assumes it
is unrecorded, and rediscovers the reason from scratch.

- **A display count in the frozen tree merges statuses under a filtered label.** Was divergence 4's
  first half. `platforms/shared/skill-blocks/stats.md:94-95` documents unfiltered counts under
  the label "Pending" — two `ls -1 … | wc -l` rows that count files, not open items — the same
  unsupportable-label defect fixed in `skills/help`,
  `hooks/scripts/session-orient.sh` and `skills/health`.

  **It cannot be fixed where it is.** `platforms/shared/skill-blocks/` is frozen: every file in it
  is pinned against a `cksum` manifest by `check-portability.sh` check 4, which fails CI on any
  modification, deletion, or unpinned addition at any depth. Editing the line to correct the label
  would turn the gate red, and re-pinning the manifest to accommodate the edit would defeat the
  freeze — the tree's whole purpose is to be a read-only inventory of vocabulary points, and its
  guard and logic parity with `skill-sources/` is explicitly not maintained.

  **The blast radius is zero, which is why won't-fix is the right answer rather than a reluctant
  one.** That tree generates nothing: no vault is produced from it, so no user has ever seen this
  count. It is documentation of a vocabulary surface, not a computation anyone runs. Verify both
  halves — that the defect is there, and that the freeze is what stops the repair:

  ```bash
  sed -n '94,95p' platforms/shared/skill-blocks/stats.md          # the unfiltered "Pending" label
  grep -n 'skill-blocks' reference/check-portability.sh | head -3 # check 4 pins the tree
  ```

  Reopening this is a decision about the freeze, not about the label. If the freeze is ever lifted,
  the fix is the `skills/help` one: name the variable what it counts, and label it what it is.

### The cross-cutting pattern

Nearly every entry above — plus the vault's own `pdf_to_text` stub-on-scanned-PDF, its
extraction subagent capping at 20 claims, and its quarantine hook moving files while reporting
success — is the **same failure class: silent failure**. Exit 0, empty output, plausible-looking
result, no error.

When adding a bash block to any skill template, assume this repo's failure mode is silence, not
noise. Make the block assert its own preconditions and say so when they fail.
