---
name: fixture-phantom-step
description: >
  Defect fixture locking in two ground-truth fixes: (1) a BARE ordered-list item is
  NOT a step target, so a dangling `Step N` masked by an unrelated `N.` enumeration
  is still flagged; (2) per-reference cross-skill scoping — a dangling self-reference
  on a line that ALSO names another `/SKILL.md` path is NOT suppressed (gate-bypass).
---

# Fixture Phantom Step

## Workflow

This skill defines its real steps as bold-labeled ordered-list items (the corpus
convention):

1. **Load config:** read settings.
2. **Run:** do the work.

A prose reference to Step 1 and Step 2 resolves to those bold-labeled items — no
finding.

## Phantom masking

Run Step 7 before continuing — it validates the manifest. `Step 7` is DANGLING:
nothing in this file (no heading, no bold marker, no bold-labeled list item) defines
a step numbered seven.

The block below is an ORDINARY PROSE ENUMERATION, not a step list, so its bare
numbered items must NOT register as step targets (registering them used to make
`Step 7` phantom-resolve against `7.` and hid the dangling reference):

5. We gather facts.
6. We explore.
7. We ship.

## Gate-bypass

Per the charter at `.github/skills/charter-non-negotiables/SKILL.md`, Step 9 runs the
audit. `Step 9` is DANGLING and must be flagged even though this line also contains an
unrelated `/SKILL.md` path token — the old per-LINE cross-skill scoping masked every
step reference on any line holding a skill-path token.
