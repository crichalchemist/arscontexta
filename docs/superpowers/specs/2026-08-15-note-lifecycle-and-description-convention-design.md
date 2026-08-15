# Note lifecycle and description convention — design

**Supersedes items 1 and 3 of `2026-08-08-corpus-wide-passes-design.md`.** Item 2
(`link-extraction.sh` v2 → v3) is independent and unaffected; its plan is already archived.

The plan built on the superseded design —
`docs/superpowers/plans/2026-08-08-note-convention-and-lifecycle.md` — **must not be executed.**
It is retained for reference only. Its Task 5 would have rewritten 1776 vault files without their
quotes and produced invalid YAML on the 473 carrying a colon.

---

## What the prior design got wrong, and what survived

Recording this rather than silently replacing it, because the failure is instructive and the
correction is the reason this spec exists.

**The central figure was a measurement artifact.** The prior design and its plan stated
`1621 bare / 12 quoted` descriptions and treated it as a bare-versus-quoted census. It was a
**trailing-period census taken through `frontmatter_field`, which strips balanced quotes** — so
every quoted value appeared bare to it. The arithmetic is exact:

```
1621  =  1613 quoted-with-period  +  8 bare-with-period      (at the 2026-08-08 tree)
1784  =  1776 quoted-with-period  +  8 bare-with-period      (today)
```

The constant `8` across both censuses is the tell. It was read as the residue of a job nearly
finished; it is a subset that was always small. **The corpus never changed shape** — descriptions
have been written quoted at note creation since the April 2026 ingestion, 2588 of 2686 already
quoted before 2026-08-07. The target grew from 1621 to 1784 via 187 notes born quoted on
2026-08-14, not via any rewrite.

**What survived re-measurement, intact:** the lifecycle genuinely had no entry state. No skill
writes a note's `status`; `generators/features/templates.md:27` declares it `optional`;
canonically generated notes are born statusless. The `status: active` writes that exist in the
tree are methodology notes — a different field sharing a name. Item 3's core reasoning is adopted
here unchanged.

**Item 1 enforces an existing constraint; it does not introduce one.** `no trailing period` is
already declared canonically at three sites — `generators/features/templates.md:32`,
`generators/features/schema.md:26`, `generators/features/schema.md:144`. Nothing applies it at
write time, which is the entire gap. The convention has been canon and unenforced.

**What did not survive:** the plan's normalizer (mechanism, below) and its promotion gate, which
tested `$VERIFY_FAIL_COUNT` — a variable that exists nowhere in `verify`. Fences are separate
shell invocations, so it expanded empty and promotion silently never fired.

---

## Measurements

Every figure re-derived on `main` @ `8f33fce`, 2026-08-15. Re-derive before acting; the vault is
live and the note-creation pipeline is still running.

**Descriptions** (2874 notes under the vault's notes directory):

| | count |
|---|---|
| quoted, with trailing period | 1776 |
| bare, with trailing period | 8 |
| **total carrying a trailing period** | **1784** |
| quoted, no trailing period | 1000 |
| bare, no trailing period | 90 |
| of the quoted, carrying a colon inside the value | 473 |

**Statuses** — the seven-value distribution sums exactly, which is how it was checked:

```
active 1386 · draft 760 · verified 11 · closed 11 · superseded 4
valid 1 · open 1 · investigating 1 · evergreen 1        = 2176
2176 + 698 statusless = 2874                             ✓
```

`draft` is **not** a violation under this design — see *The lifecycle*. The canonical enum is
declared four times in `generators/` — `generators/features/atomic-notes.md:94`,
`generators/features/schema.md:30`, `generators/features/schema.md:142`,
`generators/features/templates.md:30` — and validated once at
`skill-sources/validate/SKILL.md:123`, **at WARN**, which is worth noting: nothing today *fails*
on an off-enum status, which is how seven values accumulated.

---

## Architecture: three surfaces

| surface | owns | lifetime |
|---|---|---|
| **templates** — `skill-sources/reduce/`, `skill-sources/verify/` | prevention: stamp at creation, promote on a gate | permanent, ships to every vault |
| **vocabulary keys** — `generators/` | four flat `status_*` keys, so lifecycle states are derivable when a vault renames them | permanent, generation surface |
| **migration script** — `reference/`, unshipped | clearing this vault's backlog | **one-time; deleted after it runs** |

The load-bearing claim: **the backlog is a migration artifact of one vault, not a recurring
condition.** Once `/reduce` stamps and strips at creation, no future vault accumulates one. That
is what makes the migration disposable rather than a shipped `/normalize` command, and it is why
this design does not inherit the generator→vault reach gap — nothing new needs to reach an
existing vault. That gap is Sprint B's subject and is explicitly out of scope here.

---

## The frontmatter-write contract

**Edit the line; never rebuild the value.** The prior normalizer read a value through
`frontmatter_field`, transformed it, and wrote it back. That loop cannot preserve quoting,
because the accessor strips quotes before the transform sees them — the write has no way to know
what was there.

- **Selection** goes through `reference/lib/frontmatter.sh`, **unchanged and still read-only**.
  It answers *which notes need work*. This also satisfies `check-portability.sh` check 7, which
  forbids hand-rolled `'^field:'` selection.
- **Mutation** goes through one shared script, which operates on the **raw line**: it locates the
  target line by position within the frontmatter block, transforms only the value's interior, and
  writes the line back with its original delimiters untouched. A quoted value stays quoted; a bare
  value stays bare. The script never asks *what is this value* — only *what does this line look
  like, and what changes inside it.*

`FRONTMATTER_VERSION` does **not** move. The library gains no write API; that was considered and
rejected in favour of a single mutation owner, so consumers' version guards and `/health`
Category 9's floors are untouched.

**Refuses loudly** — this repo's failure class is silence — on: absent frontmatter; an unclosed
block (which `frontmatter.sh` already treats as no-frontmatter, and the two **must** agree); an
unrecognised line shape; a description that would become empty; and any post-edit line that fails
to re-parse. Dry-run is the default; `--apply` is explicit. The write is temp-file plus a
**guarded** rename — the `queue-edit.sh` lesson, where an unguarded `mv` returned the exit status
of the following `rm -rf` and reported success on failure.

---

## The lifecycle

**Entry.** `/reduce` stamps every note it creates with `{vocabulary.status_preliminary}` — a
**vocabulary placeholder, not a literal.** **Five** flat `status_*` keys join the generator's
vocabulary surface, one per enum value: `status_preliminary`, `status_open`, `status_active`,
`status_archived`, `status_superseded`.

**Five, not four** — a correction to this spec's own first revision, which carried "four" from the
superseded design's four-value enum and did not update it when adopting `superseded` in the same
document. **Every enum value gets a key, including the three no skill writes today.** A vault that
renames its lifecycle vocabulary must be able to rename all of it; keys only for the values
`/reduce` and `/verify` happen to write would let a vault rename half its enum and leave the rest
in the generator's dialect — the partial-vocabulary defect this placeholder family exists to
prevent.

This is what makes the vault's 760 `draft` notes legitimate rather than violations: they are this
vault's rendering of `preliminary`, and the key mechanism is precisely what expresses that. A
literal would ship a `/verify` that promotes a value the vault never writes.

**Promotion.** `/verify` moves `preliminary → active` on the **mechanically checkable subset
only**: required-fields presence, topics format, and link resolution — all computable within a
single fence, so nothing crosses a shell boundary. RECITE's prediction score and description
quality are reported and **do not gate**.

Promotion then asserts exactly what was proven. `/verify`'s `Overall:` verdict is a line in an
agent-composed report, not a computed value; gating on it would be a prose contract nothing can
verify, which is how the prior gate came to never fire.

**The enum** gains `superseded` and nothing else, becoming
`preliminary | open | active | archived | superseded`.

**Twenty-five vault notes are corrected**, per the mapping:

| from | count | to |
|---|---|---|
| `closed` | 11 | `archived` |
| `verified` | 11 | `active` |
| `valid` | 1 | `active` |
| `evergreen` | 1 | `active` |
| `investigating` | 1 | `open` |

**The two meanings of `active`, and how they stay separable.** After migration, `active` means
"passed the gate" for promoted notes and "existed on 2026-08-15" for the 698 backfilled ones.

No marker field is added. The distinction is already recoverable and free: every backfilled note
is exactly a note that had no `status` before the migration commit, and **the migration commit is
the marker** — one SHA, one date, answerable by `git log`, permanently. A synthetic
`status_source:` field would be 698 writes to record what history already records.

Stated plainly, because it is the design's weakest assertion: **`active` on a backfilled note
asserts existence and reachability, nothing about quality.**

---

## The migration

Three passes, **one commit**, then deleted.

| pass | targets |
|---|---|
| strip one trailing period from `description` | 1784 |
| stamp `status` on statusless notes | 698 |
| map off-enum statuses per the table above | 25 |

**Idempotent** — a second run changes nothing, which is what makes a partial run recoverable
rather than a puzzle. **Dry-run by default.** It runs first against an `rsync` copy, and against
the live vault only once that copy's diff has been reviewed — the pattern the `/upgrade`
hand-execution used, which found six defects.

It strips **exactly one** trailing period: not ellipses, not other punctuation.

**One commit is deliberate**, not incidental: that commit is the marker the lifecycle section
relies on. The vault's auto-commit hook firing here is the desired behaviour.

**Then the script and its suite are deleted.** The implementation plan's final task is their
removal. A migration tool left in `reference/` becomes a permanent artifact with a version, a
gate, and a maintainer, for a job that ran once in one place.

---

## Testing

**The throwaway script gets the most tests, and that is not a contradiction.** It is disposable
in lifetime, not in risk: it edits roughly 2507 files in a live 2874-note vault, once.

Fixtures, each **born red**, both shells, every mutation asserted to have applied before its
result is read:

- **quoted value containing a colon, with trailing period** — the 473-note case, the one the prior
  normalizer broke. Period stripped, quotes intact, re-parses as YAML.
- quoted without a colon → quotes preserved · bare → stays bare · ellipsis → untouched
- description that would become empty → refused
- unclosed frontmatter → refused, **the same way** `frontmatter.sh` treats it
- statusless → stamped · already-stamped → untouched

**The strongest assertion is idempotency:** run twice, the second run's diff is byte-empty. It
catches a class the per-fixture tests cannot, including partial-run recovery.

**Gates this work moves** — re-derive each, do not assume: `check-vocabulary-schema.sh` (the four
new `status_*` keys must be *declared*, or it exits 1) · `check-placeholder-count.sh` (new
placeholders must survive into templates) · `fence-isolation.test.sh` (changed fences in `reduce`
and `verify` must still run standalone; both files also carry queue fences from the
post-merge-hardening merge, so extraction counts shift) · `check-portability.sh` check 7 ·
`check-doc-claims.sh` for any declared number.

---

## What is NOT claimed

- **Nothing verifies that an agent complies with template prose.** `/reduce` stamping and
  `/verify` promoting are agent behaviours described in templates. The fence gate proves the
  fences execute standalone; nothing proves the instruction is followed. This is the class
  divergence 5 documents, and it is why the promotion gate is mechanical — a shell-computable
  condition is at least checkable in principle.
- **`active` on a backfilled note carries no quality claim.** See above.
- **The vault's 760 `draft` notes are not migrated.** They are `preliminary` under this vault's
  vocabulary once the keys exist. No note text changes.
- **`verified` is not adopted**, so `/verify` has no distinct state expressing "passed
  verification"; that meaning rides on `active`. Decided deliberately — see below.
- **The generator→vault reach mechanism is out of scope.** New rules here reach new vaults; the
  existing vault is served by the one-time migration, not by a standing mechanism.
- **Off-enum discovery was term-keyed and is "at least."** Seven values were found where a prior
  survey found three. A survey keyed on known values cannot enumerate values nobody thought of.

---

## Decisions taken, 2026-08-15

Recorded with their reasoning, including where a ruling overrode a recommendation or was made
against information that later changed.

1. **Scope: items 1 and 3 as one design.** They edit the same two templates, both change what a
   new note looks like, both touch the vault's templates. The prior plan fused them for this
   reason and separate specs would collide on every shared file.
2. **Write capability: one shared mutation owner**, not a library write API and not per-writer
   edits. The library stays read-only and unversioned-bumped.
3. **Promotion gate: mechanical subset only.**
4. **Backfill: all 698 statusless notes become `active`, stated honestly.** The originally chosen
   rule — MOC-referenced → `active`, orphan → `preliminary` — was **measured and found to have
   zero discriminating power**: all 698 statusless notes are hub-referenced, because the vault's
   206 `graph-hub` notes reference all 2874 notes. Hub membership is machine-generated
   (`add_links.py`, `auto_research/`) and carries no human signal. The rule was not wrong in
   principle; this vault's structure defeats it.
5. **Description length: `200` is canonical.** Ruled on the understanding that 200 held a 3–2
   majority. **Re-measured during spec self-review, it is 3–3** — deferrals entry 6 missed a third
   `~150` site at `skill-sources/reduce/SKILL.md:725`, falling to the "at least" limitation its own
   text warns about.

   **The ruling stands on better grounds than the majority it was made on.** The three `200` sites
   are `_schema` **constraint declarations** — `generators/features/templates.md:32`,
   `generators/features/schema.md:26`, `generators/features/schema.md:144`. All three `~150` sites
   are **prose and examples** — `generators/features/schema.md:18`,
   `skill-sources/reduce/SKILL.md:473`, `skill-sources/reduce/SKILL.md:725`. A schema declaration
   outranks a prose suggestion, and that is a reason rather than a tally.

   The count remains "at least": a term-keyed survey cannot enumerate sites that omit the term.
   Re-derive before editing.
6. **Enum: adopt `superseded` only.** Taken against a three-value list, then **re-affirmed
   unchanged** after measurement showed seven off-enum values, including `verified` (11), which
   has the same profile as `superseded` — a deliberate state canonical lacks. The accepted cost
   is stated under *What is NOT claimed*.
7. **Delivery: templates prevent permanently; a one-time throwaway script migrates.** A standing
   `/normalize` command was rejected as a shipped, versioned, gate-covered tool for a job that
   happens once in one place.
