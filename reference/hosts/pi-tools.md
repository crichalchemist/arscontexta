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
Pi's `ExtensionAPI` surface and correct this file if it is wrong. The
`/skill:<name>` invocation syntax above is likewise unverified against a
running Pi session.
