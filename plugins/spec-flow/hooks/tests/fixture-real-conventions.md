---
name: fixture-real-conventions
description: >
  Regression guard for the four real-corpus conventions the linter must tolerate
  (backtick cross-refs, bold-marker steps, cross-skill refs, incidental single-value
  config mentions). Must lint CLEAN (exit 0) under the refined invariants.
---

# Fixture Real Conventions

This fixture mirrors the conventions of the real `skills/*/SKILL.md` corpus. Every
construct here is a real convention the linter must NOT false-positive on, so this
fixture lints clean (exit 0, no findings).

## Overview

The flow defines its steps as bold markers rather than headings (the `prd/SKILL.md`
convention). It begins at Step 1 below and ends after the cleanup pass.

**Step 1: Detect inputs**

Collect the target paths. A prose reference to Step 1 above must resolve to this
bold-marker step definition, not require a `### Step 1` heading.

**Step 2: Process**

Process each input, then proceed to Step 1 on the next run.

## Cross-file pointers (backtick-wrapped)

The mid-group resume procedure is documented out-of-file. Resume from the group
journal per `reference/deferred-commit-journal.md` §Resume algorithm — the path is
wrapped in inline-code backticks exactly as the real corpus writes it, and the
target heading exists in that reference doc, so this cross-ref resolves clean.

Recovery uses the split form per `reference/deferred-commit-journal.md` §File-scoped
recovery recipe.

## Cross-skill references (out of scope)

Pipeline triage is delegated elsewhere: the orchestrator
(`plugins/spec-flow/skills/execute/SKILL.md` Step 6c) handles discovery defer. A
reference qualified with another skill's path — `execute/SKILL.md Step 6c` — is a
cross-skill reference the linter cannot resolve and must not flag.

A step-LIST may share one ownership phrase on a single line: pipeline triage (Step 6c / Step 8) belongs to `execute`, not here. The ownership phrase governs both list members even though it immediately follows only the last, so both are treated as cross-skill and neither is flagged.

## Same-file reference on a skill-path line (gate-bypass guard)

The audit (defined per `.github/skills/charter-non-negotiables/SKILL.md`) is performed
by Step 1 above. `Step 1` here is a SAME-file self-reference and must still resolve to
the bold-marker step definition — the unrelated `/SKILL.md` path token on this line
must NOT suppress it (per-reference cross-skill scoping, not per-line).

## Configuration notes

This is a non-TDD piece (the plan front-matter declares `tdd: false`). That single
incidental config mention is NOT a branch-documentation region — it names one enum
value in passing — so it must not trigger config-branch parity for `tdd`.
