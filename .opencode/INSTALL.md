# Install Ars Contexta on OpenCode

**You are the model running inside OpenCode. This file is a procedure for you to
execute, not documentation for a human to read.** Work the steps in order. Every
step ends in an assertion; when one fails, stop and report which one, rather
than continuing to the next step.

Use OpenCode's own tool names as you go — `bash` to run commands, `read` to read
files, `apply_patch` to edit them. The mapping between the names this plugin's
skills declare and the names you actually have is in
`reference/hosts/opencode-tools.md`.

## What "installed" means

All ten skills — `add-domain`, `architect`, `ask`, `health`, `help`,
`recommend`, `reseed`, `setup`, `tutorial`, `upgrade` — appear in your `skill`
tool's listing, and the eight external tools they shell out to are on `PATH`.
That is the success criterion, and nothing below satisfies it until Step 4
confirms it in a restarted session.

## How this plugin loads — read before Step 2

OpenCode loads plugins two ways: files placed in a plugin directory, which are
loaded automatically at startup, and npm packages named in the `plugin` array of
`opencode.json`.

**This adapter uses the directory mechanism, and cannot use the other one.** The
`plugin` array takes npm packages, which OpenCode installs with Bun into
`~/.cache/opencode/node_modules/`; this repository ships no `package.json`, so
it has no package name, no version and no entry point for Bun to resolve. An
entry in that array will not install it.

The two plugin directories are `.opencode/plugins/` for the current project and
`~/.config/opencode/plugins/` for every project. Which one you want depends on
where the user works, so Step 2 begins by settling that.

One property governs the whole step: `.opencode/plugins/arscontexta.js` finds
the skills at `../../skills` **relative to its own real location**, so it only
works while it sits inside a checkout of this repository. Copying the file into
a plugin directory detaches it from `skills/` and it will load and register
nothing. Symlinking it does work — both Bun and Node resolve a symlinked module
to its real path before evaluating it, so `../../skills` still lands inside the
checkout. Step 2 asserts this rather than trusting it.

## Step 1 — Prerequisites

The skills shell out to these. A missing one fails at run time, long after the
install looks finished, so check now.

```bash
missing=""
for t in rg tree awk sed jq bc git python3; do
  if command -v "$t" >/dev/null 2>&1; then echo "ok      $t"
  else echo "MISSING $t"; missing="$missing $t"; fi
done
if python3 -c 'import yaml' >/dev/null 2>&1; then echo "ok      PyYAML"
else echo "MISSING PyYAML"; missing="$missing PyYAML"; fi
if [ -z "$missing" ]; then echo "PREREQS: PASS"
else echo "PREREQS: FAIL —$missing"; exit 1; fi
```

**Assert:** the last line reads `PREREQS: PASS`.

**On failure:** report the missing names and stop. `rg` is ripgrep; the rest
install under their own names. This list is the prerequisite table in
`README.md` — if the two ever disagree, the table is authoritative.

## Step 2 — Put the adapter on a plugin path

**Establish two things from the user before running anything.** You have no
`AskUserQuestion` tool here, so ask in prose and parse the reply.

1. **Where is the checkout of this repository?** You need its absolute path.
   If the user is already working inside it, `git rev-parse --show-toplevel`
   answers this without asking.
2. **Global or project-only?** Global — `~/.config/opencode/plugins/` — makes
   the skills available in every project, which is what someone who wants a
   knowledge system in their own vault needs. Project-only is right when the
   only project they will use it from is the checkout itself, and in that case
   the adapter is already on a plugin path and Step 2 has nothing to do: skip to
   Step 3.

For the global case, set `REPO` to the absolute checkout path and run:

```bash
REPO=/absolute/path/to/arscontexta        # set this before running
LINK="$HOME/.config/opencode/plugins/arscontexta.js"

if [ ! -f "$REPO/.opencode/plugins/arscontexta.js" ]; then
  echo "INSTALL: FAIL — no adapter at $REPO/.opencode/plugins/arscontexta.js"; exit 1
fi
if [ ! -d "$REPO/skills" ]; then
  echo "INSTALL: FAIL — no skills/ directory in $REPO"; exit 1
fi

mkdir -p "$HOME/.config/opencode/plugins" || { echo "INSTALL: FAIL — cannot create the plugin directory"; exit 1; }

# Symlink, never copy: the adapter resolves skills/ relative to its real path.
if ! ln -sfn "$REPO/.opencode/plugins/arscontexta.js" "$LINK"; then
  echo "INSTALL: FAIL — could not create $LINK"; exit 1
fi
if [ ! -L "$LINK" ] || [ ! -e "$LINK" ]; then
  echo "INSTALL: FAIL — $LINK is not a symlink that resolves"; exit 1
fi

# Count skills by the property that defines one — a directory holding SKILL.md.
# `ls -1 | wc -l` counts entries, so a stray file (a macOS .DS_Store) fails a good install.
n=$(find "$REPO/skills" -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')
if [ "$n" -eq 10 ]; then
  echo "INSTALL: PASS — $LINK -> $REPO, $n skills reachable"
else
  echo "INSTALL: FAIL — expected 10 skills in $REPO/skills, found $n"; exit 1
fi
```

**Assert:** the last line reads `INSTALL: PASS`.

**On failure:** report which of the five branches fired. Do not tell the user to
restart — an unresolvable symlink loads nothing, and a wrong `REPO` produces a
link that exists and registers an empty directory, which is the worse outcome
because it looks installed.

Running this twice is a no-op; `ln -sfn` replaces an existing link in place, so
it is safe to re-run after a partial attempt.

## Step 3 — Restart

You cannot restart OpenCode yourself. Ask the user to restart it, and continue
in the new session. Everything below is worthless until they have.

## Step 4 — Confirm the skills loaded

**Use the `skill` tool to list the available skills.** Confirm all ten names
from the success criterion appear.

**Assert:** ten of ten present.

**Do not verify by invoking a skill.** Whether OpenCode takes a bare name or a
namespaced form is not verified by this repository —
`reference/hosts/opencode-tools.md` says so under "Unverified". A failed
invocation therefore cannot distinguish a broken install from an unknown syntax,
and those have different fixes. Listing separates them: if the skills list, they
are installed, whatever the syntax for running one turns out to be.

**On failure:** the adapter registers this repo's `skills/` path by pushing it
into the live config as OpenCode reads it — there are no symlinks inside the
repo to check and no `skills.paths` entry the user was meant to add. So an empty
listing means the plugin file never loaded: confirm it is on one of the two
plugin paths. A partial listing means it loaded and registered the wrong
directory: re-check `REPO` from Step 2.

## Step 5 — Measure what this repo has not verified

`README.md` marks OpenCode **"Verified: not yet"**. Several claims in the
adapter are believed rather than measured, and you are the first reader in a
position to settle them, because you are inside OpenCode looking at the real
tool surface.

1. **The tool names.** `reference/hosts/opencode-tools.md` maps six —
   `read`, `apply_patch`, `bash`, `grep`, `glob`, `webfetch`. Compare each
   against the tools you actually have.
2. **`AskUserQuestion` has no OpenCode equivalent.** Four of the ten skills
   declare it — `add-domain`, `reseed`, `setup`, `tutorial` — and the mapping
   says they must degrade to asking in prose. If you do have a
   structured-question tool, that row is wrong and those four need not degrade.
3. **Invocation syntax.** Bare name or namespaced form. Determine which, and
   record it.

Where a finding contradicts `reference/hosts/opencode-tools.md`, correct that
file with `apply_patch`; its own closing section asks for exactly this. **Do not
touch README's "Verified: not yet" row** — a successful install is not a
verified adapter, and only running the skills establishes that.

## Step 6 — Report

State all of: which plugin path you used and the checkout it points at, the Step
1 results, whether ten of ten skills listed, and each Step 5 finding with the
evidence behind it.

## Do not report success if

- any prerequisite is missing — that failure surfaces later, inside a skill
- the symlink resolves but `skills/` did not hold ten entries
- fewer than ten skills listed, even if the plugin itself appears to have loaded
- you could not complete Step 3. An OpenCode that has not restarted has loaded
  nothing; say so plainly rather than reporting Step 2 as the install

A plausible summary over a step that did not run is this repository's cardinal
defect class. An install reported as complete without Step 4 is precisely that.

## Updating

The adapter is a symlink into a git checkout, so updating is `git -C <checkout>
pull` followed by a restart. There is no package cache in play — nothing is
copied and nothing is installed by Bun — so a pull is immediately live. Confirm
the skills still list after the restart; an upstream change that renames or adds
one moves the count this file asserts.
