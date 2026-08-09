#!/bin/bash
# placeholder-pattern.sh -- the single definition of arscontexta's three placeholder
# families: {vocabulary.X}, {config.X}, {DOMAIN:X}.
#
# Sourced by reference/check-placeholder-count.sh (count-only property: no skill-sources/
# file loses placeholders across a diff range) and reference/check-vocabulary-schema.sh
# (resolution property: every {vocabulary.X}/{DOMAIN:X} used must resolve to a declared
# schema key). One definition, not two independently-typed copies -- this repo has already
# shipped that exact divergence twice (CONTRIBUTING.md's copy vs. skill-authoring.md's;
# three spellings of the note-status enum). See
# docs/superpowers/specs/archive/2026-08-08-vocabulary-schema-coverage-design.md.
#
# Do NOT widen to a bare {...}: that also matches ${TARGET} and ${FILE}, turning a
# shell-variable count into a placeholder count. skill-authoring.md section 2 says so.
PLACEHOLDER_PAT='{vocabulary\.[a-z_]*}\|{config\.[a-z_]*}\|{DOMAIN:[^}]*}'
