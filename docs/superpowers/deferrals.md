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

**From:** same two documents. Note CLAUDE.md's divergence-12 table still cites `:410`;
the true line is `:425`.

### 3. `skill-sources/next:261` — the odd `LINK_LIB` spelling

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

### 5. The 681 statusless field-vault notes

**What:** `/reduce` will stamp `status` on new notes; 681 existing notes predate the
stamp and violate the vault's own `required` schema (`insight-node.md:5-11`).

**Why not:** the stamp is forward-only. Backfilling needs a rule for what status a
pre-existing note should receive, and no such rule exists — inferring one from age or
link count would assert a quality claim nothing checked.

**Reopens if:** a promotion criterion is agreed that does not require reading the note.

**From:** `2026-08-08-corpus-wide-passes-design.md`

### 6. The `~150` vs `200` description-length disagreement

**What:** two sites say `~150` (`generators/features/schema.md:18`,
`skill-sources/reduce/SKILL.md:473`), three say `200`.

**Why not:** found while counting period declarations; reconciling a length constraint
is a separate decision from a period. **The count is "at least" — a term-keyed survey
cannot enumerate sites that omit the term.**

**Reopens if:** anyone edits the description schema for any reason.

**From:** `2026-08-08-corpus-wide-passes-design.md`

### 7. Off-enum vault statuses — two different questions

**What:** the field vault carries `closed` (11), `investigating` (1) — in **neither** the
canonical enum nor its own template enum, so genuine violations. And `superseded` (3) —
in the vault's enum, absent from canonical, so a **dialect gap** like `draft`.

**Why not:** reconciling the generator with one vault's practice is a separate decision
with a different owner. Precedent: the divergences 7–9 closure made the same call.

**Reopens if:** the canonical status enum is revisited for any reason.

**From:** `2026-08-08-corpus-wide-passes-design.md`

### 8. `open`'s semantics

**What:** the canonical enum declares `preliminary | open | active | archived`. Nothing
anywhere defines what `open` means or what transitions into or out of it.

**Why not:** specifying it would be shipping a guessed state machine.

**Reopens if:** a vault or a skill needs the state, or it is retired from the enum.

**From:** `2026-08-08-corpus-wide-passes-design.md`

### 9. `check-prose-paths.sh` scope excludes two files that name repo paths

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

### 12. The `generators/` status enum declarations are not placeholder-bearing

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

**From:** `2026-08-08-note-convention-and-lifecycle.md` self-review

```bash
/usr/bin/grep -rn 'preliminary' generators/          # 4 declarations
/usr/bin/grep -rl 'preliminary' generators/ | wc -l  # 3 files -- NOT the same number
```

### 13. Conflation in orphan-count computation on SessionStart

**What:** `platforms/claude-code/hooks/session-orient.sh.template:183` uses `grep -c .
|| true` to count lines piped from `comm -23`. This command has two distinct non-zero-exit causes: (1) zero matches (healthy, ORPHAN_COUNT should be 0) and (2) upstream failure (broken computation, signal should omit). The `|| true` collapses both to ORPHAN_COUNT=0, which contradicts the block's own comment at :154–159 that states: "NEVER substitute 0 … a fabricated 0 would silently suppress the signal forever … Same rule for a computation failure, not only a missing/stale library."

**Why not now:** The `|| true` was added because the earlier false-positive "scan failed" warning fired on every healthy SessionStart (when `grep -c .` exits 1 on empty input), training users to ignore the signal. A query-breaking `comm` failure is unreachable under normal conditions — sort, awk, grep, mktemp, and the library all work correctly in healthy cases. The trade moved from "false positive on 100% of healthy starts" to "silent 0 on rare failure". It is not a clean win; it is a trade, which is why it is recorded rather than left to rot in memory.

**Reopens if:** A second failure mode surfaces that can empty `$tgts` or `$idx` without tripping an earlier guard (the `[ -n "$idx" ]` and `[ -d "$NOTES_DIR" ]` checks at :165, :162). Such a mode would make the conflation reachable and remedy 1 required.

**From:** `2026-08-08-link-edge-map.md` final whole-branch review

```bash
/usr/bin/grep -n 'grep -c \. \|\| true' platforms/claude-code/hooks/session-orient.sh.template  # line 183
/usr/bin/grep -n 'grep -c \. \|\| true' skill-sources/graph/SKILL.md                          # line 174
/usr/bin/grep -n 'grep -c \. \|\| true' skill-sources/stats/SKILL.md                          # lines 225, 282
/usr/bin/grep -n 'NEVER substitute 0' platforms/claude-code/hooks/session-orient.sh.template  # line 155
```

---

### 14. `fence-isolation.test.sh` uses a fixed temp path, so two concurrent runs clobber each other

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

### 16. `read_config.sh` — two asymmetries between the bare-key and dotted-key paths

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

---

### 17. `session-orient.sh` counts open notes recursively but their total non-recursively

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

### 19. `check-portability.sh` check 6 — substring matching and a whitespace-split allowlist — CLOSED

Closed by `cbcd48f` (Task 13, `fix/post-merge-hardening`): the hit count is now anchored and the
allowlist `|`-delimited, born-red and mutation-proved in `guard-failure.test.sh` (60/60 → 66/66,
both shells). The full entry moved to [Closed](#closed) per this file's own convention — **with a
drift record**, because the closure measured the entry's central claim false: it asserted the
substring match "fails in the safe direction by construction — a false FAIL, never a false PASS",
and the measured failure is a false PASS (a hit line naming a deleted allowlisted path masked the
GONE arm). Kept numbered here so references by number stay valid.

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
/usr/bin/grep -n 'queue.yaml' reference/test/fence-isolation.test.sh | head -3   # fixture creates it
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

**What:** CLAUDE.md states the gate's SCOPE count in prose (`:782`, "across 11 documents") and
republishes it inside its own bash re-derive block (`:805-806`). Neither numeral is checked by any
gate — `check-doc-claims.sh` reads other sentences in this file for other quantities (the
executable-checks count, the CI-step count) and never mentions `check-prose-paths.sh` at all, so a
gate that reads one phrasing does not protect a synonym, per this file's own opening paragraph on
that exact subject. Task 14 (`fix/post-merge-hardening`) widened SCOPE from 9 to 11 and had to
hand-correct the prose at three sites in one paragraph to keep up; the next widening faces the
identical risk with nothing to catch it.

**Why not now:** wiring this count into `check-doc-claims.sh` is a change to that gate's own
claim-registration mechanism, not to `check-prose-paths.sh`, and is out of Task 14's stated scope
(widen SCOPE by two named files). `check-doc-claims.sh`'s design is itself a CI-hardening-spec
question, per the gate-table row near the top of CLAUDE.md ("Building the missing check is a
gate-design question and belongs to the CI-hardening spec").

**Reopens if:** `check-prose-paths.sh`'s SCOPE list changes size again without CLAUDE.md's stated
count moving with it, found by drift rather than by a gate. Or: `check-doc-claims.sh` gains a
mechanism generic enough to register an arbitrary computed-count-vs-prose-numeral pair without a
bespoke assertion, at which point this pair should be its first user.

**From:** Task 14 (`.superpowers/sdd/2026-08-09-post-merge-hardening/task-14-report.md`),
`fix/post-merge-hardening`

```bash
awk '/^SCOPE="/{f=1;next} /^"/{f=0} f&&NF' reference/check-prose-paths.sh | /usr/bin/grep -c .   # 11, the live count
/usr/bin/grep -c 'across 11 documents' CLAUDE.md                                                 # 1, the prose claim
/usr/bin/grep -c 'check-prose-paths' reference/check-doc-claims.sh                                # 0: gate never reads this file's name
```

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
