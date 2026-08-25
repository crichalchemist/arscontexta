# Vocabulary Transformation Reference

When generating a knowledge system for a specific domain, every universal term in the generated context file, templates, skills, and self/ files must use the domain-native equivalent. Vocabulary transformation is not cosmetic — it changes how the system feels to use.

"Surface patterns in reflections" is therapy work. "Extract claims from sources" is research work. Same structural operation, different cognitive framing.

---

## Universal → Domain Mapping

| Universal Term | Research | Therapy | Learning | Relationships | Creative | PM | Companion |
|---------------|----------|---------|----------|---------------|----------|-----|-----------|
| note | claim | reflection | concept note | observation | idea | decision | memory |
| extract / reduce | reduce | surface | break down | notice | discover | document | remember |
| connect / reflect | reflect | find patterns | relate concepts | trace connections | combine ideas | link decisions | recall together |
| verify | verify | check resonance | test understanding | confirm accuracy | evaluate draft | review quality | verify memory |
| MOC | topic map | theme | study guide | relationship map | project hub | decision register | memory collection |
| description field | claim context | reflection summary | concept explanation | observation context | idea sketch | decision rationale | memory context |
| topics footer | research areas | themes | study areas | relationship facets | creative projects | project areas | life areas |
| inbox | capture | journaling | study notes | encounters | inspiration | action items | moments |
| processing / pipeline | pipeline | reflection cycle | study cycle | relationship review | creative process | review cycle | reminiscence |
| wiki link | connection | pattern link | concept link | connection | inspiration thread | decision trail | memory link |
| thinking notes | claims | reflections | concepts | observations | ideas | decisions | memories |
| archive | processed sources | past reflections | mastered material | past encounters | completed works | closed decisions | past events |
| self/ space | research identity | reflection partner | study companion | relationship tracker | creative identity | project mind | companion memory |
| orient | orient | center | review progress | check in | survey ideas | status check | remember |
| persist | persist | journal | log progress | update records | save state | update status | save memories |
| relationship: extends | extends | develops | advances | carries forward | expands | extends | adds to |
| relationship: grounds | grounds | anchors | supports | establishes | underpins | justifies | roots |
| relationship: contradicts | contradicts | challenges | conflicts with | disputes | subverts | blocks | differs from |
| relationship: exemplifies | exemplifies | illustrates | demonstrates | shows | embodies | instances | reminds of |
| relationship: synthesizes | synthesizes | integrates | combines | weaves together | fuses | consolidates | ties together |
| relationship: enables | enables | makes possible | unlocks | allows | sparks | unblocks | lets |

**Note:** the six `relationship:` rows are the enum declared at Level 6.6 of `skills/setup/SKILL.md`, one row per `{vocabulary.rel_*}` key. The `wiki link` row above renames the link; these rename the verb riding inside it. Do not offer "builds on" as an *extends* spelling — it maps to `grounds`, and the Level 6.6 example list omits it for that reason.

---

## Template Name Mapping

| Universal Template | Research | Therapy | Learning | Relationships | Creative | PM | Companion |
|-------------------|----------|---------|----------|---------------|----------|-----|-----------|
| base-note.md | thinking-note.md | reflection-note.md | concept-note.md | observation-note.md | idea-note.md | decision-note.md | memory-note.md |
| moc.md | topic-map.md | theme.md | study-guide.md | relationship-map.md | project-hub.md | decision-register.md | collection.md |

---

## Folder Name Mapping

| Universal Folder | Research | Therapy | Learning | Relationships | Creative | PM | Companion |
|-----------------|----------|---------|----------|---------------|----------|-----|-----------|
| notes/ | notes/ | reflections/ | concepts/ | observations/ | ideas/ | decisions/ | memories/ |
| inbox/ | inbox/ | journal/ | study-inbox/ | encounters/ | inspiration/ | action-items/ | moments/ |
| archive/ | archive/ | past/ | mastered/ | history/ | completed/ | closed/ | past/ |
| templates/ | templates/ | templates/ | templates/ | templates/ | templates/ | templates/ | templates/ |

---

## Skill Name Mapping

| Universal Skill | Research | Therapy | Learning | Relationships | Creative | PM | Companion |
|----------------|----------|---------|----------|---------------|----------|-----|-----------|
| /reduce | /reduce | /surface | /break-down | /notice | /discover | /document | /capture |
| /reflect | /reflect | /find-patterns | /relate | /trace | /combine | /link | /recall |
| /verify | /verify | /check-resonance | /test | /confirm | /evaluate | /review | /verify |
| /reweave | /reweave | /revisit | /revise | /reconnect | /rework | /update | /revisit |
| /remember | /remember | /note-friction | /flag | /flag | /flag | /flag | /remember |
| /next | /next | /next | /next | /next | /next | /next | /next |
| /stats | /stats | /stats | /stats | /stats | /stats | /stats | /stats |
| /graph | /graph | /graph | /graph | /graph | /graph | /graph | /graph |

**Note:** /next (formerly /work + /next) surfaces the next recommended action from the task stack, /stats provides vault metrics and progress visualization, and /graph enables graph query generation. Those three use universal names across all domains — their rows above are uniform on purpose, and renaming one is a defect rather than a domain choice.

/remember (formerly /friction) captures operational friction with automatic detection in session transcripts. It is **not** universal: its row above renames it in five of the seven domains, so substitute it like any other skill name. A previous revision of this note listed /remember alongside the three universal commands, contradicting its own table one line above; the table is correct. The generator's own markup agrees with the table — `{DOMAIN:remember}` appears 16 times across `skills/setup`, `skills/upgrade`, `generators/claude-md.md` and three `generators/features/` blocks, which is substitution intent, not a universal name.

```bash
# Re-derive both halves of that claim.
awk -F'|' 'NR>=63 && NR<=70 { cmd=$2; gsub(/ /,"",cmd);
  same=1; for(i=3;i<=9;i++){ v=$i; gsub(/ /,"",v); if(v!=cmd) same=0 }
  printf "%-12s all-universal=%s\n", cmd, (same?"YES":"NO") }' reference/vocabulary-transforms.md
grep -rn '{DOMAIN:remember}' skills/ skill-sources/ generators/ presets/ | wc -l   # 16
```

**Two commands carry a schema key but no row here:** `cmd_validate` and `cmd_rethink` are declared at Level 6 of `skills/setup/SKILL.md`, while /validate and /rethink have no line in the table above. That gap is recorded, not closed — inventing seven domain spellings apiece would assert a mapping nobody has derived. Until it is derived, those two rename through the Level 6 key alone.

---

## Applying Transformations

### In the init wizard (Step 5b):

1. Determine the user's use case
2. Look up all universal terms in the mapping table above
3. Replace every instance in the generated context file
4. Replace template names and folder names
5. Replace skill names if generating skills
6. **Verify:** Read the generated output. Does it feel natural for the domain? Would a therapy user ever see the word "claim"? Would a PM user see "reduce"?

### Quality check:

The vocabulary test: read the generated context file as if you were the domain user. Every technical term should feel native to the domain. If any term feels imported from a different discipline, transform it.

### Extending the table:

For "Custom / Mixed" use cases, the init wizard should ask the user for their preferred vocabulary. Populate a custom column using the universal terms as prompts: "What do you call a single knowledge unit?" → their answer becomes the "note" equivalent.
