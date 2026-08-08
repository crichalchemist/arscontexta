# Spec — the CodeRabbit PR #3 residue

## What this is

PR #3 (`fix/spec-h-enforcement-gap` → `crichalchemist:main`, carrying Spec H and Spec I) drew a
26-comment ASSERTIVE-profile review from `coderabbitai`. Seven independent, read-only investigations
verified every comment against the actual current code — not the review text alone — before any of
it was acted on. Two comments were fixed directly on the branch (`e68ba7c`) after mutation-testing.
A third round found and fixed a comment-destruction regression from CodeRabbit's own earlier
automated commit on that branch (`f199e43`), plus three more comments judged small and squarely
owned by this branch (`57c8657`).

This spec is what's left: real findings that need design work, span files this branch didn't touch,
or change behavior in a way that needs its own verification pass rather than a same-PR patch. Each
item below cites the investigating agent's verdict verbatim where it matters, because two of the
seven investigations found CodeRabbit citing line ranges that had already moved, and one found
CodeRabbit's own proposed remedy would introduce a new bug — this spec is not "implement what
CodeRabbit said," it is "here is what investigation confirmed, and here is the fix investigation
actually supports."

## Why a new spec, not an amendment to an existing one

The obvious destination — `docs/superpowers/specs/2026-08-04-ci-hardening-design.md`, and its
matching plan — does not accept new items: the plan is complete (22/22 checked) and the design spec
is written as a closed document (a "Success criteria" section, an "Explicitly out of scope" section,
no open-items slot). Retrofitting either would repeat the exact anti-pattern this repo's own
`CLAUDE.md` names under divergence 10: "a record that does not ship is not a record," and — more
specifically — silently rewriting a completed document to match something discovered later is the
behavior the `## Deferrals` convention exists to replace. A fresh dated plan+spec pair is this
repo's established response to exactly this situation (see `2026-08-05-generator-vault-enforcement-
gap` and `2026-08-06-upgrade-consultation-blind-spot`, both filed the same way, for the same reason).

## The findings

Grouped by file/module. Each item states the verdict from its investigation, the concrete failure
mode, and why the minimal fix is not simply "do what CodeRabbit said."

### 1. `generators/features/graph-analysis.md` (×2) and `schema.md` (×1) — silent scan-failure in the tension-recipe pipelines

**Verdict: real bug; CodeRabbit's remedy (`set -o pipefail`) is mechanically wrong for this shape.**

All three recipes read `list_notes_by_field {DOMAIN:notes} type tension | while IFS= read -r f; do
s=$(frontmatter_field "$f" status); [ "$s" = "pending" ] || [ "$s" = "open" ] && echo "$f"; done`.
`list_notes_by_field` deliberately returns 1 and writes to stderr on a traversal failure — the whole
point of its touch-file/rc-check machinery, per its own header, is to make failures visible. Piping
it into `while read` discards that: without `pipefail`, the pipeline's exit status is the `while`
loop's, so a failed scan reads as "0 matching tensions," indistinguishable from a healthy empty
result. `reference/check-doc-claims.sh:518-521` pins these three sites by exact count
(`TENSION_RECIPES=3`), confirming they're a known, tracked set — just not checked for this mode.

But `set -o pipefail` alone is empirically wrong: the loop body's last statement is `[ "$s" =
"pending" ] || [ "$s" = "open" ] && echo "$f"`, and a `while` loop's own exit status is that of the
last command run in its body. Verified: when the last file scanned is neither `pending` nor `open`,
the pipeline returns 1 on a perfectly healthy, complete scan — no failure at all. `pipefail` bolted
onto the existing shape would introduce a **new** false failure on totally successful runs, coupled
to data content rather than to `list_notes_by_field`'s success.

The established, working idiom already exists in this exact codebase — `skill-sources/
rethink/SKILL.md:180-186` and `skills/architect/SKILL.md:271-274` both do
`OBS_PENDING=$(list_notes_by_field ...) || { echo "error: ..." >&2; exit/return 1; }` before any
further processing, precisely because this hazard is understood elsewhere. The fix is restructuring
these three recipes to that pattern — capture output via `$(...)`, check exit status explicitly,
then iterate the captured text — not adding a flag to the existing pipe shape.

### 2. `generators/features/self-evolution.md`, `generators/claude-md.md`, `skill-sources/rethink/SKILL.md` — "pending" alone in threshold triggers, contradicting the rule stated in the same file

**Verdict: real bug; CodeRabbit's cited line range is stale — the fix landed elsewhere already.**

`self-evolution.md:96-117` (observations) and `:227-249` (tensions) — CodeRabbit's cited range —
are already fully correct: both explicitly state "Counting open work means matching BOTH `pending`
and `open`. Matching one alone reads zero on a vault that only uses the other, and the failure is
silent." These sections were fixed by earlier commits already on this branch (`e54362d`, `9bffdf7`,
`8bfbab1`, `cbb520b`).

The file contradicts its own rule a short distance later: `self-evolution.md:191-192` ("10+ pending
observations" / "5+ pending tensions" trigger the threshold) and `:194` use "pending" alone — the
exact mistake the doc warns against 70+ lines earlier in the same file. `generators/claude-md.md:
242-245` has the identical problem. `blocked` isn't named in either threshold line, so adding "or
open" carries no risk of also counting `blocked` — that exclusion is correct and lives elsewhere,
undisturbed.

A third site carries the same stale wording and is in scope for consistency even though CodeRabbit
never cited it: `skill-sources/rethink/SKILL.md:21-22` ("number of pending observations/tensions
before suggesting rethink"). Fixing only the two CodeRabbit-cited files would leave this third site
drifted from the two others in the same sentence.

### 3. `generators/features/self-evolution.md` — `/rethink`'s four-action list understates its own disposition set

**Verdict: stale doc, not a live bug; CodeRabbit's own two proposed remedies are both wrong.**

Runtime behavior is correct — `skill-sources/rethink/SKILL.md`'s actual triage table has six
dispositions (PROMOTE, IMPLEMENT, METHODOLOGY, ARCHIVE, BLOCKED, KEEP PENDING) and correctly handles
tension-specific outcomes. CodeRabbit's cited range, `self-evolution.md:227-249`, is itself already
correct and complete — the full Tension Status lifecycle section. The actual incoherence is ~30
lines earlier, at `:194-198`: the "Operational Learning Loop" section claims `/rethink` "decides one
of four actions" (PROMOTE, IMPLEMENT, ARCHIVE, KEEP PENDING), omitting METHODOLOGY and BLOCKED.

CodeRabbit's two suggested remedies are themselves defective: no `/rethink` disposition ever sets
`status: resolved` directly (`resolved_by:` is added in a separate, later architect-proposal phase,
not by the six-item triage table), so "expand the four-action list to show tensions becoming
resolved via the listed actions" would introduce a new false claim. "Scope the list to observations"
doesn't fully fix it either — METHODOLOGY applies to observations too and is also missing from the
four-item list. **This is an authorial/scoping call, not a mechanical correction** — the task below
states both options and requires a decision, not a specific text.

### 4. `reference/validate-kernel.sh` — directory-discovery failures read identical to genuinely-absent directories

**Verdict: real gap, genuinely large — multi-function surgery plus new fixture infrastructure.**

`resolve_ops_dir_name` (lines 69-75) and `resolve_ops_dir` (78-97) both pipe `find ... 2>/dev/null |
head -1`, discarding `find`'s own exit status and stderr — a `find` that errors partway through the
walk (permission denied on an intermediate directory) is indistinguishable from one that legitimately
completed and found nothing. Both read as "not present," and the function falls through to `return
1` — identical to the genuinely-absent case. `resolve_note_dirs` (241-278) has the same pattern
three times (manifest `find`, config `find`, top-level shape scan). Downstream, C1's loop (899-920)
does `d=$(resolve_ops_dir "$VAULT" "$kind") || continue` — if resolution silently fails for all four
(kind, status) pairs, `c1_pairs` stays 0 and C1 reports a soft **WARN** ("self-evolution not enabled")
even though the real cause could be an I/O error, not absence.

This is a confirmed instance of this repo's own documented "silent failure" cross-cutting pattern.
It is not covered by primitives 1, 8, or 10 — those run independent, self-contained checks and never
call these resolvers; only primitive 2 (dangling-link check), primitive 12, and C1 consume them. The
codebase already applies the *opposite, correct* discipline one layer downstream (`list_notes_by_
field` captures its `find` return code and refuses to report a count on an unreadable directory; C1
propagates that as a hard FAIL, not a WARN) — this finding is that discipline not yet reaching the
resolvers that sit above it.

**Why this is genuinely large, not a quick patch:** restructuring ~6 `find` call sites across 3
functions to capture exit status without losing bash/zsh portability (ruling out bash-only `pipefail`
idioms this script explicitly avoids elsewhere); introducing a third return-code state (resolver
error vs. genuinely-absent vs. found) and threading it through every caller — the C1 loop (4 call
sites), primitive 12's two `has_*_dir` checks, and primitive 2's existing two-state `resolve_rc`
branch (which would need a third); and a new fixture combining a vocabulary-declared custom ops-dir
name with an unreadable path, plus a root-aware SKIP guard matching the existing pattern in
`reference/test/kernel-note-dirs.test.sh` (~555-587), asserting C1 fails (not warns) on it.

### 5. `reference/check-doc-claims.sh` — TENSION validation can silently validate nothing

**Verdict: real bug matching the silent-failure pattern; not hypothetical — this exact failure shape has already shipped once.**

Two independent gaps in the TENSION validation block (~lines 514-549), both currently masked by
favorable data: (a) `tenum=$(...| head -1 | enum_values)` takes only the first matching declaration
with no check that exactly one exists — unlike the sibling NOTE-enum check five lines above it,
which explicitly guards on declaration count. Only one line currently matches the anchor, so this is
harmless today, but nothing enforces it stays that way. (b) The per-recipe extraction reads exactly
one line of lookahead (`follow=$(sed -n "$((ln + 1))p" "$f")`); if that line contains zero `"$s" =
"..."` comparisons, the loop simply doesn't execute, `undeclared` stays empty, and the recipe reports
"ok...all values declared" without having checked anything. The file's own comments document that
this detector was already rewritten once because the recipe shape changed, and a prior version of
this exact check already shipped a real defect from an analogous shape drift ("three recipes matched
`^status: pending` alone after `pending` was briefly removed from the enum"). An ordinary
reformatting that moves the comparison one line further reproduces that failure mode today, silently.

Minimal fix, in the file's own idiom: mirror the `NOTE_ENUM_DECLS` guard for `tenum` (count matches,
require exactly 1, else error); inside the per-recipe loop, treat a zero-value extraction as an
error rather than a fall-through "ok". No test file currently exists for this script — this task
adds mutation fixtures alongside the fix, per this repo's own "assert every mutation applied" rule.

### 6. `reference/check-portability.sh` — three related gaps in the frontmatter-parsing gate itself

**Verdict: one real bug (currently latent), two lower-severity hardening items — but all three sit inside the file whose whole purpose is catching exactly this failure class.**

- **`FM_SCAN`/`fm_scan_files` (~698-701): real bug, currently latent.** `find`'s stderr is discarded
  and its exit status is never captured, despite this exact file containing an established,
  documented idiom for precisely this (`scan_or_die()`, plus a comment on why exit codes must be
  checked in the parent shell). Verified all nine `FM_SCAN` roots exist in this checkout today, so
  the gate is not blind right now — but a bad root (renamed, permission-denied) would silently
  produce a partial file list with zero signal, and any new hand-rolled-frontmatter violation under
  the broken root would never be flagged.
- **`fm_hits_in` (~679-685): real, low-severity.** Returns `0` for both "clean file" and "unreadable
  file," with no `scan_or_die`-style discriminator this file otherwise uses consistently. The
  reachable failure mode: an *allowlisted* file that becomes unreadable gets misdiagnosed by the
  staleness pass (`fm_stale`) as "converted, drop the entry" — wrong diagnosis, but the check still
  correctly fails. A brand-new violation in an unreadable, non-allowlisted file (fully silent) needs
  two coincident unusual conditions a clean checkout won't produce.
- **Branch ordering around `fm_present`/`fm_total`/`fm_stale` (~765-777): real, low-severity, message-correctness only.** The "scan did not run" branch can fire before a populated `fm_stale` gets
  printed, if every remaining allowlisted site is converted in one branch (`fm_total` reads 0 while
  `fm_present` stays positive) — both branches still call `red()` and fail the check, just with the
  wrong diagnosis. Reordering to check `fm_stale` first is safe: a genuinely broken scan leaves
  `fm_stale` empty too, since it reads `$ROOT` directly rather than through the scan.

### 7. `reference/lib/frontmatter.sh` — variable-scoping hygiene and duplicated find-and-check logic

**Verdict: code-quality only, no behavior change, no version bump needed.**

`list_notes_by_field` and `count_notes_missing_field` both assign `_fm_list`/`_fm_find_rc` without
declaring them `local` — a genuine scoping gap in a library that otherwise cares a great deal about
this exact class of bug. Zero external callers reference these names today, and the one in-library
caller (`count_notes_by_field`) already isolates the leak inside a subshell — so exposure is
currently nil, but the hygiene gap is real. `FRONTMATTER_VERSION=3`'s own header scopes bumps to
behavior changes (delimiter rules, key matching, quote stripping, recursion semantics); adding
`local` to two private variables changes no documented output for any conforming caller and does not
qualify.

The duplicated `find -H ...; rc=$?` block (present near-identically at two sites) is a reasonable
extraction target into a shared `_fm_find_md` helper. **Hazard for whoever implements it:** the
caller must write `_fm_list=$(_fm_find_md "$dir"); rc=$?` as two statements — never `local
x=$(_fm_find_md "$dir")`, which swallows the command substitution's exit status. This file already
documents this exact trap at its `count_notes_by_field` comment (~249-251); a refactor that
reintroduces it while fixing the scoping gap would be a net loss.

### 8. `platforms/claude-code/hooks/write-validate.sh.template` — three gaps, one of them currently masked by another

**Verdict: all three real; verified against the non-template sibling hook, which already diagnoses two of them in its own comments.**

- **SCOPE LIMIT doc is incomplete.** States only the `hooks.json` tool-matcher constraint. Omits
  the second, more consequential one: the case filter at line 25 uses an unsubstituted `{{NOTES_DIR:
  -notes}}/*` marker — plain text, not real shell parameter expansion — so the guard currently
  requires a literal path prefix of `{{NOTES_DIR:-notes}}/`, which no real note path has, and never
  fires on anything. The non-template hook's own comments (49-70) already diagnose this nearly
  verbatim, including that an earlier revision of that same comment over-credited the template for a
  fix it doesn't deliver.
- **False "only two numbers" claim.** The template's PREV_BYTES/NOW_BYTES comment says these are
  "the only two numbers in this check" — false; there's a third, separate link-loss condition
  (`NOW_LINKS -lt PREV_LINKS`, no floor, by design). The non-template hook's mirrored comment already
  retracts this exact sentence.
- **Missing FILE-existence guard, reachable once the SCOPE LIMIT bug above is fixed.** The
  non-template hook exits early on an empty or non-existent `$FILE` before any git/size logic runs;
  the template has no equivalent. Traced: an empty `FILE` is incidentally caught today by the (broken)
  case filter; a non-empty `FILE` that no longer exists on disk is not caught by anything, and
  reaches `NOW_BYTES=$(wc -c < "$FILE")`, which fails, leaves `NOW_BYTES=""`, and — because bash
  treats an empty variable as `0` in arithmetic context — produces a malformed warning rather than a
  crash or a clean exit. **This code path is unreachable today** because of the SCOPE LIMIT bug, so
  fixing the guard here should happen in the same task as fixing the scope-limit doc, not before it —
  fixing this alone, while the case filter still matches nothing, verifies nothing live.

### 9. `skill-sources/rethink/SKILL.md` — blocked tensions are dropped from discovery, not just the count

**Verdict: real gap, behavior change requiring its own verification.**

The tension status enum (`pending | open | resolved | dissolved | promoted | implemented | archived
| blocked`) added `blocked` specifically so a tension "real but blocked on work outside this system"
stays visible rather than archived — the SKILL.md's own prose (206, 223-227) states this rationale.
But Phase 1a's discovery (`list_open_items() { list_notes_by_field "$1" status pending open; }`) does
exact-value matching against only `pending`/`open` — a `status: blocked` tension matches neither, and
is filtered out of `TENSION_PENDING` entirely, not merely excluded from `TENSION_COUNT` as intended.
The consequence: the documented instruction "revisit when the blocker clears" has no mechanism behind
it — a blocked tension becomes invisible to every future `/rethink` gather step, and nothing ever
re-surfaces it. This gap sits outside `check-doc-claims.sh`'s tension-recipe validation (a different
tree entirely — the plugin's own dogfooded skill, not a `generators/` template), so no existing gate
would catch a regression here.

Minimal fix: match `blocked` too in `list_open_items` so blocked tensions populate `TENSION_PENDING`,
then subtract blocked-status entries when computing `TENSION_COUNT` specifically, so the existing
threshold-counting rule still holds. **This changes what a real, consumed variable computes** — it
needs a fixture and a verification pass, not a one-line patch taken on faith.

### 10. `docs/superpowers/plans/2026-08-05-generator-vault-enforcement-gap.md` — its own acceptance-script mechanics, not its recorded content

**Verdict: real, worth fixing; does not conflict with this repo's "don't retrofit completed plans" convention, because the target is the verification script, not the decision record.**

This repo's convention (`CONTRIBUTING.md`, and `CLAUDE.md`'s divergence 10) protects *decision and
design content* — what was decided, deferred, or shipped — from silent retroactive rewriting. It says
nothing about a plan's embedded verification-script mechanics being permanently frozen once the plan
completes. Three independent issues, confirmed by running the current heuristics against the plan's
own now-populated content:

- **The Deferrals validation block (~162-173) is a crude substring heuristic, not structural
  validation.** Run against the plan's real Deferrals table, it fails on 15 lines of legitimate
  prose/headers/separators (no `.md`/`.sh`/`.yaml`/`/` token), while also flagging two legitimate
  non-path "Landed in" references the section's own rules sanction. It never parses table rows or
  runs `git ls-files --error-unmatch` on anything, despite claiming to.
- **Acceptance commands (~108-112) contain a literal, uncopy-pasteable `<suite>` placeholder.** The
  concrete suite it should name already exists: `reference/test/kernel-note-dirs.test.sh` (the actual
  C1 assertions, lines 375-423). Separately, piping the run through `| tail -1` discards the real
  exit status — this same plan's own Global Constraints name this exact class of defect.
- **Six "Done when" fenced blocks (starting ~60-63) violate markdownlint MD031** (no blank line
  before the fence). No CI in this repo currently runs markdownlint, so this is cosmetic and
  low-priority, but free to fix alongside the other two while the file is open. **NOT SHIPPED —
  claim verified false against the target file** (see `a138126`'s commit message and the plan's
  own Step 4 annotation): exactly 5 "Done when" blocks exist, not 6, and none violate MD031.

**Explicitly not in scope for this task:** the canonical-name resolver contract wording CodeRabbit
also flagged in this plan and its design spec (lines 44-52 / 59-61) is **already moot** — the shipped
`resolve_canonical_name()` documents a mid-implementation pivot away from that exact text via its own
inline comment, and editing the plan/spec prose to match now would be the retroactive retcon this
spec's own opening section warns against. Leave it; the correct, current contract lives in the
shipped code, which is the only place it needs to.

## Deliberately not in scope

- **Any change to `docs/superpowers/plans/2026-08-04-ci-hardening.md` or its design spec.** Both are
  closed, completed records — this spec's whole reason for existing is to avoid retrofitting them.
- **CodeRabbit's docstring-bot behavior itself.** `f199e43`'s comment destruction was already fixed
  directly on `fix/spec-h-enforcement-gap` (`57c8657`). Whether to disable or reconfigure that bot's
  docstring-generation behavior going forward is a tooling/process decision for the repo owner, not
  a code-level fix this spec's tasks can make.
- **A CI gate for "prose comment survives an automated docstring pass."** Real gap this incident
  exposed, but building a detector for it is a distinct piece of gate-authoring work with its own
  design questions (what counts as "destroyed" vs. "improved"?), not a natural extension of any task
  below.

## Success criteria

- Each of the ten findings above either has a shipped fix with a mutation-proved test, or (finding 3)
  an explicit authorial decision recorded in the plan, or (finding 4) is explicitly scoped as its own
  follow-up rather than attempted inline.
- No task in the plan that follows edits `docs/superpowers/plans/2026-08-04-ci-hardening.md` or its
  design spec.
- Every fix that changes a counted, gated quantity (assertion totals, allowlist counts) updates every
  document that declares that count, verified by `reference/check-doc-claims.sh` passing clean —
  this spec's own residue is proof of how easily that drifts: two of the fixes already landed on this
  branch produced exactly this kind of drift and were caught only by re-running the gate.

## Open question for the plan that follows this spec

Whether finding 9 (rethink's blocked-tension handling) and finding 2 (the pending/open threshold fix,
which also touches `rethink/SKILL.md:21-22`) should be one task or two — they touch the same file for
related but distinct reasons (a filtering bug vs. a wording drift). Recommend deciding in the plan
itself, per this repo's own norm of separating what a spec decides from what a plan executes.
