# Contributor Surface and Residual Defects — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or
> superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.
>
> **Tick as you go.** Two plans in this directory once showed 0 of 93 steps complete while fully
> executed and merged. A status file that lies about status is the defect class this project exists
> to remove.

**Goal:** Close the last place a validator measures a proxy, and convert every remaining "known
open" item into either a fix or a stated decision.

**Spec:** `docs/superpowers/specs/2026-08-02-contributor-surface-and-residual-defects-design.md`

**Architecture:** Task 1 is mechanical and unblocked. Tasks 2-5 are gated on decisions D1-D3 below;
each is written with **both branches fully specified**, so whichever is chosen is immediately
executable and no task waits on a second round of design.

**Tech Stack:** bash, markdown templates, YAML. No build. Gates are `reference/check-portability.sh`
plus three harnesses under `reference/test/`, each run under **both bash and zsh**.

## Status of the parent spec

| Spec C item | State |
|---|---|
| 1. Commit + refresh agent-facing `CLAUDE.md` | **DONE** — `49b64e9` |
| 2. `CONTRIBUTING.md` | **DONE** — `49b64e9` |
| 3. Plan artifacts tell the truth | **DONE** — 93 boxes ticked, `49b64e9` |
| 4. Harden Kernel Primitive 10 | **Task 1 below** |
| 5. Residual defects | **Tasks 2-5 below** |

## Global Constraints

- Files under `skill-sources/` and `platforms/shared/skill-blocks/` are TEMPLATES. Never substitute
  a concrete value for a `{vocabulary.*}` or `{config.*}` placeholder.
- Every gate must pass under bash AND zsh.
- **Verify the property, not a proxy for it.** A check that passes while the capability is broken is
  worse than no check.
- A failure must exit non-zero AND emit no digits on stdout.
- `rg` exits 0=match, 1=no-match (**normal**), 2=error. Never collapse 1 and 2.
- Use `rg`. Do not introduce `python3`.
- `gh` on a fork queries upstream unless you pass `--repo crichalchemist/arscontexta`.

## Decisions required before Tasks 3-5

Batched here rather than raised mid-execution. Each names the option this plan recommends and why.

**D1 — What should a missing vault directory mean?** (gates Task 2)
Four sites render `0` when the notes directory is absent, so *"your vault is missing"* and *"your
vault is empty"* are indistinguishable.
→ **Recommended: fail loud.** Consistent with the branch's established rule that a failure must never
be a number. Risk: `/help` and `/health` are diagnostic commands a user may run *precisely because*
something is broken, and a hard failure removes their ability to see anything else. Mitigation in
Task 2 is to report the absence inline rather than abort.

**D2 — Where does `$FILE` come from in `skill-sources/seed`?** (gates Task 3)
Four fences read `$FILE`; no fence defines it. The skill's target is `$ARGUMENTS` (prose, line 15).
→ **Recommended: each fence assigns `FILE="$ARGUMENTS"` on its first line.** Fences are separate
shell invocations, so every fence that uses a value must establish it. The alternative — prose
instructing Claude to substitute the path before running — is how it silently fails today.

**D3 — How should the stale lock be bounded?** (gates Task 4)
`while ! mkdir "$LOCKDIR" 2>/dev/null; do sleep 2; done` never terminates against a stale lock.
→ **Recommended: bounded retry, then fail loud with the lock's age and path.** Do NOT auto-break the
lock; a lock older than the timeout may still be held by a live process.
> **`mkdir -p` is NOT the fix.** It returns 0 when the directory already exists, destroying the
> mutex — trading a visible hang for concurrent qmd runs corrupting each other.

---

### Task 1: Primitive 10 must assert resolution, not presence

**Files:**
- Modify: `reference/validate-kernel.sh`
- Modify: `reference/kernel.yaml` (primitive `semantic-search`, its `validation.check`)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: a primitive-10 check that FAILS when qmd is installed but a declared tool name does not
  resolve. No other task depends on it.

**Why.** `validate-kernel.sh` checks that `qmd` is on `PATH`. qmd was on `PATH` throughout the entire
period when 62 references named tools removed from its MCP surface — so the validator reported
semantic search satisfied while every call failed and each skill's documented "fall back to `rg`"
path quietly stood in. A presence check cannot detect a surface change.

This task supersedes Task 5 of
`docs/superpowers/plans/2026-08-02-stale-contracts-and-dead-configuration.md`, which now points here.
Two copies would drift — the same hazard as `skill-sources/` vs `platforms/shared/skill-blocks/`.

- [ ] **Step 1: Establish the control — confirm the current check passes while broken**

```bash
cd /Volumes/Containers/arscontexta
rg -n -A6 'id: semantic-search' reference/kernel.yaml
rg -n 'qmd' reference/validate-kernel.sh
```

Record the exact lines; you are replacing them. Expected: the check tests for the binary only.

- [ ] **Step 2: Write the three-state check**

Collapsing the last two states into "not PASS" is what hid this. Add to the primitive-10 section of
`reference/validate-kernel.sh`:

```bash
# Primitive 10 has THREE states. Collapsing the last two is the defect this replaces.
#   qmd absent            -> WARN  (semantic search is optional)
#   qmd present, resolves -> PASS
#   qmd present, does NOT -> FAIL  (undetected for 62 call sites across 20 files)
if ! command -v qmd >/dev/null 2>&1; then
  warn "semantic-search: qmd not installed (optional)"
else
  # rg: 0=match 1=no-match 2=error. Do not let an error read as "nothing declared".
  declared=$(rg -oN 'mcp__qmd__[a-z_]+' --glob '!*.diff' . | sort -u); rc=$?
  if [ "$rc" -gt 1 ]; then
    fail "semantic-search: scan for qmd tool names failed (rc=$rc); result is not evidence"
  else
    exposed='mcp__qmd__query mcp__qmd__get mcp__qmd__multi_get mcp__qmd__status'
    unknown=""
    for t in $declared; do
      case " $exposed " in *" $t "*) ;; *) unknown="$unknown $t" ;; esac
    done
    if [ -n "$unknown" ]; then
      fail "semantic-search: repo names qmd tools that do not exist:$unknown"
    else
      pass "semantic-search: qmd present, all declared tool names resolve"
    fi
  fi
fi
```

`$exposed` is a hardcoded list, and that is a deliberate cost: updating it becomes a explicit act
with a failing test attached, rather than a silent divergence.

- [ ] **Step 3: Prove it goes red — non-vacuity, both directions**

A check never seen red is not known to work. Two verification steps on a predecessor branch were
found vacuous, one because a `sed` silently matched nothing.

```bash
perl -i -pe 's/mcp__qmd__query/mcp__qmd__deep_search/ if $. == 8' skills/ask/SKILL.md
git diff --quiet -- skills/ask/SKILL.md && { echo "MUTATION DID NOT APPLY — vacuous"; exit 9; }
./reference/validate-kernel.sh . 2>&1 | rg 'semantic-search'    # expect FAIL naming the tool
git checkout -- skills/ask/SKILL.md
./reference/validate-kernel.sh . 2>&1 | rg 'semantic-search'    # expect PASS
git diff --quiet -- skills/ask/SKILL.md && echo "restored CLEAN"
```

- [ ] **Step 4: Sync `reference/kernel.yaml`**

Update primitive 10's `validation.check` so YAML and script agree. A primitive whose check does not
exist in the script is aspirational, not enforced.

- [ ] **Step 5: Point the superseded task here**

In `docs/superpowers/plans/2026-08-02-stale-contracts-and-dead-configuration.md`, replace Task 5's
steps with a one-line pointer to this task.

- [ ] **Step 6: Gates and commit**

```bash
bash reference/check-portability.sh                        # rc 0
for s in bash zsh; do
  $s reference/test/link-extraction.test.sh | tail -1      # 19/19
  $s reference/test/guard-failure.test.sh   | tail -1      # 19/19
  $s reference/test/fence-isolation.test.sh | tail -1      # PASS
done
./reference/validate-kernel.sh ~/second-brain              # 15/15
```

```bash
git add reference/kernel.yaml reference/validate-kernel.sh \
        docs/superpowers/plans/2026-08-02-stale-contracts-and-dead-configuration.md
git commit -m "Assert qmd tool names resolve, not merely that qmd is installed

Primitive 10 checked for the qmd binary. qmd was installed throughout the
entire period when all 62 of its call sites named tools removed from the MCP
surface, so the validator reported semantic search satisfied while it silently
degraded to keyword grep in every vault.

A presence check cannot detect a surface change. This asserts every declared
mcp__qmd__* name is one qmd exposes, and keeps 'qmd absent' (WARN) distinct
from 'qmd present but broken' (FAIL).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: A missing vault must not render as an empty one — GATED ON D1

**Files:**
- Modify: `skills/help/SKILL.md` (fence 1, ~line 47)
- Modify: `skills/health/SKILL.md` (~line 400)
- Modify: `skill-sources/next/SKILL.md` (~line 143)
- Modify: `skill-sources/reflect/SKILL.md` (fence 3)
- Modify: `reference/test/fence-isolation.test.sh` (remove the four drained allowlist entries)

**Interfaces:**
- Consumes: nothing.
- Produces: four fences that no longer emit digits at exit 0 with no notes directory. The fence gate
  allowlist shrinks from 8 entries to 4.

**Why.** All four render `0` when the notes directory is absent, so a missing vault and an empty one
are indistinguishable. `skills/health` additionally computes `Ratio: 0%` from it.

**If D1 = fail loud (recommended):** each block asserts its directory before counting.
**If D1 = report inline:** each block prints `absent` instead of a number and continues.

- [ ] **Step 1: Add the precondition to `skills/help` fence 1**

Current:
```bash
note_count=$(ls -1 {vocabulary.notes}/*.md 2>/dev/null | wc -l | tr -d ' ')
```
Replace the fence's opening with:
```bash
# A missing notes directory must not read as an empty vault. `ls … 2>/dev/null | wc -l`
# renders 0 for both, and /help is often the first command a user runs when something
# is wrong — reporting "0 notes" sends them looking for the wrong problem.
NOTES_DIR="{vocabulary.notes}"
if [ ! -d "$NOTES_DIR" ]; then
  echo "error: notes directory '$NOTES_DIR' does not exist; run /arscontexta:setup" >&2
  exit 1
fi
note_count=$(ls -1 "$NOTES_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
```

- [ ] **Step 2: Same guard in `skills/health` before the ratio**

```bash
NOTES_DIR="{vocabulary.notes}"
INBOX_DIR="{vocabulary.inbox}"
if [ ! -d "$NOTES_DIR" ] || [ ! -d "$INBOX_DIR" ]; then
  echo "error: cannot compute an inbox-to-notes ratio; missing directory" >&2
  exit 1
fi
```
Place it **above** the `find` calls at ~line 400, in the same fence — a guard in an earlier fence
does not carry (INVARIANT 1).

- [ ] **Step 3: Same treatment for `skill-sources/next` and `skill-sources/reflect`**

`next` fence 4 guards `{vocabulary.inbox}` and `{vocabulary.notes}` before its counts. `reflect`
fence 3 currently reads:
```bash
grep -r '\[\[note name\]\]' {vocabulary.notes}/*.md | wc -l
```
`grep | wc -l` discards grep's status, so a missing directory renders 0. Guard the directory, and
capture grep's status separately rather than piping it into `wc`.

- [ ] **Step 4: Verify each fence individually, with a missing-vault fixture**

```bash
for s in bash zsh; do $s reference/test/fence-isolation.test.sh | tail -1; done
```
Expect: the four `N` entries no longer appear under KNOWN-OPEN. **The gate will FAIL with `STALE`
until you remove them from the allowlist** — the list is checked in both directions, which is the
mechanism working, not a regression.

- [ ] **Step 5: Drain the allowlist and commit**

Remove the four `N` entries from `KNOWN_OPEN` in `reference/test/fence-isolation.test.sh`. Re-run
both shells; expect `known-open=4`.

---

### Task 3: `skill-sources/seed` — four fences read an undefined `$FILE` — GATED ON D2

**Files:** `skill-sources/seed/SKILL.md` (fences 1, 3, 4, 5), `platforms/shared/skill-blocks/seed.md`
(check for drift), `reference/test/fence-isolation.test.sh`

**Interfaces:** Produces four fences that define every variable they read. Allowlist drops to 0
`U` entries.

- [ ] **Step 1: Apply D2's chosen form to fence 1**

If D2 = per-fence assignment (recommended):
```bash
# Fences are separate shell invocations, so each one that uses the target path must
# establish it. Reading $FILE from an earlier fence expands to empty and the block
# proceeds against "" — which is how this failed silently.
FILE="$ARGUMENTS"
if [ -z "$FILE" ]; then
  echo "error: no source file given; usage: /{vocabulary.seed} <path>" >&2
  exit 1
fi
```

- [ ] **Step 2: Repeat for fences 3, 4, 5.** Fence 4 also reads `$ARCHIVE_DIR`; define it in the
      same fence or derive it from `$FILE`.

- [ ] **Step 3: Check `platforms/shared/skill-blocks/seed.md` for the same defect** — that directory
      can drift from `skill-sources/`; fix both or neither.

- [ ] **Step 4: Verify, drain the four `U` entries from the allowlist, commit**

Also re-check the zsh-only entry `skill-sources/seed f01 ~H~ ops/queue*.yaml` — a non-matching glob
aborts under zsh where bash passes the pattern through. It may resolve with this change, in which
case the gate will report it `STALE` and it must be removed too.

---

### Task 4: Bound the stale-lock retry — GATED ON D3

**Files:** `skill-sources/reflect/SKILL.md` (2 sites), `skill-sources/reweave/SKILL.md` (1 site),
plus the `platforms/shared/skill-blocks/` twins

**Interfaces:** Produces a lock acquisition that terminates. No other task depends on it.

- [ ] **Step 1: Replace the unbounded loop at each of the 3 sites**

```bash
LOCKDIR="ops/queue/.locks/qmd.lock"
# mkdir WITHOUT -p is the mutex: it fails when the directory exists. `mkdir -p` would
# return 0 in that case and destroy mutual exclusion. The PARENT must exist — setup
# creates it, upgrade §5f restores it.
mkdir -p "$(dirname "$LOCKDIR")"
waited=0
until mkdir "$LOCKDIR" 2>/dev/null; do
  if [ "$waited" -ge 60 ]; then
    echo "error: could not acquire $LOCKDIR after ${waited}s" >&2
    echo "       if no other run is active, remove it: rm -rf '$LOCKDIR'" >&2
    exit 1
  fi
  sleep 2
  waited=$((waited + 2))
done
trap 'rm -rf "$LOCKDIR"' EXIT
```

**Do not auto-break the lock.** A lock older than the timeout may still be held by a live process;
breaking it reintroduces the corruption the mutex prevents. Fail and tell the user.

- [ ] **Step 2: Verify termination against a pre-held lock**

```bash
V=$(mktemp -d); mkdir -p "$V/ops/queue/.locks/qmd.lock"    # simulate a stale lock
# extract the fence and run it in $V; expect exit 1 within ~60s, not a hang
```

- [ ] **Step 3: Gates and commit**

---

### Task 5: Run `/arscontexta:upgrade` against the live vault

**Files:** none in this repo. This is verification of prose contracts CI cannot exercise.

**Why.** `/upgrade` has never run against a real vault, and now performs three repairs — `ops/lib/`,
`ops/queue/.locks/`, and seeding `self_evolution:`. Prose contracts are the half of this product CI
cannot test.

**This mutates a live vault. It is the owner's call to run, and requires their explicit go-ahead.**

- [ ] **Step 1: Snapshot first**

```bash
cd ~/second-brain && git status --short && git rev-parse --short HEAD
```

- [ ] **Step 2: Run `/arscontexta:upgrade`, capture the full report**

- [ ] **Step 3: Verify each claimed repair independently of the report**

```bash
cd ~/second-brain
[ -r ops/lib/link-extraction.sh ] && rg -n 'LINK_EXTRACTION_VERSION=' ops/lib/link-extraction.sh
[ -d ops/queue/.locks ] && echo "locks dir present"
rg -n -A2 'self_evolution:' ops/config.yaml
./reference/validate-kernel.sh ~/second-brain    # 15/15
```

Expect `LINK_EXTRACTION_VERSION=2` — v1 is the macOS-only fold, and the version bump exists precisely
so upgrade refreshes it.

- [ ] **Step 4: Record what the report claimed vs what was true**

Any divergence is a defect in the upgrade skill's prose contract and needs its own observation.

---

## Queued to start after this plan completes

Platform expansion, sequenced deliberately behind Spec C rather than run alongside it. Full research
and sources in `.superpowers/platform-research.md` (git-ignored — promote to `reference/` when this
work starts, or the detail is lost to `git clean`).

**1. Antigravity CLI adapter — LOW cost, the right second target.** The only other platform whose
extension model is *markdown skills with YAML frontmatter*, which is exactly what
`skill-sources/*/SKILL.md` already is. Plugins bundle `skills/`, `agents/`, `hooks.json` and
`mcp_config.json` — near 1:1 with this repo's layout, and `platforms/` already anticipates the
adapter shape. Known work:

- Root `plugin.json` is currently a byte-identical copy of `.claude-plugin/plugin.json` and would
  **fail Antigravity's schema**: it is `additionalProperties: false` permitting only `name` and
  `description`, and the copy carries six illegal keys (`version`, `author`, `homepage`,
  `repository`, `license`, `keywords`). `name` must match `^[a-zA-Z0-9-_]+$`.
- Translate `hooks/hooks.json` to Antigravity's hook schema; `.mcp.json` → `mcp_config.json`.
- Generated vaults would place skills in `.agents/skills/` rather than `.claude/skills/`.
- The README currently claims `| Antigravity CLI plugin | Available |`. Nothing is installable yet —
  scope that claim before it ships, or it is exactly the status-that-lies defect this repo gates.

**2. Pi — MEDIUM, but test before planning.** Skills are markdown, and Pi discovers **`CLAUDE.md`
and `AGENTS.md` natively** (`--no-context-files` disables it), so a generated vault may already be
partially usable with **no adapter at all**. Establish that first — it is a ten-minute experiment
that decides whether this is a port or merely packaging. Costs if it becomes a port: hooks are
TypeScript extensions (`pi.registerTool()`, `pi.registerCommand()`, event interception), so the
seven bash hooks have no declarative equivalent, and packaging wants a `package.json`, which
conflicts with this repo's deliberate no-runtime-dependency stance.

> Target `@earendil-works/pi-coding-agent` (v0.83.0). The older `@mariozechner/pi-coding-agent`
> (v0.73.1) **still resolves on npm** and installs ten minor versions behind with no error — the same
> shape as the stale qmd and Exa tool names fixed in Spec B.

**opencode is NOT queued.** No markdown skill primitive at all; a plugin is an async TS function
returning hooks, with tools defined via Zod-style schemas. All 26 commands would become TypeScript.
That is a rewrite, not an adapter, and it contradicts the no-new-runtime constraint.

## Not in this plan

- Canonical `open` vs `pending` for new observations — readers accept both, so nothing is broken
  either way. A vocabulary choice, not a defect.
- Unifying `.arscontexta` and `ops/config.yaml`. `read_config.sh` handles scalar top-level keys only
  and structurally cannot reach a nested key. A design change.
- The boot disk at 100%, which makes Docker unusable and every Linux-affecting change cost a CI
  round-trip. Environmental; the owner's machine.
- `skills/help:49` merging observations with methodology in one display total; the
  `platforms/shared/skill-blocks/stats.md:94-95` doc table. Display decisions.
