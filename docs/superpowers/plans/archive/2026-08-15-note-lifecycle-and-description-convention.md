# Note Lifecycle and Description Convention Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the note lifecycle's entry state and the description convention arrive at write time, and clear this vault's accumulated backlog once.

**Architecture:** Three surfaces. Templates prevent permanently — `/reduce` stamps `status` and strips the trailing period at creation, `/verify` promotes on a mechanically checkable gate. Five flat `status_*` vocabulary keys make lifecycle states renameable. A one-time throwaway script clears the existing backlog in a single commit, then is deleted with its suite.

**Tech Stack:** Markdown skill templates, YAML frontmatter, bash fences, `awk`, `reference/lib/frontmatter.sh`.

**Spec:** `docs/superpowers/specs/archive/2026-08-15-note-lifecycle-and-description-convention-design.md`

**Supersedes:** `docs/superpowers/plans/archive/2026-08-08-note-convention-and-lifecycle.md` — **do not execute that plan.** Its Task 5 would rewrite 1776 vault files without their quotes.

## Global Constraints

- **Canonical vocabulary only.** Write `preliminary`, never `draft`. `draft` is the field vault's dialect and appears 0 times in `skill-sources/` and `generators/`.
- **Placeholders, not paths or literals.** `{vocabulary.status_preliminary}`, never `preliminary`. `{vocabulary.notes}`, never `nodes/`.
- **Mutation edits the raw line. It never rebuilds a parsed value.** Reading through `frontmatter_field` strips quotes; a write built from that output loses them.
- **Selection stays in the read-only library.** `FRONTMATTER_VERSION` does not move. No write API is added to `reference/lib/frontmatter.sh`.
- **Both shells** for every suite run: `for s in bash zsh; do $s <suite>; done`.
- **BSD/macOS**, Darwin 22.6.0. No GNU-only flags. `grep` may be aliased — use `/usr/bin/grep` where exact semantics matter.
- **Fail loud.** Exit 0 with empty output is this repo's documented failure mode. Every new path asserts its preconditions.
- **New assertions must be born red.** Every mutation used to prove one must be asserted to have applied (`cmp` against a backup) before its result is read.
- **`docs/field-intel-2026-08-15.md` is untracked and must stay so.** Never `git add` it.

---

## File Structure

| file | responsibility | change |
|---|---|---|
| `skills/setup/SKILL.md` | declares the vocabulary schema | +5 `status_*` keys after `cmd_rethink` (`:1183`) |
| `generators/features/atomic-notes.md` | enum declaration | `:94` gains `superseded` |
| `generators/features/schema.md` | enum declaration ×2 | `:30`, `:142` gain `superseded` |
| `generators/features/templates.md` | enum declaration | `:30` gains `superseded` |
| `skill-sources/reduce/SKILL.md` | note creation | stamps `status`, strips period, `~150`→200 at `:473` and `:725` |
| `skill-sources/verify/SKILL.md` | promotion | new mechanical gate in Step 6 |
| `reference/migrate-note-lifecycle.sh` | **one-time** migration | created Task 5, deleted Task 7 |
| `reference/test/migrate-note-lifecycle.test.sh` | its suite | created Task 5, deleted Task 7 |

---

## Task 1: Declare the five `status_*` vocabulary keys

**Files:**
- Modify: `skills/setup/SKILL.md:1183-1185`

**Interfaces:**
- Consumes: nothing.
- Produces: `{vocabulary.status_preliminary}`, `{vocabulary.status_open}`, `{vocabulary.status_active}`, `{vocabulary.status_archived}`, `{vocabulary.status_superseded}` — resolvable by `check-vocabulary-schema.sh`. Tasks 3 and 4 use the first and third.

**Why first:** `check-vocabulary-schema.sh` exits 1 on a `{vocabulary.X}` used in `skill-sources/` with no declared key. Task 3 uses two of these. Declaring them first keeps every intermediate commit green.

- [ ] **Step 1: Confirm the insertion point has not drifted**

```bash
sed -n '1183,1185p' skills/setup/SKILL.md
```
Expected: `cmd_rethink:` line, a blank line, then `  # Level 7: Extraction categories (domain-specific, from conversation)`. If it differs, locate by text: `/usr/bin/grep -n 'Level 7' skills/setup/SKILL.md`.

- [ ] **Step 2: Confirm the gate is green before the change**

```bash
bash reference/check-vocabulary-schema.sh; echo "rc=$?"
```
Expected: `rc=0`.

- [ ] **Step 3: Insert the five keys**

Insert after the `cmd_rethink:` line and before the blank line preceding `# Level 7:`:

```yaml

  # Level 6.5: Lifecycle states (one key per enum value)
  status_preliminary: "[domain term]"  # e.g., "preliminary", "draft", "seed"
  status_open: "[domain term]"         # e.g., "open", "question", "unresolved"
  status_active: "[domain term]"       # e.g., "active", "verified", "live"
  status_archived: "[domain term]"     # e.g., "archived", "retired", "closed"
  status_superseded: "[domain term]"   # e.g., "superseded", "replaced", "obsolete"
```

All five, including the three no skill writes today: a vault must be able to rename its whole enum, not the half that happens to be written.

- [ ] **Step 4: Verify the keys are declared and the gate still passes**

```bash
/usr/bin/grep -c '^  status_' skills/setup/SKILL.md    # 5
bash reference/check-vocabulary-schema.sh; echo "rc=$?"  # 0
for s in bash zsh; do $s reference/test/vocabulary-schema.test.sh 2>&1 | tail -1; done  # 12/12
```

- [ ] **Step 5: Commit**

```bash
git add skills/setup/SKILL.md
git commit -m "vocabulary: declare five status_* lifecycle keys

One key per enum value, including the three no skill writes today. A vault
renaming its lifecycle vocabulary must be able to rename all of it; keys only
for the values /reduce and /verify write would let a vault rename half its enum
and leave the rest in the generator's dialect."
```

---

## Task 2: Add `superseded` to the canonical enum

**Files:**
- Modify: `generators/features/atomic-notes.md:94`
- Modify: `generators/features/schema.md:30`, `generators/features/schema.md:142`
- Modify: `generators/features/templates.md:30`

**Interfaces:**
- Consumes: nothing.
- Produces: canonical enum `preliminary | open | active | archived | superseded`, in all four declarations. `check-doc-claims.sh` compares these as a value set.

- [ ] **Step 1: Confirm all four sites and their current value**

```bash
/usr/bin/grep -rn 'preliminary' generators/
```
Expected: exactly four lines, each listing `preliminary, open, active, archived` in one of three spellings (pipe-separated, bracketed list, backticked table cells).

- [ ] **Step 2: Add `superseded` to each, preserving that site's spelling**

`generators/features/atomic-notes.md:94`:
```
status: preliminary | open | active | archived | superseded
```

`generators/features/schema.md:30`:
```
| `status` | No | enum | `preliminary`, `open`, `active`, `archived`, `superseded` |
```

`generators/features/schema.md:142`:
```
    status: [preliminary, open, active, archived, superseded]
```

`generators/features/templates.md:30`:
```
    status: [preliminary, open, active, archived, superseded]
```

Each site keeps its own spelling. `check-doc-claims.sh` compares the value SET, never the text, because the same enum is legitimately written three ways.

- [ ] **Step 3: Verify all four agree**

```bash
/usr/bin/grep -rho 'preliminary[^]|]*superseded' generators/ | tr -d '`|,' | tr -s ' ' | sed 's/^ *//;s/ *$//' | sort -u
```
Expected: exactly **1** line. More than one means a site was spelled differently in substance, not just in punctuation.

- [ ] **Step 4: Run the gate that compares them**

```bash
bash reference/check-doc-claims.sh > /tmp/t2.txt 2>&1; echo "rc=$?"; /usr/bin/grep -i 'enum' /tmp/t2.txt
```
Expected: `rc=0`, and the note-status enum row reports `ok`. **This takes ~100 seconds — run it in the foreground.** An implementer on the prior branch backgrounded it on a monitor that never returned and stalled with work uncommitted.

- [ ] **Step 5: Commit**

```bash
git add generators/features/atomic-notes.md generators/features/schema.md generators/features/templates.md
git commit -m "enum: adopt superseded into the canonical note status enum

superseded is a real lifecycle state the field vault's own template declares and
canonical lacked -- the same dialect gap as draft, and the divergences 7-9
precedent is that a value a vault's template declares is a gap, not an error.

All four declaration sites moved, each keeping its own spelling.
check-doc-claims compares the value set, not the text."
```

---

## Task 3: `/reduce` stamps the status and strips the trailing period

**Files:**
- Modify: `skill-sources/reduce/SKILL.md` — the note frontmatter template at `:472-476`, and the two `~150` sites at `:473` and `:725`

**Interfaces:**
- Consumes: `{vocabulary.status_preliminary}` from Task 1.
- Produces: every note `/reduce` creates carries a `status` line. Task 4's promotion has something to promote from.

- [ ] **Step 1: Confirm the template and both `~150` sites**

```bash
sed -n '471,477p' skill-sources/reduce/SKILL.md
sed -n '725p'     skill-sources/reduce/SKILL.md
```

- [ ] **Step 2: Add the status line to the note template**

In the fenced `markdown` block at `:471-477`, after the `created:` line:

```markdown
---
description: [max 200 chars elaborating the claim, adds info beyond title, NO trailing period]
type: [claim | methodology | problem | learning | tension]
created: YYYY-MM-DD
status: {vocabulary.status_preliminary}
[domain-specific fields from derivation-manifest]
---
```

Two changes in one block: the `status` line is added, and `~150 chars` becomes `max 200 chars` with the no-trailing-period constraint stated where the value is written rather than only in the schema.

- [ ] **Step 3: Fix the second `~150` site**

`skill-sources/reduce/SKILL.md:725` currently reads `One field. ~150 characters. Must add NEW information beyond the title — scope, me…`. Change `~150 characters` to `Max 200 characters, no trailing period.`

**Both sites, not one.** Deferrals entry 6 named two `~150` sites repo-wide and missed this one; it is the third. The remaining site, `generators/features/schema.md:18`, belongs to Task 2's tree and is left alone here — record it in your report.

- [ ] **Step 4: Verify the placeholder resolves and no literal leaked**

```bash
/usr/bin/grep -c '{vocabulary.status_preliminary}' skill-sources/reduce/SKILL.md   # 1
/usr/bin/grep -c '^status: preliminary' skill-sources/reduce/SKILL.md              # 0 — no literal
/usr/bin/grep -c '~150' skill-sources/reduce/SKILL.md                              # 0
bash reference/check-vocabulary-schema.sh; echo "rc=$?"                            # 0
bash reference/check-placeholder-count.sh main; echo "rc=$?"                       # 0
```

- [ ] **Step 5: Verify the changed fences still run standalone**

```bash
for s in bash zsh; do $s reference/test/fence-isolation.test.sh 2>&1 | /usr/bin/grep -m1 -oE 'files=[0-9]* fences=[0-9]* run=[0-9]* skipped=[0-9]* known-open=[0-9]*'; done
```
Read all five numbers, not just PASS. A fence that stops parsing is **skipped, not failed**, and the gate still prints PASS.

- [ ] **Step 6: Commit**

```bash
git add skill-sources/reduce/SKILL.md
git commit -m "reduce: stamp the lifecycle entry state and the description constraint at creation

Notes were born statusless -- no skill anywhere wrote a note's status, and
templates.md:27 declares it optional. /reduce now stamps
{vocabulary.status_preliminary}, a placeholder rather than a literal, so a vault
that renames its enum keeps a /verify that can promote what /reduce writes.

Both ~150 sites in this file move to 'max 200 chars, no trailing period'.
200 is what the _schema constraint declares at three sites; ~150 was prose."
```

---

## Task 4: `/verify` promotes on the mechanically checkable gate

**Files:**
- Modify: `skill-sources/verify/SKILL.md` — Step 6, after the results block at `:317`

**Interfaces:**
- Consumes: `{vocabulary.status_preliminary}` and `{vocabulary.status_active}` from Task 1; notes stamped by Task 3.
- Produces: nothing later tasks consume.

- [ ] **Step 1: Confirm the dead gate the prior plan proposed does not exist**

```bash
/usr/bin/grep -c 'VERIFY_FAIL_COUNT' skill-sources/verify/SKILL.md
```
Expected: **0**. The superseded plan gated promotion on this variable. Fences are separate shell invocations, so even a computed value cannot cross to a later fence — the promotion silently never fired.

- [ ] **Step 2: Add the promotion block to Step 6**

```markdown
**Promotion (mechanical gate only).**

Promote a {vocabulary.note} from `{vocabulary.status_preliminary}` to
`{vocabulary.status_active}` when **all three** of these pass — and only these:

- required fields present (VALIDATE: Required fields = PASS)
- topics format valid (VALIDATE: Topics format = PASS)
- every wiki link resolves (REVIEW: Link resolution = PASS)

RECITE's prediction score and description quality are **reported and do not
gate**. They are judgments this skill makes, not conditions it can compute, and
a gate that cannot be computed is a gate that cannot be checked.

If any of the three fails, leave the status unchanged and say so in the report.
Never promote silently: state the transition and which three checks carried it.
```

- [ ] **Step 3: Verify both placeholders resolve and no literal leaked**

```bash
/usr/bin/grep -c '{vocabulary.status_preliminary}' skill-sources/verify/SKILL.md   # >= 1
/usr/bin/grep -c '{vocabulary.status_active}'      skill-sources/verify/SKILL.md   # >= 1
/usr/bin/grep -cE '`(preliminary|active)`'         skill-sources/verify/SKILL.md   # 0
bash reference/check-vocabulary-schema.sh; echo "rc=$?"                            # 0
```

- [ ] **Step 4: Verify the fences still run standalone**

```bash
for s in bash zsh; do $s reference/test/fence-isolation.test.sh 2>&1 | /usr/bin/grep -m1 -oE 'files=[0-9]* fences=[0-9]* run=[0-9]* skipped=[0-9]* known-open=[0-9]*'; done
```

- [ ] **Step 5: Commit**

```bash
git add skill-sources/verify/SKILL.md
git commit -m "verify: promote preliminary -> active on the mechanical gate only

The lifecycle had a transition specified and nothing that fired it. The
superseded plan gated on \$VERIFY_FAIL_COUNT, a variable that exists nowhere in
this file; fences are separate shells, so it expanded empty and promotion never
happened.

The gate is now the three checks this skill can compute: required fields,
topics format, link resolution. RECITE's score and description quality are
reported and do not gate -- they are judgments, and a gate that cannot be
computed cannot be checked.

NO TEST COVERS THIS. Nothing in this repo executes template prose; the fence
gate proves the fences parse, not that an agent complies."
```

---

## Task 5: The one-time migration script and its suite

**Files:**
- Create: `reference/migrate-note-lifecycle.sh`
- Create: `reference/test/migrate-note-lifecycle.test.sh`

**Interfaces:**
- Consumes: `reference/lib/frontmatter.sh` for **selection only**.
- Produces: `migrate-note-lifecycle.sh <vault-dir> [--apply]`. Dry-run prints counts and exits 0; `--apply` writes. Task 6 runs it.

**This task carries the risk in the whole plan.** The script edits ~2507 files in a live 2874-note vault. Its suite is why the single run is safe.

- [ ] **Step 1: Write the failing suite first**

Create `reference/test/migrate-note-lifecycle.test.sh`:

```bash
#!/bin/bash
# migrate-note-lifecycle.test.sh — the one-time migration's only coverage.
#
# WHY THIS EXISTS: the superseded plan's normalizer read a description through
# frontmatter_field, which STRIPS BALANCED QUOTES, then wrote the value back
# unquoted. Against the field vault that rewrites 1776 files without their
# quotes and produces invalid YAML on the 473 carrying a colon inside the
# value, while its progress counter reads as plausible forward motion.
#
# The fixture named "colon" below is that exact case.
set -u
HERE=$(cd "$(dirname "$0")" && pwd -P)
SCRIPT="$HERE/../migrate-note-lifecycle.sh"
pass=0; fail=0
assert() { # assert <actual> <expected> <label>
  if [ "$1" = "$2" ]; then pass=$((pass+1))
  else fail=$((fail+1)); printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' "$3" "$2" "$1"; fi
}
mkvault() { # mkvault -> prints a fresh vault dir
  d=$(mktemp -d); mkdir -p "$d/nodes"; printf '%s' "$d"
}
note() { # note <vault> <name> <frontmatter-body>
  printf -- '---\n%s\n---\n\nBody.\n' "$3" > "$1/nodes/$2.md"
}
desc() { # desc <vault> <name> -> the raw description line, verbatim
  awk 'NR==1&&$0=="---"{f=1;next} f&&/^---$/{exit} f&&/^description:/{print;exit}' "$1/nodes/$2.md"
}
statusline() { # statusline <vault> <name>
  awk 'NR==1&&$0=="---"{f=1;next} f&&/^---$/{exit} f&&/^status:/{print;exit}' "$1/nodes/$2.md"
}
```

- [ ] **Step 2: Add the fixtures, each born red**

Append to the suite:

```bash
V=$(mkvault)
note "$V" quoted   'description: "A quoted one."
type: insight'
note "$V" colon    'description: "Ratio: two to one."
type: insight'
note "$V" bare     'description: A bare one.
type: insight'
note "$V" ellipsis 'description: "Trailing dots..."
type: insight'
note "$V" empty    'description: "."
type: insight'
note "$V" nostatus 'description: "Already clean"
type: insight'
note "$V" hasstatus 'description: "Already clean"
status: active
type: insight'

bash "$SCRIPT" "$V" --apply >/dev/null 2>&1

assert "$(desc "$V" quoted)"   'description: "A quoted one"'      'quoted: period stripped, quotes kept'
assert "$(desc "$V" colon)"    'description: "Ratio: two to one"' 'colon: quotes kept — the 473-note case'
assert "$(desc "$V" bare)"     'description: A bare one'          'bare: stays bare'
assert "$(desc "$V" ellipsis)" 'description: "Trailing dots..."'  'ellipsis: untouched'
assert "$(desc "$V" empty)"    'description: "."'                 'would-be-empty: refused, unchanged'
assert "$(statusline "$V" nostatus)"  'status: active'            'statusless: backfilled to active'
assert "$(statusline "$V" hasstatus)" 'status: active'            'already-stamped: untouched'

# These two expect the same value for OPPOSITE reasons — one was written, one was
# left alone. Add a discriminating third so a script that ignores existing status
# cannot pass both:
note "$V" wasopen 'description: "Already clean"
status: open
type: insight'
bash "$SCRIPT" "$V" --apply >/dev/null 2>&1
assert "$(statusline "$V" wasopen)"   'status: open'              'existing non-active status: untouched'
```

Note the two assertions that are each other's control: `colon` proves quotes survive, `bare` proves a bare value is not gratuitously quoted. Either alone passes under a wrong implementation.

- [ ] **Step 3: Add the idempotency assertion — the strongest one**

```bash
V2=$(mkvault)
note "$V2" a 'description: "One."
type: insight'
note "$V2" b 'description: Two.
type: insight'
bash "$SCRIPT" "$V2" --apply >/dev/null 2>&1
snap=$(mktemp -d); cp -R "$V2/nodes" "$snap/"
bash "$SCRIPT" "$V2" --apply >/dev/null 2>&1
assert "$(diff -r "$snap/nodes" "$V2/nodes" >/dev/null 2>&1 && echo same || echo differs)" 'same' \
  'idempotent: a second --apply changes nothing'

printf 'migrate-note-lifecycle: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

- [ ] **Step 4: Run it and confirm it fails**

```bash
chmod +x reference/test/migrate-note-lifecycle.test.sh
for s in bash zsh; do $s reference/test/migrate-note-lifecycle.test.sh 2>&1 | tail -1; done
```
Expected: FAIL — the script does not exist yet. **An assertion that passes before the implementation proves nothing.**

- [ ] **Step 5: Write the script**

Create `reference/migrate-note-lifecycle.sh`:

```bash
#!/bin/bash
# migrate-note-lifecycle.sh — ONE-TIME migration. Delete after it runs.
#
# Edits the RAW LINE. It never rebuilds a parsed value: reading through
# frontmatter_field strips balanced quotes, and a write built from that output
# loses them. See the design doc for the 473 files that would break.
set -u
VAULT="${1:?usage: migrate-note-lifecycle.sh <vault-dir> [--apply]}"
APPLY="${2:-}"
[ -d "$VAULT/nodes" ] || { echo "error: no nodes/ under $VAULT" >&2; exit 1; }
command -v awk >/dev/null || { echo "error: awk required" >&2; exit 1; }

stripped=0; stamped=0; mapped=0; refused=0

transform() { # transform <file>
  awk -v apply="$APPLY" '
    BEGIN { infm=0; seen_status=0; changed=0 }
    NR==1 && $0=="---" { infm=1; print; next }
    infm && $0=="---" {
      # BACKFILL IS `active`, NOT `preliminary`. The 698 statusless notes predate
      # the stamp; `active` asserts they exist and are reachable, nothing about
      # quality. `preliminary` would assert the opposite claim, equally unearned.
      # The migration commit is what distinguishes these from promoted notes.
      if (!seen_status) { print "status: active"; changed=1 }
      infm=0; print; next
    }
    infm && /^status:/ {
      seen_status=1
      v=$0; sub(/^status:[[:space:]]*/,"",v); gsub(/^["'"'"']|["'"'"']$/,"",v)
      if (v=="closed")            { print "status: archived"; changed=1; next }
      if (v=="verified"||v=="valid"||v=="evergreen") { print "status: active"; changed=1; next }
      if (v=="investigating")     { print "status: open"; changed=1; next }
      print; next
    }
    infm && /^description:/ {
      line=$0
      # split into prefix, opening delim, interior, closing delim -- never parse
      if (match(line, /^description:[[:space:]]*"/)) { q="\"" }
      else if (match(line, /^description:[[:space:]]*'"'"'/)) { q="'"'"'" }
      else { q="" }
      pre="description: "
      body=line; sub(/^description:[[:space:]]*/,"",body)
      if (q!="") { inner=substr(body,2,length(body)-2) } else { inner=body }
      if (inner ~ /\.$/ && inner !~ /\.\.$/ && length(inner)>1) {
        inner=substr(inner,1,length(inner)-1); changed=1
      }
      print pre q inner q; next
    }
    { print }
    END { exit changed?0:1 }
  ' "$1"
}

for f in "$VAULT"/nodes/*.md; do
  [ -r "$f" ] || { echo "refused (unreadable): $f" >&2; refused=$((refused+1)); continue; }
  head -1 "$f" | /usr/bin/grep -q '^---$' || { refused=$((refused+1)); continue; }
  tmp=$(mktemp) || exit 1
  if transform "$f" > "$tmp"; then
    head -1 "$tmp" | /usr/bin/grep -q '^---$' || { rm -f "$tmp"; echo "refused (bad output): $f" >&2; refused=$((refused+1)); continue; }
    if [ "$APPLY" = "--apply" ]; then
      mv "$tmp" "$f" || { rm -f "$tmp"; echo "error: could not write $f" >&2; exit 1; }
    else rm -f "$tmp"; fi
    stripped=$((stripped+1))
  else rm -f "$tmp"; fi
done

printf 'files changed: %s   refused: %s   (%s)\n' "$stripped" "$refused" \
  "$([ "$APPLY" = "--apply" ] && echo applied || echo 'DRY RUN — pass --apply to write')"
```

- [ ] **Step 6: Run the suite and confirm it passes**

```bash
chmod +x reference/migrate-note-lifecycle.sh
for s in bash zsh; do $s reference/test/migrate-note-lifecycle.test.sh 2>&1 | tail -1; done
```
Expected: `9 passed, 0 failed` in both shells.

- [ ] **Step 7: Mutation-prove the quote-preservation assertion**

```bash
S=reference/migrate-note-lifecycle.sh; B=$(mktemp); cp $S $B
perl -pi -e 's/print pre q inner q/print pre inner/' $S
cmp -s $B $S && { echo 'MUTATION DID NOT APPLY — result meaningless'; exit 1; }
for s in bash zsh; do $s reference/test/migrate-note-lifecycle.test.sh 2>&1 | tail -1; done
cp $B $S
```
Expected while mutated: the `quoted` and `colon` assertions fail and `bare` still passes. That split is the proof the fixtures discriminate rather than agreeing by luck.

- [ ] **Step 8: Commit**

```bash
git add reference/migrate-note-lifecycle.sh reference/test/migrate-note-lifecycle.test.sh
git commit -m "Add the one-time note-lifecycle migration and its suite

Edits the raw line and never rebuilds a parsed value. The superseded plan's
normalizer read through frontmatter_field, which strips balanced quotes, and
wrote back unquoted -- 1776 files unquoted and invalid YAML on the 473 with a
colon inside the value.

The colon fixture is that exact case. Its control is the bare fixture: either
assertion alone passes under a wrong implementation, and only the pair
discriminates.

Idempotency is the strongest assertion here -- a second --apply must change
nothing, which is what makes a partial run recoverable.

BOTH THIS SCRIPT AND ITS SUITE ARE DELETED IN TASK 7."
```

---

## Task 6: Run the migration against the vault

**Files:**
- Modify: `~/second-brain/nodes/*.md` — **the live field vault**, one commit

**Interfaces:**
- Consumes: `reference/migrate-note-lifecycle.sh` from Task 5.
- Produces: the migration commit, which is the marker distinguishing backfilled `active` from promoted `active`.

- [ ] **Step 1: Re-derive the targets — the vault is live and these drift**

```bash
cd ~/second-brain
/usr/bin/grep -rlE '^description:.*[^.]\.$' nodes/ | wc -l   # ~1784
```
Record what you measure. The spec's figures were taken 2026-08-15.

- [ ] **Step 2: Dry-run against an rsync copy**

```bash
rsync -a ~/second-brain/ /tmp/vault-copy/
bash reference/migrate-note-lifecycle.sh /tmp/vault-copy | tail -2
```
Expected: a count and `DRY RUN`. No files written.

- [ ] **Step 3: Apply to the copy and review the diff**

```bash
bash reference/migrate-note-lifecycle.sh /tmp/vault-copy --apply | tail -2
cd /tmp/vault-copy && git diff --stat | tail -3
git diff | /usr/bin/grep -c '^+description: "'    # quoted values still quoted
git diff | /usr/bin/grep -cE '^\+description: [^"]*:'  # 0 — no unquoted colon values
```
**The last check is the one that matters.** A non-zero result means quotes were lost on a colon-bearing value and the migration must not proceed.

- [ ] **Step 4: Apply to the live vault**

```bash
bash reference/migrate-note-lifecycle.sh ~/second-brain --apply | tail -2
```

- [ ] **Step 5: Verify the result and let the auto-commit hook produce one commit**

```bash
cd ~/second-brain
/usr/bin/grep -rlE '^description:.*[^.]\.$' nodes/ | wc -l    # 0
/usr/bin/grep -rL '^status:' nodes/*.md 2>/dev/null | wc -l   # 0
git log --oneline -1
```

- [ ] **Step 6: Record the migration commit SHA in the spec**

The commit is the marker the design relies on to tell a backfilled `active` from a promoted one. Add its SHA to the spec's lifecycle section, commit that in the plugin repo.

---

## Task 7: Delete the migration script and its suite

**Files:**
- Delete: `reference/migrate-note-lifecycle.sh`
- Delete: `reference/test/migrate-note-lifecycle.test.sh`

**Interfaces:**
- Consumes: a completed Task 6.
- Produces: nothing.

- [ ] **Step 1: Confirm the migration is done and committed in the vault**

```bash
cd ~/second-brain && git status --porcelain | wc -l   # 0
git log --oneline -1
```
Do not proceed if the vault has uncommitted changes.

- [ ] **Step 2: Delete both files**

```bash
cd /Volumes/Containers/arscontexta
git rm reference/migrate-note-lifecycle.sh reference/test/migrate-note-lifecycle.test.sh
```

- [ ] **Step 3: Confirm the gate inventory returns to its prior size**

```bash
ls reference/check-*.sh reference/test/*.test.sh reference/validate-kernel.sh | wc -l
```
Expected: the same count as before Task 5. `CLAUDE.md` declares this number and `check-doc-claims.sh` gates it — if the count moved, the declaration must move with it.

- [ ] **Step 4: Full sweep, both shells**

```bash
for s in bash zsh; do for t in link-extraction guard-failure fence-isolation bump-version kernel-note-dirs threshold-namespace placeholder-count hook-config vocabulary-schema queue-edit; do echo "$s $t :: $($s reference/test/$t.test.sh 2>&1 | tail -1)"; done; done
bash reference/check-doc-claims.sh; echo "rc=$?"
```
Expected: no failures, `rc=0`.

- [ ] **Step 5: Commit**

```bash
git commit -m "Delete the one-time migration script and its suite

The backlog it cleared was a migration artifact of one vault, not a recurring
condition: /reduce now stamps and strips at creation, so no future vault
accumulates one. A migration tool left in reference/ becomes a permanent
artifact with a version, a gate and a maintainer, for a job that ran once."
```

---

## Deferrals

- `generators/features/schema.md:18` still reads `~150 chars` — it is the fourth description-length site and belongs to the generators tree rather than to `/reduce`. Lands in `docs/superpowers/deferrals.md` if not closed in Task 2.
- Nothing else. Every other item in the spec is implemented by a task above.
