# skill-blocks — frozen reference inventory

**Nothing generates from this directory.** `skills/setup/SKILL.md:1285` names
`${CLAUDE_PLUGIN_ROOT}/skill-sources/` as the template source and enumerates the 16 commands it
copies; no `.sh`, `.md`, `.json` or `.yaml` under `skills/`, `generators/`, `hooks/`, `reference/`
or `presets/` references `platforms/` at any depth. Editing a file here changes nothing that ships.

## Why it still exists

These files carry the most complete `{vocabulary.*}` / `{config.*}` markup in the repository — every
point where a string is vocabulary-variable, marked. Measured against their `skill-sources` twins:

Counting the three placeholder families — `{vocabulary.*}`, `{config.*}`, `{DOMAIN:*}` — with the
command in `reference/skill-authoring.md` §2. **The pattern matters:** a bare `{…}` also matches
`${TARGET}` and `${FILE}`, which inflates a shell-variable count into a placeholder count. An earlier
version of this table stated no pattern and could not be re-derived from any single one.

| skill | `skill-sources` | here |
|---|---|---|
| remember | 4 | **49** |
| validate | 5 | **60** |
| pipeline | 17 | **72** |
| ralph | 18 | **143** |
| seed | 19 | **63** |
| verify | 27 | **146** |
| rethink | 27 | **79** |
| reweave | 111 | **166** |
| reflect | 121 | **203** |
| reduce | 131 | **155** |

That makes this directory the best answer in the repo to **"is this string vocabulary-variable, or
is it structural?"** — the question every template author has to answer and can otherwise only guess
at. Consult it. Do not edit it.

The header on each file names a *"derivation engine"* that performs mechanical placeholder
substitution. That engine was never built; `/setup` has the model vocabulary-transform
`skill-sources/` while reading the derivation manifest. These files are the more complete artifact of
an abandoned mechanism — not a superseded predecessor of `skill-sources/`. Both directories were
created in the same commit (`4be327e`, the initial release); neither replaced the other.

## Two populations

- **10 full templates** (`pipeline`, `ralph`, `reduce`, `reflect`, `remember`, `rethink`, `reweave`,
  `seed`, `validate`, `verify`) — near-copies of their `skill-sources` twins, opening `---` with a
  `GENERATION TEMPLATE` header. These carry the markup the table above measures.
- **6 metadata blocks** (`graph`, `learn`, `next`, `refactor`, `stats`, `tasks`) — a different
  artifact opening `# Skill Generation Block:`, carrying a YAML spec and prose, no bash fences.
  Their structural difference from `skill-sources` is by design, not drift.

## Parity with `skill-sources/` is a NON-GOAL

**Guard and logic parity is not maintained here, and its absence is not a defect.** Some files carry
guards their twins have and some do not — `reflect.md` has the lock guard but not the notes-directory
guard, for instance. Under the previous "keep both in sync" reading that was a defect; under this
one it is simply irrelevant, because nothing here executes.

Do not "fix" it. Do not diff this directory against `skill-sources/` looking for missing guards. The
only property this directory maintains is **placeholder coverage**.

## Frozen

`reference/check-portability.sh` check 4 compares every file here against
`reference/skill-blocks.frozen`, a manifest of `cksum` digests. **This README is the one file
excepted** — it is not pinned, so it can be edited freely.

Four outcomes, because "this tree does not claim a freeze" is not "this tree passed one":

| manifest | directory | outcome |
|---|---|---|
| present | present | compared — **FAIL** on any modified, deleted, or unpinned file, at any depth, including dotfiles and non-`.md` |
| present | absent | **FAIL** — the manifest pins files that are gone |
| absent | present | **FAIL** — the documented way someone would "let an edit through" |
| absent | absent | **SKIP** if the tree has no `CLAUDE.md` (not an arscontexta root); **FAIL** if it does (the freeze was removed) |

`reference/test/guard-failure.test.sh` asserts all of these against a two-file fixture, so the check
cannot regress while the gates stay green — which it did once already.

That gate exists because the instruction it replaced — *"can drift from `skill-sources/`; check both
when editing a shared behavior"* — drew four commits of guard-porting work into a directory that
generates nothing. If you have a reason to change a template here, change the gate deliberately and
say why in the commit; do not delete the rule to let an edit through.

See `docs/superpowers/specs/2026-08-02-skill-authoring-reference-design.md`.
