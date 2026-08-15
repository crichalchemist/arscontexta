# Cross-check: field-vault ops record vs repo specs and plans — 2026-08-11

**Scope:** the two active specs (`2026-08-08-corpus-wide-passes-design.md`,
`2026-08-09-post-merge-hardening-design.md`), the two active plans
(`2026-08-08-note-convention-and-lifecycle.md` at 0/39 steps,
`2026-08-09-post-merge-hardening.md` at 0/101 steps), `docs/superpowers/deferrals.md`
(20 entries), and `CLAUDE.md`'s divergence record — checked against
`~/second-brain/ops/` (90 observations, 14 open; 16 tension files, 2 open; 37 methodology
notes). Repo at `ad341c8` (`git rev-parse HEAD` — not `git log -1`, per the rtk memory note).
Read-only; every number below has its command in the Appendix.

**A fact that reframes everything else, found before the four questions:** the field vault
**ran `/arscontexta:upgrade` inline on ~2026-08-09 and replaced 13 of its 16 skills with
0.9.7 renders** (`grep -rh generated_from ~/second-brain/.claude/skills/*/SKILL.md` →
13× `0.9.7`, 3× `0.8.0`; `ops/skills-archive/extract-2026-08-09.md` is the replace-and-archive
residue; two open observations cite "inline /upgrade run" as their source).
`CLAUDE.md:1208` still states `/upgrade` has "never been invoked as a slash command against a
real vault — structurally". That sentence is now false, and its falsity is good news: the
"FORWARD-ONLY" ceiling both specs inherit from divergence 16 has a demonstrated, if
destructive, crossing — `/upgrade` replace. The vault paid for it by discarding local edits,
and the reason it had to is itself an open vault observation (see Section 1, row 4).

---

## Summary

| section | count |
|---|---|
| 1 — orphaned field findings (no home in any spec/plan/divergence/deferral) | **9** plugin-implicating (+5 classified vault-local, listed so exclusion is auditable) |
| 2 — contradicted or complicated plan steps | **4** |
| 3 — reach-audit items | **4** |
| 4 — stale cross-references (both directions) | **11** |
| 5 — genuinely in sync | **14** verified points |

**Single highest-blast-radius finding:** the vault observation
`pipeline-skills-hardcode-queue-json-in-executable-paths-while-their-prose-is-format-aware.md`
(open, 2026-08-09) is fully live in this checkout — 23 `ops/queue/queue.json` references
across `skill-sources/`, and `reference/lib/queue-edit.sh` is jq/JSON-only by construction —
and it has **zero mentions** in either active spec, either active plan, or `deferrals.md`
(`grep -il 'queue.yaml\|tombstone'` across all five → nothing). The post-merge plan's Tasks
7–8 build a mutation-proved test suite and a guarded commit step around exactly this library,
while in the only field deployment all seven of its consumers write to a 636-byte tombstone
(`~/second-brain/ops/queue/queue.json`, `"deprecated": true`; the live queue is
`queue.yaml`, 441 KB, YAML). jq iterating `.tasks[]` over the tombstone's empty array exits 0
byte-identical — so the "lost update at rc 0" class the spec's F1 exists to close **survives
F1a and F1b untouched** on any YAML-queue vault. The hardening is correct and worth doing;
the claim that it closes the class is overstated by exactly this case.

---

## Section 1 — Orphaned field findings

Backport candidates with no home in any repo spec, plan, divergence entry, or deferral.
Ranked by blast radius. Every fix recommendation is stated in **canonical** vocabulary with
placeholder forms, per the two mandatory reverse-transforms (the vault's `/extract` is
canonical `reduce`; the vault's "connect phase" is canonical `reflect`, per
`reference/vocabulary-transforms.md:14`; the vault's `nodes/` is `{vocabulary.notes}`;
`draft` is the vault's dialect for canonical `preliminary`).

| # | vault artifact | what it says | plugin surface implicated | canonical/placeholder form of the fix | reach | severity |
|---|---|---|---|---|---|---|
| 1 | `ops/observations/pipeline-skills-hardcode-queue-json-…md` (open) | Templates document both queue formats in prose but hardcode `ops/queue/queue.json` in every executable call; on a YAML-queue vault six of seven writes silently no-op and `/next`'s append writes maintenance tasks into the dead file, minting colliding `maint-N` ids (it also *reads* `MAINT_MAX` from it, `next:94`) | `skill-sources/next:94,97-98,128-130,153-154`, `verify:532`, `reflect:825`, `reweave:727`, `reduce:1130`; `reference/lib/queue-edit.sh` (jq-only) | Adopt `skill-sources/seed`'s existing dual-format branch (the observation's own counter-example: `seed:66,307,318,401`) in the executable paths of `reduce`/`reflect`/`reweave`/`verify`/`next`; the queue path is config-derived, not `{vocabulary.*}`, so the fix is format detection before `queue_edit`, or a YAML-capable `queue_edit`. Not a straight repoint — `queue.yaml`'s top level is a bare list, `.tasks[]` has no target | FORWARD-ONLY per template fix; REACHABLE for the vault only via a future `/upgrade` replace | **Critical** — silent no-op writes in the shipped pipeline; also undermines post-merge Tasks 7–8's closure claim (Section 2) |
| 2 | `ops/observations/reweave-performs-a-second-forward-pass-not-a-backward-pass.md` (open) | Five independent workers found `/reweave` (a) surfaces only same-batch same-day candidates — no age filter, so in a bulk batch the candidate pool is all-ineligible *by construction* — and (b) writes edges into the **target's own** frontmatter, i.e. reciprocal bookkeeping reported as discovery; corollary: the skill advanced `queue.yaml` phase state from a background fork against explicit instruction | `skill-sources/reweave` (same canonical name) | Candidate pool restricted to `{vocabulary.notes}` whose first commit (`git log --diff-filter=A`) strictly predates the target — git date authoritative, source-field and page-number heuristics explicitly rejected by the vault's own measurement; write into the **older** `{vocabulary.note}`'s file or report honestly that only outbound edges were produced; distinguish "new edge" from "mirror-side clause for an existing edge" in output; remove queue writes from phase skills (report transitions to the caller) | FORWARD-ONLY / `/upgrade`-replace | **High** — the skill can report success indefinitely while the metric it exists to move (inbound links from outside the batch: 106/601 = 17.6%) does not move; invisible to every gate |
| 3 | `ops/observations/next-subagent-forks-die-to-growing-context-reinjection-…md` (open) | `/next` as a `context: fork` subagent died **four times with zero successes** (3× autocompact thrashing, 1× "Prompt is too long"); three rounds of verified SKILL.md fixes changed nothing — the growth is per-compaction context re-injection, upstream of skill content; the same task completed inline via decomposed small calls; posited remedy: drop `context: fork` from the skill | `skill-sources/next/SKILL.md:7-8` (`context: fork`, `model: sonnet`) — verified present in the canonical template | Drop `context: fork` (and `model:` with it, per the §6 precedent) from `skill-sources/next`, or derive the fork/inline rule the post-merge spec explicitly recorded as missing. No vocabulary transform needed — frontmatter keys are not dialect | FORWARD-ONLY / `/upgrade`-replace | **High** — a shipped default with a 0/4 field success record on the vault-scale workload it was designed for. Note the post-merge spec's recorded gap says "a third skill moving in either direction is the point at which the rule has to be written" — this is field evidence for that third move, sitting one tree over, uncited |
| 4 | `ops/observations/upgrade-refuses-merges-citing-a-baseline-the-plugin-cache-still-holds.md` (open) | `skills/upgrade/SKILL.md:592` withholds option (b), a customization-preserving merge, on the stated premise "there is no OLD-rendering available"; false in any installed environment — the plugin cache accumulates (`~/.claude/plugins/cache/…/{0.8.0,0.9.0,0.9.5,0.9.6,0.9.7}` all on disk), every installed skill declares `generated_from:`, and running `mechanically_compare` against both baselines was demonstrated to reorder the upgrade priority list and surface 13 real conflict hunks | `skills/upgrade/SKILL.md:592` — a **plugin** skill, not a generated one | Gate a merge option on the *fact* "a prior version directory matching `generated_from:` is present in the cache", falling back to today's replace-only when absent. No transforms — `skills/` is canonical already | **REACHABLE** — `skills/` is the plugin's own tree; the fix arrives at every install on the next plugin update, no generation surface involved | **High** — this is the single lever that converts every FORWARD-ONLY row in this table into a non-destructive REACHABLE; the vault discarded its local edits because this option was withheld |
| 5 | vault-wide edge-direction/verb class: `ops/tensions/edge-direction-defects-deferred-from-the-bernstein-reweave-run.md` (open), `ops/observations/the-vault-systematically-verbs-sibling-relations-as-hierarchies.md` (open), plus the closed 45%-defect-rate observation | Canonical `reflect` (vault dialect: "connect phase") splits edge direction **within a single pass** — the correct twin lands in the partner file and a reversed copy in the target, measured 7/7; inherited-edge defect rates 45%+ (3/4, 3/3 per node); 464 live mirror conflicts across 2,686 nodes (33% of reciprocated pairs); dominant deeper fault: sibling claims verbed as hierarchies (`extends`/`supports` where `contrasts`/`parallels` is true) | `skill-sources/reflect` (edge writing), `reweave`, `verify` (read-back absent) | Per-edge actor read-back plus the vault's two field-derived tests (substrate test: "is either {vocabulary.note} substrate for the other?" before the direction question; transfer test for cross-domain edges) added to `reflect`'s write step and `verify`'s checks; delete-not-reverse rule for reversed asymmetric edges (twin verified present every time workers looked). All in `{vocabulary.*}` placeholder terms | FORWARD-ONLY / `/upgrade`-replace | **High** — largest content-defect class in the field vault and it is generated-procedure-shaped ("the conflict is created by the procedure rather than by any author's misjudgement"), but the fix is design-heavy and needs its own spec |
| 6 | `ops/observations/drift-rethink-exempts-its-own-output-from-the-provenance-fields-it-enforces.md` (open) | `/rethink`'s Phase 0 writes `drift-*` observations that later close without `implemented_in:`/`archived_reason:` — 5 of 9 offenders are its own output; the canonical template *already states* the same-edit rule (`skill-sources/rethink:312,324`) and it is prose CI cannot exercise, so it is skipped exactly where the skill polices itself | `skill-sources/rethink` Phase 0 / closing paths | Make the status write and the provenance field one edit with no path that sets one without the other, Phase 0 output explicitly included; observation statuses are canonical (`implemented`/`archived` — note CLAUDE.md records the observation enum has no gated consumer in `generators/`) | FORWARD-ONLY / `/upgrade`-replace; symptom is detected vault-side by kernel `C1` (currently FAIL: 13 of 80) | Medium — `C1` catches the accumulated damage; nothing addresses the producer |
| 7 | `ops/observations/the-claim-to-node-mapping-…md` (open), "Related defect" section | Every extraction stub carries `semantic_neighbor: null` and the template's own comment verbatim (`closed  # or 'open' if…`) — canonical `reduce` "emits scaffolding it never fills"; the field exists, is empty, and its emptiness is invisible | `skill-sources/reduce:932` (`semantic_neighbor: "[related note title]" \| null`) | Either fill `semantic_neighbor` at emission (the skill has the search results in hand) or stop emitting the field; strip template comments from emitted stubs. `{vocabulary.notes}` for paths | FORWARD-ONLY / `/upgrade`-replace | Medium — cost is downstream hand-derivation of neighbours, measured twice |
| 8 | `ops/observations/two-shell-idioms-fail-silently-on-exactly-the-clean-case.md` (open) | BSD `sed` silently matches nothing for `\b` (exit 0), and `grep`'s rc 1 on zero matches kills a `pipefail` script on precisely the clean input — both hit while `/upgrade` rendered the 13 templates; the observation notes the 0.8.0→0.9.7 delta is explicitly GNU/BSD hardening and `\b` is not on that list | `skills/upgrade`'s render path; any fence using `\b` or unguarded `grep \| wc -l` under `pipefail` | Add `\b` to the portability class `check-portability.sh` scans for (it already catches `grep -P`; `\b` is the same GNU-only family); the grep-rc-1 half is already house idiom (post-merge Global Constraint 3) for *new* work but no gate scans existing fences for it | REACHABLE for the gate (repo-side); FORWARD-ONLY for fence fixes | Medium — the failure mode is the repo's own documented silent-failure class, in the repo's own upgrade path |
| 9 | `ops/observations/git-head-is-not-a-safe-verification-baseline-…md` (open) | The plugin's timer-based auto-commit hook sweeps writes within minutes, so a verify-against-`HEAD` check compared a file to itself and scored perfect; second instance: the hook committed a destructive concurrent rewrite, making damage indistinguishable from intent in history | `hooks/scripts/auto-commit.sh` and the generated auto-commit feature (`generators/features/`) | Guidance, not code: any generated skill that verifies a write against git must pin the baseline to a commit resolved **before** the write — belongs in the generated CLAUDE.md feature block and in `verify`'s prose; `{vocabulary.*}`-neutral | FORWARD-ONLY (generated CLAUDE.md); the plugin-side hook itself needs no change | Medium — a green-gate-over-an-unknown class created by the plugin's own convenience feature |

**Classified vault-local, not backport candidates** (stated so exclusion is auditable):
`a-field-filtered-queue-query-hid-…` (dispatch-script practice, not generated code);
`agents-draft-conclusion-sections-…` (agent process; its lesson already exists repo-side as
the "Capture numbers at the action" memory);
`the-lead-authored-more-defects-…` (wave-orchestration practice; the `advisor` it references
is not a plugin surface — `grep -rln advisor` over `skills/ skill-sources/ generators/ agents/`
matches only the word "advisory");
`pair-ownership-…-double-delete` (single-writer wave protocol, vault-invented);
`roc-cannot-cross-a-zero-line` (source-content tension, needs Bernstein p. 111).
One vault-local item still has a plugin-relevant half:
`an-edit-spec-anchored-across-the-frontmatter-terminator-…` is wave-protocol, but it and the
reweave corollary (two real quarantines from `Edit`s that stripped the `---` terminator) are
fresh field evidence bearing on the post-merge spec's **Decision 2** — see Section 2.

## Section 2 — Contradicted or complicated plan steps

**2.1 — Post-merge plan Tasks 7–8 (`queue-edit.test.sh`, guard the `mv`) — complicated,
closure claim overstated.**
Plan Task 8 Step 2: *"`:67` `mv "$tmp" "$file"`, unguarded, against stated contract of
'Fails loud … return 1' … A caller marking task `done` must not proceed believing failed
write landed."* Spec F1: *"a caller marking a task `done` proceeds believing the write landed
and the task is re-processed next pass — a lost update at rc 0, the exact class the file's
own header says the lock exists to prevent."*
Vault evidence (`pipeline-skills-hardcode-queue-json-…`, open, dated the same day as the
spec): *"jq iterating `.tasks[]` over an empty array is a no-op: exit 0, file byte-identical.
Six of the seven call sites therefore vanish without a trace."* Measured in this checkout:
`queue-edit.sh` is jq-only; all seven `queue_edit` consumers pass the hardcoded JSON path;
the field vault's JSON file is a tombstone and `ops/lib/queue-edit.sh` is installed there.
**Ruling:** the tasks stand — the guard and suite are real fixes for real defects — but the
success criteria (7, 8) and spec F1's framing must not be read as closing the lost-update
class: on a YAML-queue vault every `queue_edit` still returns rc 0 having changed nothing,
which is the identical caller-visible outcome. At minimum the suite should carry one
assertion documenting the limitation (a `deprecated`-tombstone fixture whose edit returns 0
unchanged), and the orphaned finding in Section 1 row 1 needs a home.

**2.2 — Post-merge spec §6 / plan Task 16 (four plugin skills inline) — the recorded gap's
own reopening trigger is already tripped, one tree over.**
Spec: *"Deriving a rule for which skills fork … Two candidate rules were tested and
falsified; the selection was the request … A third skill moving either way is the point at
which the rule has to be written."*
Vault evidence: four consecutive fork deaths, zero fork successes for the generated `/next`
(`context: fork`, `model: sonnet` — verified identical in `skill-sources/next:7-8`), with the
diagnosis "upstream of anything a skill author controls by editing SKILL.md" and the posited
remedy being exactly this frontmatter key. The vault's inline completion of the same task is
the missing principle's first datum: **broad-scanning skills die forked at vault scale.**
**Ruling:** not contradicted — `skill-sources/` is out of Task 16's stated scope — but the
plan's deferral bullet ("Reopening trigger: a third skill moving in either direction") is
written as if no evidence exists, while the strongest evidence in either tree is an open
observation naming the same key on the same skill family. The rule-writing trigger should
cite it.

**2.3 — Post-merge plan Decision 2 ruling (option C, "record and wait") — ruled on a cost
model the vault's newest evidence has overtaken.**
Plan: *"Widening the matcher alone buys zero coverage on any vault that renamed its notes
directory … so option A would cost a hook invocation on every edit everywhere and close
nothing."* — correct as far as it goes.
Vault evidence, both dated after the analysis that fed the ruling: two live near-misses in
which an `Edit` spec would have (and twice actually did, before repair) stripped a node's
frontmatter terminator — the precise content-destruction shape `write-validate.sh` exists
for, arriving via the `Edit` door the matcher does not watch; caught only by the vault's
**hand-written** tier-2 validator (`validate-node-schema.py`), which no other vault has.
**Ruling:** the ruling stands (it is the user's, and option B is correctly scoped to the
enforcement-gap track), but its reopening trigger is understated: it names only "that path
filter becoming vocabulary-aware" as the trigger. The field record now shows the guarded
class occurring in the wild via `Edit`, twice in one week, in the one vault that happens to
have a private net. That belongs in `deferrals.md` entry 15 as evidence, so the next reader
prices option B against measured occurrences rather than against zero.

**2.4 — Note-convention plan, vault-facing assumptions — verified, with one drifted number
the plan must re-derive on execution.**
Checked side by side (all commands in Appendix): Task 2 Step 1's "no `status:` in the
emitted template" — **holds** (`reduce:470-478`). Task 5's "1633 = 1621 + 12" — **holds
exactly** (re-measured 2026-08-11). Task 6 Step 1's "11 templates, every one reports 0 for
'period'" — **holds** (11 files, all `:0`). Task 7 Step 2's "vault reading
`draft | active | superseded | archived`" — **holds verbatim** (`templates/insight-node.md`
enum block). The spec's status distribution, however, has moved: **1238 active / 752 draft**
against the spec's 1182/808 (56 draft→active promotions by wave agents since 2026-08-08,
executing the vault's own `verified-nodes-should-promote…` methodology decision by hand);
`2005 with / 681 without` is unchanged. No step breaks — the plan already orders "re-derive"
— but Task 7's backfill will land on a vault that is *already practicing* the promotion
convention manually, which strengthens rather than complicates it.

## Section 3 — Reach audit

Every finding above classified; here, the places a spec or plan claims (or implies) more
reach than it has — plus the one place the repo now *understates* its reach.

1. **The corpus spec's "Delivery ceiling" is honest and should be the model.** It states
   items 2 and 3 reach new vaults only, ships item 1's normalizer twice for exactly this
   reason, and forbids closing divergence 16 in-scope. No overstatement found. One update it
   deserves: its premise "a rule added reaches vaults not yet created" now has a second
   channel — the field vault demonstrated `/upgrade` replace on 2026-08-09 (13 skills
   re-rendered). "Forward-only" is now more precisely "forward-only, or destructively via
   `/upgrade` replace, until the merge option (Section 1 row 4) exists."

2. **Post-merge spec F1/criteria 7–8 overstate closure** of the rc-0 lost-update class —
   see Section 2.1. The guard closes the *rename* route to rc-0-with-no-write; the *format*
   route stays open in the only field deployment and is named nowhere in the repo.

3. **CLAUDE.md divergence 16 and divergence 5 both now understate reach** — "never been
   invoked as a slash command against a real vault … structurally" (`CLAUDE.md:1208`) is
   contradicted by the vault's own ops record and `ops/skills-archive/*-2026-08-09.md`. The
   three repairs divergence 5 calls "prose contracts CI cannot exercise" have now been
   exercised once against a real vault by the real skill. What that run surfaced (two-shell
   idioms, the withheld merge) is sitting in the vault's open observations, unclaimed.

4. **The note-convention plan's Task 3/Task 4 removals have an unstated vault-side
   consequence worth one sentence:** deleting the trailing-period WARNs from
   `skill-sources/verify`/`validate` reaches the field vault only at its next `/upgrade`
   replace — until then the vault's installed `verify` keeps WARNing on a convention whose
   corpus was meanwhile normalized by the repo-side script (Task 5 runs against the vault
   directly). The two halves of item 1 arrive by different transports at different times,
   and the plan sequences them without saying the vault will spend the interval with the
   WARN firing on ~0 notes (harmless, but a reader of vault WARN counts should know why
   they dropped).

## Section 4 — Stale cross-references

Repo cites vault (stale):

| # | where | cited | measured 2026-08-11 |
|---|---|---|---|
| 1 | `CLAUDE.md:1208` (divergence 5) | `/upgrade` "never been invoked as a slash command against a real vault", gap "structural" | Invoked inline ~2026-08-09; 13/16 skills `generated_from: "arscontexta-0.9.7"`; `pipeline`, `ralph`, `validate` remain 0.8.0 |
| 2 | `CLAUDE.md:494,537,639-641` (divergences 3, 5) | Field vault's hook is a 179-line hand-patch hardcoding `-gt 20`/`-gt 10`, reading neither namespace; its `/rethink` reads `maintenance.conditions.*` at 20/10; "live split 2 firing 2 silent" at 14/8 | Hook is a 180-line 0.9.7-derived render hardcoding **10/5** (`:125,:133`) with naive `grep -l "^status: open"` (`:124`) and still no config key; vault `/rethink` now reads `self_evolution.*` (`:22-23`); `ops/config.yaml` holds **both** namespaces at 10/5 — the vault *deliberately reversed* 20/10 on 2026-08-08 (`ops/methodology/rethink-thresholds-set-to-ten-five-reversing-the-twenty-ten-choice.md`), dissolving the disagreement divergence 3's reconciliation machinery (`/upgrade` 6c) was built for. At 14 open obs / 2 open tensions the obs threshold fires everywhere consistently |
| 3 | `CLAUDE.md` divergence 5 command block | `list_notes_by_field … tensions … # 8` | **2** (obs is coincidentally still 14). Marked "drifts" in-file, so expected — recorded because the published expected-values now mislead |
| 4 | `CLAUDE.md` kernel-validator paragraphs | `15 PASS / 2 WARN / 1 FAIL`; frontmatter `5128 with, 163 without`; dangling `8 of 2716`; C1 `13 of 34` = 6 implemented + 7 promoted | Same shape, moved numbers: 15/2/1; **5445 with, 197 without**; **8 of 2717**; C1 **13 of 80** — numerator coincidentally identical, denominator more than doubled (the waves closed ~30 observations), so the published 6+7 decomposition no longer describes the 13 |
| 5 | corpus spec, Measurements | status distribution `1182 active, 808 draft` | `1238 active, 752 draft` (2005/681 split unchanged; 1633 = 1621+12 unchanged) |
| 6 | corpus spec, item 2 tables + "check 6" output | `"7 interpolated matcher(s) across 5 allowlisted file(s)"`; divergence 12/13 sets of 7; `LINK_EXTRACTION_VERSION=2` | Item 2 shipped via the archived link-edge-map plan (PR #7): allowlist is **2** entries, divergence 12 residual is `4 = 2+1+1`, version is **3**. The spec header "approved, not yet planned" is stale for item 2 — an implementer must not re-execute its conversion tables |
| 7 | corpus spec, "Known drift this design created" | `CLAUDE.md:966` still cites `testing-milestones.md:410`; divergence-12 table cites `skills/health :174,:509,:562,:585` | Both already repaired: on-disk `CLAUDE.md:951` cites `:425`; the table was re-derived to a different shape citing `skills/health/SKILL.md:661`. The spec's instruction "re-derive every row" was executed by later work; rev 3's drift warnings describe states that no longer exist |
| 8 | post-merge spec F6 evidence | `grep -n 'check_lib ' → 2 lines` | 3 lines (`:710` definition + `:743,:744` calls) — the substance (queue-edit absent) holds; the count anchor drifted by the definition line |

Vault cites repo/plugin (stale or since-resolved):

| # | where | cited | measured |
|---|---|---|---|
| 9 | `MEMORY.md` "second-brain backport candidates 2026-08-08" | "29 unsubstituted vocabulary placeholders" in vault skills | **0** — resolved by the 0.9.7 re-render; the memory note predates the upgrade |
| 10 | `pipeline-skills-hardcode-…` inventory table | raw `jq` calls at `next:94,98,130,154` | Same lines, but `:97,:128,:153` now route through `queue_edit` (the library merged in PR #7 postdates the observation's framing); the hardcoded path and the silent no-op are unchanged, so the observation's substance survives its own citation drift |
| 11 | `next-subagent-forks-…` scope question | "whether `/health`, `/stats`, `/graph` … remain unverified" as fork-death candidates | Repo-side, `skills/health` (plugin) is slated to go **inline** by post-merge Task 16 — partial convergence the observation does not know about; `skill-sources/graph`/`stats` remain forked and untested at scale |

## Section 5 — What is genuinely in sync

Verified point-by-point, so the four sections above can be trusted as the exceptions:

1. **1633 = 1621 bare + 12 quote-terminated** — re-derived exactly; the corpus spec's
   headline number is stable three days on.
2. **2686 nodes, 0 subdirectories in `nodes/`** — F4's latency premise and the Decision 1
   ruling's load-bearing measurement both re-verify.
3. **11 vault templates, every one 0 for `period`** — Task 6 Step 1's expectation exact.
4. **`templates/insight-node.md` enum `draft | active | superseded | archived`, `status`
   under `required:`** — Task 7's derivation input verbatim; `superseded` (3), `closed` (11),
   `investigating` (1), 681 absent all re-verify, so deferrals 5 and 7 are accurate.
5. **The vault independently decided verify-promotion on the same day the spec did** —
   `ops/methodology/verified-nodes-should-promote-from-draft-to-active-…md` (2026-08-08):
   draft→active on clean verify, forward-only, backlog deferred, "not yet wired into the
   verify skill." Convergent with corpus item 3 in every boundary condition (promote only on
   zero FAIL; no retroactive backfill; absent status untouched). The plan is building what
   the field already voted for.
6. **Fence gate baseline holds:** `files=27 fences=78 run=75 skipped=3 known-open=2` (bash),
   PASS — post-merge criterion 1's pins are current.
7. **All post-merge spec line citations re-verify:** template `:161-163`
   (`NOTES_DIR`/`ORPHAN_COUNT=0`/`[ -d ]`), `session-orient.sh:151,:154-155,:207`,
   `read_config.sh:107` bare-path `grep -E`, link-extraction bare sorts at
   `:195,:207,:272,:283`, `errf` 6 sites, `src=$(basename … | _fold_lower)` at `:299,:337`,
   awk rebuild at `:378,:395`, `LINK_LIB` 8 prefixed / 1 bare, `queue_edit` 7 consumers,
   deferrals.md 20 entries, check-6 allowlist 2 entries (still whitespace-delimited — Task 13
   correctly pending).
8. **The corpus spec's four `generators/` period declarations and the fifth site**
   (`reduce:473`, `~150`, no clause) re-verify, as do `verify:174/271/372` and `validate:88`.
9. **The vault's threshold surfaces now agree with the generator's defaults** (10/5 in both
   namespaces, all readers) — divergence 3's "a vault's own tools contradict each other"
   hazard is currently quiescent in the field, by the vault's own recorded decision.
10. **`ops/tensions/archive/` exists in the field vault** — D17's recursive-totals fixture
    (post-merge Task 11) models a real directory shape, not a hypothetical.
11. **The vault's installed 0.9.7 `rethink` carries the same-edit provenance prose**
    (`:325,:337`) — the generator's text arrived intact; Section 1 row 6 is a
    compliance-path gap, not a lost clause.
12. **`vaultguard` inertness confirmed by use:** this repo has no `.arscontexta`, and no
    auto-commit fired during this review's writes.
13. **Deferral 20's C1 display-cap ruling is consistent with the live FAIL** (13 of 80
    reported as a count, violation list capped) — the truncated-display-not-sampled-
    measurement distinction holds as stated.
14. **`skill-sources/seed` really is the format-agnostic counter-example** the vault
    observation says it is (`seed:66,307,318,401` branch both queue formats) — the fix for
    Section 1 row 1 is in-house, exactly as the observation claims.

## Appendix — re-derivation commands

```bash
# Repo tip (rtk memory: git log -1 misreports; use rev-parse)
git rev-parse HEAD                                                    # ad341c8

# Open observations / tensions, status distributions (frontmatter library, never bare grep)
. reference/lib/frontmatter.sh
list_notes_by_field ~/second-brain/ops/observations status pending open | grep -c .   # 14
list_notes_by_field ~/second-brain/ops/tensions      status pending open | grep -c .   # 2
for f in ~/second-brain/ops/observations/*.md; do frontmatter_field "$f" status; done \
  | sort | uniq -c        # 63 implemented, 14 open, 12 archived, 1 dissolved (90 files)

# Node count, subdirs, status distribution, trailing periods (corpus spec re-derives)
find ~/second-brain/nodes -maxdepth 1 -name '*.md' | wc -l            # 2686
find ~/second-brain/nodes -mindepth 1 -type d | wc -l                 # 0
# loop with frontmatter_field: have=2005 none=681; 1238 active, 752 draft, 11 closed,
# 3 superseded, 1 investigating; bare=1621 quoted=12 sum=1633

# Templates and enum (note-convention plan Tasks 6-7)
ls -1 ~/second-brain/templates/*.md | wc -l                           # 11
grep -c 'period' ~/second-brain/templates/*.md                        # every file :0
sed -n '15,30p' ~/second-brain/templates/insight-node.md              # draft|active|superseded|archived

# The upgrade that already happened
grep -rh 'generated_from' ~/second-brain/.claude/skills/*/SKILL.md | sort | uniq -c
                                                # 3× 0.8.0 (pipeline, ralph, validate), 13× 0.9.7
ls ~/.claude/plugins/cache/agenticnotetaking/arscontexta/             # 0.8.0 … 0.9.7
ls ~/second-brain/ops/skills-archive/ | grep 2026-08-09               # extract-2026-08-09.md
grep -n 'never been invoked as a slash command' CLAUDE.md             # :1208, on disk

# Queue format split (Section 1 row 1, Section 2.1)
head -c 200 ~/second-brain/ops/queue/queue.json                       # deprecated tombstone, 636 B
ls -la ~/second-brain/ops/queue/queue.yaml                            # 440999 B
grep -rn 'ops/queue/queue\.json' skill-sources/ | wc -l               # 23
grep -rn 'queue_edit ' skill-sources/ skills/                          # 7 consumers
grep -n 'jq \|yaml' reference/lib/queue-edit.sh                       # jq-only, no yaml path
for t in next verify reflect reweave reduce seed; do
  echo "$t $(grep -c queue.json skill-sources/$t/SKILL.md)/$(grep -c queue.yaml skill-sources/$t/SKILL.md)"
done                                       # next 7/3, verify 2/0, reflect 1/0, reweave 1/0,
                                           # reduce 5/0, seed 2/3 — matches the vault observation
ls ~/second-brain/ops/lib/                                            # queue-edit.sh installed

# Coverage greps (zsh does not word-split unquoted vars — use positional params;
# the first attempt at this sweep returned false zeros for exactly that reason)
set -- docs/superpowers/specs/2026-08-08-corpus-wide-passes-design.md \
       docs/superpowers/specs/archive/2026-08-09-post-merge-hardening-design.md \
       docs/superpowers/plans/2026-08-08-note-convention-and-lifecycle.md \
       docs/superpowers/plans/archive/2026-08-09-post-merge-hardening.md \
       docs/superpowers/deferrals.md
for kw in 'queue.yaml' 'tombstone' 'age filter' 'diff-filter' 'advisor' 'auto-commit' \
          'plugin cache'; do grep -il "$kw" "$@"; done                # no hits, any keyword

# Fork evidence (Section 1 row 3)
sed -n '1,10p' skill-sources/next/SKILL.md | grep -n 'context:\|model:'   # fork / sonnet
sed -n '1,10p' ~/second-brain/.claude/skills/next/SKILL.md                # same, 0.9.7

# Upgrade merge premise (Section 1 row 4)
sed -n '588,596p' skills/upgrade/SKILL.md                             # "no OLD-rendering available"

# Thresholds (Section 4 rows 2-3)
grep -n 'self_evolution\|pending_' ~/second-brain/ops/config.yaml     # both namespaces 10/5
grep -nE 'PENDING_(OBS|TEN)|-gt [0-9]+' ~/second-brain/.claude/hooks/session-orient.sh
                                                                      # -gt 10 / -gt 5, naive grep
grep -n 'self_evolution' ~/second-brain/.claude/skills/rethink/SKILL.md   # :22-23
wc -l ~/second-brain/.claude/hooks/session-orient.sh                  # 180

# Kernel validator, current (Section 4 row 4)
./reference/validate-kernel.sh ~/second-brain 2>&1 \
  | sed "s/$(printf '\033')\[[0-9;]*m//g" | grep -E '^ +(PASS|WARN|FAIL) '
# 18 lines: 15 PASS / 2 WARN (5445 with YAML, 197 without; 8 of 2717) / 1 FAIL (C1: 13 of 80)

# Fence gate baseline (Section 5 item 6)
bash reference/test/fence-isolation.test.sh 2>&1 | grep -E 'files=|FENCE'
                                    # files=27 fences=78 run=75 skipped=3 known-open=2, PASS

# Post-merge spec citation re-verification (Section 5 item 7)
sed -n '161,163p' platforms/claude-code/hooks/session-orient.sh.template
sed -n '151p;154p;155p;207p' hooks/scripts/session-orient.sh
sed -n '195p;207p;272p;283p;299p;337p;378p;395p' reference/lib/link-extraction.sh
grep -c 'link-extraction-err-\$\$' reference/lib/link-extraction.sh   # 6
grep -rh 'LINK_LIB=' skill-sources/ | sort | uniq -c                  # 8 prefixed, 1 bare
grep -n 'check_lib ' skills/health/SKILL.md                           # :710 def, :743-744 calls
grep -n '^### ' docs/superpowers/deferrals.md | wc -l                 # 20
sed -n '61p;67p' reference/lib/queue-edit.sh                          # jq 2>/dev/null; bare mv

# Corpus spec citations (Section 5 item 8)
sed -n '470,480p' skill-sources/reduce/SKILL.md                       # no status: field; ~150
grep -n 'railing period' skill-sources/verify/SKILL.md                # :174 :271 :372
grep -n 'trailing period' skill-sources/validate/SKILL.md             # :88
grep -rn 'trailing period\|no period' generators/                     # schema 18,26,144; templates 32

# Vault methodology bearing on the specs
sed -n '1,30p' ~/second-brain/ops/methodology/rethink-thresholds-set-to-ten-five-reversing-the-twenty-ten-choice.md
sed -n '1,60p' ~/second-brain/ops/methodology/verified-nodes-should-promote-from-draft-to-active-not-stay-draft-indefinitely.md

# Scaffolding emission (Section 1 row 7)
grep -n 'semantic_neighbor' skill-sources/reduce/SKILL.md             # :932

# Placeholder residue in vault (Section 4 row 9)
grep -rn '{vocabulary\.' ~/second-brain/.claude/skills/ | wc -l       # 0

# advisor is not a plugin surface (Section 1 exclusions)
grep -rln 'advisor' skills/ skill-sources/ generators/ agents/ platforms/  # "advisory" only
grep -rln 'advisor' ~/second-brain/.claude/                           # nothing
```
