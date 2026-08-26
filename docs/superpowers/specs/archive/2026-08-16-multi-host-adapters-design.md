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
does one job — point a host agent at that directory. **Eight** exist, plus a
`gemini-extension.json`:

```bash
# 10 = 8 adapters + .github + .agents. Stated as a sum rather than filtered with an
# exclusion, per the idiom divergence 12 uses: an exclusion rots silently and can
# quietly match nothing, whereas a sum fails loudly the moment it stops adding up.
# (A lookahead — `test("^\\.(?!github|agents)")` — is NOT available: gh's jq is gojq,
# whose Go regexp engine rejects `(?!` outright. It errors rather than under-counting,
# which is the good failure, but it does not run.)
gh api "repos/obra/superpowers/git/trees/main" \
  --jq '[.tree[] | select(.type=="tree") | select(.path|startswith("."))] | length'   # 10 = 8 + 2
```

`.claude-plugin/`, `.codex-plugin/`, `.cursor-plugin/`, `.devin-plugin/`, `.hermes-plugin/`,
`.kimi-plugin/`, `.opencode/`, `.pi/`. (`.agents/` is excluded from that count because it is
the Codex marketplace directory rather than an adapter of its own — see below — and `.github/`
is not an adapter at all.)

**This spec examined three of the eight**: `.codex-plugin/`, `.opencode/`, `.pi/`. An earlier
revision said "five exist" and named a set missing `.cursor-plugin/`, `.devin-plugin/` and
`.kimi-plugin/` — all three of which predate the 2026-08-16 read, so that was a miscount and
not upstream drift. Recording it because the correction is load-bearing in one direction: the
"every adapter does one job" claim below is generalised from three trees, and three unexamined
adapters could have contradicted it. **Nobody looked**, and the claim should be read with that
caveat rather than as a survey.

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
# rc 1 — reporting a site IS the non-clean exit, so this line aborts a `set -e` fence.
# The rc is the annotation's load-bearing half: `# 1 site` alone reads as a clean measurement.
bash scripts/bump-version.sh --audit                                 # 1 site: README.md:12, rc 1
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

Everything else across the two files exists to force-load `using-superpowers` into every
session before the agent may act. That is superpowers' central contract. It is **not** the same
machinery in each, and saying "both files" flattens a distinction a later porter would trip on:

| mechanism | opencode | Pi |
|---|---|---|
| frontmatter stripper, bootstrap cache, double-injection guard | yes | yes |
| `session_start` / `session_compact` / `agent_end` flag dance | **no** | yes |
| `compactionSummary` insert-index walk | **no** | yes |
| injection site | `experimental.chat.messages.transform` | `context` event |

```bash
for t in session_start session_compact agent_end compactionSummary; do
  printf '%-20s opencode=%s pi=%s\n' "$t" \
    "$(grep -c "$t" obra-opencode.js)" "$(grep -c "$t" obra-pi.ts)"
done      # opencode=0 for all four; pi=1 for all four
```

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
.codex-plugin/plugin.json           manifest             ~40 lines JSON
.agents/plugins/marketplace.json    Codex marketplace    symlink -> REAL FILE
.opencode/plugins/arscontexta.js    config hook          ~25 lines
.opencode/INSTALL.md                install + mapping
.pi/extensions/arscontexta.ts       resources_discover   ~15 lines
```

**Codex is two files, not one.** An earlier draft of this spec called it "a manifest and
nothing else"; obra's own `tests/codex/test-marketplace-manifest.sh` refutes that in two ways,
both of which cost more here than they do there.

*First, the marketplace entry.* Codex reads `.agents/plugins/marketplace.json`, and its schema
is **not** Claude's:

| field | Codex (obra) | Claude (this repo) |
|---|---|---|
| `$schema` | absent | `anthropic.com/claude-code/marketplace.schema.json` |
| `interface.displayName` | required, asserted | absent |
| `plugins[].source` | object `{"source":"url","url":"./"}` | string `"./"` |
| `plugins[].policy` | `{installation, authentication}` | absent |
| `plugins[].category` | `Developer Tools` | `productivity` |

This repo's `.agents/plugins/marketplace.json` is a symlink to the Claude manifest, so it
currently serves **Claude's schema to a Codex reader**. It must become a real file. See
[Version sites](#version-sites-and-the-convention-already-in-the-tree) — the symlink rule
survives this; its earlier application did not.

*Second, `"hooks": {}` is mandatory and its value is exact.* Codex auto-discovers a plugin's
`hooks/hooks.json` whenever the manifest declares no `hooks` field, falling back to a
hardcoded `DEFAULT_HOOKS_CONFIG_FILE`. An absent field, an empty array `[]`, and an empty
inline list all collapse to that fallback; **only an empty object suppresses it.**

That matters more here than in obra's tree, because of what this repo's `hooks/hooks.json`
registers:

```
SessionStart: hooks/scripts/session-orient.sh
PostToolUse:  hooks/scripts/write-validate.sh, hooks/scripts/auto-commit.sh
```

**Provenance, stated because it is weak.** The entire fallback mechanism above — the constant
name, the exact-value requirement, the three collapsing spellings — appears in exactly one
place: the comment block of obra's `tests/codex/test-marketplace-manifest.sh`. That test
asserts `manifest.hooks == {}` in a JSON file; it does not and cannot exercise the runtime
fallback. Nothing in this repo can verify it either. It is second-hand, and it is listed in
[What is NOT claimed](#what-is-not-claimed) alongside the `skills` key rather than presented as
measured.

**Registration is not execution, and the distinction resolves an apparent contradiction with
this spec's own "Codex has no PostToolUse equivalent."** What the source supports is that the
fallback registers *the file* — obra's `hooks/hooks.json` happens to contain only a SessionStart
hook, which is why their comment describes it that way. This repo's contains more. So:

| | supported by the source | status |
|---|---|---|
| the whole file is registered, all three entries | yes | second-hand but stated |
| an install-time trust prompt fires | yes | second-hand but stated |
| Codex *dispatches* SessionStart | yes | second-hand but stated |
| Codex *dispatches* PostToolUse, so `auto-commit.sh` runs | **no** | **unknown** — and this spec asserts elsewhere that Codex has no PostToolUse equivalent, which if true means it does not |

An earlier revision claimed the omission would have `auto-commit.sh` writing commits under
Codex. That over-read the source and contradicted line 289 of this same document. The honest
floor: **omitting the key registers this repo's Claude Code hooks under Codex and fires a trust
prompt** — enough to require the key without the escalation. The ceiling depends on whether
Codex maps PostToolUse-class events, which is unknown; if it does, `vaultguard.sh` gates on the
`.arscontexta` marker, so a non-vault directory exits 0 and **a vault does not.** Declare the
key and the question never arises.

Codex reads `AGENTS.md`, which in this repo already symlinks to `CLAUDE.md` — so a Codex agent
inherits the full development context with no new context file, and with no collision with
`check-portability.sh` check 5, which pins that symlink.

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

**A register defect found while citing it, reported rather than fixed.** Deferral 31 is filed
under `## Closed` while reading as open (`**Why not now:**`, `**Reopens if:**`) and while its
defect is measurably live — `--audit` reports the site today. It is misfiled, and the
misfiling **predates** the 2026-08-15 audit that landed as `b47b9c3`:

```bash
awk '/^## /{s=$0} /^### 31\./{print NR": ["s"]"}' docs/superpowers/deferrals.md   # [## Closed]
git show b47b9c3^:docs/superpowers/deferrals.md \
  | awk '/^## /{s=$0} /^### 31\./{print NR": ["s"]"}'                             # [## Closed] — already
```

That audit checked entry *content* against HEAD and not entry *placement*, so an entry whose
body was accurate passed while sitting in the wrong section. Fixing it is a write to
`deferrals.md`, which is outside this spec's scope; it belongs in whichever branch next touches
that file. Recorded here so the next reader does not conclude from the heading that the version
tool's markdown limitation was solved.

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

**The rule that symlink implies is right; the symlink itself fails it.** State the rule first:
*symlink where the target schema is identical, write a separate file where it is not.*
`AGENTS.md → CLAUDE.md` satisfies it — both sides are the same prose, and check 5 pins it.
`.agents/plugins/marketplace.json` does not: the schema table above shows five fields where
Codex and Claude disagree, so the symlink serves the wrong schema and must be replaced with a
real file.

Two corrections in one place, and they point opposite ways — worth separating, because
collapsing them is how the second gets lost:

1. It is **not** an unregistered duplicate version site. The audit is right to ignore it.
2. It **is** wrong for its actual consumer, which is Codex, not Claude.

The first correction was the visible one and it made the second look settled. Nothing about
"it's a symlink, so the audit is correct" says anything about whether the bytes on the other
end are the right bytes.

**Replacing it does NOT add a version site, and the reason is measured rather than assumed.**
The Claude manifest it currently points at carries `metadata.version` and `plugins.0.version`,
so the obvious inference is that a real file inherits both and sites go 3 → 5. Measured
against obra's Codex marketplace: it declares **no version field anywhere**, while its
`.codex-plugin/plugin.json` does.

```bash
gh api "repos/obra/superpowers/contents/.agents/plugins/marketplace.json" --jq '.content' \
  | base64 -d | jq -r '[paths(scalars)|join(".")] | map(select(test("version";"i")))'   # []
```

This design mirrors that shape: version lives in the plugin manifest, the marketplace entry
points at it. So **sites go 3 → 4** — `.codex-plugin/plugin.json` only. (An earlier revision
of this paragraph asserted 5, inferring the version fields from the Claude schema it was
replacing rather than checking the Codex one. Recorded rather than quietly fixed, because it
is the second instance in this document of a claim invented from an adjacent schema's shape;
the first was `bump-version.sh --verify`.)

## Gates

| Gate | Effect |
|---|---|
| `check-portability.sh` check 4 | `platforms/shared/skill-blocks/` is cksum-frozen at any depth. This design writes nothing there. |
| `check-portability.sh` check 5 | Asserts `AGENTS.md` is a symlink to `CLAUDE.md`. **Satisfied, not fought** — it is why Codex needs no context file. |
| `check-prose-paths.sh` | SCOPE is a stated 11-file list. `README.md` is in it; `docs/superpowers/specs/` is not. |
| `check-portability.sh` checks 1, 2, 6, 7 | **`reference/hosts/*.md` lands inside the scanned trees** — the collection is `find skills skill-sources reference generators platforms presets hooks agents scripts \( -name '*.md' … \)`, and the exemption `case` covers only `reference/lib/*` and three named gate files. Host tool-mapping docs are prose *about tools*, so a worked example quoting `grep -P`, an interpolated wiki-link matcher, or an anchored `'^status:'` recipe turns the guard red on the day it lands. Keep executable-looking counter-examples in ` ```text ` fences, per `reference/skill-authoring.md`. |
| `check-doc-claims.sh` | Reads declared numerals in `CLAUDE.md` **and enum declarations in `generators/`** — it is the only gate that reads that tree. Neither is touched: no new gate and no new CI step, so the "17 executable checks" and 30-step counts do not move. |
| `bump-version.test.sh` | 41 assertions, exists because a bump once moved some sites and not others. Registering the Codex manifest is exactly its subject. |

**Two ordering constraints, not one.** An earlier revision asserted the first was "the only
one" — two sections after creating the second.

*1 — README must not lead.* `README.md` is in `check-prose-paths.sh` SCOPE, so every repo path
its install matrix names must exist when the gate runs. The README edit lands in the same
commit as the adapter files, or after them; never before.

*2 — `.version-bump.json` and `.codex-plugin/plugin.json` must be atomic, and the two failure
directions are asymmetric.* CI runs `--check` on every push:

```bash
grep -n 'bump-version' .github/workflows/checks.yml     # :198  bash scripts/bump-version.sh --check
```

`--check` iterates the declared (path, field) pairs and emits a `MISSING` row with a non-zero
exit for any it cannot read. So:

| order | result |
|---|---|
| registration lands first | **loud** — `MISSING`, red CI, fixed in minutes |
| manifest lands first, unregistered | **silent** — nothing fails, because `--audit` is deliberately *not* in CI. The tree carries an undeclared version site until the next bump quietly moves some sites and not others |

The silent direction is the exact partial-bump drift `bump-version.test.sh`'s 41 assertions
exist to prevent, and it is the direction a normal "add the file, then wire it up" instinct
produces. Land both in one commit, with the manifest's version string equal to the current
version verbatim.

## Testing

No new CI gate. The honest reason: the four artifacts are two JSON manifests and two
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
- **Not claimed: that the adapters are tested.** An earlier revision said "two of the three are unexecuted by any gate," which counts *adapters* and so conceals that the one nominally covered adapter is only half covered: Codex is two files, and `--check` reads one field of one of them. Counted by **file**, three of the four artifacts are unexecuted by any gate, and the fourth is checked for a single version string.
- **Not claimed: parity with obra's adapters.** Theirs bootstrap a skill; these register a directory. The omission is deliberate and reasoned, not incomplete porting.
- **Not claimed: that `/setup` is equally good on every host.** It is explicitly worse where `AskUserQuestion` is absent, and the reference docs say so.
- **Not claimed: that the `hooks` fallback semantics are verified.** The constant name, the exact-empty-object requirement, and the three collapsing spellings come from one comment block in obra's `tests/codex/test-marketplace-manifest.sh` and are grounded in nothing inspectable — a code search of `openai/codex` finds no `DEFAULT_HOOKS_CONFIG_FILE` or `load_plugin_hooks`. Declaring `"hooks": {}` is cheap and the downside of being wrong about it is nil, so the design follows the claim; that is a cost asymmetry, not evidence.
- **Not claimed: that Codex dispatches PostToolUse-class events.** Unknown, and this spec asserts the opposite elsewhere. See the registration-vs-execution table above.
- **Not claimed: that Pi, opencode and Codex lack an `AskUserQuestion` equivalent.** Stated flatly in the body; the evidence is absence from obra's `<host>-tools.md` files, and obra ships none for opencode at all. Absence from a mapping document is not absence from a runtime. The `reference/hosts/` content requirement rests on these three negatives, so they should be confirmed against each host's tool surface during the manual acceptance run rather than inherited from this spec.
- **Not claimed: that the new `.agents/plugins/marketplace.json` is protected by anything.** This is the file the design exists to fix, and after the change **no gate reads it**: `bump-version.sh --check` sees only declared (path, field) pairs and this file carries no version; `check-prose-paths.sh` checks existence, not content; `check-portability.sh` collects `*.md`/`*.sh`/`*.template` and not `*.json`. It can be malformed, carry the wrong schema, or be silently reverted to a symlink — the two exact regressions this spec narrates — with CI green. Adding a `jq -e` parse plus a non-symlink and schema-discriminating assertion (`interface.displayName` present, `plugins[0].source` an object) to an existing suite would close it; that is a gate-design change and is deferred, not overlooked.
- **Not claimed: that `"skills": "./skills/"` registers skills on a Codex runtime.** It is inferred from obra's manifest shape and is *not* asserted by their `tests/codex/test-marketplace-manifest.sh`, which checks `name`, `source`, `policy`, `category` and `hooks` — never `skills`. So the one key this adapter's whole purpose rests on is the one key obra's test does not cover, and nothing in this repo can cover it either. The manual acceptance run above is the only evidence that will ever exist for it; until that run happens the Codex adapter is **unverified**, and "one JSON file" is a statement about size, not about risk.

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
| `.agents/plugins/marketplace.json` becomes a real file | It is Codex's marketplace entry and Codex's schema differs from Claude's in five fields. It is *not* an unregistered version site — that earlier reading was a misuse of `cmp`, which follows symlinks — but it is serving the wrong schema. |
| Codex marketplace carries no version | Mirrors obra's shape, measured. Version lives in `.codex-plugin/plugin.json`; sites go 3 → 4. |
| `"hooks": {}` declared explicitly | Only an empty object suppresses Codex's `hooks/hooks.json` auto-discovery. Absent, `[]`, and an empty inline list all fall back — which would register `auto-commit.sh` under Codex. |
| Host reference docs live in `reference/hosts/` | obra puts theirs under the skill that consumes them (`skills/using-superpowers/references/`); this repo has no single consuming skill, since all ten are affected. `reference/` already holds cross-cutting contracts and four subdirectories (`lib/`, `templates/`, `test/`, `test-fixtures/`), so a fifth is the conforming choice rather than a new pattern. |
