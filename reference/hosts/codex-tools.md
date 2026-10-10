# Ars Contexta on Codex — tool mapping

The plugin's ten skills declare `allowed-tools:` using Claude Code's tool names.
Codex's names differ. When a skill says "read the file", use Codex's equivalent.

| The skills say | On Codex, use |
|---|---|
| `Read` | the file-read tool |
| `Write`, `Edit` | the file-write / patch tool |
| `Bash` | the shell tool |
| `Grep`, `Glob` | the search tools, or `rg` / `find` via the shell |
| `mcp__qmd__query`, `mcp__qmd__get`, `mcp__qmd__multi_get` | the qmd server's tools, or the `qmd` CLI via the shell — see below |
| `AskUserQuestion` | **no equivalent — see below** |

## `AskUserQuestion` has no equivalent, and `/setup` is affected

Four of the ten skills declare it: `add-domain`, `reseed`, `setup`, `tutorial`.

`/setup` is not incidentally conversational — it *is* a derivation conversation,
and on Claude Code it collects structured answers. On Codex it asks in prose and
parses the reply. The derivation still works; it is chattier and the answers are
less constrained.

**This is a stated capability difference, not a bug to report.**

## qmd's MCP tools

Five of the ten skills declare them in `allowed-tools:`: `architect`, `ask`,
`health`, `recommend`, `reseed` (`health` declares only `mcp__qmd__query`).
Codex can run MCP servers (`codex mcp add`), and by default it lists a server's
tools under the namespace `mcp__<server>`: a server registered as `qmd` offers
`query`, `get` and `multi_get` under `mcp__qmd`. Without one, run the qmd CLI
through the shell: `qmd query`, `qmd get`, `qmd multi-get`.

## Unverified

The absence of a structured-question tool on Codex is believed, not measured —
it is absent from the tool-mapping conventions this document mirrors, and
absence from a mapping document is not absence from a runtime. Confirm against
Codex's own tool surface and correct this file if it is wrong. The `mcp__qmd`
namespace is read, not observed: in the `rust-v0.146.0` source, the
`non_prefixed_mcp_tool_names` feature that drops the `mcp__` prefix is off by
default, and `codex features list` on `codex-cli 0.162.0-alpha.17.2` reports it
off too. No Codex session has been seen calling a qmd tool.
