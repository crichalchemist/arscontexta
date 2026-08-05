# Plan — Spec H: the generator/vault enforcement gap

Spec: `docs/superpowers/specs/2026-08-05-generator-vault-enforcement-gap-design.md`

## Global Constraints

- **Execution model:** implement directly; dispatch reviews on opus, reviewers in separate
  worktrees (`isolation: worktree`). Subagent implementers have died of autocompact thrashing in
  this repo 3/3; reviewers survive large packages.
- **`~/second-brain` is READ-ONLY.** Copies only, deleted after use. No task here writes to it.
- **The defect class is silent failure.** Any new bash is guilty until shown otherwise: a scan that
  matches nothing must not report clean, and rc 2 ("could not run") outranks rc 1 ("found one").
- **Both bash and zsh.** Unquoted `$var` in a `for` list word-splits under bash and not zsh;
  unmatched globs error under zsh's `nomatch`; `PIPESTATUS` is bash-only.
- **`grep` in a Claude Code session is ugrep.** Spell `/usr/bin/grep` in gates.
- **Mutate the DEFECT, not the line.** A compound mutation cannot attribute coverage; a single-site
  mutation often changes nothing observable. Assert every mutation applied (`cmp -s`) before reading
  its result, and check *which* assertions reddened, not merely that some did.
- **Gate every number you mint, in the commit that mints it.** Five fixes across Specs F–G each added
  a count no gate could see.
- **Step 1 of every task is: measure the premise.** If it does not hold, record what does and
  rescope. This held 3 of 4 times in Spec G.

---

## Task 1 — reconcile the observation and tension enums with reality

- [ ] **Step 1 — measure the premise.** Re-derive the status usage table in the spec's inventory §1
      against the field vault, read-only. Confirm `implemented` is absent from every generator enum
      and that `open` is absent from these two specifically. **If any value has since changed, the
      table is the record — update it and rescope before editing anything.**
- [ ] **Step 2 — add the measured values**, keeping the three fields separate. Observations gain
      `open` and `implemented`; tensions gain `open` and `blocked`. `generators/features/self-evolution.md:88,195`
      is the site. Do **not** touch the note enum at `atomic-notes.md:94` / `schema.md:137` /
      `templates.md:30` — Spec F separated these deliberately and the closed record for divergences
      7/8/9 says why.
- [ ] **Step 3 — state each new value's meaning in the block that declares it**, especially
      `blocked`: a tension awaiting external work, which is **not counted** toward the `/rethink`
      threshold. One sentence each; an enum value with no stated meaning is how `pending` survived.
- [ ] **Step 4 — narrow the `_schema` authority claim** at `generators/features/schema.md:142`. It
      says "the single source of truth for field validation"; the hardest gate in the field vault
      ignores it and one WARN-only linter reads it. Either state the scope honestly or name what
      would have to exist for the claim to be true. Do **not** build that reader here.

**Done when:**

```bash
/usr/bin/grep -n 'status:' generators/features/self-evolution.md      # observation + tension enums
# every value the vault uses appears in the matching enum, and the note enum is untouched:
git diff --stat generators/features/atomic-notes.md generators/features/templates.md   # empty
```

---

## Task 2 — the enum-consistency gate (Spec G item 22)

- [ ] **Step 1 — measure the premise.** Confirm no existing gate references the generator enums
      (spec inventory §3 carries the command). If one has appeared, this task is already done and
      should be closed rather than duplicated.
- [ ] **Step 2 — decide the property before writing the check, and write the decision down.**
      "The declaring files agree" is not one property — the note enum is declared in three files and
      must agree; the observation and tension enums are declared once each and must instead agree
      with *nothing*. A gate asserting cross-file agreement therefore covers the note enum only.
      **State which enum this gate covers and which it cannot**, in the check's own header.
- [ ] **Step 3 — build it into `check-doc-claims.sh` or a new check**, whichever the Step-2 decision
      implies. Prefer extending `check-doc-claims.sh`: it already has the truth-source pattern, the
      three exit states, and a banner that states its scope every run.
- [ ] **Step 4 — prove non-vacuity by mutation.** Change one declaring file's enum; the gate must
      redden and name both values. Restore. A gate that cannot fail is the thing this repo keeps
      finding.

**Done when:**

```bash
bash reference/check-doc-claims.sh; echo rc=$?     # rc 0
# mutate one enum, re-run, expect rc 1 naming both sides, then restore
```

---

## Task 3 — `implemented ⇒ implemented_in:` (the placement decision)

- [ ] **Step 1 — measure the premise.** Re-derive the 6-of-26 figure. Confirm zero real script
      references to `implemented_in` in the vault (the one grep hit is a minified `node_modules`
      bundle — exclude `node_modules` and expect zero).
- [ ] **Step 2 — DECIDE THE HOME IN WRITING before implementing.** The spec's table gives three
      options and their costs. The honest default is `reference/validate-kernel.sh`, because it is
      the only one that reaches the vault that demonstrated the defect. Record the decision and the
      rejected alternatives in the check's header — **including which vaults it does not reach**,
      which for the generated-hook option is "every vault that already exists".
- [ ] **Step 3 — implement it as a conditional-field assertion**, the first in either tree. Reuse
      `reference/lib/frontmatter.sh` (`frontmatter_field`, `list_notes_by_field`) rather than a new
      parser — the library exists precisely because body-line matches were counted as frontmatter.
      A missing directory is not a violation; a directory that cannot be scanned is rc 2, not 0.
- [ ] **Step 4 — expect the field vault to go red, and do not soften the check.** It has 6
      violations, so its run will worsen from `15 PASS / 2 WARN / 0 FAIL`. That is the check working
      on the content it was built for. Record the new figure in CLAUDE.md's pass-criterion block with
      the reason, the way primitives 1 and 2 are already recorded as content defects rather than
      repo regressions.
- [ ] **Step 5 — a fixture, not the live vault.** Assertions run against a built fixture with a
      known-good and a known-bad note, so the suite does not depend on a private vault's content.

**Done when:**

```bash
./reference/validate-kernel.sh <a-fixture-vault>          # the new assertion fires on the bad note
./reference/validate-kernel.sh ~/second-brain             # reports the 6, does not crash
for s in bash zsh; do $s reference/test/<suite>.test.sh | tail -1; done   # failed=0
```

---

## Task 4 — ban inlining the frontmatter library (Spec G item 23)

- [ ] **Step 1 — measure the premise.** Confirm the library exists and no ban does
      (`/usr/bin/grep -c 'frontmatter' reference/check-portability.sh` → 0). Then **count the
      current inlined copies before writing the check** — if any exist, the check is born red and
      the task is a conversion, not a gate.
- [ ] **Step 2 — model it on the existing link-library ban**, and read that ban's own history first:
      CLAUDE.md records that the claimed link-library ban **did not exist** for four gates and a
      127 KB review, and that the commit removing inlined matchers added a sixth. Do not repeat the
      shape of a ban that was believed rather than verified.
- [ ] **Step 3 — key on the property, not a spelling.** Divergence 12 records that every search
      string tried for the matcher class was narrower than the class, twice. State the property in
      the check's header and the known edge the pattern does not cover.
- [ ] **Step 4 — prove both directions.** Plant an inlined copy of a `frontmatter.sh` function →
      the check must fail and name the file. Remove → pass. Confirm the sanctioned library itself is
      exempt and that the exemption is **directory-anchored, not a basename match** — a basename
      exemption silently swallows any file named to resemble the library, which is the one-rename
      evasion this guard's own header rejects for `--exclude`.

**Done when:**

```bash
bash reference/check-portability.sh; echo rc=$?    # rc 0, new check listed
for s in bash zsh; do $s reference/test/guard-failure.test.sh | tail -1; done  # equal totals, failed=0
```

---

## Task 5 — the record survives

- [ ] **Step 1 — amend divergence 15** with the vault-measured half: the note enum is consistent, the
      observation and tension enums are not, and 15 did not measure that because it compared
      generator files only to each other. Amend rather than supersede — it is referenced by number.
- [ ] **Step 2 — file the three-tier structural finding as a new divergence.** No gate closes it: a
      rule added here reaches new vaults only and cannot reach an existing vault's enforced gate.
      Name the evidence (`validate-note.sh` generated-and-thin vs `validate-node-schema.py`
      hand-written-and-blocking) and state that `/arscontexta:upgrade` is the nearest mechanism and
      has never been invoked as a slash command against a real vault (divergence 5).
- [ ] **Step 3 — fill this plan's `## Deferrals`.** `none` is legal only if literally nothing was
      deferred. `.superpowers/` is gitignored; a deferral recorded only there does not exist.
- [ ] **Step 4 — re-derive every number this plan and spec state**, dated. Gate any that a gate can
      hold; say plainly which cannot and why.

**Done when:**

```bash
awk '/^## Deferrals/{f=1;next} /^## /{f=0} f&&NF' docs/superpowers/plans/2026-08-05-generator-vault-enforcement-gap.md | grep -c .
bash reference/check-doc-claims.sh; echo rc=$?     # rc 0
```

---

## Review

Two dispatches, both opus, both in **separate worktrees** (`isolation: worktree`):

- One after **Task 3** — it changes `validate-kernel.sh`, the contract every generated vault is
  measured against, and it deliberately makes a green run go red.
- One after **Task 4** — it modifies the shared portability guard, the coupling that once took
  `guard-failure.test.sh` from 19/19 to 16/3.

Final whole-branch review on the most capable model before `superpowers:finishing-a-development-branch`.

---

## Deferrals

**Required section. One line per deferral naming the tracked file it landed in, or the literal word
`none`. An empty section is a failure, not a default.** `.superpowers/` is gitignored; a deferral
recorded only there does not exist.

**Every line below names the TRACKED file the deferral landed in.** `.superpowers/sdd/` is
gitignored, so the SDD ledger does not count — that is divergence 10's entire subject, and two
commits on earlier branches claimed a record that shipped nowhere. Where a deferral's only home
would have been the ledger, it is written into this section instead, which is tracked.

| # | Deferral | Landed in |
|---|---|---|
| 1 | **39 hand-rolled frontmatter parses** across 19 files and 6 fields remain unconverted. check 7 makes them visible and un-growable; converting them is separate work. | `reference/check-portability.sh` check-7 header + its `FM_ALLOW` reasons; `CLAUDE.md` gate table |
| 2 | **`session-orient.sh.template` still parses frontmatter naively** while the plugin's own `session-orient.sh` was converted on Spec F. A live plugin/template split, and the clearest single instance of this spec's three-tier finding. | `FM_ALLOW` entry states it; divergence 16 (Task 5 Step 2) |
| 3 | **`generators/features/*.md` emit naive `rg '^status: …'` recipes** into generated vaults' docs. A recipe cannot source a library the way a fence can, so converting them changes what generation emits. | `FM_ALLOW` entries; already in `CLAUDE.md`'s divergence 7-9 closed record |
| 4 | **`platforms/shared/skill-blocks/` carries 4 naive parses and cannot be fixed in place** — check 4 pins the tree against a cksum manifest. Same standing as the won't-fix already recorded for that tree. | `FM_ALLOW` entries; `CLAUDE.md` § Won't fix |
| 5 | **The content-destruction guard counts `[[` inside fenced blocks.** The hook deliberately does not source `link-extraction.sh`, on the precedent divergence 12 records for `session-orient.sh.template`. | comment at the site in `hooks/scripts/write-validate.sh` |
| 6 | **`Write`-only PostToolUse matcher**, so Edit/MultiEdit bypass the guard entirely. Widening it fires on every edit in every installed vault — a scope decision, not a fix. | `SCOPE LIMIT` comment in `hooks/scripts/write-validate.sh` and the vault template |
| 7 | **One assertion is vacuous and labelled as such** — "TRACKED but not yet in HEAD, silent". Measured: deleting the `cat-file -e` test it nominally guards leaves the suite green, because an absent HEAD blob yields 0 bytes and neither threshold fires on 0. | in-place comment, `reference/test/hook-config.test.sh` |
| 8 | **`C1`'s violation list caps at 5** with `... and N more`. Human-facing report, not an automated decision, and it discloses both the remainder and the true total — the criterion under which `skill-sources/seed:83`'s `head -5` was assessed and left. | comment at the site in `reference/validate-kernel.sh` |
| 9 | **`f07b9eb`'s commit message says "Nine assertions"; it was eight.** Not amended — a history rewrite for a message typo costs more than it fixes. | this row |
| 10 | **`check-doc-claims.sh` takes over two minutes per run** because it executes every suite to get its totals. Fine in CI, prohibitive in a mutation loop — the first Task 2 harness needed 10 runs and was killed at 25 minutes. Speeding it up is its own design question. | this row |
| 11 | **Two `session-orient.sh` files are outside `check-prose-paths.sh`'s stated scope** and name repo paths in comments and user-visible warnings. The write-validate pair now joins them. | already open in `CLAUDE.md` divergence 5; extended by divergence 16 |

Carried in from the spec's *Deliberately not in scope* and still not in scope, unchanged:

| # | Deferral | Landed in |
|---|---|---|
| 12 | **The tension-threshold population semantics** — a change to what `self_evolution.tension_threshold` counts, not a gate. | spec § Deliberately not in scope |
| 13 | **Re-syncing existing vaults.** `/arscontexta:upgrade` is the nearest mechanism and has never been invoked as a slash command against a real vault. Its own spec. | `CLAUDE.md` divergence 5; divergence 16 (Task 5 Step 2) |
| 14 | **Building the deterministic `_schema` reader** that would make the authority claim true. A generation-surface change. | spec § Deliberately not in scope; `generators/features/schema.md` narrowed claim |

**Closed rather than deferred, recorded here because it was carried as a deferral mid-branch:**
"only 1 of 8 promoted tensions carries `promoted_to:`" is no longer open — `C1` asserts it, and the
field vault's 7 violations are 7 of the 13 it now reports.

---

## Known hazards, carried forward

- **`count_notes_by_field` recurses.** `ops/tensions/archive/` holds 14 files; today all are
  `archived`/`resolved` so the threshold reads 7 either way. An archived file that kept
  `status: open` would silently inflate it. Measured, not a defect today.
- **The vault's enforced validator is wired via `settings.json` / `settings.local.json`**, outside
  anything this repo generates. Relevant to Task 3's placement decision: even a generated hook has
  to be wired by something, and that wiring is not ours.
