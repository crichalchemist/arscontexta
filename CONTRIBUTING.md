# Contributing to arscontexta

**This document is executable.** Agents read it and act on it, the same way they act on a
`SKILL.md`. Every claim below is stated as a command with an expected result, or as an invariant
with its failure mode. Do not soften a rule here into advice — advice is not enforceable, and
unenforceable guidance is how every defect in `docs/superpowers/specs/` shipped.

Agent-facing repository architecture lives in [`CLAUDE.md`](CLAUDE.md). Read it first.

---

## INVARIANT 0 — this repo is a generator

Editing a file here changes what *future* generated vaults look like. It does not change any vault
that already exists. A wrong flag in a template is not one broken call; it is one broken call in
every vault generated from it, on machines you will never see.

There is no build, no test runner, no dependency manifest. "Compiling" means Claude reading a
template and writing files. **Do not add** `package.json`, a `Makefile`, or `python3` — `python3`
appears in zero files under `skill-sources/` and in no prerequisite table. `rg` is the blessed
instrument.

---

## Step 0 — verify your environment before you trust any result

Run this first. Every line has an expected result; a mismatch invalidates verification you do later.

```bash
/usr/bin/grep -P . /dev/null 2>&1 | head -1   # macOS: "invalid option -- P"  <- EXPECTED
command -v rg awk sed tree jq bc git zsh      # all eight must resolve
qmd --version 2>/dev/null || echo "qmd absent (semantic checks will WARN)"
git remote -v | rg -c 'upstream'              # expect >= 1 if you forked
```

| Observation | Meaning | Action |
|---|---|---|
| `grep -P` works in the Claude Code Bash tool | you are seeing **ugrep**, not `/usr/bin/grep` | never verify portability from this shell |
| `/usr/bin/grep -P` exits 2 | BSD grep 2.6.0 — what end users have | this is the real target |
| any of `rg`/`tree`/`jq`/`bc`/`zsh` missing | gates will fail or halt | install before proceeding |

---

## The three traps

Each has already produced a confident wrong answer in this repo. Each will do it to you.

### Trap 1 — there is no hot reload

After **any** edit to `skills/`, `skill-sources/`, `hooks/` or `generators/`:

```bash
/plugin uninstall arscontexta@agenticnotetaking
/plugin install arscontexta@agenticnotetaking
```

**Failure mode:** you edit a skill, re-run it, observe no change, and conclude the edit was wrong.
Claude served the cached copy. This is the most common false negative in the repo.

### Trap 2 — `grep` in this session is ugrep

| Where | `grep` resolves to | `grep -P` |
|---|---|---|
| Claude Code Bash tool | ugrep (shell function) | works, exit 1 |
| Any other shell / any end-user machine | `/usr/bin/grep`, BSD 2.6.0 | `invalid option`, exit 2 |

Eight sites shipped with `-P`, each piping into `wc -l`, so the failure rendered as **0 — never as
an error**. It tested clean for everyone who checked from inside a session.

**Rule:** verify with `/usr/bin/grep` explicitly, or from a shell outside Claude Code. Use `rg`.

### Trap 3 — `gh` on a fork silently queries upstream

```bash
gh run list --branch my-branch                              # EMPTY — reads as "never ran"
gh api repos/<you>/arscontexta/actions/runs --jq .total_count   # the truth
```

**Failure mode:** the empty listing is indistinguishable from a clean one. CI was red for two pushes
behind exactly this. **Always pass `--repo <you>/arscontexta`.**

---

## Verification — run all thirteen, expect exactly these results

Twelve run in CI on every push, **most under both bash and zsh**. Three shipped defects were bash/zsh
forks (unquoted word-splitting; `PIPESTATUS` reads empty under zsh); a single-shell run cannot see
either.

**Run all of them, not the one you changed — the gates are not independent.**
`guard-failure.test.sh` *invokes* `check-portability.sh` and builds synthetic minimal roots to
exercise its failure path, so a new check added to the guard changes what every other caller sees. A
check added to `check-portability.sh` and proved non-vacuous against the real repo — but never re-run
through the other three — took `guard-failure` from 19/19 to 16/3, and the assertions it broke were
the ones proving the guard is not vacuous. Loud failure on a legitimately clean tree: the house
defect with its sign flipped.

```bash
bash reference/check-portability.sh ;  echo "expect rc=0, got rc=$?"
bash reference/check-prose-paths.sh ;  echo "expect rc=0, got rc=$?"
bash reference/check-doc-claims.sh  ;  echo "expect rc=0, got rc=$?"
bash reference/check-placeholder-count.sh main ; echo "expect rc=0, got rc=$?"

for s in bash zsh; do
  $s reference/test/link-extraction.test.sh     | tail -1   # expect: passed=19 failed=0
  $s reference/test/guard-failure.test.sh       | tail -1   # expect: passed=55 failed=0
  $s reference/test/fence-isolation.test.sh     | tail -1   # expect: FENCE ISOLATION: PASS
  $s reference/test/bump-version.test.sh        | tail -1   # expect: passed=41 failed=0
  $s reference/test/kernel-note-dirs.test.sh    | tail -1   # expect: passed=54 failed=0
  $s reference/test/threshold-namespace.test.sh | tail -1   # expect: 52 passed, 0 failed
  $s reference/test/placeholder-count.test.sh   | tail -1   # expect: passed=40 failed=0
  $s reference/test/hook-config.test.sh         | tail -1   # expect: passed=56 failed=0
done

./reference/validate-kernel.sh <your-vault>            # expect: every primitive PASSes
```

`validate-kernel.sh` may WARN **only** on primitive 10 (qmd absent) and primitive 8 (self space
disabled). Any other WARN or FAIL is a regression **in this repo** — but read the message first,
because two WARNs described below are properties of the vault being scanned, not of this codebase.

**That is a criterion about primitives, and it deliberately does not quote a total.** An earlier
revision of this line replaced it with one private vault's result-line totals, which is a different
quantity — `CLAUDE.md` explains at length that the summary counts result lines rather than
primitives, that primitive 2 emits two of them, and that the total equalling 15 is a coincidence of
arithmetic. Quoting a measurement here also mints a number no gate can check, because CI has no
generated vault to measure: it would go stale the first time anyone fixed anything in the vault it
described, and stay green. **Read the labels, not the total.**

Two things a real run will show that are not regressions in this repo. A **mature** vault can WARN
on content defects it has accumulated — the maintainer's own vault currently WARNs on primitive 1
(frontmatter coverage) and primitive 2 (unresolved wiki links). A **brand-new** vault can WARN on
primitive 2 for the opposite reason: it has no wiki links yet, and the check reports a resolved
notes directory containing none. Neither is this repo failing; both are the validator describing
the vault it was handed.

**"Green" means all twenty-four CI steps ran and passed** — not that the previously-red step turned.
Verify per-step; a skipped step is not a passing step:

```bash
RID=$(gh api repos/<you>/arscontexta/actions/runs --jq '.workflow_runs[0].id')
gh api repos/<you>/arscontexta/actions/runs/$RID/jobs \
  --jq '[.jobs[].steps[]|select(.conclusion!="success")]|length'   # expect 0
```

---

## INVARIANT 1 — fenced bash blocks are separate shell invocations

Claude runs each ```bash fence in a `SKILL.md` as its own shell. **Nothing crosses a fence
boundary.** A variable from an earlier fence expands to empty rather than erroring, `$(( ))` folds
it to 0, and the block exits 0 with a plausible number.

Four of six blocking findings in one review were this single cause.

- Each fence must define every variable it reads and source every library it calls.
- `reference/test/fence-isolation.test.sh` is the gate. **Do not defeat it** by concatenating fences
  when testing locally — a concatenated harness is more permissive than the runtime.
- A fence that legitimately cannot pass goes in that harness's allowlist **with a stated reason**.
  The allowlist is checked in both directions: an entry that starts passing, or whose fence no
  longer exists, fails the gate. It drains rather than rots.

---

## INVARIANT 2 — a failure must never be a number

The house failure mode is **silence**: exit 0, empty output, a plausible-looking result. Every bash
block you add is presumed guilty of it.

**Required of every block:** on failure it exits non-zero AND emits no digits on stdout.

| Trap | Why it bites | Correct form |
|---|---|---|
| `cmd \| wc -l` | pipeline yields the **last** stage's status, and `wc` always succeeds | check the producer's status separately |
| `[ -d "$d" ] \|\| { echo err; exit 1; } \| head -10` | `\|\|` binds looser than `\|`; the guard body runs in a subshell and `exit` exits nothing | never pipe a guarded block |
| `stat -f %m f \|\| stat -c %Y f` | GNU reads `-f` as *filesystem* status, succeeds, prints `Namelen: 255` — the `\|\|` never fires | put `-c` first; BSD has no `-c` and fails cleanly |
| probing a locale *name* to prove folding works | GNU `tr` is byte-oriented in **every** locale | probe the behavior: fold `U+00DC`, require `U+00FC` |
| checking a binary is on `PATH` to prove its tools resolve | qmd was on `PATH` while all 62 of its call sites named removed tools | assert the names resolve |

**The generalisation, and the one rule to carry:** *verify the property, not a proxy for it.* A check
that passes while the capability is broken is worse than no check — it manufactures confidence.

A fallback only works if its first branch fails **loudly**. If branch one can succeed while being
wrong, the fallback is decorative.

---

## Backporting from the field vault

`~/second-brain` runs this plugin's output daily and finds defects this repo cannot find by
inspection. **Nothing flows back automatically.** `ops/observations/` there is the richest source.

**Two reverse-transforms are mandatory.** Copy-pasting a vault fix into `skill-sources/` is almost
always wrong:

1. **Vocabulary → canonical.** The vault speaks its derived dialect (`extract`, `node`); templates
   speak canonical (`reduce`), per `reference/vocabulary-transforms.md`.
2. **Concrete paths → placeholders.** `nodes/` must become `{vocabulary.notes}`.

Verify you did not hardcode a placeholder — the count must not decrease:

```bash
bash reference/check-placeholder-count.sh main    # rc 0 clean, 1 decrease, 2 cannot conclude
```

**That command replaced an inline copy, and the copy was already wrong.** It matched
`{vocabulary.*}` and `{config.*}` only, while `reference/skill-authoring.md` §2 matches `{DOMAIN:*}`
as well — 488 markers against 616, a gap spanning **nine** `skill-sources/` files. Hardcoding a
`{DOMAIN:notes}` produced **no output at all** from the check documented here, while the three-family
pattern reported `27 -> 21` on the same tree. Both probes are recorded in the script's header. Two
spellings of one command is the drift hazard, and this pair had already drifted; the script is now
the single definition.

Only `skill-sources/` carries placeholders you may edit; `skills/` are the plugin's own commands and
legitimately have none, so scanning them produces `0 -> 0` noise. A count that *rises* is normal —
the hybrid qmd query form repeats its query string into both `lex` and `vec` sub-queries, so one
placeholder legitimately becomes two.

`platforms/shared/skill-blocks/` also carries placeholders — more of them than `skill-sources/`
does — but it is **frozen**: nothing generates from it, and `check-portability.sh` check 4 rejects
any edit. It is dropped from the scan above because it can no longer appear in a diff. Consult it
when you need to know whether a string is vocabulary-variable; see
`platforms/shared/skill-blocks/README.md`.

**Failure mode:** a backport that skips these passes every gate and silently ships one user's
vocabulary to everyone.

---

## Prose is a contract

When you change a bash block, change the prose table that describes it **in the same commit**.
Claude reads those tables and follows them, so a narrow table beside a widened bash line is the same
defect in a different font. Six code sites and four prose contracts had to move together to make one
threshold fire.

---

## Specs, plans, commits

Substantial work goes **spec → plan → execution** in `docs/superpowers/`. Execution ledgers live
under `.superpowers/sdd/` — **git-ignored, therefore working notes and never the record.** This
sentence used to end "and are the authoritative record", and that was a false licence: it told
contributors that a directory `git check-ignore` rejects was where findings belonged. Two commits
took it at its word (`741b2b7`, `c122d9e`), each claiming in its message that something was
"recorded" when the only copy was in scratch. Neither author was confused about `.superpowers/`
being ignored; the tracked guidance had said that was fine.

**Where a record actually goes:** `CLAUDE.md`'s divergence list for a defect that survives the
branch, the plan's `## Deferrals` section for work consciously not done, the spec for a decision.
**Plans from this branch forward** carry a required `## Deferrals` slot whose value is either one
line per deferral naming the tracked file it landed in, or the literal word `none` — an empty slot
is a failure, not a default. The slot exists because the two failures above were not caused by
anyone forgetting the rule, so another statement of the rule could not have prevented them; what was
missing was a place in the artifact where the omission is *visible*.

**Expect to find plans without one — that is the convention's age, not its optionality.** Two of the
eight plans carry the slot today; the six older ones predate it and are deliberately left alone,
because writing `none` into a plan nobody has audited for deferrals manufactures the very kind of
record this section exists to prevent. Copy the convention from the newest plan, not from whichever
one you happen to open:

```bash
for p in docs/superpowers/plans/*.md; do
  printf '%s  %s\n' "$(grep -c '^## Deferrals' "$p")" "$(basename "$p")"
done
```

Nothing enforces this. A gate keyed on plan structure is the one viable candidate and is deferred to
`docs/superpowers/plans/2026-08-04-ci-hardening.md`; until it exists, the slot propagates because the
next author copies the last plan.

**Keep plan checkboxes honest.** Two plans here once showed 0 of 93 steps complete while fully
executed and merged. A status file that lies about status is this project's own defect class wearing
a different hat. Tick as you go, or delete the checkboxes and point at a **tracked** record — a
completion note in the plan itself, or the divergence entry in `CLAUDE.md`.

This sentence used to end "point at the ledger", which contradicted the paragraph above: ledgers
under `.superpowers/sdd/` are git-ignored, so pointing a status file at one reintroduces exactly the
defect that paragraph exists to prevent. A remedy that routes the record somewhere it cannot ship is
not a remedy. Ticking a box means the step was **executed** — where the outcome was a measured
rejection rather than a change (this plan's Step 2.2 gate, assessed and declined on 1 true positive
against 2 false positives), the rejection and its measurement are recorded in the file the step
names.

Commit messages state **what the failure looked like**, not just what changed. "Fixed grep" is
useless; "the failure surfaced as 0, never as an error, because every site piped into `wc -l`" tells
the next reader how to recognise it.

### Before opening a PR

```bash
bash reference/check-portability.sh && echo OK                       # rc 0
for s in bash zsh; do
  $s reference/test/link-extraction.test.sh | tail -1
  $s reference/test/guard-failure.test.sh   | tail -1
  $s reference/test/fence-isolation.test.sh | tail -1
done
git diff --stat main..HEAD                                           # review every line

# Scan changed files for PCRE. Three separate hazards are handled here; removing
# any one of them makes this silently report "clean" while having scanned nothing.
#   1. NUL-delimited — one tracked filename contains spaces, and
#      $(git diff --name-only) word-splits it into nine phantom paths.
#   2. Per-file, NOT piped through xargs — xargs COLLAPSES rg's exit 2 (error)
#      into 1 (no match), so a failed scan becomes indistinguishable from a clean one.
#   3. worst-status tracking — one bad file must not be masked by later good ones.
worst=1
while IFS= read -r -d '' f; do
  [ -f "$f" ] || continue                    # deleted file is not an error
  rg -n 'grep -[a-zA-Z]*P' "$f"; rc=$?
  [ "$rc" -eq 0 ] && worst=0
  [ "$rc" -gt 1 ] && worst=2
done < <(git diff --name-only -z main..HEAD)
case $worst in
  0) echo "PCRE FOUND — fix before PR" ;;
  1) echo "no PCRE introduced" ;;
  2) echo "SCAN FAILED — this result is NOT evidence" ;;
esac
```

**Why this shape, and what it cost to get right.** `rg` exits 0 on match, **1 on no-match (which is
normal)**, and 2 on error. The first draft of this block was `rg … $(git diff --name-only) || echo
"no PCRE introduced"` — it word-split the one filename containing spaces, rg failed to open nine
phantom paths, and the `||` printed the all-clear **having scanned nothing.** The second draft piped
through `xargs -0`, which fixed the splitting and then collapsed exit 2 into exit 1, so the error
branch became unreachable. Measured, on this machine:

| | rg direct | through `xargs -0` |
|---|---|---|
| match | 0 | 0 |
| no match | 1 | 1 |
| **missing file** | **2** | **1** ← the distinction is destroyed |

Any check you add here must distinguish those three states, and you must *verify* it can reach each
one. A scan that cannot report failure will eventually tell you the repo is clean because it
crashed — which is INVARIANT 2, in the file that states INVARIANT 2.

Branch from `main`. All twenty-four CI steps must pass. State in the PR what is **not** claimed —
deferred items belong in the description so a reviewer meets them as decisions, not omissions.
