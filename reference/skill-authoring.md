# Authoring a skill in this repo

For anyone — human or agent — adding or editing a `SKILL.md`. Read [`CONTRIBUTING.md`](../CONTRIBUTING.md)
first: it carries the environment checks, the three traps, and the two invariants. This document does
not restate them. It answers the five questions that come *after* those, each of which has already
produced a confident wrong answer here.

---

## §1 — Which tree am I editing?

**Start with the predicate, not the directory name.** Open the file and look for `{vocabulary.` or
`{config.`:

| The file contains | It is | Consequence |
|---|---|---|
| `{vocabulary.*}` or `{config.*}` | a **template** | copied into user vaults at generation time. Never substitute a placeholder with a concrete value. |
| neither, and lives under `skills/` | a **plugin command** | the plugin's own `/arscontexta:<name>`. Never copied. Placeholders here are a defect. |

The predicate matters more than the path because the paths are easy to confuse and one of them is a
trap:

| Tree | Count | Generates? | Edit it? |
|---|---|---|---|
| `skill-sources/` | 16 | yes — becomes `/<name>` in every generated vault | **yes** |
| `skills/` | 10 | no — is the plugin's own commands | **yes** |
| `platforms/shared/skill-blocks/` | 16 | **no — nothing reads it** | **no; frozen** |

The third row is the trap. It looks like a second copy of `skill-sources/` and it is not: **nothing
generates from it.** No file under `skills/`, `generators/`, `hooks/` or `presets/` references
`platforms/` at any depth. (`reference/` does — the freeze check, its tests, and this document — but
those inspect the directory, they do not generate from it.) A guard fixed there reaches no user. `check-portability.sh` rejects edits to it; see
`platforms/shared/skill-blocks/README.md` for why it is kept.

**Backporting from a field vault reverses two transforms.** A vault speaks its derived dialect and
its own concrete paths; a template speaks canonical names and placeholders. Copy-pasting a vault fix
into `skill-sources/` without reversing both passes every gate and ships one user's vocabulary to
everyone. Canonical names are in `reference/vocabulary-transforms.md`.

---

## §2 — Placeholders

Four families. `{vocabulary.*}` resolves from `vocabulary.yaml`, `{config.*}` from `preset.yaml`,
`{DOMAIN:*}` from the derivation conversation (an older spelling, still live), and
`{if …}` … `{endif}` for conditional blocks.

**Inventing a token is not a silent failure.** The fence gate's `map_value()` returns 1 on an unmapped
placeholder; the harness prints the token and exits 1. You get a named error, never a skipped fence.

**To find out whether a given string is vocabulary-variable, read
`platforms/shared/skill-blocks/`.** It is frozen and generates nothing, but it carries the repo's most
complete markup. Count it yourself — a placeholder tally that does not state its pattern cannot be
re-derived, and one written here previously could not be:

Run this **from the repo root** — it is `text` rather than `bash` deliberately, and §5 says why: the
fence gate executes every ```bash block against a generated-vault fixture, where `skill-sources/`
does not exist. Marked `bash` it would print three rows of zeros and exit 0 — a plausible answer to a
question it never asked, which is the failure this document is about.

```text
PAT='{vocabulary\.[a-z_]*}\|{config\.[a-z_]*}\|{DOMAIN:[^}]*}'
for p in verify validate reflect; do
  printf '%-9s source=%-4s blocks=%s\n' "$p" \
    "$(grep -o "$PAT" "skill-sources/$p/SKILL.md" | wc -l | tr -d ' ')" \
    "$(grep -o "$PAT" "platforms/shared/skill-blocks/$p.md" | wc -l | tr -d ' ')"
done
```

That yields `verify` 27 against 146 and `validate` 5 against 60, while `reflect` is 121 against 203 —
the gap is widest exactly where `skill-sources` is sparsest, which is where you need the answer. Do
not widen the pattern to a bare `{…}`: that also matches `${TARGET}` and `${FILE}`, inflating a
shell-variable count into a placeholder count. Consult this directory; do not edit it, and do not port
behavior into it.

Two things that look vocabulary-variable and are not: frontmatter *type values* such as `type: moc`
are structural and appear untemplated across `skill-sources/`, while the MOC *filename* is
vocabulary-variable. When unsure, match what the sibling templates already do.

---

## §3 — Fences, and when a guard fires

`CONTRIBUTING.md` INVARIANT 1 states the rule: each ```bash fence is its own shell invocation and
nothing crosses a fence boundary. Two consequences for authoring:

**Prefer extending an existing fence to opening a new one.** A new fence must re-establish every
variable and re-source every library it uses. Adding a computation next to the ones already there
inherits their guards and their setup for free.

**The guard, and the sentence most often omitted:**

```bash
NOTES_DIR="{vocabulary.notes}"
[ -d "$NOTES_DIR" ] || { printf 'error: %s is absent\n' "$NOTES_DIR" >&2; exit 1; }
COUNT=$(find "$NOTES_DIR" -type f -name '*.md' | wc -l | tr -d ' ')
printf 'Notes: %s\n' "$COUNT"
```

**It fires only when its precondition is genuinely absent.** On a healthy vault the directory exists,
the guard never triggers, and the fence exits 0 with its number. Apply the shape *unconditionally* —
to a fence that has no such precondition, or that must succeed on a healthy tree — and you get a
fence that exits non-zero while writing stderr, which is what assertion H fails. The guard is correct;
applying it where nothing can be absent is the defect.

**Counting wiki-links, orphans, or dangling links? Source the library; do not write the pattern.**
`reference/lib/link-extraction.sh` is the single definition of link counting and resolution, and
`check-portability.sh` rejects inlined copies of it. The naive spelling —
`grep -rl "[[$NAME]]" | wc -l` — is the one every author reaches for and it is wrong in three ways at
once: it counts links inside fenced code blocks, it does not case-fold, and it matches the wrong
direction for orphan detection. That last one is a documented accepted defect in two shipped
templates, which is exactly why it must not spread to a third. Prefer the `*_recursive` variants: a
vault with no subdirectories today may grow one tomorrow, and the flat scan under-reports silently
rather than failing.

What the gate asserts, cited by letter so this table cannot drift from it:

| Letter | The gate asserts | What satisfies it |
|---|---|---|
| H | on the healthy fixture, no non-zero exit that also writes stderr or a computed number | let the fence succeed when its preconditions hold |
| N | never `rc 0` with digits when the notes directory is absent | the guard above, before any count |
| U | no read of a variable defined in another fence | declare it in this fence, or take it from `$ARGUMENTS` |
| S | no stale allowlist entry | if you fix a listed fence, delete its line |

Run `reference/test/fence-isolation.test.sh <path>` to check one file in seconds instead of sweeping
all of them.

---

## §4 — Prose contracts

**A prose contract is any table, output format, or signal list that tells Claude what to produce.**
Claude follows it as literally as it follows a bash line, so a contract promising something no code
computes is a defect that renders as a plausible number rather than an error.

A field in an output-format table is a contract. One template here promises eight state fields and
computes five; the remaining three are named in prose up to twenty-one times and assigned nowhere, so
the run emits the line and invents them.

**Three clauses. A contract missing any one of them is incomplete:**

| Clause | States |
|---|---|
| precondition | what must be true before the block runs |
| failure signature | what the reader sees when it is *not* — and it must not be a number |
| verifier, and when | which command confirms it, and under what condition it fires |

Two checkable rules:

- **Every filesystem path named in a prose contract must exist in the packaged plugin.** Verify
  against the installed copy, not the checkout — the plugin cache interposes a version directory, and
  checking one level too high reports a false absence.
- **Prose and code move in the same commit.** A narrow table beside a widened bash line is the same
  defect in a different font.

---

## §5 — Which fence type

The fence gate extracts and executes every ```bash fence in **its scan set** — every `SKILL.md` under
`skill-sources/` and `skills/`, plus this document. It does **not** reach bash blocks in
`CONTRIBUTING.md`, `CLAUDE.md`, `generators/`, `presets/`, `hooks/` or `README.md`; those are read by
humans and by Claude but never executed by a gate, so their correctness rests on review alone.

Inside the scan set: a working example belongs in ```bash and must pass H/N/U/S in both shells,
against a **generated-vault fixture** — so a block that needs the plugin repo's own directories will
not find them there. **A counter-example, or anything that must run somewhere other than a vault,
goes in ```text**, or the gate executes it and correctly reports it. That is the only reason this
document can show a wrong pattern at all:

```text
COUNT=$(ls "$DIR"/*.md | wc -l)      # $DIR from another fence: empty, folds to 0, exits 0
```

---

## When you have finished

The four gates are **not independent** — `guard-failure.test.sh` invokes `check-portability.sh`, so a
change to one guard alters the behavior every other caller sees. Run all of them, in both shells,
after any edit. `CONTRIBUTING.md` carries the commands and the expected results.
