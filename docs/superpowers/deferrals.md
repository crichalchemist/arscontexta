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
`docs/superpowers/plans/2026-08-04-ci-hardening.md` is tracked, but nobody opens a
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
`docs/superpowers/specs/2026-08-04-ci-hardening-design.md` item 18

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

*(none yet — entries move here when acted on, with the commit that did it. They are
never deleted: a ledger that quietly drops items is the status-file-that-lies defect
this repo documents about itself.)*
