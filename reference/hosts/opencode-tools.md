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
