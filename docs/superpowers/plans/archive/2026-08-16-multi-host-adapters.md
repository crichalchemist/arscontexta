# Multi-Host Adapters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let Codex, opencode and Pi install the `arscontexta` plugin and invoke its ten commands.

**Architecture:** Four artifacts across three hosts. Codex is two JSON manifests; opencode and Pi are ~20-line registration hooks that push this repo's `skills/` onto the host's skill path. No bootstrap injection — arscontexta's commands are invoked explicitly, so nothing must be resident before the user acts. Nothing in `platforms/`, `generators/`, `skill-sources/` or `skills/setup` changes: this is the *host* surface, not the generated-vault surface.

**Tech Stack:** JSON manifests; ESM JavaScript (opencode); unbuilt TypeScript with a type-only import (Pi); bash for verification.

**Spec:** `docs/superpowers/specs/archive/2026-08-16-multi-host-adapters-design.md`

## Global Constraints

Every task's requirements implicitly include this section. Values are verbatim from the spec.

- **Version string is `0.9.9`, exactly.** Any manifest carrying a version must match `jq -r '.version' .claude-plugin/plugin.json` character-for-character.
- **`"hooks": {}` in `.codex-plugin/plugin.json` is mandatory and its value is exact.** Absent, `[]`, and an empty inline list all collapse to Codex's auto-discovery fallback; only an empty object suppresses it.
- **`.version-bump.json` and `.codex-plugin/plugin.json` land in ONE commit.** CI runs `bash scripts/bump-version.sh --check` (`.github/workflows/checks.yml:198`). Registration-first fails loud (`MISSING`, red CI); manifest-first fails **silent**, because `--audit` is deliberately not in CI.
- **`README.md` must not lead.** It is in `check-prose-paths.sh` SCOPE, so every repo path it names must already exist when the gate runs. Its edit lands last.
- **No new CI gate and no new CI step.** `check-doc-claims.sh` reads declared numerals in `CLAUDE.md`; adding either moves the "17 executable checks" and 30-step counts and turns it red.
- **`reference/hosts/*.md` are inside `check-portability.sh`'s scanned trees.** Keep any executable-looking counter-example (a `grep -P`, an interpolated wiki-link matcher, an anchored `'^status:'` recipe) inside a ` ```text ` fence, never ` ```bash `.
- **Do not write `platforms/shared/skill-blocks/`.** It is cksum-frozen at any depth by `check-portability.sh` check 4.
- **NEVER `git add docs/superpowers/../field-intel-2026-08-15.md`** — i.e. `docs/field-intel-2026-08-15.md`. It is untracked and must stay so. Stage files by explicit path; never `git add -A` or `git add .`.
- **Do not copy the string `15 kernel primitives`** from `.claude-plugin/plugin.json` into any new manifest. `CLAUDE.md` records that as a label-vs-count error (there are 16; 15 is the largest label read as a total). Do not fix it in place either — that is another task's scope.

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `.codex-plugin/plugin.json` | Codex plugin manifest: skills path, `hooks: {}`, `interface` block, version | 1 |
| `.agents/plugins/marketplace.json` | Codex marketplace entry. **Currently a symlink to the Claude manifest** — becomes a real file with Codex's schema | 1 |
| `.version-bump.json` | Adds `.codex-plugin/plugin.json` as a fourth declared version site | 1 |
| `.opencode/plugins/arscontexta.js` | opencode `config` hook pushing `skills/` onto `config.skills.paths` | 2 |
| `.opencode/INSTALL.md` | opencode install steps + tool mapping pointer | 2 |
| `.pi/extensions/arscontexta.ts` | Pi `resources_discover` handler returning `skillPaths` | 3 |
| `reference/hosts/codex-tools.md` | Codex tool-name mapping; states the `AskUserQuestion` gap | 4 |
| `reference/hosts/opencode-tools.md` | opencode tool-name mapping; same gap | 4 |
| `reference/hosts/pi-tools.md` | Pi tool-name mapping; same gap | 4 |
| `README.md` | Install matrix covering four hosts, with verification status | 5 |

---

### Task 1: Codex adapter (two manifests + version registration, one commit)

This task is deliberately atomic. The spec's asymmetric-failure analysis means a partial landing either reddens CI or — worse — silently creates an undeclared version site. Everything below goes in one commit.

**Files:**
- Create: `.codex-plugin/plugin.json`
- Replace (symlink → regular file): `.agents/plugins/marketplace.json`
- Modify: `.version-bump.json`

**Interfaces:**
- Consumes: nothing.
- Produces: `.codex-plugin/plugin.json` with `name: "arscontexta"`, `version: "0.9.9"`, `skills: "./skills/"`, `hooks: {}`. Task 5's README matrix names both created paths.

- [ ] **Step 1: Record the before-state, so the change is provable**

```bash
git ls-files -s .agents/plugins/marketplace.json   # expect mode 120000 (symlink)
readlink .agents/plugins/marketplace.json          # ../../.claude-plugin/marketplace.json
jq -r '.version' .claude-plugin/plugin.json        # 0.9.9 — the string every manifest must match
```

Write those three outputs into the task report. If the mode is already `100644`, STOP: someone has changed it and this plan's premise no longer holds.

- [ ] **Step 2: Register the version site FIRST, to watch the guard fail**

This is the "red" step. Edit `.version-bump.json`, adding one entry to `.files`:

```json
{
  "files": [
    { "path": ".claude-plugin/plugin.json", "field": "version" },
    { "path": ".claude-plugin/marketplace.json", "field": "metadata.version" },
    { "path": ".claude-plugin/marketplace.json", "field": "plugins.0.version" },
    { "path": ".codex-plugin/plugin.json", "field": "version" }
  ],
  "audit": {
    "exclude": [
      ".git",
      "node_modules",
      ".superpowers",
      ".version-bump.json",
      "bump-version.sh",
      "superpowers",
      "check-prose-paths.sh"
    ]
  }
}
```

- [ ] **Step 3: Run the guard and confirm it fails loudly**

```bash
bash scripts/bump-version.sh --check; echo "rc=$?"
```

Expected: a `MISSING` row for `.codex-plugin/plugin.json (version)` and a **non-zero** rc. If it exits 0, the guard is not doing its job and that is a finding — stop and report it.

- [ ] **Step 4: Create `.codex-plugin/plugin.json`**

No `composerIcon`, `logo`, or `screenshots` keys: this repo ships no assets, and naming files that do not exist is the defect class this spec is about.

```json
{
  "name": "arscontexta",
  "version": "0.9.9",
  "description": "Conversational derivation engine — generate an agent-native memory architecture from natural conversation.",
  "author": {
    "name": "Heinrich",
    "url": "https://arscontexta.org"
  },
  "homepage": "https://arscontexta.org",
  "repository": "https://github.com/agenticnotetaking/arscontexta",
  "license": "MIT",
  "keywords": [
    "knowledge-management",
    "tools-for-thought",
    "memory-system",
    "derivation",
    "cognitive-architecture",
    "agent-native",
    "zettelkasten",
    "knowledge-graph"
  ],
  "skills": "./skills/",
  "hooks": {},
  "interface": {
    "displayName": "Ars Contexta",
    "shortDescription": "Derive a knowledge system your agent operates, maintains, and grows",
    "longDescription": "Ars Contexta derives a complete knowledge system through conversation — a structured markdown memory your agent reads, writes, and maintains across sessions. It generates the vault, its skills, its schema, and its maintenance loop, then validates the result against a kernel of research-backed primitives.",
    "developerName": "Heinrich",
    "category": "Developer Tools",
    "capabilities": [
      "Interactive",
      "Read",
      "Write"
    ],
    "defaultPrompt": [
      "Set up my knowledge system.",
      "What needs fixing in my vault?"
    ],
    "websiteURL": "https://arscontexta.org"
  }
}
```

**Ruling on `category`, recorded because it is a guess with a reason.** `"Developer Tools"` is the only value observed in a working Codex manifest (obra's, and their test pins it). `"Productivity"` is semantically better and matches this repo's Claude marketplace, but Codex's category enum is not published and an invalid value may break install. Evidence beats semantics for a first ship. If the manual acceptance run shows the enum accepts it, switching to `"Productivity"` is a one-line follow-up.

- [ ] **Step 5: Run the guard and confirm it now passes**

```bash
bash scripts/bump-version.sh --check; echo "rc=$?"
```

Expected: four rows, `All declared files agree at 0.9.9`, rc=0. The `.codex-plugin/plugin.json (version)` row must read `0.9.9` — not `MISSING`, not `NOT A VERSION`.

- [ ] **Step 6: Replace the marketplace symlink with a real Codex-schema file**

```bash
rm .agents/plugins/marketplace.json
```

Then create `.agents/plugins/marketplace.json` as a regular file. Note there is **no `$schema` key and no version field** — the version lives in the plugin manifest, and obra's Codex marketplace declares none:

```json
{
  "name": "agenticnotetaking",
  "interface": {
    "displayName": "Ars Contexta"
  },
  "plugins": [
    {
      "name": "arscontexta",
      "source": {
        "source": "url",
        "url": "./"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Developer Tools"
    }
  ]
}
```

- [ ] **Step 7: Assert every property the spec says nothing else will ever check**

No gate reads this file after the change. These assertions run once, by hand, here:

```bash
git ls-files -s .agents/plugins/marketplace.json | cut -c1-6   # 100644, not 120000
test ! -L .agents/plugins/marketplace.json && echo "not a symlink: ok"
jq -e '.interface.displayName' .agents/plugins/marketplace.json          # "Ars Contexta"
jq -e '.plugins[0].source | type == "object"' .agents/plugins/marketplace.json   # true
jq -e '.plugins[0].policy.installation' .agents/plugins/marketplace.json # "AVAILABLE"
jq -e 'has("$schema") | not' .agents/plugins/marketplace.json            # true — Codex schema, not Claude's
jq -e '.hooks == {}' .codex-plugin/plugin.json                           # true
jq -e '.skills == "./skills/"' .codex-plugin/plugin.json                 # true
```

`jq -e` exits non-zero on `null`/`false`, so a missing key fails rather than printing `null` and passing. Every line must exit 0 except where noted.

- [ ] **Step 8: Confirm the Claude side is untouched**

```bash
bash reference/check-portability.sh 2>&1 | tail -3    # check 5 (AGENTS.md symlink) still passes
git diff --stat HEAD -- .claude-plugin/                # EMPTY — Claude manifests unchanged
```

- [ ] **Step 9: Commit, atomically**

```bash
git add .codex-plugin/plugin.json .agents/plugins/marketplace.json .version-bump.json
git status --short    # confirm docs/field-intel-2026-08-15.md is NOT staged
git commit -m "feat(codex): plugin manifest + Codex-schema marketplace entry

.agents/plugins/marketplace.json was a symlink to the Claude manifest, so it
served Claude's schema to a Codex reader — five fields differ. Now a real file.

hooks: {} is load-bearing and exact: Codex falls back to auto-discovering
hooks/hooks.json when the field is absent, and [] and an empty inline list
collapse to the same fallback. This repo's hooks.json wires SessionStart plus
two PostToolUse hooks, one of which writes git commits.

Registration and manifest land together: --check runs in CI, so registration
alone reddens it, and manifest alone creates an undeclared version site that
nothing in CI would see."
```

---

### Task 2: opencode adapter

**Files:**
- Create: `.opencode/plugins/arscontexta.js`
- Create: `.opencode/INSTALL.md`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: named export `ArsContextaPlugin`, an async function taking `({ client, directory })` and returning an object with a `config` handler. Task 5's README names both paths.

- [ ] **Step 1: Confirm the skills directory resolves from the plugin's location**

The plugin lives two levels deep, so `../../skills` is the repo root's `skills/`. Prove it before relying on it:

```bash
node -e 'const p=require("path");console.log(p.resolve(".opencode/plugins","../../skills"))'
ls -d skills/ && echo "resolves"
```

Expected: an absolute path ending `/skills`, and `skills/` listing.

- [ ] **Step 2: Write `.opencode/plugins/arscontexta.js`**

Deliberately has no message transform, no frontmatter parser, and no bootstrap cache — obra needs those to force-load one skill before the agent acts; arscontexta's commands are invoked explicitly.

```js
/**
 * arscontexta plugin for OpenCode.ai
 *
 * Registers this plugin's skills/ directory with OpenCode so the
 * /arscontexta:* commands resolve. That is the whole job.
 *
 * Deliberately absent: bootstrap injection. obra/superpowers injects its
 * using-superpowers skill into every session because nothing may happen
 * before that skill is loaded. arscontexta has no such contract — every
 * command is invoked explicitly and no skill dispatches subagents — so
 * there is nothing to make resident ahead of the user.
 */

import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const ArsContextaPlugin = async ({ client, directory }) => {
  const skillsDir = path.resolve(__dirname, '../../skills');

  return {
    // Push our skills path into the live config. OpenCode's Config.get()
    // returns a cached singleton, so a mutation here is visible when skills
    // are lazily discovered later — no symlinks, no user config edits.
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(skillsDir)) {
        config.skills.paths.push(skillsDir);
      }
    },
  };
};
```

- [ ] **Step 3: Syntax-check it, and prove the check can fail**

CI has no JS runtime, so this is the only syntax verification that will ever run. Confirm the check discriminates before trusting it:

```bash
node --check .opencode/plugins/arscontexta.js && echo "PARSES"
printf 'const x = {\n' > /tmp/ac-broken.mjs
node --check /tmp/ac-broken.mjs 2>&1 | head -2 ; echo "broken-file rc=$?"
rm -f /tmp/ac-broken.mjs
```

Expected: `PARSES` for ours; a syntax error for the deliberately broken file. A checker that passes both is not a checker.

- [ ] **Step 4: Verify the config handler actually mutates, with a stub**

```bash
node --input-type=module -e '
import("./.opencode/plugins/arscontexta.js").then(async (m) => {
  const plugin = await m.ArsContextaPlugin({ client: null, directory: process.cwd() });
  const config = {};
  await plugin.config(config);
  await plugin.config(config);            // twice: must not duplicate
  console.log("paths:", config.skills.paths.length, config.skills.paths[0]);
});'
```

Expected: `paths: 1 /…/arscontexta/skills`. A length of 2 means the `includes` guard is broken.

- [ ] **Step 5: Write `.opencode/INSTALL.md`**

```markdown
# Installing Ars Contexta for OpenCode

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed
- `ripgrep`, `tree`, `awk`, `sed`, `jq`, `bc`, `git`, and `python3` with PyYAML — see the prerequisite table in `README.md`

## Installation

Add the plugin to the `plugin` array in your `opencode.json` (global or project-level):

```json
{
  "plugin": ["arscontexta@git+https://github.com/agenticnotetaking/arscontexta.git"]
}
```

Restart OpenCode. The plugin registers this repo's `skills/` directory; no symlinks and no `skills.paths` edit are needed.

Verify with OpenCode's native `skill` tool:

```
use skill tool to list skills
```

You should see `setup`, `health`, `ask`, `architect`, and the rest.

## Tool mapping, and one capability this host does not have

OpenCode's tool names differ from the ones the skills name. The mapping — and the
`AskUserQuestion` gap, which changes how `/setup` behaves — is in
`reference/hosts/opencode-tools.md`. Read it before your first `/setup`.

## Updating

OpenCode installs through a git-backed package spec, and some OpenCode and Bun
versions pin the resolved git dependency in a lockfile or cache. If updates do
not appear after a restart, clear OpenCode's package cache or reinstall.
```

- [ ] **Step 6: Commit**

```bash
git add .opencode/plugins/arscontexta.js .opencode/INSTALL.md
git status --short    # confirm docs/field-intel-2026-08-15.md is NOT staged
git commit -m "feat(opencode): register skills/ via the config hook

Seven lines of obra's 139 do the registration; the rest force-loads their
bootstrap skill. arscontexta has no such contract, so the transform, the
frontmatter parser and the cache are all absent by design rather than
unfinished.

Verified locally: node --check parses (and rejects a deliberately broken
file), and a stub invocation shows config.skills.paths gains exactly one
entry across two calls."
```

---

### Task 3: Pi adapter

**Files:**
- Create: `.pi/extensions/arscontexta.ts`

**Interfaces:**
- Consumes: nothing.
- Produces: a default-exported function taking Pi's `ExtensionAPI`, registering one `resources_discover` handler that returns `{ skillPaths: [<repo>/skills] }`. Task 5's README names the path.

- [ ] **Step 1: Confirm the type-only import needs no dependency**

The import is erased at compile time, so no `package.json` is required — and this repo has none. Confirm nothing was added:

```bash
ls package.json 2>/dev/null && echo "UNEXPECTED — stop and report" || echo "no package.json: correct"
```

- [ ] **Step 2: Write `.pi/extensions/arscontexta.ts`**

```ts
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Type-only import above: erased at compile time, so this file has no runtime
// dependency and this repo needs no package.json.

const extensionDir = dirname(fileURLToPath(import.meta.url));
const packageRoot = resolve(extensionDir, "../..");
const skillsDir = resolve(packageRoot, "skills");

/**
 * Registers this plugin's skills/ directory with Pi so the /arscontexta:*
 * commands resolve.
 *
 * Deliberately absent: the session_start / session_compact / agent_end flag
 * dance, the bootstrap cache, and the compactionSummary insert-index walk that
 * obra/superpowers needs to force-load one skill ahead of the agent. Every
 * arscontexta command is invoked explicitly, so nothing must be resident first.
 */
export default function arscontextaPiExtension(pi: ExtensionAPI) {
  pi.on("resources_discover", async () => ({
    skillPaths: [skillsDir],
  }));
}
```

- [ ] **Step 3: Verify the path arithmetic independently of Pi**

`.pi/extensions/` is two levels deep, same as opencode's plugin directory:

```bash
node -e 'const p=require("path");console.log(p.resolve(".pi/extensions","../..","skills"))'
ls -d skills/ && echo "resolves"
```

Expected: an absolute path ending `/skills`.

- [ ] **Step 4: Load the module, which also proves the type-only import erases**

Do **not** use `node --experimental-strip-types --check` — `--check` does not strip types and fails on a perfectly good file (verified: it errors at the `: number` in `const x: number = 1`). An implementer trusting it would "fix" correct code.

Loading the module is both a stronger test and the one that matters, because it exercises the claim this design rests on — that the `ExtensionAPI` import is erased and needs no installed package:

```bash
node --experimental-strip-types -e '
import("./.pi/extensions/arscontexta.ts").then(m => {
  console.log("loaded, default is", typeof m.default);
}).catch(e => { console.log("FAILED:", e.message); process.exit(1); });'
```

Expected: `loaded, default is function`, rc 0. **`@earendil-works/pi-coding-agent` is not installed and this repo has no `node_modules`** — so a successful load is direct evidence the type-only import erased at runtime. A `FAILED: Cannot find package` would mean the import is not type-only and the no-`package.json` decision is wrong; report that rather than installing anything.

This checks syntax and loadability. It is **not** a typecheck — none exists in this repo — so say that in the report rather than implying type safety.

- [ ] **Step 5: Commit**

```bash
git add .pi/extensions/arscontexta.ts
git status --short    # confirm docs/field-intel-2026-08-15.md is NOT staged
git commit -m "feat(pi): register skills/ via resources_discover

Three lines of obra's 121 do the registration. The ExtensionAPI import is
type-only and erases at runtime, so no package.json and no build step are
required — the same way obra ships theirs.

Syntax-checked only; this repo has no typechecker and none was added."
```

---

### Task 4: Host tool-mapping references

These three files land inside `check-portability.sh`'s scanned trees. Any executable-looking counter-example must sit in a ` ```text ` fence.

**Files:**
- Create: `reference/hosts/codex-tools.md`
- Create: `reference/hosts/opencode-tools.md`
- Create: `reference/hosts/pi-tools.md`

**Interfaces:**
- Consumes: nothing. `.opencode/INSTALL.md` (Task 2) already points at `reference/hosts/opencode-tools.md`.
- Produces: three paths Task 5's README names.

- [ ] **Step 1: Re-derive the gap these documents exist to state**

```bash
ls -d skills/*/ | wc -l                                                  # 10
grep -l '^allowed-tools:.*AskUserQuestion' skills/*/SKILL.md             # 4 files
```

Expected: `10`, and exactly `add-domain`, `reseed`, `setup`, `tutorial`. If the set has changed, update the numbers in all three documents to match rather than copying the ones below.

- [ ] **Step 2: Write `reference/hosts/codex-tools.md`**

````markdown
# Ars Contexta on Codex — tool mapping

The plugin's ten skills declare `allowed-tools:` using Claude Code's tool names.
Codex's names differ. When a skill says "read the file", use Codex's equivalent.

| The skills say | On Codex, use |
|---|---|
| `Read` | the file-read tool |
| `Write`, `Edit` | the file-write / patch tool |
| `Bash` | the shell tool |
| `Grep`, `Glob` | the search tools, or `rg` / `find` via the shell |
| `AskUserQuestion` | **no equivalent — see below** |

## `AskUserQuestion` has no equivalent, and `/setup` is affected

Four of the ten skills declare it: `add-domain`, `reseed`, `setup`, `tutorial`.

`/setup` is not incidentally conversational — it *is* a derivation conversation,
and on Claude Code it collects structured answers. On Codex it asks in prose and
parses the reply. The derivation still works; it is chattier and the answers are
less constrained.

**This is a stated capability difference, not a bug to report.**

## Unverified

The absence of a structured-question tool on Codex is believed, not measured —
it is absent from the tool-mapping conventions this document mirrors, and
absence from a mapping document is not absence from a runtime. Confirm against
Codex's own tool surface and correct this file if it is wrong.
````

- [ ] **Step 3: Write `reference/hosts/opencode-tools.md`**

````markdown
# Ars Contexta on OpenCode — tool mapping

The plugin's ten skills declare `allowed-tools:` using Claude Code's tool names.
OpenCode's names differ.

| The skills say | On OpenCode, use |
|---|---|
| `Read` | `read` |
| `Write`, `Edit` | `apply_patch` |
| `Bash` | `bash` |
| `Grep`, `Glob` | `grep`, `glob` |
| `WebFetch` | `webfetch` |
| `AskUserQuestion` | **no equivalent — see below** |

Use OpenCode's native `skill` tool to list and load the arscontexta skills.

## `AskUserQuestion` has no equivalent, and `/setup` is affected

Four of the ten skills declare it: `add-domain`, `reseed`, `setup`, `tutorial`.
On OpenCode, `/setup` asks in prose and parses the reply rather than collecting
structured answers. The derivation still works; it is chattier and the answers
are less constrained.

**This is a stated capability difference, not a bug to report.**

## Unverified

This mapping is derived from OpenCode's documented tool names, and the
`AskUserQuestion` absence is believed rather than measured — the convention this
file mirrors ships no OpenCode tool-mapping document at all. Confirm against
OpenCode's own tool surface and correct this file if it is wrong.
````

- [ ] **Step 4: Write `reference/hosts/pi-tools.md`**

````markdown
# Ars Contexta on Pi — tool mapping

The plugin's ten skills declare `allowed-tools:` using Claude Code's tool names.
Pi's built-in coding tools are lowercase.

| The skills say | On Pi, use |
|---|---|
| `Read` | `read` |
| `Write` | `write` |
| `Edit` | `edit` |
| `Bash` | `bash` |
| `Grep`, `Glob` | `grep`, `find`, `ls` (optional tools) |
| `AskUserQuestion` | **no equivalent — see below** |

Pi has native skills but does not expose Claude Code's `Skill` tool. Load a
skill's `SKILL.md` with `read`, or invoke `/skill:<name>` explicitly.

## `AskUserQuestion` has no equivalent, and `/setup` is affected

Four of the ten skills declare it: `add-domain`, `reseed`, `setup`, `tutorial`.
On Pi, `/setup` asks in prose and parses the reply rather than collecting
structured answers. The derivation still works; it is chattier and the answers
are less constrained.

**This is a stated capability difference, not a bug to report.**

## Subagents

No arscontexta skill dispatches subagents, so Pi's lack of a standard subagent
tool costs nothing here. Verify before assuming it stays true:

```text
grep -rln 'Task tool\|subagent\|Agent tool' skills/     # expect no output, rc 1
```

## Unverified

The `AskUserQuestion` absence is believed rather than measured. Confirm against
Pi's `ExtensionAPI` surface and correct this file if it is wrong.
````

- [ ] **Step 5: Run the portability guard — these files are in its scan scope**

```bash
bash reference/check-portability.sh 2>&1 | tail -5; echo "rc=$?"
```

Expected: PASS, rc=0. If a check reddens, the cause is almost certainly a matcher or a `grep -P` inside a ` ```bash ` fence in one of the three new files — move it to ` ```text `. Do **not** add an exemption marker; the guidance is in `reference/skill-authoring.md`.

- [ ] **Step 6: Commit**

```bash
git add reference/hosts/codex-tools.md reference/hosts/opencode-tools.md reference/hosts/pi-tools.md
git status --short    # confirm docs/field-intel-2026-08-15.md is NOT staged
git commit -m "docs: per-host tool mappings, and the AskUserQuestion gap stated

4 of 10 skills declare AskUserQuestion and no other host has it, so /setup
degrades to prose questioning everywhere but Claude Code. That is a real
capability difference and it is stated rather than left to be discovered.

Each file carries an Unverified section: the three absences are believed, not
measured, and the manual acceptance run is what settles them."
```

---

### Task 5: README install matrix, and the whole-branch gate sweep

Lands last: `README.md` is in `check-prose-paths.sh` SCOPE, so every path it names must already exist.

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: every path created by Tasks 1–4.
- Produces: nothing downstream.

- [ ] **Step 1: Confirm every path the matrix will name already exists**

```bash
for p in .codex-plugin/plugin.json .agents/plugins/marketplace.json \
         .opencode/plugins/arscontexta.js .opencode/INSTALL.md \
         .pi/extensions/arscontexta.ts \
         reference/hosts/codex-tools.md reference/hosts/opencode-tools.md \
         reference/hosts/pi-tools.md; do
  [ -e "$p" ] && echo "  ok   $p" || echo "  MISS $p"
done
```

Every line must read `ok`. A `MISS` means an earlier task did not land — stop.

- [ ] **Step 2: Find the install section**

```bash
grep -n '^## \|^### ' README.md | head -20
```

Insert the matrix after the existing Claude Code install instructions, not before — Claude Code stays the primary path.

- [ ] **Step 3: Add the install matrix**

Verification status is part of the table on purpose: an adapter nobody has run must not read as shipped-and-working.

```markdown
## Other hosts

The plugin's commands are also installable on Codex, OpenCode and Pi. Each host
registers this repo's `skills/` directory; the commands are then invoked the
same way.

| Host | Adapter | Install | Tool mapping | Verified |
|---|---|---|---|---|
| Claude Code | `.claude-plugin/plugin.json` | `/plugin install arscontexta@agenticnotetaking` | native | yes |
| Codex | `.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json` | via the Codex plugin marketplace | `reference/hosts/codex-tools.md` | **not yet** |
| OpenCode | `.opencode/plugins/arscontexta.js` | `.opencode/INSTALL.md` | `reference/hosts/opencode-tools.md` | **not yet** |
| Pi | `.pi/extensions/arscontexta.ts` | add this repo to Pi's extension path | `reference/hosts/pi-tools.md` | **not yet** |

**"Not yet" is literal.** Those three adapters have never been run against their
host. No gate in this repo can execute them — every check here reads this repo,
and the claim is about another runtime. They are believed correct by
construction and are unverified in fact. The row flips to `yes` when someone
installs the plugin on that host and runs `/arscontexta:health` successfully.

One capability differs everywhere but Claude Code: `AskUserQuestion` has no
equivalent, so `/setup` asks in prose instead of collecting structured answers.
Each tool-mapping document says so.
```

- [ ] **Step 4: Run the gate that reads README.md**

```bash
bash reference/check-prose-paths.sh 2>&1 | tail -3
```

Expected: PASS, and the path count risen from 278 by the number of new repo paths the matrix names. A count that did **not** move means the extractor missed them — investigate rather than accepting the PASS.

- [ ] **Step 5: Full gate sweep, both shells**

```bash
bash reference/check-portability.sh
bash reference/check-prose-paths.sh
bash reference/check-doc-claims.sh
bash reference/check-placeholder-count.sh main
bash reference/check-vocabulary-schema.sh
bash scripts/bump-version.sh --check
for s in bash zsh; do
  $s reference/test/bump-version.test.sh   | tail -1
  $s reference/test/hook-config.test.sh    | tail -1
  $s reference/test/queue-edit.test.sh     | tail -1
done
```

Record each result in the task report. `check-doc-claims.sh` is the one to watch: if it reddens, a declared numeral in `CLAUDE.md` moved, which this plan's Global Constraints forbid.

- [ ] **Step 6: Commit**

```bash
git add README.md
git status --short    # confirm docs/field-intel-2026-08-15.md is NOT staged
git commit -m "docs: install matrix for Codex, OpenCode and Pi

Lands last because README.md is in check-prose-paths.sh SCOPE — every repo
path it names must already exist when the gate runs.

The Verified column reads 'not yet' for all three new hosts, literally: no
gate in this repo can execute an adapter, so they are believed correct by
construction and unverified in fact."
```

---

## Deferrals

- **`.agents/plugins/marketplace.json` ships gate-free.** After Task 1 no check reads it: `--check` sees only declared (path, field) pairs and it carries no version; `check-prose-paths.sh` checks existence, not content; `check-portability.sh` collects `*.md`/`*.sh`/`*.template`, not `*.json`. It can be malformed, wrong-schema, or reverted to a symlink with CI green. Task 1 Step 7 asserts these once, by hand, at creation. A standing gate belongs in the CI-hardening spec — recorded in `docs/superpowers/specs/archive/2026-08-16-multi-host-adapters-design.md` under "What is NOT claimed".
- **Deferral 31 is misfiled** under `## Closed` in `docs/superpowers/deferrals.md` while reading as open and while its defect is live. The misfiling predates `b47b9c3`. Not fixed here: `deferrals.md` is outside this plan's scope. Belongs to whichever branch next edits that file.
- **`interface.category` is a reasoned guess.** `"Developer Tools"` is the only value observed in a working Codex manifest; `"Productivity"` is semantically better but Codex's enum is unpublished. Revisit after the manual acceptance run — Task 1 Step 4 records the ruling.
- **The three `AskUserQuestion` absences are believed, not measured.** Each `reference/hosts/*.md` carries an "Unverified" section saying so. Settled by the manual acceptance run, not by this plan.
- **`check-prose-paths.sh` covers only 3 of the 9 repo paths the README matrix names.** `PREFIXES` (`reference/check-prose-paths.sh:63`) carries `.github` as its only dot-prefixed entry, and the bare token `agents` does not match `.agents/…` under the guard's `case "$tok" in "$p"/*)` matcher. So the six dot-prefixed adapter paths the matrix names — `.claude-plugin/`, `.codex-plugin/`, `.agents/`, `.opencode/` (×2), `.pi/` — are structurally invisible to the gate; only the three `reference/hosts/*.md` files are actually checked. Those six were therefore verified **by hand** at Task 5 and again at final review, not by the gate. The path-count delta this branch produced, `278 → 282`, decomposes as **3 real + 1 incidental** and must not be read as "the new adapter paths are covered." Fixing the tokenizer is a gate-design change deferred to the CI-hardening spec: it must first extract dot-leading tokens at all, and widening what counts as a repo path changes behavior across all 11 `SCOPE` files.
