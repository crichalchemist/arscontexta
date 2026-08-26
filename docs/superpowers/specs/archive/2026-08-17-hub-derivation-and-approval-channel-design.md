# Hub derivation and the approval channel — design

Two defects in `skill-sources/rethink/SKILL.md`, specced together because they are the same
skill acting on the same state, and fixing either alone leaves the other's fix unsound.

- **G2** — `:329` prescribes a stateful edit of a derivable file. Four templates write the
  notes it indexes; one updates it. The field vault's hub has diverged three times, most
  recently within 72 hours of a rebuild.
- **G3** — `:290`/`:292` and `:562` make the run's progress contingent on an interactive
  answer. Where that channel does not exist, the run generates proposals and stalls. Three
  logged runs at `0 approved`.

Field evidence: `docs/field-intel-2026-08-17.md` §A (untracked). Source survey read
`~/second-brain/ops/` read-only on 2026-08-16. Adversarially reviewed 2026-08-17 (2 Critical,
5 Major, 4 Minor); Decisions 5 and 6 were refuted and rewritten. Every finding was
independently re-measured before being applied.

**Terminology.** "Hub" is the field vault's dialect and appears here only when describing that
vault's artifacts. The canonical term is **MOC** (`reference/vocabulary-transforms.md:17`), which
is what `:329` already says and what every new identifier this spec introduces uses. The
distinction is load-bearing for anything that ships: a library's function names are not
vocabulary-substituted.

## What the obvious framing gets wrong

**"The hub lies, so make the writers update it"** is the wrong fix, and it is the fix this
repo's own history predicts will fail. It creates four declarations of one rule — the shape
divergence 3 exists to record, and the shape G1 (the topic-map cap: four declarations, two
numbers) demonstrates in the generator tree today. Four writers that must each remember to
sync is a repair. It will hold until someone adds a fifth writer.

**"Make the hub authoritative and gate it"** is also wrong, for a structural reason rather
than a stylistic one. A gate built in this repo reads *this repo* — divergence 16. There is
no path from a check here to an existing vault's hub. A hub↔frontmatter agreement gate would
be green in CI forever while every field vault drifted.

**What survives:** the hub is not a record. It is a cached aggregate of frontmatter, and
every component of it is derivable — established below, and it is the fact the whole design
rests on. So the defect is not that the cache is stale; it is that the template prescribes
*incremental cache maintenance* when it could prescribe *derivation*. One instruction, and
the machinery is already sourced 165 lines above it
(`:164` sources the library, `:329` is the instruction that ignores it — the first draft said
169, which measures to the `:160` comment rather than to the source line).

That is the nearest available substitute for a gate when a gate cannot arrive: make the
operation idempotent, so that running it *is* the repair, and running it twice is a no-op.
**Idempotence makes the operation convergent; it does nothing to deliver the operation** —
see Migration, which the first draft of this spec got wrong on exactly that distinction.

## Measurements

Taken 2026-08-17. Vault figures drift; re-run rather than quoting.

```bash
# Four templates write observation notes; one touches the hub.
/usr/bin/grep -rln 'observations/' skill-sources/*/SKILL.md      # next, reduce, remember, rethink
/usr/bin/grep -rn  'observations\.md' skill-sources/*/SKILL.md   # rethink:329 ONLY

# rethink already has the derivation machinery, above the instruction that ignores it.
/usr/bin/grep -n 'FM_LIB=\|frontmatter library not found\|list_notes_by_field' \
  skill-sources/rethink/SKILL.md                                 # :164, :168, :189

# The hub's counted-status format is VAULT-AUTHORED. This repo never emitted it.
/usr/bin/grep -rn '## Open (\|## Pending (\|## Implemented (' generators/ skill-sources/
#   rc 1, no hits — the absence IS the measurement, so do not pipe this to wc -l,
#   which converts rc 1 into rc 0 and prints a plausible "0".
/usr/bin/grep -n 'observations\.md\|hub\|MOC' generators/features/self-evolution.md   # rc 1
```

Live drift, and the derivability finding:

```bash
cd ~/second-brain/ops && . lib/frontmatter.sh
/usr/bin/grep -n 'Open (' observations.md                          # 14:## Open (12)
list_notes_by_field observations status open | /usr/bin/grep -c .  # 11 genuinely open
#   set comparison: 3 shared, 9 hub-only, 8 disk-only. Heading agrees with neither side.
count_notes_by_field observations status implemented                # 87, vs heading "(69)"

# Derivability, measured across EVERY section of both hubs — not one sample.
# `description` PRESENCE is total (112/112 observations, 31/31 tensions). Prefix
# AGREEMENT is not, and conflating the two is how the first draft of this spec got it
# wrong: it measured presence on 11 open notes and generalised to the whole hub.
#   observations.md  entries=90  prefix_ok=57  divergent=33   (Open 11/12, Implemented 40/69, Archived 6/9)
#   tensions.md      entries=16  prefix_ok=9   divergent=7    (three singleton sections all diverge)
# Re-derive with the census script; do not re-derive from a single entry.
```

**So the derivability claim is scoped, and the scope is the design.** Membership, the
wiki-link and the counts are **fully** derivable. Summaries are derivable for *new* entries
and **best-effort** for existing ones: 33 of 90 observation entries and 7 of 16 tension
entries are not prefixes of their note's current `description`, because descriptions get
edited after the hub line is written. The divergence is genuine, not a normalisation
artifact — even in the open section, one entry says "the auto-commit hook" where the note now
says "the timer-based auto-commit hook".

**The first draft of this section called total derivability "THE LOAD-BEARING FACT" and the
design rested on it.** It is measured false as stated. The design survives — rule 2 below
preserves a divergent summary rather than overwriting it — but it survives by *not* depending
on the claim, which is a different and weaker thing than the claim being true. This is the
proxy-for-property class `CLAUDE.md`'s own gate table warns about, committed inside a spec
that cites it.

G3's stall, from `rethink-log.md`:

```
:239   "4 generated, 0 approved, 0 implemented — approval gate unreachable from subagent"
:986   "9 generated (P1-P9), 0 approved, 0 rejected — awaiting user approval"
:1061  "8 generated, 0 approved, 0 rejected — this pass had no approval channel"
```

21+ proposals generated across those runs; P3, P5, P7, P8 still outstanding as of the
2026-08-16 pass. **Every drainage that has ever occurred was a later human batch-approval**
(2026-08-11 "user approved backlog… 9 of 10 done"; 2026-08-13 pre-approved before the run).

## Architecture: one derivation, two gates split by reversibility

```
                    frontmatter (authoritative)
                            │
              ┌─────────────┴──────────────┐
              │                            │
      decision surfaces              ops/observations.md
   (session-orient, /next,            ops/tensions.md
    /rethink thresholds)                    │
              │                    DERIVED, carries `derived:`
   already read frontmatter          provenance, gates nothing
   via count_open_items /                   │
   list_notes_by_field                human navigation only
```

**Nothing new reads frontmatter.** The decision surfaces already do — `count_open_items` in
`hooks/scripts/session-orient.sh`, `list_notes_by_field` at `skill-sources/rethink:189`.
This design does not add call sites; it removes the hub's pretence of authority.

### The three components and where each comes from

| Hub component | Derived from | Fully derivable? |
|---|---|---|
| section membership | note `status` | **yes**, verified |
| the `[[wiki-link]]` | filename | **yes**, verified |
| the summary after ` — ` | note `description`, truncated | **no** — 57/90 and 9/16 agree; see Measurements |
| `## Section (N)` count | length of the section just built | **yes**, by construction |

Because the fourth row is computed from the first, the three quantities that disagree today
— heading count, entries listed, notes with that status — collapse into **one** computation.
A heading cannot disagree with its own section.

## The rebuild contract

`reference/lib/moc-sync.sh`, following the `queue-edit.sh` precedent exactly: a
`MOC_SYNC_VERSION` constant, a consumer guard in every calling fence, and a `/health` check
whose floor is derived from the consumers' own guards.

**The names say MOC, not hub, and that is reverse-transform 1 rather than taste.**
`reference/vocabulary-transforms.md:17` gives the canonical term as **MOC** / *topic map*;
"project hub" is one preset's dialect and bare "hub" is the field vault's own word (its
`hub_max_size`). A library ships verbatim into every vault's `ops/lib/` and its function
names are **not** vocabulary-substituted, so `hub-sync.sh` would hardcode one dialect into
every generated system — the failure this repo's own porting rules exist to prevent. The
first draft of this spec named the library `hub-sync.sh` while its own `:329` replacement
text said "**Rebuild MOCs**", so it was already inconsistent with itself.

**Why a library and not prose in the template.** Divergence 5 records what prose contracts
cost: `/arscontexta:upgrade`'s three repairs are prose CI cannot exercise, and they shipped
six defects found only by hand-running them. A library function is directly testable. A
fence is at least covered for self-containment by `fence-isolation.test.sh`. A paragraph is
covered by nothing.

`rebuild_status_moc <moc-file> <notes-dir> <section-map>` must:

1. **Be idempotent.** Two consecutive runs produce byte-identical output. **Entry order
   within a section is fixed by the contract** — ascending by filename — because rule 1 is
   satisfiable by any deterministic order, including "preserve current order and append",
   which would yield different files on different vaults from identical frontmatter. An
   unspecified sort is an idempotence claim that holds per-vault and means nothing across
   vaults.
2. **Preserve a divergent summary and warn, never overwrite.** Where an entry's prose is not
   a prefix of its note's `description`, keep the file's version, emit a warning naming the
   note, and continue. **Content destruction is worse than drift** — the discipline
   `hooks/scripts/write-validate.sh` exists for.
   **The warning must not say "someone hand-edited this."** Measured, that inference is
   wrong for most of the 40 divergent entries: 7 of the 29 divergent `Implemented` entries
   follow a *second derivation convention* — `implemented via <implemented_in target>` —
   and the rest are stale derivations from an edited `description`. The honest wording is
   "summary is not derivable from current frontmatter". See "What is NOT claimed" for the
   noise consequence, which is real and permanent.
3. **Fail loud on an entry it cannot place, and distinguish the three ways that happens.**
   (a) the note no longer exists; (b) the note exists but its `status` is unreadable —
   including the unclosed-frontmatter case, which `reference/lib/frontmatter.sh` reads as
   *no* frontmatter (0 live instances in `observations/` and `tensions/` today, one live
   instance one directory over in `ops/methodology/`); (c) the status is readable but maps
   to no section — rule 6. Each gets its own report. Rule 3's first draft covered only (a),
   whose predicate is "the note is gone", so (b) — a note that exists and silently vanishes
   from every section — passed straight through the rule meant to catch it.
4. **Write via the guarded-rename idiom** already in `reference/lib/queue-edit.sh`: a failed
   rename returns 1, discards its temp, and names the path that could not move. It must not
   end `mv "$tmp" "$file"` with no `||` — the defect `queue-edit.test.sh` was written red to
   pin.
5. **Emit provenance.** A `derived: <ISO-8601>` line plus the re-derivation command, so the
   file states its own staleness. This is this repo's existing idiom for numbers in prose:
   publish the command beside the number so the number cannot be trusted alone.
6. **Never silently omit a note whose status has no section.** An off-map status is either a
   loud per-note report or an auto-appended `Unmapped (N)` section — never absence. **This
   rule exists because three section vocabularies are live simultaneously** and any single
   map drops the others' notes:

   | Vocabulary | Sections |
   |---|---|
   | `:329`'s instruction, six names | Pending / Promoted / Blocked / Archived / Resolved / Dissolved |
   | the field vault's observations hub | Open / Implemented / Archived — its rebuild banner declares these "canonical three" |
   | the field vault's tensions hub | Open / Blocked / Dissolved / Implemented / plus a literal `Non-canonical status: resolved (6) — legacy, unspecified` heading |

   Measured today: **2 dissolved observations** have no section in the observations hub, and
   **14 tensions** (8 `promoted`, 6 `archived`) have no section in the tensions hub — 16
   notes that a rebuild under any one of these maps would silently drop. Silent omission of
   a note that exists is the exact mechanism that produced the 8-disk-only defect this spec
   was written to fix, so shipping it inside the fix would be a self-inflicted recurrence.

   **The section map is therefore an input the spec must pin, not a detail for the
   implementer.** It must cover the note-status enum as reconciled by divergences 7-9 plus
   the tension enum's current eight values, and the two `:329` names that survive nowhere
   in the field (`Pending`, `Resolved`) must be resolved deliberately — the vault renamed
   `Pending` to `Open` and demoted `Resolved` to "non-canonical", and neither change came
   back here.

`:329` then reads, in place of "Move entries between … sections as appropriate":

> **Rebuild MOCs:** After triage execution, rebuild `ops/observations.md` and
> `ops/tensions.md` from frontmatter via `rebuild_status_moc`. The rebuild is idempotent and
> authoritative on membership, links and counts; existing summaries are preserved. Do not
> move entries by hand.

## Migration: two delivery preconditions, and neither is free

**The first draft of this section said "no migration script, no `/upgrade` step" and claimed
the first `/rethink` after the change repairs the vault. That is false, and it is refuted by
Decision 3 — this spec's own library design.** Recording it rather than quietly correcting it,
because the contradiction is instructive: idempotence was doing double duty as both the
*convergence* argument and, wrongly, as the *delivery* argument.

Templates source the **vault-local** copy, not `reference/lib/`, behind a fail-loud guard that
names its own remedy:

```bash
/usr/bin/sed -n '164,171p' skill-sources/rethink/SKILL.md
#   FM_LIB="ops/lib/frontmatter.sh"    … else
#     echo "error: frontmatter library not found at '$FM_LIB'" >&2
#     echo "       run /arscontexta:upgrade to restore it"     >&2
#     exit 1
ls ~/second-brain/ops/lib/     # frontmatter, graph*, link-extraction, queue-edit, queue_edit.py
#   no moc-sync.sh, and nothing in this design delivers one
```

So on an existing vault the first `/rethink` after this change does not repair anything — it
**exits 1** and tells the user to run `/upgrade`. Two deliveries must both land before
convergence can even begin:

1. **The changed template must reach `.claude/skills/rethink/SKILL.md`** — regeneration or
   `/plugin` upgrade. Note divergence 5's cost here: that path regenerates skills
   destructively, and the field vault reports `locally_modified: all-16`.
2. **`ops/lib/moc-sync.sh` must be installed** — `/upgrade` step 5e refreshes vault
   libraries, and divergence 5 records that it has no recorded slash-command invocation
   against a real vault.

**What survives, precisely:** the rebuild needs no *migration script*, because the operation
is convergent — once it can run, running it is the repair, and there is no separate one-shot
to write. That is a real and useful property. It is not a delivery mechanism, and this spec
does not build one. Divergence 16 stands entirely unchanged.

## The approval channel

### The split is by act, not by phase — the first draft drew it at the phase boundary and was wrong

**The first draft's table said triage "moves an item between pending / promoted / blocked",
called that reversible, and un-gated the whole phase. Measured, that is false and it would
have shipped the defect `:704` exists to prevent.** What `:292` actually gates is step `1d`,
and `1d` does far more than move statuses:

```bash
/usr/bin/sed -n '293,318p' skill-sources/rethink/SKILL.md
#   ### 1d. Execute Triage — "After user confirmation, apply all dispositions in order:"
#   For PROMOTE items:   1. Create {DOMAIN:note} … in {vocabulary.notes}/
#   For IMPLEMENT items: 1. Make the specific change identified, in file/section
#                        2. Show the change to the user (before/after) and get confirmation
#                           if the change is non-trivial
```

Three consequences, each fatal to a phase-level split:

1. **IMPLEMENT executes system changes inside triage**, not in the proposals phase. Un-gating
   triage therefore auto-implements — exactly what `:704` forbids, in a design that preserves
   `:704` verbatim. The spec would have contradicted itself in two adjacent decisions.
2. **PROMOTE creates knowledge-base notes** in `{vocabulary.notes}/`. That is user content, not
   bookkeeping, and it is not reversible by flipping a field back.
3. **IMPLEMENT step 2 is a second interactive gate the first draft never noticed** — "get
   confirmation if the change is non-trivial" stalls in a subagent by the identical mechanism
   as `:290` and `:562`. So even the original G3 fix would not have made triage completable
   without a channel. The finding is not just that the split was misplaced; it is that the
   inventory of blocking gates was incomplete.

**The corrected split is by act:**

| Act | Example in `1d` | Proceeds without a channel? |
|---|---|---|
| frontmatter status-field edit | `status: archived`, `status: pending` | **yes**, recorded and reversible |
| note creation | PROMOTE step 1 | **no** — route to the persisted artifact |
| file/section modification | IMPLEMENT step 1 | **no** — route to the persisted artifact |
| methodology elevation | METHODOLOGY items → Phase 2 | **no** — route to the persisted artifact |

So a channel-less run performs the status edits, and every side effect — note creation, file
modification, methodology elevation — lands in the same persisted artifact as proposals and is
explicitly re-gated. `:704` holds without exception, and `1d` gains **one** blocking gate to
remove rather than two to reason about separately.

**One thing this exposes that predates the spec:** `1d`'s PROMOTE and IMPLEMENT branches are
already system changes executed behind a *triage* approval rather than a *proposal* approval,
so a user who approves a triage table has approved file modifications they were shown as
status dispositions. That is a live ambiguity in the template, not something introduced here,
and the corrected split resolves it as a side effect rather than by targeting it.

### Proposals terminate in an artifact, not a question

The proposal phase writes each proposal to a durable store with `status: awaiting_approval`,
prints the count and the resume command, and **exits successfully.** Approval is a separate
invocation.

**This is better than the current design even where the channel exists**, which is the
argument for it — not merely that it unblocks subagents:

- It survives context exhaustion mid-run. The field vault's `/rethink` runs are long and its
  `/next` subagents already die to autocompact thrashing.
- It removes the structural difference between subagent and interactive execution, so the
  skill has one behaviour instead of two.
- **It makes the workflow humans actually perform the supported path.** Every drainage in
  the vault's history was a later batch-approval. The current design treats that as
  degradation and interactive approval as normal; the evidence says the reverse. The design
  should follow the observed behaviour.

**The store is `ops/rethink/pending.yaml` — a dedicated file, deliberately NOT the operational
queue.** The first draft said only "persist via `queue_yaml`", which names a *writer* and not a
*destination*; `queue_yaml` takes an arbitrary file argument (`queue_yaml FILE --where k=v
--set f=v`, `reference/lib/queue-edit.sh:125`), so that sentence left the spec's central new
artifact unspecified. Three things must be pinned, and are:

| | |
|---|---|
| **file** | `ops/rethink/pending.yaml` — beside the existing `ops/rethink/` triage and decision documents |
| **status vocabulary** | `awaiting_approval` → `approved` \| `rejected` \| `deferred`, mirroring `:630`'s four report counts so the artifact and the report share one vocabulary |
| **consumer** | the approval invocation, and nothing else — no other surface reads it |

**Why not the operational queue.** Proposals would enter the store `/next` drains. `/next`'s
fences filter `--where status=pending`, so `awaiting_approval` items would *probably* be
skipped — and "probably" is the problem. No queue schema declares `awaiting_approval`, and a
status no consumer declares is precisely the unfalsifiable-state class the template itself
legislates against at `:311`. Sharing a file to reuse a writer would trade a named artifact for
an unnamed state in a file four other skills already act on.

Persist via `queue_yaml` from `reference/lib/queue-edit.sh` (v2), under its existing consumer
guard `[ "$QUEUE_EDIT_VERSION" -lt 2 ]` — the idiom seven fences across five templates
already use. **No new writer.** Re-derive the version rather than trusting this sentence:

```bash
/usr/bin/grep -n 'QUEUE_EDIT_VERSION=' reference/lib/queue-edit.sh
/usr/bin/grep -rc '\-lt 2 \]' skill-sources/ | /usr/bin/grep -v ':0'
```

### The design does not branch on availability — but not because absence is undetectable

**The first draft claimed availability is "not detectable" and that "attempt the ask, if it
fails do X" is unimplementable. That premise is refuted by evidence quoted in this same spec.**
`rethink-log.md:239` — *"approval gate unreachable from subagent"* — was written **by the
executing agent during the stalled run**. The agent detected the absence and recorded it. The
narrow bash claim is true and irrelevant: the skill is prose executed by an agent that knows
its own tool list, so detection has already effectively happened; only the fallback was missing.

The defensible statement, which is what this design rests on: **absence is detectable only by
agent-level introspection, which is not a contract this repo can gate or test.** A template
instruction contingent on an agent correctly introspecting its tool list would be exactly the
kind of prose contract divergence 5 records the cost of — unexercisable by CI, verified only by
hand-running.

So the design does not branch on availability, and Decision 7 stands on its three independent
grounds — surviving context exhaustion, one behaviour across both execution modes, and
supporting the batch workflow the field actually performs. **None of those depend on the
undetectability claim**, which is why removing the false premise costs the design nothing. It
is recorded rather than deleted so that a reviewer of the eventual plan does not inherit it.

### What must not change

`:630`'s report format (`[count] generated, [count] approved, [count] rejected,
[count] deferred`) stays exactly as it is. It is the surface that made this defect visible at
all — three log lines reading `0 approved` are why there is a finding to spec. A report
format that only printed successes would have hidden it.

## Gates

**This spec adds a check, and that has an unavoidable cost that must land atomically.**

`reference/test/moc-sync.test.sh` becomes the 18th executable check and adds 2 CI steps
(bash and zsh). `check-doc-claims.sh` reads the declared numerals in `CLAUDE.md` — "seventeen
executable checks", the 30-step count, and the `main` comparison — and **goes red the moment
the tree and the document disagree.** The same commit that adds the suite must update every
declared numeral, re-derived rather than incremented:

```bash
ls reference/check-*.sh reference/test/*.test.sh reference/validate-kernel.sh | wc -l
grep -c '^      - ' .github/workflows/checks.yml
git show main:.github/workflows/checks.yml | grep -c '^      - '
```

**"Atomically" covers the tree-side numerals only — the `main`-side one cannot be green on both
sides of the merge, and an executor who does not know that will chase an impossible green.**
The third command reads another branch. Pre-merge, `main` genuinely carries 30, so writing 32
reddens the branch; post-merge `main` carries 32, so leaving 30 reddens `main`. There is no
value correct in both states. `CLAUDE.md` documents this same numeral being corrected **three
times** for exactly this reason, and states the general rule: a claim about `main` rots on
MERGE, not on edit, with no diff to notice. The suite-adding commit updates the tree-side
numerals; the `main`-side numeral takes the documented post-merge correction. Say so in the
plan, or the step gets retried as if it were failing.

Adding fences to `skill-sources/rethink/SKILL.md` also moves `fence-isolation.test.sh`'s
extracted/run/skipped counts, which `CLAUDE.md` states in prose. Re-derive all three and read
them as three numbers, not one:

```bash
bash reference/test/fence-isolation.test.sh 2>&1 | grep -m1 -oE 'files=[0-9]+|run=[0-9]+|skipped=[0-9]+'
```

**Do not add a gate that asserts the hub agrees with frontmatter.** It would read this repo,
where there is no vault, and be green forever. That is the proxy-for-property failure this
repo's gate set already warns about — a green result asserting nothing while looking like
assurance.

## Testing

`moc-sync.test.sh`, under both shells, against a fixture vault:

| Assertion | Catches |
|---|---|
| two consecutive rebuilds are byte-identical | non-idempotence — the property convergence depends on |
| two fixtures with identical frontmatter but different existing entry order produce identical output | an "idempotent" implementation that preserves current order, so idempotence holds per-vault and means nothing across vaults |
| a note whose `status` maps to no section is reported, never omitted | rule 6 — the 16 live off-map notes, and the silent-omission mechanism this spec exists to remove |
| a note that exists but whose frontmatter is unclosed is reported, not vanished | rule 3(b) — the case the first draft's predicate ("the note no longer exists") could not see |
| a divergent summary survives a rebuild byte-identical | rule 2 regressing into overwrite, which would destroy ~40 entries' prose |
| a note whose `status` changed outside the run lands in the right section | the exact field defect: 9 hub-only, 8 disk-only |
| `## Section (N)` equals the entries beneath it, for every section | the heading that agrees with neither side |
| a hand-edited summary is preserved and warned about | content destruction dressed as a refresh |
| a hub line whose note is gone is reported, not deleted | silent deletion |
| a failed commit-step rename returns 1, discards its temp, names the path | the unguarded-`mv` defect, verbatim from `queue-edit.test.sh` |
| a rebuild on a vault that renamed `ops/` resolves the directory | the `resolve_ops_dir` class — a validator scanning names a vault changed |

The rename failure is forced with a shell-function stub, as `queue-edit.test.sh` does: a
genuine same-directory `mv` failure needs `chflags uchg` and is not portable to CI. **The
mechanism is covered; the organic trigger is hand-run only, and that is not the same claim.**

For G3, the testable surface is narrow and should be stated as such: that the proposal phase
**writes its artifact and exits 0** is assertable in a fence test. That an agent then resumes
correctly from that artifact is prose CI cannot exercise — the same gap divergence 5 records
for `/upgrade`'s three repairs. Hand-run it against an `rsync -a` copy of the field vault, as
that work did; that method found six defects.

## What is NOT claimed

- **Not that existing vaults are fixed, and not that they self-repair on next run.** Both
  delivery preconditions in Migration must land first; until they do, the first `/rethink`
  exits 1 rather than repairing. Divergence 16 is unchanged.
- **Not that the MOC becomes fully derived.** It becomes *partly derived and dated*.
  Membership, links and counts are derived; **roughly 40 existing summaries (33 observations
  + 7 tensions) are permanently frozen as non-derived content** under a `derived:` stamp, and
  each one warns on every run, forever. That is the price of rule 2 and it is not small: a
  warning that always fires is a warning nobody reads, which is the mechanism that let
  `logs/maintenance.log` accumulate 15 silent failures. **Backfilling those summaries — or
  adopting the `implemented via <target>` convention 7 entries already use — is the obvious
  follow-on and is deliberately not specced here.**
- **Not that anything gating a decision may read it.** Those surfaces read frontmatter, exactly
  as they do today.
- **Not that a re-sync mechanism exists.** Designing one is divergence 16's own spec.
- **Not that `AskUserQuestion` availability can be detected.** The design deliberately does
  not depend on it.
- **Not that the agent-level prose is verified.** That `/rethink` performs the rebuild when
  asked, and resumes correctly from a persisted proposal set, rests on review. No gate here
  reaches it.
- **Not G1, G4 or G5.** The topic-map rule's two numbers, `session-orient.sh`'s label, and
  the un-consumed-enum gate are out of scope. G5 belongs to the CI-hardening spec.
- **Not a claim about `promoted_to:`.** `C1`'s FAIL (7 of 8 archived `promoted` tensions name
  no target) is real and adjacent, but it is a content defect in one vault, not a defect in
  what this repo emits.

## The surface this does not build

A hub that regenerates on read. It is the more elegant design — a file that cannot be stale
because it is never stored — and it is rejected for one reason: `## Open (N)` is
**vault-authored**, measured above. This repo has never emitted a counted status hub, and
teaching the generator to emit one is a new feature block, not a fix to an existing
instruction. That is a larger change than the defect warrants and it would put this spec in
the business of specifying a file format the field has already settled.

## Decisions taken, 2026-08-17

Revised after adversarial review, 2026-08-17. Decisions 5 and 6 were **refuted and rewritten**;
1, 3, 4, 8 and 10 were amended. Both original defects are recorded in place rather than
overwritten, per this repo's convention of keeping drift visible.

1. **The MOC is partly derived, not recorded.** Membership, links and counts are derived; it
   carries `derived:` provenance; it gates nothing. Summaries are best-effort — see Measurements.
2. **`:329` becomes a rebuild, not a move.** Idempotence replaces incremental maintenance.
3. **The rebuild is a library function** — `reference/lib/moc-sync.sh`, `MOC_SYNC_VERSION`,
   consumer guards, `/health` check — following `queue-edit.sh`, not prose. **Named MOC, not
   hub:** library function names are not vocabulary-substituted, so "hub" would ship one
   dialect into every vault.
4. **A divergent summary is preserved and warned about,** never overwritten — but the warning
   says "not derivable from current frontmatter", **not** "someone hand-edited this", which is
   measurably wrong for most of the 40 divergent entries.
5. **No migration *script* — but two delivery preconditions, both named.** Convergence is a
   property of the operation and delivers nothing on its own. *(Rewritten: the original read
   "No migration. Convergence delivers the repair," which its own Decision 3 refutes — the
   first `/rethink` on an existing vault exits 1.)*
6. **The gates split by ACT, not by phase.** Frontmatter status edits proceed without a
   channel; note creation, file modification and methodology elevation route to the persisted
   artifact and are re-gated. `:704` is preserved verbatim and now actually holds. *(Rewritten:
   the original split by phase and would have un-gated `1d`'s IMPLEMENT and PROMOTE branches,
   auto-implementing system changes in the same spec that preserves `:704`.)*
7. **The proposal phase terminates in an artifact and exits 0.** Approval is a separate
   invocation, making the batch workflow the field already uses the supported path.
8. **The store is `ops/rethink/pending.yaml`,** with a declared status vocabulary and exactly
   one consumer — written through `queue_yaml` under the existing version guard. Deliberately
   not the operational queue.
9. **The declared numerals in `CLAUDE.md` are updated in the same commit as the new suite,**
   re-derived rather than incremented — tree-side only. The `main`-side numeral takes the
   documented post-merge correction; no value is green on both sides of a merge.
10. **No MOC↔frontmatter agreement gate in this repo.** It cannot reach a vault and would
    assert nothing. The substitute is rule 6's loud report at run time, inside the vault.
11. **The section map is a pinned input, not an implementer's choice** — three vocabularies are
    live today and any single map silently drops 16 existing notes.
12. **Entry order within a section is ascending by filename,** so idempotence means the same
    thing across vaults rather than only within one.
