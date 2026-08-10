# Spec — post-merge hardening (adversarial review of `a98352c`)

## What this is

Ten findings from an adversarial review of `main` at `a98352c` — the merge of PR #7.
Six Important, four Minor, zero Critical. This spec groups them by root cause, rules on
each, and states the decisions it cannot make alone — **two of them**, since the salvaged
deferrals below added one.

**Plus six salvaged deferrals, added 2026-08-09 by direct request, under their own heading
and numbered `D<n>` after their `deferrals.md` entry** — never `F<n>`, which is reserved for
this review's findings. They arrive from commit `f741a6c`, which recovered 28 parked findings
out of the eight gitignored SDD ledgers before those were deleted alongside the plan archive;
seven were still live, and six of them fold here. A seventh (D15) became Decision 2 rather
than a fix. **Thirteen entries did not fold, and each is listed by number with its blocking
reason** under *Deliberately not in scope*, so the ceiling is auditable instead of asserted.
The split is `20 = 6 folded + 1 decision + 13 remaining` — stated as a sum, per the idiom
divergence 12 uses, because a bare total cannot fail loudly and this one already did: the
first draft of this sentence said "fourteen", which is the count you get by forgetting that
D15 left the not-folded set to become a decision.

**Plus two out-of-band items, added 2026-08-09 by direct request and kept under their own
heading** so neither can be misread as an eleventh finding: making four plugin skills run
inline rather than forked, and an audit of `README.md`'s claims. The review's subject was
`a98352c` as merged; these are changes *to* it, and conflating the two would corrupt the
provenance the next section is at pains to establish.

**Provenance matters here.** PR #7 merged **46 commits, not the 35** the
`2026-08-08-link-edge-map.md` plan produced. Eleven commits of earlier backport work were
already on the branch and rode along undescribed by the PR body — including
`reference/lib/queue-edit.sh`, a third shared library with seven consumers that never
passed through that plan's review process. Findings 1 and 6 are both in that undescribed
half. Re-derive the split:

```bash
git rev-list --count 542fed8..d2c5054   # 11 — pre-existing backport work
git rev-list --count d2c5054..77928ee   # 35 — the link-edge-map plan
git rev-list --count 542fed8..77928ee   # 46 — what actually merged
```

Line numbers below are as of `a98352c` and **drift**. Every one has a command beside it.

## Background and evidence

The review was run with a falsification brief, under both shells, with `cmp`-guarded
mutations and verified restores. Its negative results are as load-bearing as its
findings: all published `CLAUDE.md` numerals re-derive correctly, no vocabulary leaked
into `skill-sources/`, and the suite does catch the self-edge, `source_path` and
`LC_ALL` pin mutations. The tree was clean at the end (`git status --porcelain`).

Three findings were independently re-verified before this spec was written:

| finding | independent check | result |
|---|---|---|
| 5 — source-side fold untested | mutated both edge-map builders, `cmp`-guarded | **91/0 green under the mutant** |
| 3 — locale mismatch | read the four cited export lines | **confirmed bare `sort -u`** |
| 6 — `/health` omits `queue-edit.sh` | `grep -n 'check_lib '` | **2 lines, neither is queue-edit** |

### The grouping that matters

These are not ten independent bugs. They are five root causes:

**A — `link-extraction.sh` correctness (F3, F7, F9).** Three defects in the library this
merge promoted to version 3. All silent-wrong-answer class.

**B — `queue-edit.sh` shipped with no suite (F1, F6).** A library with seven consumers,
an unguarded commit step, and nothing that tests it or vouches for it. Measured:

```bash
ls reference/test/ | grep -i queue                 # nothing
grep -rln 'queue-edit' reference/ .github/         # the library itself + fence gate only
grep -n 'QUEUE_EDIT_VERSION' reference/lib/queue-edit.sh   # :23 — a version nothing reads
```

This is the same shape as the `bump-version.sh` "zero coverage" gap `CLAUDE.md`'s closed
record documents fixing — reproduced one library over, in the same merge.

**C — suite blind spots (F5, F8).** The 91-assertion suite cannot detect removal of the
source-side case fold, and reports six false FAILs from any non-root working directory.

**D — orphan semantics diverge across five surfaces (F4).** Three independent axes of
disagreement. See the open decision below.

**E — silent suppression in the hook template (F10).** The new orphan block gates on an
unsubstituted placeholder with no else arm.

### F4 is real but does not currently manifest — measured, not assumed

Fable rated the five-surface divergence Important on the strength of "up to five
different orphan counts." Measured against the field vault, **all three computable
semantics return 0**:

| semantics | surface | orphans on `~/second-brain` |
|---|---|---|
| recursive candidates, notes-dir rescue, self **excluded** | `/architect` | **0** |
| recursive candidates, notes-dir rescue, self **rescues** | `/graph`, `/stats` | **0** |
| **flat** candidates, whole-vault rescue, self excluded | `/health` | **0** (3234 targets) |

The two axes that could diverge cannot fire on this vault: `nodes/` has **zero
subdirectories** (2686 files flat and recursive alike), so flat-vs-recursive is a
distinction without a difference there, and no note is rescued by its own self-link
alone.

```bash
find ~/second-brain/nodes -mindepth 1 -type d | wc -l          # 0
find ~/second-brain/nodes -maxdepth 1 -name '*.md' | wc -l     # 2686
find ~/second-brain/nodes -name '*.md' | wc -l                 # 2686 — same
```

**This lowers F4's urgency and does not remove the defect.** A vault with subdirectories,
or one self-linking note, diverges immediately and silently. But it means F4 is a
*hazard* to be ruled on deliberately, not a wrong number shipping today — and that
ordering matters, because the fix changes user-visible counts in five commands.

### F2 does not reopen deferral 13 — checked against its own stated trigger

Finding 2 is `deferrals.md` entry 13, rediscovered independently by a reviewer who was
deliberately not told it existed. That independence is evidence the trade is visible to a
fresh reader, which is what a recorded deferral is for.

Entry 13 reopens if *"a second failure mode surfaces that can empty `$tgts` or `$idx`
without tripping an earlier guard."* F10 is a different route to the same outcome: the
`[ -d "$NOTES_DIR" ]` guard at `:163` **trips** and the block is skipped entirely. That
is silent suppression, but not the mode entry 13 named. **Entry 13 stays deferred.**

Entry 13 cites that guard as `:162` and its companion as `:165`; both are off by one
(`:162` is `ORPHAN_COUNT=0`, `:163` is the `[ -d ]`). The amendment fixes the citations —
a deferral whose line references have drifted is a record that cannot be checked, which is
the failure mode the deferrals file exists to prevent.

What F10 does change is entry 13's premise. On any vault whose notes directory is not
literally `notes/` — the field vault's `nodes/` being the canonical case — the block
entry 13 defends **never runs at all**. Fixing F10 is therefore worth more than reopening
13, and entry 13 should be amended to say so rather than left reading as though the code
it describes is live everywhere.

## Design

### 1. `link-extraction.sh` correctness (F3, F7, F9)

**1a. Pin `LC_ALL=C` on the four exported sorts.** `existing_note_index{,_recursive}` and
`extract_link_targets{,_recursive}` end in bare `sort -u`, so every consumer receives an
ambient-locale-collated stream. `orphan_notes` pins both of its own `comm` inputs — the
exports it hands outward re-open the hole one layer up.

```bash
sed -n '195p;207p;272p;283p' reference/lib/link-extraction.sh   # four bare `| _fold_lower | sort -u`
```

Consumers that join an export against a `LC_ALL=C`-sorted stream are then correct by
construction. `skill-sources/graph/SKILL.md:172` and `skill-sources/stats/SKILL.md:280`
additionally get `LC_ALL=C` on the `comm` itself.

**This cannot be falsified on macOS and that must be stated in the code, not discovered.**
BSD `sort` ignores collation, so a local test passes either way; CI is glibc, where it
bites. Verification is therefore **structural** — assert the pins exist — in the same
idiom section 18b already uses, and the comment claiming "both operands reach comm
already folded and sorted, which is what makes it valid" must be corrected: they were
sorted, but not under the same collation, which is exactly the distinction that failed.

**1b. Stop collapsing internal whitespace in `backlink_counts`.** The rebuild runs under
default FS and reassembles the target from whitespace-split fields:

```bash
sed -n '378p;395p' reference/lib/link-extraction.sh
#     | LC_ALL=C awk '{ c=$1; $1=""; sub(/^ /,""); printf "%s\t%s\n", $0, c }'
```

A note whose filename contains two consecutive spaces gets a corrupted key, so
`skills/health` Categories 7 and 8 — which look up `awk -v n="$basename" '$1==n'` against
this table — find no row, default `incoming` to 0, and falsely report the note stale or
under-linked. Rebuild without re-splitting.

**1c. Clear the error-flag file before first use.** `errf="/tmp/link-extraction-err-$$"`
is a fixed path keyed on a recyclable PID, never cleared. `bump-version.sh` fixed this
exact class — a same-PID leftover must be deleted before first use, not read.

```bash
grep -c 'link-extraction-err-\$\$' reference/lib/link-extraction.sh   # 6 sites
```

The concurrency half (two library calls sharing one flag in one shell) is **latent** — no
current call site does it. Clearing before use is the whole fix; making the path unique
per call is not required and should not be done speculatively.

### 2. `queue-edit.sh`: guard the commit, and give it a suite (F1, F6)

**2a. Guard the `mv`.** `queue_edit`'s contract is *"Fails loud … return 1"*; its commit
step is unguarded, so a failed rename returns **rc 0** with the queue unchanged and the
staged temp left beside it.

```bash
sed -n '67p' reference/lib/queue-edit.sh    # mv "$tmp" "$file"
```

All seven call sites (`next:97,128,153`, `reduce:1130`, `reflect:825`, `reweave:727`,
`verify:532`) branch on that exit status, so a caller marking a task `done` proceeds
believing the write landed and the task is re-processed next pass — a lost update at rc 0,
the exact class the file's own header says the lock exists to prevent.

Adopt the `bump-version.sh` remedy verbatim, because it is already the house idiom and
already reviewed: guard the rename, **discard the temp**, name the path that could not
move. Leaving the temp is not neutral — it is an undeclared second copy of the queue.

**2b. Surface jq's diagnostic.** `:61` runs jq with `2>/dev/null` and replaces the real
error with a generic message, so a rejected filter reports nothing actionable.

**2c. Build the suite.** This is the substantive half of the task, not a coda. A library
with seven consumers and no test is how the unguarded `mv` shipped. Mirror
`bump-version.test.sh`'s structure, including its lesson: **every assertion must be
mutation-proved, because a total that rises while the new rows cannot fail is a failure
this repo has already shipped.** Wire it into CI in both shells.

The `mv`-failure path needs `chflags uchg` (macOS) / `chattr +i` (Linux root) and is not
portable to CI — the same limit `bump-version`'s record states. Cover the *mechanism*
(temp discarded, rc 1, path named) with a stub, and state plainly that the organic
trigger is hand-run only. Do not round that up.

**2d. `/health` Category 9 must vouch for it.** The category checks two libraries; the
merge wired a third into `skills/setup:434`, `skills/upgrade:717` and seven fences, and
skipped the one surface whose stated purpose is to *"report that condition directly
instead of leaving the user to discover it the next time they run a command."*

```bash
grep -n 'check_lib ' skills/health/SKILL.md    # 2 lines; queue-edit absent
```

### 3. Suite blind spots (F5, F8)

**3a. Add a capitalized source fixture.** Every source filename in `EDGE_DIR` is already
lowercase, so `src=$(basename "$f" .md | _fold_lower)` at `:299,:337` — the documented
"columns 1-2 folded" contract — is asserted by nothing. Consumers rely on it in comments;
re-derive rather than trusting a count, since the phrase has variants:

```bash
grep -rn 'columns 1-2 folded\|columns 1-2 are folded' skill-sources/ skills/ platforms/ | wc -l   # 2 exact
grep -rc 'folded' skill-sources/graph/SKILL.md skill-sources/stats/SKILL.md skills/health/SKILL.md
```
Independently confirmed: removing it from both builders leaves the suite **91/0 green**,
while a note `Myself.md` containing `[[myself]]` is rescued from orphanhood by its own
self-link and self-links start counting as incoming.

The fixture must be **discriminating**: a capitalized filename whose only link is to its
own lowercase form. The new assertion must be mutation-proved to go red under exactly
that deletion, with the mutation asserted to have applied.

**3b. Make section 18b location-independent.** Its six assertions read the library via a
CWD-relative path with hardcoded line numbers while every other assertion uses
`$HERE`-derived `$LIB`. Run from `reference/test/`, the suite reports **six false FAILs**.

```bash
cd reference/test && bash link-extraction.test.sh | tail -1   # passed=85 failed=6
```

Use `$LIB`, and anchor on **content** rather than line number. The hardcoded `414` also
rots on any edit above it — it fails loud, which is why this is Minor rather than
Important, but a suite that lies about the library is the wrong kind of loud.

### 4. The hook template's silent skip (F10)

`platforms/claude-code/hooks/session-orient.sh.template:161-163` gates the whole orphan
block on `NOTES_DIR="{{NOTES_DIR:-notes}}"` + `if [ -d "$NOTES_DIR" ]`, with **no else
arm**. On a `nodes/` vault the directory test is false, the block is skipped, and nothing
is printed — the silent-suppression outcome the block's own comment forbids for every
other failure mode ("an omitted line is visible — here nothing marks the omission").
Because `{{NOTES_DIR}}` is never substituted, this fires on **every** vault whose notes
directory is not literally `notes/` — the field vault included. It is not a rare path.

**Read the nesting before touching this, because a flat `grep` gets it wrong.** A draft of
this spec claimed the skip *fabricates a zero* — on the reasoning that `:162` sets
`ORPHAN_COUNT=0` and `:185` tests `-gt 0`. That is wrong: `:185` is **inside** the
`[ -d ]` block, which spans `:163`–`:195`, so when the guard fails the threshold test
never executes and `ORPHAN_COUNT=0` is dead initialisation, never consulted.
`grep -n 'ORPHAN_COUNT'` returns `:162 :183 :185 :186` and shows no nesting, which is
exactly how the wrong reading survives.

The distinction does not change the remedy — an else arm either way — but it does change
one thing the implementer would otherwise do: **`ORPHAN_COUNT=0` must be left alone.**
"Also stop pre-initialising the count" is a plausible-sounding instruction that edits dead
code on a false premise.

```bash
# :163 opens at column 0; :185 is INDENTED, which is the nesting made visible.
sed -n '163p;185p;195p' platforms/claude-code/hooks/session-orient.sh.template
#   if [ -d "$NOTES_DIR" ]; then
#         if [ "$ORPHAN_COUNT" -gt 0 ]; then      <- six spaces in
#   fi
```

**In scope:** add the else arm. Warn on stderr, omit the signal, say why. That restores
the block's own stated contract and is a two-line change.

**Explicitly NOT in scope:** substituting `{{NOTES_DIR}}`. Nothing in this repo
substitutes it —

```bash
grep -rn '{{NOTES_DIR' generators/ skills/    # no substitution site
```

— which puts it in the same family as `{{OBS_THRESHOLD}}` / `{{TENSION_THRESHOLD}}`,
already recorded as divergence 14: placeholders that look configurable and are not.
Wiring them is a change to what generation emits and belongs to the generator/vault
enforcement-gap track, not here.

### 5. Amend deferral 13

Not a reopening. Add to entry 13 that on any vault whose notes directory is not literally
`notes/`, the block it describes does not execute at all, so its "rare failure" framing
understates the case — and cross-reference the F10 fix.

## Out-of-band scope additions (2026-08-09)

Requested directly, not surfaced by the review. Numbered 6 and 7 to continue the Design
sections, but held outside `## Design` so the finding-to-fix mapping above stays exact.

### 6. Four plugin skills run inline, not forked

`setup`, `upgrade`, `architect` and `health` drop `context: fork`. The request named those
four. **No principle was derived, and none is claimed here.** Two candidate rationales were
tested against the tree and both failed, which is why this section records the input rather
than inventing a rule to justify it:

| hypothesis | falsified by |
|---|---|
| "the skills that ask the user questions" | `add-domain`, `reseed`, `tutorial` also carry `AskUserQuestion` and are out of scope; `architect` and `health` do not carry it and are in |
| "the skills that mutate the vault" | `add-domain` and `reseed` mutate too |

The four are 4 of the 9 forked skills; `help` is already inline, making the post-change
split 5 inline / 5 forked with no stated rule governing it. That is recorded as a known
gap rather than papered over — see `## Deliberately not in scope`. Re-derive:

```bash
for d in skills/*/; do printf '%-12s %s\n' "$(basename "$d")" \
  "$(/usr/bin/grep -m1 '^context:' "$d/SKILL.md" || echo '(none — inline)')"; done
```

**Nothing in this repo reads the key.** Verified by substring search rather than a
line-anchored one, so the claim covers the key and not one spelling of it — the only hits
are unrelated prose and `reference/templates/companion-note.md`'s own `context:` field, a
different schema entirely:

```bash
/usr/bin/grep -rn 'context:' scripts/ .github/ hooks/ generators/ \
    platforms/claude-code/ .claude-plugin/ reference/ 2>/dev/null
```

This is therefore a change to host behaviour only. No gate, generator or hook observes it —
which also means **no gate can regress on it.** That cuts both ways and is stated, not sold.

**`model:` goes with it, on precedent — not on a mechanism claim.** `skills/help` is the
only inline skill today and declares neither `context:` nor `model:`; the four match it.
Whether `model:` is genuinely *inert* without `context: fork` is host behaviour this repo
cannot verify from here, and this spec does not assert it. The precedent is n=1 and is
stated as such.

**The material consequence is `setup`, and only `setup`.** It declares `model: sonnet`
where the other three declare `model: opus`. Dropping the key hands all four to the session
model: for `upgrade`, `architect` and `health` in an opus session that is opus→opus and no
change at all; for `setup` it is a real move off sonnet, on the largest skill in the tree
at 1777 lines.

**The trap, stated because a `sed` walks straight into it.**
`skills/setup/SKILL.md:1317` reads *"Adjust skill metadata (set `context: fork` for fresh
context per invocation)"* — that is `setup` **prescribing fork for generated vault
skills**, a different tree, out of scope, and it must survive byte-identical. `setup` is
the one file where the string appears twice with opposite meanings.

**Frontmatter shape is not uniform**, so this is "delete two adjacent lines per file", not
one patch applied four times: `setup` carries no `version:`/`user-invocable:`, `health` no
`user-invocable:`, and `architect`/`health` carry `argument-hint:`. Rule 5 — normalise
nothing else.

### 7. README claim audit

Every checkable claim in `README.md` was re-derived. **Nine correct, one defect.**

| claim | site | measured |
|---|---|---|
| 10 plugin-level commands | `:291`, table `:108-117` | 10 dirs, 10 rows ✓ |
| 16 generated templates | `:302`, table `:123-138` | 16 dirs, 16 rows, set difference empty **both ways** ✓ |
| 17 feature blocks | `:315` | 17 ✓ |
| 249 research claims | `:196`, `:316` | 249 ✓ |
| 16 kernel primitives | `:318`, `:383` | 16 ✓ |
| Three hooks | `:176` | 3 ✓ — see the near-miss below |
| six shell tools = what the fence gate asserts | `:276` | 7 rows = 6 + `tree` ✓ |
| `hooks/scripts/` also holds `vaultguard.sh`, `read_config.sh` | `:186` | both present ✓ |
| `agents/knowledge-guide.md` | `:309` | present ✓ |
| **`reference/` check-script family** | `:323-326` | **4 listed, 5 on disk** ✗ |

**The defect is `check-vocabulary-schema.sh`, absent from the Project Structure block.**
That block elides heavily and legitimately elsewhere — `reference/` holds 33 entries and
lists 11 — but the four `check-*.sh` appear consecutively with no ellipsis, which reads as
the complete family. There are five. This repo's own "stated limitations imply
completeness" class, sitting in its front-door document.

**The "Three hooks" row is a near-miss worth recording**, because the first measurement
returned 2 and looked like a second defect. `jq '[.hooks[][]]|length'` counts *matcher
groups*, and the two `PostToolUse` hooks share one:

```bash
jq '[.hooks[][]]|length'         hooks/hooks.json   # 2 — matcher groups, the wrong unit
jq '[.hooks[][].hooks[]]|length' hooks/hooks.json   # 3 — individual hooks, matches README:176
```

Verify the property, not a proxy that resembles it — the lesson the kernel validator's
`PASS: 15` teaches one tree over.

**The fork change falsifies nothing in the README, and that is a finding rather than an
absence.** The obvious assumption is that `### Fresh Context Per Phase` (`:156-169`) must
now be wrong. It is not: every line of it is about `/ralph` and the **generated** pipeline
spawning a subagent per phase, which this change does not touch. Editing it would introduce
an error, not remove one.

```bash
/usr/bin/grep -n -iE 'subagent|fresh context|context window' README.md   # all /ralph or generated
```

**Two constraints on editing README**, both verified rather than assumed. It is in
`check-prose-paths.sh`'s stated SCOPE, so every path it names must resolve — the addition
does, which is why it is safe. And `check-doc-claims.sh:299` anchors a claim on `:383`'s
text by regex, so **inserting a line above it is safe and rewording that line is not.**

### 8. One prose claim elsewhere goes stale on this commit

`CLAUDE.md:307` reads *"Both use SKILL.md frontmatter (`context: fork`, `model:`,
`allowed-tools:`)"*. After section 6 that parenthetical is false for 4 of 10 `skills/`.
It is ungated prose of exactly the class the divergence list is about, and it rots on **this
commit** rather than on merge — so it is fixed in the same commit, not filed.

## Salvaged deferrals (2026-08-09)

Pulled in from `docs/superpowers/deferrals.md` after commit `f741a6c` recovered 28 parked
findings from the eight gitignored SDD ledgers deleted with the plan archive. **Numbered 9-14
to continue the Design sections, but labelled `D<n>` against their `deferrals.md` entry, not
`F<n>`** — an `F` is an adversarial-review finding against `a98352c`, a `D` is a previously
deferred item whose blocking reason has lapsed. The opening section makes a point of
provenance; collapsing the two numberings would spend it.

**Six of twenty entries fold in. That is the honest ceiling, not a target met** — the
remaining fourteen are accounted for individually under *Deliberately not in scope*, each
with the specific thing that blocks it. Entry 20 is excluded on its own recorded ruling
rather than on cost: it argues it is a truncated *display* that discloses its remainder, not
a sampled measurement, and folding it would contradict the reasoning committed one commit ago.

### 9. `read_config.sh`'s two bare-vs-dotted asymmetries (D16)

One reader, two code paths that differ where a caller cannot see it.

- **A present-but-empty value fails LOUD on the dotted path (`exit 1`) and SILENTLY returns
  the default on the bare path.** Returning the default on a key the user actually wrote is
  precisely how divergence 3's hardcoded `10` stayed invisible for as long as it did — the
  file said one thing, the hook did another, and nothing said so.
- **Key names are interpolated into an awk ERE**, so a `.` in a key matches any character:
  `self_evolution.obs.ervation` would match a line spelling `obsXervation`.

**Why it belongs here rather than deferred again:** this spec already reasons about
`read_config.sh`'s consumers through F10 and section 4, and the first asymmetry is the same
failure class as F10's silent skip — a value that should have been refused coming back as a
plausible default. Fixing them apart would mean two passes over one 90-line reader.

The bare path becomes loud on present-but-empty, matching the dotted path; the key is escaped
before interpolation. **The bare-key change is a behaviour change and is safe only because no
shipped bare key is written-but-empty** — that is a measurement, and it must be re-taken at
implementation time rather than inherited from this sentence.

```bash
/usr/bin/grep -n 'exit 1' hooks/scripts/read_config.sh     # the dotted path's loud arm
/usr/bin/grep -n 'awk' hooks/scripts/read_config.sh        # the interpolation sites
bash reference/test/threshold-namespace.test.sh | tail -1  # 52/52 — covers NEITHER today
```

### 10. `session-orient.sh` counts open recursively but totals flat (D17)

`:151` counts open items with `count_notes_by_field`, which recurses. `:154`-`:155` compute
`OBS_TOTAL`/`TENS_TOTAL` with `ls -1 ops/observations/*.md`, which does not. `:207` prints
both in one sentence — `"$OBS_COUNT pending observations (of $OBS_TOTAL total)"` — so a vault
holding an open item under `ops/observations/archive/` can report a count larger than its own
total.

**Why here:** it is the same recursion axis as the open decision below, on the same file
family, and resolving one while leaving the other would leave the hook internally inconsistent
about what "a note" means. The totals become recursive, matching the library — which is also
the direction the orphan decision's `candidates` axis recommends, so the two land coherent.

**It gates nothing today** — the threshold compares `OBS_COUNT` alone — which is why it was
deferrable at all, and why it must not be allowed to grow a second consumer first.

```bash
/usr/bin/grep -n 'count_notes_by_field\|OBS_TOTAL=\|TENS_TOTAL=' hooks/scripts/session-orient.sh
```

### 11. `fence-isolation.test.sh`'s fixed temp path (D14)

`:50` sets `WORK="/tmp/fence-isolation-gate-$SELF"`. `$SELF` is the shell name, not a per-run
token, so two runs under the same shell share one directory. Observed live: a foreground run
beside a background sweep produced `harness: extracted no fences — cannot conclude anything`
under bash and `rm: Permission denied` under zsh.

**Why here:** section 3 is already "suite blind spots", and this spec adds assertions to this
very suite. Adding rows to a harness that can corrupt its own workspace when run twice is the
wrong order of operations.

`mktemp -d` replaces the fixed path. **The failure is currently LOUD, not a false PASS** — the
"cannot conclude anything" arm is doing its job — so this is a contributor-ergonomics fix, and
the criterion must not claim it closes a correctness hole.

```bash
/usr/bin/grep -n '/tmp/fence-isolation-gate-' reference/test/fence-isolation.test.sh   # :50
```

### 12. `check-portability.sh` check 6 — substring match, whitespace-split allowlist (D19)

- `interp_hits_in` (`:436`, used `:484`, `:497`) is an unanchored `-F` substring match while
  the half it is compared against parses paths differently. Any divergence yields a false
  FAIL, never a false PASS.
- The allowlist is whitespace-delimited, so a path containing a space mis-parses silently.

**Why here:** section 3's suite work already touches this guard's coverage, and both defects
are in the check whose allowlist this spec's own changes may move.

**The space claim needs stating precisely, because its first form was wrong.** 234 tracked
paths contain a space — all in `methodology/`, whose sentence-length filenames the check's
declared scope excludes; the scanned trees hold zero. And measuring that requires
`core.quotePath=false`: git quotes the one tracked path carrying an em dash, so a
`^methodology/` anchor reports a spurious survivor.

```bash
/usr/bin/grep -n 'interp_hits_in' reference/check-portability.sh          # 436, 484, 497
git -c core.quotePath=false ls-files | /usr/bin/grep ' ' \
  | /usr/bin/grep -c '^\(skill-sources\|skills\|platforms\|reference\|generators\)/'   # 0
```

### 13. `skill-sources/next:261`'s bare relative `LINK_LIB` (D3)

Eight sites spell `LINK_LIB="$VAULT_ROOT/ops/lib/link-extraction.sh"`; `next:261` spells it
bare and relative, so it resolves against the fence's working directory.

**Why here:** its own entry says *"Reopens: immediately — this is a 'do it separately', not a
'do it never'. Anyone touching `next`'s link fences should take it."* This spec's group work
touches the link library and its consumers. This is the trigger firing as written, and it is
the only one of the six that folds in on its own terms rather than on a judgment call.

Behaviour-neutral where the working directory is already the vault root, which is why it was
correctly kept out of the link-library change whose whole risk was reported numbers moving.

```bash
/usr/bin/grep -rn 'LINK_LIB=' skill-sources/          # 8 prefixed, 1 bare
```

### 14. Widen `check-prose-paths.sh`'s stated scope by two files (D9)

`hooks/scripts/session-orient.sh` and `platforms/claude-code/hooks/session-orient.sh.template`
both name repo paths — in comments and in warning text a user reads at SessionStart — and
neither is in the gate's eight-file scope. A path that rots in either is checked by nothing.

**This is a new decision, not a trigger that fired, and the distinction is the entry's own
point.** D9 reopens "whenever someone is editing that gate anyway"; this spec edits the gate's
*subject* (section 4 changes the template), not the gate. Folding it means deliberately
widening a stated scope, which is exactly the act D9 protects — a *stated* list is what makes
a shrinking scope impossible to mistake for a clean result, so growing one must be an explicit
edit with a reason on the record. The reason: section 4 adds warning text to the template that
names paths, so this spec is actively increasing the unchecked surface.

**Widening a stated list is only safe while it stays stated.** The two files are added by
name; no discovery, no glob.

```bash
awk '/^SCOPE="/{f=1;next} /^"/{f=0} f&&NF' reference/check-prose-paths.sh   # 8 today, 10 after
/usr/bin/grep -c 'session-orient' reference/check-prose-paths.sh            # 0 today
```

## The open decisions

Two, now. Both change behaviour on machines that are not this one, which is the property
that puts them here rather than in a Design section.

### Decision 1 — which orphan definition is authoritative, on three axes?

This spec cannot rule
alone, because every option changes user-visible counts in five shipped commands.

| axis | option A | option B | recommendation |
|---|---|---|---|
| self-link | rescues (graph, stats) | **excluded** (library, health, architect, template) | **B** — a note linking to itself has no *incoming* link from another note; the library's suite already pins this and `/graph`'s "authority" ranking is meaningless if self-citation counts |
| candidates | flat (health, template) | **recursive** (graph, stats, architect) | **B** — a note in a subdirectory is still a note; flat silently makes it unreportable |
| rescuing links | notes dir (graph, stats, architect, template) | whole vault (health) | **A**, weakly — the kernel's dangling check already excludes `ops/` and logs on the stated ground that a wiki link in a changelog is a historical citation, not a graph edge; the same reasoning applies to rescue |

Recommending **B / B / A**: converge every surface on
`orphan_notes_recursive(<notes dir>)`, which is what `/architect` already calls.

**The third row is the one to challenge**, and the reason is on the record: during the
link-edge-map plan, `skills/health:185-186` was *deliberately composed* from primitives rather
than delegated, because neither library variant expressed "notes from here, links from
anywhere", and the composition was chosen against a measured alternative. Changing that
row reverses a decision made with evidence. It measures 0 either way on the field vault
today, so nothing forces the choice now — which is precisely why it should be made
deliberately rather than absorbed into a refactor.

**Until this is ruled on, the plan implements groups A, B, C and E and leaves D
untouched.** Partial conversion is what created the divergence; converting two more
surfaces on a guess would deepen it.

### Decision 2 — should the PostToolUse matcher widen beyond `Write`? (D15)

`hooks/hooks.json:17` matches `"Write"` only, so `Edit` and `MultiEdit` bypass
`write-validate.sh`'s content-destruction guard entirely — and notes are usually changed with
`Edit`. The guard exists to catch a note being overwritten with less than it had; today it
watches the least-used door.

**Why this is a decision and not a fix.** Widening the matcher makes the guard run on every
edit in every vault the plugin is installed in. That is a cost imposed on other people's
machines, and it is the same shape as Decision 1: not hard to implement, hard to be entitled
to decide unilaterally.

**It also does not stand alone, which is the part that makes a naive widening actively
misleading.** Divergence 16 records that the guard is *already* gated behind a hardcoded
`*/notes/*` filter, so on the field vault — `nodes/`, the very vault whose defect motivated
the guard — it cannot fire for `Write` either. Widening the matcher without also making that
filter vocabulary-aware buys **zero** additional coverage on any vault that renamed its notes
directory, while adding a hook invocation to every edit. A change that costs on every machine
and pays on almost none.

| option | coverage gained | cost |
|---|---|---|
| A — widen matcher only | none on any renamed-directory vault | a hook run per edit, everywhere |
| B — widen matcher **and** make the path filter vocabulary-aware | the guard actually fires | same, plus a generation-surface question |
| C — neither; record and wait | none | none |

**Recommending C for this spec and B as its own change.** B crosses into the
generation-surface territory this spec explicitly excludes (the filter has to learn the
vault's vocabulary, which is divergence 14 and the enforcement-gap track's subject). Doing A
alone is the option to avoid: it looks like a fix, changes the cost profile for every
installed vault, and closes nothing.

```bash
/usr/bin/grep -n '"matcher"' hooks/hooks.json                        # :17, "Write"
/usr/bin/grep -n 'notes/' hooks/scripts/write-validate.sh | head -2  # the hardcoded filter
```

## Deliberately not in scope

**The thirteen deferrals that did not fold, each with what blocks it.** Listed by entry so
"as many as possible" is auditable rather than asserted — a reader can check that the ceiling
was real. Entries 3, 9, 14, 16, 17 and 19 folded in above; 15 became Decision 2; `20 = 6 + 1 + 13`.

```bash
/usr/bin/grep -c '^### [0-9]' docs/superpowers/deferrals.md   # 20 open entries
```

| # | entry | what blocks it |
|---|---|---|
| 1 | `generators/features/maintenance.md` matchers | Generation-surface: a recipe cannot source a library the way a fence can, so converting it changes what generation *emits* |
| 2 | `testing-milestones.md:425` matcher | Teaching material in a test spec's worked example; changing it changes what the spec teaches, not what ships |
| 4 | materialized backlink cache | Design track, not a defect |
| 5 | 681 statusless field-vault notes | Field-vault **content**, not repo code |
| 6 | `~150` vs `200` description length | Needs a ruling on which is right; no code change without it |
| 7 | off-enum vault statuses | Field-vault content plus an enum-authority ruling |
| 8 | `open`'s semantics | Definitional ruling, same family as 7 |
| 10 | contract-field assertion | Needs an explicit contract marker in the templates first; owned by the CI-hardening spec, item 18 |
| 11 | divergence 16, three-tier gap | Explicitly its own spec — a generated-artifact refresh mechanism, not a check |
| 12 | `generators/` enum placeholders | **Blocked on `2026-08-08-note-convention-and-lifecycle` landing**, which has not been executed; its own entry says "reopens immediately *after*" that plan |
| 13 | orphan-count conflation | Already handled — section 5 amends it; its trigger is untripped |
| 18 | `check-placeholder-count` range-relativity | Closing (a) needs content-similarity pairing the gate does not have; it is the price of being the one range-relative gate |
| 20 | C1 display cap | **Excluded on its own ruling**, not on cost: it discloses its remainder, so it is a truncated display and not a sampled measurement — the distinction divergence 11 turned on |

- **Reopening deferral 13.** Its stated trigger is not tripped. Amended, not reopened.
- **Substituting `{{NOTES_DIR}}` / the threshold placeholders.** Generation-surface
  change; divergence 14 and the enforcement-gap track own it.
- **F4's implementation.** Blocked on the ruling above.
- **Making the `errf` path unique per call.** The concurrency half is latent; clearing
  before use is the whole fix.
- **The inlined `_strip_fences` awk clones in `graph:~549` / `stats:~383`.** Pre-existing,
  not this merge — Fable verified `graph` went 2→1 during it.
- **`existing_note_index_recursive`'s missing `-not -path '*/.git/*'`.** Practically empty
  set; noted, not fixed.
- **Deriving a rule for which skills fork.** After section 6 the split is 5 inline / 5
  forked with nothing stating why. Two candidate rules were tested and falsified; the
  selection was the request. Inventing a principle to fit four named skills would be
  reverse-engineered rationale, which is worse than a recorded gap — so it is recorded as
  a gap. A third skill moving either way is the point at which the rule has to be written.
- **`reference/skill-authoring.md` documenting the frontmatter keys.** Found while
  checking what `context:`/`model:` control: the authoring reference describes neither.
  Real gap, but widening that document is its own change and not this one.

## Success criteria

**Each criterion names a finding, so none can be satisfied by work that skipped one.** A
first draft of this list had four findings — the else arm, jq's diagnostic, the `errf`
clear, and the deferral amendment — touched by no criterion at all, which would have let
the whole set pass with them undone. That is the same defect as a test that cannot fail.

| # | criterion | covers |
|---|---|---|
| 1 | All sixteen gates green in both shells, unchanged in count and composition — fence gate `files=27 fences=78 run=75 skipped=3`, skips still `remember f04` / `tasks f03` / `reseed f03` | all |
| 2 | Every new assertion mutation-proved with the mutation asserted to have applied. A rising total is not evidence | all test work |
| 3 | Deleting the source-side `_fold_lower` from either edge-map builder turns the suite **red** | F5 |
| 4 | Stripping `LC_ALL=C` from any one of the four exported sorts turns the suite **red**; `LINK_EXTRACTION_VERSION` is 4; the raised floors are enumerated in the commit message, not assumed | F3 |
| 5 | A note whose filename contains two consecutive spaces round-trips through `backlink_counts` with the key intact | F7 |
| 6 | A stale `/tmp/link-extraction-err-$$` planted before a call does not make that call return 1 | F9 |
| 7 | A new `queue-edit.test.sh` wired into CI in both shells, every assertion mutation-proved; the `mv`-failure path documented as hand-run, **not rounded up to covered** | F1c |
| 8 | A forced rename failure returns rc 1, discards the temp, and names the path — verified by stub | F1a |
| 9 | A jq-rejected filter surfaces jq's own diagnostic, not the generic message | F1b |
| 10 | Running the suite from `reference/test/` gives the same result as from the repo root | F8 |
| 11 | `/health` Category 9 reports on all three libraries | F6 |
| 12 | With `NOTES_DIR` pointing at a directory that does not exist, the template's orphan block **warns on stderr** and emits no signal — and `ORPHAN_COUNT=0` at `:162` is still present, untouched | F10 |
| 13 | `deferrals.md` entry 13 carries the amendment and corrected line citations, and is **not** moved to Closed | F2 |
| 14 | `check-doc-claims.sh` green — any numeral this work moves is updated in the same commit | records |
| 15 | No new `skill-sources/` hardcoding: `check-placeholder-count.sh main` rc 0 | Constraint 5 |
| 16 | `^context:` returns **0** across the four skills, and `^model:` with it — measured per file, not as a total | §6 |
| 17 | `skills/setup/SKILL.md:1317` is **byte-identical** to its pre-change state, and the `context: fork` string still occurs there exactly once | §6 trap |
| 18 | The other five forked skills are **untouched**: `^context: fork` still returns 5 across `skills/` | §6 scope |
| 19 | `check-vocabulary-schema.sh` appears in README's `reference/` block, and `check-prose-paths.sh` is green — the added path resolves | §7 |
| 20 | README `:156-169` and `:383` are **unmodified**, and `check-doc-claims.sh` is still green — the fork change touches neither | §7 constraints |
| 21 | `CLAUDE.md:307`'s frontmatter parenthetical no longer claims all `skills/` carry `context: fork` | §8 |
| 22 | A bare key that is **present but empty** in `.arscontexta` exits non-zero and says so, matching the dotted path — verified against a fixture, and the "no shipped bare key is written-but-empty" claim **re-measured**, not inherited from the spec | §9 (D16) |
| 23 | A key containing a `.` no longer matches a line where that position holds a different character — a fixture spelling `obsXervation` is **not** returned for `self_evolution.obs.ervation` | §9 (D16) |
| 24 | `OBS_TOTAL`/`TENS_TOTAL` count recursively; a fixture with an open item under `ops/observations/archive/` reports a total **≥** its open count, and the `:207` sentence is consistent | §10 (D17) |
| 25 | Two concurrent runs of `fence-isolation.test.sh` under the same shell both complete; no run reports `extracted no fences`. Criterion is contributor ergonomics — it must **not** be written as closing a correctness hole, because the pre-fix failure was already loud | §11 (D14) |
| 26 | `interp_hits_in` is anchored, and an allowlist entry whose path contains a space parses as one entry — both mutation-proved. The scanned-tree space count is re-derived **with `core.quotePath=false`**, since without it the check reports a spurious survivor | §12 (D19) |
| 27 | `/usr/bin/grep -rn 'LINK_LIB=' skill-sources/` returns **9 prefixed, 0 bare**, and `/next`'s reported numbers are unchanged before and after — the fix is behaviour-neutral or it is not this fix | §13 (D3) |
| 28 | `check-prose-paths.sh`'s SCOPE names **10** files including both `session-orient` paths, the gate is green, and the list is still a literal stated list — no glob, no discovery | §14 (D9) |
| 29 | Decision 2 is **recorded as ruled, not silently implemented**: `hooks/hooks.json:17` still reads `"Write"` unless the user picks option B, and `deferrals.md` entry 15 reflects whichever way it went | Decision 2 (D15) |

Criterion 12's second clause is deliberate: it fails both the missing fix *and* the
plausible-but-wrong over-fix the spec warns about in section 4.

## Self-review findings

Dispatched review of this spec: **2 Important, 3 Minor. All five fixed above.**

| # | finding | resolution |
|---|---|---|
| I1 | Section 4's "fabricates a zero" claim was **wrong** — `:185`'s `-gt 0` test is nested inside the `[ -d ]` block (`:163`–`:195`), so a failed guard skips it and `ORPHAN_COUNT=0` is never consulted | Reverted to the adversarial report's original reading; the trap that produced it is now recorded, and the plan carries an explicit "leave `ORPHAN_COUNT=0` alone" |
| I2 | All eight success criteria could be met with four findings — the else arm, jq's diagnostic, the `errf` clear, the deferral amendment — **never implemented** | Criteria rewritten as 15 rows, each naming the finding it covers |
| M1 | Cited the `[ -d ]` guard at `:162`; actual `:163` | Fixed, and the amendment now also corrects entry 13's own drifted citations |
| M2 | Cited `skills/health:174` for the deliberate composition; actual `:185-186` | Fixed |
| M3 | "quoted in five consumer comments" not re-derivable — 2 exact, variants in 2 more | Replaced with a re-derivation command |

**I1 is the one worth carrying forward.** It came from reading `grep -n 'ORPHAN_COUNT'`
output — `:162 :183 :185 :186` — and inferring structure from line adjacency. The line
numbers were all correct; the nesting was invisible. A flat match list cannot show scope,
and this repo's own house style of citing `file:line` makes that mistake easy to reach.
Verify structure with a range, or read the indentation.

Verified sound by the same review, and not re-litigated here: coverage is complete (all
ten findings mapped, none silently absent); every fenced command ran and matched
(`11/35/46`, `85/6`, `0/2686/2686`, the queue-edit evidence); the deferral-13 ruling is
genuinely untripped rather than motivated reasoning; the measurement table re-derives;
criterion 1's fence-gate pins including the three skip names check out live; and the F5
mutation was independently re-confirmed at 91/0 green under the mutant, restored
byte-identical.
