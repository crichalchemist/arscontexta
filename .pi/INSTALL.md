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

## How Pi finds these skills — read before Step 2

**There is no Pi extension in this repository, and none is needed.** One existed
and was deleted. Its entire body registered a `skills/` directory that Pi
already finds on its own, so it was a second way to get the same result and a
second way to get it wrong.

The mechanism is Pi's own, documented under *Packages → Convention Directories*:
when a package ships no `pi` manifest, Pi auto-discovers `skills/` from the
package root, finding every directory that holds a `SKILL.md`. This repository
ships no `package.json` at all, so the convention applies and the ten skills
register with nothing declared.

Two routes reach that, and the difference between them is **whether the
installed copy tracks your checkout**:

1. **Package install — the default.** `pi install git:<url>` clones to
   `~/.pi/agent/git/<host>/<path>` and appends the source to `packages` in
   settings. **That clone is a snapshot.** A later `git pull` in some other
   working copy does not touch it; `pi update --extensions` reconciles it to the
   configured ref. Use this when the user wants the plugin, not the repository.
2. **Local directory — for working on this repo.** `pi install /absolute/path`
   registers a directory **in place, without copying**, and Pi applies the same
   package rules to it. Edits in that checkout are live at the next restart. Use
   this when the user already has a checkout they intend to edit.

Both write user settings (`~/.pi/agent/settings.json`) by default; `-l` writes
project settings (`.pi/settings.json`) instead, which requires the project to be
trusted before Pi will load anything from it.

A third route exists and is narrower: a `skills` array in settings takes
directories directly, so `"skills": ["/absolute/path/to/this/repo/skills"]`
registers the skills without registering the repository as a package. Prefer
route 1 or 2 — this one is here so you recognise it in a settings file you did
not write.

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

## Step 2 — Install

Pick exactly one source, per the two routes above. If the user's intent is not
obvious from context, ask which before running anything — route 1 leaves them a
snapshot they will later wonder why `git pull` does not update.

```bash
# Choose ONE. Route 1 clones a snapshot; route 2 registers a live checkout.
SRC="git:https://github.com/agenticnotetaking/arscontexta"
# SRC="/absolute/path/to/arscontexta"

pi install "$SRC" || { echo "INSTALL: FAIL — pi install rejected $SRC"; exit 1; }

# Ask Pi where it put it rather than assuming: route 1 clones into
# ~/.pi/agent/git/..., route 2 registers the path unchanged.
ROOT=$(pi list 2>/dev/null | awk -v s="$SRC" '
  { line=$0; sub(/^[[:space:]]+/,"",line); sub(/[[:space:]]+$/,"",line)
    if (found) { print line; exit }
    if (line == s) found=1 }')

if [ -z "$ROOT" ]; then
  echo "INSTALL: FAIL — pi list does not show $SRC. Registered sources are:"
  pi list 2>&1
  exit 1
fi
if [ ! -d "$ROOT" ]; then
  echo "INSTALL: FAIL — pi resolved $SRC to $ROOT, which is not a directory"; exit 1
fi

# Count skills by the property that DEFINES one — a directory holding SKILL.md.
# `ls -1 | wc -l` counts directory entries instead, so one stray file (a macOS
# .DS_Store) fails a healthy install and a missing SKILL.md passes a broken one.
n=$(find "$ROOT/skills" -maxdepth 2 -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$n" -eq 10 ]; then
  echo "INSTALL: PASS — $SRC -> $ROOT, $n skills present for convention discovery"
else
  echo "INSTALL: FAIL — expected 10 skills under $ROOT/skills, found $n"; exit 1
fi
```

**A PASS here means the files are in place, not that Pi has loaded them.**
Convention discovery runs at startup, so nothing is registered in the current
session. Step 4 is what closes that gap.

## Step 3 — Restart

Pi reads `packages` when it starts. Restart it before checking anything.

**Do not substitute `/reload`.** It is documented for extensions, and this
install registers no extension — whether it re-runs package discovery is not
established here, so a `/reload` that appears to do nothing is indistinguishable
from a failed install. Restart, and the ambiguity does not arise.

If the install used `-l` (project settings), expect a trust prompt: Pi loads
nothing from `.pi/settings.json` until the project is trusted. An untrusted
project produces exactly the symptom of a broken install — no skills, no error.

## Step 4 — Confirm the skills loaded

List the skills available to you and confirm all ten names from the success
criterion appear.

**Assert:** ten of ten present.

**Do not verify by invoking a skill.** Whether Pi takes the bare name or a
namespaced form is not established by this repository —
`reference/hosts/pi-tools.md` records the invocation syntax as unverified. A
failed invocation therefore cannot distinguish a broken install from unknown
syntax, and those have different fixes. Listing separates them.

**On failure, the shape of the result tells you which thing broke:**

- **No arscontexta skills at all** — discovery never ran against this package.
  Re-check that `pi list` still shows the source, that Pi was actually
  restarted, and, for a project-local install, that the project was trusted.
- **Some but not ten** — discovery ran and found a `skills/` tree that is not
  this one, or one that is incomplete. Re-run the Step 2 count against the
  `ROOT` Pi reports now, not the one you recorded earlier.

## Step 5 — Measure what this repo has not verified

`README.md` marks Pi **"Verified: not yet"**. Several claims there are believed
rather than measured, and you are the first reader in a position to settle them,
because you are inside Pi looking at the real surface.

1. **The tool names** in `reference/hosts/pi-tools.md` — compare each against
   the tools you actually have.
2. **Invocation syntax** — bare name or namespaced form. Determine which.
3. **That discovery is sufficient.** Appearing in a skill listing is not the
   same as being invocable. Confirm one actually runs.

Where a finding contradicts `reference/hosts/pi-tools.md`, correct that file.

**Do not touch README's "Verified: not yet" row.** A successful install does not
verify the adapter; only running the skills does.

## Step 6 — Report

State all of: which route and source you used, the `ROOT` Pi resolved it to, the
Step 1 results, whether ten of ten skills appeared after the restart, and any
Step 5 finding with the evidence behind it.

## Do not report success if

- any prerequisite was missing — that failure surfaces later, inside a skill
- `find` did not count ten skills under the `ROOT` Pi reported
- fewer than ten skills appeared after the restart
- Pi was not restarted. A Pi that has not restarted has loaded nothing; say so
  plainly rather than reporting Step 2's PASS as the outcome.

A plausible summary written over a step that did not run is this repository's
cardinal defect class. It is also the specific failure this install is shaped to
avoid: convention discovery pointed at the wrong directory finds nothing,
returns cleanly, and reports no error.

## Updating

**The route decides this, and getting it wrong is silent.**

- **Route 1 (git package).** The clone under `~/.pi/agent/git/` is independent of
  any other working copy. `git pull` elsewhere does nothing to it. Use
  `pi update <source>`, or `pi update --extensions` to reconcile every package
  to its configured ref. Restart afterwards.
- **Route 2 (local directory).** `git -C <checkout> pull`, then restart. Nothing
  was copied, so the pull is live immediately.

Either way, confirm the ten skills still appear: an upstream change that adds or
renames one moves the count this file asserts.

**Do not add a `package.json` with a `pi` key to this repository.** Convention
discovery applies only when no `pi` manifest is present, so adding one turns it
off — and a manifest that declares `extensions` but forgets `skills` produces an
install that registers nothing while looking deliberate.
