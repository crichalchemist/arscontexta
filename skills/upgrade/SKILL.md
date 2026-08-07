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

## Shared Step: Resolving a Vault Skill to Its Canonical Template

Step 1 and Step 5 both need to know, for a skill installed in this vault, which
`skill-sources/<canonical-name>/SKILL.md` in the plugin it came from.

**Only 6 of the 16 canonical skills are ever vocabulary-transformable.**
`skills/setup/SKILL.md`'s own manifest template (its "Level 5: Process verbs"
section) declares exactly `reduce`, `reflect`, `reweave`, `verify`, `validate`,
`rethink` as renameable — every other canonical name (`graph`, `next`,
`pipeline`, `ralph`, `refactor`, `remember`, `seed`, `stats`, `tasks`, `learn`)
keeps its canonical name as the vault's directory name in *every* generated
vault, unconditionally, by generator design — not by omission. A first version
of this step assumed all 16 were vocabulary-derived and halted on 11 of them
when tested against a real vault, even though all 11 have a `skill-sources/`
counterpart — a false halt on the common case, not the rare one. Fixed by
scoping the reverse lookup to exactly the 6 transformable keys and falling
back to identity for everything else, rather than guessing at directory
existence on the plugin side (which this file's own Step 6a note says a shell
fence cannot check — `${CLAUDE_PLUGIN_ROOT}` is unset in a shell; it resolves
for the agent, not for a subprocess).

```bash
# Given a vault-local skill directory name, resolve the canonical
# skill-sources/ name it was generated from. Needs only this vault's own
# ops/derivation-manifest.md -- no plugin-side path is read here, so this
# never depends on ${CLAUDE_PLUGIN_ROOT} resolving in a shell.
resolve_canonical_name() {
  local derived="$1" manifest="ops/derivation-manifest.md"
  [[ -f "$manifest" ]] || { echo "HALT: no $manifest — cannot resolve '$derived' to a canonical name" >&2; return 1; }
  # Scoped to the "Level 5: Process verbs" section only -- the sole part of
  # the vocabulary: block whose keys are skill names. Scoping any wider (the
  # whole block) risks matching a folder- or field-level derived value that
  # happens to coincide with a skill's domain term; scoping narrower would
  # miss a real rename. The two comment markers are the generator's own
  # section boundaries (skills/setup/SKILL.md), not this vault's wording, so
  # this holds across every generated vault, not just this one.
  grep -q '# Level 5: Process verbs' "$manifest" || { echo "HALT: $manifest has no 'Level 5: Process verbs' section — cannot verify '$derived' is not a renamed skill, and falling back to identity here would be a silent guess" >&2; return 1; }
  local level5 key value line canonical=""
  level5=$(sed -n '/# Level 5: Process verbs/,/# Level 6:/{/^  [a-z_]*: /p;}' "$manifest")
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    key=$(printf '%s' "$line" | sed 's/^  \([a-z_]*\): .*/\1/')
    value=$(printf '%s' "$line" | sed 's/^  [a-z_]*: "\(.*\)"$/\1/')
    # First match wins; the six process-verb domain terms are meant to be
    # distinct per vault, so this is not expected to matter in practice.
    [ "$value" = "$derived" ] && { canonical="$key"; break; }
  done <<EOF_LEVEL5
$level5
EOF_LEVEL5
  # No match means $derived was never one of the six renameable terms, so it
  # already IS the canonical name -- not a failure, the common case.
  printf '%s\n' "${canonical:-$derived}"
}
```

**This resolver never halts on a valid derived name — only on a missing
manifest**, since every non-renamed skill legitimately resolves to itself.
Whether the *resulting* canonical name actually has a `skill-sources/`
template is a separate question this function does not answer: that check
belongs to whichever step reads the plugin side (Step 5's render step, next),
which already needs agent-carried plugin-root resolution for other reasons.

**Placement decision, stated rather than implied:** this lives inline here,
not as a third file in `reference/lib/` alongside `frontmatter.sh` and
`link-extraction.sh`, and the decision covers only this deterministic lookup
— the render/substitution half (next) may end up living elsewhere. Nothing
calls this yet, and a new shared library means a version constant, a Step 6a
row, and a `skills/setup` copy-step change for a function with exactly one
caller today. Revisit only if a second caller appears.

---

## Shared Step: Rendering the Canonical Template in This Vault's Vocabulary

Together with `resolve_canonical_name` above, this is `render_current_template`
— what Step 5b calls to reproduce what the plugin's *current*
`skill-sources/` template would look like, in *this vault's* vocabulary, as
the candidate replacement text. Step 1's modification test does **not** call
this — see "Shared Step: Mechanically Comparing..." below for why an LLM
render can't back that check, and what replaces it.

Given a canonical name from `resolve_canonical_name`:

1. **Read `${CLAUDE_PLUGIN_ROOT}/skill-sources/<canonical>/SKILL.md`.** If it
   doesn't exist — the installed plugin predates this skill, or the name
   resolved above doesn't correspond to a real template — **halt evaluation of
   this one skill and report it, mirroring Step 6a's row-scoped tag style**
   (`halt this row and report it`, not a whole-run abort):
   `<canonical>: no skill-sources/ template [skipped — plugin absent or
   predates this skill]`. Move on to the next skill; never fall through to
   treating the vault's installed copy as current for *this* skill when the
   comparison can't actually be made — that is exactly the failure this plan
   exists to close.

2. **Apply vocabulary transformation the way `/setup` already does it — do
   not restate or re-derive the rule here.** `skills/setup/SKILL.md:637`
   describes this as "LLM-based contextual replacement, NOT string
   find-replace" — a judgment call you make as you read the template, not a
   substitution script. Its Structural Marker Protection rule
   (`skills/setup/SKILL.md:702`) binds here too: YAML field names
   (`description:`, `topics:`, `relevant_notes:`, `type:`, `status:`,
   `_schema:`, and so on) stay universal; only values, prose, and
   user-facing labels transform. Use this vault's own
   `ops/derivation-manifest.md` `vocabulary:` block as the mapping — the
   same one `resolve_canonical_name` reads.

3. **The result is Step 5b's candidate replacement text** — the vault's
   post-upgrade version of this skill, once the human approves swapping it
   in. It is **not** used to decide `MODIFIED`; see the mechanical-comparison
   step below for that.

---

## Shared Step: Mechanically Comparing a Vault Skill Against Its Canonical Template

Step 1's modification check needs this, not `render_current_template` above.
Measured on two canonical templates (~310 and ~740 lines, one with real
`{vocabulary.*}` substitution activity): two independent LLM renders of the
*identical* source diverge from each other — every diverging hunk was a
missed or inconsistent vocabulary-term substitution, never open rephrasing.
A diff between one such render and the installed file can't tell "the user
edited this" from "this render's judgment call landed differently than
whatever render produced the installed copy" — so `render_current_template`
cannot back a MODIFIED verdict. This step is a separate, fully mechanical,
deterministic substitution instead — no LLM judgment anywhere in it.

Given a canonical name from `resolve_canonical_name` above:

1. **Confirm both files exist:** `${CLAUDE_PLUGIN_ROOT}/skill-sources/<canonical>/SKILL.md`
   and the installed `.claude/skills/<skill>/SKILL.md`. Same halt contract
   as `render_current_template`'s step 1 on a missing template — halt
   evaluation of this one skill, report it, move on. The function below
   takes both as *file paths*, not pre-read content — it reads them itself.

2. **Unwrap the placeholder syntax on the canonical side, then fold, then
   substitute.** `{vocabulary.X}` and the older `{DOMAIN:X}` spelling
   (`reference/skill-authoring.md:45` documents the latter as still live)
   are unified and stripped to the bare key `X` first — folding alone turns
   the wrapper into extra `vocabulary`/`domain` tokens with no counterpart
   on the installed side, which is already plain prose (measured: this
   alone made an unmodified template diff non-empty against itself). *Then*
   fold to lowercase and replace every character that is not alphanumeric,
   `_`, or whitespace with a space. Then replace every token that exactly
   matches one of this vault's `vocabulary:` block keys (Levels 1-6 — Level
   7 is a nested list, not a substitution pair) with that key's value —
   itself folded and trimmed the same way, so a value like
   `cmd_reduce: "/extract"` matches what the installed side's own folding
   already produced for it — plus one further pair sourced from
   `reference/vocabulary-transforms.md`'s own "MOC" row — the documented
   universal name for what the manifest calls `topic_map`/`topic_maps` —
   mapped to this vault's value for those keys.

3. **Fold the installed file the same way — case, punctuation, and
   whitespace normalization only, never substitution.** The installed file
   is already in vault vocabulary; running the same table on it risks a
   real collision, not a hypothetical one: this vault's own `hub: "index"`
   key re-matches the bare word "hub" inside `topic_map`'s *already-correct*
   value "graph hub", corrupting it (measured). Substitute only the
   canonical side, ever — that asymmetry is the fix, not an oversight. Both
   sides get the identical whitespace-normalizing rebuild regardless of
   whether a substitution fired on a given line — otherwise a substituted
   line and an untouched line normalize differently for no reason connected
   to real content (measured: this too made an unmodified template diff
   non-empty against itself).

4. **Diff the two.** A non-zero exit from any guard in step 1 (or from the
   substitution-table build below) means the comparison could not be made
   for this skill — halt evaluation of this one skill and report it, per
   the tag convention above; never treat that as `MODIFIED`, since an empty
   diff and "the comparison never ran" must not read the same way.
   Otherwise: non-empty diff → `MODIFIED: $skill`.

```bash
# Steps 2-4 above, portable bash/zsh. Takes both files as PATHS -- it reads
# them itself; the caller does not need to pre-read either one.
mechanically_compare() {
  local manifest="ops/derivation-manifest.md" canon_file="$1" installed_file="$2"
  [[ -f "$manifest" ]] || { echo "HALT: no $manifest -- cannot build the substitution table" >&2; return 1; }
  [[ -f "$canon_file" ]] || { echo "HALT: $canon_file does not exist" >&2; return 1; }
  [[ -f "$installed_file" ]] || { echo "HALT: $installed_file does not exist" >&2; return 1; }

  local block line key value topic_map_val="" topic_maps_val="" pairs_file
  pairs_file=$(mktemp)
  # Presence-check the CLOSING marker before extracting -- an unclosed
  # range (vocabulary: present, # Level 7: absent) runs to EOF and silently
  # absorbs every later key: "value" line into the table (wrong answers,
  # not just a missing block), so the emptiness check below can't catch
  # it: that block would be non-empty, just contaminated. Mirrors
  # resolve_canonical_name's own closing-marker guard above. (No separate
  # opening-marker check is needed: if "vocabulary:" itself is absent the
  # sed range below never opens and $block is empty, which the check
  # after this loop already catches.)
  grep -q '# Level 7:' "$manifest" || { echo "HALT: $manifest has no '# Level 7:' marker -- cannot bound the vocabulary: block's extraction, and running it to EOF would silently absorb unrelated content" >&2; rm -f "$pairs_file"; return 1; }
  block=$(sed -n '/^vocabulary:/,/# Level 7:/p' "$manifest")
  if [ -z "$block" ]; then
    echo "HALT: $manifest has no 'vocabulary:' block -- cannot build the substitution table" >&2
    rm -f "$pairs_file"; return 1
  fi
  while IFS= read -r line; do
    case "$line" in *': "'*'"'*) : ;; *) continue ;; esac
    key=$(printf '%s\n' "$line" | sed -n 's/^  \([a-zA-Z_]*\): .*/\1/p')
    value=$(printf '%s\n' "$line" | sed -n 's/^  [a-zA-Z_]*: "\(.*\)"$/\1/p')
    [ -n "$key" ] && [ -n "$value" ] || continue
    # Fold the value the same way the text is folded -- a leading-slash
    # command name like "/extract" must match what the installed side's
    # own folding already produced for it, not the raw slash-prefixed form.
    value=$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]_[:space:]' ' ' | awk '{$1=$1}1')
    printf '%s\t%s\n' "$key" "$value" >> "$pairs_file"
    [ "$key" = "topic_map" ] && topic_map_val="$value"
    [ "$key" = "topic_maps" ] && topic_maps_val="$value"
  done <<EOF_VOCAB
$block
EOF_VOCAB
  [ -n "$topic_map_val" ]  && printf 'MOC\t%s\n' "$topic_map_val" >> "$pairs_file"
  [ -n "$topic_maps_val" ] && printf 'MOCs\t%s\n' "$topic_maps_val" >> "$pairs_file"
  if [ ! -s "$pairs_file" ]; then
    echo "HALT: $manifest's vocabulary: block yielded no usable key/value pairs -- cannot build the substitution table" >&2
    rm -f "$pairs_file"; return 1
  fi

  # Canonical side: unify placeholder spellings and strip the wrapper down
  # to the bare key, fold+strip, then substitute -- the only side that
  # ever gets substituted (see step 3 above).
  local canon_text canon_folded canon_out
  canon_text=$(sed -e 's/{DOMAIN:topic maps}/{vocabulary.topic_maps}/g' \
                    -e 's/{DOMAIN:topic map}/{vocabulary.topic_map}/g' \
                    -e 's/{DOMAIN:\([a-zA-Z_]*\)}/{vocabulary.\1}/g' \
                    -e 's/{vocabulary\.\([a-zA-Z_]*\)}/\1/g' "$canon_file")
  canon_folded=$(printf '%s' "$canon_text" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]_[:space:]' ' ')
  canon_out=$(printf '%s\n' "$canon_folded" | awk -v pf="$pairs_file" '
    BEGIN { while ((getline line < pf) > 0) { n = split(line, f, "\t"); if (n == 2 && f[1] != "") map[tolower(f[1])] = f[2] }; close(pf) }
    { for (i = 1; i <= NF; i++) if ($i in map) $i = map[$i]; $1 = $1; print }
  ')
  rm -f "$pairs_file"

  # Installed side: same fold and the same forced whitespace rebuild, never
  # the substitution table (see step 3 above). The rebuild is what keeps
  # whitespace normalization identical to the canonical side's on every
  # line, substituted or not -- it adds no substitution of its own.
  local installed_folded
  installed_folded=$(tr '[:upper:]' '[:lower:]' < "$installed_file" | tr -c '[:alnum:]_[:space:]' ' ' | awk '{$1=$1}1')

  diff <(printf '%s\n' "$canon_out") <(printf '%s\n' "$installed_folded")
}
```

**What this catches and what it doesn't — stated, not silent.** Covers the
`{vocabulary.X}`/`{DOMAIN:X}` placeholder forms, the literal Levels-1-6 key
names as bare words, and the one sourced MOC alias. It does NOT cover any
other synonym outside that closed set: `{vocabulary.topic_map_plural}` — a
spelling that does not literally match the manifest's declared key
(`topic_maps`) — appears 24 times across 5 `skill-sources/` files (measured)
and will not substitute, reading as false-positive divergence; a
pre-existing naming mismatch this step does not fix. Nor does it cover
`{DOMAIN:extraction_categories}` (a Level 7 nested list, never a
substitution pair by design) — any template using it always shows that
token as unsubstituted. Case-folding is exercised only against BSD `tr`
(this repo's default); GNU `tr`'s handling of non-ASCII uppercase is
untested and could fold differently across environments. And even a
perfect substitution can't separate "the user edited this" from "the
plugin's canonical template changed since generation" — there are no git
tags to isolate an original baseline (Global Constraint). The honest
predicate this produces is **diverges from the current canonical template**,
not strictly *user-modified* — both conflate into the same non-empty diff,
and Step 1's presentation says so rather than implying otherwise.

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

5. **Check for user modifications — as instructions you carry out, not one
   isolated fence.** For each installed skill directory (`.claude/skills/*/`):
   a. Run `resolve_canonical_name` (shared step above) on the directory
      name — a fresh, standalone invocation each time; a fence earlier in
      this file does not persist into this one.
   b. Run `mechanically_compare` (shared step above) — another standalone
      invocation — with `${CLAUDE_PLUGIN_ROOT}/skill-sources/<canonical>/SKILL.md`
      and the installed file's path. It reads both itself; do not pre-read
      the canonical template for this check (Step 5b's render step, which
      does need pre-read content, is separate).
   c. Non-zero exit (any file it needs is missing, or the manifest's
      vocabulary block is missing or unusable) → halt evaluation of this
      one skill and report it, same tag convention as the two shared steps
      above — never treat that as `MODIFIED`. Otherwise: non-empty diff →
      `MODIFIED: $skill`.

Present inventory:

```
--=={ upgrade : inventory }==--

System: {domain description}
Engine: arscontexta-{version}
Skills: {count} installed ({modified_count} diverge from the current template)

  Skill               Version  Generated From    Modified
  /{vocabulary.reduce}    1.0  arscontexta-v1.6  no
  /{vocabulary.reflect}   1.0  arscontexta-v1.6  yes
  ...

Note: "Modified" means diverges from the current canonical template, not
strictly "the user edited this" -- a template that changed upstream since
generation reads the same way, and there is no way to separate the two
without git tag history (there is none). See the mechanical-comparison
step above for what the substitution table covers and what it doesn't.
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
  (c) Apply upgrade, replacing your version (archived to ops/skills-archive/)
```

**Option (b), a merge preserving customizations, is not offered — not as a corner case, but as
the real behavior every invocation of `/upgrade` gets today: there is no OLD-rendering
available.** A merge needs the *original* canonical template this skill was generated from, and
this repo carries no release tags to recover it. Without that baseline a merge is a guess, not a
fact — exactly the render-noise problem the mechanical-comparison step above was built to avoid,
not something to reintroduce here by another route. State this plainly to the human rather than
presenting a third option that would fail silently or produce a guessed merge.

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

1. Resolve the canonical name (`resolve_canonical_name`, shared step above) and render it in
   this vault's vocabulary (`render_current_template`, shared step above) — no "if available"
   fallback: the halt contract shared by both closes the silent skip a looser phrasing here used
   to license. A missing manifest section, canonical template, or vocabulary block halts naming
   the exact skill and lookup that failed.
2. Apply the specific improvements identified in Step 2
3. Preserve the user's vocabulary transformation from `ops/derivation-manifest.md`
4. Preserve the user's dimensional positions from `ops/config.yaml`

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

### 6a. Refresh the shared libraries

Generated vaults carry their own copies of **two** versioned libraries under `ops/lib/`:

| Vault file | Plugin source | Version constant |
|---|---|---|
| `ops/lib/link-extraction.sh` | `${CLAUDE_PLUGIN_ROOT}/reference/lib/link-extraction.sh` | `LINK_EXTRACTION_VERSION` |
| `ops/lib/frontmatter.sh` | `${CLAUDE_PLUGIN_ROOT}/reference/lib/frontmatter.sh` | `FRONTMATTER_VERSION` |

**Scope, stated rather than implied: this step reconciles those two files, not the whole of
`ops/lib/`.** A vault's `ops/lib/` may also hold graph parsers and their tests. Those carry no version
marker to compare against, so this step cannot reconcile them and must not claim to. Report the files;
never report the directory as repaired.

**Run the procedure below once per row, independently.** One row halting or skipping says nothing
about the other, and a single combined line in the report would hide which file was actually written.

**Do not assert which skills source these files.** In the one field vault measured, *no* skill
referenced `link-extraction.sh` at all: its `/graph` sources `ops/lib/graph.mjs` — which that skill
calls the only sanctioned parser, warning that a naive wikilink regex once produced 135 false
dangling links against a real count of 0 — and `/stats` sources neither. Restoring a file may
therefore leave a vault's counting broken. Say what was restored; do not infer what now works.

**Do this as instructions you carry out, not as a bash block.** `${CLAUDE_PLUGIN_ROOT}` resolves for you; it is unset in a shell, so a shell copy would read from `/reference/lib/...` and silently do nothing.

1. Read the row's version constant from the row's **plugin** source.
   **If that file is absent, halt this row and report it — do not treat it as version `0`.** A
   missing plugin-side library means the installed plugin predates the step reading it; there is
   nothing to refresh *from*, and the only safe action is to leave the vault's copy untouched. This
   is a live case, not a hypothetical: a plugin installed from a release older than this step has no
   `reference/lib/` at all, and treating that as `0` would copy a nonexistent file over a working
   library. Report `<file>: plugin copy absent [skipped — plugin older than this step]`.
2. Read the same constant from the row's **vault** file. Treat a missing file or a missing assignment as version `0`.
3. **Compare numerically, and copy only when the plugin's version is strictly greater than the
   vault's.** Equal means current — do nothing. Vault *ahead* of plugin means the vault was refreshed
   by a newer plugin than the one now installed; leave it alone and report it. Copying on "the two
   versions differ" silently downgrades a working library and renders it as `[refreshed]`, which
   reads like progress. When the copy is warranted, create `ops/lib/` if absent and copy the plugin's
   file over the vault's, preserving the executable bit.
4. Confirm the copy landed: the vault file must now exist, be readable, and report the plugin's version. If it does not, report the failure — do not record the refresh as applied.

**Report each replacement; never overwrite silently.** Name both versions and the outcome in the Final
Report, **one line per row** — every branch above has a line, including the ones where nothing was
written:

```text
link-extraction.sh: v0 (absent) → v2 [restored]
link-extraction.sh: v1 → v2 [refreshed]
link-extraction.sh: v2 [current]
link-extraction.sh: v2 → v1 [vault ahead, skipped]
link-extraction.sh: plugin copy absent [skipped — plugin older than this step]
frontmatter.sh:     v0 (absent) → v3 [restored]
frontmatter.sh:     v1 → v3 [refreshed]
frontmatter.sh:     v3 [current]
```

`frontmatter.sh` is absent from **every vault generated before it existed**, so `v0 (absent) → v3
[restored]` is the expected line on an older vault, not an anomaly. A vault that has the file but at
v1 or v2 gets `[refreshed]`: v2 added the directory-readability guard and v3 symlink traversal plus a
check on `find`'s own exit status, so a v1 copy reports counts over trees it cannot fully scan. These
examples track the constant — do not read them as pinned versions. Until that copy lands, `/next`,
`/rethink` and `/stats` exit 1 naming this step as the repair — which is why this step must actually
perform it. A remedy message pointing at a step that does not restore the file would be the silent
failure this repo is named for, wearing a helpful voice.

When the vault's `ops/lib/` held files other than the two rows above, add the scope line so the user
is not left reading restored files as a restored directory: `other ops/lib/ files not checked`. A
library swapped in without a line in the report is a change the user cannot audit — and these files
decide what every link count and every status count in the vault reports.

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

### 6c. Reconcile the self-evolution thresholds

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
3. **Which "present" it is decides what happens. Never write a default over a configured value.**
   There are four cases, not two. The both-present case is the one that actually occurs.
   - **Neither present** → seed (step 4).
   - **Only `self_evolution:`** → `self_evolution: present [current]`.
   - **Only `maintenance.conditions.*`** → the vault is tuned, but three of its four consumers
     cannot see the tuning. **Propose carrying it across** (step 5). There is no competing
     `self_evolution` value to weigh it against, so the copy is unambiguous and requires no guess:
     `self_evolution: absent, maintenance.conditions declares 20/10 → carry across [reconcile]`.
   - **Both present** → **compare the values.** Equal is fine: `self_evolution: present, agrees with
     maintenance.conditions (20/10) [current]`. **Unequal is a live split and must be reported**:

     ```text
     self_evolution: 10/5 but maintenance.conditions declares 20/10 — surfaces disagree [split]
       /{DOMAIN:rethink} reads maintenance.conditions -> 20/10
       /{DOMAIN:next}, /{DOMAIN:remember}, SessionStart hook read self_evolution -> 10/5
     ```

     **Do not pick the winner yourself.** Both are things the user may have set deliberately, and
     nothing on disk distinguishes a tuned `10/5` from the `10/5` that step 4 seeds — which is
     precisely why "the value equal to the default must be the stale one" is not a safe inference.
     Ask with AskUserQuestion which pair the system should use, then write that pair via step 5.

   **This case is not hypothetical, and reporting `present [current]` for it is the defect this step
   was rewritten to stop.** The field vault carries exactly this state — `maintenance.conditions`
   at 20/10 (lines 68-69 of its `ops/config.yaml`) and `self_evolution` at 10/5 thirteen lines below
   (71-73), the latter byte-identical to the block step 4 seeds. At 14 open observations and 8 open
   tensions it means `/rethink` reports the threshold unmet while `/next` and `/remember` recommend
   running it. A check that tests only for the *presence* of `self_evolution:` sees a healthy vault
   there.
4. Only when **neither** is present, append the documented defaults, preserving the file's existing
   comment style:

   ```yaml
   self_evolution:
     observation_threshold: 10   # open observations before suggesting rethink
     tension_threshold: 5        # open tensions before suggesting rethink
   ```

   Report: `self_evolution: absent → seeded (10/5) [restored]`.
5. **Carrying a value across copies it; it does not move it.** On approval, write the chosen pair
   into `self_evolution:` and leave `maintenance.conditions.*` exactly as it is:

   ```yaml
   self_evolution:
     observation_threshold: 20   # carried across from maintenance.conditions.pending_observations_threshold
     tension_threshold: 10       # carried across from maintenance.conditions.pending_tensions_threshold
   ```

   Report: `self_evolution: 20/10 carried across from maintenance.conditions [reconciled]`.

   **Leaving the old pair in place is the point, not laziness.** A vault in this state has a
   `/{DOMAIN:rethink}` generated before the namespace was settled, and that skill file reads
   `maintenance.conditions.*`. Deleting the old keys would drop it back to its built-in default and
   re-open the split from the other side. With both pairs declared at the same values, the stale
   `/{DOMAIN:rethink}` and the four `self_evolution.*` readers agree — and keep agreeing whether or
   not that skill is ever regenerated.

   **The residual, stated here rather than discovered later:** two declarations of the same two
   thresholds now exist in one file. They agree when written and nothing keeps them agreeing; a user
   who later edits one re-opens the split. This is reconciliation, not deduplication. Deduplicating
   means deleting the old pair, which breaks the stale `/{DOMAIN:rethink}` above. The split is fully
   closed for a vault only once its `/{DOMAIN:rethink}` has been regenerated from the current
   template — after which `maintenance.conditions.pending_*_threshold` has no reader left and can be
   removed by hand.

**The namespace question, settled: `self_evolution.*` is authoritative.** The field vault's own
write-up recommended the opposite repair — change the skills to read `maintenance.conditions.*`
rather than invent a namespace no generator ever wrote (Rule 12 — conform to the existing
structure). That was sound advice *to a vault*. This is the generator, and three measurements taken
against it point the other way:

- `read_config.sh` resolves **one** level of nesting.
  `maintenance.conditions.pending_observations_threshold` is three, so the SessionStart hook
  structurally cannot read it. Deepening the reader means a general YAML parser in bash, which
  `read_config.sh` rejects in its own header comment as "how you get a second class of silent wrong
  answers."
- No generator here has ever emitted `maintenance.conditions.pending_*_threshold`
  (`grep -rn 'maintenance\.conditions\.' generators/ skills/setup/` → 0 hits). Conforming to it
  would mean conforming to a structure this product does not produce.
- It is not a live namespace being iterated. In the field vault the other seven keys under
  `maintenance.conditions:` have **zero** readers
  (`grep -rl <key> ~/second-brain/.claude ~/second-brain/.agents` → 0 files each), and the
  `maintenance_conditions` that `/{DOMAIN:next}` iterates is a section of the **queue** file, not of
  `ops/config.yaml` — a similarly-named different structure in a different file.

**The cost of choosing it, paid rather than denied:** a vault that tuned `maintenance.conditions.*`
gets nothing from the choice until something carries the value across. That is what step 5 is for,
and why this step now ends in a write instead of a report.

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
  - frontmatter.sh:     v{vault} → v{plugin} [restored | refreshed | current
                                              | vault ahead, skipped
                                              | plugin copy absent, skipped]
    {when ops/lib/ held files other than those two:} other ops/lib/ files not checked
  - queue lock dir: {absent → created [restored] | present [current]}
  - self_evolution: {absent → seeded (10/5) [restored] | present [current]
                     | present, agrees with maintenance.conditions ({n}/{n}) [current]
                     | {n}/{n} carried across from maintenance.conditions [reconciled]}

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
