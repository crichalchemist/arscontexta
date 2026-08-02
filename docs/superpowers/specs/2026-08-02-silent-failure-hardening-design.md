# Spec A2 — Silent-failure hardening

**Date:** 2026-08-02
**Status:** draft, not yet approved
**Predecessor:** `2026-08-01-portability-link-correctness-design.md` (branch `fix/portability-link-correctness`, 14 commits, **unmerged**)
**Evidence:** `.superpowers/sdd/2026-08-01-portability-link-correctness/FINAL-REVIEWS-CONSOLIDATED.md` — three independent whole-branch reviews (opus ×1, fable ×2), all blocking

## Why this spec exists

Spec A set out to eliminate one failure class: **a failure that produces a plausible-looking
number instead of an error.** It fixed twelve sites and added a guard and CI.

Three final reviews found the class was reduced but not eliminated — and reintroduced in three
places, including inside the guard written to prevent it. Ten distinct instances are now
catalogued; five remain open. The predecessor branch is correct in its extraction logic (verified:
the old code would report 83 false FAILs on the bundled 249-note `methodology/` graph where the
true count is 0) but the plumbing around it is not.

**The lesson driving this spec:** point fixes do not eliminate a failure class. Every fix so far
was verified by a check the same author designed, and the class kept reappearing through mechanisms
nobody had thought to check. This spec targets the *conditions* that let it reappear, not another
list of sites.

## Three themes

Everything below serves one of these. A change that fits none of them is out of scope.

1. **The guard must actually guard.** It currently passes when its own scan fails, and covers a
   third of the shipped surface.
2. **Failure must propagate.** Dependency and runtime errors are converted to `0` at four layers.
3. **Behavior must be tested, not asserted.** CI executes no library code, which is why three of
   these findings shipped.

## Phase 1 — Guard integrity (blocking)

### 1.1 Guard must fail when its own scan fails
`reference/check-portability.sh:27,36-38`. `hits=$(... 2>/dev/null || true)` makes grep's exit 2
(missing scan dirs, bad `$1` root, `/usr/bin/grep` absent on NixOS/Alpine) indistinguishable from
"no matches."

Reproduced: `bash reference/check-portability.sh /nonexistent-root-xyz` → `PORTABILITY: PASS`, exit 0.

Required: capture grep's rc; `rc > 1` is an error, not a clean scan. Assert every scan directory
exists before scanning. A guard that cannot distinguish "nothing wrong" from "I could not look" is
the branch's own bug class applied to the branch's own protection.

### 1.2 Guard must scan every shipped directory
`check-portability.sh:21` scans `skills`, `skill-sources`, `reference`. Also shipped:
`generators/`, `platforms/`, `presets/`, `hooks/`, `agents/`, `scripts/`.

A live instance of the defect sits in one it misses —
`generators/features/maintenance.md:29`:
`rg -o '\[\[([^\]]+)\]\]' {DOMAIN:notes/} -r '$1'` — naive capture, in a generator that writes
maintenance instructions into every generated vault. The guard would have caught it verbatim.

Required: extend SCAN to all shipped directories; fix the site it then flags. Expect other
pre-existing hits — triage them, and where any are deliberately deferred, list them explicitly in
the guard rather than by omission.

### 1.3 Close guard evasion vectors
- `grep --perl-regexp` passes **both** checks (no uppercase `P` after a `-`) — and it is exactly
  the BSD-exit-2 bug class.
- `egrep -oP` evades check 1.
- `rg -P` / `--pcre2` uncovered; fails on rg builds without PCRE2.
- Check 2's exclusion filters by **line content**, so any naive capture on a line that mentions
  `lib/link-extraction.sh` (e.g. a trailing comment) is invisible.
- Check 2 requires a negated class, so `rg -o '\[\[.*?\]\]'` passes clean.

## Phase 2 — Failure propagation (blocking)

### 2.1 Remove `2>/dev/null` from library rg calls
`reference/lib/link-extraction.sh:48,67,94,112`. `command -v rg` proves existence, not health.
Reproduced with a broken `RIPGREP_CONFIG_PATH` (a common real user setting): rg exits 2 on every
call, `count_links → 0` rc=0, and validate-kernel degrades to "No wiki links found to check",
exit 0, stderr clean. The redirect protects nothing — rg's no-match exit 1 is silent.

### 2.2 `skill-sources/stats/SKILL.md:87` — reintroduced instance
Inline `rg ... 2>/dev/null` bypassing the library's fail-loud check → `TOPIC_COUNT=0`, exit 0, no
stderr when rg is absent (verified: 0 vs 2). It is also the only site that dropped the plan's
trim + case-fold, so `[[Hub-Topic]]` and `[[hub-topic]]` count as two topics. Route it through the
library.

### 2.3 Errors must propagate past command substitution
Every consumer does `VAR=$(count_links ...)`. The function's `return 1` is discarded and the block
continues, rendering `Dangling: 0` after a dependency error. "Fail loud" currently stops at the
library-source check.

### 2.4 Validate directory arguments
No library function validates `$dir`. A nonexistent directory is indistinguishable from an empty
vault: stats renders `Connections: 0  Dangling: 0`; health emits nothing and renders PASS
"All links resolve". A failed `{vocabulary.notes}` substitution therefore produces a plausible
healthy report.

### 2.5 Fix `count_links_recursive`
`link-extraction.sh:82`. **Shell-dependent, not merely broken**: bash → `0`, zsh → `9` (correct).
The `while` is the last stage of a pipe, so bash loses the accumulator to a subshell. Fix rather
than delete — its two `_recursive` siblings use the same `find | while` shape correctly because
they emit to stdout. Mirror them.

## Phase 3 — Coherence (blocking)

### 3.1 Resolve the flat/recursive split
Flat (`stats`, `graph`, `architect`) and recursive (`health`, `validate-kernel`) run against the
same `{vocabulary.notes}` path and give **opposite answers**. Verified at mixed depth: flat reports
`DANGLING: buried`, recursive reports clean, and `health:190` escalates any dangling to FAIL.

Flat returns empty with rc=0, so a wrong pick is silent. Decide one: make all consumers recursive,
or make flat fail loudly on an unmatched glob. `skills/setup/SKILL.md:162,591` generates a flat
notes folder by default, so a fresh vault is not broken — but nothing forbids subdirectories, and
health's own use of `_recursive` on that path concedes that nesting happens.

### 3.2 RESOLVED — the sourcing design is broken. Rework required.

**Verified 2026-08-02 against the real generated vault at `~/second-brain`. The design does not
work.** This is now the largest item in this spec and should be done first.

Evidence:

1. **`CLAUDE_PLUGIN_ROOT` is unset in a shell.** With `:-`, the path resolves to
   `/reference/lib/link-extraction.sh` — absolute from filesystem root, not readable. The
   loud-failure branch fires on **every** invocation of a generated `/stats` or `/graph`.
2. **Generated vaults are self-contained by design.** `~/second-brain/.claude/hooks/` holds the
   vault's *own copies* of `auto-commit.sh`, `session-orient.sh`, `validate-node-schema.py` and the
   rest. `skills/setup/SKILL.md:1382-1408` writes hook commands as `bash .claude/hooks/*.sh` —
   vault-relative paths. Nothing in a generated vault points back into the plugin.
3. **The vault's live hook config uses `$CLAUDE_PROJECT_DIR`, never `CLAUDE_PLUGIN_ROOT`.**
4. **There is no precedent for vault-local shell sourcing a plugin file.** The only
   `CLAUDE_PLUGIN_ROOT` occurrences in the entire generated vault are two **prose** lines in
   `refactor` (`:163`, `:247`) instructing an agent to *read a document*. That is not shell; it
   never required the variable to be set in an environment.

**The Spec A planning error, recorded so it is not repeated.** The extraction approach was chosen
partly because it appeared to need no generator change, justified by the `refactor` precedent. That
was wrong twice: the precedent is prose rather than shell, and generated vaults do not reference the
plugin at all. **A generator change IS required.** The cost estimate that informed the
duplicate-vs-extract decision was therefore too low.

### 3.2a Reworked sourcing design

Two tiers, because the two consumer classes genuinely differ. This is not a workaround; it is the
architecture the plugin already uses for hooks.

**Tier 1 — plugin-tier consumers keep sourcing from the plugin.**
`skills/architect/SKILL.md` and `skills/health/SKILL.md` run from the plugin directory, where the
library actually lives. They are unaffected by this rework and need no change. Keep the existing
relative-path form used by `reference/validate-kernel.sh`:

```bash
LINK_LIB="$(cd "$(dirname "$0")" && pwd)/lib/link-extraction.sh"
```

**Tier 2 — generated vaults get a copy, like hooks.**

*Placement:* `ops/lib/link-extraction.sh`.

Verified: `ops/` is written **literally** throughout `skills/setup/SKILL.md` (`ops/config.yaml`,
`ops/tasks.md`, `ops/queue/`, `ops/derivation.md`, `ops/methodology/`) — it is a fixed directory
name, not vocabulary-templated, so the path is safe to hardcode in a template. `ops/` is also the
right family: operational infrastructure, not knowledge content.

Rejected: `.claude/skills/lib/` — every sibling under `.claude/skills/` is a skill directory
containing `SKILL.md`, and a bare `lib/` invites exactly that ambiguity.
Note `ops/lib/` exists in `~/second-brain` but is **user-created**; the plugin does not generate it
today, so setup must create the directory as well as the file.

*Lookup:* match `hooks/scripts/read_config.sh:20` exactly. Do not invent a third way to find the
vault root.

```bash
VAULT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LINK_LIB="$VAULT_ROOT/ops/lib/link-extraction.sh"
if [ -r "$LINK_LIB" ]; then
  . "$LINK_LIB"
else
  echo "error: link-extraction library not found at '$LINK_LIB'" >&2
  echo "       run /arscontexta:upgrade to restore it" >&2
  exit 1
fi
```

**Stated precondition:** this resolves correctly only when the working directory is the vault root.
That assumption is already load-bearing across the plugin — `vaultguard.sh` tests bare
`[ -f ".arscontexta" ]`, and `read_config.sh` falls back to `$(pwd)`. Relying on it here keeps all
three consistent. Do **not** add a walk-up in the library alone: it would resolve the vault root
differently from the two scripts that already do it, which is a new inconsistency in a spec whose
theme is that protections must actually protect. If a walk-up is wanted, see §3.2c.

**Generator change (required):** `skills/setup/SKILL.md` must create `ops/lib/` and copy the library
into it, in the same step that writes `.claude/hooks/`. This is the change Spec A wrongly costed at
zero.

### 3.2b Staleness must be loud, not aspirational

A vault running an old copy of the library while the plugin has a fixed one is a wrong answer
delivered confidently — this spec's own failure class, introduced by this spec's own mechanism.
"Detectable rather than silent" is not a design; here is one.

1. The library declares its contract version on the first line of the file:
   `LINK_EXTRACTION_VERSION=1`. Bump it on any behavior change (fold rules, termination, recursion
   semantics) — not on comment edits.
2. Every generated consumer asserts the minimum it was written against, immediately after sourcing:

```bash
: "${LINK_EXTRACTION_VERSION:=0}"
if [ "$LINK_EXTRACTION_VERSION" -lt 1 ]; then
  echo "error: ops/lib/link-extraction.sh is version $LINK_EXTRACTION_VERSION; this skill needs >= 1" >&2
  echo "       run /arscontexta:upgrade to refresh it" >&2
  exit 1
fi
```

3. `/arscontexta:upgrade` owns refreshing the vault's copy and must report when it replaces a file
   whose version differs, rather than overwriting quietly.
4. `/arscontexta:health` should surface a version mismatch as a FAIL, so drift is visible without
   waiting for a skill to break.

The runtime assertion is the load-bearing part: it fires whenever a skill runs, not only when
someone remembers to upgrade.

### 3.2c Deferred — unify vault-root discovery

`read_config.sh:20` carries the comment "use CLAUDE_PROJECT_DIR if set, otherwise walk up" above
code that does `$(pwd)` and never walks up. `vaultguard.sh` tests `[ -f ".arscontexta" ]` relative
to cwd. Neither walks up; the comment is wrong.

Unifying all three on a real walk-up (searching upward for the `.arscontexta` marker, which already
exists as the canonical vault identifier) would make skills work from a subdirectory. **Deferred as
its own item** — it must change `read_config.sh`, `vaultguard.sh`, and the library together, or the
inconsistency it is meant to remove gets worse. Not a prerequisite for 3.2a.

### 3.2d Side benefit — the plugin-cache trust boundary

Copying the library into the vault removes a dependency on the plugin cache, which is writable and
drifts from the repo. Observed during this work: two installed skills carry mtimes months newer than
their eight siblings, with content absent from git history — consistent with the vault's own
documented "plugin skill patches". A vault-local copy means generated skills execute shell that
`/arscontexta:upgrade` placed there deliberately, not whatever currently sits in a mutable cache.

Related trust-boundary question worth a deliberate decision: the plugin cache is writable and
drifts from the repo (observed: two installed skills carry mtimes months newer than their eight
siblings, with content absent from git history — consistent with the vault's own documented
"plugin skill patches"). Vault skills sourcing executable shell from `${CLAUDE_PLUGIN_ROOT}`
inherit whatever is in the cache, not what is in the repo.

### 3.3 Locale-independent case folding
`tr '[:upper:]' '[:lower:]'` does not fold non-ASCII under `LC_ALL=C`. Verified: `[[über]]` and
`[[CAFÉ]]` resolve under `en_US.UTF-8` and report DANGLING under C locale — cron, CI, minimal
containers. The fold is *partial*, so symmetry does not save it.

### 3.4 Health scope contract
Extraction and index are now confined to `{vocabulary.notes}`, while the documented contract at
`skills/health/SKILL.md:160` still says "Every wiki link in every file". Links in `inbox/` and
`self/` go unchecked; links *to* files outside `notes/` now false-FAIL. Either restore whole-vault
scope on both sides or change the contract — but symmetrically.

### 3.5 `graph:161-162` trim + fold
The triangles/adjacency block dropped trim and fold, so closure detection miscomputes on case
variants while the dangling check in the same file folds correctly.

## Phase 4 — Behavioral tests (the meta-fix)

CI runs the textual guard and `bash -n`. It **executes no library code**. The "Install ripgrep"
step is dead — nothing in CI invokes rg. `bash -n` also cannot reach bash inside SKILL.md fences,
where four of five consumers live.

One fixture test exercising the six library functions would have caught the `count_links_recursive`
shell fork, §2.1, §2.4, and §3.3 — every one of which shipped because nothing ran the code.

Required: a fixture asserting fence stripping, `|`/`#` termination, both-sides case folding
(including a non-ASCII title), flat-vs-recursive at mixed depth, and loud failure on a missing
dependency. Run it in CI on both `bash` and `zsh` — two findings in this spec are shell forks.

## Out of scope

- **The mirror-defect class (~11 sites).** `rg -l "\[\[$NAME\]\]"` / `grep -rl` miss
  `[[NAME|alias]]` and `[[NAME#heading]]`, feeding backlink counts, orphan detection, and MOC
  coverage — so they silently produce false orphans and false "not in any MOC". Sites at
  `skills/health` 132/421/474, `skills/architect:175`, `skill-sources/graph` 89/106/312/446,
  `skill-sources/stats` 106/133, `reference/testing-milestones.md:410`. This is the *matching*
  direction rather than the *extraction* direction — a distinct class deserving its own spec, and
  large enough to swamp this one.
- **`validate-kernel.sh` candidate-directory discovery.** Hardcoded lists at `:74` and `:145` are
  incomplete and mutually inconsistent; neither includes `nodes/`, the reference vault's layout, so
  its dangling check silently scans nothing there. Directory discovery, not link parsing.
- **Spec B** (`/rethink` status vocabulary, `setup` never emitting `self_evolution.*`, `/learn`'s
  dead Exa tools) and **Spec C** (`CONTRIBUTING.md` authored and baseline-tested like a SKILL.md).
- **Documentation accuracy carried over:** the guard's blind-spot comment says "13 sites" (true
  count 9–11) with three stale line numbers; health's documented output format still promises
  per-file attribution the code no longer emits; the predecessor spec's success criterion still
  says "All 11 sites" (true count 12). Fix opportunistically when touching those files.

## Success criteria

1. `bash reference/check-portability.sh /nonexistent-root` **fails**, and so does a run with the
   scan directories removed.
2. The guard scans every shipped directory; `generators/features/maintenance.md:29` is fixed; any
   deliberately-deferred hits are listed in the guard by name.
3. `grep --perl-regexp`, `egrep -oP`, and `rg -P` are all caught.
4. With `rg` absent **and** with a broken `RIPGREP_CONFIG_PATH`, every consumer fails loudly. No
   path renders a number.
5. A nonexistent `{vocabulary.notes}` fails loudly rather than reporting a healthy vault.
6. `count_links_recursive` returns the same correct value under bash and zsh.
7. Flat and recursive agree on a mixed-depth vault, or the wrong choice fails loudly.
8. A real generated vault's `/stats` runs successfully — verified by generating a vault and running it, not by reasoning about environment variables.
8a. `skills/setup` creates `ops/lib/` and copies the library; a freshly generated vault contains it.
8b. A vault whose copied library is older than a skill requires FAILS LOUDLY at runtime, and `/arscontexta:health` reports the mismatch.
   reasoning about `CLAUDE_PLUGIN_ROOT`.
9. `[[Über]]` resolves to `über.md` under `LC_ALL=C`.
10. CI executes a fixture test of all six library functions, under both bash and zsh, and that
    fixture fails when any Phase 2 or Phase 3 defect is reintroduced.

## Decomposition note

Phases 1–2 are self-contained, close every open instance of the branch's own bug class, and could
ship alone as the smallest defensible unit. Phase 3.2 is the wildcard: if `CLAUDE_PLUGIN_ROOT` is
unset for vault-local skills, the sourcing design is wrong and that finding outgrows this spec.
**3.2 is resolved and it did change the shape.** The sourcing design is broken and needs rework plus a generator change, so it is the largest item here and blocks the `skill-sources` half of Phases 1-3. The plugin-tier consumers (`skills/architect`, `skills/health`) are unaffected and can proceed independently.
