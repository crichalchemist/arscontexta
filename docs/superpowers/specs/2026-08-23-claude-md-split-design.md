# Spec: split CLAUDE.md into three files (2026-08-23)

**Status:** design, not executed. This document is the tracked record for the split.
**Baseline:** branch `fix/ci-timeout-bound`, HEAD `97cc6fd`. Every line number below was
measured at that commit; if HEAD has moved, re-measure the three boundary lines first
(command in §4) before trusting any `L<n>` in this file.

## 1. Problem

`CLAUDE.md` is 112,522 bytes / 1,454 lines. The harness auto-loads roughly the first
40,000 characters of a CLAUDE.md into every session; everything past that point is
silently absent — which for this file means most of the Verification forensics and the
entire divergence list load never, while still costing the full 40k of context budget on
the parts that do. The fix is to keep an orientation-sized CLAUDE.md and move the two
oversized sections into `docs/`, where they are read deliberately rather than injected.

The hazard is not the move — it is the readers. Four programmatic mechanisms in
`reference/check-doc-claims.sh` and one in `reference/check-prose-paths.sh` read
CLAUDE.md **by hardcoded path and by text anchor**, and this repo's dominant defect
class is silent failure. §6 inventories every reader and classifies each failure mode
as loud or silent. The one genuinely silent mode is **duplication** (fragment present
in both the old and a new file), and §11's assertions exist specifically for it.

## 2. Locked decisions (do not reopen)

1. **Three files.** `CLAUDE.md` (kept) + `docs/verification.md` + `docs/open-divergences.md`.
   Names final; the second pairs with the existing `docs/closed-divergences.md`.
2. **The run fence (L46–75) moves** to `docs/verification.md` with the rest of the
   Verification section. This was chosen against a recommendation to keep it; the kept
   file lands at ~11.5k chars instead of ~13.3k. It is the riskiest step in this spec
   because the fence's first line (`bash reference/check-portability.sh`) and its
   `for s in bash zsh; do … done` loop are text anchors for two gate mechanisms (§6.2,
   §6.3).
3. **This spec is the tracked record** and carries the required `## Deferrals` section
   (§14).
4. **Deferral 24 is reopened** — it already fired: `check-prose-paths.sh` SCOPE is 14
   files while CLAUDE.md L868 still says "across 11 documents". §10 draws the scope
   boundary for what this branch fixes vs. what stays deferred.

## 3. Scope and non-goals

**In scope:** the three-file split; repointing every programmatic reader; the enumerated
anaphora edits (§7); the two pointer restatements promoted into the kept file (§8); the
deferral-24 prose fixes and `docs/superpowers/deferrals.md` entry-24 update (§9, §10);
the no-duplicate and size assertions; one commit.

**Non-goals — the split changes WHERE prose lives, never WHAT it claims:**

- No renumbering of divergence entries (entries are referenced by number from work in
  flight; the file's own headers say so).
- No heading-level normalization, no reflow, no typo fixes inside moved fragments. The
  moved bodies are byte-identical except for the edits enumerated in §7, each of which
  is individually listed and individually verifiable.
- No `@docs/...` import lines in the kept CLAUDE.md — an @import re-inflates the
  auto-loaded context and defeats the split. Plain markdown links only.
- No gate-building. Deferral 24's gate half and divergence 17's dot-directory widening
  stay with the CI-hardening spec (§10, §14).
- No edits to `platforms/shared/skill-blocks/` (frozen), no edits to CONTRIBUTING.md,
  no changes to what any generator emits.
- No content-staleness repairs beyond the deferral-24 numeral. Stale prose that moves,
  moves stale; recording drift rather than silently correcting it is this repo's
  convention and the moved text does it internally.

## 4. Three-file layout

Boundary lines at `97cc6fd` — re-derive before executing:

```bash
# -E, NOT BRE '\|'. BSD grep 2.6.0-FreeBSD (this environment) drops every alternative
# but the last when a NON-FINAL branch ends in '$' -- the '$' degrades to a literal, so
# that branch can never match. rc=0, one plausible line instead of three. ('^' mid-pattern
# is fine here; the fault is the '$' specifically. Measured both ways.)
LC_ALL=C /usr/bin/grep -nE '^### Verification$|^## Architecture: three generation paths$|^## Known open divergences$' CLAUDE.md
# 47:### Verification      <- L46 is BLANK; the fragment starts on it, not on the heading
# 355:## Architecture: three generation paths
# 463:## Known open divergences
```

Fragment sizes, measured, with the decomposition stated (sum must equal the file):

| fragment | lines | chars |
|---|---|---|
| preamble + What this repo is + dev-loop intro | 1–45 | 2,134 |
| Verification (run fence 46–75 + forensics 76–354) | 46–354 | 29,450 |
| Architecture + The backport loop | 355–462 | 7,644 |
| Known open divergences (incl. Closed pointer, Won't fix, cross-cutting) | 463–1454 | 73,294 |
| **total** | | **112,522** |

```bash
LC_ALL=C awk 'NR<=45{a+=length($0)+1} NR>=46&&NR<=354{b+=length($0)+1} NR>=355&&NR<=462{c+=length($0)+1} NR>=463{d+=length($0)+1} END{print a, b, c, d, a+b+c+d}' CLAUDE.md
# 2134 29450 7644 73294 112522
```

Targets:

| file | content | target chars | hard assertion |
|---|---|---|---|
| `CLAUDE.md` (kept) | L1–45 + verification pointer stanza + L355–462 + divergences pointer stanza (both stanzas in §8) | ~11,500 | `wc -c` < 13,000, and < 40,000 as the property the split exists for |
| `docs/verification.md` | header (§5.1) + L46–354 byte-identical, then §7 edits | ~29,900 | body byte-identical to fragment before §7 edits (diff in §11 step S1) |
| `docs/open-divergences.md` | header (§5.2) + L463–1454 byte-identical, then §7 edits | ~73,900 | same |

The kept file's ~11.5k is 2,134 + 7,644 + roughly 1.7k of stanzas; it is deliberately
far under the limit so the file has headroom to grow the way this one did — slowly, in
prose — before anyone notices again.

## 5. New-file headers

Headers are the one place a new file may add content above the moved fragment. Both are
short, and both carry the cross-file resolution note that lets dozens of "divergence N"
/ "gate table" references stay untouched (§7).

### 5.1 `docs/verification.md`

```markdown
# Verification

> Split out of the repo root `CLAUDE.md` on 2026-08-23, because the harness auto-loads
> only the first ~40,000 characters of a CLAUDE.md and the file had reached 112,522
> bytes. The body below is the moved section — byte-identical at the split except for
> the edits enumerated in `docs/superpowers/specs/2026-08-23-claude-md-split-design.md`
> §7. "Divergence N" refers to the numbered entries in `docs/open-divergences.md`.
> Every fence assumes cwd = repo root, exactly as it did before the move.
> `reference/check-doc-claims.sh` reads this file by text anchor: do not reword a
> sentence carrying a number without running that gate.
```

The moved fragment begins with the **blank line** at CLAUDE.md L46, and the original
`### Verification` heading (L47) is its second line, kept verbatim (the heading is not a
gate anchor, but byte-identity is the property S1 verifies). `docs/open-divergences.md`
is NOT symmetric here: its fragment starts *on* `## Known open divergences` (L463) with no
leading blank. That asymmetry is why S1 computes each body's start line separately.

### 5.2 `docs/open-divergences.md`

```markdown
# Open divergences

> Split out of the repo root `CLAUDE.md` on 2026-08-23; pairs with
> `docs/closed-divergences.md`, exactly as before. The run fence, the gate table, and
> the Verification forensics this list refers to live in `docs/verification.md`.
> `reference/check-doc-claims.sh` anchors its divergence-uniqueness scan on the
> `## Known open divergences` heading below and reads three CLAIMS rows from this file
> by text anchor. Body byte-identical to the moved section except for the edits in
> `docs/superpowers/specs/2026-08-23-claude-md-split-design.md` §7.
```

Constraint the header must obey: **no line in it may begin `## ` (h2)**. The
uniqueness awk is `/^## Known open divergences/{f=1;next} f&&/^## /{exit} f` — an h2
above the real heading would not set the flag early (pattern is exact), but the
discipline is cheap and removes the case entirely. Blockquote lines and the `# ` h1
title are safe. The moved fragment's own subsections (`### Closed divergences`,
`### Won't fix`, `### The cross-cutting pattern`) are h3 and do not terminate the awk
range — verified against the fragment: no `^## ` line exists after L463, so the
extracted section runs to EOF in the new file exactly as it does today.

## 6. Complete reader inventory

Every programmatic reader of this repo's CLAUDE.md content, what fragment its anchor
lands in, where it must repoint, and — the load-bearing column — whether a **missed**
repoint fails loud or silent. Finding during verification, contra the working notes
this spec was commissioned from: **a missed repoint is loud in all four
`check-doc-claims.sh` mechanisms.** Duplication is the only silent mode, and it is
silent for every reader at once. §11's assertions are built on that asymmetry.

### 6.1 CLAIMS rows (19 rows name CLAUDE.md)

Mechanism, verified at the consumption loop (`:338`,
`while IFS='|' read -r file label extract truthfn arg`): each row runs
`claimed=$(LC_ALL=C sed -n "$extract" "$file" | sort -u)`. Zero matches →
`ERROR … claim anchor not found — document reworded, or claim removed` (**loud**).
More than one *distinct* value after `sort -u` → MISMATCH (**loud**). Value ≠ truth
function → MISMATCH (**loud**). So a row left pointing at CLAUDE.md whose anchor moved
out errors immediately — *provided the anchor text is not duplicated in the kept file*.

Rows by script line at `97cc6fd`, with the pre-split anchor line each `sed` extract
matches (verified individually):

| row(s) | anchor (pre-split) | anchor phrase | repoint field 1 to |
|---|---|---|---|
| `:304` | L134 | "the seven checks are enumerated above" | `docs/verification.md` |
| `:305` | L50 | "the eleven test suites each run under both" | `docs/verification.md` |
| `:307` | L391 | "`reference/kernel.yaml` declares the 16 primitives" (Architecture, kept) | **stays `CLAUDE.md`** |
| `:308` | L1088 | "not remembered: **9 hits**" (divergence 12) | `docs/open-divergences.md` |
| `:310` `:311` | L114 | "born red at 72 sites across 26 files" (gate table) | `docs/verification.md` |
| `:312` | L114 | gate-table "seven checks:" | `docs/verification.md` |
| `:325` `:326` | L49 | "There are eighteen executable checks. Sixteen run in CI" | `docs/verification.md` |
| `:327` | L521 **and** L552 | `# 32` / `# 32, this tree` — two matching lines | `docs/open-divergences.md` |
| `:328`–`:335` | L63–L73 | the eight suite-count lines inside the run fence (`101/101`, `66/66`, `41/41`, `76/76`, `57/57`, `40/40`, `60/60`, `12/12`) | `docs/verification.md` |
| `:336` | L520 **and** L584 | `# 18` — two matching lines | `docs/open-divergences.md` |

Tally: 15 → verification, 3 → open-divergences, 1 stays. 19 total.

**Multi-match nuance (rows `:327`, `:336`):** these pass today only because both
matching lines carry equal values and `sort -u` collapses them to one. Both pairs
(L520+L584, L521+L552) sit inside the divergences fragment, so the split keeps each
pair in one file and the rows keep working. Invariant to preserve in any future edit:
the two spellings of each number must stay in the same gated file or stay equal —
splitting a pair across files would leave one copy silently ungated while the row
still passed. (The adjacent commands at L508–509 deliberately carry no `# N` comment
and are matched by neither extract — verified; they impose nothing.)

### 6.2 `truth_fence_suites()` (`:168`–`:174`) — the third reader the plan originally missed

```sh
truth_fence_suites() {
  [ -r CLAUDE.md ] || return 1
  _n=$(awk '/^for s in bash zsh; do/,/^done/' CLAUDE.md | /usr/bin/grep -c 'test\.sh' || true)
  [ "${_n:-0}" -gt 0 ] || return 1
  ...
}
```

Hardcodes `CLAUDE.md` **twice** (the `-r` guard and the awk). The `for s in bash zsh;
do` loop it scans is L62–74, inside the moving run fence. Repoint both occurrences to
`docs/verification.md`. Missed repoint: the awk yields nothing, the function returns 1,
row `:305` prints `ERROR … truth source produced nothing` — **loud**.

### 6.3 `check_list_len` invocation at `:426` ("verification fence is complete")

The flagged-unverified item, now verified. The awk program is
`'/^bash reference\/check-portability/{f=1} f&&/^```/{exit} f&&/reference\//'` — it is
**text-anchored** on the run fence's first command line (L56,
`bash reference/check-portability.sh …`) and terminated by the closing fence. The
count of `reference/` lines it extracts is compared against
`truth_checks_no_vault()` (= number of check/test files minus 1; `validate-kernel.sh`
is deliberately absent from the fence). Repoint the file argument to
`docs/verification.md`. Failure modes, from `check_list_len()`'s own body (`:396`):
empty extraction → `ERROR … extracted EMPTY list — block's shape changed, not list
cleaned` (**loud**); non-empty wrong count → MISMATCH (**loud**). The residual silent
hole — a *different* fence that happens to begin with the same anchor line and happens
to contain the right number of `reference/` lines — is pre-existing, not widened by the
split, and is pinned down to one case by the uniqueness assertion in §11
(`^bash reference/check-portability` appears exactly once in `docs/verification.md`).

### 6.4 Divergence-uniqueness block (`:479`–`:498`)

Hardcodes `CLAUDE.md` twice: a readability guard and
`section=$(awk '/^## Known open divergences/{f=1;next} f&&/^## /{exit} f' CLAUDE.md)`,
followed by header extraction `sed -n 's/^\*\*\([0-9][0-9]*\)[.,].*/\1/p'`. Repoint
both to `docs/open-divergences.md`. Missed repoint: zero headers extracted →
`ERROR zero divergence headers extracted` (**loud**). Behavior that must not change,
verified against the extractor: `**7, 8 and 9` extracts as `7` (comma matches
`[.,]`); `**14 — pointer` extracts as nothing (em-dash matches neither), so the
current output is **14 entries, all distinct** (1–6, 7, 10–13, 15, 16, 17) and must
read identically post-split. Do not "fix" entry 14's header to make it count — that is
a content change, out of scope.

### 6.5 `reference/check-prose-paths.sh` — the one reader where a miss is SILENT

SCOPE is a stated 14-file list (CLAUDE.md is a member; `docs/closed-divergences.md`
already is, which proves the `docs` prefix passes the PREFIXES filter — divergence
17's dot-directory limitation does not apply here). Add `docs/verification.md` and
`docs/open-divergences.md` → 16 files. **A missed addition is the silent case:** the
moved prose simply stops being scanned, and the banner's `0 missing` still prints.
This is why §11 asserts the banner reads `scanned 16 files` and `checked N repo paths`
with N ≥ 310 (the pre-split count) — a shrunken path count at 16 files would mean the
new files were listed but not parsed. An in-scope file that is missing is an ERROR
(stated in the script), so a typo'd filename in SCOPE is loud.

### 6.6 Readers that are NOT affected — inventoried so the next auditor need not re-sweep

Each verified by reading the site:

| file:site | what it does with CLAUDE.md | verdict |
|---|---|---|
| `reference/check-portability.sh:249` | root-CLAUDE.md **existence** as the arscontexta-root marker | unaffected — kept file persists |
| `reference/check-portability.sh:346` (check 5) | `AGENTS.md` must be a symlink to CLAUDE.md | unaffected — target persists |
| `reference/check-placeholder-count.sh:40` | comment only | none |
| `.github/workflows/checks.yml:115` | comment only | none |
| `hooks/scripts/session-orient.sh:270` | comment only | none |
| `reference/validate-kernel.sh` | reads the **vault's** CLAUDE.md, not this repo's | none |
| `reference/test/{fence-isolation,guard-failure,hook-config,kernel-note-dirs,moc-sync}.test.sh` | comments/fixture prose only | none |
| `reference/test/check-doc-claims.test.sh` | comments only (`:24,:29,:34,:42,:53`); mechanically it backs up and mutates `generators/features/graph-analysis.md` and runs the real script against the real tree (`cd "$ROOT" && "$SELF" "$CHECK"`) — no fabricated CLAUDE.md fixtures | none to edit; **must be run post-repoint** (§11 S7) |
| fence-isolation gate | extracts fences from `skill-sources/`/`skills/`, never from CLAUDE.md | none |

This closes the reader inventory: the complete programmatic reader set is §6.1–6.5.

## 7. Anaphora adjudication

The moved fragments are full of deixis — "above", "below", "this file", "near the top
of this file" — written when everything shared one file. Sweep patterns used
(`this file`, `above`, `below`, `near the top`, `divergence [0-9]`, `gate table`,
section names), each candidate read in context. 24 adjudicated sites; the
commissioning notes counted 20 — the four extra are D13–D16 below, found by the same
sweep run wider. A pattern sweep can undercount (divergence 12's own lesson); the
mitigation is §11 S9, a full read of both new files as a review step.

Header notes (§5) resolve the *named-reference* class ("divergence N", "the gate
table") once per file, so only sites making a now-false locational claim get edited.
Every edit is minimal and additive; none may touch a line matched by a §6.1 extract
(none does — checked per row; the gate run in S7 proves it).

Sites landing in `docs/verification.md` (pre-split CLAUDE.md line numbers):

| # | site | phrase | referent → post-split location | breaks? | remedy |
|---|---|---|---|---|---|
| V1 | L114–135 (gate table rows) | "divergence 13 draws", "divergence 3 documents", "divergences 12 and 13" (row-internal mentions) | numbered entries → open-divergences.md | resolves via header note | none (header §5.1) |
| V2 | L142 | "See divergences 12 and 13." | same | cross-file, bare | edit to "See divergences 12 and 13 in `docs/open-divergences.md`." |
| V3 | L87–89 | "this file never named it / this file already tracks" | the version-tracking prose, same fragment | no — "this file" becomes verification.md and stays true | none |
| V4 | L167 | "this file documents `./reference/validate-kernel.sh <vault>`" | the validate-kernel paragraph (~L308), same fragment | no | none |
| V5 | L199 | "an ungated prose numeral of exactly the class the divergence list below is about" | the divergence list → open-divergences.md | **BREAKS** — "below" now false | edit to "…the class the divergence list (`docs/open-divergences.md`) is about" |
| V6 | L221, L345 | fence comments "per the idiom divergence 12 uses / already uses" | numbered entry | resolves via header note | none |
| V7 | L294 | "not the one this file used to describe" | historical, same fragment | no | none |

Sites landing in `docs/open-divergences.md`:

| # | site | phrase | referent → post-split location | breaks? | remedy |
|---|---|---|---|---|---|
| D1 | L490 | "it is what the eighteen checks above enforce" | the check inventory → verification.md | **BREAKS** | edit to "the eighteen checks in `docs/verification.md` enforce" |
| D2 | L502 | "the gate's rows for those quantities anchor on a different sentence in this file" | anchored sentences (L49–50) → verification.md | **BREAKS** | edit to "…anchor on a different sentence, in `docs/verification.md`" |
| D3 | L514 | "three paragraphs above this file's own explanation" | explanation ~L530, same fragment | no | none |
| D4 | L545 | "three lines below a Verification section opening 'There are nine executable checks'" | **historical** — describes a past state of the pre-split file | judgment: leave verbatim | none — it is an archived record of drift; editing it would destroy the evidence it exists to keep (same reasoning as the 0/29 unticked boxes) |
| D5 | L670 | "a live instance of this file's own cross-cutting pattern" | cross-cutting section stays at end of this fragment | no — contingent on §8 (originals stay) | none |
| D6 | L830 | "the same substitution this file records for the kernel validator's `PASS: 15`" | PASS:15 forensics → verification.md | **BREAKS** | edit to "the same substitution `docs/verification.md` records for the kernel validator's `PASS: 15`" |
| D7 | L864 | "the proxy-for-property failure this file spends most of its length warning about" | still true of open-divergences.md | no | none |
| D8 | L887 | "per this file's own convention of recording drift" | convention enacted throughout this fragment | no | none |
| D9 | L920 | "`check-doc-claims.sh` reads a different sentence in this file for a different quantity" | rows `:308`/`:327`/`:336` read *this* file post-repoint | no — stays true, contingent on S4 | none; S7 gate run is the check |
| D10 | L1083 | "`check-prose-paths.sh` resolves every repo path in this file" | true only once this file joins SCOPE | no — contingent on S5, same commit | none |
| D11 | L1134 | "the table above was re-derived fresh" | same fragment | no | none |
| D12 | L1171 | "see the gate table near the top of this file, and divergence 13" | gate table → verification.md | **BREAKS** | edit to "see the gate table in `docs/verification.md`, and divergence 13" |
| D13 | L1302–1303 | "stated once, in the gate table near the top of this file, and gated there — see that row" | same | **BREAKS** | edit to "…in the gate table in `docs/verification.md`, and gated there — see that row" |
| D14 | L1371 | "every 'we fixed it in the generator' in this file" | those phrases live in this fragment | no | none |
| D15 | L1393 | "per this file's standing rule that building a missing gate is a gate-design question" | rule stated in the Verification forensics (→ verification.md), enacted here | **BREAKS** (weakly — the rule's statement moved) | edit to "per the repo's standing rule (`docs/verification.md`) that building a missing gate is a gate-design question" |
| D16 | L1446–1448 | "### The cross-cutting pattern / Nearly every entry above" | the entries, same fragment | no — contingent on §8 (section stays here) | none |

Kept CLAUDE.md:

| # | site | phrase | breaks? | remedy |
|---|---|---|---|---|
| K1 | L24 | "See [The backport loop](#the-backport-loop)" | no — in-file anchor, section kept | none |
| K2 | (created by the split) | the two pointer stanzas | n/a | written fresh, self-contained, no deixis (§8) |

Break tally: **7 edits** (V2, V5, D1, D2, D6, D12–13 counted as two sites one edit
each, D15). Each is verified in S3 by a positive grep on its replacement text — never
by a zero-grep alone, which passes on absence.

## 8. Promotion decision (finding 4)

Two warnings were slated for promotion into the kept file: "**None of these gates
asserts that a computed number is correct**" (L137–139, head of a paragraph chain
whose tail — "That is not a small caveat…" at L146 — continues it) and "**### The
cross-cutting pattern**" (L1446–1454, whose first sentence is "Nearly every entry
above…").

**Decision: promote freshly written pointer restatements; both originals stay
byte-identical in their fragments.** The alternative — moving the originals — fails
twice over: each is the head of a chain whose continuation stays behind ("That is not
a small caveat" would open verification.md's forensics referring to a paragraph now in
another file; "Nearly every entry above" would sit in a file with no entries above
it), and the plan's claim that promotion could be "byte-identical" cannot hold for
either, because both texts contain deixis that is false outside their fragments. A
restatement written for the kept file's context carries the warning without the
anaphora, and the originals remain intact as the archived, gated record.

**Seam requirement — stanza 1 MUST lead with a blank line; stanza 2 need not.** The four
fragments do not end symmetrically, and the kept file is the only place that matters.
Fragment A (L1–45) ends on *prose* — `"fix" something and observe no change.` — with no
trailing blank, because the blank at L46 went to the verification fragment. Fragment C
(L355–462) ends on a *blank* (L462). So in `L1–45 + stanza1 + L355–462 + stanza2`, seam 1
has no separator and seam 2 has one: if stanza 1 does not open with a blank line, L45 and
the stanza's first line render as a single jammed paragraph, while seam 2 looks fine — the
asymmetry is exactly what makes this easy to miss. Verify after S2:

```bash
# the line after L45's text must be blank in the kept file; 1 = separator present
LC_ALL=C awk '/^"fix" something and observe no change\.$/{getline; print ($0=="") ? 1 : 0; exit}' CLAUDE.md
```

The kept file's two stanzas, verbatim (the restatements are embedded in them — this is
the promotion, realized):

Replacing L46–354, in the dev-loop section:

```markdown
### Verifying changes

The verification inventory — the run fence for all eighteen executable checks, the
gate table, and the forensics on what each gate can and cannot catch — lives in
[docs/verification.md](docs/verification.md). Run the fence there before trusting any
change.

Two warnings survive here because a reader who never opens that file still needs
them. **None of the gates asserts that a computed number is correct** — a green run
means "no fence is silently broken", never "the arithmetic is right"; correctness
rests on review, and the gate set does not substitute for it. And
`reference/check-doc-claims.sh` reads `docs/verification.md`, `docs/open-divergences.md`
and this file by text anchor — do not reword a sentence that states a number without
running that gate.
```

Replacing L463–1454, after The backport loop:

```markdown
## Open divergences

The open-divergence list — every known defect, each with the command that re-derives
its numbers — lives in [docs/open-divergences.md](docs/open-divergences.md), paired
with [docs/closed-divergences.md](docs/closed-divergences.md). Do not read a number
there, or anywhere in this repo's prose, without running the command beside it.

The cross-cutting pattern, restated here because it governs every edit: nearly every
entry in that list is the same failure class — **silent failure**. Exit 0, empty
output, plausible-looking result, no error. When adding a bash block to any skill
template, assume this repo's failure mode is silence, not noise. Make the block assert
its own preconditions and say so when they fail.
```

Two deliberate heading choices, load-bearing for §11's assertions: the kept headings
are `### Verifying changes` and `## Open divergences` — **not** `### Verification` and
**not** `## Known open divergences` — so that a zero-count grep for each original
heading in CLAUDE.md is a clean duplication detector rather than something the pointer
stanzas would trip.

## 9. External references

### 9.1 `docs/superpowers/deferrals.md` — must-fix in the same commit

The file names CLAUDE.md 14 times. One is executable and goes **silently wrong** the
moment the split lands: entry 24's re-derive fence (`:573`–`:577`) contains

```
/usr/bin/grep -c 'across 11 documents' CLAUDE.md   # 1, the prose claim
```

Post-split the phrase is not in CLAUDE.md (and per §10 it will not exist anywhere),
so this returns 0 at exit 0 — the exact silent-zero this repo documents everywhere.
Fix in the same commit, and because a zero-expectation grep passes on absence, the
replacement must be a **positive** assertion on the new wording in the new file
(exact command in §10). The same entry has two more stale items found during
verification, neither in the commissioning notes: `:550` cites the phrase at "`:782`"
(it sits at L868 at `97cc6fd`), and the fence's first command carries the comment
`# 11, the live count` against a live count of 14 (16 after this branch). All three
are entry-24 body content and are rewritten together in S6.

The other 13 references are prose in deferral histories — archived records, left
verbatim (same reasoning as D4). S6 ends with an audit command proving no executable
reference to moved content remains in the file.

### 9.2 Repo-wide sweep

The §6.6 inventory covered every `.sh`/`.yml` reader. What was NOT exhaustively
audited: markdown files (e.g. `docs/closed-divergences.md`, `reference/*.md`,
`methodology/`) containing fenced *commands* that grep CLAUDE.md for content that
moves. S6 includes the sweep; the adjudication rule is: executable fence targeting
moved content → repoint in this commit; prose mention → leave. Expected result is
zero further executable sites (the known ones are all in §6.6 and §9.1), but the
expectation is asserted, not assumed.

## 10. Deferral 24: what this branch fixes, what stays deferred

**Fixed here (prose, one commit):** CLAUDE.md L868 — "so `reference/check-prose-paths.sh`
now checks it, across 11 documents, in CI" — lands in `docs/open-divergences.md`
already stale (live SCOPE is 14) and about to be doubly stale (16 after S5). Do **not**
re-mint the numeral as "fourteen" or "sixteen": that is the exact ungated-live-count
defect the deferral fired on, and this repo's precedent for it (the main-side CI count)
is numeral removal. Reword to:

> so `reference/check-prose-paths.sh` now checks it, across the documents in its
> stated SCOPE list, in CI

and let the existing re-derive command in the same entry carry the count. Additionally,
per the file's own record-drift-don't-overwrite convention, append one sentence to the
adjacent history paragraph ("It became fourteen on the branch that…"): that SCOPE
became sixteen on this branch, adding `docs/verification.md` and
`docs/open-divergences.md` when the divergence list itself moved out of CLAUDE.md.
(A numeral in a history sentence describes a past event and does not rot; only the
live-count numeral is banned.)

**Stays deferred (gate-design, CI-hardening spec):** a gate that reads the SCOPE list
size against prose claims about it — deferral 24's original subject — and divergence
17's dot-directory widening. Entry 24's body is updated in S6 to record: fired
2026-08-23, prose fixed on this branch by numeral removal, trigger retargeted at
`docs/open-divergences.md`, gate half unchanged and still owned by the CI-hardening
spec.

## 11. Ordered execution steps

Sequencing rationale: file moves first (S1–S3), reader repoints second (S4–S5),
external references third (S6), full battery last (S7). **Between S2 and S4 the
doc-claims gate is expectedly red** — 18 rows loudly failing to find their anchors is
the mechanism working; do not "fix" an intermediate state by restoring text to
CLAUDE.md. All of S1–S6 land as **one commit** (S8): every intermediate state is
either loud or covered by an assertion below, but no intermediate state should ever be
pushed.

All commands run from repo root. `LC_ALL=C` throughout; `/usr/bin/grep`, not the
shell's grep (aliased to ugrep in this environment). Quote every `$VAR` (zsh does not
word-split unquoted expansions the way bash does — a bug can hide in the difference).

**S0 — preflight.** Clean tree on the executing branch. Record baselines:

```bash
git rev-parse HEAD
LC_ALL=C wc -c CLAUDE.md                                   # 112522 at 97cc6fd; if it differs, re-measure §4 boundaries
bash reference/check-doc-claims.sh; echo "rc=$?"           # ends "DOC CLAIMS: PASS", rc=0
bash reference/check-prose-paths.sh | tail -1              # scanned 14 files, checked 310 repo paths, 0 missing
```

If any baseline is not green, stop — the split must not launder a pre-existing red.

**S1 — extract fragments and create the new files.**

```bash
LC_ALL=C sed -n '46,354p' CLAUDE.md  > "$TMPDIR/frag-ver"
LC_ALL=C sed -n '463,$p'  CLAUDE.md  > "$TMPDIR/frag-div"
LC_ALL=C wc -c "$TMPDIR/frag-ver" "$TMPDIR/frag-div"       # 29450, 73294
```

Write `docs/verification.md` = §5.1 header + blank line + `frag-ver`;
`docs/open-divergences.md` = §5.2 header + blank line + `frag-div`. Verify
byte-identity of the bodies before any §7 edit (compute the header line count `H` for
each file at execution time rather than trusting a constant):

```bash
# S is the body's FIRST line in the new file, used directly by tail -n +"$S".
# The two files differ by one line and the difference is not cosmetic:
#   verification.md  -- body starts on the blank ABOVE the heading  -> heading_line - 1
#   open-divergences -- body starts ON the heading                  -> heading_line
# A single shared formula is wrong for one of them; an earlier draft of this spec used
# tail -n +"$((H+1))" for both and reported a spurious `0a1 >` diff on verification.md.
S=$(( $(LC_ALL=C /usr/bin/grep -n '^### Verification$' docs/verification.md | head -1 | cut -d: -f1) - 1 ))
diff <(tail -n +"$S" docs/verification.md) "$TMPDIR/frag-ver" && echo VER-IDENTICAL
S=$(LC_ALL=C /usr/bin/grep -n '^## Known open divergences$' docs/open-divergences.md | head -1 | cut -d: -f1)
diff <(tail -n +"$S" docs/open-divergences.md) "$TMPDIR/frag-div" && echo DIV-IDENTICAL
```

Expected: both `IDENTICAL` lines, no diff output.

**S2 — rewrite the kept CLAUDE.md.** L1–45 verbatim, then the first §8 stanza, then
L355–462 verbatim, then the second §8 stanza. Verify:

```bash
LC_ALL=C wc -c CLAUDE.md                                              # < 13000
LC_ALL=C /usr/bin/grep -c '^### Verification$' CLAUDE.md              # 0
LC_ALL=C /usr/bin/grep -c '^## Known open divergences$' CLAUDE.md     # 0
LC_ALL=C /usr/bin/grep -c '^bash reference/check-portability' CLAUDE.md   # 0
LC_ALL=C /usr/bin/grep -c '^for s in bash zsh; do$' CLAUDE.md         # 0
LC_ALL=C /usr/bin/grep -c 'declares the 16 primitives' CLAUDE.md      # 1  (row :307 anchor retained)
LC_ALL=C /usr/bin/grep -c 'docs/verification\.md' CLAUDE.md           # >= 1
LC_ALL=C /usr/bin/grep -c 'docs/open-divergences\.md' CLAUDE.md       # >= 1
LC_ALL=C /usr/bin/grep -c '@docs/' CLAUDE.md                          # 0  (links, not imports)
```

The four zero-count lines are a **proxy** duplication detector: they test *headings*,
while every CLAIMS anchor is a *text phrase*. Run the property itself as well — for each
of the 19 rows, its field-3 `sed` program must yield a value in exactly one fragment, and
no moved row may match the kept text (verify the property, not the proxy):

```bash
LC_ALL=C sed -n '1,45p;355,462p' CLAUDE.md > "$TMPDIR/frag-kept"   # pre-split kept text
LC_ALL=C /usr/bin/grep -n '^CLAUDE\.md|' reference/check-doc-claims.sh | while IFS= read -r l; do
  rest=${l#*:}; IFS='|' read -r _f label ex _t _a <<<"$rest"
  k=$(LC_ALL=C sed -n "$ex" "$TMPDIR/frag-kept" | sort -u | /usr/bin/grep -c .)
  v=$(LC_ALL=C sed -n "$ex" "$TMPDIR/frag-ver"  | sort -u | /usr/bin/grep -c .)
  d=$(LC_ALL=C sed -n "$ex" "$TMPDIR/frag-div"  | sort -u | /usr/bin/grep -c .)
  printf '%s k=%s v=%s d=%s %s\n' "${l%%:*}" "$k" "$v" "$d" "$label"
done
# MEASURED at 97cc6fd, all 19 rows: exactly one fragment each, k+v+d=1, no ambiguity.
# k=1 for row :307 ONLY. 15 -> v, 3 -> d (:308, :327, :336), 1 stays. Matches §6.1.
# Any row other than :307 showing k=1 would pass post-split while reading the WRONG file:
# that is the single silent mode, and the heading greps above cannot see it.
```

Zero-greps here are paired with the S1 positive identity checks, the per-row table above,
and the S7 gate run; a zero-grep alone proves nothing.

**S3 — apply the seven §7 edits** (V2, V5, D1, D2, D6, D12–13, D15) to the two new
files. Verify each by positive grep on replacement text; summarized:

```bash
LC_ALL=C /usr/bin/grep -c 'divergences 12 and 13 in `docs/open-divergences\.md`' docs/verification.md   # 1
LC_ALL=C /usr/bin/grep -c 'the divergence list (`docs/open-divergences\.md`)' docs/verification.md      # 1
LC_ALL=C /usr/bin/grep -c 'docs/verification\.md' docs/open-divergences.md                              # 5 = D1 + D2 + D6 + D12/13 + D15
```

The `5` is a decomposition, stated as a sum; if an edit is dropped or doubled the
total moves and fails loudly. (The §5.2 header also names `docs/verification.md` —
run the grep against the body only, i.e. `tail -n +"$((H+1))"`, or expect 6+ and say
which; pick at execution time and record the choice in the commit message.)

**S4 — repoint `reference/check-doc-claims.sh`.** Four mechanisms:

1. 18 CLAIMS rows: field 1 per the §6.1 table (row `:307` untouched).
2. `truth_fence_suites()`: both `CLAUDE.md` occurrences → `docs/verification.md`.
3. `:426` `check_list_len` file argument → `docs/verification.md`.
4. Uniqueness block: both `CLAUDE.md` occurrences → `docs/open-divergences.md`.

```bash
LC_ALL=C /usr/bin/grep -c '^CLAUDE\.md|' reference/check-doc-claims.sh              # 1  (row :307 only)
LC_ALL=C /usr/bin/grep -c '^docs/verification\.md|' reference/check-doc-claims.sh   # 15
LC_ALL=C /usr/bin/grep -c '^docs/open-divergences\.md|' reference/check-doc-claims.sh  # 3
LC_ALL=C sed -n '/^truth_fence_suites()/,/^}/p' reference/check-doc-claims.sh | /usr/bin/grep -c 'CLAUDE\.md'   # 0
LC_ALL=C /usr/bin/grep -n 'CLAUDE\.md' reference/check-doc-claims.sh
# adjudicate every remaining hit by eye: expected = the one row line + comments only
```

**S5 — widen `reference/check-prose-paths.sh` SCOPE** by the two new files:

```bash
LC_ALL=C awk '/^SCOPE="/{f=1;next} /^"/{f=0} f&&NF' reference/check-prose-paths.sh | /usr/bin/grep -c .   # 16
```

**S6 — external references.** Rewrite deferral 24's body per §10 (fired-date, prose
fix, retargeted trigger, gate half still deferred); fix `:550`'s `:782` citation and
the `# 11, the live count` comment; replace the silent-zero grep with a positive
assertion on the new wording. Apply the §10 reword at the (moved) L868 sentence and
append the SCOPE-history sentence in `docs/open-divergences.md`. Then the sweep:

```bash
LC_ALL=C /usr/bin/grep -c 'across the documents in its stated SCOPE list' docs/open-divergences.md   # 1  (positive, not a zero-grep)
LC_ALL=C /usr/bin/grep -c 'across 11 documents' docs/open-divergences.md docs/superpowers/deferrals.md | /usr/bin/grep -v ':0' | /usr/bin/grep -c .   # 0 — paired with the positive line above
LC_ALL=C /usr/bin/grep -rn 'CLAUDE\.md' docs/*.md reference/*.md README.md CONTRIBUTING.md | /usr/bin/grep -v 'closed-divergences\|superpowers'
# adjudicate: executable fence targeting moved content -> repoint now; prose -> leave.
```

**S7 — full battery.** This is where every loud mechanism actually fires or passes:

```bash
bash reference/check-doc-claims.sh; echo "rc=$?"
#   every repointed row prints ok; divergence line reports 14 entries, all distinct;
#   ends "DOC CLAIMS: PASS", rc=0
bash reference/test/check-doc-claims.test.sh          # 13/13 (runs the real repointed script; ~100s x3)
bash reference/check-prose-paths.sh | tail -1
#   scanned 16 files, checked N repo paths, 0 missing — with N >= 310; a smaller N
#   at 16 files means a new file was listed but not parsed: stop and diagnose
bash reference/check-portability.sh; echo "rc=$?"     # rc=0 (root marker + AGENTS.md symlink both still satisfied)
LC_ALL=C wc -c CLAUDE.md                              # < 13000, and < 40000 (the property)
```

Then the remaining CI suites (`link-extraction` … `moc-sync`, both shells) — no
mechanism in them reads CLAUDE.md (§6.6), so this is insurance, and CI reruns it on
push regardless.

**S8 — one commit.** All of S1–S6. Message records the split, the reader repoints, the
S3 grep choice from above, and the deferral-24 fix. No `Co-Authored-By` trailer
(Rule 14, which overrides the harness instruction to add one).

**S9 — manual review, not a gate.** (a) Read both new files top to bottom once,
hunting deixis the §7 sweep patterns missed — a synonym escapes a pattern, per
divergence 12. (b) Open a fresh Claude Code session in the repo and confirm the
injected CLAUDE.md is the ~11.5k kept file in full — this is the only direct test of
the property the split exists for; `wc -c` is its proxy (verify the property, not the
proxy).

## 12. Rollback

The split is one commit touching six files (`CLAUDE.md`, two new `docs/` files,
`check-doc-claims.sh`, `check-prose-paths.sh`, `deferrals.md`). Rollback is
`git revert <sha>` — content and every reader return together; rerun the S0 baselines
to confirm (expect `112522`, `scanned 14 files … 310`, `DOC CLAIMS: PASS`). There is
no generated artifact, cache, or installed-plugin copy that reads this repo's
CLAUDE.md, so no cleanup beyond the revert. Partial-state analysis, for someone
interrupted mid-execution: every possible half-done state is loud (unrepointed row →
anchor-not-found; unrepointed truth fn → truth-produced-nothing; unrepointed `:426` →
extracted-EMPTY-list; unrepointed uniqueness awk → zero-headers; SCOPE typo →
in-scope-file-missing ERROR) **except duplication and the SCOPE omission**, which are
exactly the two states S2's zero-greps and S7's banner assertion exist to catch.

## 13. What this spec does not cover (adversarial)

- **The `check_list_len` coincidence hole** (§6.3): a wrong-membership fence matching
  the anchor whose `reference/` line count coincidentally equals truth−1 passes.
  Pre-existing, not widened here, accepted.
- **The anaphora table is a sweep, not a proof.** §7's patterns can miss a deictic
  phrase spelled differently; S9(a) is review, not enforcement. Class size found: 24;
  class size that exists: unknown.
- **The 40k auto-load behavior itself is unverified harness behavior.** The spec
  assumes `docs/*.md` are not auto-injected and that the kept file is injected whole
  once under the limit; S9(b) observes it once, nothing gates it.
- **References outside this repo.** The field vault's patch-anchor checker already
  FAILs on upstream text drift; this split will trip more of its anchors, and memory
  files and in-flight branches cite CLAUDE.md line numbers that all rot at once.
  Out of scope; expect the vault's SessionStart warning to get noisier until its
  patches are re-anchored.
- **Sessions in flight** carry the old injected CLAUDE.md snapshot (it is captured at
  session start); nothing here can fix that, and prose-drift reports from such a
  session must re-read from disk.
- **Prose numerals inside the moved fragments** remain exactly as ungated (or gated)
  as they were; the split neither fixes nor worsens them, except the one §10 numeral.
- **The S3 body-vs-header grep ambiguity** is resolved at execution time by decision,
  not by this spec — recorded in the commit message either way.

## Deferrals

- Gate that reads `check-prose-paths.sh` SCOPE size against prose claims (deferral
  24's gate half) — remains recorded in `docs/superpowers/deferrals.md` entry 24,
  owned by the CI-hardening spec (`docs/superpowers/plans/archive/2026-08-04-ci-hardening.md`
  lineage).
- `check-prose-paths.sh` dot-directory widening (divergence 17) — unchanged, recorded
  in `docs/open-divergences.md` entry 17, owned by the CI-hardening spec.
- The 13 non-executable CLAUDE.md mentions in `docs/superpowers/deferrals.md` left as
  historical prose — recorded in this spec, §9.1.
- Kept-file growth re-check (nothing warns when CLAUDE.md approaches 40k again) —
  recorded in this spec, §4; a size assertion in CI is a gate-design question for the
  CI-hardening spec.
