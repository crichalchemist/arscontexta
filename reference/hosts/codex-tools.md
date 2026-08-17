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
