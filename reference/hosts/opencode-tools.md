# Ars Contexta on OpenCode — tool mapping

The plugin's ten skills declare `allowed-tools:` using Claude Code's tool names.
OpenCode's names differ.

| The skills say | On OpenCode, use |
|---|---|
| `Read` | `read` |
| `Write`, `Edit` | `apply_patch` |
| `Bash` | `bash` |
| `Grep`, `Glob` | `grep`, `glob` |
| `mcp__qmd__query`, `mcp__qmd__get`, `mcp__qmd__multi_get` | `qmd_query`, `qmd_get`, `qmd_multi_get` — see below |
| `AskUserQuestion` | **no equivalent — see below** |

Use OpenCode's native `skill` tool to list and load the arscontexta skills.

## `AskUserQuestion` has no equivalent, and `/setup` is affected

Four of the ten skills declare it: `add-domain`, `reseed`, `setup`, `tutorial`.
On OpenCode, `/setup` asks in prose and parses the reply rather than collecting
structured answers. The derivation still works; it is chattier and the answers
are less constrained.

**This is a stated capability difference, not a bug to report.**

## qmd's MCP tools

Five of the ten skills declare them in `allowed-tools:`: `architect`, `ask`,
`health`, `recommend`, `reseed` (`health` declares only `mcp__qmd__query`).
OpenCode names an MCP server's tools `<server>_<tool>`, so the names in the
table hold when a qmd server is configured under the key `qmd`. Without one,
run the qmd CLI through `bash`: `qmd query`, `qmd get`, `qmd multi-get`.

## Unverified

This mapping is derived from OpenCode's documented tool names, and the
`AskUserQuestion` absence is believed rather than measured — the convention this
file mirrors ships no OpenCode tool-mapping document at all. Confirm against
OpenCode's own tool surface and correct this file if it is wrong. The exact
syntax for invoking a loaded skill (bare name vs. a namespaced form) is
likewise unverified. The `<server>_<tool>` naming was read from OpenCode
1.14.24's source and a qmd server connected in a scratch project, but no
OpenCode session has called a qmd tool.
