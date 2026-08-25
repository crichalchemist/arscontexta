# Vocabulary Integrity Across Emitted Surfaces — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this
> plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Do NOT dispatch implementer subagents in this repo.** Three of three died of autocompact
> thrashing on packages this size. Reviewers survive; implementers do not. Execute inline.

**Goal:** Make every relationship-verb, command-name, status and description-length vocabulary in
this generator agree across all the surfaces that declare it, and make one counting site report the
values it currently drops.

**Architecture:** Five ordered units. Unit 1 is a standalone repair commit with no behavior change.
Units 2–5 split into two PRs at the schema boundary: PR 1 *declares* new vocabulary keys, PR 2
*uses* them. Declaration must precede use because `check-vocabulary-schema.sh` fails any
`{vocabulary.X}` resolving to nothing — so the two PRs cannot be reordered, and that is the correct
direction to fail.

**Tech Stack:** Markdown, YAML, POSIX shell. There is no build, no package manager, no test runner.
"Tests" are bash suites under `reference/test/` and five gate scripts under `reference/`.

**Spec:** `docs/superpowers/specs/2026-08-24-vocabulary-integrity-design.md` (commit `c5d4257`).
Read it alongside this plan — the plan states *what* to do; the spec states *why*, and several
steps below are only safe if you understand the reason.

---

## Global Constraints

Copied verbatim from the spec and from this repo's measured tooling failures. Every task's
requirements implicitly include this section.

**Tooling — these are not preferences. Each one has produced a shipped defect here.**

- **Use `/opt/local/bin/bash` to run gates and suites.** macOS `/bin/bash` is 3.2; three of five
  gates fail to *parse* on it and still **exit 0**.
- **Use `/opt/local/bin/gtimeout`.** `timeout` does not exist on macOS.
- **Use `/usr/bin/grep`, not bare `grep`.** The Claude Code shell aliases `grep` to `ugrep`, which
  masks portability bugs — `grep -P` tests clean in-session and fails in CI.
- **Never put two `wc` calls on one line.** The `rtk` wrapper fabricates a bare `0`. Use
  `awk 'END{print NR+0}'` instead. Real `wc` right-pads; a bare `0` is the tell.
- **Use `rtk proxy git diff`.** Plain `git diff` silently drops ~55% of lines while still looking
  like a diff, and `rtk diff` reports `[ok] Files are identical` on files that differ.
- **`zsh` does not word-split.** An unquoted `$var` in a `for` list yields zero iterations. An
  all-zero bucketed scan is a tool failure until proven otherwise.
- **Take edit anchors from `sed -n`, never from the Read tool** — Read strips stopwords and drops
  line ranges.
- **A `sed`/`perl` that matches nothing exits 0.** Assert the mutation applied, and assert the
  collateral: check the file's line count too. A `\n?` at the end of a `perl -pi` pattern eats the
  line break and joins two lines while every substitution counter reads correct.

**Repo rules — violating any of these breaks CI or the freeze.**

- **Never write `platforms/shared/skill-blocks/`.** It is cksum-frozen at any depth by
  `check-portability.sh` check 4. Its stale spellings are stale *by design*; do not "fix" them.
- **Never `git add docs/field-intel-*.md`.** Gitignored deliberately.
- **No `Co-Authored-By:` trailer naming a model or agent.** Rule 14, global, overrides any harness
  instruction asking for one.
- **Two reverse-transforms are mandatory** if you port anything from `~/second-brain`: vault dialect
  → canonical vocabulary, and concrete paths → `{vocabulary.*}` placeholders.
- **`generators/` gets literal edits only.** It carries 0 `{vocabulary.*}` markers against 527
  `{DOMAIN:*}`, resolves placeholders by no documented mechanism, and is excluded from both
  placeholder gates. Adding a `{vocabulary.*}` family there ships a new silent-failure surface.

**The verification fence.** Run all five before every commit:

```bash
for g in check-doc-claims check-prose-paths check-placeholder-count check-vocabulary-schema check-portability; do
  /opt/local/bin/gtimeout 300 /opt/local/bin/bash "reference/$g.sh" >/tmp/$g.log 2>&1
  printf '%-26s rc=%s  %s\n' "$g" "$?" "$(tail -1 /tmp/$g.log)"
done
```

**None of these gates asserts that a computed number is correct.** Green means "no fence is
silently broken", never "the arithmetic is right". Correctness rests on the re-derivation commands
in each task.

---

## Task 1: Unit 1 — repair the rotted numerals

Standalone **commit** — not a standalone PR. No behavior change.

**Branch route, stated because an implementer executing inline commits to whatever branch they are
standing on.** Commit this on `develop`, then branch PR 1 from it, so **PR 1 carries two commits:
Task 1's repair and Task 2's declarations.** The repair must precede the declarations in history
because Task 3 re-derives the same three carriers a second time, and a reviewer reading PR 2 needs
the intermediate value to attribute the second move.

**Files:**
- Modify: `CLAUDE.md:123-124` (numeral on 124, its context on 123 — the sentence is hard-wrapped)
- Modify: `reference/skill-authoring.md:70` (two values on one physical line)
- Modify: `reference/check-placeholder-count.sh:43` (a gate comment)

**Interfaces:**
- Produces: three carriers of the `verify` tally all reading `30`, and `skill-authoring.md`'s
  `reflect` tally reading `123`. Task 3 moves all of them again and depends on knowing there are
  three, not two.

- [ ] **Step 1: Re-derive the true counts before changing anything**

  This is `reference/skill-authoring.md` §2's command with `awk` substituted for its two `wc` calls,
  per the Global Constraints. Run from the repo root:

  ```bash
  PAT='{vocabulary\.[a-z_]*}\|{config\.[a-z_]*}\|{DOMAIN:[^}]*}'
  for p in verify validate reflect; do
    printf '%-9s source=%-4s blocks=%s\n' "$p" \
      "$(/usr/bin/grep -o "$PAT" "skill-sources/$p/SKILL.md" | awk 'END{print NR+0}')" \
      "$(/usr/bin/grep -o "$PAT" "platforms/shared/skill-blocks/$p.md" | awk 'END{print NR+0}')"
  done
  ```

  Expected:
  ```text
  verify    source=30   blocks=146
  validate  source=5    blocks=60
  reflect   source=123  blocks=203
  ```

  If any number differs, **stop**. The tree has moved since the spec was measured and every figure
  below must be re-derived rather than copied.

- [ ] **Step 2: Locate the three carriers**

  ```bash
  /usr/bin/grep -n '\b27\b' CLAUDE.md                    # 124  <- the numeral
  /usr/bin/grep -n '146 markers' CLAUDE.md               # 123  <- its context
  /usr/bin/grep -n 'That yields' reference/skill-authoring.md          # 70
  /usr/bin/grep -n 'has 27' reference/check-placeholder-count.sh       # 43
  ```

  The `CLAUDE.md` sentence is hard-wrapped: line 123 ends `…146 markers in \`verify\` where
  \`skill-sources\`` and line 124 opens `27.`. A line-grep for the sentence finds 123; a line-grep
  for the number finds 124. **Neither alone is the edit anchor** — you are editing 124 and
  reflowing 123-124 together.

- [ ] **Step 3: Edit all three carriers**

  - `CLAUDE.md:124` — `27` → `30`, then reflow lines 123-124 so the sentence still wraps sensibly.
  - `reference/skill-authoring.md:70` — `27` → `30` **and** `121` → `123`, value edits only, no
    reflow. Leave `validate` 5 against 60 **alone in this task**: it is the born-green control that
    proves the re-derivation command still binds. (It stops being a control in Task 3, which moves
    it to 11.)
  - `reference/check-placeholder-count.sh:43` — `27` → `30`. Ruled KEEP-and-repair: leaving one of
    three carriers stale is the exact failure this task exists to close. It is deliberately **not**
    registered as a gate row — a comment inside a gate cannot be asserted by that gate without
    circularity.

- [ ] **Step 4: Assert all three mutations applied and nothing else moved**

  ```bash
  echo "stale 27s remaining (expect 0):"
  /usr/bin/grep -c 'has 27' reference/check-placeholder-count.sh
  /usr/bin/grep -c '\b27\b' CLAUDE.md
  /usr/bin/grep -c '\b27\b\|\b121\b' reference/skill-authoring.md
  echo "new values present (expect 1 each):"
  /usr/bin/grep -c 'has 30' reference/check-placeholder-count.sh
  /usr/bin/grep -c '\b30\b' CLAUDE.md
  echo "line counts unchanged apart from the CLAUDE.md reflow:"
  awk 'END{print FILENAME": "NR}' reference/skill-authoring.md
  awk 'END{print FILENAME": "NR}' reference/check-placeholder-count.sh
  ```

  A `grep -c` of `0` on the "stale" block and `1` on the "new values" block is the pass. **An empty
  result is what a passing negative assertion looks like** — that is why each negative is paired
  with a positive here. Never accept the negatives alone.

- [ ] **Step 5: Run the verification fence**

  Run the fence from Global Constraints. Expected: all five `rc=0`.

  `check-doc-claims.sh` reads `CLAUDE.md` by text anchor, so a reworded sentence can turn it red
  even when the number is right. If it fails, read its message: it names the anchor it lost.

- [ ] **Step 6: Commit**

  ```bash
  git add CLAUDE.md reference/skill-authoring.md reference/check-placeholder-count.sh
  git commit -m "fix: the verify and reflect placeholder tallies rotted at three carriers

The counts moved when placeholders were added and no prose followed. verify is
30 against 146, not 27; reflect is 123 against 203, not 121. Repaired at all
three carriers rather than the two a draft named — CLAUDE.md:124,
skill-authoring.md:70, and the gate comment at check-placeholder-count.sh:43.

validate 5/60 is left alone deliberately: it is the born-green control proving
the re-derivation command still binds."
  ```

---

## Task 2: Unit 2 — declare (PR 1)

Branch PR 1 from the Task 1 commit. This task adds vocabulary keys and a schema field; it uses
neither. **PR 1 carries no `skill-sources/` placeholder change**, so
`check-placeholder-count.sh` must not move.

**Files:**
- Modify: `skills/setup/SKILL.md` — Level 6.6 block inside the `vocabulary:` schema
- Modify: `reference/vocabulary-transforms.md` — append below `:11-25`
- Modify: `generators/features/self-evolution.md:102` and `:240`
- Modify: `skill-sources/rethink/SKILL.md:232,233,335,516,357`
- Modify: `docs/superpowers/deferrals.md` — entry 12

**Interfaces:**
- Produces: six declared keys `{vocabulary.rel_extends}`, `{vocabulary.rel_grounds}`,
  `{vocabulary.rel_contradicts}`, `{vocabulary.rel_exemplifies}`, `{vocabulary.rel_synthesizes}`,
  `{vocabulary.rel_enables}`. Task 3 consumes exactly these six names — a typo here surfaces there
  as a red `check-vocabulary-schema.sh`, which is the correct direction to fail.
- Produces: a `closes:` field on both terminal-status blocks, written by five `rethink` sites.

- [ ] **Step 1: Locate the setup vocabulary block and its insertion point**

  ```bash
  /usr/bin/grep -n '^vocabulary:\|# Level 6\|# Level 7' skills/setup/SKILL.md
  ```

  Insert Level 6.6 after Level 6's existing keys and before Level 7.

- [ ] **Step 2: Declare the six relationship keys**

  One key per enum value. The comments are example spellings a derivation might choose — they are
  illustrative, not defaults:

  ```yaml
    # Level 6.6: Relationship types (one key per enum value)
    rel_extends: "[domain term]"      # e.g., "extends", "develops", "advances"
    rel_grounds: "[domain term]"      # e.g., "grounds", "supports", "establishes"
    rel_contradicts: "[domain term]"  # e.g., "contradicts", "challenges", "disputes"
    rel_exemplifies: "[domain term]"  # e.g., "exemplifies", "illustrates", "shows"
    rel_synthesizes: "[domain term]"  # e.g., "synthesizes", "combines", "unifies"
    rel_enables: "[domain term]"      # e.g., "enables", "permits", "makes possible"
  ```

  **Do not offer "builds on" as an example spelling of `rel_extends`.** The mapping table routes
  that phrase to `rel_grounds`; offering it here would make the schema contradict the table.

- [ ] **Step 3: Append the verb-family row to the transforms table**

  ```bash
  /usr/bin/sed -n '11,25p' reference/vocabulary-transforms.md
  ```

  **Append below the existing rows.** Root `CLAUDE.md:115` says *"line 14 of that file is the
  mapping table"* — inserting above line 14 silently invalidates that pointer, and **no gate reads
  it**, so nothing will tell you.

- [ ] **Step 4: Add `closes:` to both terminal-status blocks**

  ```bash
  /usr/bin/sed -n '100,104p;238,242p' generators/features/self-evolution.md
  ```

  `:102` is the **observations** register; `:240` is the **tensions** register, whose enum at `:220`
  carries `resolved | dissolved`. They are two different registers, not two observation blocks —
  a prior revision's label would have misdirected your grep.

  ```yaml
  status: implemented
  implemented_in: path/to/file      # where the fix lives
  closes: [the property this fix actually closes]
  ```

  Literal text only — `generators/` takes no `{vocabulary.*}` markers (Global Constraints).

- [ ] **Step 5: Add `closes:` to the five closure-writing sites in `/rethink`**

  ```bash
  /usr/bin/grep -n 'set `status: implemented`' skill-sources/rethink/SKILL.md
  # expect: 232, 233, 335, 516
  /usr/bin/sed -n '357p' skill-sources/rethink/SKILL.md
  # the pairing assertion: an `implemented` with no `implemented_in:` is unfalsifiable
  ```

  **This step is why the schema change is not cosmetic.** Declaring `closes:` in the generator and
  stopping there produces a vault whose schema requires a field no emitted skill ever writes — two
  surfaces of one contract disagreeing, which is this spec's own definition of the defect. The four
  recipes gain `closes:`; the assertion at `:357` extends to cover it.

  `implemented_in` appears in only two files repo-wide, so this sweep is closed:

  ```bash
  /usr/bin/grep -rln 'implemented_in' skill-sources/ generators/ skills/    # expect 2
  ```

- [ ] **Step 6: Amend `deferrals.md` entry 12 — this is not bookkeeping**

  ```bash
  /usr/bin/sed -n '238p' docs/superpowers/deferrals.md   # reads "REOPEN TRIGGER FIRED ... NOW DUE"
  ```

  Entry 12 was resequenced out of this spec to a destination that **did not exist**. Amend it in
  place with: the mechanism reason (`generators/` resolves no `{vocabulary.*}` and is excluded from
  both placeholder gates), its prerequisite (*document `{vocabulary.*}` substitution for the
  composition path, or rule that tree permanently `{DOMAIN:*}`-only*), and today's date.

  A deferral whose reopen trigger has fired, re-deferred to an unwritten document with no tracking
  entry, is precisely how `deferrals.md` itself says items get lost.

- [ ] **Step 7: Verify declaration-without-use is green**

  ```bash
  /opt/local/bin/gtimeout 300 /opt/local/bin/bash reference/check-vocabulary-schema.sh
  /opt/local/bin/gtimeout 300 /opt/local/bin/bash reference/check-placeholder-count.sh
  ```

  Expected: both PASS. Declared-but-unused keys are tolerated — `status_open`, `status_archived`
  and `status_superseded` are already declared with zero markers and the gate is green. And
  `check-placeholder-count.sh` must **not** move: this task edits `skill-sources/rethink/SKILL.md`,
  but those edits add no placeholders, so the count it scans is unchanged.

- [ ] **Step 8: Run the fence and commit**

  ```bash
  git add skills/setup/SKILL.md reference/vocabulary-transforms.md \
          generators/features/self-evolution.md skill-sources/rethink/SKILL.md \
          docs/superpowers/deferrals.md
  git commit -m "feat: declare the six relationship verbs and the closes: field

Six rel_* keys at Level 6.6 so relationship verbs become vocabulary rather than
hardcoded English, and a closes: companion to implemented_in.

closes: goes in both the generator schema and the five /rethink sites that write
closures. Schema alone would require a field no emitted skill ever writes. Both
falsified closures that motivated the field named a real, existing file, so
implemented_in resolving is not the discriminator — restating the property is.

Also amends deferrals entry 12, whose reopen trigger has fired and whose stated
destination did not exist."
  ```

---

## Task 3: Unit 3 — substitute, harmonize, re-derive (PR 2)

**Files:**
- Modify: `skill-sources/verify/SKILL.md:197`
- Modify: `skill-sources/validate/SKILL.md:146`
- Modify: `skill-sources/reflect/SKILL.md:295-300`, `:378`, `:385-388`
- Modify: `skill-sources/reduce/SKILL.md:279`, `:494`, `:781`
- Modify: `generators/features/wiki-links.md:36`, `:48-53`, `:49`, `:57` (literals only)
- Modify: `CLAUDE.md:124`, `reference/skill-authoring.md:70`,
  `reference/check-placeholder-count.sh:43` (re-derive)

**Interfaces:**
- Consumes: the six `rel_*` keys declared in Task 2. A name mismatch turns
  `check-vocabulary-schema.sh` red.
- Produces: per-file placeholder counts of verify 36, validate 11, reflect 139, reduce 141.

- [ ] **Step 1: Capture the baseline at the substitution, not from this document**

  ```bash
  PAT='{vocabulary\.[a-z_]*}\|{config\.[a-z_]*}\|{DOMAIN:[^}]*}'
  for p in verify validate reflect reduce; do
    printf '%-9s %s\n' "$p" "$(/usr/bin/grep -o "$PAT" "skill-sources/$p/SKILL.md" | awk 'END{print NR+0}')"
  done
  ```

  Expected: `verify 30`, `validate 5`, `reflect 123`, `reduce 132`. Write these down now. **A figure
  recalled after the fact is a reconstruction** — three of four such figures were wrong the last
  time this was tried here, and the one that held was the one captured at the action.

- [ ] **Step 2: Substitute the six declared enum sites**

  Adopt reflect's six verbs as the canonical enum. Replace the literal verb lists with markers:

  - `verify:197` — `extends, foundation, contradicts, enables, example` → all six markers (**+6**).
    Five wrong spellings become six right ones: `foundation`→`rel_grounds`, `example`→
    `rel_exemplifies`, plus the two members that list never had.
  - `validate:146` — same list, same treatment (**+6**).
  - `reflect:295-300` — one marker per table row, six rows (**+6**).
  - `reflect:378` — the six verbs in prose (**+6**).
  - `reduce:494` — `extends, contradicts, builds on` → `rel_extends`, `rel_contradicts`,
    `rel_grounds` (**+3**). This is a template *hint*, so three verbs is correct here.

  `builds on` → `rel_grounds` is a judgment call. Its two textual anchors cancel
  (`wiki-links.md:49` pulls toward extends, `:36` toward foundation), so what binds is
  **non-collision**: `reduce:494`'s list already contains `extends`, so routing `builds on` there
  would render "extends, contradicts, extends".

- [ ] **Step 3: Widen `reduce:279` to all six verbs — this changes behavior, not spelling**

  ```bash
  /usr/bin/sed -n '274,282p' skill-sources/reduce/SKILL.md
  ```

  Every other edit in this task is a rename. **This one is not.** `:279` reads *"Pass: extends,
  contradicts, or deepens existing {vocabulary.note_plural}"* and sits under `### 4. Connected`,
  which closes with **"If ANY criterion fails: do not extract."** It is a gating accept-list: a note
  whose relationship is *exemplifies*, *synthesizes* or *enables* fails the Connected criterion and
  is **silently not extracted**. That is Finding 6's defect one layer earlier in the pipeline.

  Substitute all six markers (**+6**, not +3). Record the before/after text in the commit — this is
  the one E-1 site a reviewer could reasonably object to on merit rather than mechanics.

- [ ] **Step 4: Substitute `reflect:385-388`**

  ```bash
  /usr/bin/sed -n '384,389p' skill-sources/reflect/SKILL.md
  ```

  Four quoted verb *tokens* in the asymmetry guidance (**+4**). These are spelling carriers: a vault
  that renames `extends` would otherwise find guidance naming a verb it does not have. That is what
  separates them from the two carriers ruled OUT below.

- [ ] **Step 5: Harmonize the literal carriers — no markers**

  - `generators/features/wiki-links.md:48-53` — replace `foundation`/`example` with the
    `grounds`/`exemplifies` spellings and add the two missing members. **Literal words only**;
    `generators/` takes no markers.
  - `generators/features/wiki-links.md:49` — reword the gloss. It currently reads
    `- **extends** — builds on an idea by adding a new dimension`. Post-Decision-1 that defines
    *extends* using the exact phrase the mapping table assigns to *grounds*. Use
    *"adds a new dimension to an idea"*.
  - `generators/features/wiki-links.md:36`, `:57` — the two gloss phrases carrying `foundation`.
  - `skill-sources/reduce/SKILL.md:781` — `- Good: "-- provides the foundation this challenges"`.
    Twin of `wiki-links.md:57`, in a **Good** example, teaching the deprecated verb from inside
    `reduce`. Harmonize as a literal: the word reads as a noun in a prose gloss, so it takes no
    marker and does not move the count.

- [ ] **Step 6: Confirm the two ruled-OUT carriers are still OUT**

  ```bash
  /usr/bin/sed -n '54p' generators/features/processing-pipeline.md
  /usr/bin/sed -n '127p' reference/open-questions.md
  ```

  Both are prose about relationship *quality*, naming two or three verbs as illustration inside a
  sentence — not spelling-family declarations. Substituting would put markers into sentences that
  are not lists and would change meaning. **Leave them.** Recorded here so a later sweep sees a
  ruling rather than a miss.

- [ ] **Step 7: Measure the delta and reconcile against the prediction**

  ```bash
  PAT='{vocabulary\.[a-z_]*}\|{config\.[a-z_]*}\|{DOMAIN:[^}]*}'
  for p in verify validate reflect reduce; do
    printf '%-9s %s\n' "$p" "$(/usr/bin/grep -o "$PAT" "skill-sources/$p/SKILL.md" | awk 'END{print NR+0}')"
  done
  ```

  Predicted: `verify 36` (+6), `validate 11` (+6), `reflect 139` (+16), `reduce 141` (+9). Total
  **+37**.

  **Reconcile; do not assert.** If the total is 33, that is the `reflect:385-388` ruling not having
  been applied — not a missed site. Any other shortfall means a site was missed or hit twice.
  Investigate before touching prose: the prose is downstream of the count.

- [ ] **Step 8: Re-derive all three tally carriers — three, not two**

  Task 1 repaired three carriers to `30`. This task moves `verify` to 36, so **all three go stale
  again**:

  - `CLAUDE.md:124` — `30` → the measured verify figure
  - `reference/skill-authoring.md:70` — verify, reflect **and validate** (5 → 11; it stopped being
    the born-green control the moment this task ran)
  - `reference/check-placeholder-count.sh:43` — `30` → the measured verify figure

  ```bash
  /usr/bin/grep -rn 'has 3[0-9]' reference/check-placeholder-count.sh
  /usr/bin/grep -n 'That yields' reference/skill-authoring.md
  /usr/bin/grep -n '146 markers' CLAUDE.md
  ```

  **No gate reads these numbers** (`/usr/bin/grep -c '146\|203' reference/check-doc-claims.sh` → 0),
  so nothing catches a skip. That is why this is a numbered step and not a note.

- [ ] **Step 9: Run the fence and commit**

  `check-placeholder-count.sh` is range-relative against the merge base and fails only on a
  *decrease*, so it will not block an increase — the per-unit bookkeeping above is for attribution,
  not enforcement. Do not mistake its PASS for a check of your arithmetic.

  ```bash
  git add skill-sources/ generators/features/wiki-links.md CLAUDE.md \
          reference/skill-authoring.md reference/check-placeholder-count.sh
  git commit -m "feat: relationship verbs become vocabulary at seven declaring sites

Seven surfaces declared a relationship enum in four different spellings and no
gate compared them, because check-vocabulary-schema.sh asserts that a marker
resolves to a declared key, never that two declarations agree.

Adopts reflect's six verbs. The six sites in skill-sources/ take markers; the
wiki-links block takes harmonized literals, since generators/ resolves no
placeholders. wiki-links:49 is reworded because it glossed extends with the
phrase the mapping table assigns to grounds.

reduce:279 changes behavior, not spelling: it gates extraction, so a three-verb
accept-list silently refused to extract notes whose relationship is exemplifies,
synthesizes or enables. It now carries all six.

Tallies re-derived at all three carriers, including validate, which stopped
being the born-green control when this landed."
  ```

---

## Task 4: Unit 4 — consume (PR 2)

**Files:**
- Modify: `hooks/scripts/session-orient.sh` — the unknown-status branch
- Modify: `reference/test/hook-config.test.sh` — fixtures and assertions
- Modify: `docs/verification.md:36` and `CONTRIBUTING.md:114` — **the pinned suite totals**

**Interfaces:**
- Consumes: nothing from Tasks 2–3. This task is independent of the vocabulary work and could run
  first; it is sequenced here only to keep PR 2 coherent.
- Produces: a report line naming off-enum statuses, plus a suite total that is no longer 60.

- [ ] **Step 1: Read the guard structure before writing anything**

  ```bash
  /usr/bin/sed -n '132,175p' hooks/scripts/session-orient.sh
  ```

  Note the asymmetry, because it is the whole hazard: `OBS_TOTAL`/`TENS_TOTAL` come from `find`
  (`:158-159`) and are **still correct** when `ops/lib/frontmatter.sh` is missing, while
  `OBS_COUNT`/`TENS_COUNT` are deliberately left `""` (`:160-171`, guarded by `FM_OK`).

- [ ] **Step 2: Build the two fixtures, then write the failing assertions**

  The suite builds fixtures explicitly and **asserts its own setup** — read `mkvault()` at `:70`,
  `staged()` at `:88` and `cfg()` at `:102` first. `mkvault` produces 12 open observations and 6
  open tensions; `staged <vault> <n-obs> <n-tensions>` fails loudly if the tree it built is not the
  tree you asked for. That guard exists because `placeholder-count.test.sh` once reported 30/30,
  28/2 and 29/1 with its subject unchanged: a silent setup failure left it measuring a tree that
  was never built.

  Use `superseded` as the off-enum value. It is outside both accept-lists and both closed lists, it
  is a real status this repo's registers have carried, and picking a concrete value here stops an
  implementer inventing one that happens to collide.

  ```bash
  # V3: a healthy vault plus two observations carrying an off-enum status.
  V3=$(mkvault)
  printf -- '---\nstatus: superseded\n---\nobservation 13\n' > "$V3/ops/observations/o13.md"
  printf -- '---\nstatus: superseded\n---\nobservation 14\n' > "$V3/ops/observations/o14.md"
  staged "$V3" 14 6 || true
  cfg "$V3" 10 5

  # V4: the same shape, with the frontmatter library removed.
  # staged() asserts the library is readable, so it MUST run before the rm --
  # this is the ordering the existing V2 block at :322-324 already uses.
  V4=$(mkvault)
  printf -- '---\nstatus: superseded\n---\nobservation 13\n' > "$V4/ops/observations/o13.md"
  staged "$V4" 13 6 || true
  cfg "$V4" 10 5
  rm -f "$V4/ops/lib/frontmatter.sh"
  ```

  Now add the assertions, mirroring the shape of the existing pinned pair at `:324-330`:

  ```bash
  # A fixture carrying an off-enum status is COUNTED and NAMED.
  eq "session-orient: off-enum status is reported"        "yes" \
     "$(orient "$V3" | grep -q 'outside the recognized set' && echo yes || echo no)"
  # With the library gone the residual is OMITTED, not rendered as 0.
  eq "session-orient: residual omitted when lib missing"  "yes" \
     "$(orient "$V4" | grep -q 'outside the recognized set' && echo no || echo yes)"
  eq "session-orient: and NOT reported as a residual of 0" "yes" \
     "$(orient "$V4" | grep -q '0 observations carry' && echo no || echo yes)"
  ```

  **The positive arm is not optional.** The two negatives pass on *absence* — they stay green
  against a branch that never fires at all. Without the first assertion the whole set passes on
  dead code.

- [ ] **Step 3: Run the suite and verify the new assertions fail**

  ```bash
  /opt/local/bin/gtimeout 300 /opt/local/bin/bash reference/test/hook-config.test.sh | tail -1
  ```

  Expected: `failed=` a nonzero number. If it reports `failed=0`, your fixtures are not reaching the
  assertions — fix that before implementing.

- [ ] **Step 4: Implement the branch inside the `FM_OK` guard**

  ```
  unknown = total − matched − known-closed        (per register, independently)
  ```

  Four things this step must get right:

  1. **Inside `[ "$FM_OK" -eq 1 ]`.** Outside it, `total − "" − ""` either errors or reports the
     entire register as unknown — a fabricated alarm arriving exactly when the tooling is broken.
  2. **Two closed lists, one per register — never a union.** Observations:
     `promoted implemented archived`. Tensions:
     `resolved dissolved promoted implemented archived blocked`. Their enums genuinely differ
     (`generators/features/self-evolution.md:88` vs `:220`), and `count_open_items()` serving both
     makes a shared list the tempting shortcut. **A union over-matches closed, which under-reports
     unknown** — the silent direction, and the one way this ships broken with every assertion green.
     Put the source line in a comment beside each list.
  3. **`count_open_items()` takes only `<dir>`** and hardcodes `pending open`. The closed count needs
     a sibling function or a parameterized call. Pick one; do not inline a third variant of the scan.
  4. **Never name a variable `status`.** It is a read-only special in zsh and assigning it aborts
     fatally — and this suite runs the hook under zsh. Use `OBS_CLOSED`/`OBS_UNKNOWN`/`TENS_*`.

  **The report line must not contain the substring `pending observations`.** Four existing
  assertions pin it (`:324-327`, `:350-353`). Use e.g. *"N observations carry a status outside the
  recognized set (of M total)."*

  Beside the CONDITION, emit the distinct off-list values on **stderr**, using the library's own
  documented idiom (`reference/lib/frontmatter.sh:80-95`): a `frontmatter_field` loop piped through
  `sort | uniq -c`. It names `wontfix` where a bare count says only "3". It cannot drive the
  threshold — it cannot tell a legitimate closure from an unknown — so it is a diagnostic, not the
  signal.

- [ ] **Step 5: Run the suite under BOTH shells**

  ```bash
  /opt/local/bin/gtimeout 300 /opt/local/bin/bash reference/test/hook-config.test.sh | tail -1
  /opt/local/bin/gtimeout 300 zsh  reference/test/hook-config.test.sh | tail -1
  ```

  Expected: `failed=0` from both, with a `passed=` above 60. **The zsh arm is the one that catches
  the read-only `status` hazard** — the gate pins only the bash total, but CI runs both.

- [ ] **Step 6: Update the two pinned totals IN THIS SAME COMMIT**

  ```bash
  /usr/bin/grep -n 'hook-config' docs/verification.md CONTRIBUTING.md
  # docs/verification.md:36   ... # 60/60
  # CONTRIBUTING.md:114       ... # expect: passed=60 failed=0
  ```

  `check-doc-claims.sh` does not merely grep — `truth_suite()` at `:69` **runs** the suite and
  compares its passed total against these two declarations. Your new assertions move the total off
  60 and the gate goes red through its *data* changing, not its logic.

  Use the number you measured in Step 5, not a number predicted here — it depends on how many
  assertions you wrote.

  **Split across two commits, PR 2 is red at the intermediate commit**, and the gate's own message
  ("Fix document, not gate") will read like an invitation to edit the gate. It is not.

  Confirm there is no third carrier before you trust "two" — the `27` tally had three where a draft
  said two:

  ```bash
  git -c core.quotePath=false ls-files | xargs /usr/bin/grep -n 'hook-config.*60\|60.*hook-config'
  ```

  One hit in `docs/superpowers/reviews/` cites `:60` as a *line number*. That is a false positive.

- [ ] **Step 7: Run the fence and commit**

  ```bash
  git add hooks/scripts/session-orient.sh reference/test/hook-config.test.sh \
          docs/verification.md CONTRIBUTING.md
  git commit -m "feat: session-orient reports statuses outside the accept-list

count_open_items matched pending and open; every other status vanished between
numerator and denominator, so a register full of off-enum notes reported clean.
The residual is now counted and named.

The two closed lists are per-register and deliberately not unioned: the enums
differ, and a union over-matches closed, which under-reports unknown — failing
in the silent direction this hook exists to prevent.

The branch sits inside the FM_OK guard. OBS_TOTAL survives a missing frontmatter
library while OBS_COUNT does not, so an unguarded subtraction would report the
whole register as unknown exactly when the tooling is broken.

docs/verification.md and CONTRIBUTING.md move in this commit because
check-doc-claims.sh runs the suite and compares against both pinned totals."
  ```

---

## Task 5: Unit 5 — independent (PR 2)

Two unrelated closures. Split into **two commits** for attribution: `check-placeholder-count.sh`
does not scan `reference/`, so no gate distinguishes them.

**Files:**
- Modify: `skill-sources/graph/SKILL.md` (×6), `skill-sources/reduce/SKILL.md` (×3),
  `skill-sources/stats/SKILL.md` (×2)
- Modify: `generators/features/atomic-notes.md:75`, `generators/features/schema.md:18`
- Modify: `reference/kernel.yaml:57`, `reference/templates/*.md:2` (×8),
  `reference/methodology.md:55`

- [ ] **Step 1: Strip the leading slash at the 11 call sites**

  ```bash
  /usr/bin/grep -rn '/{vocabulary\.cmd_' skill-sources/    # expect 11: graph 6, reduce 3, stats 2
  ```

  Fix the **call sites**, not the stored value. 17 bare `{vocabulary.cmd_*}` sites already assume
  slash-in-value, so the storage convention is the majority — changing the value would break 17 to
  fix 11.

- [ ] **Step 2: Verify and commit E-4**

  ```bash
  /usr/bin/grep -rn '/{vocabulary\.cmd_' skill-sources/ | awk 'END{print NR+0}'   # expect 0
  /usr/bin/grep -rn '{vocabulary\.cmd_' skill-sources/ | awk 'END{print NR+0}'    # expect 28
  ```

  Paired positive and negative — an empty negative alone is indistinguishable from a broken grep.

  ```bash
  git add skill-sources/graph/SKILL.md skill-sources/reduce/SKILL.md skill-sources/stats/SKILL.md
  git commit -m "fix: strip the doubled slash at 11 command call sites

The stored value carries its own sigil and 17 bare call sites already assume it.
Fixing the value would have broken 17 to fix 11."
  ```

- [ ] **Step 3: Re-derive the `~150` residue tree-wide before editing**

  ```bash
  git -c core.quotePath=false ls-files -z | xargs -0 /usr/bin/grep -n '~150'
  ```

  Expected: 75 hits across 36 files. **The spec's original two-site figure came from a command
  scoped to `generators/` and `skill-sources/`** — the same too-narrow-discovery failure this spec
  diagnoses for E-1, reproduced one section later. Re-run tree-wide; do not trust either number.

- [ ] **Step 4: Move all twelve normative carriers to `200`**

  | Site | Count |
  |---|---|
  | `generators/features/atomic-notes.md:75`, `generators/features/schema.md:18` | 2 |
  | `reference/kernel.yaml:57` | 1 |
  | `reference/templates/{base,companion,creative,learning,life,relationship,research,therapy}-note.md:2` | 8 |
  | `reference/methodology.md:55` | 1 |

  Entry #6 states its own condition — *fix them together or not at all*. Editing the two
  `generators/` sites while the **kernel contract** keeps saying `~150` closes the entry while the
  disagreement survives.

  **KEEP `reference/claim-map.md:84`** (*"~150 chars may not accommodate all styles"*): it discusses
  the tension rather than declaring the value, and rewriting it erases the record of why the
  question was open.

  Carry the `no period` clause **uniformly** — `schema.md:18` and `base-note.md:2` have it; the
  other ten do not. Do not preserve that inconsistency.

  **Do not touch** `platforms/shared/skill-blocks/reduce.md:501,753` (cksum-frozen, stale by
  design) or the `methodology/` corpus (249 research claims, not a declaration surface). Two false
  hits stay as they are: `skills/architect/SKILL.md:482` (`"line ~150"`, a line number) and
  `reference/semantic-vs-keyword.md:244` (`"~150 notes"`, a volume threshold).

- [ ] **Step 5: Assert the residue is closed and nothing frozen moved**

  ```bash
  git -c core.quotePath=false ls-files -z | xargs -0 /usr/bin/grep -ln '~150' \
    | /usr/bin/grep -v '^methodology/' | /usr/bin/grep -v '^platforms/shared/skill-blocks/' \
    | /usr/bin/grep -v '^docs/'
  ```

  Expected: only `reference/claim-map.md` (ruled KEEP), `skills/architect/SKILL.md` and
  `reference/semantic-vs-keyword.md` (both false hits). Anything else is a missed carrier.

  ```bash
  /opt/local/bin/gtimeout 300 /opt/local/bin/bash reference/check-portability.sh | tail -3
  ```

  Expected: `PASS 16 frozen templates unchanged`. If this fails you edited the frozen mirror.

- [ ] **Step 6: Run the fence, close the deferrals, and commit**

  Mark entries 6 and 32.1 `CLOSED` in place in `docs/superpowers/deferrals.md` — **in place, not
  deleted**; the register marks rather than removes.

  ```bash
  git add generators/features/atomic-notes.md generators/features/schema.md \
          reference/kernel.yaml reference/templates/ reference/methodology.md \
          docs/superpowers/deferrals.md
  git commit -m "fix: the description-length disagreement at all twelve normative sites

200 is canonical. ~150 survived at twelve declaring sites, not the two the
deferral named — including reference/kernel.yaml, the invariant contract, which
would otherwise disagree with the generators feeding it, and eight shipped note
templates that teach ~150 to every vault instantiating one.

Entry 6 says fix them together or not at all, so a two-site edit would have
closed the entry while the disagreement survived. claim-map.md:84 is kept: it
discusses the tension rather than declaring the value."
  ```

---

## Final verification

- [ ] **Step 1: Full fence, both shells**

  ```bash
  for g in check-doc-claims check-prose-paths check-placeholder-count check-vocabulary-schema check-portability; do
    /opt/local/bin/gtimeout 300 /opt/local/bin/bash "reference/$g.sh" >/tmp/$g.log 2>&1
    printf '%-26s rc=%s  %s\n' "$g" "$?" "$(tail -1 /tmp/$g.log)"
  done
  for t in reference/test/*.test.sh; do
    printf '%-46s %s\n' "$t" "$(/opt/local/bin/gtimeout 300 /opt/local/bin/bash "$t" 2>/dev/null | tail -1)"
  done
  ```

  All five gates `rc=0`. Every suite `failed=0`.

- [ ] **Step 2: Confirm the fence-gate actually ran, rather than skipping**

  Read the `files=` / `run=` / `skipped=` line. **A non-parsing fence is SKIPPED, not failed** — a
  PASS with a nonzero `skipped=` is not a pass. It is also not concurrency-safe; run it alone.

- [ ] **Step 3: Confirm no seventh E-1 spelling survives**

  ```bash
  git -c core.quotePath=false ls-files '*.md' | xargs /usr/bin/grep -n 'contradicts' \
    | /usr/bin/grep -v '{vocabulary' | /usr/bin/grep -v '^platforms/shared/skill-blocks/'
  ```

  Every remaining hit should be one of the eleven ruled-OUT residuals (ordinary English ×2,
  detection rules ×5, `reweave` content-evolution ×4) or the two ruled-OUT partial carriers. A hit
  outside those classes is a carrier this plan missed.

- [ ] **Step 4: Open the two PRs**

  **PR 1 = Tasks 1 + 2** (the repair commit, then the declarations). **PR 2 = Tasks 3–5.** Per this
  fork's convention, feature branches PR into **`crichalchemist:main`**, not upstream.

  PR 2 branches from PR 1's head, not from `main`: Task 3 consumes the six `rel_*` keys Task 2
  declares, and `check-vocabulary-schema.sh` fails any marker resolving to nothing.
