# Verification

> Split out of the repo root `CLAUDE.md` on 2026-08-23, because the harness auto-loads
> only the first ~40,000 characters of a CLAUDE.md and the file had reached 112,522
> bytes. The body below is the moved section — byte-identical at the split except for
> the edits enumerated in `docs/superpowers/specs/2026-08-23-claude-md-split-design.md`
> §7. "Divergence N" refers to the numbered entries in `docs/open-divergences.md`.
> Every fence assumes cwd = repo root, exactly as it did before the move.
> `reference/check-doc-claims.sh` reads this file by text anchor: do not reword a
> sentence carrying a number without running that gate.


### Verification

There are eighteen executable checks. Sixteen run in CI (`.github/workflows/checks.yml`) on every push.
Three defects shipped here were bash/zsh forks, so **the eleven test suites each run under both
shells** — but read the paragraph below the table before treating that as "everything is tested
under both": `check-portability.sh` itself runs bash-only, and one suite's zsh run exercises the
harness rather than its subject.

```bash
bash reference/check-portability.sh                      # exit 0
bash reference/check-prose-paths.sh                      # 0 missing (path count drifts)
bash reference/check-doc-claims.sh                       # exit 0 (declared claims only)
bash reference/check-placeholder-count.sh main           # exit 0 (1 = a template lost placeholders)
bash reference/check-vocabulary-schema.sh                # exit 0 (1 = an undeclared key; also runs under zsh in CI)
bash reference/test/check-doc-claims.test.sh              # bash-only (see the suite's own header); 13/13
for s in bash zsh; do
  $s reference/test/link-extraction.test.sh              # 101/101
  $s reference/test/guard-failure.test.sh                # 66/66
  $s reference/test/fence-isolation.test.sh              # PASS
  $s reference/test/bump-version.test.sh                 # 41/41
  $s reference/test/kernel-note-dirs.test.sh             # 76/76
  $s reference/test/threshold-namespace.test.sh          # 57/57
  $s reference/test/placeholder-count.test.sh            # 40/40
  $s reference/test/hook-config.test.sh                  # 60/60
  $s reference/test/vocabulary-schema.test.sh            # 12/12
  $s reference/test/queue-edit.test.sh                   # 77/77
  $s reference/test/moc-sync.test.sh                     # 68/68
done
```

**`queue-edit.test.sh` is green: 77/77, both shells.** It was RED ON PURPOSE for one branch — three
of its assertions pinned an open defect before the fix landed, the only order in which a test can be
shown to fail for the stated reason. `reference/lib/queue-edit.sh` used to end `mv "$tmp" "$file"`
with no `||`, so a rename that failed left the temp on disk, printed nothing, and returned the exit
status of the following `rm -rf` — 0. The commit step is now guarded: a failed rename returns 1,
discards its temp, and names the path that could not move — the `bump-version.sh` remedy verbatim.
The rename failure is forced with a shell-function stub, because a genuine same-directory `mv`
failure needs `chflags uchg` or `chattr +i` and is not portable to CI; the mechanism is covered, the
organic trigger is hand-run only, and that is not the same claim.

**`QUEUE_EDIT_VERSION` is 2 — bumped from 1 by task 12a on this branch — and until now this file
never named it.** `LINK_EXTRACTION_VERSION` (4) and `FRONTMATTER_VERSION` (3) are the library
versions this file already tracks; this is the third, added for the ported YAML write path the
paragraph above describes. Seven fences across five `skill-sources/` templates (`next` ×3, `reduce`,
`reflect`, `reweave`, `verify`) guard `[ "$QUEUE_EDIT_VERSION" -lt 2 ]` before calling `queue_yaml`.
`skills/health` checks all four libraries through one shared `check_lib` helper whose floors are
per-library and derived from the consumers' own guards — queue-edit 2, link-extraction 4,
frontmatter 1, moc-sync 1. That REVERSES the ruling this paragraph used to record ("THE FLOOR IS 1 AND STAYS
1", a task-12a reviewer ruling): the final whole-branch review measured that ruling against the
floors this same branch raised and found `/health` vouching at 1 for libraries the skills refuse
to run below 2 and 4 — a vault on queue-edit v1 had every queue write exiting 1 while Category 9
printed `PASS … queue-edit v1` beside them. The half of the old ruling that survives: a floor is
a consumer guard, never the library's current version, so a stale-but-working copy above its
floor still PASSes (frontmatter has no versioned consumer guard, so its floor stays 1). The same
fix added the check the version constant cannot carry: a v2 `queue-edit.sh` without its
`queue_edit.py` companion FAILs, because the split reads version-healthy while every YAML queue
write fails at run time.

```bash
/usr/bin/grep -n 'QUEUE_EDIT_VERSION=' reference/lib/queue-edit.sh                       # 2
/usr/bin/grep -rc '\-lt 2 \]' skill-sources/ | /usr/bin/grep -v ':0'                      # 3,1,1,1,1 = 7
/usr/bin/grep -n 'FLOOR IS PER-LIBRARY' skills/health/SKILL.md                            # the superseding comment
/usr/bin/grep -c 'queue_edit\.py' skills/health/SKILL.md                                  # non-zero: the companion check
```

| Gate | What only it can catch |
|---|---|
| `check-portability.sh` | seven checks: `grep -P`; wiki-link capture that omits the `\|`/`#` terminators; `rg -P`; modification of the frozen `skill-blocks/` manifest; `AGENTS.md` not being a symlink; a wiki-link matcher that interpolates a note name into its pattern (check 6, allowlisted bidirectionally); and a hand-rolled frontmatter parse outside `reference/lib/frontmatter.sh` — a line-anchored `'^field:'` grep used to select notes, which matches the BODY too (check 7, allowlisted bidirectionally, **born red at 72 sites across 26 files** — 72 matching lines carrying 72 field references across 16 distinct names, three quantities the check's own header decomposes with a re-derive command that uses its detector rather than a looser one, because the first attempt published a command yielding 17 and contradicting the gated 71 — so green means "no NEW one" and never "none exists"). Its first version required a flag between the command and the pattern and so reported **39**, missing `rg '^status: open' dir/` entirely — including a line named as an open instance in `docs/open-divergences.md`. Scope is declared in the check and excludes `methodology/`, whose 87 further sites are illustrative prose inside research claims that neither run nor compose into a vault |
| `link-extraction.test.sh` | library behavior, incl. "a failure must never be a number" |
| `guard-failure.test.sh` | the guard's own failure path |
| `fence-isolation.test.sh` | a fence reading a variable or sourced function from a **different** fence; (assertion F) a frontmatter parser that reads the body, or ignores the field name it was given; and (assertion M) `mechanically_compare` substituting the installed side as well as the canonical side, which silently launders a real divergence into false agreement — caught via a fixture built on the real `topic_map`/`hub` vocabulary collision, the specific pair that makes symmetric substitution wrong |
| `bump-version.test.sh` | the release tool's failure paths — a `MISSING` row summarised as agreement, jq's `"null"` accepted as a version, a failed audit scan read as "all clear", and a bump that moves some declared sites and not others (including two fields of the *same* file, which no file-to-file comparison sees) |
| `check-prose-paths.sh` | prose naming a repo path that does not exist **in this checkout**. Read its banner: it does *not* check the packaged plugin, and prints that every run |
| `hook-config.test.sh` | the only gate that executes `session-orient.sh` or `vaultguard.sh` at all. Before it, three of five hook scripts could be broken with every other gate green, and `session-orient.sh` had only TEXTUAL coverage — `threshold-namespace` checks that it NAMES its config key, so a break that keeps the name and ignores the value passes there (57/0) and fails only here. Measured by mutation, one script at a time. An unparseable config value silently becoming the default, and `session-orient.sh` ignoring its configured threshold, are the two defects divergence 3 documents; `vaultguard.sh` decides whether **every** plugin hook runs, so inverting its inertness fires auto-commit in every repo the plugin is installed in |
| `check-placeholder-count.sh` | a backport that HARDCODED a vault's vocabulary into a `skill-sources/` template — `nodes/` where `{vocabulary.notes}` stood — shipping one user's dialect to every future system. The only gate that reads a git range, so CI needs `fetch-depth: 0`; it exits 2, not 0, where the merge base is unreachable |
| `kernel-note-dirs.test.sh` | the kernel contract reading the vault it was handed — a validator scanning canonical directory names a generated vault renamed, and a check that never ran reported as anything softer than FAIL. The only gate that executes `validate-kernel.sh` |
| `threshold-namespace.test.sh` | two config namespaces declaring the same threshold, so a vault's own tools disagree about whether it is time to run `/rethink`; and a consumer reverting to the legacy key. The only gate that executes `read_config.sh`, which had no coverage at all before it |
| `check-doc-claims.sh` | a number a document DECLARES going stale — including on MERGE, where nothing in a working tree changes and there is no diff to notice. Also the only gate reading `generators/`: the note `status` enum is declared **four times across three files** (`schema.md` declares it twice, once in a table and once in `_schema`), and a file-to-file comparison cannot see those two disagree — the blind spot `bump-version.test.sh` exists for, one tree over. It compares the VALUE SET, never the text, because the same enum is legitimately spelled three ways. It also checks the tension enum against its three consumers, which is the half that is checkable for an enum declared only once: a recipe matching a value the enum dropped returns 0 forever. **What it cannot cover:** the observation enum, declared once with no consumer inside `generators/` — its consumer is the SessionStart hook, in another tree. Declaration counts are PINNED, because discovery keys on an anchor value and a declaration that drops the anchor stops being discovered; three survivors agreeing would otherwise read PASS |
| `queue-edit.test.sh` | the only gate that executes `reference/lib/queue-edit.sh` — a shared library with seven consumers that had no test at all, which is how its commit step shipped unguarded. It pins the lock contract the library's header argues for and asserts nowhere: that a bounded wait failing does **not** break the lock it could not take (an auto-break wearing a failure message), that a rejected filter leaves the queue file byte-identical and releases the lock, and that jq arguments reach the filter rather than being silently dropped — the last of which returns 0 while writing nothing; and that a failed commit-step rename returns 1, discards its temp, and names the path — see the paragraph above the table. Since v2 (task 12a) it also pins the ported YAML write path: `queue_edit` refuses a `.yaml` target naming `queue_yaml` as the remedy, and `queue_yaml` edits surgically (one changed line, folded scalars untouched), fails loud on a zero-match `--where` — the silence that left seven fences dead for a month — and shares the same lock and guarded-rename contract |
| `moc-sync.test.sh` | the only gate that executes `reference/lib/moc-sync.sh` — a derivation whose failure mode is a *plausible* MOC: correct headings above silently missing notes. It pins all four unplaceable-note reports (entry whose note is gone, unreadable status, off-map status, divergent summary — the field vault holds 16 notes that any one of the three competing section maps would have dropped), that a divergent summary survives byte-identical (~40 entries would otherwise be destroyed), that a render failure leaves the target intact rather than replacing it with a header at rc 0, and idempotence in BOTH senses — byte-identical consecutive runs, and an identical body from reordered input, which a "preserve order and append" implementation passes on the first and fails on the second. It also pins the report-once guard against a map whose statuses share a section name, the case where guarding on the section NAME rather than the iteration index reports every unplaceable note once per colliding section |

**None of these gates asserts that a computed number is correct.** They assert that a fence runs, is
self-contained, does not read across a fence boundary, and fails loudly on a missing vault. Whether
the number it prints is *right* is not checked by anything here.

**Nor does any gate enforce "do not inline the link library's functions."** That row used to claim
`check-portability.sh` catches inlined copies, and `reference/lib/link-extraction.sh` said the same in
its header. Both were false — the seven checks are enumerated above and only check 7 looks for an inlined copy, of the FRONTMATTER library and not this one. Check
6 is not that gate either, and the distinction is the one divergence 13 draws: it forbids
*interpolating* a note name into a matcher, while the inlined sites spell `rg -o '\[\[([^\]|#]+)'` and
interpolate nothing, so they are correctly outside it. The
cost was not hypothetical: inlined matchers sat in five `skill-sources` fences through four gates, a
127 KB review and a live vault run, and the commit that removed them added a *sixth* inlined
extraction (`skill-sources/graph/SKILL.md`, the `rg -o` edge builder) which likewise passed every
gate. The rule is real and still binding; it is convention, not enforcement.
See divergences 12 and 13 in `docs/open-divergences.md`.
Building the missing check is a gate-design question and belongs to the CI-hardening spec — do
not bolt it on here.

That is not a small caveat, because it is where this repo's defects actually live. Every correctness
defect fixed on the branch that added this paragraph — the claim counter truncating at three digits,
`/next` promising eight state fields and computing five, the padding — **passed every gate in both
shells before and after the fix.** A green run means "no fence is silently broken", never "the
arithmetic is right." Correctness rests on review, and the gate set does not substitute for it.

Building the missing gate means per-fence expected-output fixtures — a project, not a task. Until it
exists, this paragraph is the honest form of the inventory, in the same spirit as
`check-prose-paths.sh` printing its own limits on every run.

**One suite hardcodes a shell and one does not, and the distinction is the invocation surface —
not the shebang.** `guard-failure.test.sh` always invokes the guard as `bash "$GUARD"` because
*nothing* invokes `check-portability.sh` by any other name: CI, `.pre-commit-config.yaml` and this
file all spell `bash reference/check-portability.sh`, and an assertion fails if a caller ever stops
doing so. Running it under zsh would exercise a configuration that does not occur. Its zsh run
therefore tests *the harness's own* portability, not the guard's.

A shebang alone would not have justified that: `scripts/bump-version.sh` also carries a bash shebang
and is also run as `bash …` in CI, and it shipped a zsh fork anyway, because a human typed
`zsh bump-version.sh`. So `bump-version.test.sh` makes the opposite call and runs the script under
whichever shell the harness is in. `kernel-note-dirs.test.sh` follows `bump-version`, for the same
reason and one more: this file documents `./reference/validate-kernel.sh <vault>`, which is a
shebang invocation a user can just as easily spell `zsh reference/validate-kernel.sh`, and the
resolver it tests deliberately avoids a `"$dir"/*/` glob because zsh's default `nomatch` makes an
unmatched glob an error rather than an empty list. Pinning that suite to bash would have left the
one decision it exists to protect unexercised. The fence gate is the one suite that genuinely runs
the same code under both, because Claude really does invoke those fences under whatever shell the
user has.

**The fence gate exists because Claude runs each ```bash fence in a SKILL.md as its own shell
invocation.** A variable from an earlier fence expands to empty rather than erroring, `$(( ))` folds
it to 0, and the block exits 0 with a plausible number. It extracts 80 fences from 27 files,
substitutes vocabulary placeholders, and runs 77 of them standalone against a healthy fixture and a
missing-vault fixture — printing the 3 it skips and the stated rule each fell under, because a
silently skipped fence is the same defect class the gate exists to catch. Read the run count and the
extracted count as two numbers: this sentence said "extracts all 75", which is the run count wearing
the extraction label, and a skip rule that quietly began matching a fourth fence would not have
moved it. It supplies `ARGUMENTS` so the healthy fixture models a healthy *invocation*
and not merely a healthy vault. It carries an allowlist of known-open defects — now 4, and the
composition carries the meaning rather than the total: two `ZSH ONLY:` entries against assertion H
(the non-matching-glob fork, down from 8 such at its peak) and two shell-agnostic entries against
assertion N — **checked in both directions**: a listed entry that starts passing, or whose fence no
longer exists, fails the gate, so the list drains rather than rots. The seven shell-agnostic
assertion-H queue entries the list carried from 2026-08-11 (`skill-sources/next` f01-f03, `reduce`
f03, `reflect` f06, `reweave` f04, `verify` f01 — each calling `queue_edit` on the
`ops/queue/queue.json` tombstone) drained on 2026-08-15, in the same commit that repointed those
seven fences: they now detect the queue via the `ops/queue.yaml` → `ops/queue/queue.yaml` →
`ops/queue/queue.json` search order and write YAML through `queue_yaml`, the field-proven write path
ported into `reference/lib/queue-edit.sh` v2 (task 12a's ruling). That port is also why `python3`
joined the gate's asserted tool set and the README prerequisite table below.

**That sentence read "now 2, both zsh-only" from 2026-08-02 until 2026-08-08**, while the
vocabulary-schema work added the two N entries and merged. It is an ungated prose numeral of exactly
the class the divergence list (`docs/open-divergences.md`) is about, sitting in the paragraph that explains the mechanism
built to stop entries rotting — the mechanism drained the list correctly; the prose describing it
did not follow.

**It then read "now 4" from 2026-08-08 until 2026-08-11**, when `fix/post-merge-hardening` added the
`queue_edit` precondition described above and the healthy fixture's legitimate coexistence of
`queue.json` and `queue.yaml` turned seven fences red against assertion H. Same class of drift as the
line above, recorded rather than silently corrected. **It read "now 11" from 2026-08-11 until
2026-08-15**, when task 12a's port drained those seven — that move is a fix landing with its own
count, not drift, and it returns the total to a coincidental 4 whose composition differs from the
2026-08-08 "now 4": read the composition, not the number.

**Re-derive it, and do not read the gate's own `known-open=` as the table size — it is SHELL-SCOPED.**
The header counts entries in scope for the shell running it, so the same unchanged table reports
`known-open=2` under bash and `known-open=4` under zsh: the two `ZSH ONLY:` entries are correctly out
of scope under bash. A reader taking either number as "how many known-open defects are there" gets a
different answer depending on which shell they happened to run, and both look authoritative. Count
the table for the total; run both shells for the split:

```bash
# 5 = 4 table entries + 1 comment line, the one documenting the fabricated
# `.probe-skill f01~H~` absorption probe. Stated as a sum rather than filtered with
# an exclusion, per the idiom divergence 12 uses: an exclusion rots silently and can
# quietly match nothing, whereas a sum fails loudly the moment it stops adding up.
/usr/bin/grep -c '~[A-Z]~' reference/test/fence-isolation.test.sh                    # 5 = 4 + 1
bash reference/test/fence-isolation.test.sh 2>&1 | grep -m1 -o 'known-open=[0-9]*'   # 2 — in scope for bash
zsh  reference/test/fence-isolation.test.sh 2>&1 | grep -m1 -o 'known-open=[0-9]*'   # 4 — in scope for zsh
```

It also carries one assertion that is **not** about fences: **F**, which runs once against a
four-note discriminating set and pins `reference/lib/frontmatter.sh` three ways — correct parser 2,
naive `grep -rl '^status:'` 1, wrong-field parser 4. It lives here rather than in a standalone
frontmatter test suite of its own because a suite wired into neither CI nor the table above is a
green-looking nothing, and this gate is already wired into both.

That two-directional check had a hole in it, now closed: absorption matched on `(letter, label)`
alone and ignored the entry's `ZSH ONLY:` / `BASH ONLY:` scope, while the staleness half honoured it.
A `ZSH ONLY:` entry therefore swallowed a **bash** failure on the same fence and the gate printed
PASS. Both halves now call one `in_scope` predicate — re-deriving the condition at the second site is
how they came apart. What remains, by choice: absorption still keys on `(letter, label)` *within* a
shell, so a listed fence failing for a different reason in its own shell is still absorbed. The gate
now prints the **measured** failure beside the entry's stated reason, so the two disagreeing is
visible rather than silent. Keying absorption on the message was rejected — it would couple every
entry to the gate's own wording, so rewording a message would turn all entries stale, a new trap
inside the mechanism built to drain them.

The eighth check is kernel validation, which does **not** run in CI, because it needs a
generated vault to run against. It is no longer the only one: `reference/test/check-doc-claims.test.sh`
is also not CI-wired, deliberately — a step there would also move the gated CI-step counts below,
including the one that compares against `main` and rots on merge with no diff to notice. "Eighth"
is stale numbering, kept because renumbering it is out of scope here, not because only one check
sits outside CI:

```bash
./reference/validate-kernel.sh /path/to/generated-vault
./reference/validate-kernel.sh ~/second-brain     # the live instance
```

Pass criterion is 16/16 primitives PASSing — sixteen, not the fifteen the highest header number
suggests; see below. `WARN` is acceptable **only** for primitive 10 (semantic search,
when `qmd` is absent) and primitive 8 (self space, when disabled by config). Any other WARN or
FAIL is a real regression.

**One check in that run is NOT a primitive and is labelled `C1.` rather than numbered.** It asserts
that an outcome status names a target — `implemented` carries `implemented_in:`, `promoted` carries
`promoted_to:` — and it is the first conditional-field assertion in either tree. It is deliberately
outside the numbering because it is not in `kernel.yaml` and has no `cognitive_grounding`; numbering
it 16 would make the contract look like it declares something it does not. It emits one result line,
so it moves the totals without moving the primitive count — which is the third distinct number in
this paragraph and the reason to read labels rather than totals. `C1` may WARN for one stated
reason: a vault with no `ops/observations/` or `ops/tensions/` has not enabled self-evolution, so
the rule does not apply. That WARN is *not* a soft pass and is not a fourth exception to the
criterion above — the criterion is about primitives, and `C1` is not one. Full test specs live in `reference/testing-milestones.md`.

**Measured against the live vault, that criterion is violated by two items — and one of them only
became visible when a check stopped sampling.** Re-measured on `fix/exhaustive-dangling-scan`:
`15 PASS / 2 WARN / 1 FAIL` — 18 result lines, exit 1. Primitives 8 and 10 both PASS there.

**The FAIL is `C1`, and it is the check working rather than a regression.** `13 of 34 outcome-status
notes name no target`. Spec H predicted **6**, and the difference is scope rather than drift: the
spec measured `implemented` observations only, while `C1` covers all four (directory × status)
pairs, so `13 = 6 implemented + 7 promoted`. `promoted` is the worse half by a wide margin — it
misses its field 7 times in 8, against 6 in 26 for `implemented` — which is why covering only the
status the spec happened to name would have left the larger violation unmeasured. Both figures are
field-vault content defects, not defects in this repo, and they drift; re-derive with the command
below rather than quoting them.

**The two survivors are primitive 1, frontmatter coverage — `5128 with YAML, 163 without` — and
primitive 2, `8 unresolved wiki links out of 2716 unique checked`.** Neither is on the list of
primitives permitted to WARN, so by the criterion above both are real findings. Both are content
defects in the field vault rather than defects in this repo, which is why they are recorded here
rather than fixed. **All four figures in that sentence are live-vault measurements and drift as the
vault grows** — the one command below re-derives every one of them, since it prints each result line
in full; do not quote them without running it.

**Primitive 2's WARN is not the one this file used to describe, and the label is the same in both
directions — read the message, not the level.** The old WARN meant *the check did not run*: it
printed `No wiki links found to check` beside a PASS, on a vault whose directories it had failed to
resolve. That one is gone and stays gone. The current WARN is its opposite: an exhaustive scan ran
and found eight genuinely unresolved targets. A previous revision of this paragraph said "the
dangling-link WARN is gone because that check now runs" — true when written, and it would now be
read as covering a WARN that means something else entirely.

**The criterion and the summary count different things, which is what made the labels skippable.**
"16/16" is primitives; the summary counts *result lines*. On the field vault there are 16 primitives,
16 numbered headers and 18 result lines — primitive 2 emits two, and `C1` adds one that belongs to
no primitive at all. **The headers run 1–15 with
one spelled `10A`, so the highest number is 15 and the COUNT is 16** — `unique-addresses` is a full
primitive in `kernel.yaml` (its own id, layer, validation and grounding) that was folded into 10's
number rather than renumbering the rest. This file said "15 primitives" for exactly that reason: the
largest label was read as the total. So `PASS: 15`
is simply `18 − 2 − 1` — it is not independent evidence that fifteen primitives passed, and it would
read `18` if both WARNs and the FAIL cleared. It has now equalled the target number `15` **three
times, for three unrelated reasons**: as `15 − 0` when the scan resolved nothing, as `17 − 2` once
the dangling scan ran, and now as `18 − 2 − 1` with `C1` added. Three different arithmetics landing
on the same number is not corroboration — it is the same coincidence recurring, and the third
instance arrived within a day of the second. **Read the labels.**

Re-derive every number above with — it prints each result line, so the totals, the frontmatter
counts and the dangling counts all come out of this one run:

```bash
./reference/validate-kernel.sh ~/second-brain 2>&1 \
  | sed "s/$(printf '\033')\[[0-9;]*m//g" | grep -E '^ +(PASS|WARN|FAIL) '   # 18 result lines
```

**The blind spot that used to be here is closed.** Primitive 10 once checked only that `qmd` was on
`PATH`, which is why 62 references to qmd tools removed from its MCP surface survived across 20
files while the validator reported semantic search satisfied — qmd was on `PATH` the whole time. It
now asserts that the declared tool names resolve, scanning the vault's **live** surface (`.claude/`,
`.agents/`, `.mcp.json`) rather than the whole tree: `ops/skills-archive/` and `ops/changelog.md`
legitimately record retired names, and failing on those would make the check unfixable without
rewriting history. *qmd absent* stays WARN; *qmd present but declaring names that do not resolve*
is FAIL.

`tree` and `ripgrep` are required (per the README's prerequisite table) — by generated systems at
runtime and by `validate-kernel.sh` here. Fences additionally invoke `awk`, `sed`, `jq`, `bc`,
`git` and — since queue-edit v2's `queue_edit.py` (task 12a) — `python3` with PyYAML; the fence
gate asserts their presence (including a PyYAML import probe) and halts loudly rather than letting
a missing tool's 127 read as a defect.

**Those seven and the README's prerequisite table are now deliberately the same set** — that sentence
used to read "which are **not** in that table", and the table has since been widened to cover every
tool the gate asserts. The relationship, not either list alone, is what to check when one side moves.
The table carries **8** shell-tool rows rather than 7: the decomposition is `8 = 7 gate-asserted +
tree`, `tree` being a SessionStart-hook dependency that no fence invokes. Stated as a sum rather than
as a `grep -v tree` exclusion, per the idiom divergence 12 already uses — an exclusion rots silently
and can quietly match nothing, which this repo has shipped twice. (The first command's character
class carries a `3` because `python3` does; the old `[a-z ]*` would silently truncate the very
token this port added.)

```bash
grep -o 'for t in [a-z3 ]*' reference/test/fence-isolation.test.sh   # rg awk jq bc git sed python3
grep -cE '^\| `(ripgrep|awk|sed|jq|bc|git|tree|python3)' README.md   # 8 = 7 + tree
```

