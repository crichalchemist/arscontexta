# Vocabulary integrity across emitted surfaces — design

Six defects, one class — five of which this spec closes; the sixth is resequenced for a
mechanism reason found in review, and is named below rather than folded away. Every emitted vocabulary in this repo is declared at several surfaces
that do not agree, or is missing a value it needs. None of them is caught by a gate, because
`reference/check-vocabulary-schema.sh` asserts that a `{vocabulary.X}` marker *resolves* to a
declared key — never that two prose declarations of the same enum *match*.

That is why all six drifted independently and none turned CI red.

**Source:** `docs/field-intel-2026-08-24.md` findings 6, 15, E-1, E-4; `docs/superpowers/deferrals.md`
entries 6, 12, 32 item 1.

**Packaging:** two PRs split at the schema boundary, preceded by a standalone repair commit.
Rationale in [Architecture](#architecture-five-ordered-units).

**Revised 2026-08-24** after adversarial review
(`docs/superpowers/reviews/2026-08-24-vocabulary-integrity-review.md`, findings independently
re-verified against the tree). The five units survived; their edit lists did not.

## The unit, and why these six are one spec

Five of the six are the same shape — *one vocabulary, several surfaces, no agreement*:

| # | Vocabulary | Surfaces | Disagreement |
|---|---|---|---|
| E-4 | command names | schema + 11 call sites | sigil stored *and* prefixed |
| E-1 | relationship verbs | 7 sites | 4 distinct spellings |
| #6 + 32.1 | description length | 2 sites | `~150` against a canonical `200` |
| F6 | status values | 1 counting site | no branch for a value outside the enum |

Finding 15 is the sixth and inverts the shape — the observation register's terminal vocabulary
is *missing a value it needs*: `implemented` closes an **instance**, and nothing can say the
**condition** remains reachable by other causes. It is the same defect class read from the other
side, which is why it belongs here rather than in its own spec.

### The scoping rule, and the one item it removes

**Literal edits in `generators/` are in scope; new placeholder families there are not.**

This is not a convenience boundary — it is the repo's own, stated in the gate that draws it.
`reference/check-vocabulary-schema.sh:12-15` excludes `generators/features/*.md` because they
are *"composition blocks selected by config, not verbatim templates"*, and
`check-placeholder-count.sh:37-47` excludes them for the same reason. Measured, the tree agrees
with its own rationale:

```bash
/usr/bin/grep -roh '{vocabulary\.[a-z_]*}' generators/ | awk 'END{print NR+0}'   # 0
/usr/bin/grep -roh '{DOMAIN:[a-zA-Z_]*}'    generators/ | awk 'END{print NR+0}'   # 527
```

Zero `{vocabulary.*}` against 527 `{DOMAIN:*}`. A `{vocabulary.status_preliminary}` written
there would be a marker family the tree has never carried, resolved by no mechanism documented
in `generators/claude-md.md`, and checked by neither placeholder gate — so a typo'd
`{vocabulary.status_preliminery}` ships silently into every vault. That is a *new* silent-failure
surface, added by a spec whose subject is silent failure.

The rule sorts the six items cleanly:

| Item | Tree | Kind of edit | Verdict |
|---|---|---|---|
| E-4 | `skills/`, `skill-sources/` | literal | in |
| E-1 (6 sites) | `skill-sources/` | placeholder, tree already resolves it | in |
| E-1 (7th site) | `generators/features/wiki-links.md` | **literal** — harmonize the words | in |
| #6 + 32.1 | `generators/features/` | literal (prose numerals) | in |
| F6 | `hooks/scripts/` | logic | in |
| Finding 15 | `generators/features/`, `skill-sources/` | literal (a field name) | in |
| **#12** | `generators/features/` | **placeholder family** | **out** |

**Deferral #12 moves to the companion agreement-gate spec.** It is the only item that is
definitionally a new placeholder family in the composition tree. Two consequences follow, and
both are improvements:

1. **PR 2 carries zero gate-logic risk.** An earlier revision of this spec had Unit 3 co-editing
   `check-doc-claims.sh`'s `enum_values()` normalizer, because `{vocabulary.status_*}` in
   `generators/` collapses that gate's extraction to one garbage token and trips its under-2
   guard into rc 2. With #12 gone, the gate never sees a placeholder and the normalizer is left
   alone. That co-edit travels with #12.
2. **Finding 6 is decoupled, not blocked.** It was specified as "after #12" because it seemed to
   need the converted enum. It does not — see Unit 4, which counts without an enum at all.

**The alternative, rejected:** extend `{vocabulary.*}` resolution into the composition path —
document substitution in `generators/claude-md.md` and widen a gate's scope to cover
`generators/`. That is a larger change to how vaults are assembled, it contradicts the stated
rationale of two gates, and it deserves its own derivation rather than riding along here.

## Measurements

Every number below was produced by the command beside it on `develop` @ `db399d8`. Re-derive
before acting; this file is prose and prose numerals rot — which is itself one of the findings.

```bash
# E-4 -- the schema stores the sigil INSIDE the value, and 11 sites prefix it again
/usr/bin/grep -n 'cmd_reflect' skills/setup/SKILL.md
#   1180:  cmd_reflect: "[/domain-verb]" # e.g., "/reflect", ...
/usr/bin/grep -rho '/{vocabulary\.cmd_[a-z]*}' skill-sources/ | awk 'END{print NR}'   # 11
/usr/bin/grep -rho  '{vocabulary\.cmd_[a-z]*}' skill-sources/ | awk 'END{print NR}'   # 28 (11 + 17 bare)
```

The 17 bare sites already assume slash-in-value, so the storage convention is the majority and
is correct. Fixing the stored value instead would break 17 to repair 11.

```bash
# E-4 -- the rendered consequence, in the field vault
cd ~/second-brain/.claude/skills && \
  /usr/bin/grep -rho '//[a-z][a-z]*' graph/SKILL.md stats/SKILL.md extract/SKILL.md | sort | uniq -c
#   9 //reflect · 1 //reweave · 1 //verify   (and 1 //github -- a URL, not a defect)
```

11 template sites, 11 malformed references. They reconcile exactly. **Do not quote a per-file
rendered count**: a `//[a-z]*` probe also matches URL separators and will not reconcile.

```bash
# E-1 -- seven declaring sites, four distinct spellings.
# Sweep the whole repo, and anchor on `contradicts`, not `extends`:
# `contradicts` appears in all four spellings and is rarer in ordinary prose.
git -c core.quotePath=false ls-files '*.md' \
  | xargs /usr/bin/grep -n 'contradicts' \
  | /usr/bin/grep -v '{vocabulary' | /usr/bin/grep -v '^platforms/shared/skill-blocks/'
```

Two earlier discovery commands were both too narrow, in the same way.
`grep -rn 'extends,' skill-sources/` yields **five** sites under a caption claiming six — the
`reflect` table never matches `extends,`. Widening it to two trees found `wiki-links.md` but is
still C2's defect narrowed by one tree rather than fixed. Only the repo-wide sweep above closes
the inventory, and it must be the command the plan re-runs.

**Triage disposition for the whole sweep, so the untriaged remainder is a stated number rather
than an implied zero.** Narrowed to the two generation trees,
`/usr/bin/grep -rn 'contradicts' generators/ skill-sources/` returns **21** hits. Ten are
accounted for above — the seven declaring sites that fall in these trees, the two ruled-OUT
partial carriers in `processing-pipeline.md`, and `reflect:385-388`. The remaining **eleven** are
ruled OUT as a class, in three groups:

| Group | Hits | Ruling |
|---|---|---|
| Ordinary English (`claude-md.md`, `maintenance.md`) | 2 | The word used as a verb about ideas, not a relationship-type token |
| Detection rules — `reduce`, `reflect`, `remember`: *"contradicts existing {vocabulary.note_plural} → create a tension"* | 5 | Single-verb triggers for an action, not spelling-family declarations. Substituting would couple tension-detection to the relationship enum, which is a design change, not a harmonization |
| `reweave` content-evolution language (4 hits) | 4 | About a revision contradicting an earlier version of the same note — a different sense of the word entirely |

A delta review reported 36 hits for this command and named three untriaged files —
`graph-structure.md`, `dimension-claim-map.md`, `conversation-patterns.md`. Re-measured: the
command returns 21, and none of those three files exists under `generators/features/`; they are
`methodology/graph-structure.md`, `reference/dimension-claim-map.md` and
`reference/conversation-patterns.md`. Both trees sit outside the generation paths — `methodology/`
is the 249-claim research corpus, not a declaration surface, the same exclusion Unit 5 applies to
it for `~150`. The finding pointed at a real gap (the spec did triage fewer hits than the sweep
returns); its evidence did not survive re-measurement. Re-run the command rather than trusting
either number.

| Site | Verbs |
|---|---|
| `reflect:295-300` (table rows; caption at `:291`, header `:293-294`) | extends, grounds, contradicts, exemplifies, synthesizes, enables |
| `reflect:378` (prose) | *same six* |
| `validate:146` | extends, **foundation**, contradicts, enables, **example** |
| `verify:197` | extends, **foundation**, contradicts, enables, **example** |
| `reduce:279` | extends, contradicts, **deepens** |
| `reduce:494` | extends, contradicts, **builds on** |
| `generators/features/wiki-links.md:48-53` | extends, **foundation**, contradicts, enables, **example** |

Only `extends` and `contradicts` appear in all four spellings.

**Two partial carriers, ruled OUT with reason.** The repo-wide sweep also returns
`generators/features/processing-pipeline.md:54` (*"'extends X by adding Y' or 'contradicts X
because Z'"*) and `reference/open-questions.md:127` (*"mix of extends/contradicts/enables is
richer"*). Neither declares the enum — they name two or three verbs as illustration inside prose
about connection quality — so substituting them would put markers into sentences that are not
lists. They are recorded here so a later sweep sees a ruling rather than a miss. If the verb
family is ever renamed in a domain, `processing-pipeline.md:54` is the one to re-read: it composes
into the vault like `wiki-links.md` does.

**The seventh site is the one that matters most and was found last.**
`generators/features/wiki-links.md:48-53` declares the enum inside the feature block that
composes into **every generated vault's `CLAUDE.md`** — the always-loaded context file. Substitute
the six `skill-sources/` sites and leave it, and a vault's skills speak the derived terms while
its always-loaded context hardcodes `foundation`/`example`: *one vocabulary, several surfaces, no
agreement*, surviving at the most visible surface in the product. Two further carriers ride the
same file — the inline example at `:36` (*"provides the evidence this builds on"*) and `:57`
(*"provides the foundation this challenges"*).

A prior revision of this spec claimed `deepens` and `builds on` *"occur nowhere else in the
repo."* Measured false by the sweep in Decision 1: `builds on` is at `wiki-links.md:36` and `:49`,
in `self-evolution.md:273`, `platforms/shared/templates/README.md:31` and `skills/tutorial/SKILL.md:486`;
`deepens` recurs as ordinary English ("understanding deepens") in five `reference/` and `presets/`
files. None is a declaration — but "in the repo" was the claim's own quantifier, and the corrected
statement is the narrower one: *neither string is used as a relationship verb outside `reduce`.*

Deferral #12's four declarations (`atomic-notes.md:94`, `schema.md:30`, `schema.md:142`,
`templates.md:30` — 4 declarations in 3 files; a file-to-file survey sees three and misses one)
are measured in the companion spec, not here. See *The scoping rule* above.

```bash
# Finding 6 -- the counting site, and its closed accept-list
/usr/bin/grep -n 'count_notes_by_field' hooks/scripts/session-orient.sh
#   151:  count_notes_by_field "$1" status pending open
```

Any status outside `pending|open` is excluded from the count while remaining inside `OBS_TOTAL`,
which is computed by `find`. The item vanishes from the numerator and stays in the denominator,
and nothing says so.

```bash
# Deferral #6 -- the ~150 residue, both sites in generators/
/usr/bin/grep -rn '~150' generators/ skill-sources/
#   generators/features/atomic-notes.md:75 · generators/features/schema.md:18
```

```bash
# Finding 15 -- the closure contract
/usr/bin/sed -n '88p;102p;220p;240p' generators/features/self-evolution.md
#   88:  status: pending | open | promoted | implemented | archived
#  102:  - `implemented` -- the fix exists; add `implemented_in: path/to/file`
#  220:  status: pending | open | resolved | dissolved | promoted | implemented | archived | blocked
#  240:  - `implemented` -- resolving it required a system change; add `implemented_in: path/to/file`
```

`implemented_in:` names a **file**. A file can address a property other than the one observed,
and the field has now produced three such closures in one week — two of them re-opened as
falsified. Verified directly: `~/second-brain/ops/observations/hubs-can-hold-claimed-members-…md`
carries `falsified_implemented_in: ops/scripts/health_check.py`, and that file exists at 101
lines containing zero occurrences of `claimant`, `claimed`, or `coverage`.

### Two prose numerals have already rotted, ungated

```bash
PAT='{vocabulary\.[a-z_]*}\|{config\.[a-z_]*}\|{DOMAIN:[^}]*}'
for p in verify validate reflect; do
  printf '%-9s source=%-4s blocks=%s\n' "$p" \
    "$(/usr/bin/grep -o "$PAT" "skill-sources/$p/SKILL.md" | awk 'END{print NR+0}')" \
    "$(/usr/bin/grep -o "$PAT" "platforms/shared/skill-blocks/$p.md" | awk 'END{print NR+0}')"
done
# verify    source=30   blocks=146     <- CLAUDE.md:124 states 27 (see note)
# validate  source=5    blocks=60      <- correct
# reflect   source=123  blocks=203     <- skill-authoring.md §2 states 121
```

**`awk` is substituted for the canonical block's two `wc` calls deliberately.** This environment's
`rtk` wrapper fabricates a bare `0` for a line carrying two `wc` invocations. Running
`reference/skill-authoring.md` §2 verbatim through a shell tool returns zeros
indistinguishable from a clean measurement.

Only the live side rotted. Every `blocks=` figure is correct because
`platforms/shared/skill-blocks/` is cksum-frozen and **cannot** drift — the frozen tree is
accidentally acting as the control group for an experiment nobody ran.

`reference/check-doc-claims.sh` reads neither number:

```bash
/usr/bin/grep -c '146\|verify.*27' reference/check-doc-claims.sh   # 0
```

This matters here because **E-1 changes these counts again** — adding `{vocabulary.rel_*}` markers
touches `verify`, `validate`, `reflect` and `reduce`. Three of those four appear in the documented
tallies; `reduce` does not (`/usr/bin/grep -c '155\|132' CLAUDE.md reference/skill-authoring.md`
→ 0 and 0). Unit 3 therefore owns re-deriving the tallies Unit 1 repairs — see *Unit 3*. Without
that, PR 2 ships numerals that are stale the moment it merges: a fresh instance of the very defect
this spec opens by condemning, minted by the spec itself.

## Decision 1: relationship verbs become vocabulary

**Adopt `reflect`'s six as canonical, and make them substitutable** by declaring six flat
`rel_*` keys.

`reflect` is the only site that *defines* the verbs — its table rows at `:295-300` carry Signal and
Example columns; the other five merely list them. `foundation`→`grounds` and
`example`→`exemplifies` are synonym pairs; `synthesizes` is genuinely additional; `deepens` and
`builds on` are singletons with no definition anywhere.

Substitutability is the correction of a real inconsistency, not scope creep. This generator
derives domain-native terms for `note`, `MOC`, `inbox` and `description field`, then ships
hardcoded English relationship verbs into every domain. `reference/vocabulary-transforms.md`
already renames `wiki link` per domain; the verbs riding *inside* those links were simply never
given the same treatment.

**Shape.** Follow the `# Level 6.5: Lifecycle states (one key per enum value)` precedent exactly
— it is the same problem solved once already:

```yaml
  # Level 6.6: Relationship types (one key per enum value)
  rel_extends: "[domain term]"      # e.g., "extends", "develops", "advances"
  rel_grounds: "[domain term]"      # e.g., "grounds", "supports", "establishes"
  rel_contradicts: "[domain term]"  # e.g., "contradicts", "challenges", "disputes"
  rel_exemplifies: "[domain term]"  # e.g., "exemplifies", "illustrates", "shows"
  rel_synthesizes: "[domain term]"  # e.g., "synthesizes", "combines", "unifies"
  rel_enables: "[domain term]"      # e.g., "enables", "permits", "makes possible"
```

Keys must be **flat, two-space-indented, and before the `# Level 7:` marker**. The gate extracts
with `sed -n '/^vocabulary:/,/# Level 7:/{/^  [a-zA-Z_]*: /p;}'`, so a dotted key cannot resolve
and a key placed after that marker looks correctly placed while reading as undeclared. The block
is bounded at `skills/setup/SKILL.md:1149`–`:1192`.

`reference/vocabulary-transforms.md` gains a row for the verb family in the same commit —
otherwise the keys exist and nothing tells a deriving conversation what they are for.

**Per-occurrence mapping, ruled here so the plan is deterministic.** "Six verb sites →
`{vocabulary.rel_*}`" does not say what the odd spellings become, and two readings produce
materially different templates:

| Site | Occurrence | Becomes |
|---|---|---|
| `reflect:295-300`, `reflect:378` | all six | the matching `rel_*`, one for one |
| `validate:146`, `verify:197` | `extends` | `{vocabulary.rel_extends}` |
| | `foundation` | `{vocabulary.rel_grounds}` |
| | `contradicts` | `{vocabulary.rel_contradicts}` |
| | `enables` | `{vocabulary.rel_enables}` |
| | `example` | `{vocabulary.rel_exemplifies}` |
| | *(absent)* | **gains `{vocabulary.rel_synthesizes}`** — these are "standard types" lists and must state the whole enum |
| `reduce:279` | `deepens` | `{vocabulary.rel_grounds}` |
| `reduce:494` | `builds on` | **`{vocabulary.rel_grounds}`** — see below |
| `wiki-links.md:48-53` | literal words | harmonized, **not** substituted — see Unit 3 |

**`deepens` and `builds on` both map to `rel_grounds` — a judgment call whose two textual
anchors point opposite ways and cancel.** An earlier revision of this line said "no textual
anchor". The measurement below is sound and stands — neither string is *declared* as a
relationship verb — but two **glosses** use `builds on`, and they pull against each other:
`wiki-links.md:49` glosses **extends** as *"builds on an idea by adding a new dimension"*, while
`:36` glosses **foundation** as *"provides the evidence this builds on"*. Because they cancel, the
call is free; because `:49` survives, it must be reworded or every generated vault's CLAUDE.md
will define *extends* with the exact phrase this table assigns to *grounds*. That rewording is in
Unit 3's harmonize list. The distinction worth keeping: a declaration is a spelling carrier, a
gloss is a semantic one, and a sweep for the former does not find the latter.

Measured, neither string is *declared* anywhere in the repo:

```bash
git -c core.quotePath=false ls-files '*.md' | xargs /usr/bin/grep -n 'builds on\|deepens' \
  | /usr/bin/grep -v '^platforms/shared/skill-blocks/'
#   as a relationship verb: reduce:279 (deepens), reduce:494 (builds on) -- and nowhere else.
#   every other hit is ordinary English ("understanding deepens", "builds on base-note.md").
```

Both sites read as bare list items with no gloss — `:279` is *"Pass: extends, contradicts, or
deepens existing notes"*, `:494` is *"[why it relates: extends, contradicts, builds on]"*. A prior
revision of this spec justified the mapping by quoting *"provides the evidence this builds on"* and
attributing it to `:494`; that gloss is `wiki-links.md:36`, a different file. The citation was
wrong, which is worse than having none.

What *does* bind is non-collision. Both lists already contain `extends` and `contradicts`, so
routing the third slot to `rel_extends` — the naive reading, since a prior draft of the Level 6.6
block offered "builds on" as an example spelling of `rel_extends` — renders `reduce:494` as
**"extends, contradicts, extends"**: a three-verb list with a duplicate, in the default
derivation. `rel_grounds` keeps three distinct verbs at both sites, as they read today. **The
`rel_extends` example list drops "builds on" in the same commit** so the schema does not tell a
deriving conversation the opposite of what the mapping table says.

`deepens` leans toward extends/develops on a plain reading. It cannot go there for the
collision reason above, and no evidence in the tree settles it further. Recorded as a decision, not
a derivation — revisit if a vault's field use disambiguates it.

## Decision 2: closure names the property, not just the file

`implemented` gains a required companion field stating **what was closed**, in the observation's
own terms:

```yaml
status: implemented
implemented_in: path/to/file      # where the fix lives
closes: [the property this fix actually closes]
```

Both falsified closures named a **real, existing file**. A reviewer checking "does
`implemented_in` resolve?" passes them. A reviewer checking "does `closes:` restate the property
this observation is about?" catches them. The field is the discriminator; the path is not.

**Explicitly rejected:** adding a status value (e.g. `mitigated`). It expands the same enum that
Finding 6 has just shown cannot handle a value outside its accept-list — and that enum is already
queued for conversion to placeholders under deferral #12, so a new value would have to be added
twice, in two spellings, across two specs. Revisit once Finding 6 ships and #12 lands.

**The schema is not the surface that writes closures.** Declaring `closes:` in
`generators/features/self-evolution.md` and stopping there changes nothing a vault emits. The
skill that *performs* the closure is `/rethink`, and its template instructs the full recipe —
without `closes:` — at four sites, with a fifth asserting the pairing rule:

```bash
/usr/bin/grep -n 'set `status: implemented`' skill-sources/rethink/SKILL.md
#   232, 233, 335, 516     ("set `status: implemented`, add `implemented_in: [filepath]`")
#   357 asserts: an `implemented` with no `implemented_in:` is unfalsifiable
```

Leave those alone and a generated vault carries a schema requiring `closes:` and a skill whose
recipes omit it — two emitted surfaces of one contract that disagree, which is this spec's own
definition of the defect. The falsified closures that motivate this decision were produced by
exactly that flow. All five sites are in scope; `implemented_in` appears in only two files
repo-wide (`/usr/bin/grep -rln 'implemented_in' skill-sources/ generators/ skills/`), so the
sweep is closed.

**This is advisory in the template, not gated** — and that declines a mechanism that already
exists. `reference/validate-kernel.sh:1012-1014` enforces `implemented → implemented_in`
(non-empty) for observations *and* tensions; `closes:` would be one token away in the same loop.
The choice stands anyway, for two reasons: no check can assert `closes:` is *accurate* — only that
it is present, which is the weaker half of what makes the field useful — and adding it would
require the `kernel.yaml`/validator sync `CLAUDE.md` mandates, expanding PR 1 from a schema
addition into a contract change. Stated so a later reader sees a declined option rather than an
absent one.

## Architecture: five ordered units

Packaging **B** — split at the schema boundary, so each PR carries one kind of risk. A single PR
would mix a mechanical string fix, two schema expansions, a logic change and a schema addition;
`reference/check-placeholder-count.sh` is range-relative (deferral #18), so when a count moved
unexpectedly there would be no way to attribute which item moved it.

### Unit 1 — repair the rotted numerals. Standalone commit, no behavior change.

**Three numeral edits across two files, not two.** The `27` is stated twice:

| Site | Now | Correct | Reflow? |
|---|---|---|---|
| `CLAUDE.md` (numeral on 124, context on 123) | `27` | `30` | **yes** |
| `reference/skill-authoring.md:70` | `27` | `30` | no |
| `reference/skill-authoring.md:70` | `121` | `123` | no |

`skill-authoring.md:70` carries all three figures on one physical line — *"That yields `verify` 27
against 146, `validate` 5 against 60, `reflect` 121 against 203"* — so it needs value edits only.
`validate` 5/60 is correct and must be left alone **in this unit** — it is the born-green control
that proves the re-derivation command still binds, and changing it here destroys the only positive
signal in the set. It stops being a control in Unit 3, which moves `validate` to 11 and owns
updating it. Left without that clause, "must be left alone" reads as permanent and an implementer
ships a stale 5.

An earlier draft of this unit listed two edits and would have left `skill-authoring.md`'s `27`
standing — a partial repair that reads as complete.

**A third carrier exists and is ruled KEEP, with a note.** `reference/check-placeholder-count.sh:43`
repeats `146 in \`verify\` where skill-sources has 27` in a gate comment
(`/usr/bin/grep -rn 'has 27' CLAUDE.md reference/`). It is repaired to `30` in the same commit —
leaving one of three carriers stale is the failure mode this unit exists to avoid — but it is
explicitly **not** registered as a gate row: a comment inside a gate cannot be asserted by that
gate without circularity, and the numeral-gate spec's rows cover prose files only. Ruled in
writing here so a later reader sees a decision rather than an oversight.

**The `27` is hard-wrapped onto line 124, orphaned from its context on line 123.** Line 123 ends
`…146 markers in \`verify\` where \`skill-sources\``; line 124 opens `27.`. A first draft of this
spec cited `CLAUDE.md:123` and was wrong — a line-grep for the sentence finds 123, a line-grep for
the number finds 124, and neither alone is the edit anchor:

```bash
/usr/bin/grep -n '\b27\b' CLAUDE.md          # 124  <- the numeral
/usr/bin/grep -n '146 markers' CLAUDE.md     # 123  <- its context
```

This is not incidental. The wrap is *why* the count is currently unregistrable by any
anchor-based gate, and the fix commit must **reflow the sentence** so the numeral and its subject
share a line. Doing so is a prerequisite for the separate numeral-gate spec, which cannot register
a row against a number split from what it counts.

Take edit anchors from `sed`, never from a Read — Read output is lossy here and drops line ranges.

**Cross-spec dependency, agreed with the numeral-gate design.** Unit 1 owns the reflow and all
three numeral repairs. `docs/superpowers/specs/2026-08-24-rot-prone-numeral-gate-design.md` takes
Unit 1 as a **precondition** and registers its rows afterwards — its earlier "one commit, born
green" coupling is withdrawn. The binding invariant is *ordering, not atomicity*: a registration
row cannot precede the reflow, because a `sed` extract cannot bind across the 123/124 wrap.
Nothing requires it to ride the same commit.

**Born-red is structurally unavailable here**, which is why that spec proves its rows by verified
mutation instead: a CLAIMS row on a merge-blocking gate cannot be born red, because a red row
cannot merge. Mutation is not a weaker substitute for born-red in this mechanism — it is the only
coherent binding proof available. When that mutation test runs, it must **mutate digits only,
never the surrounding anchor words**: the gate's rc 2 (anchor moved / could not run) outranks
rc 1 (stale claim), so mutating a word turns CI red while proving the wrong path.

There is no regression window between the two commits. The gate is green over the rot today
because no rows exist; Unit 1 makes the prose true; registration later adds the enforcement.

**This lands alone, before any placeholder moves.** Repairing a stale number in the same commit
that changes it again makes the repair unprovable — you cannot show 27 was wrong once the tree
that produced 30 has itself moved. Born-red first: re-derive, commit the repair, re-derive again
to confirm it holds, *then* start Unit 2.

### Unit 2 — declare. (PR 1)

**Append the new `reference/vocabulary-transforms.md` row BELOW the existing rows** (`:11-25`).
Root `CLAUDE.md:115` says *"line 14 of that file is the mapping table"*; inserting above line 14
silently invalidates that pointer, and no gate reads it.

**This unit also amends `docs/superpowers/deferrals.md`, and that edit is not bookkeeping.**
Entries 6 and 32.1 close when Unit 5 lands, and entry 12 changes state — yet no unit touched the
register. Worse, entry 12's stated destination did not exist: "moves to the companion
agreement-gate spec" names no file, and
`docs/superpowers/specs/2026-08-24-rot-prone-numeral-gate-design.md` is a different subject
(`/usr/bin/grep -c '#12\|status_\|enum_values'` against it → 0). Entry 12's own reopen trigger has
already fired — it reads **NOW DUE** at `deferrals.md:238`.

A deferral whose trigger has fired, re-deferred to an unwritten document with no tracking entry,
is precisely how `deferrals.md` says items get lost. So amend entry 12 in place with the mechanism
reason and its prerequisite — *document `{vocabulary.*}` resolution for the composition path, or
rule that tree permanently `{DOMAIN:*}`-only* — and the date. That is the landing place; no stub
spec is required.

- Six `rel_*` keys at Level 6.6 in `skills/setup/SKILL.md`
- The verb-family row in `reference/vocabulary-transforms.md`
- `closes:` on both terminal-status blocks in `generators/features/self-evolution.md` — `:102`
  (the **observations** register) and `:240` (the **tensions** register; its enum at `:220` carries
  `resolved | dissolved`). A prior revision called both "observation-status blocks"; the edits were
  right, the label would misdirect a grep.
- `closes:` in the five closure-writing sites of `skill-sources/rethink/SKILL.md` — `232`, `233`,
  `335`, `516`, and the pairing assertion at `357`. Without these the schema requires a field no
  emitted skill ever writes (Decision 2).

Declaration precedes use. `check-vocabulary-schema.sh` fails any `{vocabulary.X}` that resolves
to nothing, so using a `rel_*` marker before its key is declared turns CI red — which is the
correct direction to fail, and means the two units cannot be safely reordered.

### Unit 3 — substitute, harmonize, re-derive. (PR 2)

**Substitute** — six `skill-sources/` verb sites → `{vocabulary.rel_*}`, per Decision 1's
per-occurrence table: `reflect:295-300`, `reflect:378`, `validate:146`, `verify:197`,
`reduce:279`, `reduce:494` — **plus two carriers the sweep structurally could not find**, below.

**`reduce:279` takes all six verbs, not three.** It reads *"Pass: extends, contradicts, or deepens
existing {vocabulary.note_plural}"* and sits under `### 4. Connected`, closing with **"If ANY
criterion fails: do not extract."** It is therefore a gating **accept-list**, not an illustration:
a note whose relationship is *exemplifies*, *synthesizes* or *enables* fails the Connected
criterion and is silently not extracted. That is Finding 6's defect — a closed accept-list
dropping valid values — one layer earlier in the pipeline, and substituting only the three verbs
present would preserve it under new spelling. `reduce:494` is a template *hint*, not a gate, so it
keeps its three.

**Two carriers the `contradicts`-anchored sweep could not see.** Both hold a single verb, and the
sweep matches multi-verb lists; these were found by reading, as `wiki-links.md:36`/`:57` were.

| Site | Content | Treatment |
|---|---|---|
| `skill-sources/reduce/SKILL.md:781` | `- Good: "-- provides the foundation this challenges"` | Harmonize the literal — the deprecated `foundation` spelling, taught from a **Good** example, in a file this unit already edits. Same phrase as `wiki-links.md:57`, which this spec harmonizes; leaving the twin ships the dead verb from inside `reduce`. It reads as a noun in a prose gloss, so it harmonizes without a marker — same treatment as `:57`, and no effect on the count. |
| `skill-sources/reflect/SKILL.md:385-388` | `"extends"`, `"exemplifies"`, `"contradicts"`, `"synthesizes"` in the asymmetry guidance | Substitute. These are quoted verb *tokens*, so a vault that renames `extends` would find guidance naming a verb it does not have. This is what separates them from the two carriers ruled OUT below, which discuss relationship quality without naming spellings. |

**State the closure as "7/7 declared enum sites, plus 3 harmonized literals" — and say that the
literal count is a floor.** The declared class is closed and verified. The literal-carrier class
is not a census: the sweep finds multi-verb lists by construction, so every single-verb carrier in
this spec arrived by reading. Two were found this way after the inventory was called complete.
Naming some gaps makes the unlisted ones read as covered, so: the declared class is 7 of 7; the
literal class is 3 found, of an unknown total.

**Harmonize** — `generators/features/wiki-links.md` gets the canonical words as *literals*:
`:48-53`'s `foundation`→`grounds` and `example`→`exemplifies`, a `synthesizes` row added, and the
two prose carriers at `:36` and `:57` brought into line. No placeholder, no marker family, no gate
scope change — this is the scoping rule applied, and it is what lets E-1 close at 7 of 7 rather
than 6 of 7 with a deferral. It moves no placeholder count, so it perturbs no tally.

The frozen mirror keeps the old spellings: `platforms/shared/skill-blocks/validate.md:159` and
`verify.md:226` carry `extends, foundation, contradicts, enables, example` and are cksum-pinned.
**After this unit, that tree visibly disagrees with both live trees.** That is expected — its
parity is explicitly unmaintained — and is recorded here so a future reader files it as known
rather than as a fresh defect.

**Re-derive** — the tallies Unit 1 repaired move again, and this unit owns updating them at
**all three** carriers, not two: `CLAUDE.md:124`, `reference/skill-authoring.md:70`, and
`reference/check-placeholder-count.sh:43`. A draft of this unit named only the first two. Unit 1
repairs three sites and this unit re-derived two, so the gate comment would have shipped a number
this same spec falsified one unit later — the ratchet where a fix stales the count it documents.
The carriers are not interchangeable: `skill-authoring.md:70` states all three file-pairs on one
line, while `CLAUDE.md:124` and `check-placeholder-count.sh:43` state only `verify`'s.

Capture the numbers **at the substitution**, not afterwards: a figure recalled after the fact is a
reconstruction. No gate reads either number (`/usr/bin/grep -c '146\|203'
reference/check-doc-claims.sh` → 0), so nothing will catch it if this step is skipped — which is
precisely why it is a numbered step and not a note.

**State the expected value before running the command.** `check-placeholder-count.sh` is
range-relative against the merge base with `main` (deferral #18), so PR 2 surfaces a count move
that has to be attributed to a cause. A step that says "re-derive" without a predicted number
gives up exactly the attributability packaging B exists to buy. Baselines re-derived on `develop`
with `reference/skill-authoring.md` §2's command, `awk` substituted for its two `wc` calls:

| File | Baseline | E-1 sites | Markers added | Expected after Unit 3 |
|---|---|---|---|---|
| `skill-sources/verify` | 30 | `:197` (5 literals → 6 markers) | +6 | **36** |
| `skill-sources/validate` | 5 | `:146` (5 → 6) | +6 | **11** |
| `skill-sources/reflect` | 123 | `:295-300` (6 rows) + `:378` (6) + `:385-388` (4) | +16 | **139** |
| `skill-sources/reduce` | 132 | `:279` (**6**, accept-list) + `:494` (3) + `:781` (literal, +0) | +9 | **141** |

Total `skill-sources/` delta **+37**. Two sites yield six markers from five literals because
`verify` and `validate` declare a five-verb list whose spellings are wrong; harmonizing onto the
six-verb enum adds a member as well as renaming two. `reduce:279` yields six from three under the
accept-list ruling above, and `reduce:781` harmonizes a literal without adding a marker. A
measured delta that is not +37 means the substitution missed a site or hit one twice —
investigate before repairing the prose, because the prose is downstream of the count.

**No site sits in an executable ` ```bash ` fence**, so the fence gate is unaffected:
`reduce:494` is inside ` ```markdown ` and the other five are in bare markdown tables or prose.
Re-confirm this if a site moves, since the fence gate executes every ` ```bash ` block against a
generated-vault fixture where `skill-sources/` does not exist.

Only the `rel_*` substitution moves markers; the harmonize and re-derive halves do not. That keeps
`check-placeholder-count.sh`'s delta attributable to a single cause.


### Unit 4 — consume. (PR 2)

`Finding 6`: `hooks/scripts/session-orient.sh:151` gains an unknown-status branch. The accept-list
stays; what changes is that items matching neither it nor a known closed state are counted and
reported, rather than silently dropped between numerator and denominator.

**The residual, and the closed lists it needs.** Compute per directory, independently:

```
unknown = total − matched − known-closed        (per register, independently)
```

**A prior revision called this "enum-free" and claimed "nothing enumerates". That was false, and
the correction matters more than the error.** `known-closed` cannot be computed without naming the
closed statuses somewhere: `count_open_items()` (`session-orient.sh:149-152`) matches only
`pending open`, and the totals at `:158-159` count every `.md` recursively. There is no third
quantity in between. Building the branch forces two literal argument lists — observations
`promoted implemented archived`, tensions `resolved dissolved promoted implemented archived
blocked` — and pretending otherwise would have sent an implementer looking for a formulation that
does not exist.

**Those lists are not a #12 instance, which is why this unit still travels without #12.** The
scoping rule sorts on the *tree*, and `hooks/scripts/` is live code, not a template. It carries
zero `{vocabulary.*}` markers (`/usr/bin/grep -rc '{vocabulary\.' hooks/scripts/` → 0 in every
file), and its own comment at `:257` records that the `{{TENSION_THRESHOLD:-5}}` forms "are
substituted by nothing in this repo." Nothing there resolves a placeholder, so no placeholder is
due. The hook already hardcodes the other half of the same enum one line away —
`count_notes_by_field "$1" status pending open` at `:151` — and no one has ever called that a #12
instance. #12's shape is literals where placeholders are *due*, in a tree that resolves them; the
scoping table sorts F6 as `hooks/scripts/ | logic | in` for exactly this reason.

**Two lists, one per register — never a union.** Their enums genuinely differ
(`self-evolution.md:88` vs `:220`), and `count_open_items()` serving both registers
(`:163,167`) makes a shared list the tempting shortcut. A union over-matches closed, which
**under-reports unknown** — the silent direction, and the exact failure this unit exists to close.
Put the source line in a comment beside each list so the next reader can check it.

`count_open_items()` takes only `<dir>` and hardcodes its accept-list, so the closed count needs
either a sibling function or a parameterized call. Say which in the plan; left unstated, an
implementer inlines a third variant of the same scan.

**Report the values, not just the count.** Beside the CONDITION, emit the distinct status values
actually found outside the accept-list, using the library's own documented idiom
(`reference/lib/frontmatter.sh:80-95`): a `frontmatter_field` loop piped through `sort | uniq -c`.
That names `wontfix` or `superseded` where a bare residual says only "3". It enumerates nothing —
it discovers — but it cannot drive the threshold, because it cannot tell a legitimate closure from
an unknown without the closed list above. Diagnostic on stderr; the count drives the CONDITION.

This was previously sequenced "after #12" on the assumption it needed #12's *converted* enum. It
does not: it needs two literal lists in a tree where literals are correct.

Report it — do not merely count it. A silent unknown-status bucket is the same defect one layer
down.

**The residual must be OMITTED, not reported as 0, when the frontmatter library is missing.**
This is the sharpest hazard in the unit and it is not symmetric with the counts beside it.
`OBS_TOTAL`/`TENS_TOTAL` come from `find` (`session-orient.sh:158-159`) and are still correct with
`ops/lib/frontmatter.sh` gone, while `OBS_COUNT`/`TENS_COUNT` are deliberately left `""`
(`:160-171`, guarded by `FM_OK`). So `unknown = total − matched − known-closed` written the obvious
way evaluates against empty strings and either errors or reports **the entire register as
unknown** — a fabricated alarm arriving at precisely the moment the tooling is broken. The new
branch must sit inside the existing `[ "$FM_OK" -eq 1 ]` guard and emit nothing outside it. The
file's own comment at `:132-136` already states the principle for the counts; this extends it to the
residual.

**Executable coverage is part of this unit.** `reference/test/hook-config.test.sh` is, per
`docs/verification.md`, the only gate that executes `session-orient.sh`; its fixtures carry
`status: open` and `pending` only, so the new branch would land with none. Add unknown-status
fixtures to that suite. This extends an existing suite rather than adding a gate or a CI step, so
the no-new-gate constraint holds.

**Extending the suite turns `check-doc-claims.sh` RED, and two documents must move in the same
commit.** This is the sharpest sequencing hazard in the spec and an earlier revision missed it
entirely while claiming the opposite. `check-doc-claims.sh` does not merely grep: `truth_suite()`
at `:67` *runs* each suite (`line=$(bash "$f" 2>/dev/null | tail -1)`) and compares the passed
total against pinned declarations. `hook-config.test.sh` is pinned at **60** in exactly two places:

| Carrier | Text | Gate claim row |
|---|---|---|
| `docs/verification.md:36` | `$s reference/test/hook-config.test.sh   # 60/60` | `:334` |
| `CONTRIBUTING.md:114` | `$s reference/test/hook-config.test.sh \| tail -1   # expect: passed=60 failed=0` | `:319` |

Any fixture or assertion Unit 4 adds moves the total off 60 and the gate fails with *"document
says 60, tree measures N — Fix document, not gate."* Both carriers join Unit 4's edit list and are
updated in the same commit as the assertions. The gate goes red through its **data** changing, not
its logic — which is why the earlier "no gate-logic risk" framing did not catch it.

**Two carriers, and that is measured, not assumed.** A repo-wide sweep
(`git -c core.quotePath=false ls-files | xargs /usr/bin/grep -n 'hook-config.*60\|60.*hook-config'`)
returns a third hit in `docs/superpowers/reviews/2026-08-24-vocabulary-integrity-review.md:288`,
which cites `:60` as a *line number*, not a total — a false positive. Unlike the `27` tally, which
had three carriers where a draft of this spec said two, `60` genuinely has two. Re-run the sweep
before editing rather than trusting this sentence.

**The baseline is 60 under both shells** (`bash` and `zsh` each print `passed=60 failed=0`), so
there is no pre-existing shell divergence to work around. The gate pins the `bash` total
specifically, since `truth_suite()` hardcodes `bash "$f"`.

**Phrasing constraint on the new report line.** The suite pins negatives on the substrings
`pending observations` and `0 pending observations` (`:324-327`) and on
`^CONDITION: 0 pending observations` (`:350-353`). The residual line must not contain the
substring `pending observations` — the natural phrasing "N pending observations with unknown
status" trips four assertions. Use the register name and the condition instead, e.g. *"N
observations carry a status outside the recognized set (of M total)"*.

**The suite's existing pinned assertions do not break — and that is not reassurance.** The
omitted-not-zero assertions at `:324-330` match the literal string `pending observations`, which
the residual line will not contain, so they stay green whatever Unit 4 does. They are negative
assertions, and a negative assertion passes on absence: they would report green against a residual
branch that emits nothing at all, and equally green against one that fabricates a total. Unit 4
therefore adds its **own** pair, mirroring their shape — the signal is omitted when the library is
gone, and specifically is not rendered as `0` — plus a positive assertion that a fixture carrying
an off-enum status is actually counted and named. Without the positive arm the whole set passes on
a branch that never fires.

**The zsh hazard is live here regardless of the shebang.** That suite invokes the hook as
`$SH hooks/scripts/session-orient.sh` (`:111`) with `SH=zsh` under zsh (`:60`), overriding the
script's own interpreter. `status` is a read-only special variable in zsh and assigning it aborts
fatally — this unit edits status-handling code under exactly that execution path.

### Unit 5 — independent. (PR 2)

- `E-4`: strip the leading slash at 11 sites — `graph` ×6, `reduce` ×3, `stats` ×2
- `#6` + entry 32 item 1: `~150` → `200` at `atomic-notes.md:75` and `schema.md:18`

**The `~150` residue is twelve normative sites, not two, and a two-site edit does not close
entry #6.** The discovery command in [Measurements](#measurements) scoped `generators/` and
`skill-sources/`; the string lives in five other trees. Re-derived tree-wide:

```bash
git -c core.quotePath=false ls-files -z | xargs -0 /usr/bin/grep -n '~150'   # 75 hits, 36 files
```

Normative description-length carriers, all of which must move to `200` together:

| Site | Count | Why it binds |
|---|---|---|
| `generators/features/atomic-notes.md:75`, `generators/features/schema.md:18` | 2 | The originally-named pair |
| `reference/kernel.yaml:57` | 1 | **The invariant contract.** The highest-authority surface in the repo would otherwise disagree with the generators feeding it |
| `reference/templates/*.md:2` — `base-note`, `companion-note`, `creative-note`, `learning-note`, `life-note`, `relationship-note`, `research-note`, `therapy-note` | 8 | Shipped note templates; every vault instantiating one is taught `~150` |
| `reference/methodology.md:55` | 1 | Reference doc carrying the same description line |

`reference/claim-map.md:84` (*"~150 chars may not accommodate all styles"*) is **KEEP**: it
discusses the tension rather than declaring the value, and rewriting it to `200` would erase the
record of why the question was open. Note the secondary split while editing — `schema.md:18` and
`base-note.md:2` carry a `no period` clause that the other ten sites lack; carry the clause
uniformly rather than preserving the inconsistency.

**Excluded, stated so the class size is explicit rather than implied.**
`platforms/shared/skill-blocks/reduce.md:501,753` — the cksum-frozen mirror, expected stale by
design. The `methodology/` research corpus — it discusses the convention as historical research
content, and 249 atomic claims are not a declaration surface. Two false hits:
`skills/architect/SKILL.md:482` (*"line ~150"*, a line number) and
`reference/semantic-vs-keyword.md:244` (*"~150 notes"*, a volume threshold).

Entry #6 states its own condition: *fix them together or not at all*. Editing the two
`generators/` sites while ten normative carriers keep saying `~150` closes the entry while the
disagreement survives — including in the kernel contract. **This is the same failure this spec
diagnoses for E-1: a discovery command too narrow to see its own class.** Having caught it there
and reproduced it here one section later is the argument for re-running every count tree-wide
before acting on it.

## Constraints

- **`platforms/shared/skill-blocks/` is cksum-frozen at any depth** (`check-portability.sh`
  check 4, `README.md` the single exception). It mirrors roughly six E-1 sites (`extends,` in
  `reduce.md` ×2, `reflect.md`, `validate.md`, `verify.md`, plus `reflect.md`'s six-row table) and
  seven slash-prefixed `cmd_*` markers for E-4 across `graph.md`, `learn.md`, `reduce.md`. A prior
  revision stated "four E-1 sites and two E-4 sites" — the only figures in this spec given without
  a command, and neither survived one. **They keep the old spellings, by design** — that tree is a read-only inventory whose parity with
  `skill-sources/` is explicitly not maintained. Anyone "helpfully" syncing it turns the gate red.
- **`check-doc-claims.sh` reads by text anchor.** Do not reword a sentence stating a number
  without running that gate.
- **Both shells, every gate run:** `for s in bash zsh; do $s <gate>; done`.
- **macOS `/bin/bash` is 3.2**, and three of five gates already fail to parse under it while
  exiting 0. Run gates as `/opt/local/bin/gtimeout 500 /opt/local/bin/bash reference/<gate>.sh`.
  `timeout` does not exist on macOS — it returns 127 and the outer shell still exits 0.
- **`status`, `path`, `options`, `argv`, `PATH` are RESERVED.** In zsh `status` is a read-only
  special variable and assigning it aborts the script fatally. Unit 4 edits status-handling code;
  this is a live hazard there.
- **Fail loud.** Exit 0 with empty output is this repo's documented failure mode. Every new
  assertion pairs a negative expectation with a positive one that proves the probe still binds.
- **No agent attribution in commit messages** (Rule 14).

## Gates

No new CI gate and no new CI step. `check-doc-claims.sh` asserts declared numerals inside
`CLAUDE.md`, including counts of the repo's own checks and steps; adding either moves those
numbers and turns it red.

**No gate's logic is modified either.** An earlier revision had Unit 3 co-editing
`check-doc-claims.sh`'s `enum_values()` normalizer, because `{vocabulary.status_*}` in
`generators/` collapses that gate's extraction to a single garbage token and trips its under-2
guard into rc 2. That was a real defect and a correct fix — it travels with deferral #12 to the
companion spec. With #12 resequenced out, this gate never sees a placeholder and is left untouched.
**PR 2 therefore carries no gate-logic risk at all**, which is the concrete payoff of the scoping
rule.

Stated precisely, because the claim is narrower than it sounds: no gate *script's logic* is
modified. Two executable files are still touched — `check-placeholder-count.sh:43`, a comment
carrying a rotted numeral (Unit 1), and `reference/test/hook-config.test.sh`, which gains fixtures
and assertions (Unit 4). Neither changes a gate's decision procedure, but "no gate-logic risk" is
not the same as "no executable file is edited", and a plan step that conflates them will skip
running the suite it just changed.

**The boundary check is the full CI suite, not the five gates.** `.github/workflows/checks.yml`
runs ~12 test suites beyond `check-*.sh`, each under bash *and* zsh — including
`reference/test/hook-config.test.sh`, the only executor of Unit 4's target. Naming only the five
gates would have let Unit 4 merge with zero executable coverage of its new branch. Run the fence in
`docs/verification.md` at each unit boundary; the five gates are a subset of it, not a substitute.

```bash
/opt/local/bin/gtimeout 500 /opt/local/bin/bash reference/check-doc-claims.sh | /usr/bin/grep 'CI steps'
#   .github/  CI steps vs main  ok  32 here, 32 on main
```

**The gate passes today over both rotted numerals** — verified, exit 0, and its output contains no
occurrence of `27`, `30`, `121` or `123`. Its own verdict line states the limit honestly:
`DOC CLAIMS: PASS (declared claims only — bash-run totals only)`. A green run from this gate has
never meant the documented numbers are true, and Unit 1 does not change that. Closing it is the
numeral-gate spec's job.

`check-placeholder-count.sh` will legitimately move in **Unit 3 only**. A prior revision said
Units 2 and 3, and the reason given for the correction was itself wrong: it claimed Unit 2 touches
no `skill-sources/` file, which the same revision's own fold falsifies — Unit 2 edits
`skill-sources/rethink/SKILL.md` at `232`, `233`, `335`, `516` and `:357`. The conclusion survives
on a different premise: those rethink edits add no placeholders, so the gate's count does not move
even though the tree it scans is touched. It also fails only on a
*decrease*, so it never enforces the additions this spec makes; the per-unit before/after
bookkeeping is worth doing for attribution, but do not mistake it for enforcement.

## What is NOT claimed

- **No gate asserts any of these vocabularies is now correct** — only that markers resolve.
  Cross-surface *agreement* remains unenforced after this spec ships. Designing that mechanism is
  `docs/superpowers/specs/2026-08-24-rot-prone-numeral-gate-design.md`, deliberately separate.
- **`closes:` is not validated for accuracy.** See Decision 2.
- **The `~150`/`200` question is settled by `next-sprints.md`'s "200 is canonical" ruling**, which
  settles the *value*. It does not settle boundary semantics — `<` versus `≤` at exactly 200 is
  field-intel finding 14 and is **not** in this spec.

## Deferred out of this spec

| Item | Why |
|---|---|
| Finding 14 — `<` vs `≤` at exactly 200 | Different axis from #6; ships with whatever settles inclusivity everywhere |
| A `mitigated` status value | See Decision 2; revisit after Finding 6 |
| E-2, E-3 backports | Divergence direction unconfirmed; `refactor` and `seed` are stale 0.9.7 copies |
| E-2's library dependency | Its scan needs a `reference/lib/` counterpart to `inbound-edges.mjs`; library first, prose second |
| **Deferral #12** — status literals → `{vocabulary.status_*}` in `generators/` | **Resequenced**, not dropped. It is a new placeholder family in a tree with no vocabulary-resolution mechanism and no gate coverage (see *The scoping rule*). It travels with the `enum_values()` normalizer fix it forces. |
| Vocabulary resolution for `generators/features/*.md` | The prerequisite #12 turned out to need: document `{vocabulary.*}` substitution in the composition path and widen a gate's scope, or rule that tree permanently `{DOMAIN:*}`-only |
| Cross-surface agreement gate | Its own spec, already in flight |
| SkillEvaluator adoption | Different axis — evaluation posture, not vocabulary integrity |
