# Deferrals

**A deferral is a decision NOT to do something, with the reason and the condition that
would reopen it.** It is not a TODO. A TODO says "someone should"; a deferral says "we
looked, we decided no, and here is what would change our minds."

## Why this file exists

Deferrals were previously recorded in each plan's `## Deferrals` section. That
convention exists because of divergence 10 — two commits claimed findings were
"recorded" when they had been written only to the git-ignored `.superpowers/` ledger,
and **a record that does not ship is not a record.** The plan sections fixed the
shipping half and left the reading half broken: a deferral in
`docs/superpowers/plans/archive/2026-08-04-ci-hardening.md` is tracked, but nobody opens a
four-month-old plan to find out whether a question was already settled. So the same
question gets re-litigated, or worse, silently answered the other way.

**One list, read top to bottom, is the shape that works** — the same reason CLAUDE.md's
"Known open divergences" section is an ordered list in one file rather than a directory.

## How to use it

- **Plans keep their `## Deferrals` section**, but each line now names the entry here
  rather than restating it. The plan says *what it deferred*; this file says *why, and
  what reopens it*.
- **Every entry needs a reopening trigger** stated as an observable condition, not a
  preference. "If it becomes a problem" is not a trigger. "If a second independent
  consumer compares against this number" is.
- **An entry that is acted on gets MOVED to Closed, not deleted.** A ledger that
  quietly drops items is the status-file-that-lies defect this repo already documents.
- **Numbers here go stale like numbers anywhere.** Where an entry cites one, it carries
  the command that re-derives it.
- **A `**From:**` field names its source by BARE FILENAME, never by path** — every entry
  below does, deliberately, so the reference survives the file being moved. It also means
  the name alone does not tell you where the file is. Completed plans and their specs now
  live under `docs/superpowers/plans/archive/` and `docs/superpowers/specs/archive/`; only
  plans still being executed sit at `docs/superpowers/plans/*.md`. Resolve a `**From:**` by
  looking in both. Prose elsewhere in this file cites full paths and was rewritten when the
  archive was created — the two addressing styles are intentional, not drift.

---

## Open

### 1. `generators/features/maintenance.md` — both link-matcher classes

**What:** `:20` is an interpolated matcher (divergence 12's class, and the site check 6
gates); `:29` is an inlined extraction (divergence 13's class). Neither is converted to
`reference/lib/link-extraction.sh`.

**Why not:** a **recipe emitted into a generated vault's documentation cannot source a
library the way a fence can.** Converting it changes what generation emits, which is a
different kind of change from fixing a fence. Same blocker CLAUDE.md records for the
`generators/features/*` `rg '^status: …'` recipes.

**Note the arithmetic trap:** `:29` is an *eighth* site of divergence 13's class, which
sits outside that divergence's published search (it scans `skill-sources/` and `skills/`
only). "Divergence 13 — all 7 closed" is therefore closed-**within-scope**, not closed.

**Reopens if:** a mechanism exists for a generated vault's documentation to reference a
library, or the recipes move into fences.

**From:** `2026-08-08-corpus-wide-passes-design.md`, `2026-08-08-link-edge-map.md`

```bash
/usr/bin/grep -nE 'rg |grep ' generators/features/maintenance.md   # :20 matcher, :29 extraction
```

### 2. `reference/testing-milestones.md:425` — matcher in a test spec

**What:** an interpolated wiki-link matcher in a test specification.

**Why not:** it is a **spec, not executable code** — teaching the pattern is not
shipping it.

**Reopens if:** the spec's examples ever become executable fixtures.

**From:** same two documents. Note docs/open-divergences.md's divergence-12 table still cites `:410`;
the true line is `:425`.

### 4. The materialized backlink cache

**What:** caching the link edge map to `ops/cache/` instead of recomputing it per fence.

**Why not — measured, not assumed:**

| path | cost |
|---|---|
| cache: staleness check 0.155s + read 0.048s | **0.203s** |
| rebuild | **0.278–0.30s** |

It saves **0.075–0.094s (~27–32%)**, and the ratio is **flat across corpus size**
because both sides are O(n) filesystem traversals — so **no node-count threshold exists
at which it starts paying.** Worse, mtime staleness is unsound: 1-second granularity
misses a same-second write, and `git checkout` / `touch -t` / rsync all preserve mtimes.
Each is a wrong backlink count returned with **exit 0**. A content-hash check would be
sound and costs at least as much as rebuilding.

**Reopens if:** a corpus exists where one pass exceeds a stated wall-clock budget **and**
a sound staleness check is measurably cheaper than a rebuild. Both halves required.

**From:** `2026-08-08-corpus-wide-passes-design.md`

### 8. `open`'s semantics

**What:** the canonical enum declares `preliminary | open | active | archived`. Nothing
anywhere defines what `open` means or what transitions into or out of it.

**Why not:** specifying it would be shipping a guessed state machine.

**Reopens if:** a vault or a skill needs the state, or it is retired from the enum.

**From:** `2026-08-08-corpus-wide-passes-design.md`

### 10. The contract-field assertion

**What:** an assertion that every `[A-Z_]*` field named in an output-format contract has
an assignment in the same file.

**Why not:** it mis-fired on three healthy templates (`graph`, `next`, `remember`).
Precise detection needs an explicit contract marker in the templates; without one it
cannot distinguish a documented-but-computed-elsewhere field from a stale one.

**Reopens if:** contract markers are added to the templates.

**From:** CLAUDE.md divergence 10; deferred to
`docs/superpowers/specs/archive/2026-08-04-ci-hardening-design.md` item 18

### 11. Divergence 16 — the three-tier validation gap

**What:** a generated vault has three tiers of validation that do not connect, and every
gate in this repo reads *this* repo. A rule added here reaches vaults **not yet
created**.

**Why not:** closing it needs a generated-artifact refresh mechanism plus a generator
counterpart for the enforced tier that today exists only as hand-written vault code.
Both are generation-surface changes.

**Reopens:** it is its own spec. Until it lands, read every "we fixed it in the
generator" in this repo as "we fixed it for vaults not yet created."

**From:** CLAUDE.md divergence 16

### 12. The `generators/` status enum declarations are not placeholder-bearing — **TRIGGER FIRED 2026-08-15; RE-DEFERRED 2026-08-24, BLOCKED ON A MECHANISM**

**What:** once status values are vocabulary (`{vocabulary.status_preliminary}` et al.),
the enum declarations in `generators/features/atomic-notes.md`, `schema.md` (×2) and
`templates.md` still spell canonical literals.

**Why not now:** converting four declarations across three files changes what
`check-placeholder-count.sh` measures in all of them. Doing that inside a plan whose
risk is already "what a newly created note looks like" mixes two unrelated failure
modes — if a count moves, you cannot attribute it.

**Note the file-vs-declaration trap:** it is **4 declarations in 3 files** —
`schema.md` carries two. A file-to-file survey sees three and misses one, which is the
blind spot divergence 15's amendment documents and `bump-version.test.sh` exists for.

**Reopens:** immediately after the note-convention-and-lifecycle plan lands. This is a
"next, separately", not a "never".

**Amended 2026-08-24 (vocabulary-integrity spec).** This was carried into that spec as its sixth
item and resequenced out on a *mechanism* finding, not on effort. `generators/` carries **0**
`{vocabulary.*}` markers against **527** `{DOMAIN:*}`, resolves `{vocabulary.*}` by no documented
mechanism, and is excluded from both placeholder gates (`check-vocabulary-schema.sh:12-15`,
`check-placeholder-count.sh:37-47`). Converting the four declarations there would ship a marker
family that nothing substitutes and no gate checks — a new silent-failure surface, which is the
exact class that spec exists to close.

**Prerequisite — supersedes the `Reopens:` trigger above.** Either document how `{vocabulary.*}`
resolves for the composition path, **or** rule that tree permanently `{DOMAIN:*}`-only. Until one
of those lands this entry is not actionable, and the older trigger is retired because it gates on
the wrong event: the note-convention plan landing says nothing about whether a substitution
mechanism exists.

**From:** `2026-08-08-note-convention-and-lifecycle.md` self-review

```bash
/usr/bin/grep -rn 'preliminary' generators/          # 4 declarations
/usr/bin/grep -rl 'preliminary' generators/ | wc -l  # 3 files -- NOT the same number
```

### 13. Conflation in orphan-count computation on SessionStart

**What:** `platforms/claude-code/hooks/session-orient.sh.template:183` uses `grep -c .
|| true` to count lines piped from `comm -23`. This command has two distinct non-zero-exit causes: (1) zero matches (healthy, ORPHAN_COUNT should be 0) and (2) upstream failure (broken computation, signal should omit). The `|| true` collapses both to ORPHAN_COUNT=0, which contradicts the block's own comment at :154–159 that states: "NEVER substitute 0 … a fabricated 0 would silently suppress the signal forever … Same rule for a computation failure, not only a missing/stale library."

**Why not now:** The `|| true` was added because the earlier false-positive "scan failed" warning fired on every healthy SessionStart (when `grep -c .` exits 1 on empty input), training users to ignore the signal. A query-breaking `comm` failure is unreachable under normal conditions — sort, awk, grep, mktemp, and the library all work correctly in healthy cases. The trade moved from "false positive on 100% of healthy starts" to "silent 0 on rare failure". It is not a clean win; it is a trade, which is why it is recorded rather than left to rot in memory.

**Reopens if:** A second failure mode surfaces that can empty `$tgts` or `$idx` without tripping an earlier guard (the `[ -n "$idx" ]` and `[ -d "$NOTES_DIR" ]` checks, now at :177 and :163 — corrected 2026-08-15; the entry originally cited :165 and :162, both off by one, which is a deferral whose own line references had drifted). Such a mode would make the conflation reachable and remedy 1 required.

**AMENDED 2026-08-15 — task 15, post-merge-hardening.** Task 10 (already complete) touched the
`[ -d "$NOTES_DIR" ]` guard this entry's own "Reopens if" clause names, and the trigger above is
**not** tripped: task 10 added an `else` warning to that guard's existing `if`, so a missing
`NOTES_DIR` is now loud on stderr rather than silent — the guard was not bypassed, and no new route
into the `comm -23 | grep -c . || true` conflation was opened. This entry stays open, not reopened.

What task 10 does change is this entry's own framing. "Why not now" characterizes the silent-0 path
as reachable only through a *rare* internal failure — sort, awk, grep, mktemp all working. That
framing was already incomplete before task 10 and remains so after it: the outer `[ -d "$NOTES_DIR" ]`
guard means the entire block this entry is about — including the conflation it diagnoses — never
executes at all for any vault whose notes directory does not resolve to the literal path `notes/`
(an unsubstituted `{{NOTES_DIR:-notes}}` placeholder, or a vault that legitimately named its notes
directory something else). That is not rare in the way "sort/awk/grep/mktemp fail" is rare — it is
the default outcome for any vault that customized `{{NOTES_DIR}}`. Before task 10 this route was
silent, same outcome as the conflation this entry names, reached a different way. After task 10 it
warns, so the common route is no longer silent; the entry's remaining scope is the narrower one it
was always about — the inner conflation, still real, still requiring an actual sort/awk/grep/mktemp
failure to reach.

```bash
/usr/bin/grep -n 'ORPHAN_COUNT=0\|if \[ -d "\$NOTES_DIR" \]' platforms/claude-code/hooks/session-orient.sh.template   # :162, :163
/usr/bin/grep -n 'notes directory .* not found; orphan signal omitted' platforms/claude-code/hooks/session-orient.sh.template   # task 10's else warning
```

**From:** `2026-08-08-link-edge-map.md` final whole-branch review

```bash
/usr/bin/grep -n 'grep -c \. \|\| true' platforms/claude-code/hooks/session-orient.sh.template  # line 183
/usr/bin/grep -n 'grep -c \. \|\| true' skill-sources/graph/SKILL.md                          # line 174
/usr/bin/grep -n 'grep -c \. \|\| true' skill-sources/stats/SKILL.md                          # lines 225, 282
/usr/bin/grep -n 'NEVER substitute 0' platforms/claude-code/hooks/session-orient.sh.template  # line 155
```

---

### 15. The PostToolUse matcher is `Write`, so `Edit`/`MultiEdit` bypass the content-destruction guard

**What:** `hooks/hooks.json:17` matches `"Write"` only. `hooks/scripts/write-validate.sh` compares a
written note against its last committed version to catch content destruction — and never runs when a
note is changed with `Edit` or `MultiEdit`, which is how notes are usually changed.

**Why not now:** Widening the matcher makes the guard fire on every edit in every installed vault.
That is a scope decision about what the plugin does on other people's machines, not a defect fix, and
it compounds with divergence 16: the guard is already gated behind a hardcoded `*/notes/*` filter, so
on the field vault (`nodes/`) it cannot fire even for `Write`. Widening the matcher without also
resolving the path filter would add load without adding coverage.

**Reopens if:** the `*/notes/*` filter is made vocabulary-aware, at which point the matcher becomes
the only remaining thing keeping the guard from running.

**From:** `2026-08-05-generator-vault-enforcement-gap.md` Task 1

```bash
/usr/bin/grep -n '"matcher"' hooks/hooks.json                    # line 17, "Write"
/usr/bin/grep -n 'notes/' hooks/scripts/write-validate.sh | head -2
```

---

### 18. `check-placeholder-count.sh` is range-relative in two ways that let a real change through

**What:** (a) `-M` pairs a rename with an edit only while the two sides stay similar; a template
renamed *and* rewritten end-to-end arrives as an add plus a delete and is never compared. The shape
is now NAMED rather than silent (`NOTE: template deleted, not compared`) but is not a failure,
because deleting a template is legitimate. (b) Allowlist staleness is scoped to files in the diff
range, so a fully obsolete entry survives until some range happens to touch its file again.

**Why not now:** Both are the price of a range-relative gate, which is deliberate — it is the only
gate that reads a git range, and that is what lets it catch a backport that drops placeholders.
Closing (a) needs content-similarity pairing the gate does not have. Tree-relative checks exist
alongside it and cover the standing state: `check-portability.sh` check 6 and
`check-vocabulary-schema.sh`.

**Reopens if:** a template is renamed and rewritten in one commit and placeholders are lost in the
process — the exact case (a) cannot see.

**From:** `2026-08-04-ci-hardening.md` Task 3

```bash
/usr/bin/grep -n '\-M' reference/check-placeholder-count.sh
bash reference/check-placeholder-count.sh main; echo "rc=$?"    # 0 clean, 1 finding, 2 no merge base
```

---

### 20. `validate-kernel.sh`'s C1 violation list caps at five

**What:** `reference/validate-kernel.sh:1093` prints five offenders then `... and $((c1_missing - 5))
more`. On the field vault C1 reports 13 violations and names 5.

**Why not now:** It discloses the remainder in the same line, so it is a truncated *display* and not
a sampled *measurement* — the count itself is exhaustive. That is the distinction divergence 11 turned
on: the dangling-link scan was fixed because it sampled the computation; this samples only the
printout.

**Reopens if:** the cap is ever applied to the computation rather than the display, or the "and N
more" suffix is dropped, at which point the output stops disclosing its own truncation.

**From:** `2026-08-05-generator-vault-enforcement-gap.md` Task 3

```bash
/usr/bin/grep -n 'and \$((c1_missing' reference/validate-kernel.sh        # line 1093
```

---

### 21. The fence gate never exercises the queue fences' JSON dispatch arm

**What:** Task 12a's seven repointed fences dispatch on queue format: `*.yaml` → `queue_yaml`, else
`queue_edit` with the original jq filter. The fence gate's healthy fixture always creates
`ops/queue/queue.yaml` (deliberately, beside the `queue.json` tombstone — that coexistence is what
turned the seven red in the first place), so YAML always wins the search order and the fences' jq
arm is never executed by that gate, in either shell.

**Why not now:** The jq arm's mechanics are covered where they live — `queue-edit.test.sh` asserts
`queue_edit`'s argument pass-through, tombstone refusal, lock and guarded rename — and a
JSON-only fixture variant is a harness design change (a second `build_fixture` mode or a
per-fence fixture override), not a one-line addition. A fixture rigged so JSON wins would also
stop modeling the field-measured tombstone shape the gate exists to pin.

**Reopens if:** a queue fence's JSON branch changes (the un-exercised arm is where a regression
would land unseen by the fence gate), or the CI-hardening spec picks up harness variants.

**From:** task 12a (`.superpowers` report, promoted here per divergence 10; plan
`2026-08-09-post-merge-hardening.md` ## Deferrals)

```bash
# The fixture WRITE itself, not merely lines mentioning the name — a `| head -3` over
# 'queue.yaml' returns a KNOWN_OPEN entry and two comments and proves nothing:
/usr/bin/grep -n '> "\$v/ops/queue/queue\.yaml"' reference/test/fence-isolation.test.sh   # :204, the healthy fixture writing it
```

---

### 22. `next` f02's JSON arm never writes `completed` — pre-existing, preserved, marked

**What:** In `skill-sources/next/SKILL.md` fence f02 (auto-close a satisfied maintenance task),
the JSON arm's jq filter sets `.status = "done"` in its first clause, then the second clause
re-selects `.status == "pending"` — which no longer matches the task just closed — so
`.completed = $ts` lands on nothing. Tasks auto-close without a completion timestamp on JSON
queues. The YAML arm added by task 12a sets both fields correctly.

**Why not now:** Pre-existing (it shipped with the original fence, before task 12a), and task
12a's scope was the dead write path, not the filters' semantics — fixing it inside that commit
would have hidden a behavior change in a port commit (Rule 5). The fix is one line: select once
into a variable binding or repeat the selection on `condition_key` alone. It wants its own
commit and a suite assertion pinning "close writes both fields."

**Reopens if:** anyone touches f02, or a JSON-queue vault's `/next` auto-close is debugged for
missing `completed` timestamps — the site carries a `# KNOWN:` comment pointing here.

**From:** task 12a (`.superpowers` report, promoted here per divergence 10; plan
`2026-08-09-post-merge-hardening.md` ## Deferrals)

```bash
/usr/bin/grep -n 'and .status == "pending")).completed' skill-sources/next/SKILL.md   # the dead clause
```

---

### 23. `check-portability.sh` check 7's allowlist keeps the whitespace-split parse check 6 dropped

**What:** `FM_ALLOW` is `<path> <count> <reason>`, space-delimited, parsed at three sites via
`cut -d' ' -f1` / `-f2` and a `case "$rel "*` glob — the same silent-mis-parse class Task 13
closed for check 6's `INTERP_ALLOW`: a path containing a space parses as a shorter path plus
garbage, and nothing says so. Check 4's manifest parse (`${line%% *}` / `${line#* }`) is the same
shape one check over. Anchor on the variable names, not on line numbers — this file's own rule.

**Why not now:** Out of Task 13's stated scope — its brief bound the change to check 6 and
"allowlist's contents unchanged" — and the exposure is what entry 19(b)'s was before its closure:
zero space-bearing paths in the scanned trees today, `234 = 234 methodology/ + 0 scanned`
(re-derive with the commands preserved in entry 19 under [Closed](#closed); `core.quotePath=false`
is load-bearing there). Unlike 19(a), no false-PASS route is currently measured here; that
asymmetry is why 19 closed first and this one waits.

**Reopens if:** a space-bearing path lands in any tree the guard scans, or anyone edits check 7's
allowlist or its parses — a conversion should reuse check 6's now-tested `|` idiom and a
D19b-style entry-count assertion (measure ENTRIES, not pipe-lines in a fixed window) rather than
invent a third format.

**From:** Task 13 of `2026-08-09-post-merge-hardening.md` (finding promoted from the
`.superpowers` report per divergence 10 — review round 1 found the promotion had not shipped)

```bash
/usr/bin/grep -n "cut -d' ' -f" reference/check-portability.sh                        # check 7's parse sites
sed -n '/^FM_ALLOW="/,/^"$/p' reference/check-portability.sh | /usr/bin/grep -c '|'   # 0 — still space-delimited
```

---

### 24. `check-prose-paths.sh`'s SCOPE count is itself an ungated prose numeral

**FIRED 2026-08-23** — and independently of what tripped it. The prose half is fixed on
`fix/ci-timeout-bound`; the gate half below is unchanged and still owned by the CI-hardening spec.

**What:** the sentence stating the gate's SCOPE count in prose ("across 11 documents") and
republishing it inside its own bash re-derive block. Neither numeral is checked by any
gate — `check-doc-claims.sh` reads other sentences in this file for other quantities (the
executable-checks count, the CI-step count) and never mentions `check-prose-paths.sh` at all, so a
gate that reads one phrasing does not protect a synonym, per this file's own opening paragraph on
that exact subject. Task 14 (`fix/post-merge-hardening`) widened SCOPE from 9 to 11 and had to
hand-correct the prose at three sites in one paragraph to keep up; the next widening faces the
identical risk with nothing to catch it.

**Why not now:** wiring this count into `check-doc-claims.sh` is a change to that gate's own
claim-registration mechanism, not to `check-prose-paths.sh`, and is out of Task 14's stated scope
(widen SCOPE by two named files). `check-doc-claims.sh`'s design is itself a CI-hardening-spec
question, per the gate-table row in docs/verification.md ("Building the missing check is a
gate-design question and belongs to the CI-hardening spec").

**How it actually fired:** by drift, exactly as predicted, and it had already fired before the
split noticed. SCOPE went 11 -> 14 on the host-adapter branch while the prose stayed at eleven;
the same file said "It became fourteen" thirty-three lines below the stale "across 11 documents",
and no gate saw either. The split then took SCOPE to 16, which would have made the numeral wrong
a third time.

**Fixed on that branch (prose only):** the live numeral is REMOVED, not re-minted — the sentence
now reads "across the documents in its stated SCOPE list", and the entry's own re-derive command
carries the count. Re-minting it as "fourteen" or "sixteen" would have reproduced the exact defect
this entry describes; the precedent is the main-side CI-step count, fixed the same way. A history
sentence recording the 16 was appended beside the existing one, because a numeral describing a
past event does not rot. The sentence now lives in `docs/open-divergences.md`, not `CLAUDE.md`.

**Reopens if:** `check-prose-paths.sh`'s SCOPE list changes size again without the stated
count moving with it, found by drift rather than by a gate. Or: `check-doc-claims.sh` gains a
mechanism generic enough to register an arbitrary computed-count-vs-prose-numeral pair without a
bespoke assertion, at which point this pair should be its first user.

**From:** Task 14 (`.superpowers/sdd/2026-08-09-post-merge-hardening/task-14-report.md`),
`fix/post-merge-hardening`

```bash
awk '/^SCOPE="/{f=1;next} /^"/{f=0} f&&NF' reference/check-prose-paths.sh | /usr/bin/grep -c .   # 16, the live count
# POSITIVE assertion on the new wording. The old form was `grep -c 'across 11 documents' CLAUDE.md`,
# which returns 0 at exit 0 the moment the phrase moves or is reworded -- passing on absence, the
# very failure class this repo is about, inside a deferral entry about ungated numerals.
/usr/bin/grep -c 'across the documents in its stated SCOPE list' docs/open-divergences.md         # 1, the prose claim
/usr/bin/grep -c 'check-prose-paths' reference/check-doc-claims.sh                                # 0: gate STILL never reads this file's name
```

---

### 25. `check-prose-paths.sh` is zsh-broken by an unquoted `for f in $SCOPE`

**What:** `reference/check-prose-paths.sh:74` reads `for f in $SCOPE; do`, where `SCOPE` is a
multi-line heredoc variable. Under zsh, an unquoted `$SCOPE` in a `for` list is not word-split
(`SH_WORD_SPLIT` is off by default), so the entire 11-line SCOPE blob collapses into a single
"filename" argument — the loop body runs once against a string that is not a real path, fails the
existence/readability test, and the script reports `ERROR <blob> is in scope but missing or
unreadable` followed by `FAIL: scope is empty -- no files scanned`. Under bash the same script scans
all 11 files correctly (`scanned 11 files, checked 267 repo paths, 0 missing`, `PROSE PATHS: PASS`).
This is pre-existing and independent of Task 14's SCOPE widening — it reproduces on the unwidened
9-file SCOPE just as it does on the current 11-file one.

This exact bug class is pre-named as a risk by this task's own governing plan — Global Constraint #2
(`docs/superpowers/plans/archive/2026-08-09-post-merge-hardening.md:54`), verbatim: *"zsh also does **not**
word-split an unquoted `$var` in a `for` list; use `while IFS= read -r`."* `check-prose-paths.sh` is
an unconverted instance of exactly that named pattern, in a file this same task edited without
noticing the fork.

**The mitigation, and why it matters:** this is not a silent failure. The guard's own
zero-paths-extracted design (`found -eq 0` → exit 2, distinct from exit 1 for a genuine missing-path
finding — the property Task 14 preserved and re-verified) is what catches it: the collapsed blob
fails to resolve as a path, `found` stays 0, and the script exits loud with `FAIL: scope is empty --
no files scanned. This is a broken check, not a clean repo.` A reader who runs this under zsh gets an
unambiguous failure, not a false PASS. What is missing is not loudness but a *documented* invocation
contract: unlike `check-portability.sh`, which `guard-failure.test.sh` pins to `bash "$GUARD"` because
nothing anywhere invokes it any other way, nothing pins `check-prose-paths.sh` to bash-only. Its
bash-only-safe posture is accidental, not a decision this repo has recorded — which is the distinction
that matters here, not bash-vs-zsh in the abstract.

**Why not now:** fixing the fork (rewriting the loop as `while IFS= read -r f; do … done <<<"$SCOPE"`,
per the plan's own prescribed remedy) is a change to `check-prose-paths.sh`'s shell-portability
posture, not to its SCOPE list — out of Task 14's stated scope (widen SCOPE by two named files).
Every documented invocation of this script in this repo (`CLAUDE.md`, CI, `.pre-commit-config.yaml`)
already spells `bash reference/check-prose-paths.sh`, so the fork has no organic trigger today; but
that same sentence was true of `check-portability.sh` until a human typed `zsh` in front of a
different script (`bump-version.sh`) and shipped a live zsh fork anyway.

**Reopens if:** anyone invokes this script under zsh (by habit, by a new CI matrix leg, or by
following this file's own "Run every suite under BOTH bash and zsh" constraint literally onto a
script that is not a suite), or if a future task hardens `check-prose-paths.sh`'s shell portability
and this entry should close alongside it. The fix, when taken, should also add a
`guard-failure.test.sh`-style pin (or an explicit `check-prose-paths.sh` header comment) recording
which shell(s) it is invoked under, so the posture stops being accidental either way.

**From:** Task 14 (`.superpowers/sdd/2026-08-09-post-merge-hardening/task-14-report.md`),
`fix/post-merge-hardening` — found during Task 14's guard-invariant verification, review round 1
(coordinator finding, Important 2)

```bash
grep -n 'for f in \$SCOPE' reference/check-prose-paths.sh   # :74, the unquoted for-list
bash reference/check-prose-paths.sh; echo "bash rc=$?"      # rc=0, PASS, 11 files scanned
zsh  reference/check-prose-paths.sh; echo "zsh rc=$?"       # rc=2, "scope is empty", loud FAIL
grep -n 'word-split' docs/superpowers/plans/archive/2026-08-09-post-merge-hardening.md   # :54, the named risk class
```

---

### 26. PR #7 merged 46 commits; the plan that drove its review describes only 35

**What:** The merge commit for PR #7 (`a98352c`, `crichalchemist/arscontexta`) landed 46 commits
on `main`, not the 35 that `2026-08-08-link-edge-map.md` — the plan whose review this branch's own
adversarial pass was scoped against — set out to produce. Eleven earlier backport commits, already
sitting on the branch before that plan's work began, rode along inside the same PR, described by
neither the PR body nor the plan. That undescribed eleven-commit range is not incidental: it
includes the entire initial `reference/lib/queue-edit.sh` — a third shared library, with seven
consumers, that consequently never passed through the plan's own review process the way
`link-extraction.sh` and `frontmatter.sh` did. Two of the ten findings the subsequent adversarial
review raised against `a98352c` live in that undescribed half: **F1** — `queue_edit`'s commit step
(`mv "$tmp" "$file"`) was unguarded, so a failed rename returned rc 0, left the queue file
unchanged, and left a staged temp beside it, silently defeating the library's own stated
fail-loud contract — and **F6** — `/health` Category 9 audited `link-extraction.sh` and
`frontmatter.sh` but not `queue-edit.sh`, the very library that had ridden along undescribed.

**Why not now:** there is nothing left to implement — both findings this provenance gap produced
are already fixed on this branch (Task 8, `694e880`: `queue_edit`'s commit step is now guarded —
the F1a/F1b assertions; Task 12a: `QUEUE_EDIT_VERSION` moved 1→2; Task 9, `69003a1`: `/health`'s
shared `check_lib` helper now covers all three
libraries), and CLAUDE.md's `QUEUE_EDIT_VERSION` paragraph (added by task 15) already documents the
fixed state. What this entry closes is a different gap: the provenance fact itself — a PR silently
carrying undescribed backport work past the review its own findings are numbered against — already
exists as tracked, committed, non-gitignored prose (`docs/superpowers/specs/archive/2026-08-09-post-merge-hardening-design.md`'s
"Provenance matters here" paragraph, duplicated in `docs/superpowers/plans/archive/2026-08-09-post-merge-hardening.md:1469`),
but only inside this branch's own task-scoped spec and plan documents. Those are exactly the kind
of file this branch's own history shows going stale or getting archived once the branch that
produced them lands (see `docs/closed-divergences.md`'s absorption of earlier per-branch sections).
`deferrals.md` is this repo's durable ledger; the process lesson here — that a PR's stated scope and
its actual commit range can silently diverge, hiding findings inside the gap — outlives this one
branch and belongs in the file that does.

**Reopens if:** a future PR's merged commit range again exceeds what its driving plan or PR body
describes, by any margin — the remedy each time is the same: run the three `git rev-list --count`
comparisons below against the new range before treating a plan's stated commit count as the actual
diff under review, and re-check whether any review finding traces to the undescribed portion.

**From:** Task 15 (`.superpowers/sdd/2026-08-09-post-merge-hardening/task-15-brief.md`),
`fix/post-merge-hardening` — cross-referencing
`docs/superpowers/specs/archive/2026-08-09-post-merge-hardening-design.md`'s "Provenance matters here"
paragraph and its grouping-B finding pair (F1, F6)

```bash
git rev-list --count 542fed8..d2c5054   # 11 — pre-existing backport work, incl. queue-edit.sh v1
git rev-list --count d2c5054..77928ee   # 35 — the link-edge-map plan's own described scope
git rev-list --count 542fed8..77928ee   # 46 — actually merged by PR #7 (merge commit a98352c)
/usr/bin/grep -n 'QUEUE_EDIT_VERSION=' reference/lib/queue-edit.sh   # 2 — the task-12a bump; the F1 guard itself shipped in task 8 (694e880)
/usr/bin/grep -n 'queue-edit' skills/health/SKILL.md | /usr/bin/grep -c .   # F6 fixed, task 9
```

---

### 27. `/upgrade` option (b) — the customization-preserving merge — stays withheld

**What:** `skills/upgrade/SKILL.md` offers (a) keep and (c) replace-with-archive; option (b), a
merge preserving a user's customizations, is deliberately not offered. Its stated blocker — "this
repo carries no release tags to recover it" (`git tag` returns 0, still true) — is no longer the
whole story: five complete cached baselines sit under
`~/.claude/plugins/cache/agenticnotetaking/arscontexta/` (`0.8.0 0.9.0 0.9.5 0.9.6 0.9.7`, 16
`skill-sources/` directories each), so the canonical side of a merge baseline is recoverable from
cache. Task 19 annotated the skill with that path beside the release-tags sentence; it did not
restore the option.

**Why not now:** restoring (b) is a behavior change to a plugin skill where a wrong merge
**corrupts a user's customized skills** — a worse failure than the withholding it repairs. And the
cached baseline is usually-present, not guaranteed: a cache can be pruned, and mapping an installed
skill back to its cached original is a derivation rather than a lookup — measured 2026-08-15, the
field vault's stamps no longer name a plugin version at all (10 of its 16 skills carry
`generated_from: "arscontexta-v1.6"` and the other 6 carry no stamp), so the earlier claim that the
cache holds "both versions the field vault is stamped with" no longer holds as stated. Needs its
own spec.

**Reopens if:** any vault reports a customization lost to `/upgrade`'s replace path — at that point
the cost of withholding exceeds the risk of merging — or a baseline-retention mechanism (release
tags, or a pinned per-vault baseline copy) lands, making the baseline guaranteed rather than
usually-present.

**From:** Task 19 (`.superpowers/sdd/2026-08-09-post-merge-hardening/task-19-brief.md`),
`fix/post-merge-hardening`, spec §15.

```bash
git tag | wc -l                                                    # 0 — no release tags
ls -1 ~/.claude/plugins/cache/agenticnotetaking/arscontexta/       # 0.8.0 0.9.0 0.9.5 0.9.6 0.9.7
for v in ~/.claude/plugins/cache/agenticnotetaking/arscontexta/*/; do
  ls -1 "$v/skill-sources" | wc -l
done                                                               # 16, five times — each complete
/usr/bin/grep -rho 'generated_from:.*' ~/second-brain/.claude/skills/*/SKILL.md \
  | sort | uniq -c        # 10 x arscontexta-v1.6, of 16 skills; the other 6 carry no stamp line
/usr/bin/grep -c 'plugins/cache/agenticnotetaking' skills/upgrade/SKILL.md   # >=1 — the annotation
```

---

### 28. `TENS_TOTAL`'s `find -H` has no symlink fixture of its own

**What:** `hooks/scripts/session-orient.sh:159` computes `TENS_TOTAL` with `find -H`, added by
Task 11 alongside `OBS_TOTAL`'s (`:158`). D17b in `reference/test/hook-config.test.sh` pins the
`-H` behavior through a symlinked `ops/observations` only — the suite's single `ln -s` fixture
points at observations — so deleting `-H` from `:159` alone leaves every gate green. The visible
symptom of that mutation is the invariant Task 11 exists to hold: `count_open_items` goes through
the library's `_fm_find_md`, which carries its own `-H`, and still finds open tensions, while
`TENS_TOTAL` reads 0 through a symlinked `ops/tensions` — "N pending (of 0 total)", the
observations defect reappearing one directory over, seen by a user and by no gate.

**Why not now:** promoted from the gitignored task-11 report at final review (divergence 10: a
record that does not ship is not a record). The fix is mechanical — a D17c mirroring D17b with
`tensions` substituted, born red against a `-H`-less `:159` — but it was outside the consolidated
fix round's stated scope, which shipped that round's own born-red assertion (the D16b field arm)
instead of a second one.

**Reopens if:** anyone edits `session-orient.sh:158`-`:159` or the D17 block — write D17c first,
verify it red against a `-H`-less `:159`, then touch the hook.

**From:** Task 11 (`.superpowers/sdd/2026-08-09-post-merge-hardening/task-11-report.md`),
`fix/post-merge-hardening`; promoted by the final fix round.

```bash
/usr/bin/grep -n 'find -H ops/' hooks/scripts/session-orient.sh      # :158 observations, :159 tensions
/usr/bin/grep -n 'ln -s' reference/test/hook-config.test.sh          # one fixture — observations only
```

---

### 29. `comm`-collation residue: two stale rationales inside the governed trees, two unpinned sites outside them

**What:** Two survivors of Task 4's collation work, both the "conclusion true, reasoning false"
class it fixed. (a) `skill-sources/graph/SKILL.md` (~`:127`) and `skill-sources/next/SKILL.md`
(~`:352`) still gloss their orphan/dangling comparisons with "Both sides are already folded and
sorted by the library, which is what makes comm valid" — but sortedness never makes `comm` valid,
identical COLLATION does, which graph's own later comment states in full. The invocations
themselves are now pinned `LC_ALL=C comm` (final fix round), so the conclusion stays true for a
new reason; the prose survives to teach the fallacy to the next reader. Anchor on the phrase, not
the line numbers — they drift. (b) The same sweep found the unpinned-`comm` class survives
outside the trees the review named: `reference/validate-kernel.sh:520`'s dangling-count `comm`
(both operands C-sorted, the collation requirement argued in its own comment a few lines up) and
`scripts/sync-thinking.sh`'s three `comm`s (unsorted `echo` operands — a different and worse
state).

**Why not now:** (a) the pinning commit deliberately did not reword two rationale blocks — a
behavior-neutral locale pin should not smuggle prose rewrites past review (Rule 5). (b) is out of
the review's flagged scope (`skill-sources/` templates), and pinning `validate-kernel.sh` should
land with a field-vault re-run of the validator, which is its own verification cost.

**Reopens if:** anyone edits either rationale, either outside site, or lands a new `comm`
anywhere — the property is "every `comm` carries `LC_ALL=C` and its rationale names collation,
not sortedness".

**From:** Task 4 (`.superpowers/sdd/2026-08-09-post-merge-hardening/final-triage.md`, deferred
minors), promoted and extended by the final fix round.

```bash
# 'makes comm valid', not the fuller phrase: next/SKILL.md hard-wraps 'which is
# what' onto the previous line, and the longer pattern finds only graph — this
# command's first spelling did exactly that, a pattern narrower than its class.
/usr/bin/grep -rn 'makes comm valid' skill-sources/                        # 2 — the two stale rationales
/usr/bin/grep -rn '\bcomm -[0-9]' reference/validate-kernel.sh scripts/sync-thinking.sh \
  | /usr/bin/grep -v 'LC_ALL=C comm'                                       # the unpinned survivors (one hit is validate-kernel's :508 comment)
```

---

### 30. Six controller errors on this branch — condensed record

**What:** The controller running this branch's task dispatch disclosed its own errors in the
gitignored session ledger as they happened; divergence 10 makes that no record, so the condensed
list lands here. Six, in task order: (1) Task 12 — told the implementer THREE doc sites carried
the suite total when there were FIVE, because the controller's grep required an `N/M` slash form
and missed a `(52/0)` and a bare prose numeral. (2) Task 12a — the brief instructed
`{config.ops_dir}` placeholders for queue paths, a marker that appears nowhere in
`skill-sources/` (it is the frozen `skill-blocks/` dialect); followed literally it would have
shipped an unsubstituted marker into every generated vault. (3) Task 16 — repeated the
implementer's "six deleted lines" claim to the ledger and the user as established fact without
re-checking a brief already read in full. (4) Task 16 — the "six" then traced back to the
controller's OWN dispatch message, which undercounted 8 as six; the root of the chain, not a
relay of it. (5) Task 18 — verified a paragraph's numbers through the bundling frame the
paragraph itself supplied, so the unmeasured half (`model:`) inherited the assumption that made
the claim false. (6) Task 19 — a pre-derivation ending in `| tail -5` presented as a complete
date list; the true list had six entries, and the truncation was invisible because a truncated
list looks exactly like a short one. Separately, three implementer REPORTS contradicted their own
source documents — Task 16's misattributed "six", Task 17's summary-vs-table mismatch, Task 19's
non-verbatim quotation — report-vs-source incidents, each caught in review.

**Why not now:** nothing to implement — every error was caught and its work product corrected on
the branch. The record ships because the shapes recur: recollection-vs-file,
verification-through-the-document's-own-frame, and display-truncation-read-as-completeness are
the same narrower-than-the-class failures this repo's gates catch in code, appearing in the
process that builds the gates.

**Reopens if:** never, as such — it is a record, not work. Cite it when a dispatch, review or
report repeats one of the three shapes.

**From:** `.superpowers/sdd/2026-08-09-post-merge-hardening/final-triage.md` ("Controller errors
made during this branch"), promoted per divergence 10. No re-derive command: this is a process
record, not a claim about the tree.

---

### 32. Note-lifecycle branch — nine items, of which two are live, seven are MOOT, and one is not a deferral

**From:** `docs/superpowers/plans/2026-08-15-note-lifecycle-and-description-convention.md`,
whose own `## Deferrals` section reads "Nothing else." That was true when written and is no
longer, which is why these land here rather than only in commit messages and a gitignored
ledger — divergence 10's rule.

**STATUS AFTER THE BRANCH MERGED (`a5ccae3`, 2026-08-15) — read this before acting on any
item below.** The heading first read "four deferrals" and the entry grew to nine while it
said so; that is the drift this file exists to catch, caught by an audit rather than by a
gate.

| items | status | why |
|---|---|---|
| **1** | **CLOSED 2026-08-24**, with entry 6, as both required. The residue was twelve normative sites, not the two named here — see entry 6 for the full list and the tree-wide re-derive | the generators tree was out of scope for `/reduce` |
| **2** | **LIVE** — a design question, not a defect. `/verify`'s gate is a defensible subset of the computable checks, not the complete one | shipped at `skill-sources/verify/SKILL.md:326-327` |
| **3–9** | **MOOT ×7 — nobody fixed these; the ground disappeared.** Every one is a property of `reference/migrate-note-lifecycle.sh` and its suite, which were created and deleted **inside** `94f44de..a5ccae3` and do not exist at HEAD | see the re-derive below |

**MOOT is not RESOLVED, and the distinction is load-bearing here**, because the script *ran*
before it was deleted: items 5, 6 and 9 describe decisions now baked into 2090 live vault
notes. All three were fail-safe by their own accounts — modes measured `644` throughout, zero
symlinked notes, and a kept period is never corruption — so there is nothing to chase. But a
reader who takes MOOT to mean "was fixed" would draw the wrong conclusion about the corpus.

```bash
# added AND deleted inside the range, so the net branch diff shows neither
git log --diff-filter=A --name-only --format='' 94f44de..a5ccae3 | grep migrate-note-lifecycle
test -e reference/migrate-note-lifecycle.sh || echo "GONE at HEAD"
```

1. **`~150 chars` survives at TWO generators sites, not one.** The plan's Deferrals names
   `generators/features/schema.md:18`; `generators/features/atomic-notes.md:75` is a second.
   Both belong to the generators tree rather than to `/reduce`, which is why Task 3 left them.
   **CLOSED 2026-08-24.** Two was itself an undercount — the term-keyed survey was scoped to
   `generators/` and could not see `reference/`, where nine more sites lived. Twelve in total.
   A third hit, `skills/architect/SKILL.md:482`, is the phrase `"line ~150"` — a line-number
   reference, not a description-length claim — and is correctly out of scope.

   ```bash
   /usr/bin/grep -rn '~150' skill-sources/ generators/ skills/    # 3 = 2 generators + 1 unrelated
   ```

2. **`/verify`'s promotion gate names three checks; it is a defensible subset of the
   computable ones, not the complete one.** `REVIEW: Frontmatter: [PASS/FAIL]` and
   `{DOMAIN:topic map} connection: [PASS/FAIL]` are equally binary and excluded with no
   stated rationale. Inherited verbatim from the plan's own Step 2 text, so this is a design
   question, not an execution defect. Nothing tests any of it — nothing in this repo executes
   template prose.

3. **The migration script rewrites duplicate `status:` lines individually while `mapped`
   counts once.** A file with two frontmatter `status:` keys is already ambiguous YAML;
   refusing it would be the consistent choice. Measured **0 of 2874** in the field vault.
   Moot once the script is deleted, recorded because the same shape recurs.

4. **A description with trailing whitespace after its closing quote is refused** by the
   per-line balance check. Fail-safe and named on stderr; 0 occurrences in the corpus.

5. **`stat -f '%OLp'` masks the high bits on BSD.** A note at `2755`, `4755` or `1755` is
   reported as `755`, so setgid/setuid/sticky is dropped before any guard can see it. The
   field vault is `644` throughout (2874 of 2874), so this cannot fire there. It is a
   property of the probe, not of the guards that consume it.

6. **A symlinked note is replaced by a regular file.** `mv` writes over the link rather than
   through it, so the link's target is never migrated and the run reports success. Measured
   **0 symlinked notes of 2874** in the field vault. A hostile or wrong `stat` returning a
   valid-but-incorrect mode is undetectable by construction, and is conceded rather than
   guarded.

7. **Seven guards are unasserted and were previously undisclosed**, enumerated by the final
   pre-apply review: `${1:?}`, `command -v awk`, `base==""` inside `ends_abbrev`,
   `[ -r "$f" ]`, both `mktemp ||` branches, and the two output-invariant refusals (leading
   `---` absent; output shorter than input). All are environment preconditions or
   unreachable-by-construction, since the transform only exits 0 on success. Listed rather
   than tested because each would require shadowing a coreutil to reach.

8. **A populated but non-matching tree exits 0 with `files changed: 0`**, which the script's
   fail-loud header does not cover. This is a deliberate tension rather than a defect: exit 0
   on no-work is exactly what the idempotency contract requires, since a second `--apply`
   must be a clean zero. Making "nothing to do" loud would break "running twice is safe".
   Recorded so the next reader does not resolve it in one direction without seeing the other.

9. **Three of the eight preserved abbreviations are preserved for the wrong reason.** `d.` and
   `k.` are math symbols ending real sentences ("at fixed d.", "regardless of k."), matched
   by the single-LETTER rule intended for initials; `vol.` matched the list in the *volume*
   sense while the text means *volatility*. All three outcomes are fail-safe — a kept period,
   never corruption — and the fixture label "initial" is looser than what it matches.

**Not a deferral, stated so it is not mistaken for one:** the migration's three mode guards
(octal validation, non-empty check, `chmod` status check) are mutually redundant, so **no
single-site mutation of any one of them is observable** — removing any one leaves the outcome
identical. That is defense in depth, not missing coverage, and the measured guard matrix is in
the branch's ledger. Two compound mutations do reproduce the defect: `guard+chmod` under
either stat shim, and `octal+chmod` under a shim returning a non-empty non-mode.

---

## Design-track — not deferrals, listed so they are not mistaken for open work

These are decisions awaiting a **design pass**, not decisions already made.

- **Auto-fix trailing period as a corpus convention** — resolved into
  `2026-08-08-corpus-wide-passes-design.md` item 1. *(closed as a design-track item)*
- **Fan-out concurrency findings** (agent identity vs liveness; ungoverned
  cross-orchestrator concurrency; diffusion-of-responsibility defect backlog;
  ground-truth-only state re-derivation; pre-fan-out validation as the highest-value
  crash point; no global fan-out visibility). Six findings from the field vault,
  captured and explicitly **not implemented**. Need their own brainstorm.

---

## Closed

*(Entries move here when acted on, with the commit that did it. They are never
deleted: a ledger that quietly drops items is the status-file-that-lies defect this repo
documents about itself.)*

### 19. `check-portability.sh` check 6 — substring matching and a whitespace-split allowlist

**CLOSED 2026-08-15 by `cbcd48f` (Task 13, `fix/post-merge-hardening`) — and the closure
measured this entry's central claim FALSE. Recorded rather than silently corrected, the way
CLAUDE.md keeps its own drifted lines.** From filing until 2026-08-15 the entry asserted that the
unanchored match could produce "a false FAIL, never a false PASS" and so "fails in the safe
direction by construction". Measured otherwise: a hit line whose CONTENT names another allowlisted
path with its trailing colon inflates that path's `interp_hits_in` count, and the stale loop's
`!= 0` skip then swallows the GONE arm for a deleted allowlisted file — check 6 reports green over
a masked STALE. A false PASS, in the gate the entry called safe by construction, established three
ways: a born-red fixture (`guard-failure.test.sh`, the D19a pair), the Task 13 reviewer's
independent measurement, and a mutation restoring the substring count that reddens exactly those
two assertions. The fix: `interp_hits_in` anchors with `awk 'index($0,p)==1'`, still fixed-string;
`INTERP_ALLOW` is `|`-delimited with all three parse sites updated; contents unchanged. The entry
below is preserved as filed — including the false claim — because the drift is the evidence.

**What:** (a) `interp_hits_in` (`:436`, used at `:484` and `:497`) is an unanchored `-F` substring
match, while the half it is compared against parses paths differently; any divergence produces a
false FAIL, never a false PASS. (b) The allowlist is whitespace-delimited, so a path containing a
space mis-parses silently.

**Why not now:** (a) fails in the safe direction by construction — a gate that cries wolf gets
investigated, and this one has, twice. (b) has no instance **in the trees check 6 scans**. Read that
qualifier as load-bearing: **234 tracked paths do contain a space**, and the first version of this
entry claimed "no path in the tree contains a space" on the strength of a command it had not run.
All 234 are in `methodology/`, whose filenames are whole sentences and which the check's declared
scope excludes; the scanned trees hold **zero**. State it as `234 = 234 methodology + 0 scanned`
rather than filtering down to a bare `0`, which is the same one-number-hides-the-class error the
guard itself exists to catch. Both findings sit inside the guard that divergence 12 warns is the one
place where writing *about* matchers inflates the matcher count, so edits here are conservative.

**Reopens if:** a path containing a space appears under any tree check 6 scans (`skill-sources/`,
`skills/`, `platforms/`, `reference/`, `generators/`) — not merely anywhere in the repo — or check 6's
allowlist grows an entry whose file is matched by another entry as a substring.

**From:** `2026-08-04-ci-hardening.md` Task 2 (findings M-2 and M-5)

**`core.quotePath=false` is required and its absence is silent.** `git ls-files` quotes any path
holding a non-ASCII byte, so that line arrives as `"methodology/notes are skills \342\200\224 …"` —
starting with `"`, not `m`. A `grep -v '^methodology/'` therefore reports **1** path outside
`methodology/` when the true answer is **0**, and the survivor looks like a real finding rather than
a quoting artifact. Exactly one tracked path is affected today, which is the worst case: enough to
make the filter wrong, too few to look broken.

```bash
/usr/bin/grep -n 'interp_hits_in' reference/check-portability.sh          # 436, 484, 497
git -c core.quotePath=false ls-files | /usr/bin/grep -c ' '               # 234, all methodology/
git -c core.quotePath=false ls-files | /usr/bin/grep ' ' \
  | /usr/bin/grep -cv '^methodology/'                                     # 0 — none outside it
git ls-files | /usr/bin/grep -c '^"'                                      # 1 — the quoted path
git -c core.quotePath=false ls-files | /usr/bin/grep ' ' \
  | /usr/bin/grep -c '^\(skill-sources\|skills\|platforms\|reference\|generators\)/'   # 0 — scanned trees
```


**Deferral text, merged from `## Open` on 2026-08-26.** The ledger carried this item in both sections at once; the convention is one entry that MOVES, so the original deferral now sits with its closure rather than reading as open work.

#### 19. `check-portability.sh` check 6 — substring matching and a whitespace-split allowlist — CLOSED

Closed by `cbcd48f` (Task 13, `fix/post-merge-hardening`): the hit count is now anchored and the
allowlist `|`-delimited, born-red and mutation-proved in `guard-failure.test.sh` (60/60 → 66/66,
both shells). The full entry moved to [Closed](#closed) per this file's own convention — **with a
drift record**, because the closure measured the entry's central claim false: it asserted the
substring match "fails in the safe direction by construction — a false FAIL, never a false PASS",
and the measured failure is a false PASS (a hit line naming a deleted allowlisted path masked the
GONE arm). Kept numbered here so references by number stay valid.

---
### 16. `read_config.sh` — two asymmetries between the bare-key and dotted-key paths

**CLOSED 2026-08-15, and the closure was recorded by a later fix round rather than by the commit
that did the work — that gap is itself the finding.** Task 12 (`d9662fd`,
`fix/post-merge-hardening`) closed BOTH asymmetries this entry filed: (a) the bare path now exits 1
on a present-but-empty value instead of silently returning the default — pinned by the D16a pair in
`reference/test/threshold-namespace.test.sh` — and (b) both paths now match keys fixed-string, so
an ERE metacharacter in a key matches nothing — pinned by the D16b pair. But `d9662fd` touched
`CLAUDE.md`, `CONTRIBUTING.md`, the hook and the suite, and never this ledger, so from that commit
until 2026-08-15 this entry's own closing command still asserted `52/52 — covers neither
asymmetry`. Measured at closure: the suite printed `56 passed, 0 failed` and covered both. The
numeral was false and the claim beside it was false — a status file lying about status, in the
ledger whose header warns about exactly that. The entry below is preserved as filed, including the
refuted command, because the drift is the evidence. Re-derive rather than quote — the same fix
round that recorded this closure adds a field-arm assertion and moves the total again:

```bash
/usr/bin/grep -n 'D16' reference/test/threshold-namespace.test.sh   # the assertions covering both
bash reference/test/threshold-namespace.test.sh | tail -1           # N passed, 0 failed
```

**What:** One reader, two code paths, differing in ways a caller cannot see. (a) A **present but
empty** value fails LOUD on the dotted path (`exit 1`) and SILENTLY returns the default on the bare
path — and returning the default is exactly how divergence 3's hardcoded `10` stayed invisible.
(b) Key names are interpolated into an awk ERE, so a dot in the key matches any character:
`self_evolution.obs.ervation` would match a line spelling `obsXervation`.

**Why not now:** Neither is reachable from any key this repo ships — every dotted key in use is a
clean identifier, and no shipped bare key is written-but-empty in a real `.arscontexta`. Fixing (b)
means escaping the key before interpolation, which is the same class as `check-portability.sh` check
6 and belongs with it rather than as a one-off.

**Reopens if:** any consumer starts passing a user-supplied or vocabulary-derived string as a config
key, which makes (b) reachable; or a bare key is added whose empty value is meaningful.

**From:** `2026-08-04-ci-hardening.md` Task 4

```bash
/usr/bin/grep -n 'exit 1' hooks/scripts/read_config.sh          # the dotted path's loud arm
/usr/bin/grep -n 'awk' hooks/scripts/read_config.sh             # the interpolation sites
bash reference/test/threshold-namespace.test.sh | tail -1       # 52/52 — covers neither asymmetry
```


**Deferral text, merged from `## Open` on 2026-08-26.** The ledger carried this item in both sections at once; the convention is one entry that MOVES, so the original deferral now sits with its closure rather than reading as open work.

#### 16. `read_config.sh` — two asymmetries between the bare-key and dotted-key paths — CLOSED

Closed by `d9662fd` (Task 12, `fix/post-merge-hardening`): the bare path now fails loud on a
present-but-empty value exactly as the dotted path does, and both paths match keys fixed-string
rather than through an interpolated ERE — pinned by the D16a/D16b assertions in
`reference/test/threshold-namespace.test.sh`. The full entry moved to [Closed](#closed) per this
file's own convention — **with a drift record**, because the commit that closed both asymmetries
never touched this ledger: the entry kept asserting `52/52 — covers neither asymmetry` while the
suite measured 56 and covered both. A status file lying about status, inside the ledger that
exists to prevent exactly that. Kept numbered so references by number stay valid.

---
### 31. `README.md` declares the version but `bump-version.sh` cannot manage it

**What:** `README.md:12` carries `**v0.9.9** · Claude Code plugin · MIT` — a real version
declaration outside `.version-bump.json`'s declared set. `bump-version.sh` is **JSON-only**:
every read and write goes through `jq` (`read_json_field`, `stage_json_field`, `jq_path`), so a
markdown badge cannot be added to `.files` at all. Its `--audit` correctly reports the site on
every run and cannot fix it.

**Why not now:** closing it needs one of three changes, each larger than a bump. Extend
`bump-version.sh` with pattern-based sites — a real feature in a tool whose 41-assertion suite
exists because it once shipped a partial bump, so it needs its own tests. Or drop the version
from `README.md` as redundant with `plugin.json` — a human-facing decision, since the badge is
the only place a reader sees the version without opening JSON. Or record it in `audit.exclude`
and bump it by hand — which is the partial-bump failure the tool exists to prevent, merely
documented.

**Reopens if:** `bump-version.sh` gains non-JSON site support for any other reason, or a bump
ships with `README.md` left stale — the exact outcome the audit is warning about.

**From:** the 0.9.7 → 0.9.9 bump, 2026-08-15. The README was updated by hand in that commit;
this entry exists because "by hand" is not a mechanism.

```bash
# the site the tool cannot reach, and the proof it cannot:
sed -n '12p' README.md
/usr/bin/grep -c 'README' .version-bump.json          # 0 — undeclared
/usr/bin/grep -c 'jq ' scripts/bump-version.sh        # every site read/write is jq
bash scripts/bump-version.sh --audit | tail -3        # reports README every run
```

---


### 6. The `~150` vs `200` description-length disagreement — **CLOSED 2026-08-24**
**CLOSED 2026-08-24 (vocabulary-integrity Unit 5), together with entry 32 item 1 as this entry
required.** The residue was **twelve** normative sites, not the two named below: the two
`generators/` sites, plus `reference/kernel.yaml:57` — the invariant contract, which would
otherwise have gone on declaring `~150` while the generators feeding it said `200` — plus
`reference/methodology.md:55` and all eight `reference/templates/*-note.md`, which teach the
value to every vault that instantiates one. Both re-derive commands below are scoped to
`skill-sources/ generators/ skills/` and so could not see nine of the twelve; the tree-wide form
is in the block at the end of this entry. All twelve now read `200 chars, no trailing period`,
the spelling `generators/features/schema.md:26` already used — the `no trailing period` clause is
now carried uniformly, where before only two of the twelve had it.

`reference/claim-map.md:84` is deliberately KEPT: it discusses the tension rather than declaring
the value, and rewriting it would erase the record of why the question was open.

```bash
git -c core.quotePath=false ls-files -z | xargs -0 /usr/bin/grep -ln '~150' \
  | /usr/bin/grep -v '^methodology/' | /usr/bin/grep -v '^platforms/shared/skill-blocks/' \
  | /usr/bin/grep -v '^docs/'
#   reference/claim-map.md           (KEEP -- discusses, does not declare)
#   reference/semantic-vs-keyword.md ("~150 notes", a volume threshold)
#   skills/architect/SKILL.md        ("line ~150", a line number)
```

**What:** two sites say `~150` (`generators/features/schema.md:18`,
`skill-sources/reduce/SKILL.md:473`), three say `200`.

**AMENDED 2026-08-15 — both halves of that sentence are now stale, in opposite directions.**
`skill-sources/reduce/SKILL.md` no longer says `~150` at all: the note-lifecycle branch moved
**both** of its sites to "max 200 chars, no trailing period". The `~150` residue is now two
sites, and **both are in `generators/`** — `schema.md:18` and `atomic-notes.md:75`, the latter
never named by this entry. And "three say `200`" measured **8** at the time of the audit.

**This is the same residue as entry 32 item 1. Fix them together or not at all** — they were
filed from different branches, describe the identical two files, and a reader closing one
would leave the other looking live.

**Why not:** found while counting period declarations; reconciling a length constraint
is a separate decision from a period. **The count is "at least" — a term-keyed survey
cannot enumerate sites that omit the term.** That caveat is exactly why this entry undercounted
its own subject by one file for a week.

```bash
/usr/bin/grep -rn '~150' skill-sources/ generators/ skills/   # 3 = 2 generators + 1 unrelated
/usr/bin/grep -rn '200 char\|max 200\|<=200\|<= 200' generators/ skill-sources/ | wc -l   # 8
```

**Reopens if:** anyone edits the description schema for any reason.

**From:** `2026-08-08-corpus-wide-passes-design.md`

## Closed by the 2026-08-15 audit

**Six entries, and only two were closed by the note-lifecycle branch.** The other four were
already fixed by `fix/post-merge-hardening` and sat in `## Open` unnoticed — **this register
was stale before the branch that audited it ever started.** That is the finding worth keeping:
a deferrals file is itself a status file, and nothing gates it.

### 3. `skill-sources/next:261` — the odd `LINK_LIB` spelling — CLOSED

Closed by `fix/post-merge-hardening`, not by this branch. All nine sites are now
`$VAULT_ROOT/`-prefixed; zero bare.

**Its own re-derive command was broken and is corrected here.** The entry declared
`# 8 prefixed, 1 bare`; measured, it is 9 and 0.

```bash
/usr/bin/grep -rn 'LINK_LIB=' skill-sources/ | grep -c 'VAULT_ROOT'   # 9
/usr/bin/grep -rn 'LINK_LIB=' skill-sources/ | grep -vc 'VAULT_ROOT'  # 0
```


**Deferral text, merged from `## Open` on 2026-08-26.** The ledger carried this item in both sections at once; the convention is one entry that MOVES, so the original deferral now sits with its closure rather than reading as open work.

#### 3. `skill-sources/next:261` — the odd `LINK_LIB` spelling — CLOSED

**What:** 8 sites spell `LINK_LIB="$VAULT_ROOT/ops/lib/link-extraction.sh"`; `next:261`
spells the bare relative `LINK_LIB="ops/lib/link-extraction.sh"`, which depends on the
fence's working directory.

**Why not now:** converting it inside link-library work would mix a behaviour-neutral
cleanup into a change whose whole risk is that reported numbers move. Fix it where it
can be reviewed on its own.

**Reopens:** immediately — this is a "do it separately", not a "do it never". Anyone
touching `next`'s link fences should take it.

**From:** `2026-08-08-link-edge-map.md`

```bash
/usr/bin/grep -rn 'LINK_LIB=' skill-sources/    # 8 prefixed, 1 bare
```
### 5. The 681 statusless field-vault notes — CLOSED, rationale OVERRIDDEN not satisfied

The migration (`~/second-brain` `6d941634`) backfilled **698** notes — the count had drifted
from 681 — to `status: active`. Statusless is now **0 of 2874**.

**Read the qualifier, because the entry's own reasoning was overruled rather than met.** It
deferred precisely because assigning a status would "assert a quality claim nothing checks",
and the backfill asserts `active` on all 698 anyway. The spec answers this directly — `active`
on a backfilled note asserts existence and reachability, nothing about quality, and the
migration commit is the marker separating those from promoted notes — but that is a *decision
taken against the entry's objection*, not a demonstration the objection was wrong.

Its stated reopening trigger ("a promotion criterion that does not require reading the note")
was independently tripped by the same branch: `/verify`'s mechanical gate is exactly that.

```bash
/usr/bin/grep -rL '^status:' ~/second-brain/nodes/ | grep -c .   # 0
```


**Deferral text, merged from `## Open` on 2026-08-26.** The ledger carried this item in both sections at once; the convention is one entry that MOVES, so the original deferral now sits with its closure rather than reading as open work.

#### 5. The 681 statusless field-vault notes — CLOSED (rationale OVERRIDDEN, not satisfied)

**What:** `/reduce` will stamp `status` on new notes; 681 existing notes predate the
stamp and violate the vault's own `required` schema (`insight-node.md:5-11`).

**Why not:** the stamp is forward-only. Backfilling needs a rule for what status a
pre-existing note should receive, and no such rule exists — inferring one from age or
link count would assert a quality claim nothing checked.

**Reopens if:** a promotion criterion is agreed that does not require reading the note.

**From:** `2026-08-08-corpus-wide-passes-design.md`
### 7. Off-enum vault statuses — CLOSED, **with an inversion worth flagging**

`closed` and `investigating` are gone from the vault; `superseded` became canonical in
`generators/`. Post-migration census: `active 2097 · draft 760 · archived 11 · superseded 4 ·
open 2` = 2874.

**The inversion:** the `investigating` → `open` remap put **2 notes on `open`, which is
canonical but absent from the vault's own template enum** (`~/second-brain/templates/insight-node.md`
declares `draft | active | superseded | archived`). So the same dialect gap now exists in the
opposite direction — the vault's template does not know a value its corpus carries. `draft`
(760) remains the standing gap the entry named as precedent rather than subject, and
`preliminary` has **0** notes.

See also entry 32 and the plugin spec's marker section: the `closed` → `archived` half of this
remap **deviated from the criterion the migration itself applied**, affecting 11 notes.


**Deferral text, merged from `## Open` on 2026-08-26.** The ledger carried this item in both sections at once; the convention is one entry that MOVES, so the original deferral now sits with its closure rather than reading as open work.

#### 7. Off-enum vault statuses — two different questions — CLOSED (with an inversion, see record)

**What:** the field vault carries `closed` (11), `investigating` (1) — in **neither** the
canonical enum nor its own template enum, so genuine violations. And `superseded` (3) —
in the vault's enum, absent from canonical, so a **dialect gap** like `draft`.

**Why not:** reconciling the generator with one vault's practice is a separate decision
with a different owner. Precedent: the divergences 7–9 closure made the same call.

**Reopens if:** the canonical status enum is revisited for any reason.

**From:** `2026-08-08-corpus-wide-passes-design.md`
### 9. `check-prose-paths.sh` scope excludes two files that name repo paths — CLOSED

Closed by `fix/post-merge-hardening`. Both `session-orient` files are now in `SCOPE`.

**Its re-derive command was not merely stale but INVERTED** — it declared
`# 0 — neither is listed`, and the measured answer is 2.

```bash
awk '/^SCOPE="/{f=1;next} /^"/{f=0} f&&NF' reference/check-prose-paths.sh \
  | grep -c session-orient    # 2
```


**Deferral text, merged from `## Open` on 2026-08-26.** The ledger carried this item in both sections at once; the convention is one entry that MOVES, so the original deferral now sits with its closure rather than reading as open work.

#### 9. `check-prose-paths.sh` scope excludes two files that name repo paths — CLOSED

**What:** `hooks/scripts/session-orient.sh` and
`platforms/claude-code/hooks/session-orient.sh.template` both name repo paths in
comments and in warning messages a user reads at SessionStart. Neither is in the gate's
stated 8-file scope.

**Why not:** the gate's scope is a **stated list**, not a discovered one, and that is
deliberate — a shrinking scope must not read as a clean result. Widening it is a
deliberate edit, not an oversight to patch.

**Reopens:** whenever someone is editing that gate anyway.

**From:** CLAUDE.md divergence 5

```bash
awk '/^SCOPE="/{f=1;next} /^"/{f=0} f&&NF' reference/check-prose-paths.sh
grep -c 'session-orient' reference/check-prose-paths.sh    # 0 — neither is listed
```
### 14. `fence-isolation.test.sh` uses a fixed temp path — CLOSED

Closed by `fix/post-merge-hardening`, using the digit-free unique-path remedy. The entry cited
line 50; the fix is at line 56 and the content differs, so anchor on the phrase.

```bash
/usr/bin/grep -n 'WORK=' reference/test/fence-isolation.test.sh   # unique per-process path
```


**Deferral text, merged from `## Open` on 2026-08-26.** The ledger carried this item in both sections at once; the convention is one entry that MOVES, so the original deferral now sits with its closure rather than reading as open work.

#### 14. `fence-isolation.test.sh` uses a fixed temp path, so two concurrent runs clobber each other — CLOSED

**What:** `reference/test/fence-isolation.test.sh:50` sets `WORK="/tmp/fence-isolation-gate-$SELF"`.
`$SELF` is the shell name, not a per-run token, so two runs of the same suite under the same shell
share one directory. Observed while running the suite in the foreground beside a background sweep:
the bash run reported `harness: extracted no fences — cannot conclude anything` and the zsh run died
on `rm: Permission denied`.

**Why not now:** CI cannot hit it — its steps are sequential — and the failure is LOUD rather than a
false PASS, since the "cannot conclude anything" arm is doing exactly its job. Recorded because a
local contributor running the suite twice sees a failure with no obvious cause.

**CORRECTED 2026-08-09 — this entry originally said "`mktemp -d` fixes it in one line". It does
not; it would reintroduce a defect the code already fixed.** The four comment lines above `:50`
state why the path is pinned: assertion N asks whether a fence emitted digits, `has_digit` (`:701`)
tests the **whole** captured file, and an `mktemp` path like `/var/folders/f2/9vss9brn…` carries
digits — so any fence echoing a path under that root reports a defect against correct code. That was
a measured near-miss false Critical. The entry proposed the remedy without reading the comment
immediately above the line it cited, which is the same not-reading-the-neighbourhood error the entry
itself is about.

The real fix keeps the path **digit-free and** makes it unique, since `$SELF` is only `bash`/`zsh`
(`:42`) and so separates the two CI jobs but not two runs of the same shell:

```bash
WORK="/tmp/fence-isolation-gate-$SELF-$(printf '%s' "$$" | tr '0-9' 'abcdefghij')"   # 91553 -> jbffd
```

**Reopens if:** CI ever runs the shells in parallel, or the fixed path is given to any check that
fails soft instead of loud.

**From:** `2026-08-04-ci-hardening.md` Task 2

```bash
/usr/bin/grep -n '/tmp/fence-isolation-gate-' reference/test/fence-isolation.test.sh   # line 50
```

---
### 17. `session-orient.sh` counts open notes recursively but their total non-recursively — CLOSED

Closed by `fix/post-merge-hardening`: both `OBS_TOTAL` and `TENS_TOTAL` now use
`find -H … -type f -name '*.md'`, which recurses, so the two halves agree.

**This does not close entry 28**, which is about test coverage *of* this fix and remains open —
the two are easily conflated because they name the same variable.

```bash
/usr/bin/grep -n 'OBS_TOTAL=\|TENS_TOTAL=' hooks/scripts/session-orient.sh   # both find -H
```


**Deferral text, merged from `## Open` on 2026-08-26.** The ledger carried this item in both sections at once; the convention is one entry that MOVES, so the original deferral now sits with its closure rather than reading as open work.

#### 17. `session-orient.sh` counts open notes recursively but their total non-recursively — CLOSED

**What:** `hooks/scripts/session-orient.sh:151` counts open items with `count_notes_by_field`, which
recurses; `:154`–`:155` compute `OBS_TOTAL`/`TENS_TOTAL` with `ls -1 ops/observations/*.md`, which
does not. The two are combined in one sentence at `:207` — `"$OBS_COUNT pending observations (of
$OBS_TOTAL total)"` — so a vault with open items under `ops/observations/archive/` can report a count
larger than its own total.

**Why not now:** Consistent today only by accident: no archive subdirectory in the field vault holds
an `open` item. It is a display line that gates nothing — the threshold compares `OBS_COUNT` alone.

**Reopens if:** any vault files an `open` observation or tension in a subdirectory, or `OBS_TOTAL`
ever gains a second consumer that compares against it.

**From:** `2026-08-05-generator-vault-enforcement-gap.md` Task 1

```bash
/usr/bin/grep -n 'count_notes_by_field\|OBS_TOTAL=\|TENS_TOTAL=' hooks/scripts/session-orient.sh
```

---