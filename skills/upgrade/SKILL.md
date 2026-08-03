---
name: upgrade
description: Apply plugin knowledge base updates to an existing generated system. Consults the Ars Contexta research graph for methodology improvements, proposes skill upgrades with research justification. Never auto-implements. Triggers on "/upgrade", "upgrade skills", "check for improvements", "update methodology".
version: "1.0"
generated_from: "arscontexta-v1.6"
user-invocable: true
context: fork
model: opus
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

## Runtime Configuration (Step 0 — before any processing)

Read these files to configure domain-specific behavior:

1. **`ops/derivation-manifest.md`** — vocabulary mapping, platform hints
   - Use `vocabulary.notes` for the notes folder name
   - Use `vocabulary.note` / `vocabulary.note_plural` for note type references
   - Use `vocabulary.reduce` for the extraction verb
   - Use `vocabulary.reflect` for the connection-finding verb
   - Use `vocabulary.reweave` for the backward-pass verb
   - Use `vocabulary.verify` for the verification verb
   - Use `vocabulary.rethink` for the meta-cognitive verb
   - Use `vocabulary.topic_map` for MOC references

2. **`ops/config.yaml`** — processing depth, domain context

3. **`ops/derivation.md`** — derivation state and engine version

If these files don't exist, use universal defaults.

## EXECUTE NOW

**Target: $ARGUMENTS**

Parse immediately:
- If target contains a specific skill name (e.g., "upgrade reduce"): check only that skill
- If target contains "--all": check all generated skills
- If target is empty: check all generated skills (same as --all)

**START NOW.** Reference below defines the upgrade process.

---

## Why Consultation, Not Hashing

Skills do not upgrade through hash comparison against a generation manifest. Hash comparison answers a narrow question: "Has this file changed?" Meta-skill consultation answers the right question: "Is this skill's approach still the best approach given what we know?"

A skill could be unchanged but outdated because the knowledge base has grown. Or a skill could be heavily edited by the user but already incorporate the latest thinking through a different path. Reasoning about methodology is more valuable than diffing bytes.

---

## Two Upgrade Paths

Generated skills and meta-skills follow fundamentally different upgrade mechanisms:

| Category | Skills | Upgrade Mechanism |
|----------|--------|-------------------|
| **Generated skills** | /{vocabulary.reduce}, /{vocabulary.reflect}, /{vocabulary.reweave}, /{vocabulary.verify}, /ralph, /next, /remember, /{vocabulary.rethink}, /stats, /graph, /tasks, /refactor, /learn, /recommend, /ask | Runtime consultation with knowledge graph |
| **Meta-skills** | /setup, /architect, /health, /reseed, /add-domain, /help, /tutorial, /upgrade | Plugin release cycle — update the plugin itself |

/upgrade evaluates generated skills. It cannot evaluate itself or other meta-skills — that is the plugin maintainers' responsibility.

---

## Step 1: Inventory Current System

Gather the vault's current state:

1. Read `ops/derivation.md` for:
   - Original derivation state
   - Engine version that generated the system
   - Domain description and dimensional positions

2. Read `ops/generation-manifest.yaml` (if exists) for:
   - Skill versions and generation timestamps
   - Which plugin version generated each skill

3. List all installed skills:
   ```bash
   # Find all skill directories with SKILL.md
   for dir in .claude/skills/*/; do
     skill=$(basename "$dir")
     version=$(grep '^version:' "$dir/SKILL.md" 2>/dev/null | head -1 | awk -F'"' '{print $2}')
     gen_from=$(grep '^generated_from:' "$dir/SKILL.md" 2>/dev/null | head -1 | awk -F'"' '{print $2}')
     echo "$skill  v$version  (from $gen_from)"
   done
   ```

4. Read `ops/config.yaml` for current dimensional positions

5. Check for user modifications:
   ```bash
   # Detect skills modified after generation
   for dir in .claude/skills/*/; do
     skill=$(basename "$dir")
     file="$dir/SKILL.md"
     [[ ! -f "$file" ]] && continue
     # Check git status — modified files indicate user customization
     git_status=$(git status --porcelain "$file" 2>/dev/null)
     if [[ -n "$git_status" ]]; then
       echo "MODIFIED: $skill"
     fi
   done
   ```

Present inventory:

```
--=={ upgrade : inventory }==--

System: {domain description}
Engine: arscontexta-{version}
Skills: {count} installed ({modified_count} user-modified)

  Skill               Version  Generated From    Modified
  /{vocabulary.reduce}    1.0  arscontexta-v1.6  no
  /{vocabulary.reflect}   1.0  arscontexta-v1.6  yes
  ...
```

---

## Step 2: Consult Knowledge Base

For each generated skill (or the specific skill if targeted), consult the plugin's bundled knowledge base to evaluate whether the skill's current approach reflects current best practices.

### Knowledge Base Tiers

Read from the plugin's four content tiers:

| Tier | Path | What It Contains |
|------|------|------------------|
| Methodology graph | `${CLAUDE_PLUGIN_ROOT}/methodology/` | All content — filter by `kind:` field (research/guidance/example) |
| Reference docs | `${CLAUDE_PLUGIN_ROOT}/reference/` | WHAT — structured reference documents and dimension maps |

Notes in `methodology/` are differentiated by their `kind:` frontmatter field:
- `kind: research` — WHY: principles and cognitive science grounding (213 claims)
- `kind: guidance` — HOW: operational procedures and best practices (9 docs)
- `kind: example` — WHAT IT LOOKS LIKE: domain compositions (12 examples)
- `type: moc` — Navigation: topic maps linking related notes (15 maps)

### Consultation Process Per Skill

For each skill being evaluated:

1. **Read the current vault skill** — understand its complete approach, quality gates, edge case handling

2. **Read relevant knowledge base documents:**
   - Research claims about this skill's domain (e.g., for /{vocabulary.reduce}: claims about extraction methodology)
   - Guidance docs about processing pipeline best practices
   - Reference docs about the skill's operational patterns

3. **Compare methodology, not text:**
   - Does the skill implement the quality gates the knowledge base recommends?
   - Does it handle edge cases the knowledge base identifies?
   - Does it use the discovery/search patterns the knowledge base recommends?
   - Has the knowledge base added new techniques since this skill was generated?

4. **Classify each finding:**

   | Classification | Meaning | Example |
   |---------------|---------|---------|
   | **Current** | Skill reflects knowledge base best practices | No action needed |
   | **Enhancement** | Knowledge base adds technique the skill lacks | New quality gate, better search pattern |
   | **Correction** | Knowledge base contradicts skill's approach | Outdated methodology, known anti-pattern |
   | **Extension** | Knowledge base covers scenario skill ignores | New edge case, new domain pattern |

5. **Check user modifications:**
   If the skill has been modified by the user, read both the current (user-modified) version and evaluate whether:
   - The user's changes already incorporate the improvement (skip it)
   - The user's changes are orthogonal to the improvement (can coexist)
   - The user's changes conflict with the improvement (flag for side-by-side review)

---

## Step 3: Generate Upgrade Plan

For each skill with available improvements, create a structured proposal:

```
Skill: /{domain:skill-name}
Status: {current | enhancement | correction | extension}
User-modified: {yes | no}

Current approach:
  {2-3 sentences describing what the skill currently does}

Proposed improvement:
  {2-3 sentences describing what would change}

Research backing:
  {Specific claims from the knowledge base that support this change}
  - "{claim title}" — {how it applies}
  - "{claim title}" — {how it applies}

Impact: {what changes for the user's workflow}
Risk: low | medium | high
Reversible: yes (previous version archived to ops/skills-archive/)
```

### Risk Assessment

| Risk Level | Criteria |
|-----------|----------|
| **Low** | Additive change (new quality gate, better logging). Existing behavior unchanged. |
| **Medium** | Modified behavior (different extraction strategy, changed search pattern). Output quality affected. |
| **High** | Structural change (different phase ordering, changed handoff format). Pipeline coordination affected. |

### Side-by-Side for User-Modified Skills

When a skill has been modified by the user AND an upgrade is available, show a side-by-side comparison:

```
Skill: /{domain:skill-name} (USER-MODIFIED)

Your version:                     Recommended:
  [relevant section excerpt]        [what knowledge base suggests]

Your customization:
  {description of what the user changed and why it appears intentional}

Options:
  (a) Keep your version unchanged
  (b) Apply upgrade, preserving your customizations
  (c) Apply upgrade, replacing your version (archived to ops/skills-archive/)
```

Option (b) requires the upgrade to be compatible with the user's changes. If they conflict, explain why and recommend (a) or (c).

---

## Step 4: Present Plan

```
--=={ upgrade }==--

Plugin: arscontexta-{current_version}
Knowledge base: {count} research claims, {count} guidance docs
Skills checked: {count}

Upgrades available: {count}
  Enhancements: {n}  |  Corrections: {n}  |  Extensions: {n}

  1. /{domain:skill-name}
     Type: Enhancement
     Change: {one-line summary}
     Research: "{claim title}"
     Risk: low

  2. /{domain:skill-name} (USER-MODIFIED)
     Type: Correction
     Change: {one-line summary}
     Research: "{claim title}", "{claim title}"
     Risk: medium
     Note: Side-by-side comparison available

  ...

{If no upgrades:}
  All {count} skills reflect current best practices.
  No upgrades needed.

Apply all? Select specific upgrades (e.g., "1, 3")?
Or "show 2" for side-by-side detail on a specific skill.
```

Wait for user response. Do NOT proceed without explicit approval.

**Approval gates Step 5 only.** Step 6's vault repairs run either way — including when the report
above was "no upgrades needed" and there is nothing to approve. Do not skip to the Final Report from
here.

---

## Step 5: Apply Approved Upgrades

For each approved upgrade:

### 5a. Archive Current Version

```bash
mkdir -p ops/skills-archive
SKILL_NAME="{skill-name}"
DATE=$(date +%Y-%m-%d)
cp ".claude/skills/${SKILL_NAME}/SKILL.md" \
   "ops/skills-archive/${SKILL_NAME}-${DATE}.md"
```

### 5b. Generate Updated Skill

1. Read the skill's generation block from the plugin (if available)
2. Apply the specific improvements identified in Step 2
3. Preserve the user's vocabulary transformation from `ops/derivation-manifest.md`
4. Preserve the user's dimensional positions from `ops/config.yaml`
5. For user-modified skills with option (b): merge the user's customizations into the updated skill

### 5c. Update Version Tracking

Update the skill's frontmatter:

```yaml
---
version: "{incremented}"
generated_from: "arscontexta-{current_plugin_version}"
---
```

### 5d. Update Generation Manifest

If `ops/generation-manifest.yaml` exists, update the entry for this skill:

```yaml
skills:
  {skill-name}:
    version: "{new_version}"
    upgraded: "{ISO 8601 UTC}"
    upgrade_source: "knowledge-graph-consultation"
    changes: "{brief description of what changed}"
```

---

## Step 6: Repair Vault Infrastructure

**This step runs on every invocation — including when no upgrades were available, and when the user
approved none.** The three repairs below are vault-level (one shared library, one lock directory, one
config section), not per-skill.

They were once written as subsections of Step 5's *"For each approved upgrade"* loop. That made them
unreachable in exactly the case that needs them most: the vault most likely to be missing `ops/lib/`
is an **old** vault, which is also the one most likely to have its user decline the skill upgrades.
It also ran each repair once per approved upgrade. The Final Report's `[current]` variants
(`queue lock dir: present [current]`) are the tell — a per-upgrade step has no reason to report
"nothing needed."

### 6a. Refresh the shared library

Generated vaults carry their own copy of the link-extraction library at `ops/lib/link-extraction.sh`.

**Scope, stated rather than implied: this step reconciles that one file, not the whole of
`ops/lib/`.** A vault's `ops/lib/` may also hold graph parsers and their tests. Those carry no version
marker to compare against, so this step cannot reconcile them and must not claim to. Report the file;
never report the directory as repaired.

**Do not assert which skills source this file.** In the one field vault measured, *no* skill
referenced `link-extraction.sh` at all: its `/graph` sources `ops/lib/graph.mjs` — which that skill
calls the only sanctioned parser, warning that a naive wikilink regex once produced 135 false
dangling links against a real count of 0 — and `/stats` sources neither. Restoring this file may
therefore leave a vault's link counting broken. Say what was restored; do not infer what now works.

**Do this as instructions you carry out, not as a bash block.** `${CLAUDE_PLUGIN_ROOT}` resolves for you; it is unset in a shell, so a shell copy would read from `/reference/lib/...` and silently do nothing.

1. Read `LINK_EXTRACTION_VERSION` from the plugin's `${CLAUDE_PLUGIN_ROOT}/reference/lib/link-extraction.sh`.
   **If that file is absent, halt this step and report it — do not treat it as version `0`.** A
   missing plugin-side library means the installed plugin predates the step reading it; there is
   nothing to refresh *from*, and the only safe action is to leave the vault's copy untouched. This
   is a live case, not a hypothetical: a plugin installed from a release older than this step has no
   `reference/lib/` at all, and treating that as `0` would copy a nonexistent file over a working
   library. Report `link-extraction.sh: plugin copy absent [skipped — plugin older than this step]`.
2. Read `LINK_EXTRACTION_VERSION` from the vault's `ops/lib/link-extraction.sh`. Treat a missing file or a missing assignment as version `0`.
3. **Compare numerically, and copy only when the plugin's version is strictly greater than the
   vault's.** Equal means current — do nothing. Vault *ahead* of plugin means the vault was refreshed
   by a newer plugin than the one now installed; leave it alone and report it. Copying on "the two
   versions differ" silently downgrades a working library and renders it as `[refreshed]`, which
   reads like progress. When the copy is warranted, create `ops/lib/` if absent and copy the plugin's
   file over the vault's, preserving the executable bit.
4. Confirm the copy landed: the vault file must now exist, be readable, and report the plugin's version. If it does not, report the failure — do not record the refresh as applied.

**Report the replacement; never overwrite silently.** Name both versions and the outcome in the Final
Report — every branch above has a line, including the ones where nothing was written:

```text
link-extraction.sh: v0 (absent) → v2 [restored]
link-extraction.sh: v1 → v2 [refreshed]
link-extraction.sh: v2 [current]
link-extraction.sh: v2 → v1 [vault ahead, skipped]
link-extraction.sh: plugin copy absent [skipped — plugin older than this step]
```

When the vault's `ops/lib/` held other files, add the scope line so the user is not left reading a
restored file as a restored directory: `other ops/lib/ files not checked`. A library swapped in
without a line in the report is a change the user cannot audit — and this file decides what every
link count in the vault reports.

### 6b. Restore the queue lock directory

`/{DOMAIN:reflect}` and `/{DOMAIN:reweave}` serialize their qmd calls with
`until mkdir "$LOCKDIR" 2>/dev/null; do … done`, bounded at 60 seconds. The `mkdir` deliberately
omits `-p`, because creating that directory atomically *is* the mutex — with `-p` it would return 0
while another run holds the lock. So the **parent** `ops/queue/.locks/` must already exist.

Vaults generated before this was part of setup do not have it, and the shape of that failure depends
on which templates their skills were generated from:

- **Skills carrying the old unbounded `while ! mkdir …; do sleep 2; done`.** The `mkdir` can never
  succeed, `2>/dev/null` swallows the reason, and the skill loops every 2 seconds forever, printing
  nothing. It does not fail — it hangs. This is the case this step exists for.
- **Skills carrying the current bounded loop.** It creates the parent itself with
  `mkdir -p "$(dirname "$LOCKDIR")"`, so a missing parent can no longer hang or abort. The repair
  below is then a no-op.

Perform the repair either way: it is idempotent, and this step cannot tell which generation of the
templates a given vault's skills came from.

1. Check whether `ops/queue/.locks/` exists.
2. If absent, create it (the directory only — leave it empty).
3. Never add `-p` to the lock `mkdir` itself in any generated skill; that silently removes the mutex.

Report the outcome: `queue lock dir: absent → created [restored]`, or `present [current]`.

### 6c. Seed the self-evolution thresholds

`/{DOMAIN:rethink}`, `/{DOMAIN:remember}` and `/{DOMAIN:next}` all read
`self_evolution.observation_threshold` and `self_evolution.tension_threshold` from `ops/config.yaml`,
and all document the same defaults. No generator ever wrote those keys, so in every vault built
before this step they are simply absent: each skill falls back to its built-in default, and a user
who wants to tune the loop has nothing to edit and no way to discover the setting exists.

**Check both names before writing anything.** A vault may already declare these thresholds under a
different key. The field vault does — `maintenance.conditions.pending_observations_threshold: 20` and
`pending_tensions_threshold: 10` — and it wrote that mismatch up itself on 2026-07-25, in
`ops/observations/drift-self-evolution-config-path-mismatch-in-rethink-skill.md`. Its `/rethink`
reads the `maintenance.conditions.*` pair; `/next` and `/remember` read `self_evolution.*`.

A check keyed only to `self_evolution:` cannot see that tuning. It seeds the **defaults** `10/5`
directly beneath a user's configured `20/10`, halving both, while reporting that it seeded a missing
section. That is not a hypothetical ordering — it is what this step does to the one real vault it has
been run against.

1. Check whether `ops/config.yaml` contains a `self_evolution:` section.
2. Check whether it declares the same thresholds under `maintenance.conditions:` as
   `pending_observations_threshold` / `pending_tensions_threshold`.
3. **If either is present, write nothing.**
   - `self_evolution:` present → `self_evolution: present [current]`.
   - Only `maintenance.conditions.*` present → report the conflict, naming **both keys and both
     values**, and stop: `self_evolution: absent, but maintenance.conditions declares 20/10 —
     not seeded [conflict]`. A report that says only "not seeded" replaces a silent overwrite with a
     silent skip, which is no better.
4. Only when **neither** is present, append the documented defaults, preserving the file's existing
   comment style:

   ```yaml
   self_evolution:
     observation_threshold: 10   # open observations before suggesting rethink
     tension_threshold: 5        # open tensions before suggesting rethink
   ```

   Report: `self_evolution: absent → seeded (10/5) [restored]`.

**The namespace question this leaves open.** The field vault's own recommendation was the opposite
repair: change the skills to read `maintenance.conditions.*` rather than invent a `self_evolution`
namespace that no generator ever wrote (Rule 12 — conform to the existing structure). That is a
design change across three skill templates, not an upgrade step, so it is not made here. This step
now refuses to make the split worse; it does not resolve it.

**Seeding this section now changes hook behavior too — it is no longer cosmetic.** This note used to
say the opposite, and was correct when written: the SessionStart hook carried hardcoded thresholds
and `read_config.sh` read only the top-level `.arscontexta` marker, so a nested `ops/config.yaml` key
was unreachable. Both halves of that changed. `read_config.sh` routes dotted keys to
`ops/config.yaml`, and `session-orient.sh` reads `self_evolution.observation_threshold` and
`self_evolution.tension_threshold` rather than hardcoding them.

So a seeded section is read by the hook as well as by `/{DOMAIN:rethink}`, `/{DOMAIN:remember}` and
`/{DOMAIN:next}`. That is a stronger reason to seed a genuinely missing section — and the reason
step 3 above must refuse to seed over a threshold declared under another name. Writing `10/5` here no
longer merely fails to help; it now actively overrides what the vault was tuned to.

One limit worth stating rather than discovering later: `read_config.sh` resolves **one** level of
nesting, which is all `self_evolution.*` needs. `maintenance.conditions.pending_observations_threshold`
is three levels, so the hook cannot read that pair whichever way this step is resolved.

---

## Step 7: Validate

After applying all approved upgrades:

1. **Kernel validation** — run kernel checks to confirm structural invariants hold:
   ```bash
   # Verify skill files are valid
   for dir in .claude/skills/*/; do
     [[ -f "$dir/SKILL.md" ]] || echo "MISSING: $dir/SKILL.md"
   done
   ```

2. **Context file check** — verify all skill references in the context file still resolve

3. **Vocabulary check** — confirm upgraded skills use domain vocabulary consistently:
   ```bash
   # Spot-check that vocabulary markers were resolved
   grep -l '{vocabulary\.' .claude/skills/*/SKILL.md 2>/dev/null
   # Should return nothing — all markers should be resolved
   ```

4. **Pipeline compatibility** — if pipeline skills were upgraded (/{vocabulary.reduce}, /{vocabulary.reflect}, /{vocabulary.reweave}, /{vocabulary.verify}), verify handoff format compatibility with /ralph

---

## Final Report

```
--=={ upgrade complete }==--

Applied: {N} upgrades
Archived: {N} previous versions to ops/skills-archive/
Skipped: {N} (user-modified, kept as-is)

Changes:
  - /{skill}: {what changed} (Research: "{claim}")
  - /{skill}: {what changed} (Research: "{claim}")

Vault infrastructure (Step 6 — runs regardless of approvals):
  - link-extraction.sh: v{vault} → v{plugin} [restored | refreshed | current
                                              | vault ahead, skipped
                                              | plugin copy absent, skipped]
    {when ops/lib/ held other files:} other ops/lib/ files not checked
  - queue lock dir: {absent → created [restored] | present [current]}
  - self_evolution: {absent → seeded (10/5) [restored] | present [current]
                     | absent, but maintenance.conditions declares {n}/{n} —
                       not seeded [conflict]}

Validation: {PASS | FAIL with details}

{If any validation failed:}
  WARNING: Validation issue detected.
  Previous versions available in ops/skills-archive/
  for manual rollback.

Note: Run /{vocabulary.verify} on a recent {vocabulary.note}
to confirm upgraded skills work correctly in practice.
```

---

## INVARIANT

**/upgrade never auto-implements.** The upgrade plan is always presented to the user first. The user decides which upgrades to apply. This prevents the cognitive outsourcing failure mode where the system changes itself without human understanding.

All upgrades are advisory. The user owns the files.

---

## Edge Cases

**No improvements available:** Report "All skills reflect current best practices. No upgrades needed." with the count of skills checked.

**No generation manifest:** Treat all skills as version 0 (unknown generation state). Compare methodology against current knowledge base. This is fine — consultation reasons about approach, not version numbers.

**Skill has been user-modified:** Present the side-by-side comparison. Offer three options: keep user version, merge upgrade with customizations, or replace (with archive). Never silently overwrite.

**No ops/derivation-manifest.md:** Use universal vocabulary for all output.

**Plugin knowledge base unavailable:** Report that knowledge base consultation requires the Ars Contexta plugin. Without the plugin's bundled methodology/ and reference/ directories, /upgrade cannot evaluate skills.

**User rejects upgrades consistently:** This is a signal, not an error. Note the pattern — it may indicate the knowledge base recommendations don't match this user's domain. Log to ops/observations/ if it persists across multiple /upgrade runs.

**Correction conflicts with user modification:** When the knowledge base identifies a correction (not just enhancement) but the user has modified the skill, explain the conflict clearly. The user may have modified the skill precisely because the original approach was wrong — their fix may already address the correction. Show both and let the user decide.

**Multiple skills share a change:** If the same knowledge base improvement applies to several skills (e.g., a new search pattern), present it as a single conceptual change affecting multiple skills rather than listing it redundantly per skill.
