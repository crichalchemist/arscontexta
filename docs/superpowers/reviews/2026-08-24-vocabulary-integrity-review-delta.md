# Delta review: vocabulary-integrity design spec (revision 2)

**Date:** 2026-08-24
**Subject:** `docs/superpowers/specs/2026-08-24-vocabulary-integrity-design.md` (606 lines; first review covered the 408-line revision)
**Tree:** `develop` @ `db399d8`, working tree clean
**Prior report:** `docs/superpowers/reviews/2026-08-24-vocabulary-integrity-review.md` (unmodified; its verification table remains load-bearing)
**Method:** every finding carries the command that proves it; inferences are marked UNVERIFIED. All gate and suite runs used `/opt/local/bin/bash` (and zsh where the fence requires it), never `/bin/bash` 3.2. Sandbox runs used full copies under the session scratchpad; no repo file was modified.

**Counts: 2 Critical, 5 Major, 5 Minor.** The prior review's one UNVERIFIED item is resolved below (§ "Resolved: the pinned-negative-assertion question") — the answer is favorable to the spec, with one phrasing constraint the spec must state.

---

## Critical

### D-C1 — Unit 4 turns `check-doc-claims.sh` red; the spec's headline "PR 2 therefore carries no gate-logic risk at all" (spec :559) is false

**What the spec says:** the new scoping rule resequences #12 out and concludes PR 2 has zero gate-logic risk (:559). Unit 4 (:482-516) extends `reference/test/hook-config.test.sh` with unknown-status fixtures and assertions.

**What is true:** `check-doc-claims.sh` does not merely grep — `truth_suite()` at `reference/check-doc-claims.sh:67` **runs each test suite** (`line=$(bash "$f" 2>/dev/null | tail -1)`) and compares the passed total against two pinned declarations:

- `docs/verification.md:36` — `reference/test/hook-config.test.sh  # 60/60` (claim row at gate :334)
- `CONTRIBUTING.md:114` — `# expect: passed=60 failed=0` (claim row at gate :319)

Any fixture or assertion Unit 4 adds moves the suite total off 60. Neither `docs/verification.md` nor `CONTRIBUTING.md` appears in any unit's edit list. The gate goes red not through its *logic* changing but through its *data* changing — which is exactly the class of path the delta tasking asked me to hunt ("any other path by which PR 2 touches gate logic or turns a gate red").

**Empirical chain (all four links run, none inferred):**

1. Baseline suite reproduced at 60/60 under both bash and zsh (sandbox `sim/`).
2. The gate's own sed expressions extract `60` from both documents:
   ```bash
   /usr/bin/grep -n 'hook-config' docs/verification.md CONTRIBUTING.md
   # docs/verification.md:36  ... # 60/60
   # CONTRIBUTING.md:114      ... # expect: passed=60 failed=0
   ```
3. A full repo copy with one additional assertion inserted before the summary line prints `passed=61 failed=0`.
4. `check-doc-claims.sh` over that copy exits **rc=1**:
   ```text
   CONTRIBUTING.md hook-config suite total MISMATCH document says 60, tree measures 61
   docs/verification.md hook-config fence total MISMATCH document says 60, tree measures 61
   DOC CLAIMS: FAIL — 2 stale claim(s). Fix document, not gate.
   ```
   Control run over the unmutated copy: rc=0, `DOC CLAIMS: PASS`.

**Correction:** add `docs/verification.md:36` and `CONTRIBUTING.md:114` to Unit 4's edit list (update `60` to the new total in the same commit as the fixture additions), and strike or qualify :559. The gate's own failure text names the required fix ("Fix document, not gate"). This does not invalidate the scoping rule itself — see the Q1 answer below — but the zero-risk claim as written sends an implementer into a red gate with no edit planned for it.

### D-C2 — Unit 4's formula names a term that has no enum-free source; "Nothing enumerates" is false as specified

**What the spec says:** Unit 4 computes `unknown = total − matched − known-closed` per directory, presented as the enum-free formulation that decouples Unit 4 from #12 (M5/M6 fold).

**What is true:** `known-closed` cannot be computed without enumerating the closed statuses somewhere. Building the working simulation (which passes 60/60 and fires correctly on a mixed vault) forced exactly that:

```bash
OBS_CLOSED=$(count_notes_by_field ops/observations status promoted implemented archived)
# tensions: resolved dissolved promoted implemented archived blocked
```

Those argument lists are the fifth and sixth literal status-enum declarations in the codebase — the precise artifact #12 exists to abolish and the unit's own rationale forbids planting. The two alternative readings both fail: `unknown = total − matched` (dropping the term) fires on every healthy vault that has any closed item; a location heuristic (e.g. closed = archived subdirectory) is nowhere stated and not currently true of the fixture layout or the field vault.

**Proving commands:** `count_open_items()` at `hooks/scripts/session-orient.sh:149-152` matches only `pending open`; totals at :158-159 count every `.md` recursively. There is no third quantity available without a closed list:

```bash
/usr/bin/sed -n '149,159p' hooks/scripts/session-orient.sh
```

**Correction (judgment call, flagged for the team-lead):** the decoupling is syntactic, not real. Either (a) accept one closed-set declaration in a single named place and have Unit 4 cite it as deliberate — which concedes Unit 4 genuinely depends on #12's normalizer and weakens the resequencing rationale, or (b) scope Unit 4 down to the fixture/assertion extension only and let the unknown-status *report line* travel with #12 to wherever #12 lands (see D-M3 — that destination must first exist). I recommend (b): it preserves the scoping rule's integrity and loses nothing that works today.

---

## Major

### D-M1 — E-1 "closes 7/7" holds for the declared class only; the carrier inventory is incomplete

The seven-site table (:128-136) is verbatim-verified (see the favorable table below), and the team-lead's ruling OUT of the two partial carriers (`processing-pipeline.md:54`, `open-questions.md:127`) is correct — I read both; they are prose about relationship *types*, not spelling-family carriers, and harmonizing them would change meaning.

But two carriers are missing from the inventory, and the sweep could not have found them — the contradicts-anchored sweep structurally cannot see single-verb carriers (wiki-links :36/:57 entered the spec by reading, not by the sweep):

- `skill-sources/reduce/SKILL.md:780-781` — `- Good: "-- provides the foundation this challenges"` — the deprecated `foundation` spelling, in a Good-example block, **in a file Unit 3 already edits**. This is the same phrase as `wiki-links.md:57`, which the spec *does* harmonize; leaving its twin teaches the deprecated verb from inside the reduce skill.
- `skill-sources/reflect/SKILL.md:385-388` — literal-verb asymmetry guidance (`"extends"`, `"exemplifies"`, `"contradicts"`, `"synthesizes"`) not in the substitution table and not in the harmonize list.

```bash
/usr/bin/sed -n '779,782p' skill-sources/reduce/SKILL.md
/usr/bin/sed -n '385,388p' skill-sources/reflect/SKILL.md
```

**Correction:** add both to Unit 3's edit list (reduce :780-781 harmonize like wiki-links :57; reflect :385-388 either substitute or rule out with a sentence). Restate the closure as "7/7 declared enum sites, plus N harmonized literals" — and state the class-size caveat: the sweep finds multi-verb lists; single-verb carriers were found by reading, so the literal-carrier count is a floor, not a census.

### D-M2 — `wiki-links.md:49` glosses **extends** as "builds on an idea"; post-Decision-1 this is a live contradiction the harmonize list does not touch, and it falsifies the "no textual anchor" claim

Decision 1 maps `builds on` → `{vocabulary.rel_grounds}` and drops "builds on" from rel_extends' example list. But `generators/features/wiki-links.md:49` — two lines inside the very block E-1 harmonizes (:48-53) — reads:

```text
- **extends** — builds on an idea by adding a new dimension
```

After the spec lands, every generated vault's CLAUDE.md will define *extends* using the exact phrase the mapping table assigns to *grounds*. The edit list for wiki-links covers :36, :48-53's verb substitutions, :57 — but no unit rewords the :49 gloss.

This also corrects the spec's framing at :290-317 ("a judgment call with NO textual anchor"): there are **two conflicting anchors** — :49 pulls "builds on" toward extends, :36 ("provides the evidence this builds on") pulls it toward grounds. They cancel rather than being absent, which is why the call is free — but the spec must then fix :49, or the contradiction ships.

```bash
/usr/bin/sed -n '48,53p' generators/features/wiki-links.md
```

**Correction:** add :49 to the harmonize list with a reworded gloss (e.g. "adds a new dimension to an idea"), and reframe :290-317 from "no anchor" to "two conflicting anchors that cancel."

### D-M3 — #12 is resequenced to a destination that does not exist, while its own deferral entry reads "NOW DUE"

The deferred-work table (:595-607) sends #12 (with the `enum_values()` normalizer co-fix) to "the companion agreement-gate spec." No such spec exists:

```bash
ls docs/superpowers/specs/
/usr/bin/grep -c '#12\|status_\|enum_values' docs/superpowers/specs/2026-08-24-rot-prone-numeral-gate-design.md   # 0
/usr/bin/sed -n '238p' docs/superpowers/deferrals.md   # "REOPEN TRIGGER FIRED 2026-08-15, NOW DUE"
```

A deferral whose reopen trigger has fired, deferred again to an unwritten document with no tracking entry, is how this repo's own deferrals.md says items get lost. **Correction:** either create the companion spec file (even as a stub with the #12 hand-off recorded) before this spec merges, or add a deferrals.md entry-12 amendment to a unit's edit list naming the destination and date. Note D-C2's recommendation (b) increases what travels there.

### D-M4 — Unit 3's re-derive list omits two tallies its own edits move

Unit 3's re-derive step names only vault-CLAUDE.md :123-124 and `skill-authoring.md:70`. But:

- `reference/check-placeholder-count.sh:43` — the third carrier of the verify-tally, which Unit 1 repairs to 30 — goes stale *again* when Unit 3's substitutions move verify to ~36. Unit 1's own ruling was KEEP-and-repair; repairing it in PR 1 and re-rotting it in PR 2 with no re-derive entry recreates the defect the spec exists to close.
- The validate tally moves 5 → 11 under Unit 3, while Unit 1's "must be left alone (born-green control)" language invites an implementer to leave it stale.

```bash
/usr/bin/sed -n '37,47p' reference/check-placeholder-count.sh
```

**Correction:** Unit 3's re-derive list gains both sites, each with its re-derivation command, and Unit 1's born-green-control sentence gains "until Unit 3, which re-derives it."

### D-M5 — Unit 5's `~150` inventory is instrument-scoped; the residue survives at ten normative sites, including the kernel contract, so deferral #6's own closure condition ("fix them together or not at all") is not met

**What the spec says:** ":181 `/usr/bin/grep -rn '~150' generators/ skill-sources/`" → "both sites in `generators/`" (`atomic-notes.md:75`, `schema.md:18`); Unit 5 edits those two and closes #6 + #32.1. The deferral's AMENDED note carries the same two-tree measurement.

**What is true:** the grep scoped two trees; the string lives in five others. Full-tree sweep, false hits removed:

```bash
git ls-files -z | xargs -0 /usr/bin/grep -n '~150' | /usr/bin/grep -v '^docs/' | /usr/bin/grep -v '^methodology/'
```

Normative description-length carriers Unit 5 leaves at `~150` while it moves the generators to 200:

| Site | Content | Weight |
|---|---|---|
| `reference/kernel.yaml:57` | `description: "YAML description (~150 chars) adds information beyond the title..."` | The invariant contract itself — the highest-authority surface in the repo would disagree with the generators feeding it |
| `reference/templates/*.md:2` — all 8 files (`base-note`, `companion-note`, `creative-note`, `learning-note`, `life-note`, `relationship-note`, `research-note`, `therapy-note`) | `description: One sentence adding context beyond the title (~150 chars…)` | Shipped note templates; every vault that instantiates one is taught ~150 |
| `reference/methodology.md:55` | same description line | Reference doc |
| `reference/claim-map.md:84` | "~150 chars may not accommodate all styles" | Discussion of the tension; needs a ruling, not necessarily an edit |

Deliberately excluded, stated so the class size is explicit: `platforms/shared/skill-blocks/reduce.md:501,:753` (frozen mirror — expected stale, per the spec's own frozen-mirror handling); `methodology/` research corpus (discusses the convention as historical research content); false hits `skills/architect/SKILL.md:482` ("line ~150" — a line number) and `reference/semantic-vs-keyword.md:244` ("~150 notes" — a volume threshold).

This is the same failure class the spec itself diagnoses for E-1 at :122-126 — "two earlier discovery commands were both too narrow, in the same way" — reproduced by the revision one section later. Entry #6's condition is *fix them together or not at all*; a two-site edit closes the entry while the disagreement survives at ten sites, one of them the kernel.

**Correction:** Unit 5's edit list gains `kernel.yaml:57`, the eight `reference/templates/*.md:2` lines, and `reference/methodology.md:55`; `claim-map.md:84` gets an explicit KEEP-or-edit ruling; the frozen-mirror and `methodology/` exclusions get one sentence each; and the measurement at :181 is re-run tree-wide so the number in the spec matches the command beside it.

---

## Minor

### D-m1 — Gates section :580-581 contradicts the C3 fold
":580-581 Unit 2 edits `skills/setup/`, `reference/` and `generators/`, no `skill-sources/` file" — falsified by the same revision's C3 fold, which puts `skill-sources/rethink/SKILL.md` 232/233/335/516/:357 in Unit 2. The conclusion (PR 1 placeholder-gate safety) survives because the rethink edits add no placeholders, but the stated premise is wrong; reword to say that.

### D-m2 — Sweep triage understated: 36 hits, 9 triaged
`/usr/bin/grep -rn 'contradicts' generators/ skill-sources/` returns 36 (scratchpad `contradicts-sweep.txt`); the spec triages 9. Notable untriaged: `generators/features/graph-structure.md:40` lists `causes` — a verb in **no** spelling family, needing its own ruling; `dimension-claim-map.md:36`; `conversation-patterns.md:203`. Add a triage disposition line per hit class, or state the residual count.

### D-m3 — No unit updates `docs/superpowers/deferrals.md`
Entries 6, 12, and 32.1 all change state when this spec lands (6/32.1 close, 12 moves), and no unit's edit list touches the file. One edit-list line fixes it.

### D-m4 — The transforms-table pointer at CLAUDE.md:115
Root `CLAUDE.md:115` says "line 14 of that file is the mapping table." Unit 2's new row in `reference/vocabulary-transforms.md` must be appended below the existing rows (:11-25) — inserting above line 14 silently breaks the pointer. One sentence in Unit 2.

### D-m5 — Unit 4's report-line phrasing constraint is real but unstated
The suite pins negatives on the substrings `'pending observations'` / `'0 pending observations'` (:324-327) and `'^CONDITION: 0 pending observations'` (:350-353). Unit 4's new report line must avoid the substring `pending observations` (the sim's phrasing — "N observations carry a status outside the recognized set (of M total)" — passes all 60 under both shells). State the constraint in the unit so an implementer who writes the natural phrase "N pending observations with unknown status" doesn't trip four assertions.

---

## Resolved: the pinned-negative-assertion question (prior review's UNVERIFIED item)

**Question:** does Unit 4's new report line break `hook-config.test.sh`'s pinned negative assertions at :325-327?

**Answer: no — VERIFIED, with the phrasing constraint of D-m5.** Constructed run, sandbox `sim/` (full `hooks/` tree + `reference/lib` + `reference/test` + `platforms/claude-code/hooks`, baseline 60/60 both shells):

1. Patched `session-orient.sh` with a Unit-4-shaped branch inserted after the tensions-report `fi` (line 215): closed-count via `count_notes_by_field`, `OBS_UNKNOWN=$((OBS_TOTAL - OBS_COUNT - OBS_CLOSED))`, report line `CONDITION: N observations carry a status outside the recognized set (of M total).` Variables named `OBS_CLOSED`/`OBS_UNKNOWN`/`TENS_*` — **not** `status`, which is a read-only special in zsh (`zsh -c 'status=5'` → `read-only variable: status`), a hazard the spec's zsh note already flags.
2. Suite over the patched hook: **60/60 under bash and 60/60 under zsh** — no pinned assertion, positive (:248/:250/:267) or negative (:324-327, :350-353), fires.
3. Functional check on a hand-built mixed vault (open + closed + off-enum statuses): the new line fired `2 observations…` / `1 tensions…` correctly under both shells.

So the *hook-side* change is safe as long as the phrasing avoids the pinned substrings. The genuinely red path is not this — it is the *suite-side* extension colliding with the pinned totals (D-C1). Note the sim also embodies D-C2: making the branch work required enumerating the closed sets.

---

## Answers to the eight tasking items

1. **Scoping rule:** right, and I endorse it — literal edits in `generators/` are text the composer copies verbatim; new placeholder *families* there change what the composer must resolve. No objection to carry to the user. But the derived headline ":559 no gate-logic risk at all" is false via the truth_suite data path (D-C1), and #12's destination must exist before the resequencing is real (D-M3).
2. **Partial-carrier ruling and 7/7:** ruling confirmed correct; 7/7 verbatim-verified for the declared class; inventory incomplete beyond it (D-M1).
3. **C3 fold:** verified — rethink 232/233/335/516 verbatim, :357 pairing assertion present and correctly described. No finding.
4. **C4 fold:** verified for the two named sites; re-derive list short by two (D-M4).
5. **rel_grounds second opinion:** **defensible, and I concur with the mapping** — non-collision binds, and :36's evidence-phrasing leans grounds. Two amendments: (a) the framing is wrong — not "no textual anchor" but two conflicting anchors that cancel, and the extends-gloss anchor at wiki-links :49 must be reworded or it ships a contradiction (D-M2); (b) split the two sites rather than treating them alike: `reduce:494` is a template hint — keep three verbs with rel_grounds, fine; `reduce:279` is an **accept-list** ("Pass: extends, contradicts, or deepens…") — a 3-of-6 accept-list silently fails notes whose relationship is exemplifies/synthesizes/enables, the same closed-accept-list shape as Finding 6, so :279 should carry the full six per the spec's own standard-types rule.
6. **Enum-free formulation:** decouples on paper only — the `known-closed` term forces the enum back in (D-C2); recommend scoping Unit 4 to fixtures-only and letting the report line travel with #12.
7. **The UNVERIFIED item:** constructed and resolved — safe with a stated phrasing constraint (§ above, D-m5); the real red path uncovered by the same investigation is D-C1.
8. **Minors folded:** all verified as folded (reflect :295-300 range, frozen-mirror restatements, three-of-four tallies, placeholder-count Unit-3-only, tensions relabel, validate-kernel acknowledgment); residual seams are D-m1 through D-m5.

---

## Verified in the spec's favor (delta pass)

Every row below was re-measured this session; commands in the right column (scratchpad dumps: `delta-measure-1..6.txt`, `contradicts-sweep.txt`, `base-bash.txt`, `base-zsh.txt`, `dc-control.txt`).

| Spec claim | Result | How verified |
|---|---|---|
| E-1 seven-site table :128-136 line numbers and content | all 7 verbatim | `sed -n` each site |
| Two partial carriers' content supports ruling OUT | confirmed | read `processing-pipeline.md:54`, `open-questions.md:127` |
| rethink 232/233/335/516 + :357 pairing | verbatim | `sed -n '232p;233p;335p;357p;516p'` |
| `builds on`/`deepens` occurrence lists :158-163 | exact match, no extras | tree-wide grep |
| Marker tallies: verify 30/146, validate 5/60, reflect 123/203, reduce 132/155 | all reproduce | counting greps per `skill-authoring.md` §2 pattern |
| setup vocabulary block bounds 1149/1192 | reproduce | `grep -n '^vocabulary:\|# Level 7:'` |
| Frozen mirror: 6 E-1 sites, 7 slash-cmd markers | reproduce | grep in `platforms/shared/skill-blocks/` |
| #12's 4 declarations in 3 files | verbatim | grep |
| `implemented_in` in exactly 2 files | reproduce | `git grep -l` |
| generators/ placeholder count 0/527 lines | reproduce | grep -c |
| 11/28 cmd_* counts | reproduce | extraction sed + grep |
| doc-claims negative greps (g1=g2=0; '155|132' absent) | reproduce | gate's own expressions |
| Declared-but-unused schema keys tolerated (PR 1 declare-first safe) | empirically green | `check-vocabulary-schema.sh` run; status_open/status_archived/status_superseded declared, zero markers, gate PASS |
| `vocabulary-schema.test.sh`, `placeholder-count.test.sh` fixture-self-contained | confirmed | read both; no repo-tree reads |
| No test pins any PR-2-edited string | confirmed (positive control paired) | grep of `reference/test/` for each edited literal |
| Scope comments `check-vocabulary-schema.sh:12-15`, `check-placeholder-count.sh:37-47` | verbatim | sed -n |
| zsh `status` hazard note | confirmed real | `zsh -c 'status=5'` |
| Baseline `hook-config.test.sh` 60/60 both shells | reproduce | sandbox run |
| `check-doc-claims.sh` control run on unmutated copy | rc 0, PASS | background task `b1mdiv0ha` |
| `exemplifies`/`synthesizes` zero occurrences in `generators/` (harmonize additions collide with nothing) | reproduce | grep -c |
| `grounds` in `skill-sources/` only reduce:227 (prose) and reflect table | reproduce | grep -n |

---

## Independent verification (main session, 2026-08-24)

Every finding was re-measured against the tree on `develop` before being folded. Two did not
survive re-measurement. Verdicts below; the spec revision is commit `c5d4257`.

| # | Verdict | Evidence |
|---|---|---|
| **D-C1** | **CONFIRMED — blocks** | `truth_suite()` at `check-doc-claims.sh:69` runs `bash "$f"`; claim rows `:319`/`:334` pin `CONTRIBUTING.md:114` and `docs/verification.md:36` at 60. Suite measures `passed=60 failed=0`. Both carriers added to Unit 4. |
| **D-C2** | **Diagnosis CONFIRMED, remedy REJECTED** | `known-closed` needs a closed list — `count_open_items` matches only `pending open` (`:149-152`), totals count every file (`:158-159`), no third quantity. But `grep -rc '{vocabulary\.' hooks/scripts/` → **0 in every file**, and `:151` already hardcodes `pending open`. The tree resolves no placeholders, so none is due: not a #12 instance. Took option (a), not (b). |
| **D-M1** | **CONFIRMED** | `reduce:781` = `- Good: "-- provides the foundation this challenges"`, twin of `wiki-links.md:57`. `reflect:385-388` = four quoted verb tokens. Both added. |
| **D-M2** | **CONFIRMED** | `wiki-links.md:49` = `- **extends** — builds on an idea by adding a new dimension`. Reframed to two cancelling anchors; `:49` joins the harmonize list. |
| **D-M3** | **CONFIRMED** | No companion spec exists; `rot-prone-numeral-gate-design.md` scores 0 for `#12\|status_\|enum_values`. Unit 2 now amends `deferrals.md` entry 12 in place. |
| **D-M4** | **Bullet 1 already fixed; bullet 2 CONFIRMED** | `check-placeholder-count.sh:43` was added in the prior revision. The born-green-control sentence was not qualified; now reads "in this unit … until Unit 3". |
| **D-M5** | **CONFIRMED — changes Unit 5's scope** | Independent tree-wide sweep: 75 hits / 36 files. Normative carriers outside `generators/`: `kernel.yaml:57`, 8 × `reference/templates/*.md:2`, `reference/methodology.md:55` = 10. All four stated exclusions check out, both false hits genuinely false. |
| **D-m1** | **CONFIRMED** | Premise falsified by the same revision's C3 fold; conclusion re-based on "rethink edits add no placeholders". |
| **D-m2** | **Gap real, evidence FAILED** | `grep -rn 'contradicts' generators/ skill-sources/` returns **21**, not 36. None of `graph-structure.md`, `dimension-claim-map.md`, `conversation-patterns.md` exists under `generators/features/` — they are `methodology/` and `reference/` files, both outside the generation paths. Spec now carries a full triage disposition: 10 accounted, 11 ruled out in three groups. |
| **D-m3** | **CONFIRMED** | Folded with D-M3. |
| **D-m4** | **CONFIRMED** | `CLAUDE.md:115` pins "line 14"; Unit 2 now says append below `:11-25`. |
| **D-m5** | **CONFIRMED** | Assertions pin `pending observations` at `:324-327` and `:350-353`. Phrasing constraint stated in Unit 4. |
| Resolved §, prior UNVERIFIED item | **CONFIRMED** | The `:324-330` negatives pin a substring the residual line will not carry, so they cannot break — and cannot cover it either. Unit 4 adds its own pair plus a positive arm. |

### Two findings the delta pass did not draw

**`reduce:279` is a gate, not an illustration.** The review reached the right answer under item 5b
but filed it as a note on the `rel_grounds` mapping. It is stronger than that: `:279` closes with
**"If ANY criterion fails: do not extract."** A 3-of-6 accept-list therefore *silently refuses to
extract* notes whose relationship is `exemplifies`, `synthesizes` or `enables` — Finding 6's exact
defect, one layer earlier in the pipeline and with a worse consequence. It belongs in the spec as
a defect, not as a mapping footnote.

**A union of the two closed lists fails silently in the reporting direction.** The registers'
enums differ and `count_open_items()` serves both, so a shared list is the natural shortcut. A
union over-matches `closed`, which **under-reports** `unknown` — the branch reports nothing and
looks healthy. Neither review names this, and it is the one way Unit 4 can ship broken while every
assertion stays green.
