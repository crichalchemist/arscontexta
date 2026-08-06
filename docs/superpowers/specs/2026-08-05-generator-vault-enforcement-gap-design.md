# Spec H — the generator/vault enforcement gap

**Predecessor:** `2026-08-04-ci-hardening-design.md` (Spec G, merged). This spec collects the items
Spec G deferred *pending in-flight fixes*, now that those fixes have landed, plus one structural
finding that Spec G could not have seen because it only looked at this repo.

**Trigger:** `~/second-brain/ops/rethink/2026-08-04-observation-triage.md`, a `/rethink` pass over
13 open observations and 7 open tensions. Three of its findings are generator defects, not vault
content. Investigating them exposed the structural gap this spec is named for.

---

## What this is

Every gate this repo has built reads **this repo**. `check-doc-claims.sh` reads our documents.
`check-placeholder-count.sh` reads our templates. `check-portability.sh` reads our shell.

The defects the field vault keeps finding are of a different kind: **a prose contract the generator
emits into a vault, which nothing reads back.** Not "we forgot to write the rule" — the rule ships.
`skill-sources/rethink/SKILL.md:269,321` instructs setting `status: implemented` together with
`implemented_in:`. Six observations in the field vault are `implemented` with no `implemented_in:`,
and nothing noticed.

That is the same class as `grep -P` rendering as 0, as primitive 10 asserting PATH presence, as the
manual placeholder command that matched two families of three. The generalization worth writing
down once:

> **An instruction the generator emits into a vault is unenforced unless something reads it back.**
> Shipping the instruction is not shipping the check.

---

## The finding Spec G could not have seen

A generated vault has **three tiers** of validation, and they do not connect.

| tier | example in the field vault | reachable from this repo? |
|---|---|---|
| generated, thin | `.claude/hooks/validate-note.sh` — 42 lines; checks `description`, `topics` | **only in a NEW vault**; no re-sync mechanism exists |
| hand-written, enforced | `.claude/hooks/validate-node-schema.py` — 299 lines, wired PostToolUse, **blocks commits** | **never — it has no generator counterpart at all** |
| prompt-based, soft | `/validate` reading `_schema` | ships, but fires only on invocation and only if the agent complies |

The consequence is the thing to internalise before scoping any work here: **a rule added to this
repo today reaches new vaults only, and cannot reach an existing vault's real gate by any path.**
"Fix it in the generator" fixes it *forward*. Saying so is not pessimism; it is the difference
between a spec that closes a class and one that believes it did.

### Two corollaries, both measured

**`_schema` is an over-claim in our own generator.** `generators/features/schema.md:142` calls the
`_schema` block "the single source of truth for field validation." In the field vault, the gate that
actually blocks commits ignores it entirely and hardcodes its own `VALID_TYPES`; one WARN-only
linter (`ops/scripts/format-lint.sh`) is the sole deterministic reader. The claim is documentation
about an authority nothing enforces — the exact shape this repo spends its divergence list on,
sitting in the generator's self-description.

**No conditional-field rule exists anywhere,** in this repo or the vault. `implemented ⇒
implemented_in:` would be the first of its kind. What exists is a *write-time instruction to an
agent* ("when you set X, also set Y"), never a post-hoc assertion ("if X, verify Y"). Those fail
differently: the instruction fails silently and per-invocation.

---

## The inventory

Measured 2026-08-05. Every row re-derived; do not quote without re-running the command beside it.

### 1. The observation and tension enums do not describe reality

```bash
for d in observations tensions; do
  printf '%s:' "$d"
  for v in open pending implemented archived resolved dissolved; do
    n=$(/usr/bin/grep -rl "^status: $v\$" ~/second-brain/ops/$d/ 2>/dev/null | wc -l | tr -d ' ')
    [ "$n" != "0" ] && printf ' %s=%s' "$v" "$n"
  done; echo
done
```

| field | generator declares | field vault uses |
|---|---|---|
| observations | `status: pending` (`generators/features/self-evolution.md:88`) | `implemented` 26, `open` 12, `archived` 3, **`pending` 0** |
| tensions | `pending \| resolved \| dissolved` (`:195`) | `open` 7, `resolved` 6, `archived` 6, **`pending` 0**, **`dissolved` 0** |

> **CORRECTION, re-derived 2026-08-05 at execution.** The table above is left as written because it
> is the record of what this spec believed; this note is what measurement found.
>
> **The tension row omits `promoted` 8 — a third of that directory — and the omission is not drift.**
> The probe beside this table is `for v in open pending implemented archived resolved dissolved`, a
> CLOSED CANDIDATE LIST reported as a survey. It could only find values already thought of, so a
> value the repo's own `/rethink` template WRITES was invisible. Acting on the table cost Task 1 a
> Critical: the first commit "describing what vaults write" left 14 of 27 tension files carrying an
> undeclared status. **A closed enumeration cannot survey.** The survey form:
>
> ```bash
> . reference/lib/frontmatter.sh
> for d in observations tensions; do
>   find ~/second-brain/ops/$d -type f -name '*.md' \
>     | while IFS= read -r f; do frontmatter_field "$f" status; done | sort | uniq -c | sort -rn
> done
> ```
>
> Measured 2026-08-05 — observations: `implemented` 26, `open` **13**, `archived` 3.
> Tensions: **`promoted` 8**, `open` 7, `resolved` 6, `archived` 6. `pending` and `dissolved` are 0
> in both, as stated. `open` moved 12 → 13 in a day, which is ordinary vault drift; `promoted` was
> never measured at all.
>
> §2's figures re-derived unchanged: **6 of 26**, and **0** real script references outside
> `node_modules`.

**`implemented` has 26 live uses and is declared in no generator enum at all.** `open` has 19 across
the two fields and is declared in neither of these two (it was added to the *note* enum by Spec F).

This is the same defect Spec F closed for notes, left open for these two. The closed record for
divergences 7/8/9 states the reason it is easy to miss: `ops/tensions/` and observations are
**different fields sharing a name**, so a fix to one reads as a fix to all three.

**Do not merge them.** The triage additionally wants a `blocked` state for tensions awaiting
external work — that belongs to the *tension* enum only. Merging it into the note enum would
collapse a separation this repo made deliberately.

### 2. C1: Conditional-field assertions are enforced by nothing

Two outcome statuses carry a target field — `implemented ⇒ implemented_in:` for observations,
`promoted ⇒ promoted_to:` for tensions — and neither is enforced.

```bash
. reference/lib/frontmatter.sh
total=$(list_notes_by_field ~/second-brain/ops/observations status implemented | wc -l | tr -d ' ')
missing=$(count_notes_missing_field ~/second-brain/ops/observations implemented_in | tr -d ' ')
echo "$missing of $total"
```

**6 of 26** implemented observations lack `implemented_in:`. Measured separately:

```bash
. reference/lib/frontmatter.sh
total=$(list_notes_by_field ~/second-brain/ops/tensions status promoted | wc -l | tr -d ' ')
missing=$(count_notes_missing_field ~/second-brain/ops/tensions promoted_to | tr -d ' ')
echo "$missing of $total"
```

**7 of 8** promoted tensions lack `promoted_to:`. **13 combined violations.**

The rule is prose in the vault's root `CLAUDE.md`; the two scripts the triage names as candidate
homes both lack it. Grepping the vault's `*.py`/`*.sh`/`*.mjs` for `implemented_in` or `promoted_to`
returns one hit, and it is a coincidental substring inside a minified `node_modules/workerd` bundle —
so **zero real references**.

An `implemented` or `promoted` with no target is unfalsifiable: nothing distinguishes a real fix
from a closed-by-fiat one, which is the failure the field exists to prevent.

### 3. Spec G items 22 and 23 are now unblocked

Spec G deferred both explicitly *pending in-flight fixes*, with the reason stated: "a ban on inlining
a library that does not exist yet mandates nothing", and "named here so those commits know a gate is
expected of them." Those commits merged on `fix/spec-f-divergence-drain` (`820af90` is on `main`).
The condition is satisfied and neither gate exists:

```bash
for f in reference/check-*.sh reference/test/*.test.sh; do
  /usr/bin/grep -lE 'generators/.*status|atomic-notes|schema\.md' "$f"; done   # none
/usr/bin/grep -c 'frontmatter' reference/check-portability.sh                  # 0
```

This is CLAUDE.md divergence 15, filed 2026-08-04.

---

## Reconciliation — where the sources disagree

**The triage says `/rethink` "has no step that writes the check." That is wrong about the template
and right about the outcome.** `skill-sources/rethink/SKILL.md:269,321` does instruct writing
`implemented_in:`. What is missing is enforcement. Recording the correction matters because the two
diagnoses imply different fixes: "add a step" would edit a template that already has one.

**Divergence 15 says the enum is "currently consistent." That is true of the note enum and false of
these two.** The note enum agrees across its three declaring files (`atomic-notes.md:94`,
`schema.md:137`, `templates.md:30`). The observation and tension enums disagree with the vault, which
divergence 15 did not measure because it only compared generator files to each other. Divergence 15
should be amended rather than superseded.

---

## Scope

Four tasks. Each closes a measured instance, not a hypothetical.

1. **Reconcile the observation and tension enums** with what vaults use, including `blocked` and
   `promoted` for tensions, keeping the three fields separate.
2. **The enum-consistency gate** (Spec G item 22) — assert the declaring files agree, so the
   reconciliation cannot silently come apart again.
3. **C1: conditional-field assertions** (`implemented ⇒ implemented_in:` for observations,
   `promoted ⇒ promoted_to:` for tensions) — the first such rules, and the task that has to
   answer the placement question below.
4. **The frontmatter-inlining ban** (Spec G item 23), in the style of the existing link-library ban.

### The placement question task 3 must answer, not assume

There are three possible homes and each buys something different. **This is the decision the spec
exists to force, and it should be made explicitly rather than by whichever file was easiest to edit.**

| home | reaches | cost |
|---|---|---|
| `reference/validate-kernel.sh` | any vault, on demand | not in CI (needs a vault); manual invocation |
| the generated write-validate hook | **new vaults only** | existing vaults never get it |
| a new kernel primitive | any vault, via the contract | grows the invariant surface; needs `cognitive_grounding` |

The honest default is `validate-kernel.sh`, because it is the only one that reaches the vault that
demonstrated the defect. Note the consequence: it will report on the field vault immediately, and
that vault has 6 violations, so the run goes from `15 PASS / 2 WARN` to something worse until the
vault fixes its own content. **That is the check working.** It must not be softened to keep a number
green — CLAUDE.md already records two occasions where a check was weakened into agreeing with itself.

---

## Deliberately not in scope

- **The tension-threshold population.** The triage shows 6 of 7 open tensions are content
  contradictions `/rethink` structurally cannot resolve, so the threshold fires on a routing defect.
  Real, and a *semantics* change to what `self_evolution.tension_threshold` counts — different work
  from adding a gate. Bundling them would make one review adjudicate two unrelated designs.
- **Re-syncing existing vaults.** The three-tier finding implies a generated-artifact refresh
  mechanism. `/arscontexta:upgrade` is the nearest thing and divergence 5 records that it has never
  been invoked as a slash command against a real vault. A design for that is its own spec.
- **Making `_schema` authoritative.** Narrowing the claim is in scope for task 1's neighbourhood;
  building the deterministic reader that would make it true is a generation-surface change.
- **Spec G items 16, 17, 19, 21, 24, 25, 26.** Each carries a defense in Spec G that this spec does
  not relitigate. Item 27 unblocks with Spec F Task 5 but is small; fold it in only if free.

---

## Success criteria

1. The observation and tension enums include every value the field vault uses, with the three fields
   still separate, and a gate that fails if the declaring files disagree.
2. C1 conditional-field assertions (`implemented ⇒ implemented_in:` and `promoted ⇒ promoted_to:`)
   are asserted by something that runs, with placement decided in writing and reach stated —
   including which vaults it does *not* reach.
3. `check-portability.sh` bans inlining `reference/lib/frontmatter.sh`, proved by planting a copy.
4. Divergence 15 is amended with the vault-measured half; a new divergence records the three-tier
   structural finding, since no gate closes it.
5. Every number this spec states is re-derived at execution and dated.

---

## The premise rule, adopted from four sessions of evidence

Across Specs D–G, **the plan's Step 1 premise was wrong three times out of four**, and each time
measurement found a better RED than the one written down:

- Spec G Task 2 expected six matcher sites; its scan set omitted `generators/`, where a seventh lived.
- Spec G Task 3 expected one hazard; the documented check missed a whole placeholder family.
- Spec G Task 4 expected an all-green run proving zero hook coverage; the mutation it named is the
  one thing already covered.

So: **Step 1 of every task in the plan is "measure the premise; if it does not hold, record what
does and rescope."** Written into the plan rather than left to be rediscovered, so the next executor
knows it is allowed.
