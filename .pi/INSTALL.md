# Install Ars Contexta on Pi

**You are the model running inside Pi. This file is a procedure for you to
execute, not documentation for a human to read.** Work the steps in order. Every
step ends in an assertion; when one fails, stop and report which one, rather
than continuing to the next step.

The mapping between the tool names this plugin's skills declare and the names
you actually have is in `reference/hosts/pi-tools.md`.

## What "installed" means

All ten skills — `add-domain`, `architect`, `ask`, `health`, `help`,
`recommend`, `reseed`, `setup`, `tutorial`, `upgrade` — are discoverable by Pi,
and the eight external tools they shell out to are on `PATH`. That is the
success criterion, and nothing below satisfies it until Step 4 confirms it in a
restarted session.

## How this extension loads — read before Step 2

`.pi/extensions/arscontexta.ts` subscribes to `resources_discover` and returns
`{ skillPaths: [<repo>/skills] }`. Pi loads extensions through jiti, so the
TypeScript needs no build step, and the file's only import is type-only and
erased — this repository deliberately ships no `package.json`.

Pi offers three ways in, and **which one you pick decides whether the extension
can find the skills at all**:

1. **A path in `settings.json`.** The `extensions` array takes absolute paths to
   local files or directories. The file stays where it is. **This is the route
   to use**, and Step 2 uses it.
2. **An auto-discovered directory** — `~/.pi/agent/extensions/*.ts` for every
   project, `.pi/extensions/*.ts` for the current one. Correct only when the
   file is *already* in such a directory, which is true exactly when the user's
   project is a checkout of this repository.
3. **A pi package** via `packages` (`git:github.com/...`). **Closed to this
   repository by design.** Distributed packages need a `package.json` declaring
   `pi.extensions`, and this repo has none — the extension's own header comment
   says why. Do not add one to make this route work.

The property that rules out the obvious move: the extension finds the skills at
`../..` **relative to its own location**, so it only works while it sits inside
a checkout. **Copying it into `~/.pi/agent/extensions/` breaks it** — from
there, `../..` is `~/.pi`, and it registers `~/.pi/skills`, which does not
exist. That failure is silent: the extension loads, the handler returns a path,
and no skills appear, with nothing reported. Route 1 avoids it entirely by never
moving the file.

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

## Step 2 — Register the extension by path

**Establish two things from the user before running anything.**

1. **Where is the checkout of this repository?** You need its absolute path. If
   the user is already working inside it, `git rev-parse --show-toplevel`
   answers this without asking.
2. **Global or project-only?** Global is `~/.pi/agent/settings.json` and applies
   everywhere, which is what someone who wants a knowledge system in their own
   projects needs. Project-only is `.pi/settings.json` in the project they are
   working in, and Pi will not read it until they trust that project. Prefer
   global unless the user asks otherwise; if they choose project-local, set
   `CFG` accordingly and expect a trust prompt at the next start.

**This step edits a settings file the user already owns.** It merges rather than
replaces, keeps a backup, and proves afterwards that no existing key was lost.

```bash
REPO=/absolute/path/to/arscontexta          # set this before running
EXT="$REPO/.pi/extensions/arscontexta.ts"
CFG="$HOME/.pi/agent/settings.json"         # or .pi/settings.json for project-only

if [ ! -f "$EXT" ]; then
  echo "INSTALL: FAIL — no extension at $EXT"; exit 1
fi

# Count skills by the property that defines one — a directory holding SKILL.md.
# `ls -1 | wc -l` counts entries, so a stray file (a macOS .DS_Store) fails a good install.
n=$(find "$REPO/skills" -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')
if [ "$n" -ne 10 ]; then
  echo "INSTALL: FAIL — expected 10 skills under $REPO/skills, found $n"; exit 1
fi

mkdir -p "$(dirname "$CFG")" || { echo "INSTALL: FAIL — cannot create $(dirname "$CFG")"; exit 1; }
[ -f "$CFG" ] || echo '{}' > "$CFG"

if ! jq -e 'type == "object"' "$CFG" >/dev/null 2>&1; then
  echo "INSTALL: FAIL — $CFG is not a JSON object; refusing to touch it"; exit 1
fi
cp "$CFG" "$CFG.arscontexta-backup" || { echo "INSTALL: FAIL — could not back up $CFG"; exit 1; }

if ! jq --arg p "$EXT" \
     'if ((.extensions // []) | index($p)) then . else .extensions = ((.extensions // []) + [$p]) end' \
     "$CFG" > "$CFG.tmp"; then
  echo "INSTALL: FAIL — jq could not rewrite $CFG; the original is untouched"
  rm -f "$CFG.tmp"; exit 1
fi

# Write THROUGH the existing file rather than mv-ing over it: mv replaces the
# inode and can silently change the file's mode, which nothing downstream reports.
if ! cat "$CFG.tmp" > "$CFG"; then
  echo "INSTALL: FAIL — could not write $CFG; restore from $CFG.arscontexta-backup"
  rm -f "$CFG.tmp"; exit 1
fi
rm -f "$CFG.tmp"

lost=$(jq -n --slurpfile a "$CFG.arscontexta-backup" --slurpfile b "$CFG" \
       '(($a[0]|keys) - ($b[0]|keys)) | length')
if [ "$lost" -ne 0 ]; then
  echo "INSTALL: FAIL — $lost existing setting(s) disappeared; restore $CFG.arscontexta-backup"; exit 1
fi

if jq -e --arg p "$EXT" '.extensions | index($p)' "$CFG" >/dev/null; then
  echo "INSTALL: PASS — $CFG lists $EXT, $n skills reachable, $lost settings lost"
else
  echo "INSTALL: FAIL — the path is not in $CFG after writing it"; exit 1
fi
```

**Assert:** the last line reads `INSTALL: PASS`.

**On failure:** report which branch fired. Where a backup was already written,
say where it is — the user's settings file matters more than this install.

Running this twice is a no-op: the path is appended only when absent, and the
array is never sorted, so an order the user chose is preserved.

## Step 3 — Restart

You cannot restart Pi yourself. Ask the user to restart it, and continue in the
new session.

**`/reload` is not a substitute here.** Pi hot-reloads extensions in
*auto-discovered* locations; this install registers a path through
`settings.json`, which is read at startup. If the user chose project-local
settings, they will also see a trust prompt — Pi does not load `.pi/settings.json`
or project extensions until the project is trusted.

## Step 4 — Confirm the skills loaded

List the skills available to you and confirm all ten names from the success
criterion appear.

**Assert:** ten of ten present.

**Do not verify by invoking a skill.** Whether Pi takes a bare name or a
namespaced form is not verified by this repository —
`reference/hosts/pi-tools.md` says the invocation syntax is unverified. A failed
invocation therefore cannot distinguish a broken install from an unknown syntax,
and those have different fixes. Listing separates them.

**On failure:** an empty result means the extension never loaded — confirm the
path in `settings.json` and, for project-local installs, that the project was
trusted. **A result that is empty rather than wrong is the expected shape of the
copy mistake**, so also confirm the registered path still points inside a
checkout and was not copied out of one.

## Step 5 — Measure what this repo has not verified

`README.md` marks Pi **"Verified: not yet"**. Several claims are believed rather
than measured, and you are the first reader in a position to settle them,
because you are inside Pi looking at the real surface.

1. **The tool names** in `reference/hosts/pi-tools.md` — compare each against
   the tools you actually have.
2. **Invocation syntax** — bare name or namespaced form. Determine which.
3. **That `resources_discover` is enough.** The extension assumes returning
   `skillPaths` makes the skills invocable. Confirm they are, not merely listed.

Where a finding contradicts `reference/hosts/pi-tools.md`, correct that file.
**Do not touch README's "Verified: not yet" row** — a successful install is not
a verified adapter, and only running the skills establishes that.

## Step 6 — Report

State all of: which settings file you edited and the checkout path you
registered, the Step 1 results, whether ten of ten skills appeared, and each
Step 5 finding with the evidence behind it.

## Do not report success if

- any prerequisite is missing — that failure surfaces later, inside a skill
- `find` did not count ten skills under the checkout you registered
- fewer than ten skills appeared, even if the extension itself loaded
- you could not complete Step 3. A Pi that has not restarted has loaded nothing;
  say so plainly rather than reporting Step 2 as the install

A plausible summary over a step that did not run is this repository's cardinal
defect class, and this extension's own failure mode is silence: a wrong path
returns cleanly and registers nothing.

## Updating

The registered path points into a git checkout, so updating is
`git -C <checkout> pull` followed by a restart. Nothing is copied and no package
is installed, so a pull is immediately live. Confirm the skills still appear
afterwards; an upstream change that adds or renames one moves the count this
file asserts.
