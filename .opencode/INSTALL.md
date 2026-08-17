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
