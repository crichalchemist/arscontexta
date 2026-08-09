# Note Convention and Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the trailing-period convention arrive where notes are written instead of being enforced per-note afterwards, and give the note lifecycle an entry state so its transition can actually fire.

**Architecture:** Both items converge on the same two files. `/reduce` gains a status stamp and a mechanical description strip at creation; `/verify` loses two WARN sites and gains the promotion. A one-pass normalizer clears the existing backlog, and four new vocabulary keys make lifecycle states derivable so a vault that renames them stays conforming.

**Tech Stack:** Markdown skill templates, YAML frontmatter, bash fences, `reference/lib/frontmatter.sh`.

**Source spec:** `docs/superpowers/specs/2026-08-08-corpus-wide-passes-design.md` — items 1 and 3. Item 2 is `docs/superpowers/plans/archive/2026-08-08-link-edge-map.md` and is independent of this plan; either may land first.

## Why items 1 and 3 are one plan

The spec calls its three items "independently shippable." Items 1 and 3 are not independent of *each other*: both edit `skill-sources/reduce/SKILL.md` and `skill-sources/verify/SKILL.md`, both change what a newly created note looks like, and both touch the field vault's 11 templates. Planned separately they would conflict on every shared file.

## Global Constraints

- **Canonical vocabulary only.** Write `preliminary`, never `draft`. `draft` is the field vault's dialect and appears **0 times** in `skill-sources/` or `generators/`; writing it in ships one user's vocabulary to every future system.
- **Placeholders, not paths.** `{vocabulary.notes}`, never `nodes/`. `check-placeholder-count.sh` fails a template that loses placeholders across the range.
- **Frontmatter reads go through the library.** `reference/lib/frontmatter.sh` repo-side, `ops/lib/frontmatter.sh` vault-side. A line-anchored `grep '^status:'` is what `check-portability.sh` check 7 bans, and it matches the body.
- **New vocabulary keys must be flat, two-space, and BEFORE the `# Level 7:` marker.** `check-vocabulary-schema.sh` extracts declared keys with `sed -n '/^vocabulary:/,/# Level 7:/{/^  [a-zA-Z_]*: /p;}'`. A dotted key cannot resolve; a key after that marker looks correctly placed and reads as undeclared.
- **Both shells** for every gate run: `bash` and `zsh`.
- **A status change is a semantic claim.** Every promotion is reported in output, never silent.

---

## File Structure

| file | responsibility | change |
|---|---|---|
| `skills/setup/SKILL.md` | derivation; vocabulary schema | +4 lifecycle keys |
| `reference/vocabulary-transforms.md` | canonical → domain-native mapping | first non-command rows |
| `skill-sources/reduce/SKILL.md` | note creation | stamp status; strip trailing period |
| `skill-sources/verify/SKILL.md` | note verification | −2 WARN, −1 auto-fix line, +promotion |
| `skill-sources/validate/SKILL.md` | schema audit | −1 WARN |
| `skill-sources/normalize/SKILL.md` | **new** — the one-pass normalizer | created |
| `reference/normalize-descriptions.sh` | **new** — repo-side twin, pointable at a vault | created |
| `generators/features/templates.md` | emitted template spec | clause made survivable |
| `skills/upgrade/SKILL.md` | vault repair | +§6e status-key backfill |
| `docs/superpowers/deferrals.md` | the ledger | entries 5, 6, 7 updated |

---

## Task 1: Declare the four lifecycle vocabulary keys

**Files:**
- Modify: `skills/setup/SKILL.md` (vocabulary block, before line 1187)
- Modify: `reference/vocabulary-transforms.md`

**Interfaces:**
- Produces: `{vocabulary.status_preliminary}`, `{vocabulary.status_open}`, `{vocabulary.status_active}`, `{vocabulary.status_archived}` — resolvable by `check-vocabulary-schema.sh`. Every later task consumes these names verbatim.

- [ ] **Step 1: Confirm the insertion point before editing**

```bash
grep -n '^vocabulary:' skills/setup/SKILL.md      # 1151
grep -n '# Level 7:' skills/setup/SKILL.md        # 1187 -- the extractor's RANGE END
```

**Keys must go before the `# Level 7:` line.** After it they fall outside the extractor's range and read as undeclared while looking correctly placed in the file.

- [ ] **Step 2: Insert the block immediately before `# Level 7:`**

```yaml
  # Level 6b: Lifecycle states (the note status enum)
  # Flat keys, not nested: check-vocabulary-schema.sh extracts declared keys with
  # /^  [a-zA-Z_]*: / -- no dots, one indent level. {vocabulary.status.entry} is
  # unrepresentable and would report as an UNDECLARED key rather than an error.
  status_preliminary: "[domain term]"  # e.g., "preliminary", "draft", "seedling"
  status_open: "[domain term]"         # e.g., "open", "in progress"
  status_active: "[domain term]"       # e.g., "active", "established"
  status_archived: "[domain term]"     # e.g., "archived", "retired"
```

- [ ] **Step 3: Prove the keys resolve — a negative control first**

```bash
bash reference/check-vocabulary-schema.sh 2>&1 | tail -2
```

Expected PASS. **But PASS here is also what "the keys were never read" looks like**, since nothing uses them yet. Prove the extractor sees them:

```bash
sed -n '/^vocabulary:/,/# Level 7:/{/^  [a-zA-Z_]*: /p;}' skills/setup/SKILL.md | grep -c '^  status_'
```

Expected: `4`. **If this is 0, the block landed after the `# Level 7:` marker** — move it up.

- [ ] **Step 4: Add the mapping rows**

`reference/vocabulary-transforms.md` currently maps command names only. Add a lifecycle-state section with the same table shape, noting it is the file's first non-command family and that the mapping is partial — the field vault has `superseded` with no canonical counterpart and no `open`.

- [ ] **Step 5: Commit**

```bash
git add skills/setup/SKILL.md reference/vocabulary-transforms.md
git commit -m "Declare four lifecycle vocabulary keys

Status values are vocabulary, not literals: a literal 'preliminary' ships a
/verify that promotes a value the vault never writes, in exactly the vaults that
renamed it. The field vault renamed it to 'draft', so this is not hypothetical.

Flat keys before the '# Level 7:' marker, both dictated by the gate's extractor
(/^  [a-zA-Z_]*: / between ^vocabulary: and that marker). A dotted key cannot
resolve, and it would report as UNDECLARED rather than as malformed -- so the
natural response is to try to declare it, which cannot succeed.

vocabulary-transforms.md's first non-command rows. The mapping is partial: the
field vault has 'superseded' with no canonical counterpart and no 'open'."
```

---

## Task 2: `/reduce` stamps the status and strips the trailing period

**Files:**
- Modify: `skill-sources/reduce/SKILL.md:473` (the emitted note template) and the fence that writes notes

**Interfaces:**
- Consumes: `{vocabulary.status_preliminary}` (Task 1)
- Produces: every note `/reduce` creates carries `status: {vocabulary.status_preliminary}` and a description with no trailing period.

**Both items land here together** because they edit the same template block. Splitting them means two conflicting edits to one region.

- [ ] **Step 1: Confirm the template has no status field today**

```bash
sed -n '470,480p' skill-sources/reduce/SKILL.md
```

Expected: `description:`, `type:`, `created:`, `[domain-specific fields…]` — **no `status:`**. This is why the spec's original transition could never have fired.

- [ ] **Step 2: Add the status line to the emitted template**

```markdown
---
description: [~150 chars elaborating the claim, adds info beyond title, NO trailing period]
type: [claim | methodology | problem | learning | tension]
status: {vocabulary.status_preliminary}
created: YYYY-MM-DD
[domain-specific fields from derivation-manifest]
---
```

- [ ] **Step 3: Add the mechanical post-write strip**

A prose instruction already failed once — the clause is declared four times in `generators/` and reached **zero** of the field vault's 11 templates. Prose is necessary and demonstrably not sufficient, so add the mechanical guarantee to the fence that writes notes:

```bash
FM_LIB="ops/lib/frontmatter.sh"
if [ -r "$FM_LIB" ]; then
  . "$FM_LIB"
else
  echo "error: frontmatter library not found at '$FM_LIB'" >&2
  echo "       run /arscontexta:upgrade to restore it" >&2
  exit 1
fi
: "${FRONTMATTER_VERSION:=0}"
if [ "$FRONTMATTER_VERSION" -lt 3 ]; then
  echo "error: frontmatter library is version $FRONTMATTER_VERSION; this skill needs >= 3" >&2
  echo "       run /arscontexta:upgrade to refresh it" >&2
  exit 1
fi

# Strip a trailing period from the description of each note just written.
# BOTH terminated forms: a bare '.' and a '.' before a closing quote. On the
# field vault those are 1621 and 12 respectively -- handling only the bare form
# silently leaves 12 behind, which is how the published count and the published
# command came apart in the spec's first revision.
for f in "$@"; do
  [ -f "$f" ] || continue
  d=$(frontmatter_field "$f" description) || continue
  [ -n "$d" ] || continue
  stripped=$(printf '%s' "$d" | sed -E 's/\.$//; s/\.("|'"'"')$/\1/')
  [ "$stripped" = "$d" ] && continue
  # Rewrite ONLY the description line, and only inside frontmatter.
  awk -v new="description: $stripped" '
    NR==1 && $0=="---" { print; infm=1; next }
    infm && $0=="---"  { print; infm=0; next }
    infm && /^description:/ { print new; next }
    { print }
  ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  echo "  normalized description: $(basename "$f")"
done
```

- [ ] **Step 4: Smoke-test the strip against a fixture covering both forms**

```bash
T=$(mktemp -d); mkdir -p "$T/notes"
printf -- '---\ndescription: A sentence with a period.\nstatus: preliminary\n---\nbody: not a description line.\n' > "$T/notes/a.md"
printf -- '---\ndescription: "A quoted one."\n---\nbody\n' > "$T/notes/b.md"
printf -- '---\ndescription: Already clean\n---\nbody\n' > "$T/notes/c.md"
# run the strip loop over "$T"/notes/*.md, then:
grep -h '^description:' "$T"/notes/*.md
rm -rf "$T"
```

Expected: `A sentence with a period` / `"A quoted one"` / `Already clean` — and **the body line ending in a period in `a.md` must be untouched.** Verify that explicitly; an unanchored `sed` on the whole file would eat it.

- [ ] **Step 5: Run the gates**

```bash
bash reference/check-vocabulary-schema.sh 2>&1 | tail -1
bash reference/check-placeholder-count.sh main 2>&1 | tail -1
bash reference/test/fence-isolation.test.sh 2>&1 | tail -3
zsh  reference/test/fence-isolation.test.sh 2>&1 | tail -3
```

- [ ] **Step 6: Commit**

```bash
git add skill-sources/reduce/SKILL.md
git commit -m "reduce: stamp the lifecycle entry state and strip the description period

Two items, one file, one commit -- they edit the same template block.

The status stamp gives the lifecycle an ENTRY. The canonical emitted template
had no status field at all and generators/features/templates.md:27 lists status
as optional, so notes were born statusless and a preliminary -> active
transition could never have fired.

The strip is mechanical because prose already failed here: the no-trailing-period
clause is declared four times in generators/ and reached ZERO of the field
vault's 11 templates. Prose is necessary and demonstrably not sufficient.

Handles BOTH terminated forms, bare '.' and '.' before a closing quote -- 1621
and 12 on the field vault. Rewrites only the description line and only inside
frontmatter; the fixture pins that a body line ending in a period survives."
```

---

## Task 3: `/verify` promotes, and loses its two WARN sites

**Files:**
- Modify: `skill-sources/verify/SKILL.md` — `:174` (WARN), `:271` (auto-fix list line), `:372` (WARN), plus a new promotion step

**Interfaces:**
- Consumes: `{vocabulary.status_preliminary}`, `{vocabulary.status_active}` (Task 1)

- [ ] **Step 1: Re-derive all three line numbers**

```bash
grep -n 'trailing period\|Trailing period' skill-sources/verify/SKILL.md
```

Expected `:174`, `:271`, `:372`. Do not trust these numbers if Task 2 edited this file — it did not, but re-derive anyway.

- [ ] **Step 2: Delete the three trailing-period lines**

| line | current text |
|---|---|
| `:174` | `\| Format \| Single sentence, no trailing period \| WARN \|` |
| `:271` | `- Trailing period on description` |
| `:372` | `\| description format \| No trailing period \| WARN \|` |

`:174` is a row in a checks table and `:372` a row in a report table — delete the rows, not the tables. `:271` is a bullet under *Auto-fix (safe to apply)*.

**Removing the WARN is safe because it gates nothing.** It is orientation output, not a threshold input — unlike the observation/tension counts, where a mislabelled number changes whether `/rethink` fires.

- [ ] **Step 3: Add the promotion, after the checks and before the report**

```bash
# (frontmatter library stanza, as in Task 2 Step 3 -- fences are separate shells)

# Promote only on a clean run. A status change is a semantic claim, so it is
# reported, never silent.
if [ "$VERIFY_FAIL_COUNT" -eq 0 ]; then
  cur=$(frontmatter_field "$NOTE_FILE" status) || cur=""
  if [ -z "$cur" ]; then
    # ABSENT is skipped, never promoted. Absence is overloaded -- "created
    # before the stamp" and "someone deleted the field" are indistinguishable,
    # so intent cannot be inferred from it.
    echo "  status: absent — skipped (not promoted; see deferrals.md entry 5)"
  elif [ "$cur" = "{vocabulary.status_preliminary}" ]; then
    awk -v new="status: {vocabulary.status_active}" '
      NR==1 && $0=="---" { print; infm=1; next }
      infm && $0=="---"  { print; infm=0; next }
      infm && /^status:/ { print new; next }
      { print }
    ' "$NOTE_FILE" > "$NOTE_FILE.tmp" && mv "$NOTE_FILE.tmp" "$NOTE_FILE"
    echo "  status: {vocabulary.status_preliminary} → {vocabulary.status_active}"
  else
    echo "  status: $cur — unchanged"
  fi
fi
```

- [ ] **Step 4: Verify idempotence and the three status states by hand**

| starting status | expected |
|---|---|
| `preliminary` | promoted to `active`, transition printed |
| `active` | unchanged, "unchanged" printed |
| absent | skipped, "absent — skipped" printed, **file not modified** |
| any, with a FAIL in the run | unchanged, nothing printed |

Run `/verify` twice on the same `preliminary` note: the second run must print `unchanged`, not promote again.

- [ ] **Step 5: Run the gates, both shells**

```bash
bash reference/check-vocabulary-schema.sh 2>&1 | tail -1
bash reference/check-portability.sh 2>&1 | tail -1     # check 7: no hand-rolled frontmatter parse
bash reference/test/fence-isolation.test.sh 2>&1 | tail -3
zsh  reference/test/fence-isolation.test.sh 2>&1 | tail -3
```

- [ ] **Step 6: Commit**

```bash
git add skill-sources/verify/SKILL.md
git commit -m "verify: promote preliminary -> active, drop the trailing-period WARN

The promotion reuses the gate that already exists rather than adding a
mechanism: a note that clears verification is what 'no longer preliminary'
means.

Three deliberate limits. An ABSENT status is skipped and never promoted --
absence is overloaded, since 'created before the stamp' and 'someone deleted the
field' are indistinguishable. 'open' is untouched: canonical declares it and
nothing defines its semantics. No retroactive backfill; the 681 statusless
field-vault notes are deferrals.md entry 5.

The trailing-period WARN goes because the convention now arrives at creation.
It gated nothing -- orientation output, not a threshold input."
```

---

## Task 4: `/validate` loses its trailing-period row

**Files:**
- Modify: `skill-sources/validate/SKILL.md:88`

- [ ] **Step 1: Re-derive and delete the row**

```bash
grep -n 'trailing period' skill-sources/validate/SKILL.md    # :88
```

Delete: `| No trailing period | Convention: descriptions don't end with periods | Check last character |`

- [ ] **Step 2: Confirm nothing else in the file depends on it**

```bash
grep -n 'period' skill-sources/validate/SKILL.md    # expect no remaining hits
```

- [ ] **Step 3: Gates and commit**

```bash
bash reference/test/fence-isolation.test.sh 2>&1 | tail -3
git add skill-sources/validate/SKILL.md
git commit -m "validate: drop the trailing-period check row

Last of the three per-note check sites. The convention now arrives at creation
(reduce stamps it mechanically), so checking for it afterwards is the per-node
treadmill this work exists to remove."
```

---

## Task 5: The one-pass normalizer, shipping twice

**Files:**
- Create: `skill-sources/normalize/SKILL.md` (vault-side, sources `ops/lib/frontmatter.sh`)
- Create: `reference/normalize-descriptions.sh` (repo-side, sources `reference/lib/frontmatter.sh`, takes a vault path)

**Interfaces:**
- Consumes: `frontmatter_field` from the frontmatter library
- Produces: nothing other tasks read

**It ships twice because of divergence 16** — the generator reaches vaults not yet created, so a `skill-sources/` template alone cannot touch the existing 1633 notes.

- [ ] **Step 1: Write the repo-side script**

Same strip logic as Task 2 Step 3, but iterating a vault's notes directory, with:

- a **dry-run default** — `--apply` required to write. A 1633-file mutation must not be one keystroke away.
- a **count printed before and after**, so the run reports what it changed.
- **no scan cap.** No `head -N` anywhere. Divergence 11 was a `head -100` reporting a sample as a property of the graph.
- **fail loud on a missing vault**, never an empty successful run.

- [ ] **Step 2: Verify the dry run changes nothing**

```bash
cp -a ~/second-brain /tmp/vault-copy
bash reference/normalize-descriptions.sh /tmp/vault-copy | tail -3
diff -rq ~/second-brain/nodes /tmp/vault-copy/nodes && echo "DRY RUN CLEAN: no files changed"
```

**If `diff` reports differences, the dry run is writing** — stop and fix before going near the real vault.

- [ ] **Step 3: Verify `--apply` on the copy, and count both forms**

```bash
bash reference/normalize-descriptions.sh /tmp/vault-copy --apply | tail -3
# re-derive the remaining count on the copy -- expect 0
```

Expected: 1633 changed (1621 bare + 12 quoted), 0 remaining. **If it reports 1621, the quoted form was missed.**

- [ ] **Step 4: Write the vault-side skill template**

`skill-sources/normalize/SKILL.md` — same logic, `{vocabulary.notes}` for the directory, `ops/lib/frontmatter.sh` for the library, the fail-loud guard naming `/arscontexta:upgrade`.

- [ ] **Step 5: Gates**

```bash
bash reference/check-placeholder-count.sh main 2>&1 | tail -1
bash reference/check-vocabulary-schema.sh 2>&1 | tail -1
bash reference/check-prose-paths.sh 2>&1 | tail -1
bash reference/test/fence-isolation.test.sh 2>&1 | tail -3
zsh  reference/test/fence-isolation.test.sh 2>&1 | tail -3
```

- [ ] **Step 6: Clean up and commit**

```bash
rm -rf /tmp/vault-copy
git add skill-sources/normalize/SKILL.md reference/normalize-descriptions.sh
git commit -m "Add the description normalizer, shipping twice

Divergence 16: the generator reaches vaults not yet created, so a skill-sources
template alone cannot touch the field vault's existing 1633 notes. The repo-side
twin can be pointed at a vault.

Dry-run by default; --apply required. A 1633-file mutation should not be one
keystroke away. No scan cap anywhere -- divergence 11 was a head -100 reporting
a sample as a property of the whole graph.

Verified on an rsync copy: dry run changes nothing (diff -rq clean), --apply
clears 1633 = 1621 bare + 12 quote-terminated, 0 remaining."
```

---

## Task 6: Make the clause survive derivation, and repair the 11 vault templates

**Files:**
- Modify: `generators/features/templates.md`
- Vault-side: the field vault's 11 node templates

- [ ] **Step 1: Establish that the clause is not arriving**

```bash
grep -rn 'period' generators/features/templates.md          # the generator DOES declare it
/usr/bin/grep -lc 'period' ~/second-brain/templates/*.md    # 11 files, every one reports 0
```

**The generator declares it and zero derived templates carry it.** That is the root cause of the 61%, and the normalizer alone would leave the 1634th note to be written the same way.

- [ ] **Step 2: Strengthen the generator's template spec**

The generated template's `constraints.description` block is derived, not copied — the field vault's reads `format: "One sentence adding context beyond the title…"` where the generator's says `"max 200 chars, no trailing period"`. Make the clause explicit as a required element of the emitted `format:` string, so a derived value that drops it is visibly wrong rather than plausibly paraphrased.

- [ ] **Step 3: Repair the 11 vault templates**

Vault-side, one-time. Add the clause to each `constraints.description.format` string.

```bash
/usr/bin/grep -lc 'period' ~/second-brain/templates/*.md    # expect 11 non-zero after
```

- [ ] **Step 4: Commit the generator half**

```bash
git add generators/features/templates.md
git commit -m "Make the no-trailing-period clause survive derivation

The generator declares the clause four times and ZERO of the field vault's 11
derived templates carry it. That -- not the practice rejecting the rule -- is
why 61% of descriptions end in a period. The corpus was never asked.

The vault-side repair to the 11 templates is not in this commit: divergence 16,
no generator path reaches an existing vault."
```

---

## Task 7: `/upgrade` §6e — backfill the status keys without resetting a tuned enum

**Files:**
- Modify: `skills/upgrade/SKILL.md` — new §6e after §6d (line 935), before Step 7 (line 967)

- [ ] **Step 1: Read §6d as the pattern to follow**

```bash
sed -n '935,966p' skills/upgrade/SKILL.md
```

- [ ] **Step 2: Write §6e with the guard that 5g got wrong**

An existing vault has no `status_*` keys. Adding them must **not** overwrite a vault whose enum is already tuned.

**This is 5g's failure mode exactly**: it seeded `10/5` defaults beneath a vault's configured `20/10` because its guard tested only whether the block was *present*, not whether it was *tuned*. Here the equivalent error is writing `status_preliminary: "preliminary"` into a vault whose notes all say `draft`.

The correct behaviour, in order:

1. If the four keys already exist — report `[current]`, write nothing.
2. If absent, **derive the values from the vault's own template enum** rather than defaulting. A vault reading `draft | active | superseded | archived` must end at `status_preliminary: "draft"`.
3. If the vault's enum cannot be read, **report and write nothing.** Do not fall back to canonical defaults — that is precisely the silent reset.
4. Report every key written, and every value derived, with its source.

- [ ] **Step 3: Note the partial mapping explicitly**

The field vault has `superseded` with no canonical counterpart and no `open`. The backfill must not invent a key for `superseded` or leave `status_open` pointing at nothing. State the handling in the section text.

- [ ] **Step 4: Verify against a copy in three states**

| vault state | expected |
|---|---|
| keys already present, tuned | `[current]`, nothing written |
| keys absent, template enum readable (`draft \| active \| …`) | `status_preliminary: "draft"` derived and reported |
| keys absent, template enum unreadable | reported, **nothing written** |

- [ ] **Step 5: Gates and commit**

```bash
bash reference/check-vocabulary-schema.sh 2>&1 | tail -1
bash reference/test/fence-isolation.test.sh 2>&1 | tail -3
zsh  reference/test/fence-isolation.test.sh 2>&1 | tail -3
git add skills/upgrade/SKILL.md
git commit -m "upgrade 6e: backfill lifecycle vocabulary keys without resetting a tuned enum

Derives values from the vault's OWN template enum rather than defaulting, so a
vault reading 'draft | active | superseded | archived' ends at
status_preliminary: \"draft\" and stays conforming.

Writes nothing when the enum cannot be read. Falling back to canonical defaults
there is exactly 5g's failure mode, which seeded 10/5 beneath a vault's
configured 20/10 because its guard tested for PRESENCE rather than TUNING.

The mapping is partial in both directions and the section says so: the field
vault has 'superseded' with no canonical counterpart and no 'open'."
```

---

## Task 8: Update the ledger and CLAUDE.md

**Files:**
- Modify: `docs/superpowers/deferrals.md` — entries 5, 6, 7
- Modify: `CLAUDE.md` if any count it states has moved

- [ ] **Step 1: Re-derive every number before writing one**

```bash
. reference/lib/frontmatter.sh
bare=0; quoted=0
for f in ~/second-brain/nodes/*.md; do
  d=$(frontmatter_field "$f" description 2>/dev/null) || continue
  case "$d" in *.) bare=$((bare+1));; *.\"|*.\') quoted=$((quoted+1));; esac
done
echo "$bare + $quoted"
```

- [ ] **Step 2: Update the affected ledger entries**

Entry 5 (the 681 statusless notes) stays open — the stamp is forward-only. Entry 6 (`~150` vs `200`) stays open. Entry 7 (off-enum statuses) stays open. **Add what changed:** entry 5 should now note that new notes carry a status, so 681 is a closed set that cannot grow.

- [ ] **Step 3: Run the doc gate**

```bash
bash reference/check-doc-claims.sh 2>&1 | tail -3     # ~100s
```

- [ ] **Step 4: Commit**

---

## Self-Review

**Spec coverage.** Item 1's four parts map to Tasks 5 (normalizer), 6 (template repair), 3+4 (remove per-note checks), 2 (mechanical strip). Item 3 maps to Tasks 1 (vocabulary keys), 2 (stamp), 3 (promotion), 7 (backfill). The vocabulary-family decision including the extractor constraints is Task 1. The three deliberate limits — absent skipped, `open` untouched, no backfill — are Task 3 Step 3 and its commit message.

**Gap I am naming rather than leaving implicit:** the spec says the enum declarations in `generators/features/{schema,templates,atomic-notes}.md` become placeholder-bearing once status values are vocabulary. **No task does that.** It is deliberate — converting four enum declarations to placeholders changes what `check-placeholder-count.sh` measures across three files, and doing it inside a plan whose risk is already "what a new note looks like" mixes two unrelated failure modes. It becomes ledger entry 12 in Task 8.

**Type consistency.** `{vocabulary.status_preliminary}` and `{vocabulary.status_active}` are spelled identically in Tasks 1, 2, 3 and 7. `frontmatter_field <file> <field>` matches the library's existing signature. The `awk` frontmatter-rewrite idiom is identical in Tasks 2 and 3.

**Placeholder scan.** No TBDs. Tasks 5, 6 and 7 describe deliverables against explicit behaviour tables rather than final code, because each is a new file or section whose exact text depends on a re-derivation the step performs first — each carries the required behaviours, the guard to copy, and the verification table.

---

## Deferrals

Each names its entry in **`docs/superpowers/deferrals.md`**.

| what this plan defers | ledger entry |
|---|---|
| the 681 statusless field-vault notes — the stamp is forward-only | **5** |
| the `~150` vs `200` description-length disagreement | **6** |
| off-enum vault statuses: `closed`/`investigating` vs the `superseded` dialect gap | **7** |
| `open`'s undefined semantics | **8** |
| converting the `generators/` enum declarations to placeholders | **12** — added by Task 8 |
