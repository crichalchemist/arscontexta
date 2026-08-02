# Spec A — Portability and link correctness in shipped templates

**Date:** 2026-08-01
**Status:** approved, ready for implementation planning
**Target:** PR to `upstream` (`agenticnotetaking/arscontexta`) from `origin` (`crichalchemist/arscontexta`)
**Branch:** `fix/portability-link-correctness`

## Problem

Nine bash blocks in shipped skill templates use `grep -P`. On BSD grep — the default on macOS —
`-P` does not exist; the command exits 2 with `invalid option -- P`. Every one of these blocks
pipes into `wc -l` or `while read`, so the failure surfaces as **0 or empty, never as an error**.

End users on macOS therefore see `Connections: 0`, `Topics: 0`, and `Dangling: 0` from `/stats`,
and `skills/architect` builds evolution proposals on empty link data.

A separate defect overlaps the same lines: wiki-link targets are captured with `[^\]]+`, which runs
through `|` and `#`. `[[slug|alias]]` yields `slug|alias` and `[[slug#heading]]` yields
`slug#heading`; neither matches a filename, so both count as dangling. Fenced code blocks are also
scanned, so `[[example]]` inside a fence counts as a real edge. The reference vault hit exactly this
— 135 false positives against a true count of 0 (2026-07-27).

### Why this survived

Inside a Claude Code Bash session, `grep` is not `/usr/bin/grep`. It is a shell function wrapping
**ugrep 7.5.0**, built `+P:pcre2jit`, which accepts `-P` happily.

| Where | `grep` resolves to | `grep -P` |
|---|---|---|
| Claude Code Bash tool | ugrep 7.5.0 (shell function) | works, exit 1 |
| Any other shell, any end-user machine | `/usr/bin/grep`, BSD 2.6.0-FreeBSD | `invalid option -- P`, exit 2 |

Any contributor who "verifies" a fix from the Bash tool gets a **false negative**. The bug looks
fixed and ships broken. This is the root cause of persistence and is why this spec mandates a guard
that invokes `/usr/bin/grep` explicitly.

## Evidence

Five independent subagents were given the reference vault's working fix and asked, under time and
authority pressure, to port it into `skill-sources/stats/SKILL.md`. All five reversed the
vault-to-template transforms correctly. Beyond that they surfaced defects not in the original
diagnosis:

- The vault snippet ends `print(f"total: {len(bad)}")`. Ported verbatim, `DANGLING_COUNT` becomes
  the string `total: 2`, which fails the numeric comparison at `stats/SKILL.md:276` and renders
  wrong at `:244`. Any port must emit a bare integer.
- Two reps independently discovered the ugrep masking described above.
- Three reps flagged `stats/SKILL.md:183`, absent from the initial diagnosis.

## Scope

### In scope — 11 edits to live code

| File | Lines | Defect |
|---|---|---|
| `skill-sources/graph/SKILL.md` | 69, 84, 151, 308 | `grep -P` + naive capture |
| `skill-sources/stats/SKILL.md` | 68, 78, 102, 183 | `grep -P` + naive capture |
| `skills/architect/SKILL.md` | 180 | `grep -P` + naive capture |
| `reference/validate-kernel.sh` | 67, 75 | naive capture only (no `-P`) |

Plus: one guard script, one CI workflow.

### Explicitly out of scope

- **`platforms/shared/skill-blocks/` (16 files).** Verified vestigial: `skills/setup/SKILL.md:1270`
  names `skill-sources/` as the template source and enumerates all 16 commands; nothing in the
  generation path references `skill-blocks`, and it has not changed since the v0.8.0 initial
  release. Its `stats.md:81` uses `rg -o` for a metric that `skill-sources/stats/SKILL.md:68`
  computes with `grep -ohP`, which is drift between a live file and a dead one, not a half-finished
  migration. Deleting or reconciling it is a maintainer decision about repo structure and belongs in
  its own PR.
- **`platforms/claude-code/hooks/session-orient.sh.template:74`.** Uses `tree -P`, a different tool
  with a legitimate `-P` flag. The guard script must not match it.
- **A committed fixture vault.** Considered and rejected: the guard plus CI cover regression, and a
  checked-in fixture becomes a maintenance burden contributors must keep in sync.
- **Spec B** (the `/rethink`, `setup`, and `/learn` defects) and **Spec C** (`CONTRIBUTING.md`).

## Design

### 1. Canonical extraction form

The nine `grep -P` sites share one shape — extract wiki-link targets, then count or test them. One
form replaces all nine:

```bash
for f in "$NOTES_DIR"/*.md; do
  awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$f"
done | rg -o '\[\[([^\]|#]+)' -r '$1' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | sort -u
```

Three properties the current code lacks: fences stripped before matching, capture terminated at `|`
and `#`, no `-P`.

**On `awk`:** it is POSIX-mandated and present on every macOS and Linux system. `python3` is not in
the README prerequisite table and appears in zero files under `skill-sources/`; adding it would
create a new runtime dependency on every end-user machine. `rg` is already a declared prerequisite.

**Bare integers.** Every block assigning to a counted variable must emit a bare integer, never a
labelled string. See the `total:` defect under Evidence.

**`reference/validate-kernel.sh:67,75` is an adaptation, not a paste.** Those two sites scan
`$VAULT/$d` across several candidate directories, not a single `$NOTES_DIR`, and they feed a `warn`
rather than a user-facing count. Apply the *properties* of the canonical form — fences stripped,
capture terminated at `|` and `#` — to their existing loop structure. Do not paste the block
verbatim; it will not work there.

### 2. Case folding

Wiki-link resolution must fold case explicitly on both sides:

```bash
| tr '[:upper:]' '[:lower:]'
```

**Rationale.** The current test `[[ -f "$NOTES_DIR/$NAME.md" ]]` delegates case semantics to the
filesystem. Default macOS APFS is case-insensitive; Linux is case-sensitive. So `[[Alpha]]` →
`alpha.md` resolves clean on macOS and reports dangling on Linux **from identical content**.

That is the same failure class as the `-P` bug: behavior silently forked by environment. Folding
case makes the result deterministic across platforms. Forcing case-sensitivity everywhere would be
equally deterministic and equally acceptable; leaving it filesystem-dependent is not.

This is a deliberate behavior change, not only a bug fix, and must be called out in the PR
description.

### 3. Guard script

`reference/check-portability.sh`, modelled on the existing `validate-kernel.sh` (same idiom, no new
infrastructure). Exits non-zero on:

1. `grep` invoked with a `-P` flag anywhere in `skills/`, `skill-sources/`, or `reference/`.
   Must **not** match `tree -P`.
2. Wiki-link capture that does not exclude `|` and `#`.

**The script must invoke `/usr/bin/grep` explicitly.** Run with bare `grep`, the ugrep shim makes it
pass while the bug ships. This single detail is the reason the guard exists.

### 4. CI

`.github/workflows/` — the repository's first — running `check-portability.sh` and
`validate-kernel.sh` on push and pull request. Ubuntu runner.

Note the ordering dependency: the Ubuntu runner is case-sensitive, so §2 must land in the same
change or CI will report dangling links that do not reproduce locally on macOS.

### 5. Verification

Each edited site is checked against a throwaway fixture containing an alias link, an anchor link, a
fenced-code link, and a case-variant link. For each, assert the old form is wrong and the new form
correct.

Fixtures are throwaway by design (see out-of-scope).

**The design in §1 and §2 was verified empirically before this spec was approved**, against a
fixture holding `[[real]]`, `[[real|some alias]]`, `[[real#a-heading]]`, `[[real|alias#frag]]`,
`[[Alpha]]` (file is `alpha.md`), `[[nonexistent-note]]`, and a fenced `[[in-code-fence]]`, using
ripgrep 15.2.0:

- Extraction returned exactly `Alpha`, `nonexistent-note`, `real` — alias and anchor forms both
  resolved to `real`, and the fenced link was excluded.
- With case folding, the dangling count was `1` (`nonexistent-note` only), and the value passed a
  numeric `-gt` comparison, confirming the bare-integer requirement.
- The platform fork in §2 was confirmed on the filesystem, not merely predicted: `[ -f
  notes/Alpha.md ]` returns true on this macOS APFS volume although the file on disk is `alpha.md`.
  Unfolded, that same code reports "clean" on macOS and "dangling" on the Ubuntu runner from
  identical content.

Implementation must re-verify per site; this establishes only that the canonical form and the case
decision are sound.

## Success criteria

1. All 11 sites edited; `/usr/bin/grep -rn 'grep [^|]*-[a-zA-Z]*P'` over `skills/`,
   `skill-sources/`, and `reference/` returns no matches.
2. `reference/check-portability.sh` exists, is executable, passes on the fixed tree, and fails when
   a `grep -P` is reintroduced. Verified by deliberately reintroducing one.
3. The guard does not flag `tree -P` in `platforms/claude-code/hooks/session-orient.sh.template:74`.
4. CI workflow runs both scripts and passes.
5. On a fixture with alias, anchor, fenced, and case-variant links, every edited metric reports the
   correct count under `/usr/bin/grep` on both macOS and the Ubuntu runner.
6. Counted variables hold bare integers.

## Risks

- **Behavior change.** Case folding alters dangling-link results for vaults with mixed-case slugs.
  Must be stated in the PR description.
- **First CI in the repo.** Upstream may have opinions about adding CI in a bug-fix PR. If it
  becomes contentious, the guard script alone still satisfies criteria 1–3 and CI can be split out.
- **`awk` dependency.** POSIX-universal, but not currently in the README prerequisite table.
  Consider adding it there.
