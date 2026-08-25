# Rot-prone prose numerals: gate design

Written on `develop` at 2026-08-24. Every number below was re-derived on that tree with the
command shown beside it; none is quoted from prose, including the prose this design is about.

**Scope.** A mechanism that catches prose numerals which silently become false when the thing
they count changes — designed against two counts that have already rotted, plus deferral #24's
SCOPE count. Out of scope: correcting the numbers themselves (another spec's task 1), and any
content change to `platforms/`, `generators/`, or `skill-sources/`.

---

## The defect, measured

`reference/skill-authoring.md` §2 states `verify` 27 against 146, `validate` 5 against 60,
`reflect` 121 against 203. `CLAUDE.md` states 146 markers in `verify` where `skill-sources`
has 27. The live tree:

```bash
# Substituting awk for the ```text block's `wc -l`: this environment's rtk wrapper
# fabricates a bare 0 when two wc calls share a line — a live instrument failure,
# not a hypothetical. Same PAT, same files, different counter.
PAT='{vocabulary\.[a-z_]*}\|{config\.[a-z_]*}\|{DOMAIN:[^}]*}'
for p in verify validate reflect; do
  s=$(/usr/bin/grep -o "$PAT" "skill-sources/$p/SKILL.md" | awk 'END{print NR+0}')
  b=$(/usr/bin/grep -o "$PAT" "platforms/shared/skill-blocks/$p.md" | awk 'END{print NR+0}')
  printf '%s source=%s blocks=%s\n' "$p" "$s" "$b"
done
# verify   source=30  blocks=146   — prose says 27: ROTTED
# validate source=5   blocks=60    — still correct
# reflect  source=123 blocks=203   — prose says 121: ROTTED
```

The asymmetry is the design input. Every `blocks=` figure is still correct because
`platforms/shared/skill-blocks/` is cksum-frozen by `check-portability.sh` check 4 and
*cannot* drift. Every `source=` figure is a claim about the live tree, and two of three have
rotted. A numeral rots exactly when its referent can move; the frozen side proves the
counting method is stable and the live side proves nothing reads the sentence.

The third instance is deferral #24 (`docs/superpowers/deferrals.md`), the registered entry
for this defect class: `check-prose-paths.sh`'s SCOPE count went 9 → 11 → 14 → 16 while its
prose numeral was hand-corrected, went stale twice anyway, and was finally *removed* — the
surviving numeral is the `# 16, the live count` annotation inside the entry's own re-derive
block, which nothing reads either:

```bash
awk '/^SCOPE="/{f=1;next} /^"/{f=0} f&&NF' reference/check-prose-paths.sh | /usr/bin/grep -c .   # 16
```

---

## Why `check-doc-claims.sh` does not read these numbers

`reference/check-doc-claims.sh` is the existing numeral gate, and it is green over both
rotted counts — measured, not inferred:

```bash
time bash reference/check-doc-claims.sh    # DOC CLAIMS: PASS ... 2m25.95s wall, Darwin/SD-card
```

Three reasons, in descending order of design weight:

1. **The CLAIMS table is a stated list, not a discovery scan** — its header says so on every
   run ("a number this file does not name is not checked"). Nobody registered rows for the
   §2 sentence or the CLAUDE.md sentence, so the gate is behaving exactly as documented. The
   gap is registration, not mechanism.
2. **No truth source exists for placeholder-marker counts.** Every claim row names a truth
   function; the closest existing ones count check headers, allowlist lines, CI steps. The
   PAT count was never wrapped as one.
3. **CLAUDE.md's 27 is unregistrable as worded.** The claim extraction is line-based `sed`,
   and the sentence hard-wraps: line 123 ends `…\`skill-sources\` has` and the `27.` opens
   line 124. A row registered against that sentence today would return rc 2 (anchor not
   found) until the sentence is reflowed. This is not a corner case — it is the
   grepping-hard-wrapped-prose failure the repo has already met elsewhere, and it becomes a
   registration precondition below.

So the question the brief poses — extend or build beside — is really: is the CLAIMS registry
the right mechanism, and if so, what is missing? Deferral #24 already answered the first
half in its own Reopens-if clause: *"`check-doc-claims.sh` gains a mechanism generic enough
to register an arbitrary computed-count-vs-prose-numeral pair without a bespoke assertion,
at which point this pair should be its first user."* This design is that mechanism.

---

## Extend, not build beside — the accounting

A new gate file or CI step is not free here; `check-doc-claims.sh` gates the repo's own
inventory numbers, so adding one moves them all:

| If the design added… | It moves | Where the number is gated |
|---|---|---|
| a new `reference/check-*.sh` | 18 executable checks → 19 | `truth_check_files` reads two word-form sites (`docs/verification.md`, `CONTRIBUTING.md`) plus two `check_list_len` list assertions whose fences must gain the file |
| a new CI step | 32 step items → 33 | `truth_ci_steps` reads two word-form sites in `CONTRIBUTING.md`, plus the `# 32` row in `docs/open-divergences.md` |
| a new CI-run check | 16 in CI → 17 | `truth_ci_run_checks` reads two word-form sites |

```bash
ls reference/check-*.sh reference/test/*.test.sh reference/validate-kernel.sh | /usr/bin/grep -c .   # 18
/usr/bin/grep -c '^      - ' .github/workflows/checks.yml                                            # 32
/usr/bin/grep -oE 'run: (bash|zsh) reference/(check-[a-z-]+\.sh|test/[a-z-]+\.test\.sh|validate-kernel\.sh)' \
  .github/workflows/checks.yml | sed 's/.*reference\///' | sort -u | /usr/bin/grep -c .              # 16
```

Extending the CLAIMS table moves **none of these**: no new file, no new step, and no prose
counts the number of CLAIMS rows (verified: `CLAIMS table` and `claim row` appear in no
gated document). The extension rides the existing CI step at `.github/workflows/checks.yml:63`
(`run: bash reference/check-doc-claims.sh`) under the existing `timeout-minutes: 20`.

Building beside would also duplicate machinery the gate already has and that this problem
needs: the rc-2/rc-1 distinction (anchor moved vs. claim stale), empty-truth-is-error, the
multi-value MISMATCH on an over-matching extract, word-form claims, and a positive-control
convention. Every one of those exists because a prior numeral gate shipped without it and
failed silently.

---

## The three candidate shapes, and the pick

**Shape 1 — self-describing numerals** (prose carries its re-derive command beside the
number; a gate parses the convention and executes each). This is the deferrals-file
convention, and `docs/superpowers/next-sprints.md` sketches the gate: run every entry's
```bash re-derive block, flag entries whose answer changed, drain like
`fence-isolation.test.sh`'s allowlist. The sketch does not generalize to prose numerals, for
four reasons:

- **Executing commands parsed out of prose is a discovery scan with an open execution
  surface.** The blocks were written against the tree of their day; four deferral entries
  are already asserting things that are no longer true, and next-sprints itself warns that
  acting on an underived entry is "a plan written against a false premise". A gate that runs
  them verbatim inherits every stale command and every instrument hazard the prose was
  written under — the §2 block's own multi-`wc` line is corrupted by this environment's rtk
  wrapper *today*.
- **The expected values do not parse uniformly.** `# 16, the live count`, `# 0: gate STILL
  never reads this file's name`, `# 5 = 4 + 1` — comment shapes are heterogeneous by
  design, because they carry reasoning, not just numbers.
- **The repo's fence semantics have no slot for it.** The fence gate executes ```bash
  fences against a *generated-vault fixture*; §2's block is ```text *precisely so it is not
  executed* (§5 states this), and ```text is also where deliberate counter-examples live.
  A third semantic — "executable, but at repo root, in CI" — would need new fence
  discipline across every prose file before the gate could trust a single block.
- **It answers a different question.** "Is this backlog entry still true" is the
  deferral-drain gate, and it stays with the CI-hardening spec where next-sprints routed
  it. This design takes exactly one numeral from that file (#24's `# 16`) as a declared
  claim, without executing the block it sits in.

What survives from Shape 1: the *pairing* of number and re-derivation. The CLAIMS row is
that pairing with the execution surface closed — the command lives in the gate as a named
truth function, the prose keeps the number, and the row binds them.

**Shape 2 — single source of truth** (numbers live in one generated file; prose references
it; the gate regenerates and diffs). Rejected. It inverts the repo's governing idiom —
"re-derive a number, never quote one", stated in `check-doc-claims.sh`'s own comments as the
reason a previous claim row was *removed* — by making quotation the mechanism. It adds a
generation step to a repo whose CLAUDE.md opens with "there is no build". And it cannot
reach a number embedded mid-sentence ("the gap is widest exactly where `skill-sources` is
sparsest — 27 against 146") without template syntax in prose, which is a bigger convention
change than the one Shape 1 was rejected for.

**Shape 3 — drift detection without assertion** (report every disagreeing numeral; fail
only on a registered set; allowlist drains). The fence-isolation shape solves a problem
this gate does not have: known-open defects that must not block while they drain. After the
fix commit there are zero known-stale numerals to carry, so the allowlist is born empty —
and "report every numeral" is undecidable without a convention for what counts as a
checkable numeral, which is the discovery scan the gate's header rejects because a green
run gets read as the broader claim. What survives from Shape 3: the **two-directional
check**. A registered claim whose anchor vanishes is rc 2, which forces the row's deletion
in the same commit the sentence dies — the registry drains rather than rots, exactly as
fence-isolation's allowlist does.

**The pick: extend the CLAIMS registry with one generic truth source per count family.**
This is Shape 1's pairing plus Shape 3's drain, on machinery that already runs in CI.

---

## The mechanism

Two new truth functions, both bash-3.2-clean (no arrays, no `mapfile`, no `${var^^}`), both
following the house contract — print one bare number or nothing, missing input is
could-not-run, zero is could-not-run when zero is impossible:

```bash
# Placeholder markers in one file. The PAT is the canonical one from
# reference/skill-authoring.md §2 — three families; {if…} conditionals are a
# fourth family and are NOT markers, which is a definition this gate shares
# with the prose rather than checks (see "what it cannot catch").
# BSD-safe: BRE \| alternation drops a non-final branch ending in $ under BSD
# grep, and no branch here ends in $ — all three end in }. awk, not wc: two
# wc calls on one line are corrupted by the rtk wrapper in at least one live
# environment, and awk 'END{print NR+0}' has no such failure mode.
truth_marker_count() {   # <path relative to repo root>
    local _n
    [ -r "$1" ] || return 1
    _n=$(/usr/bin/grep -o '{vocabulary\.[a-z_]*}\|{config\.[a-z_]*}\|{DOMAIN:[^}]*}' "$1" \
         | awk 'END{print NR+0}')
    # Zero markers in a REGISTERED file means the pattern stopped binding, not
    # that a template lost every placeholder — every registered file is chosen
    # because it carries them. could-not-run, never a count.
    [ "${_n:-0}" -gt 0 ] || return 1
    printf '%s' "$_n"
}

# check-prose-paths.sh's SCOPE size — deferral #24's quantity, same awk its
# re-derive block uses.
truth_scope_files() {
    local _n
    [ -f reference/check-prose-paths.sh ] || return 1
    _n=$(awk '/^SCOPE="/{f=1;next} /^"/{f=0} f&&NF' reference/check-prose-paths.sh \
         | /usr/bin/grep -c . || true)
    [ "${_n:-0}" -gt 0 ] || return 1
    printf '%s' "$_n"
}
```

Nine rows. The extracts below are written against the **post-fix wording** — registration
and the numeral corrections land in one commit (see ordering, below). Anchors deliberately
repeat enough of each sentence that two rows on one sentence cannot capture each other's
number:

```text
reference/skill-authoring.md|verify marker count (source)|s/.*yields `verify` \([0-9][0-9]*\) against [0-9][0-9]*.*/\1/p|truth_marker_count|skill-sources/verify/SKILL.md
reference/skill-authoring.md|verify marker count (blocks)|s/.*yields `verify` [0-9][0-9]* against \([0-9][0-9]*\).*/\1/p|truth_marker_count|platforms/shared/skill-blocks/verify.md
reference/skill-authoring.md|validate marker count (source)|s/.*`validate` \([0-9][0-9]*\) against [0-9][0-9]*.*/\1/p|truth_marker_count|skill-sources/validate/SKILL.md
reference/skill-authoring.md|validate marker count (blocks)|s/.*`validate` [0-9][0-9]* against \([0-9][0-9]*\).*/\1/p|truth_marker_count|platforms/shared/skill-blocks/validate.md
reference/skill-authoring.md|reflect marker count (source)|s/.*`reflect` is \([0-9][0-9]*\) against [0-9][0-9]*.*/\1/p|truth_marker_count|skill-sources/reflect/SKILL.md
reference/skill-authoring.md|reflect marker count (blocks)|s/.*`reflect` is [0-9][0-9]* against \([0-9][0-9]*\).*/\1/p|truth_marker_count|platforms/shared/skill-blocks/reflect.md
CLAUDE.md|verify markers, frozen side|s/.*[^0-9]\([0-9][0-9]*\) markers in `verify` where `skill-sources` has [0-9][0-9]*.*/\1/p|truth_marker_count|platforms/shared/skill-blocks/verify.md
CLAUDE.md|verify markers, live side|s/.*[0-9][0-9]* markers in `verify` where `skill-sources` has \([0-9][0-9]*\).*/\1/p|truth_marker_count|skill-sources/verify/SKILL.md
docs/superpowers/deferrals.md|SCOPE count, entry 24 re-derive|s/^awk .*check-prose-paths\.sh[^#]*# *\([0-9][0-9]*\), the live count.*/\1/p|truth_scope_files|
```

**Every extract above was executed against a simulated post-fix file before being written
here, and one was wrong the first time.** The frozen-side CLAUDE.md row originally opened
`s/.*\(` — and greedy `.*` ate into the digit run, capturing `6` from `146`: a sliding
capture that would have reported "document says 146, tree measures 146" as
"document says 6" on a correct document. The published form carries the `[^0-9]` boundary
that pins the capture to the full run. The six skill-authoring rows do not need it only
because a literal backtick-space precedes each capture; a future row whose numeral follows
`.*` directly must repeat the boundary, and the mutation tests below are the check that a
row binds the number it claims to.

The deferrals row reads a `# N` annotation on a command line rather than a sentence —
precedent is the existing `docs/open-divergences.md|CI step items` row, which does exactly
that. Note what it does *not* do: it never executes the block it reads. When entry 24
closes and its text leaves the file, the row goes rc 2 and is deleted in the same commit —
the drain direction.

**Why the frozen-side numbers are registered at all.** 146/60/203 cannot drift while check
4's freeze holds, so those three rows look redundant. They are kept for three reasons:
a two-number sentence with one gated number invites the reader to assume both are (naming
some coverage makes the rest read as covered — a documented failure shape here); a row per
capture group is what proves each half of the extract binds rather than free-matching; and
if the freeze is ever lifted and the blocks edited, these rows are a second, independent
reader. `platforms/shared/skill-blocks/` is only ever *read* — nothing in this design
writes it.

**Positive control at birth.** `validate` 5 and 60 are currently correct, so two rows are
born proving `truth_marker_count` can return `ok` — the same role the CLAIMS comments
assign to the link-extraction row. Without it, a gate whose every new row fires on day one
has not demonstrated it can do anything but fire.

**Registration precondition: one physical line.** A registered sentence must keep its
numeral and its anchor phrase on one line, because the extraction is line-based `sed`.
CLAUDE.md's sentence currently violates this (the `27` opens line 124) and must be reflowed
by the fix commit before its two rows can bind. This becomes a stated rule in the
contributor section below, not a silent property of the implementation.

**Ordering.** Rows and numeral corrections land in **one commit**. Registered against the
current prose, the gate is born rc-1 red on 27 and 121 — truthful, and there is born-red
precedent (check 7), but born-red needs an allowlist to be mergeable and the fix here is a
two-word edit; carrying scaffolding to avoid a trivial edit is backwards. The fix commit
therefore: corrects 27→30 and 121→123, reflows the CLAUDE.md sentence, adds the two truth
functions and nine rows, and runs the gate green.

---

## What a contributor does differently

The commit-time rule, in decision order — this operationalizes the constraint the gate's
own comments already state ("gate every number you mint, in the commit that mints it"):

1. **Prefer no live numeral.** State the relationship, or point at the re-derive command,
   the way the CI-step-on-main count and the SCOPE prose were fixed — by removal. A numeral
   that only ever detects its own staleness should not exist.
2. **A numeral describing a past event gets a date** ("born red at 72 sites",
   "SCOPE went 11 → 14"). History does not rot; deferral #24 says this in as many words.
3. **A live numeral that stays gets a CLAIMS row in the same commit** — reusing an existing
   truth function where one fits, adding one truth function per new count *family* (not per
   number). Its sentence keeps number and anchor on one physical line.
4. **Rewording a registered sentence means running the gate** before pushing. This is
   already the standing warning for `CLAUDE.md`, `docs/verification.md` and
   `docs/open-divergences.md`; it now also covers `reference/skill-authoring.md` §2's yield
   sentence and deferral #24's re-derive annotation. rc 2 is the loud form of that mistake.

And the cost, stated rather than hidden: an edit that changes a registered template's
marker count — adding a `{vocabulary.*}` token to `verify`, `validate`, or `reflect` —
now turns the branch's own CI red until the prose moves with it. That is the intended
behavior ("prose and code move in the same commit", §4's rule, now enforced for these
sites), but it is a new two-file obligation on template edits that previously shipped
alone. It falls on three of sixteen templates.

---

## What it catches, and what it provably cannot

**Catches.** A registered numeral going stale against the working tree — including on the
branch that moves it, *before* merge: unlike the retired main-anchored CI-step claim, every
truth source here measures the working tree, so the branch that changes a count fails its
own CI run rather than reddening `main` afterward. Merge-order races collapse to a visible
prose conflict, not a silent stale. Also caught: a registered sentence being reworded or
deleted (rc 2, forcing row maintenance — the drain), an over-matching extract (two values →
MISMATCH), and a truth source that stops producing (rc 2, never a comparison against
empty).

**Provably cannot catch, by construction:**

- **Any unregistered numeral.** The scope is declared-claims-only and the banner says so on
  every run. The registered set after this design is 9 rows added to the existing table;
  the population of prose numerals in this repo is unenumerated and unenumerable without
  the discovery-scan convention this design rejects. The next 27 rots freely unless its
  author follows the contributor rule — the mechanism lowers the cost of registration and
  cannot compel it.
- **A number that is wrong the same way on both sides.** The gate checks currency, never
  meaning ("only whether it is current"). Concrete instance already latent: PAT counts
  three placeholder families, and §2 names four — `{if …}` conditionals are excluded from
  "markers" by shared definition. If a fifth family ships, prose and gate undercount in
  perfect agreement and the gate stays green. One-sided in effect, two-sided in
  appearance.
- **A synonym site.** A second sentence stating the same count in different words is
  invisible until registered; a gate that reads one phrasing does not protect a paraphrase
  — deferral #24's own wording, describing exactly how its count escaped the existing
  rows.
- **A hard-wrapped registered sentence** whose reflow puts the number back on the next
  line: that is rc 2 (anchor not found), so it fails loud rather than silently passing —
  but the gate cannot *bind* across the wrap, only refuse it.

**False-positive behavior.** The failure modes split cleanly by exit code. rc 1 without a
real drift requires the extract to capture the wrong number from a correct sentence — a
demonstrated hazard, not a theoretical one (the sliding-capture defect recorded in the
mechanism section was caught by executing the rows before publishing them). Mitigated by a
non-digit boundary before any capture that follows `.*` directly, by anchors that spell out
the neighboring number (`[0-9][0-9]*`), by the existing multi-value MISMATCH when an
extract over-matches, and by the two positive-control rows. rc 2 fires on any rewording of a registered sentence, which is a
true statement ("this gate no longer knows") rather than a false accusation, and is the
designed pressure toward rule 4 above. There is no path to a *silent* false pass: empty
extraction and empty truth are both rc 2 by inherited machinery.

---

## Which declared numerals this design moves

**None in the gated set.** No new file (`truth_check_files` stays 18), no new CI step
(`truth_ci_steps` stays 32), no new CI-run check (`truth_ci_run_checks` stays 16), both
`check_list_len` fences unchanged, and the CI-steps-vs-main relationship is untouched.

**One ungated numeral moves, and by a documented hand-maintenance contract:**
`docs/verification.md:27` quotes `check-doc-claims.test.sh` as `13/13`. The implementation
adds mutation coverage to that suite (below), so the `13` moves and must be hand-updated in
the same commit. This is not an oversight to fix in passing: the suite's own header
declares the row deliberately unwired, because wiring `truth_suite` to it would make the
gate invoke a suite that itself invokes the gate three times — a ~4x cost multiplier on
every run, plus a recursion seam. A static assertion count (`grep -c` over the suite) was
considered as a cheaper truth source and rejected: call sites and runtime passes are
different quantities, and a row asserting one while prose states the other is a
one-sided comparison wearing a two-sided label. The gap stays a stated, hand-maintained
one. (The suite header names `CLAUDE.md/CONTRIBUTING.md` as the prose sites; post-split
the only live site is `docs/verification.md:27` — noted here, not fixed, per the
surgical-change rule.)

---

## Runtime

Measured baseline, this machine (Darwin 22.6.0, repo on SD-card — the slow case):

```bash
time bash reference/check-doc-claims.sh   # PASS, 2m25.95s wall, 39.4s user
```

The gate's cost is dominated by its eight `truth_suite` rows, each of which executes a test
suite. This design adds **zero** suite executions: nine rows backed by one `grep -o | awk`
or one `awk | grep -c` each, over files of 11 KB (`skill-authoring.md`, `CLAUDE.md`) to
71 KB (`deferrals.md`) and six template files. Expected delta: well under one second.
Worst case: unchanged in shape — the new truth sources cannot hang (no subprocesses beyond
grep/awk on regular files, no network, no git), so the worst case remains the existing
one, a wedged test suite, already fenced by the CI job's `timeout-minutes: 20` with roughly
seventeen minutes of headroom over the measured gate.

Shell posture: the new code is bash-3.2-clean and zsh-indifferent (quoted expansions,
`local`, POSIX arithmetic — the same posture the existing truth functions hold after the
zsh-fork fix their header describes). The gate's totals remain BASH-RUN ONLY, unchanged.

---

## Testing

Mutation coverage in `reference/test/check-doc-claims.test.sh`, following its existing
back-up/mutate/restore pattern against the real tree, one defect per mutation:

1. **Drift fires.** Append one `{vocabulary.notes}` token to a temp-backed copy of
   `skill-sources/verify/SKILL.md` → gate must exit 1 naming the verify row. This mutates
   the *defect* (the count moved) rather than the line, and proves the PAT binds on the
   live side.
2. **Rewording fires as rc 2, not as a pass.** Replace `yields` with `gives` in
   `reference/skill-authoring.md` (temp-backed) → gate must exit 2 with the
   anchor-not-found message. This is the negative assertion, and mutation 1 is its paired
   positive — an empty grep result is what PASS looks like, so absence-based expectations
   never stand alone.
3. **Truth-source loss is rc 2.** Point `truth_marker_count`'s argument at a missing file
   (drive via a copied gate with one row edited, the suite's existing technique) → rc 2,
   never a comparison against empty.
4. **The deferrals row binds.** Change `# 16, the live count` to `# 17, the live count`
   (temp-backed) → exit 1 on the SCOPE row.

Baseline before and after: `bash reference/check-doc-claims.sh` green;
`bash reference/test/check-doc-claims.test.sh` green with its new total, and
`docs/verification.md:27` updated to that total in the same commit. Full fence per
`docs/verification.md` before merge.

---

## What is NOT claimed

- **Not claimed: the repo's numerals are now gated.** Nine more are. The banner's sentence
  — a green run is not evidence that every number in every document is right — is as true
  after this design as before, and the design depends on contributors reading it that way.
- **Not claimed: the deferral-drain gate.** Running every deferral entry's re-derive block
  to flag entries whose defect is fixed remains unbuilt and remains routed to the
  CI-hardening spec, where next-sprints and entry #24's "Why not now" both placed it. This
  design reads one annotation from that file; it does not execute anything in it.
- **Not claimed: correctness of the counted quantity.** `truth_marker_count` asserts the
  prose matches the PAT's output, not that the PAT matches the placeholder grammar. The
  gate inherits the inventory's standing caveat: no gate here asserts a computed number is
  *right*.

## Decisions taken, 2026-08-24

1. **Extend `check-doc-claims.sh`; no new file, no new CI step.** Deferral #24's Reopens-if
   condition is satisfied by this mechanism, and #24's SCOPE count is its first user
   alongside the two motivating rots.
2. **Truth functions per count family, rows per numeral, frozen-side numbers included.**
3. **Registration rides the fix commit** (the other spec's task 1): corrections, CLAUDE.md
   reflow, truth functions, rows, and mutation tests land together, born green.
4. **The one-physical-line rule for registered sentences** is a stated registration
   precondition, recorded here and enforced by rc 2.
5. **`13/13` stays hand-maintained**, per the suite's own documented reasoning; it moves by
   hand in the implementation commit.

The strongest standing objection, recorded rather than argued away: the mechanism is
opt-in, and the two counts that motivated it rotted precisely because nobody opted them
in. This design makes registration cheap (one row, an existing truth function) and loud
when neglected after the fact (nothing — that is the point of the objection). The
mitigation is the contributor rule plus the precedent that every numeral family now has a
worked example; the residual risk is real and is the same risk the CLAIMS table has
carried since it was built.
