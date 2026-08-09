# Corpus-wide passes — design

**Date:** 2026-08-08
**Status:** approved, not yet planned
**Origin:** three field-vault findings from `~/second-brain`, triaged 2026-08-08
**Revision:** rev 3. Two Fable-model review passes, 9 defects each; rev 2's own
corrections introduced 4 of the second batch (see [Review provenance](#review-provenance))
**Blocking open question:** [status values — literal or vocabulary key?](#open-question--are-status-values-canonical-literals-or-vocabulary)

---

## Thesis

Three findings arrived separately. They are one defect wearing three hats:

> **A per-note operation standing in for a corpus-wide pass.**

| item | per-note today | one pass |
|---|---|---|
| 1 — trailing period | WARN + auto-fix, fires on 61% of the corpus | normalize once; deliver the rule where notes are written |
| 2 — backlinks | `n` full-corpus scans, **~157s per loop** | one scan, ~0.29s, in a library function |
| 3 — lifecycle | **nothing** — no entry state and no transition | `/reduce` stamps the entry; `/verify` promotes on pass |

Each item is independently shippable. They share one discipline: every one came from
the field vault, so every one carries the two mandatory reverse-transforms
(`CONTRIBUTING.md`, "Two reverse-transforms are mandatory") — vault dialect becomes
canonical, concrete paths become `{vocabulary.*}` placeholders.

**Items 1 and 3 are coupled and must sequence together.** Both edit
`skill-sources/verify/SKILL.md` (1 removes WARN lines, 3 adds promotion) *and* both
change what a newly created note looks like (1 strips the description's trailing
period, 3 stamps `status`). Item 2 is independent.

## Measurements

**Every number below was derived from a command on 2026-08-08, against
`~/second-brain` (2686 nodes) or this checkout.** Vault figures drift as the vault
grows. Re-derive rather than quote.

**Nothing in CI gates any number in this file** — see [Testing](#testing). These
commands are the only defence against them going stale.

```bash
. reference/lib/frontmatter.sh

# ITEM 1 — descriptions ending in a period.
# 1633 = 1621 bare '.' + 12 terminated by a closing quote ('."' / ".'").
# Stated as a SUM, not a single total: rev 1 published a command matching only the
# bare form, which returns 1621 and so failed to reproduce its own headline 1633.
# That is the house failure exactly -- a published count its published command
# cannot re-derive.
bare=0; quoted=0
for f in ~/second-brain/nodes/*.md; do
  d=$(frontmatter_field "$f" description 2>/dev/null) || continue
  [ -n "$d" ] || continue
  case "$d" in
    *.)        bare=$((bare+1)) ;;
    *.\"|*.\') quoted=$((quoted+1)) ;;
  esac
done
echo "$bare + $quoted = $((bare+quoted))"        # 1621 + 12 = 1633 of 2686 = 60.79% -> 61%

# ITEM 3 — status distribution. MUST SUM TO THE NODE COUNT.
# rev 1 printed five values summing to 2005 against a corpus of 2686 and did not
# say where the other 681 went. A distribution that does not sum is not a
# distribution; the missing bucket was the largest finding in the item.
have=0; none=0
for f in ~/second-brain/nodes/*.md; do
  s=$(frontmatter_field "$f" status 2>/dev/null)
  if [ -z "$s" ]; then none=$((none+1)); else have=$((have+1)); fi
done
echo "$have with status + $none without = $((have+none))"   # 2005 + 681 = 2686
for f in ~/second-brain/nodes/*.md; do frontmatter_field "$f" status 2>/dev/null; done \
  | sort | uniq -c | sort -rn   # 1182 active, 808 draft, 11 closed, 3 superseded, 1 investigating

# ITEM 2 — the two shapes, timed.
#   per-note scan:  58ms/note  (57.5ms at n=100, 58.4ms at n=300 -- stable)
#                   -> ~157s PER LOOP over 2686 nodes, and it grows as n^2
#   one-pass index: 0.28-0.30s for all 2686, across TWO benchmark runs --
#                   0.278s in one, 0.30/0.29/0.30 in another. Rev 2 published
#                   0.278 as the headline beside runs of 0.30/0.29/0.30, i.e. a
#                   figure BELOW every run listed next to it, because the two
#                   benchmarks were conflated. Quote the range, not a point.
```

**False-positive check on the description count:** zero. Descriptions ending in
`etc.`, `e.g.`, `i.e.` or a `vN.N` version token number **0**. The matches are
ordinary sentences (`"...orthogonalization safety brittleness."`). The figure is real.

---

## Item 1 — the trailing-period convention

### The root cause is delivery, not the corpus

The obvious reading of "60% of a mature corpus violates the rule" is that the practice
rejected the rule. **That reading is wrong, and it was held during this design until
one command refuted it.** The field vault's note templates carry:

```yaml
constraints:
  description:
    max_length: 200
    format: "One sentence adding context beyond the title — ..."
```

**The "no trailing period" clause is absent.** The generator declares it and the
derived templates dropped it. The corpus was never asked. This is divergence 16 in
miniature: a rule that exists upstream and does not arrive downstream.

```bash
ls -1 ~/second-brain/templates/*.md | wc -l                    # 11
/usr/bin/grep -lc 'period' ~/second-brain/templates/*.md        # every one reports 0
```

**Eleven templates, zero carrying the clause.** Rev 1 said "the vault's note
template", singular, and quoted `annotation-node.md` — a minority type. The dominant
type (`insight-node.md`) carries a *different* format string. **The repair is plural
or it is nothing:** fixing one template leaves every other node type writing the
1634th note the old way, which is this item's own both-halves-or-neither argument
turned on itself.

### The generator declares it FOUR times, and they disagree

```bash
/usr/bin/grep -rn 'period' generators/
```

| site | says |
|---|---|
| `generators/features/schema.md:18` | `~150 chars, no period` — **inside the YAML block generation emits** |
| `generators/features/schema.md:26` | `Max 200 chars, no trailing period, must add info beyond title` |
| `generators/features/schema.md:144` | `"max 200 chars, no trailing period, must add info beyond title"` |
| `generators/features/templates.md:32` | `"max 200 chars, no trailing period"` |

Rev 1 said three. The missed one is `schema.md:18`, and **`schema.md` carrying two of
the four is exactly the single-file case a per-file survey cannot see** — the blind
spot divergence 15's amendment documents and `bump-version.test.sh` exists to catch.

**They also disagree on length: `~150` at `:18` against `200` at the other three.**
That is a second, pre-existing defect found while counting. It is *reported here, not
fixed* — reconciling a length constraint is a separate decision from a period.

**A fifth site exists that this survey structurally cannot see, and it is the one
part 4 edits.** `skill-sources/reduce/SKILL.md:473` — the note template `/reduce`
actually emits — declares `description: [~150 chars elaborating the claim, adds info
beyond title]`: **`~150`, and no period clause at all.**

```bash
sed -n '473p' skill-sources/reduce/SKILL.md
```

`grep -rn 'period' generators/` misses it twice over: wrong tree, and **a missing
clause does not contain the word being searched for.** That second failure is the
general one — *a survey keyed on a term can only find sites that already carry it*, so
it can never enumerate the sites that dropped it.

Two consequences. The `~150` vs `200` disagreement is wider than the deferral says (2
sites at `~150`, not 1). And the root-cause story needs qualifying: the clause was not
merely lost in derivation — **the canonical note-writing template never carried it**,
so it may never have been in the emission path at all. Part 4's mechanical strip covers
this functionally; the narrative and the deferral scope did not.

### Four parts

1. **One-pass normalizer.** Strips the trailing period from every `description:` in
   the notes directory, in both terminated forms (bare and quote-closed — the 12).
   Reads frontmatter through the shared library; a line-anchored
   `grep '^description:'` is what `check-portability.sh` check 7 bans and it would
   match the body. Rewrites only the `description:` line, never the body.
   **Ships twice** (see [Delivery ceiling](#delivery-ceiling)) — as a `skill-sources/`
   template sourcing **`ops/lib/frontmatter.sh`**, and as a `reference/` script
   sourcing `reference/lib/frontmatter.sh`.
2. **Template repair — all 11.** Restore the clause to every node-type template so new
   notes inherit it regardless of type. Vault-side, one-time.
3. **Remove the per-note checks.** `skill-sources/verify/SKILL.md:174` (WARN), `:372`
   (WARN), the `"Trailing period on description"` line in verify's *Auto-fix (safe to
   apply)* list, and `skill-sources/validate/SKILL.md:88`. **All four `generators/`
   declarations stay** — the convention survives; only the per-node finding goes.
4. **Mechanical post-write strip in `/reduce`.** A prose rule already went missing once
   in derivation; a second, mechanical guarantee costs a short fence. `/reduce` is the
   note-writing skill (`skill-sources/reduce/SKILL.md:473` carries the emitted note
   template). Strips trailing periods from the descriptions that run just wrote.

### Why removing the WARN is safe

The WARN gates nothing. It is orientation output, not a threshold input — unlike the
observation/tension counts, where a mislabelled number changes whether `/rethink`
fires (divergence 4). Nothing reads the trailing-period finding to make a decision.

---

## Item 2 — `link-extraction.sh` v2 → v3

### The missing API

`reference/lib/link-extraction.sh` (currently `LINK_EXTRACTION_VERSION=2`) exposes
directory-scoped functions only: `count_links`, `extract_link_targets`,
`existing_note_index`, and their `_recursive` variants. **Nothing answers per-file or
per-target questions.** Divergence 13 names this exactly and counts the cost: seven
sites re-inline the same three-stage pipeline because there is no other way to spell
the work.

### Three functions, not one

```bash
link_edge_map    <dir>...   # source<TAB>target, one line per link occurrence
backlink_counts  <dir>...   # target<TAB>count, pre-aggregated, self-edges excluded
orphan_notes     <dir>...   # basenames with zero incoming links
```

A raw edge list alone would be insufficient: consumers would loop over it per note,
which is the same quadratic with a cheaper constant. Aggregating **in the library** is
what removes the loop.

| consumer | function |
|---|---|
| `skills/health` orphans; `skill-sources/stats` orphans | `orphan_notes` |
| `skills/health` incoming + MOC counts; `skills/architect`; `skill-sources/reflect`, `reweave` | `backlink_counts` |
| `skill-sources/graph` authority ranking, triangles, backward links | `link_edge_map` |

### Two sets of size 7, different members — do not merge them

**Rev 1 merged them, which is the trap CLAUDE.md documents twice** (the five literal
`30`s; the two `9 = 7 + 2` sums). Same arithmetic, different subject.

```bash
# Divergence 12's class: a MATCHER -- brackets CLOSED with \]\]
/usr/bin/grep -rnE '(grep|rg)[^|]*\\\[\\\[.*\\\]\\\]' \
    skill-sources/ skills/ platforms/claude-code/ reference/ \
  | /usr/bin/grep -Ev 'reference/+(check-portability\.sh|test/guard-failure\.test\.sh):'
# 9 hits = 7 executable + 2 graph documentation-table rows

# Check 6's set: matchers that INTERPOLATE a note name
bash reference/check-portability.sh 2>&1 | /usr/bin/grep 'interpolated'
# "7 interpolated matcher(s) across 5 allowlisted file(s)"
```

| | divergence 12, executable (7) | check 6, interpolated (7) |
|---|---|---|
| `skills/health` | **4** (incl. `:585`) | **3** (`:585` takes no title — `portability-exempt`) |
| `skills/architect` | 1 | 1 |
| `session-orient.sh.template` | 1 | 1 |
| `reference/testing-milestones.md` | 1 | 1 |
| `generators/features/maintenance.md` | **0** — but see below | **1** (`:20`) |

**`maintenance.md` contains BOTH classes, in different lines, and this spec has now
mis-assigned it in both directions.** Rev 1 put it in divergence 12's set; rev 2
"corrected" that by citing `:29` and calling it divergence 13's class. Both were
wrong about the gated site:

```bash
/usr/bin/grep -nE 'rg |grep ' generators/features/maintenance.md
#  20:  rg -q "\[\[$title\]\]" {DOMAIN:notes/} || echo "Orphan: $f"      <- MATCHER, interpolated
#  29:  rg -oNI '\[\[([^\]|#]+)' {DOMAIN:notes/} -r '$1' | ...           <- EXTRACTION
/usr/bin/grep -n 'rg -q' reference/check-portability.sh    # :382 names this site by its spelling
```

- **`:20`** is an interpolated, closed-bracket **matcher** — divergence 12's class,
  and it is the line check 6 gates. `check-portability.sh:382` identifies it by
  spelling: *"required an `-l` flag, so it could not see `rg -q`."*
- **`:29`** is a separate **extraction** — divergence 13's class.

It shows `0` in divergence 12's column only because **that divergence's published grep
scans `skill-sources/ skills/ platforms/claude-code/ reference/` and never
`generators/`.** That is a scope artifact of the search string, not a property of the
file — precisely the "every search string tried so far has been narrower than the
class" failure divergence 12 documents about itself.

**Consequence for the claim below:** "divergence 13 — all 7 → closed" is likewise
scoped to `skill-sources/` and `skills/`. `maintenance.md:29` is an eighth site of
that class, outside the published search, and it stays open.

### What the conversion closes

| | count | disposition |
|---|---|---|
| Divergence 13 — inlined extraction, **as published** (`skill-sources/`, `skills/`) | **7** (`graph` ×4, `reflect`, `reweave`, `stats`) | all 7 → **closed within that scope** |
| — same class, outside the published scope | **1** (`generators/features/maintenance.md:29`) | **stays open** — a recipe, see below |
| Divergence 12 — executable matchers | **7** | **5 converted, 2 remain** |
| Check 6 — interpolated allowlist | **7** | **5 drained, 2 remain** |
| Regex-metacharacter bug | **3** live vault notes | fixed by construction |

**Five conversions:** `health` ×3, `architect` ×1, `session-orient.sh.template` ×1.

**What remains, and why each is blocked rather than skipped:**

- `skills/health:585` — takes no note title, tests MOC **list shape** not a backlink,
  already `portability-exempt`. Correctly outside the class.
- `reference/testing-milestones.md` — a test **spec**, not executable code.
- `generators/features/maintenance.md` — a **recipe emitted into a generated vault's
  documentation**. A recipe cannot source a library the way a fence can; this is the
  blocker CLAUDE.md already records for the `generators/features/*`
  `rg '^status: …'` recipes. Converting it changes what generation emits.

So divergence 12 ends at `health:585` + `testing-milestones`, and check 6's allowlist
ends at `testing-milestones` + `maintenance.md`. **Both land at 2 with different
members.** State it that way in the plan.

### Correctness properties the fixture must pin

| property | why |
|---|---|
| `[[a.b]]` does not match `axb` | the live bug — an interpolated name is a regex; 3 field-vault notes exposed |
| links inside ``` fences do not count | `_strip_fences`, already in the library |
| `[[T\|alias]]` and `[[T#anchor]]` resolve to `T` | the negated class `[^\]\|#]+` handles both |
| case-folded; `LC_ALL=C` on **every** sort | the collation trap from the exhaustive-dangling-scan fix — an unpinned side makes non-ASCII names spuriously dangle, silently |
| self-links excluded | preserves today's `grep -v "$f"` behaviour |

### The scope change, flagged rather than buried

Current sites disagree about scope **by accident**. `skills/health:174` orphan-scans
the whole vault (`rg -l … --glob '*.md'`, no directory argument); `skills/health:562`
restricts to the notes directory. An explicit `<dir>...` argument makes scope visible
— but each conversion must pass **the same directory set the old line scanned**, or
the reported number moves for reasons unrelated to the fix. Where the old scope was
accidental rather than chosen, the plan states the chosen scope and the expected delta.

**A count that changes for an unstated reason is the defect this repo is most prone
to.** Do not let a conversion silently re-scope a number.

### The hook template gets the SessionStart treatment

`platforms/claude-code/hooks/session-orient.sh.template` runs on **every**
SessionStart. Per the precedent set when `hooks/scripts/session-orient.sh` was
converted (divergences 7–9 closure), it must:

- **warn on stderr and omit the signal** when the library is absent;
- **never `exit 1`** — that turns a missing library into a broken session;
- **never substitute `0`** — an omitted line is visible, and `0` is precisely the
  value that stops a threshold from ever firing.

It also carries the `SESS_COUNT`/`INBOX_COUNT` cross-references installed by
divergence 3. **The conversion must preserve them.** Those values are declared in two
places and the cross-reference is the only thing stopping an edit to one from silently
splitting them.

### Library paths differ by shipping surface

**Vault-side templates source `ops/lib/`; only repo-side scripts source
`reference/lib/`.** A generated vault has no `reference/` directory. Rev 1 wrote
`reference/lib/` for vault-side deliverables, which would ship a guard that fails in
every vault — or, unguarded, silently reads nothing.

**Rev 2 then cited three lines that carry the *frontmatter* library, not this one.**
`next:216`, `rethink:164` and `stats:430` are all `FM_LIB="ops/lib/frontmatter.sh"`,
and `rethink` sources link-extraction nowhere at all. The real sites:

```bash
/usr/bin/grep -rn 'LINK_LIB=' skill-sources/
```

**They disagree on spelling, and the plan must pick one:**

| spelling | sites |
|---|---|
| `LINK_LIB="$VAULT_ROOT/ops/lib/link-extraction.sh"` | **8** — `graph` ×4, `reflect`, `reweave`, `stats` ×2 |
| `LINK_LIB="ops/lib/link-extraction.sh"` (bare relative) | **1** — `next:261` |

The bare form depends on the fence's working directory; the prefixed form does not.
This is a pre-existing inconsistency, surfaced here because every new consumer must
choose. **Match the 8, and note the 1 as a separate cleanup** — do not silently
convert it in this work, and do not copy it.

### Version bump is a multi-site edit

`LINK_EXTRACTION_VERSION` 2 → 3 moves together with `skills/setup`'s library copy
table, `skills/upgrade` §6a's version table, and every consumer's `>= N` guard. This
is the shape `bump-version.test.sh` exists to catch: **a bump that moves some declared
sites and not others, including two fields of the same file.**

### Draining check 6 is mandatory, not cleanup

Check 6's allowlist is **bidirectional** — a listed site that starts passing fails the
gate. Converting `health` and `architect` without draining their entries turns CI red.

---

## Item 3 — the note lifecycle

### The lifecycle had no entry state, not just no transition

The canonical enum `preliminary | open | active | archived` is declared four times
across `generators/` and validated once (`skill-sources/validate/SKILL.md:123`).
**No skill anywhere writes a NOTE's `status`**, and `generators/features/templates.md:27`
lists `status` as **optional**, so canonically generated notes are born *statusless*.
The only `status: active` writes in the tree are methodology notes — a different field
sharing a name, the same ambiguity documented in the divergences 7–9 closure.

**Rev 1 specified `preliminary → active` without noticing nothing writes
`preliminary`.** As written it shipped a transition that could never fire in a new
vault. The field vault's 808 `draft` notes exist only because *its* templates stamp
`status: draft` at creation — a vault-local choice the generator does not make.

**The `status: active` writes that DO exist are three, and none is a note.** Rev 2 said
"the only `status: active` writes in the tree are methodology notes", which the obvious
grep refutes. The load-bearing claim survives; the supporting sentence did not:

```bash
/usr/bin/grep -rn 'status: active' skill-sources/ skills/
# remember:99, rethink:346 -> type: methodology
# setup:823                -> category: derivation-rationale (an ops document)
# none of the three is a note in {vocabulary.notes}/
```

### `/reduce` stamps the entry; `/verify` promotes

- **`/reduce` writes `status: preliminary`** on every note it creates. `status` moves
  from *optional* to *written by default* in the emitted template.
- **`/verify` promotes `preliminary` → `active`** when the run completes with **no
  FAIL**. Idempotent. **Reports the transition in its output** — a status change is a
  semantic claim and must not be a silent mutation.
- Both read and write `status` through the shared frontmatter library, never a
  line-anchored grep (check 7).

### Four deliberate limits

1. **A missing `status` is skipped and reported, never promoted.** Absence is
   overloaded — "created before the stamp" and "someone deleted the field" are
   indistinguishable — so `/verify` must not infer intent from it.
2. **`open` is not touched.** Canonical declares it; nothing anywhere defines its
   semantics or transitions. Inventing one here would be shipping a guessed state
   machine.
3. **Off-enum and absent values are reported, not reconciled.** Per the divergences
   7–9 precedent, reconciling the generator with one vault's practice is a separate
   decision with a different owner.
4. **No retroactive backfill.** The 808 drain as notes are verified. A one-pass
   promotion would assert a quality claim about 808 notes that nothing checked.

### The field vault's schema violations are 693, not 12

`~/second-brain/templates/insight-node.md:5-11` lists `status` under **`required`**.
So:

```
  11  status: closed          ┐ present, in NEITHER the canonical enum
   1  status: investigating   ┘ nor the vault's own template enum   = 12
   3  status: superseded        in the VAULT's enum, absent from canonical
                                (see the mapping table) -- a dialect value,
                                not a violation                     =  3
 681  status absent entirely    violates the vault's `required` list = 681
                                                        -----------------
                                        total schema violations       693
```

**Rev 2 drew this box with `superseded` bracketed into the "outside both" group,
labelled `= 12` over three numbers summing to 15** — and contradicting its own
vocabulary mapping table twelve lines below, which correctly records `superseded` as
the vault's dialect. The total 693 was right via a decomposition the drawing denied.
*A distribution that does not sum is not a distribution* — this spec's own sentence,
three hundred lines up.

**Stating only the 12 would make the 681 read as clean** — the "stated limitation
implies unlisted gaps are covered" class, and an exclusion where CLAUDE.md's house
idiom demands a sum. Rev 1 stated only the 12.

The 681 are **explicitly out of scope**: the stamp is forward-only and does not reach
notes that predate it. See [Deferrals](#deferrals).

### OPEN QUESTION — are status values canonical literals or vocabulary?

**This is the one decision the spec does not make, and a plan cannot proceed without
it.** When `/reduce` writes `status: preliminary` and `/verify` matches on
`preliminary`, is that string a literal, or a `{vocabulary.*}` placeholder?

Neither answer is currently supported by anything:

```bash
/usr/bin/grep -n 'status' reference/vocabulary-transforms.md   # command-name rows only
/usr/bin/grep -rn 'vocabulary\.\(status\|preliminary\)' skill-sources/ skills/ generators/
#   no {vocabulary.status*} marker exists anywhere
```

`reference/vocabulary-transforms.md` maps **command names** only. There is no key
family for enum values, so a status placeholder would be a new vocabulary family, not
a new key in an existing one.

**The stakes are rev 1's defect in shipped form.** If the values are literals, a vault
whose derivation renames them — *exactly what the field vault did with `draft`* — gets
a `/verify` that promotes a value nothing writes. The transition compiles, ships, and
never fires: the same failure this revision exists to fix, one level up. If they are
vocabulary, the placeholder family has to be designed, and `check-vocabulary-schema.sh`
has to resolve it.

The testing table's row *"`check-vocabulary-schema.sh` — any new `{vocabulary.*}`
marker must resolve"* hints a marker might exist without deciding whether one is
needed. **That hedge is the defect.** Decide before planning.

### The vocabulary mapping is not one-to-one

The spec writes **`preliminary`** throughout. `draft` is the field vault's dialect and
appears **0 times** in `skill-sources/` or `generators/`; writing it in would ship one
user's vocabulary to every future system.

| canonical | field vault |
|---|---|
| `preliminary` | `draft` |
| `open` | *absent* |
| `active` | `active` |
| `archived` | `archived` |
| *absent* | `superseded` |

---

## Delivery ceiling

**Divergence 16 governs all three items.** A generated vault has three tiers of
validation that do not connect, and every gate in this repo reads *this* repo. A rule
added here reaches vaults **not yet created**.

- Item 1's **normalizer** must ship twice — a `skill-sources/` template *and* a
  `reference/` script pointable at an existing vault — or the 1633 notes are
  unreachable.
- Item 1's **template repair (all 11)** is a vault-side edit with no generator path to
  existing vaults.
- Items 2 and 3 reach new vaults only.

That is not a defect in this design; it is the standing constraint, and stating it
prevents "we fixed it in the generator" from being read as "it is fixed." **Do not
attempt to close divergence 16 here** — a generated-artifact refresh mechanism is its
own spec.

---

## Testing

| item | gate |
|---|---|
| 2 | new assertions in `reference/test/link-extraction.test.sh` against a discriminating fixture — one note per row of the correctness table, including the `a.b` / `axb` decoy pair |
| 2 | `fence-isolation.test.sh` green in **both** shells for every converted fence; each newly library-sourcing fence mutation-proved by deleting its `.`-source and confirming the gate reddens |
| 2 | `check-portability.sh` check 6 allowlist drained for the 5 converted sites |
| 1, 3 | `check-placeholder-count.sh` — the normalizer and the promotion must not hardcode vocabulary |
| 1, 3 | `check-vocabulary-schema.sh` — any new `{vocabulary.*}` marker must resolve |
| 1, 2, 3 | `check-doc-claims.sh` — for the counts **CLAUDE.md** states, if this work moves any |

### No gate reads this document

```bash
/usr/bin/grep -c 'superpowers\|specs/' reference/check-doc-claims.sh   # 0
```

`check-doc-claims.sh`'s table anchors on `CLAUDE.md`, `README.md`, `CONTRIBUTING.md`,
two library headers, `reference/skill-authoring.md` and `skill-sources/next/SKILL.md`
— **never `docs/superpowers/`** — and even for CLAUDE.md it reads *declared* claims
only. **Every number in this spec is ungated.** Rev 1's testing table claimed
otherwise ("every count this spec or CLAUDE.md states"), which is a proxy presented as
the property, inside the section whose closing paragraph warns about exactly that.

The re-derive commands in [Measurements](#measurements) are the only defence. Treat
them as the deliverable they are.

### What else is not covered

**A row in a total is not evidence it can fail.** Every new assertion is
mutation-proved, and each mutation is asserted to have applied (`cmp`) before its
result is read — a `sed`/`perl` that matches nothing reports the same all-green as a
robust assertion.

**Stated because a listed limitation implies the unlisted are covered:** none of these
gates asserts that a computed number is *correct*. The library fixture pins
`link_edge_map` and friends; nothing pins that a converted consumer aggregates them
into the right report. That is the standing gap the CI-hardening spec owns.

---

## Deferrals

- **The 681 statusless field-vault notes.** The `/reduce` stamp is forward-only. They
  violate the vault's own `required` schema and are not addressed here. Reaching them
  needs a vault-side backfill, which needs a rule for what status a pre-existing note
  should get — a question this spec does not answer.
- **The `~150` vs `200` description-length disagreement.** Two sites say `~150`
  (`generators/features/schema.md:18` and `skill-sources/reduce/SKILL.md:473`) against
  three saying `200`. Found while counting; reported, not fixed. The count is "at
  least" — a term-keyed survey cannot enumerate sites that omit the term.
- **`generators/features/maintenance.md` and `reference/testing-milestones.md`.** Not
  converted — a recipe cannot source a library, and a test spec is not executable.
  Check 6's allowlist stays open at 2; divergence 12 stays open at 2, with **different
  members**.
- **Off-enum vault statuses.** Two different questions, kept apart because rev 2
  merged them: `closed` (11) and `investigating` (1) are in **neither** enum — genuine
  violations. `superseded` (3) is in the vault's enum and absent from canonical — a
  **dialect gap**, the same shape as `draft`, asking whether the canonical enum widens.
  Reported by item 3, neither reconciled.
- **`open`'s semantics.** Undefined; no transition specified.
- **Materialized backlink cache** — assessed and **rejected**, with measurements. The
  cache path (staleness check 0.155s + read 0.048s = 0.203s) versus rebuild
  (0.278–0.30s) saves **0.075–0.094s, ~27–32%** — a range, because the rebuild figure
  is a range. The ratio is roughly **flat across corpus size** because both
  sides are O(n) filesystem traversals, so no node-count threshold exists at which it
  starts paying. And mtime staleness is unsound: 1-second granularity misses a
  same-second write, and `git checkout` / `touch -t` / rsync preserve mtimes — each a
  wrong backlink count returned with exit 0. A content-hash check would be sound but
  costs at least as much as rebuilding. **Reopening trigger:** a corpus where one pass
  exceeds a stated wall-clock budget *and* a sound staleness check measurably cheaper
  than a rebuild.
- **Divergence 16 itself** — out of scope, its own spec.

## Known drift this design created

`CLAUDE.md`'s divergence-12 table cites `skills/health` at `:132, :467, :520, :543`.
The Category 1 enum-value check added on `worktree-backport-queue-seed-vocab-health`
shifted them to `:174, :509, :562, :585` (+42). The **count** is unchanged, so check 6
stays green while the table rots — the same `(letter, label)` fragility that
renumbered the fence known-open entry `f08 → f09` on the same branch.

**A fifth row in that same table is also stale, and was not caused by this branch:**
`reference/testing-milestones.md` is cited at `:410` and is actually at `:425`.

```bash
/usr/bin/grep -n 'grep -rl' reference/testing-milestones.md   # :425
/usr/bin/grep -n 'testing-milestones.md:' CLAUDE.md           # :966 still says :410
```

Rev 2 named only the four health rows and told the plan to re-derive *those* — which
makes the fifth read as current. That is this spec's own named class, committed in the
paragraph about stale line numbers. **Re-derive every row of that table, not the four
named here.**

## Review provenance

Rev 1 passed an inline self-review cleanly: no placeholders, every named repo path
resolving, all seven cited line numbers correct. A dispatched Fable-model reviewer
then found **9 defects**, of which 6 were independently re-verified before rev 2. The
two passes failed at different layers and neither substitutes for the other — the
inline check verified that citations *resolved*, a syntactic property; the Fable pass
verified they *meant what the spec said they meant*. The most consequential finding
could not have been caught syntactically: every line number in item 3 was correct, and
the section was simply describing a state machine with no entry.

**Rev 2 was reviewed the same way and yielded 9 more — of which four were introduced
BY rev 1's corrections.** That is the finding worth carrying forward:

| rev 2 correction | what it introduced |
|---|---|
| reassigning `maintenance.md` from divergence 12 to 13 | cited `:29`; the gated site is `:20`, a matcher. Rev 1 was closer |
| citing the `ops/lib/` precedent | quoted three `FM_LIB` lines as `LINK_LIB`, one from a file that sources it nowhere |
| adding the schema-violation box | bracketed three numbers summing to 15 under a label of 12, contradicting its own mapping table |
| pinning the index timing | published `0.278s` beside runs of `0.30 / 0.29 / 0.30` — below every run listed with it |

**A correction lands as verified prose and is read with more trust than the error it
replaced.** Rev 2 also *narrowed* one true statement into a false one (61% → 60%, by
truncating rather than rounding) — the original was right.

Per the convention established the same day, a dispatched Fable review is the
self-review step for specs in this repo — read-only, asked for defects ranked by blast
radius with a re-derive command each, and **its findings verified independently before
being acted on**. Two rounds converged: round 2's defects were smaller and more
localized than round 1's, and only one (the status-value vocabulary question) was a
design gap rather than a citation error.
