# Install Ars Contexta on Codex

**You are the model running inside Codex. This file is a procedure for you to
execute, not documentation for a human to read.** Work the steps in order. Every
step ends in an assertion; when one fails, stop and report which one, rather
than continuing to the next step.

The mapping between the tool names this plugin's skills declare and the names
you actually have is in `reference/hosts/codex-tools.md`.

## What "installed" means

`codex plugin list` reports `arscontexta@agenticnotetaking` as `installed` and
`enabled`, the installed tree contains all ten skills — `add-domain`,
`architect`, `ask`, `health`, `help`, `recommend`, `reseed`, `setup`,
`tutorial`, `upgrade` — and the eight external tools they shell out to are on
`PATH`.

## How this plugin loads — read before Step 2

Codex installs plugins from **marketplaces**, so this is two commands, not one:
register the marketplace, then install the plugin from it.
`.agents/plugins/marketplace.json` declares the marketplace `agenticnotetaking`
containing one plugin, `arscontexta`; `.codex-plugin/plugin.json` is the plugin
manifest and points at the skills with `"skills": "./skills/"`.

`codex plugin marketplace add` accepts a **local path** to a checkout, GitHub
shorthand `owner/repo[@ref]`, or an HTTPS or SSH Git URL. Use whichever the user
has.

**Codex copies rather than references, and that changes two things.** The
install lands in `$CODEX_HOME/plugins/cache/<marketplace>/<plugin>/<version>/`
and is a copy of the whole repository, skills included. So unlike the OpenCode
and Pi adapters, nothing here resolves a path relative to a file that could be
moved — there is no copy-versus-symlink hazard to avoid. But the copy is
**pinned to the version in the manifest**, which means a `git pull` in the
source checkout changes nothing about what Codex runs. See Updating.

**Everything in this section was measured on `codex-cli 0.146.0`**, against a
local-path marketplace, with `CODEX_HOME` pointed at a scratch directory. What
was *not* measured is whether Codex's agent then discovers and invokes those
skills — there is no `codex skill list` to ask. Step 4 is where you settle that.

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
if command -v codex >/dev/null 2>&1; then echo "ok      codex ($(codex --version 2>/dev/null))"
else echo "MISSING codex"; missing="$missing codex"; fi
if [ -z "$missing" ]; then echo "PREREQS: PASS"
else echo "PREREQS: FAIL —$missing"; exit 1; fi
```

**Assert:** the last line reads `PREREQS: PASS`.

**On failure:** report the missing names and stop. `rg` is ripgrep; the rest
install under their own names. The eight tool names are the prerequisite table
in `README.md` — if the two ever disagree, the table is authoritative.

## Step 2 — Add the marketplace and install the plugin

**Ask the user for the source** — you have to be told this. It is either the
absolute path of a local checkout, or a Git source (`owner/repo`,
`owner/repo@ref`, or an HTTPS/SSH URL). If they are already working inside a
checkout, `git rev-parse --show-toplevel` answers it without asking.

```bash
SRC=/absolute/path/to/arscontexta   # or owner/repo[@ref] or an HTTPS/SSH Git URL

mp=$(codex plugin marketplace add "$SRC" --json) || {
  echo "INSTALL: FAIL — marketplace add rejected $SRC"; exit 1; }
name=$(printf '%s' "$mp" | jq -r '.marketplaceName // empty')
root=$(printf '%s' "$mp" | jq -r '.installedRoot // empty')
if [ -z "$name" ]; then
  echo "INSTALL: FAIL — marketplace add returned no marketplaceName: $mp"; exit 1
fi
echo "  marketplace $name -> $root"

# Do NOT gate on `codex plugin list` .available before installing. Measured on
# codex-cli 0.146.0, that array is EMPTY both before and after adding the
# marketplace, while `plugin add` succeeds — so treating it as a precondition
# reports a working marketplace as a broken one. Gate on the add result instead.
pa=$(codex plugin add "arscontexta@$name" --json) || {
  echo "INSTALL: FAIL — plugin add failed for arscontexta@$name"; exit 1; }
ip=$(printf '%s' "$pa" | jq -r '.installedPath // empty')
ver=$(printf '%s' "$pa" | jq -r '.version // empty')
if [ -z "$ip" ] || [ ! -d "$ip" ]; then
  echo "INSTALL: FAIL — plugin add reported no usable installedPath: $pa"; exit 1
fi

# Count skills by the property that defines one — a directory holding SKILL.md.
# `ls -1 | wc -l` counts entries, so a stray file fails a good install.
n=$(find "$ip/skills" -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')
if [ "$n" -ne 10 ]; then
  echo "INSTALL: FAIL — expected 10 skills in the installed tree $ip/skills, found $n"; exit 1
fi

if codex plugin list --json \
   | jq -e --arg id "arscontexta@$name" \
       '.installed[]? | select(.pluginId == $id) | select(.installed and .enabled)' >/dev/null; then
  echo "INSTALL: PASS — $ver at $ip, $n skills, installed and enabled"
else
  echo "INSTALL: FAIL — $name installed but codex does not report it enabled"; exit 1
fi
```

**Assert:** the last line reads `INSTALL: PASS`.

**On failure:** report which branch fired and the raw JSON where the message
carries it. The manifest declares `authPolicy: ON_INSTALL`, so an install may
prompt for authentication; that is not a failure, but it does mean this step is
not always non-interactive.

Re-running is safe: `marketplace add` reports `alreadyAdded: true` rather than
duplicating, and `plugin add` reinstalls the same version into the same path.

## Step 3 — Restart

Ask the user to restart Codex, and continue in the new session. A session that
was already running when Step 2 completed has not loaded the plugin.

## Step 4 — Confirm the skills are usable

Step 2 proved the files are on disk and Codex reports the plugin enabled. It did
**not** prove the skills are reachable from a session, and that is the gap this
step closes — there is no `codex skill list`, so the check is behavioural.

Confirm all ten names from the success criterion are available to you as skills.

**Assert:** ten of ten present.

**Do not verify by invoking a skill.** Whether Codex takes a bare name or a
namespaced form is not verified by this repository —
`reference/hosts/codex-tools.md` says the invocation syntax is unverified. A
failed invocation cannot distinguish a broken install from an unknown syntax,
and those have different fixes.

**On failure:** the plugin is installed and enabled, so the fault is between
Codex and the manifest rather than in Step 2. Report it as such, and say which
of the ten are missing — all, or some.

## Step 5 — Measure what this repo has not verified

`README.md` marks Codex **"Verified: not yet"**, and Step 2's mechanics are now
measured while the skill surface is not. Settle the rest:

1. **The tool names** in `reference/hosts/codex-tools.md` — compare each against
   the tools you actually have.
2. **Invocation syntax** — bare name or namespaced form.
3. **Whether `"skills": "./skills/"` is honoured** as the discovery path, or
   whether Codex expects something else and found these another way.

Where a finding contradicts `reference/hosts/codex-tools.md`, correct that file.
**Do not touch README's "Verified: not yet" row** — a successful install is not
a verified adapter, and only running the skills establishes that.

## Step 6 — Report

State all of: the source you registered and the marketplace name it produced,
the installed version and path, the Step 1 results, whether ten of ten skills
were available, and each Step 5 finding with its evidence.

## Do not report success if

- any prerequisite is missing — that failure surfaces later, inside a skill
- `find` did not count ten skills in the **installed tree**; counting them in
  the source checkout proves nothing about what Codex copied
- you gated on `codex plugin list` `.available` — it is empty on a healthy
  install, so an abort there is a false negative, not a finding
- fewer than ten skills were available in Step 4, even though Step 2 passed
- you could not complete Step 3

A plausible summary over a step that did not run is this repository's cardinal
defect class.

## Updating

**`git pull` in the source checkout does not update Codex.** The install is a
copy pinned to the manifest version, under a version-named directory. To move to
a new version: `codex plugin marketplace upgrade <name>` refreshes a **Git**
marketplace snapshot, then `codex plugin add arscontexta@<name>` installs the
refreshed version. For a local-path marketplace the source is read from disk, so
re-running `plugin add` after the manifest version changes is what installs it.

**Neither upgrade path was measured** — only a first install was. So confirm the
`version` in `plugin add --json` actually changed, rather than assuming the
refresh took effect. Where the version is unchanged, `installedPath` is the same
directory and nothing moved.
