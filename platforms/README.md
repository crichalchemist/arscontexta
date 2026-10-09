# platforms/ -- Distribution View

This directory maps the distribution layout for the Claude Code agent platform. It does not contain the generation logic itself -- that lives in `generators/`. What `platforms/` provides is a reference view of what the platform produces and how the shared components relate to platform-specific ones.

## Relationship to generators/

The `generators/` directory is the working structure:

- `generators/claude-md.md` -- CLAUDE.md generation template
- `generators/features/` -- 17 composable feature blocks

`platforms/` organizes these same components from a distribution perspective: what does a Claude Code user get? What is shared across potential future platforms?

## Structure

```
platforms/
├── shared/
│   ├── features/     --> generators/features/ (17 canonical feature blocks)
│   ├── skill-blocks/ Frozen inventory of vocabulary points; generates nothing (see its README.md)
│   └── templates/    --> reference/templates/ (10 note type templates)
├── claude-code/
│   ├── generator.md  --> generators/claude-md.md (CLAUDE.md generation)
│   └── hooks/        Hook templates for Claude Code platform
└── README.md         This file
```

## How platforms/ is used

Nothing reads it to generate or package anything. There is no build step (see the root `CLAUDE.md`), and no file under `skills/`, `generators/` or `presets/` references `platforms/` (see `reference/skill-authoring.md`). The plugin ships as the repository, with `skills/`, `reference/` and `methodology/` beside this directory.

The `generators/` directory remains the canonical source. Files here are not duplicated -- README files document the relationship and provide platform-specific context that the generator files themselves don't carry.

## What the platform produces

| Output | Claude Code |
|--------|-------------|
| Context file | CLAUDE.md |
| Hooks | .claude/hooks/ (bash scripts) |
| Settings | .claude/settings.json |
| Skills | .claude/skills/<name>/SKILL.md, generated from plugin skill-sources/ |
| Identity | Embedded in CLAUDE.md |
| Memory bootstrap | Embedded in CLAUDE.md |
