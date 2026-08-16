# Multi-host adapters: Codex, opencode, Pi — design

Templated on `obra/superpowers`' `.codex-plugin/`, `.opencode/` and `.pi/` trees, read at
`main` on 2026-08-16.

**Scope is the HOST surface only.** Three adapters that let a non-Claude-Code host install
this plugin and invoke its ten commands. Nothing here changes what `/setup` *writes into a
vault*. That second surface is real, is not covered by obra's template, and is deferred —
see [The surface this does not build](#the-surface-this-does-not-build).

---

## The template covers one surface; this repo has two

`obra/superpowers` ships a skills framework: the product **is** `skills/`, and every adapter
does one job — point a host agent at that directory. Five exist (`.claude-plugin/`,
`.codex-plugin/`, `.opencode/`, `.pi/`, `.hermes-plugin/`), plus a `gemini-extension.json`.

`arscontexta` is a generator. Its skills derive a knowledge system and write it into a user's
directory. So "platform support" splits, and the two halves have different costs:

| | Surface | Artifact | Covered by obra's template |
|---|---|---|---|
| 1 | Can the host run `/arscontexta:setup`? | `.codex-plugin/`, `.opencode/`, `.pi/` | yes — this spec |
| 2 | What does a *generated vault* look like on that host? | `platforms/<host>/` | **no** |

Surface 2 is where `platforms/claude-code/` lives — `generator.md` plus four hook templates —
and it is the harder half, because a generated vault's automation ceiling is set by the host's
hook model. Building both at once would produce a spec that cannot be reviewed as one thing.

## Measurements

Taken 2026-08-16 against `main` at `212065a` and against `obra/superpowers@main`. Re-derive
rather than quote; the first four drift with obra's releases.

```bash
# obra's adapter payloads. `select(.type=="blob")` is load-bearing: without it the
# tree's directory entries emit `null` size rows that read as unmeasured files.
gh api "repos/obra/superpowers/git/trees/main?recursive=1" \
  --jq '.tree[] | select(.type=="blob")
        | select(.path | test("^\\.(codex-plugin|opencode|pi)/")) | "\(.size)\t\(.path)"'

# this repo's plugin skills, and how many need a structured-question tool
ls -d skills/*/ | wc -l                                              # 10
/usr/bin/grep -l '^allowed-tools:.*AskUserQuestion' skills/*/SKILL.md # 4
/usr/bin/grep -rln 'Task tool\|subagent\|Agent tool' skills/          # none, rc 1

# declared version sites, and what the audit finds outside them
jq '.files | length' .version-bump.json                              # 3
bash scripts/bump-version.sh --audit                                 # 1 site: README.md:12
```

| Quantity | Value |
|---|---|
| `.codex-plugin/plugin.json` | 1730 B, pure JSON |
| `.pi/extensions/superpowers.ts` | 4283 B, 121 lines |
| `.opencode/plugins/superpowers.js` | 5464 B, 139 lines |
| `.opencode/INSTALL.md` | 3342 B |
| this repo's plugin skills | 10 |
| …declaring `AskUserQuestion` | 4 — `add-domain`, `reseed`, `setup`, `tutorial` |
| …dispatching subagents | **0** |
| declared version sites | 3, all in `.claude-plugin/` |

## Both runtime adapters collapse, for one reason

obra's opencode plugin is 139 lines. **Seven of them do the registration**:

```js
config: async (config) => {
  config.skills = config.skills || {};
  config.skills.paths = config.skills.paths || [];
  if (!config.skills.paths.includes(superpowersSkillsDir)) {
    config.skills.paths.push(superpowersSkillsDir);
  }
},
```

Pi's equivalent is three:

```ts
pi.on("resources_discover", async () => ({
  skillPaths: [skillsDir],
}));
```

Everything else in both files — the frontmatter stripper, the module-level bootstrap cache,
the double-injection guard, the `compactionSummary` insert-index walk, the `session_start` /
`session_compact` / `agent_end` flag dance — exists to force-load `using-superpowers` into
every session before the agent may act. That is superpowers' central contract.

**`arscontexta` has no equivalent contract.** Its commands are invoked explicitly
(`/arscontexta:setup`, `/arscontexta:health`), and the measurement above confirms no skill
dispatches subagents. Nothing must be resident before the user types a command. So the
bootstrap machinery is not ported — not trimmed for taste, but absent because the requirement
it serves does not exist here.

Consequence: **Pi's typed-SDK problem mostly evaporates.** obra's extension imports
`type ExtensionAPI from "@earendil-works/pi-coding-agent"` — a type-only import, erased at
runtime. obra has a root `package.json`; this repo has none and needs none, because a
type-only import in an unbuilt `.ts` file has no runtime dependency and this repo runs no
typecheck. Ship unbuilt `.ts`, exactly as obra does.

## Architecture: three adapters

```
.codex-plugin/plugin.json           manifest only        ~40 lines JSON
.opencode/plugins/arscontexta.js    config hook          ~25 lines
.opencode/INSTALL.md                install + mapping
.pi/extensions/arscontexta.ts       resources_discover   ~15 lines
```

**Codex** is a manifest and nothing else: `"skills": "./skills/"` plus the `interface` block
(displayName, category, capabilities, defaultPrompt, brandColor). Codex reads `AGENTS.md`,
which in this repo already symlinks to `CLAUDE.md` — so a Codex agent inherits the full
development context with no new file and no collision with `check-portability.sh` check 5,
which pins that symlink.

**opencode** registers `skills/` on the `config` hook. No message transform.

**Pi** registers `skills/` on `resources_discover`. No `context` hook.

Each adapter resolves its own directory from `import.meta.url` and walks to the package root,
as obra's do. None carries a version string — see below.

## The gap obra's template hides rather than solves

Every skill here declares `allowed-tools:` in Claude Code's vocabulary, and **4 of 10 declare
`AskUserQuestion`**: `add-domain`, `reseed`, `setup`, `tutorial`. Pi has no such tool.
opencode has no such tool. Codex has no such tool.

`/setup` is not incidentally conversational — it *is* a derivation conversation, and
`AskUserQuestion` is how it takes structured input. On a host without it, `/setup` still
works, by asking in prose and parsing the reply. That is a genuine capability difference and
it must be **stated**, not discovered by a user whose setup conversation feels subtly worse.

obra handles the equivalent problem by embedding a tool-mapping table inside the bootstrap
they inject on every session. With no bootstrap to carry it, the mapping needs a home a host
actually reads. This design puts it in per-host reference documents mirroring obra's own
convention (`skills/using-superpowers/references/<host>-tools.md`):

```
reference/hosts/codex-tools.md
reference/hosts/opencode-tools.md
reference/hosts/pi-tools.md
```

Each states the tool-name mapping and, explicitly, that `AskUserQuestion` has no equivalent
and `/setup` degrades to prose questioning.

**This is the seam where a second, separately-specced piece of work attaches.** "Forked agents
need a way to surface questions to a team lead or the user" and "`AskUserQuestion` has no
cross-host equivalent" are the same missing primitive seen from two directions: there is no
portable channel for an agent to ask a question mid-run. That spec is deferred by decision on
2026-08-16; this one names the gap so the next has something to attach to, and **does not
attempt a mechanism.**

## Version sites, and the convention already in the tree

`.version-bump.json` declares three sites, all under `.claude-plugin/`. `--audit` reports one
site outside the declared set — `README.md:12` — which is deferral 31 and is not touched here.

**`.codex-plugin/plugin.json` carries a version and must be registered.** Sites go 3 → 4. The
opencode and Pi adapters carry no version string (obra's do not either), so they add none.

A live trap, recorded because this design walked into it and had to be corrected: **the fourth
manifest already in the tree is a symlink, not a duplicate.**

```bash
git ls-files -s .agents/plugins/marketplace.json    # 120000 — symlink mode
readlink .agents/plugins/marketplace.json           # ../../.claude-plugin/marketplace.json
```

An earlier draft called it an unregistered version site and a live defect, on the evidence of
`cmp` reporting it byte-identical to `.claude-plugin/marketplace.json`. `cmp` follows symlinks;
byte-identity is not file-identity. `grep -r` does **not** follow symlinked files, which is why
`--audit` correctly stays silent about it — the bytes it would report are already declared. The
audit was right and the reading was wrong.

That symlink is the convention this repo already uses for multi-host manifests, alongside
`AGENTS.md → CLAUDE.md`. **The rule it implies:** symlink where the schema is identical,
write a separate file where it is not. Codex's manifest carries an `interface` block that
Claude's schema has no slot for, so it is a real file. Had the schemas matched, it should have
been a symlink.

## Gates

| Gate | Effect |
|---|---|
| `check-portability.sh` check 4 | `platforms/shared/skill-blocks/` is cksum-frozen at any depth. This design writes nothing there. |
| `check-portability.sh` check 5 | Asserts `AGENTS.md` is a symlink to `CLAUDE.md`. **Satisfied, not fought** — it is why Codex needs no context file. |
| `check-prose-paths.sh` | SCOPE is a stated 11-file list. `README.md` is in it; `docs/superpowers/specs/` is not. |
| `check-doc-claims.sh` | Reads declared numerals in `CLAUDE.md`. No new gate and no new CI step, so the "17 executable checks" and 30-step counts do not move. |
| `bump-version.test.sh` | 41 assertions, exists because a bump once moved some sites and not others. Registering the Codex manifest is exactly its subject. |

**One ordering constraint follows from the SCOPE list, and it is the only one.** `README.md`
is in scope, so every repo path its install matrix names must exist when the gate runs. The
README edit must land in the same commit as the adapter files, or after them — never before.

## Testing

No new CI gate. The honest reason: the three artifacts are a JSON manifest and two
registration hooks, and a bash gate can assert only that they parse and that their paths
resolve — neither of which is the property that matters. **The property that matters is "a
Codex/Pi/opencode session can install this plugin and run `/arscontexta:health`", and nothing
in this repo can assert that**, for the same structural reason divergence 16 records: every
gate here reads this repo, and this claim is about another runtime.

What is checkable, and where:

- `.codex-plugin/plugin.json` parses and carries the declared version — `bump-version.sh --check`, already existing, once the site is registered. A malformed manifest or an absent field surfaces as that tool's `MISSING` / `NOT A VERSION` row rather than as agreement. Its subcommands are `--check`, `--audit` and a bare version; there is no `--verify`, and an earlier draft of this spec invented one.
- Adapter paths named in `README.md` resolve — `check-prose-paths.sh`, already existing.
- The JS/TS adapters parse — **not checked.** There is no JS runtime in CI and adding one is a toolchain decision larger than this work.

Manual verification is the acceptance criterion, once per host, recorded in the plan: install
the plugin, run `/arscontexta:health` against a generated vault, confirm the skill list
resolves. A host that cannot be tested ships its adapter marked **unverified** in the README
matrix rather than silently claimed.

## What is NOT claimed

- **Not claimed: that generated vaults work on these hosts.** Only that the plugin installs and its commands are reachable. A vault generated from a Codex session will be Claude-Code-shaped, because surface 2 is untouched — `platforms/claude-code/` is still the only generator target.
- **Not claimed: that hook-dependent behavior survives.** `/setup` Step 10 generates `.claude/hooks/`. Codex has no PostToolUse equivalent. A Codex-run `/setup` will write hooks the host never fires. This design does not fix that; it is the first thing surface 2 must address.
- **Not claimed: that the adapters are tested.** See above. Two of the three are unexecuted by any gate.
- **Not claimed: parity with obra's adapters.** Theirs bootstrap a skill; these register a directory. The omission is deliberate and reasoned, not incomplete porting.
- **Not claimed: that `/setup` is equally good on every host.** It is explicitly worse where `AskUserQuestion` is absent, and the reference docs say so.

## The surface this does not build

For whoever takes surface 2, the shape of the problem as it stands today:

`platforms/claude-code/` is `generator.md` plus four `.template` hook files. Divergence 3
establishes that **nothing copies those templates** — no skill under `skills/` or `generators/`
names the `platforms/` tree at all; `platforms/claude-code/generator.md:27` points Claude at
the directory as *documentation it reads while generating*. So a `platforms/codex/` tree would
be reference material too, and the real work is in `skills/setup` Phase 1, whose tier table
has two rows (`claude-code`, `minimal`) and whose columns are Context File / Skills Location /
Hooks / Automation Ceiling.

The load-bearing question is the fourth column. Claude Code's ceiling is "Full" because
PostToolUse exists. Codex's is not, and a tier table that adds a row without answering that
is a table that lies.

## Decisions taken, 2026-08-16

| Decision | Rationale |
|---|---|
| Host surface only | Surface 2's automation ceiling is unresolved per host; bundling makes one unreviewable spec. |
| All three hosts in one spec | The adapters are three files that share one mechanism; splitting them triples the review overhead for no isolation gain. |
| No bootstrap injection | The requirement it serves in obra's tree does not exist here — measured: 0 skills dispatch subagents, all commands are explicitly invoked. |
| Unbuilt `.ts` for Pi, no `package.json` | The SDK import is type-only and erases at runtime; obra ships it the same way. |
| No sync script | obra's 467-line `sync-to-codex-plugin.sh` publishes into `prime-radiant-inc/openai-codex-plugins`, an external marketplace. This repo has no such listing. |
| No new CI gate | Nothing checkable is the property that matters; a green gate asserting "the JSON parses" would read as coverage it does not provide. |
| Fork-question escalation deferred | Named as a gap here, specced separately. |
| `.agents/` symlink left alone | It is correct as-is. The earlier "defect" was a misreading of `cmp`. |
