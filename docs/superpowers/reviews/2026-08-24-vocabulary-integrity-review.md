# Adversarial review — vocabulary integrity design spec

**Spec:** `docs/superpowers/specs/2026-08-24-vocabulary-integrity-design.md`
**Tree:** `develop` @ `db399d8` (clean). All commands below were run against this tree on 2026-08-24.
Gates and fixtures were executed with `/opt/local/bin/bash`; nothing in the repo was modified —
gate experiments used `SCAN_ROOT`/`SCHEMA_FILE` overrides against scratchpad fixtures.

**Verdict: 4 Critical, 5 Major, 7 Minor.** The measurements largely reproduce and the
declare-before-use ordering argument is empirically correct, but the spec's site inventory was
scoped to the trees its source entries came from and never swept `generators/` for E-1 or the
closure-writing skill for Decision 2 — and Unit 3 as written turns `check-doc-claims.sh` red via
a structural check the spec never mentions.

---

## What reproduces (verified, no finding)

| Claim | Result |
|---|---|
| 11 slash-prefixed `/{vocabulary.cmd_*}` sites; 28 total (11 + 17 bare) | reproduces exactly |
| E-4 per-file: `graph` ×6, `reduce` ×3, `stats` ×2 (skill-sources) | reproduces exactly |
| Field-vault rendered probe: 9 `//reflect`, 1 `//reweave`, 1 `//verify`, 1 `//github` | reproduces exactly |
| E-1 line numbers `reflect:378`, `validate:146`, `verify:197`, `reduce:279`, `reduce:494`; table near `reflect:291-303` | reproduce (table rows sit at 293–300) |
| #12: 4 declarations in 3 files (`atomic-notes.md:94`, `schema.md:30`, `schema.md:142`, `templates.md:30`) | reproduces exactly |
| F6: `session-orient.sh:151` `count_notes_by_field "$1" status pending open` | reproduces exactly |
| `~150` at `atomic-notes.md:75` and `schema.md:18`; `200` canonical per `docs/superpowers/next-sprints.md:171` | reproduces |
| F15: `self-evolution.md` lines 88/102/220/240 | reproduce verbatim |
| Tallies: verify 30/146, validate 5/60, reflect 123/203; `grep -c '146\|verify.*27' check-doc-claims.sh` = 0 | reproduce |
| Vault falsified closure: `falsified_implemented_in: ops/scripts/health_check.py`; file is 101 lines, 0 hits for claimant/claimed/coverage | reproduces exactly |
| Schema block bounds `skills/setup/SKILL.md:1149`–`:1192`; gate sed matches spec's quote verbatim (`check-vocabulary-schema.sh:73`) | reproduces |
| Ordering direction: undeclared `rel_*` marker in scope → gate exit 1; six keys inserted flat before `# Level 7:` → picked up, exit 0; key placed after the marker → exit 1 | **all three confirmed by fixture** (`SCAN_ROOT`/`SCHEMA_FILE` overrides) |
| zsh `status` hazard is live for Unit 4: `hook-config.test.sh:111` runs `$SH hooks/scripts/session-orient.sh` with `$SH` ∈ {bash, zsh} in CI, overriding the `#!/bin/bash` shebang | confirmed |
| Frozen tree: `reference/skill-blocks.frozen` exists; `check-portability.sh:219` keys on the manifest | confirmed |
| `/opt/local/bin/gtimeout` exists; deferrals entries 6, 12, 32 exist; `docs/superpowers/specs/2026-08-24-rot-prone-numeral-gate-design.md` exists | confirmed |
| Unit 4 does not contradict the reasoning at `session-orient.sh:118-127` — those comments justify the open-of-total report; an unknown-status bucket extends, not reverses, that reasoning | confirmed by reading |
| Decision 2 `closes:` breaks no parser: `reference/lib/frontmatter.sh` extracts named fields and rejects nothing unknown; kernel fixtures construct observations with arbitrary small key sets | confirmed (see m7 for the asymmetry it does create) |

---

## Critical

### C1 — Unit 3's #12 substitution turns `check-doc-claims.sh` red, and the spec does not know it

**Spec says:** "All five existing gates must pass at each unit boundary" (Gates), with
`check-doc-claims.sh` mentioned only as a reason not to reword numeral-bearing sentences.

**Actually true:** `check-doc-claims.sh:507-592` carries a *structural* check the spec never
cites: it discovers the note status enum by grepping `preliminary` in `generators/`
(count pinned, `NOTE_ENUM_DECLS=4` at `:551`), then extracts each declaration's value set with
`enum_values()` (`:560`) and requires one agreed set. After substituting
`{vocabulary.status_*}` at the four sites, discovery still finds 4 lines
(`status_preliminary` contains `preliminary` as a substring), but extraction collapses:

```bash
enum_values() { sed 's/.*enum//' | sed 's/.*status[`:]*//' | tr -d '`|,[]' \
                | tr -s ' ' | sed 's/^ *//;s/ *$//' | tr ' ' '\n' | grep -v '^$' | LC_ALL=C sort -u; }
printf 'status: {vocabulary.status_preliminary} | {vocabulary.status_open} | {vocabulary.status_active} | {vocabulary.status_archived} | {vocabulary.status_superseded}\n' | enum_values
# -> _superseded}        (ONE value; the greedy `.*status` eats through the last "status_")
```

One value trips the `nv -lt 2` guard at `:576` → "extraction yielded under 2 values … the
declaration form changed" → `errors` → **rc 2** (`:661`). CI runs this gate
(`.github/workflows/checks.yml:63`). The gate's own failure text says "Fix the document, not
the gate" (`:666`) — but here the document change is the intent, so the *gate* needs a
redesigned discovery/normalisation and a re-pin, which is exactly the cross-surface-agreement
mechanism work this spec explicitly defers to the rot-prone-numeral-gate spec.

**Correction:** the spec must choose and say so: either (a) Unit 3 co-edits
`check-doc-claims.sh`'s note-enum check to extract placeholder keys and compare key sets
(re-pinning `NOTE_ENUM_DECLS` semantics), acknowledging PR 2 now carries gate-logic risk; or
(b) #12 moves out of this spec into the agreement-gate spec. As written, PR 2 cannot merge.

### C2 — E-1's inventory misses a seventh declaring site: `generators/features/wiki-links.md:48-53`

**Spec says:** "six declaring sites, four distinct spellings"; "`deepens` and `builds on` occur
nowhere else in the repo."

**Actually true:**

```bash
/usr/bin/sed -n '48,53p' generators/features/wiki-links.md
# Standard relationship types:
# - **extends** — builds on an idea by adding a new dimension
# - **foundation** — provides the evidence or reasoning this depends on
# - **contradicts** — ...
# - **enables** — ...
# - **example** — ...
```

This is a full declaration of the verb enum, in the `foundation`/`example` spelling, inside the
feature block that composes into **every generated vault's CLAUDE.md** — the always-loaded
context file. Unit 3 substitutes six sites in `skill-sources/` and leaves this one, so after the
spec ships, a vault's skills speak the derived `rel_*` terms while its CLAUDE.md still hardcodes
`foundation`/`example` — *one vocabulary, several surfaces, no agreement*, surviving at the most
visible surface. The discovery command (`grep -rn 'extends,' skill-sources/`) was scoped to
`skill-sources/` and can never have seen it. The "nowhere else" claim is also measured false:
`builds on` at `wiki-links.md:36,49` and `deepens` in two `methodology/` files (illustrative
prose, but "in the repo" is the spec's own quantifier).

**Correction:** add `wiki-links.md:48-53` (and the inline example at `:36`, plus `:57`'s
"provides the foundation") to Unit 3's site list — which compounds C1's problem, since this too
is `generators/`, outside `check-vocabulary-schema.sh`'s scope (see M3). Re-derive the site
inventory with a repo-wide sweep, not a per-tree grep.

### C3 — Decision 2 never reaches the code path that writes closures

**Spec says:** Unit 2 adds `closes:` "on both observation-status blocks,
`generators/features/self-evolution.md:102` and `:240`", making it "a required companion field."

**Actually true:** the surface that *writes* `status: implemented` in a generated vault is the
`/rethink` skill, and its template instructs the closure recipe in full — without `closes:` — at
four sites, with a fifth asserting the pairing rule:

```bash
/usr/bin/grep -n 'set `status: implemented`' skill-sources/rethink/SKILL.md
# 232, 233, 335, 516  ("set `status: implemented`, add `implemented_in: [filepath]`")
# 357 asserts: `implemented` with no `implemented_in:` is [an error]
```

Unit 2 touches none of them. A generated vault therefore carries a schema doc requiring
`closes:` and a skill whose closure recipes omit it — two emitted surfaces of one contract that
do not agree, which is this spec's own definition of the defect class. The falsified closures
that motivate Decision 2 were produced by exactly this flow; implementing the spec verbatim
changes that flow's output not at all.

**Correction:** Unit 2 (or a Unit 3 twin) must extend every `set status: implemented, add
implemented_in` recipe in `skill-sources/rethink/SKILL.md` — and `:357`'s pairing assertion —
to include `closes:`. Sweep `skill-sources/` for other closure writers before pinning the list.

### C4 — The spec re-rots the numerals Unit 1 repairs, and assigns the re-repair to nobody

**Spec says:** Unit 1 repairs `CLAUDE.md` 27→30 and `skill-authoring.md` 121→123; the
Measurements section notes "E-1 changes these counts again."

**Actually true:** noting the interaction is not scheduling the work. Unit 3 adds `rel_*`
markers to `verify`, `validate`, `reflect`, `reduce`; the verify/validate/reflect source tallies
all move (verify 30 → ~35, reflect 123 → ~130+, exact deltas depending on M4's unresolved
mapping). No unit's edit list touches `CLAUDE.md:123-124` or `skill-authoring.md:70` after
Unit 1, and no gate reads either number (`grep -c '146\|verify.*27' reference/check-doc-claims.sh`
→ 0, reproduced). The post-implementation tree therefore states documented tallies that are
wrong the moment PR 2 merges — a fresh instance of the stale-ungated-numeral defect this spec
opens by condemning, minted by the spec itself.

**Correction:** Unit 3's edit list must include re-deriving and updating both tally sentences
(and Unit 1's "born-red" protocol should be repeated there), or the spec must state explicitly
that PR 2 ships stale tallies pending the rot-prone-numeral gate.

---

## Major

### M1 — Unit 1 is incomplete: the line it edits still carries a second rotted numeral

`reference/skill-authoring.md:70` reads: "That yields `verify` 27 against 146 and `validate` 5
against 60, while `reflect` is 121 against 203". Unit 1 repairs the `121` on this line and
leaves the `27` — same measurement, same staleness (source is 30), same sentence. The spec's
Measurements annotation ("`<- CLAUDE.md:123 states 27` … `<- skill-authoring.md §2 states 121`")
implies one stale numeral per file, which is what the survey missed. A third carrier,
`reference/check-placeholder-count.sh:43` ("146 in `verify` where skill-sources has 27", a gate
comment), needs an explicit keep-or-fix ruling. **Correction:** Unit 1 becomes three edits in
two prose files plus a ruling on the gate comment; re-derive with
`grep -rn 'has 27\|verify.*27' CLAUDE.md reference/`.

### M2 — The verification protocol omits the CI suites, including the only one that executes Unit 4's target

"All five existing gates must pass at each unit boundary" — but `.github/workflows/checks.yml`
runs ~12 test suites beyond the five `check-*.sh` gates, each under bash *and* zsh.
`reference/test/hook-config.test.sh` is, per `docs/verification.md`, the **only** gate that
executes `hooks/scripts/session-orient.sh`; it invokes it as `$SH hooks/scripts/session-orient.sh`
(`:111`), so Unit 4's edit runs under zsh in CI regardless of the shebang — this is where the
spec's own read-only-`status` constraint actually bites. Its fixtures contain only
`status: open`/`pending`, so Unit 4's unknown-status branch lands with zero executable coverage,
against this repo's explicit convention (the suite exists because session-orient once had "only
TEXTUAL coverage"). Whether the new report line breaks the suite's pinned negative assertions
(e.g. `:325-327`) is **UNVERIFIED** — I did not construct that run — but the coverage omission
stands either way. **Correction:** the boundary protocol must name the suites; Unit 4 must
extend `hook-config.test.sh` with unknown-status fixtures (not a new gate or step, so the
constraint holds).

### M3 — #12 plants the first `{vocabulary.*}` markers into a tree where nothing resolves or checks them

`generators/` today contains **zero** `{vocabulary.*}` markers against 631 `{DOMAIN:*}`
(`grep -roh '{vocabulary\.[a-z_]*}' generators/ | awk 'END{print NR+0}'` → 0). The tree's
native placeholder family is `{DOMAIN:*}`; `check-vocabulary-schema.sh` excludes `generators/`
by SCOPE (`:12-15`, `:60`), and `check-placeholder-count.sh` likewise (`:37-47`). So Unit 3's
`{vocabulary.status_*}` markers are (a) a new marker family in that tree, contrary to its
convention, (b) resolved by no documented mechanism in the CLAUDE.md composition path
(`generators/claude-md.md` instructs `{DOMAIN:*}` usage and prose-level vocabulary transforms,
never `{vocabulary.X}` substitution), and (c) gated by nothing — a typo'd
`{vocabulary.status_preliminery}` there ships silently into every vault. The spec addresses none
of this. **Correction:** either use the tree's `{DOMAIN:*}` family (whose fold the schema gate
already defines) with the schema-gate scope question addressed, or document `{vocabulary.*}`
resolution for feature blocks in `generators/claude-md.md` and extend a gate's scope to cover
them — and say which, in the spec.

### M4 — The E-1 substitution is underdetermined at four of the six sites

`validate:146` and `verify:197` list *five* verbs (`foundation`, `example`, no `synthesizes`);
`reduce:279` lists three (`… or deepens`); `reduce:494` lists three (`… builds on`). "Six verb
sites → `{vocabulary.rel_*}`" does not say whether the five-verb tables gain
`rel_synthesizes`, nor what `deepens` and `builds on` map to — and the spec's own Level 6.6
block lists "builds on" as an *example value of* `rel_extends`, so mapping `builds on` →
`{vocabulary.rel_extends}` makes `reduce:494` read "extends, contradicts, extends" in the
default derivation. Different implementers produce materially different templates and different
tally deltas (compounding C4). **Correction:** a per-site before/after table in Unit 3, one row
per verb occurrence.

### M5 — Unit 4's "rest of the enum" has no source, and the obvious implementation re-creates defect #12

The unknown-status branch needs the enum to define "unknown" — but `count_open_items` serves
*both* `ops/observations` and `ops/tensions` (`session-orient.sh:163,167`) and their enums
differ (`self-evolution.md:88` vs `:220`). The spec's one-line instruction does not say where
the enum(s) come from; hardcoding them in `session-orient.sh` adds a fifth and sixth literal
enum declaration in yet another file — the exact "literals where placeholders are due" shape of
#12, in the hook `docs/verification.md` already flags as the observation enum's only consumer
"in another tree." **Correction:** specify per-directory enums (or an enum-free formulation:
report `total − matched − known-closed` per directory), and where the values are sourced from.

---

## Minor

1. **Unit 1's edit site is off by one line.** The numeral `27` sits on `CLAUDE.md:124`; line 123
   ends "…`skill-sources` has" (hard-wrapped sentence). `/usr/bin/sed -n '123,124p' CLAUDE.md`.
   Say `CLAUDE.md:123-124` or anchor on the sentence.
2. **The frozen-mirror counts do not reproduce.** Spec: skill-blocks "mirrors four E-1 sites and
   two E-4 sites." Measured: `extends,` lines in `reduce.md` ×2, `reflect.md` ×1, `validate.md`
   ×1, `verify.md` ×1, plus the six-row table in `reflect.md` (`grep -c exemplifies` → 3) ≈ six
   E-1 sites; and 7 slash-prefixed `cmd_*` markers across three files (`graph.md` 2, `learn.md`
   2, `reduce.md` 3) for E-4. These are the only numbers in the spec stated without a command,
   and neither survives one. No behavioral consequence (the tree is frozen either way).
3. **"all four of which appear in the documented tallies" is false for `reduce`.**
   `grep -c '155\|132' CLAUDE.md reference/skill-authoring.md` → 0 and 0. Three of four appear.
4. **"check-placeholder-count.sh will legitimately move in Units 2 and 3" is false for Unit 2.**
   Unit 2 edits `skills/setup/`, `reference/`, and `generators/` — no `skill-sources/` file — and
   the gate scans `skill-sources/` only and fails only on *decrease*. The per-unit before/after
   bookkeeping is sound advice, but the gate itself never enforces it for additions.
5. **Decision 2 calls `self-evolution.md:220/:240` an "observation-status block"; it is the
   tensions register's block** (the enum at `:220` carries `resolved | dissolved`; the `:240`
   bullet closes a contradiction). The edit is right; the label will misdirect a grep.
6. **The E-1 discovery command under-produces its own inventory.** `grep -rn 'extends,'
   skill-sources/` yields five sites; the sixth (the `reflect` table, rows at 293–300, spec says
   291–303) never matches `extends,`. The caption "six declaring sites" over a five-site command
   is the same command/claim mismatch that let C2 happen one tree over.
7. **`closes:` "advisory, not gated" creates an unacknowledged asymmetry with its sibling.**
   `validate-kernel.sh:1012-1014` already *enforces* `implemented → implemented_in` (non-empty)
   for observations and tensions; the spec's "a gate can confirm the field is present and
   non-empty" describes a check that exists, one token away from where `closes:` would go. The
   advisory choice may stand, but the spec should acknowledge it is declining an existing
   mechanism (and that adding it would require the kernel.yaml/validator sync CLAUDE.md
   mandates), not asserting one cannot exist.

---

## Assignment-specific answers

- **Ordering (priority 1):** the spec's Unit 2 → Unit 3 argument is **verified correct** for the
  `skill-sources/` half — `check-vocabulary-schema.sh` exits 1 on an undeclared `{vocabulary.X}`
  (fixture-confirmed), and passes with the six keys inserted before `# Level 7:`
  (fixture-confirmed). It is **vacuous** for the #12 half: the gate's SCOPE excludes
  `generators/` (`check-vocabulary-schema.sh:12-15`), so nothing enforces declare-before-use
  there (see M3). The ordering conclusion survives; its stated justification covers only rel_*.
- **`check-prose-paths.sh`:** scope is `CLAUDE.md` + three `docs/` files (`:44-48`); the spec
  file is not scanned, and every repo path the spec names exists (including
  `2026-08-24-rot-prone-numeral-gate-design.md` and `docs/superpowers/next-sprints.md`, whose
  `:171` carries the "200 is canonical" ruling). No finding.
- **`check-doc-claims.sh` vs Unit 1:** the gate does **not** anchor the CLAUDE.md:123-124 or
  skill-authoring §2 tallies (grep reproduced 0, with a positive control), so Unit 1 does not
  turn it red — the spec is right there. It is Unit 3 that turns this gate red (C1).
- **Scope (priority 7):** the repair-commit + two-PR packaging and the schema-boundary split are
  sound; this does not need decomposition. It needs a **revision**: C1 forces an explicit
  decision about co-editing a gate or resequencing #12; C2 and C3 mean the declared inventory is
  short by one tree in each direction. The five units survive; their edit lists do not.

---

## Independent verification (main session, 2026-08-24)

Every finding below was re-run against the tree rather than accepted from the report.

| ID | Verdict | Evidence |
|---|---|---|
| C1 | **Already fixed — reviewer read a draft** | Spec `:294-320` carries the unwrap-first `enum_values()` normalizer and names `NOTE_ENUM_DECLS=4` at `:551`. The review was dispatched before that edit landed. The diagnosis is identical to the one reached in-session, so this is corroboration, not a new defect. Its option (b) — resequence #12 out — is new and is adopted below for a different reason (M3). |
| C2 | **VERIFIED — real gap** | `generators/features/wiki-links.md:48-53` declares the enum in the `foundation`/`example` spelling. Seventh site, missed because the discovery grep was scoped to one tree. |
| C3 | **VERIFIED — real gap** | `skill-sources/rethink/SKILL.md` writes the closure recipe at `232, 233, 335, 516`; `:357` asserts the pairing rule. None carry `closes:`. `implemented_in` appears in exactly two files repo-wide (rethink + self-evolution). |
| C4 | **VERIFIED** | No unit's edit list touches the tally sentences after Unit 1; `grep -c '146' reference/check-doc-claims.sh` → 0, `'203'` → 0. PR 2 would ship tallies stale on merge. |
| M1 | **VERIFIED — third carrier confirmed** | `reference/check-placeholder-count.sh:43` carries `has 27` in a gate comment. Needs an explicit keep-or-fix ruling. |
| M2 | **VERIFIED** | `hook-config.test.sh:111` invokes `$SH hooks/scripts/session-orient.sh`; `:60` sets `SH=zsh` under zsh. The shebang does not protect Unit 4. |
| M3 | **VERIFIED — and decisive** | `generators/` holds **0** `{vocabulary.*}` against **527** `{DOMAIN:*}`. `check-vocabulary-schema.sh:12-15` excludes the tree with a stated rationale: feature blocks are *"composition blocks selected by config, not verbatim templates."* |
| M5 | **VERIFIED** | `session-orient.sh:163,167` — `count_open_items` serves both `ops/observations` and `ops/tensions`, whose enums differ. |
| m3 | **VERIFIED** | `grep -c '155\|132'` → 0 in both prose files. Three of four, not four. |
| m6 | **VERIFIED** | `grep -rn 'extends,' skill-sources/` yields **5**, not the 6 the caption claims; the `reflect` table never matches. |
| m7 | **VERIFIED** | `validate-kernel.sh:1012-1014` already enforces `implemented → implemented_in` for observations *and* tensions. The spec declines an existing mechanism; it must say so. |

### The finding the review did not draw

C1, C2 and M3 are one fact seen three times: **`generators/` has no vocabulary-resolution
mechanism, by documented design.** Two gates exclude it for the stated reason that feature
blocks are composed, not substituted. Deferral #12 lives entirely in that tree, and C2's
correction would put `{vocabulary.rel_*}` there too.

So the tree boundary — not the defect list — is what scopes this spec. See the revision note in
the design doc.
