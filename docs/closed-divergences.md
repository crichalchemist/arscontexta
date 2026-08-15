# Closed divergences

Records of divergences that were found, fixed, and verified. Extracted from `CLAUDE.md`
on 2026-08-11 so that completed work stops loading into every session; the content below is
unchanged from what that file carried.

**This is an archive, not guidance.** Open divergences, the "Won't fix" list, and the
cross-cutting pattern all remain in `CLAUDE.md`. Entries here are referenced by number from
that file, which is why they are kept verbatim and in order rather than renumbered.

---

### Closed on `fix/exhaustive-dangling-scan`

- **The dangling-link check sampled 100 links and reported the result as a property of the graph** —
  divergence 11. `validate-kernel.sh` capped `link_candidates` at `head -100`. On the field vault
  that is **100 of 2716 unique link targets — 3.7%**, and the PASS it produced read as a statement
  about all of them.

  **The cap was hiding real defects, which is the part worth stating rather than the percentage.**
  Measured on the field vault immediately before the change, replicating the old path exactly:

  | scan | coverage | dangling found | verdict |
  |---|---|---|---|
  | old, `head -100` | 100 of 2716 (3.7%) | **0** | `PASS No dangling wiki links` |
  | new, exhaustive | 2716 (100%) | **8** | `WARN 8 unresolved wiki links` |

  So the primitive was printing a clean PASS over a graph with eight broken links, and had been for
  as long as directory resolution worked.

  **The fix is a set difference, NOT a bigger cap — and the premise that kept the cap was simply
  untested.** The entry reasoned that lifting it "is not free": one `grep -qxF` per link on top of a
  run already taking ~45s. That much was true — measured, the per-link loop costs **32.0s** for all
  2716 links against **1.0s** for 100. What was never checked is that a loop was the only
  alternative. `comm -23` over two sorted, folded streams checks **all 2716 in under a second** and
  returns the identical count. **The exhaustive version is faster than the sample it replaced**, so
  there was no coverage/time tradeoff to defend — only a loop shape. Equivalence was verified against
  the loop on the validator's own inputs, not on a convenient subset: both return 8.

  **Beware the two different "existing" sets — they produce different dangling counts and the
  difference is not a bug.** A first benchmark built the existing-file index from `nodes/` alone
  (2686 files) and found **30** dangling; the validator builds it from every `*.md` in the vault
  (5251 folded basenames) and finds **8**. Both are internally consistent; only the second describes
  what the validator does. Re-derive:

  ```bash
  . reference/lib/link-extraction.sh
  V=~/second-brain
  existing=$(find "$V" -name '*.md' -not -path '*/.git/*' | xargs -I{} basename {} .md \
             | _fold_lower | LC_ALL=C sort -u)
  links=$({ for d in nodes capture self; do extract_link_targets_recursive $V/$d; done; } \
          | grep -v '^$' | sort -u | _fold_lower | LC_ALL=C sort -u)
  comm -23 <(printf '%s\n' "$links") <(printf '%s\n' "$existing") | grep -c .   # 8 (drifts)
  ```

  **`comm` adds a requirement the loop did not have, and it fails silently.** The loop folded each
  link at comparison time and cared nothing about order. `comm` consumes two **sorted** streams and
  emits nonsense when their collations disagree — and default `sort` is locale-dependent.
  `existing_files` was sorted with a bare `sort -u`, so pinning only the new side would have made
  every non-ASCII name a spurious dangling link, quietly. **Both sides now pin `LC_ALL=C`**, and the
  suite asserts that both do.

  **The disclosure machinery went with the cap, deliberately.** The PASS used to print sample size,
  true total, percentage and unchecked remainder — added on the previous branch precisely so a
  sampled PASS could not read as complete. With an exhaustive scan those phrasings would describe a
  sample that no longer exists, which is the same class of false statement they were built to
  prevent. Both PASS arms now say `checked all`. The one surviving two-number case is **not** a
  sample: case-folding merges targets differing only by case, which resolve to one file, and that
  arm says so in words.

  ```bash
  for s in bash zsh; do $s reference/test/kernel-note-dirs.test.sh | tail -1; done   # 37/37, was 36/36
  ```

  **Five assertions were deleted and six added, and the deletions are the point.** Section 9 existed
  to pin the sample's disclosure — "the sample is a full 100, not 99", "states the unchecked
  remainder", "discloses the percentage", "does not claim to have checked all". Those pinned
  machinery that no longer exists; keeping them green would have required keeping the cap. The
  120-note fixture is **kept**, because it sits above the old cap and is exactly the case that used
  to be truncated and called clean.

  **Both new guards were mutation-proved rather than counted**, per this repo's own rule that a row
  in a total is not evidence it can fail:

  | mutation | turns red |
  |---|---|
  | reinstate `head -100` on `link_folded` | `checks all 120, not 100` **and** `no scan cap survives on the link pipeline` |
  | drop `LC_ALL=C` from the `existing_files` side only | `both comm inputs pin LC_ALL=C`, and only it |

  The structural guard keys on `link_(candidates|folded).*head -`, not on `head -[0-9]`. The broad
  form was written first and failed against three legitimate `head -1` uses — find-first-file,
  read-first-line, take-first-of-list. A guard that fires on correct code gets deleted, not fixed.

  **Consequence for the pass criterion, and it is a content defect rather than a regression here:**
  the field vault now reports **15 PASS / 2 WARN / 0 FAIL**, the new WARN being these 8 unresolved
  links. Primitive 2 is not on the list permitted to WARN, so by the criterion above it is a real
  finding — in the vault's content, not in this repo. It joins primitive 1 (frontmatter coverage) as
  a standing item the validator now surfaces instead of hiding.

  **What is NOT fixed:** `generators/features/*.md` still emit line-anchored `rg` recipes into
  generated vaults' documentation, and `skill-sources/seed/SKILL.md:83` caps duplicate candidates at
  `head -5`. The latter was assessed and left: it feeds a human-facing "proceed anyway?" prompt where
  five examples are illustrative, and it does not present itself as a complete result. If that prompt
  ever becomes an automated decision, it becomes the same defect.


### Closed on `fix/spec-f-divergence-drain`

- **`bump-version.sh` could leave a partial bump** — divergence 2. `cmd_bump` called the write helper
  unguarded under `set -e`, so a failure on a later declared site aborted with the earlier ones
  already rewritten. It now **stages every declared site into a temp and commits nothing until all of
  them have staged successfully.** That is the property, and it is the one worth stating — not
  "atomic": the commit phase is a sequence of same-directory renames, so a `mv` failing after a clean
  stage (ENOSPC/EROFS/EACCES) still leaves a partial tree. It **stops at the first failure** —
  continuing would move more declared files away from the state they share with the one that failed,
  maximising the divergence rather than bounding it — names the path that could not move, and
  discards every surviving temp.

  **That last clause was a defect in the first version of this fix, and it is the drift condition
  from one paragraph below.** `COMMIT FAILED` left the staged temps on disk: complete, undeclared
  copies of the release metadata beside the manifests — exactly what the rollback branch's own
  comment calls "a second copy of the release metadata that nothing declares". The message then sent
  the user to `--check`, which iterates declared **sites** and cannot see a temp. A remedy blind to
  the wreckage its own branch created. Each temp is redundant with the file it failed to replace, so
  discarding it loses nothing. Reproduced with `chflags uchg` on the target in both shells: before,
  a `…marketplace.json.tmp.<pid>` survived; after, it is named as discarded and the tree has none.

  **No gate exercises that branch.** Forcing a same-directory `mv` to fail needs a read-only target
  inside a writable directory — `chflags` on macOS, `chattr +i` as root on Linux — and neither is
  portable to CI. The check above is a hand-run reproduction, not a test. What *is* covered is the
  `discarded:` mechanism, which the abort branch shares and the suite exercises.

  **The staging source is chosen by what the run has staged, not by what is on disk.** It was
  `[ -f "$tmp" ]`, which answers a different question: `$$` is recycled by the OS, so a temp bearing
  this run's PID can be debris from an earlier run killed before it could roll back, and staging from
  it would bump a stale base and say nothing. The decision now consults the run's own staged-path
  list, and a same-PID leftover is deleted before first use rather than read.

  **The three declared sites live in two files, and two of them are the same file** —
  `.claude-plugin/plugin.json` (`version`) and `.claude-plugin/marketplace.json` twice
  (`metadata.version`, `plugins.0.version`). The suite's fixture mirrors that shape under `pkg/`,
  which is why the previous version of this entry read as though `pkg/marketplace.json` were a repo
  path: those are fixture paths, and nothing named `pkg/` exists in this checkout.

  **The same-file pair is why staging is keyed on path rather than on site.** The second edit is
  staged *from the first edit's temp*; staging both from the original file — the obvious shape for
  this fix — leaves the second temp carrying only its own edit, so committing it silently discards
  `metadata.version`. A fix that looks atomic and loses data.

  **Both halves of the defect were reproduced before it was touched**, and the second is the one a
  file-to-file comparison cannot see:

  | failure | before | after |
  |---|---|---|
  | inter-file: `marketplace.json` unparseable | `plugin.json` → `8.8.8`, `marketplace.json` old | both old |
  | intra-file: third site unassignable | one file **disagreeing with itself** — `metadata.version` `8.8.8`, `plugins[0].version` `7.7.7` | both old |

  `--check` does catch the intra-file state (measured: `DRIFT`, rc 1) because it iterates declared
  *sites*, not files. What that case defeats is a file-level diff; the defect is that the bump
  produced it at all.

  ```bash
  for s in bash zsh; do $s reference/test/bump-version.test.sh | tail -1; done   # 41/41, was 28/28
  ```

  **Thirteen assertions added, each mutation-proved rather than counted** — the failure this repo has
  already shipped is a suite whose total rises while the new rows cannot fail. Every mutation was
  asserted to have applied before its result was read:

  | mutation | turns red |
  |---|---|
  | full revert of `scripts/bump-version.sh` to `f38ebc8` | the 3 unmoved-site assertions |
  | delete the rollback loop | the 2 failure-path no-temp assertions |
  | stage every site from the original file | `metadata.version moved`, `--check agrees afterwards` |
  | delete `rm -f "$work"` from `stage_json_field` | the write-time no-temp assertion |
  | don't create the temp the positive control looks for | the harness control |
  | buffer the `SKIP (missing)` line into `$report` again | the SKIP-survives-abort assertion |
  | rename the temp suffix `.tmp.` → `.stg.` (4 sites, behaviour-identical) | the `$TMP_GLOB` coupling assertion |
  | that rename **plus** neutered temp removal (temps genuinely orphaned) | the same one, and only it |
  | stop printing the `discarded:` line at both sites | all three of the new controls |
  | neutered temp removal alone, suffix unchanged | the 2 failure-path no-temp assertions |

  **The fix introduced a regression of the house class, and the last row is its pin.** Moving the
  per-site rows into a buffer printed after the commit is right for the `old -> new` rows, which
  would otherwise claim moves that had not happened — but it swallowed `SKIP (missing)` too, so a
  declared file that was absent vanished from the output on exactly the runs that aborted. Found by
  review, not by the suite. A SKIP is a statement about the tree rather than a claim about a write,
  so it prints immediately, as it did before.

  **Coverage is partial in one place and is not rounded up.** The two failure-path "leaves no `.tmp.`
  behind" assertions stay **green** under the full revert, because the pre-fix helper also removed its
  temp on that path. They are guarded by the rollback-deletion mutation only; they are not evidence of
  the barrier.

  The rc-only assertion that stood here was **left exactly as it was** rather than tightened, per the
  brief — it holds whether the bump is atomic or merely loud. The new state assertions were added
  beside it. Two non-vacuity comments naming `write_json_field:55` and `rm -f "$tmp"` were rewritten
  to name `stage_json_field` and `rm -f "$work"`, and the new mutation re-run: a non-vacuity note
  naming a function that no longer exists records a check nobody has performed.

  **Two controls guard the four `""`-expecting temp assertions, and the first one alone was not
  enough — the sentence that stood here claimed the opposite of what was measured.** It said "without
  it, renaming the temp suffix would make all four pass for free." Measured: **with** it, renaming
  the suffix (`.tmp.` → `.stg.`, behaviour-identical, 4 sites) left the suite fully green in both
  shells — and so did the same rename with temp removal neutered, which genuinely orphans staged
  temps beside the manifests. A tracked claim that a check covers something it does not, in the file
  whose purpose is recording where this repo's checks fall short.

  The first control plants a file and proves the **search** works — right root, pattern can match.
  That is all it proves; it observes nothing about `bump-version.sh`, and the two were linked only by
  a string typed into both files and checked in neither.

  The second control closes it. Both failure branches now **print each temp they discard**, so a
  filename built by the script crosses the boundary, and the test asserts `$TMP_GLOB` matches *that*
  — using `find` with the same pattern the four assertions use, not a shell `case`, which matched
  under bash and not under zsh. `$TMP_GLOB` is single-sourced across all six `find` uses — of which
  **five** are assertions that depend on the pattern matching what the script names, the sixth being
  the planted control that deliberately does not
  (`grep -c '\$(find .*-name "\$TMP_GLOB"' reference/test/bump-version.test.sh` → 6; anchor on the
  `$(find` invocation, since `grep -c 'find .*\$TMP_GLOB'` also matches two comment lines and
  returns 7). The two counts differ by exactly that control, which is the
  defect this fix closed; a re-review read them as one number and reported an off-by-one in the test
  comment that says "five assertions", where that sentence is correct. Both mutations above now turn
  it red in both shells.

  ```bash
  # Re-derive any row of the table above: apply the mutation, ASSERT IT APPLIED, run, restore.
  S=scripts/bump-version.sh; B=$(mktemp); cp $S $B
  perl -pi -e 's/\.tmp\.\$BUMP_PID/.stg.\$BUMP_PID/g' $S          # the suffix-rename row
  cmp -s $B $S && echo 'MUTATION DID NOT APPLY — result meaningless' || \
    for s in bash zsh; do $s reference/test/bump-version.test.sh | tail -1; done
  cp $B $S
  ```

  A mutation that silently fails to match reports the same all-green as a robust assertion, which is
  why the `cmp` guard is part of the recipe rather than a note beside it.

- **No shared frontmatter parser, a split `status` enum, and a fixture blind to both** — divergences
  7, 8 and 9. `reference/lib/frontmatter.sh` (`FRONTMATTER_VERSION=1` when that record was written; **3** as of `fix/spec-h-enforcement-gap`, which added the readability guard and symlink traversal) is now the single definition,
  alongside `link-extraction.sh` and versioned the same way. Frontmatter is **strictly** the block
  between a `---` on line 1 and the next `---`; keys must start at column 0; the field name is matched
  with `index()`, never a regex.

  **Eleven live sites converted**, not the three the entry named — the count was taken by hand and was
  low. Re-derive the live set (comments describing the old form are excluded, which is why a check
  keyed on the literal string returns 5 and means nothing):

  ```bash
  for f in $(find skill-sources skills -name SKILL.md) hooks/scripts/session-orient.sh; do
    sed 's/#.*$//' "$f" | grep -q "grep -r[lLc]* *['\"]\^status" && echo "LIVE: $f"
  done                                   # prints nothing; injecting one site makes it print
  ```

  **The enum was resolved toward `schema.md`, not away from it:** `open` was added to
  `generators/features/atomic-notes.md:94`, because `schema.md` declares the `_schema` block "the
  single source of truth for field validation" and both `_schema` blocks list `open`. The reasoning is
  written into the file that changed, together with the note that `ops/tensions/` (`pending | resolved
  | dissolved`) and queue entries (`pending`, `done`) are *different fields that share a name* — the
  ambiguity that let one `status` vocabulary be mistaken for three.

  **D8 was latent in the scope the converted sites scan, and manifest just outside it.** Measured on
  the field vault: `ops/observations/` has 38 files matching `^status:` and `ops/tensions/` 27, and
  **zero** of those 65 carry the match outside frontmatter — so no shipped observation or tension
  count was ever wrong, and "this was producing wrong numbers" would have been the wrong claim.
  Vault-wide, though, 15 files *do* match only in the body, and 2 of them are in `ops/methodology/` —
  a directory `generators/features/methodology-knowledge.md:31` tells vaults to scan with
  `rg '^status: active'`. The class is live there; that recipe is among the unconverted ones noted in
  the open list above. Re-derive both halves:

  ```bash
  . reference/lib/frontmatter.sh
  for d in ~/second-brain/ops/observations ~/second-brain/ops/tensions ~/second-brain; do
    n=0; t=0
    for f in $(grep -rl '^status:' "$d" --include='*.md' 2>/dev/null); do
      t=$((t+1)); frontmatter_field "$f" status >/dev/null 2>&1 || n=$((n+1))
    done
    printf '%-46s %4s matching, %2s body-only\n' "$d" "$t" "$n"
  done                                  # 38/0, 27/0, 2476/15
  ```

  **The earlier entry's "14 matching files" was a different quantity wearing that label.** 14 is the
  number of observations whose status *is* `open` — the filtered count — not the number of files
  matching `^status:`, which is 38. A filtered count read as a match count is the same substitution
  this file records under divergence 4, and it is worth naming because it made the defect look two
  orders of magnitude smaller than the surface it covered.

  **The parser matches values exactly where the naive form matched prefixes** (`^status: pending` also
  matches `pending-review`). That is a real semantic change, and it changes nothing here: measured
  against the same 65 files, naive and library agree exactly — observations 14/14, tensions 8/8 — and
  the distinct values present are `open`, `implemented`, `archived`, `resolved`, none of them a prefix
  of another.

  ```bash
  . reference/lib/frontmatter.sh
  for d in ~/second-brain/ops/observations ~/second-brain/ops/tensions; do
    printf '%-24s naive=%s lib=%s\n' "$(basename "$d")" \
      "$(grep -rl '^status: pending\|^status: open' "$d" 2>/dev/null | wc -l | tr -d ' ')" \
      "$(count_notes_by_field "$d" status pending open)"
  done                                  # observations 14/14, tensions 8/8
  ```

  **The fixture is why 7 and 8 could survive.** `reference/test/fence-isolation.test.sh` now builds a
  four-note discriminating set under `notes/status-probe/` — frontmatter `status`, a body-fenced
  `status: pending` at **column 0**, a nested one, and one with no frontmatter at all — and asserts
  three ways as gate assertion **F**: correct parser **2**, naive `grep -rl` **1**, wrong-field parser
  **4**. The two wrong answers test *different* properties (body discrimination; field-name
  discrimination), so neither arm is redundant. Both arms were verified live by mutation: removing the
  frontmatter guard drops the correct arm to 1, hardcoding the field drops the wrong-field arm to 2,
  and each turns the gate red.

  **The remedy message is backed by a step that performs it.** `/next`, `/rethink`, `/stats`,
  `/architect` and `/health` exit 1 naming `/arscontexta:upgrade`, so `skills/upgrade` Step 6a is now
  table-driven over **both** libraries — reading each one's own version constant, reporting one line
  per file — and `skills/setup` copies both. `skills/health` Category 9 checks both, which it must:
  it sources `frontmatter.sh` for its own condition counts and would otherwise vouch for a library it
  had just failed to use. `hooks/scripts/session-orient.sh` is the one converted site that does **not**
  exit: it is a SessionStart hook, so it warns on stderr and omits the two signals, because an omitted
  line is visible and a substituted `0` is exactly the value that stops a threshold from ever firing.

  `platforms/shared/skill-blocks/rethink.md:75,77` still carries the naive form and was deliberately
  not touched — that tree is frozen by `check-portability.sh` check 4's cksum manifest. The queue-file
  greps (`skill-sources/stats:329-330`, `tasks:86-87`, `next:215`) are also unconverted and are a
  different subject: a queue file is a list of entries, not per-note frontmatter.

- **`graph`'s authority loop inlined the naive matcher** — divergence 6, and one more site than that
  entry knew about: the identical loop also drove `stats`' orphan count
  (`skill-sources/stats/SKILL.md:198`). Both now read the shared library. `/graph hubs` builds the
  edge set once through `_strip_fences` + `_fold_lower` and counts per note with `grep -cxF`;
  `stats` computes orphans as `comm -23` over the library's folded, sorted index and target set,
  minus a folded MOC index — MOCs are still excluded, as they were before.

  **The measured before/after is the reason to trust the change, and the reason the defect lasted.**
  On an eight-note fixture exercising case, fences, aliases and regex metacharacters, the old
  spelling scored `Target` 0 incoming (truly 2 — one link differing only in case, one `[[Target|alias]]`),
  scored `Fenced` 1 (truly 0 — its only link sits inside a ``` block), and scored `a.b` 2 (truly 1 —
  `.` matched the decoy `[[axb]]`, because the note name was interpolated into a regex). `grep -v "$f"`
  had the same regex hole on the exclusion side. **Wrong in both directions at once**: the orphan set
  came out at exactly 6 before and after, with `target` swapped for `fenced` inside it. A check
  comparing totals would have called this fix cosmetic.

  Gate coverage was proved rather than assumed: deleting the library `.`-source from that one fence
  (line 436, `f03`, opening at line 415) makes `fence-isolation.test.sh` report
  `H skill-sources/graph f03` and FAIL under bash; restoring it returns the suite to green.

  **Round 2 finished the class inside `skill-sources/`.** The paragraph above used to end here,
  saying three sites survived in these same two files under a spelling the criterion could not see.
  That was itself an undercount, and the widened pattern in divergence 12 found **five**: MOC coverage
  in `graph` and `stats` (`xargs grep -l`), `/graph backward` (`-exec grep -l`), plus two the first
  widening still missed because it required a **double** quote — `reweave`'s backlink command and
  `reflect`'s incoming-link count, both single-quoted. All five now resolve through the library;
  `reweave` and `reflect` gained a `NOTES_DIR` guard and a library stanza they never had.

  Measured, not assumed: the in-fence count across `skill-sources/` goes **5 → 0**, with the same scan
  against the previous commit still returning 5 as a positive control. Gate coverage was mutation-
  proved for the two fences that newly source the library — removing the `.`-source from each makes
  `fence-isolation.test.sh` report `H skill-sources/reweave f03` and `H skill-sources/reflect f03`.

  **What this still does not do is remove the class from the repo — see divergence 12**, which listed
  seven executable sites outside `skill-sources/` when this branch closed — five have since been
  converted to the library, leaving two survivors (`skills/health/SKILL.md:661` and
  `reference/testing-milestones.md:425`). Divergence 12's residual table adds two sites promoted from
  prose into documentation-table rows (`skill-sources/graph/SKILL.md:789`, `:794`), for **four**
  residual sites total, only two of them executable (one non-interpolating, one interpolating); the other two are documentation-table rows — and **divergence 13**, which counted the cost
  at seven sites inlining link *extraction* then (now closed within `skill-sources/` and `skills/`;
  divergence 13 names the one site still outside that scope), because the library answers directory-
  scoped questions only and nothing asks "which files link to X".

- **`validate-kernel.sh` soft-passed the dangling-link primitive** — was divergence 1, and the
  highest blast radius entry on the list: the kernel contract, run against every generated vault,
  reporting a soft pass on a check that never executed. Two consecutive lines of one run read
  `PASS 3786 of 5253 files contain wiki links` and `WARN No wiki links found to check`.

  The scan named a hardcoded list — `01_thinking`, `notes`, `00_inbox`, `04_meta/logs`, plus
  `$VAULT/../self`. Measured against the field vault: **all five absent.** Its notes directory is
  `nodes/`, because that is what its derivation named it. Same root cause as the primitive-10 defect
  closed on `fix/spec-c-primitive-10` — canonical directory names hardcoded inside a validator for a
  generator whose whole purpose is renaming them.

  The list is gone. `resolve_note_dirs` derives the directories from the vault, preferring the
  vault's own `ops/derivation-manifest.md` `vocabulary:` block — authoritative because
  `platforms/claude-code/generator.md` states that a vault's skills read that same file at runtime,
  so the validator now obeys the mapping the vault already obeys — then `ops/config.yaml`, then a
  shape scan for top-level directories containing `*.md`. A source that *names* a directory which
  does not exist does not count as resolved and falls through, because a successful parse and a
  usable directory look identical downstream. `$VAULT/../self` became `$VAULT/self`, where primitive
  8 was already finding it. Logs and `ops/` are deliberately excluded and the header says why: a
  wiki link in a changelog entry is a historical citation, not a graph edge, and it is *expected* to
  dangle.

  **Unresolvable is now FAIL, never WARN** — three outcomes where there were two, since "could not
  run" and "ran and found nothing" are different facts.

  Every message from the primitive now prints `scanned: <basenames>` as well as the source label,
  because naming the source is not naming the set: on the field vault the vocabulary route resolves
  3 directories and the shape scan resolves 6, so two vaults identical but for a manifest get
  different coverage under the same green PASS. The resolver's header carries the measured
  comparison and states that reconciling the two routes is deliberately not done here.

  Measured after, on the field vault: `16 PASS / 1 WARN / 0 FAIL`, the WARN being frontmatter
  coverage. Guarded by `reference/test/kernel-note-dirs.test.sh`, 36 assertions in both shells, in
  CI — every fixture uses the arbitrary directory name `zzz-arbitrary`, never `nodes`, because a fix
  verified against the field vault only proves that `nodes` joined the hardcoded list. Confirmed to
  fail 15 of 21 against the pre-fix validator.

- **A new over-claim the fix would otherwise have minted.** The dangling loop samples the first 100
  links, which was harmless while the scan resolved nothing and the sample was always empty. With
  resolution working, `PASS No dangling wiki links` would have asserted over the field vault's 2711
  unique links on the strength of a hundred. The cap is deliberately left alone — changing what is
  scanned in the same commit that changed how directories are resolved would make the two effects
  impossible to attribute — but the message now discloses the sample size, the true total, **the
  percentage** and the unchecked remainder, because `100 of 2711` skims as near-complete and `3.7%`
  does not. The sample was also one short of its own cap: `link_candidates` is seeded empty and the
  leading blank line survived `sort -u`, so `head -100` delivered 99. Whether to lift the cap is
  open; see divergence 11.

### Closed on `fix/spec-e-fourteen-items`

- **The fence-gate allowlist could hide an unrelated failure** — was divergence 1. Absorption keyed
  on `(letter, label)` and ignored the `ZSH ONLY:` scope the staleness half already honoured, so a
  zsh-only entry swallowed a **bash** failure and the gate printed PASS. Reproduced with a fabricated
  entry against a deliberately-broken fence, then fixed by extracting one `in_scope` predicate that
  both halves call. Same probe after the fix: bash blocks, zsh still absorbs. See the Verification
  section above for the residual that was left open on purpose.
- **`/next` promised eight state fields and computed five** — was divergence 2, and the only entry on
  that list that reached users' machines. Orphans, Dangling, Stale and Queue are now computed, the
  first two through `ops/lib/link-extraction.sh` rather than an inlined naive matcher; `graph`'s
  **orphan loop** got the same treatment, and its authority-ranking loop did **not** — that survivor
  was carried as divergence 6 and is now closed on `fix/spec-f-divergence-drain`. This sentence has
  been wrong twice in opposite directions, which is the part worth keeping. It first read "`graph` got
  the same treatment" while a site remained; corrected, it read "still inlines" and is now stale the
  other way. Commit `741b2b7`'s claim that the spelling is "gone from executable code in both files"
  overstated it then, because sites remained in both. It is finally true of these two files as of the
  second round on `fix/spec-f-divergence-drain` — but only of `skill-sources/`, and only for
  *matching*: see divergence 12 for the sites elsewhere (seven when this branch closed; four
  residual today, only two of them executable — the other two are documentation-table rows), and
  divergence 13 for the extraction the fix inlined (also seven then, now closed within
  `skill-sources/` and `skills/`). `stale_notes` was redefined in prose to the definition the
  code can actually compute — "not modified in 30+ days" — instead of shipping a fifth reading of
  "stale".
- **The claim counter truncated at three digits.** `{source}-999.md` was not a cap but a *collision*:
  the scan matched exactly three digits, so the maximum went backwards once numbering passed 999.
  Padding is now seven digits minimum, wider values pass through unchanged, and existing files are
  never re-padded — re-padding renames a file and breaks every wiki link to it, because links resolve
  by filename.
- **Four gate-integrity gaps** (this task). The DELETED branch of the freeze check was untestable by
  exit code alone — `cksum < <missing>` yields an empty digest and reports MODIFIED at the same rc 1,
  which also mis-fires the "suspect a differing cksum implementation" note; two message assertions now
  distinguish them. `guard-failure.test.sh`'s hardcoded `bash "$GUARD"` is now a stated decision with
  a shebang assertion pinning it. `bump-version.sh` went from zero coverage to 28 assertions in both
  shells, wired into CI — **28 was that branch's number; the suite is at 41 today**, raised by
  divergence 2's fix. The historical figure is kept because this section records what that branch
  delivered, but a reader who takes it as current will be 13 assertions behind.

### Closed on `fix/spec-c-primitive-10`

Listed because the entries above were renumbered, and a divergence list that quietly drops items is
the same status-that-lies defect in miniature.

- **Primitive 10 checked presence, not resolution** (`fd9bdb6`). `validate-kernel.sh` verified only
  that `qmd` was on `PATH` — and qmd *was* on PATH throughout the entire period when all 62 of its
  call sites named tools qmd had removed, so the validator reported semantic search satisfied while
  every call failed and the documented "fall back to `rg`" path quietly stood in. It now asserts the
  declared tool names resolve, keeping *qmd absent* (WARN) distinct from *qmd present but broken*
  (FAIL).
- **Eight fence defects** → two. `skills/help` f01, `skills/health` f10, `skill-sources/next` f04
  and `skill-sources/reflect` f03 each rendered `0` on a missing notes directory (`bb219d0`);
  `skill-sources/seed` f01/f03/f04/f05 each read a `$FILE` no fence defined (`a5e1795`). The two
  survivors are the **zsh-only** glob forks, found only because the gate runs both shells.
- **The stale-lock retry was unbounded** (`7765504`). Bounded at 60s, then exits 1 naming the lock
  path. The lock is still never broken automatically on mtime, and `mkdir` still omits `-p` on the
  lock itself — that atomic create *is* the mutex.

