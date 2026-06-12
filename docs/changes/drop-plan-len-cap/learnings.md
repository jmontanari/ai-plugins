# Learnings: drop-plan-len-cap (spec-flow 5.14.0 → 5.15.0)

**Captured:** 2026-06-12
**Type:** change-track (3 Implement phases, doc-as-code)
**Scope:** Remove plan.md length budget gate from 5 coupled files; bump version.

---

## What happened

A pure doc-as-code removal of the qa-plan "Plan over budget" criterion and its five coupled
artifacts (artifact-budgets.md rows, metrics-artifact.md schema, plan/SKILL.md sub-step,
pipeline-config.yaml example keys). All three phases passed Opus QA in one iteration; Phase 3
correctly triggered the FR-8 skip (additions-only, literal scalars, no new SKILL.md).

The Final Review board found one must-fix: `plugins/spec-flow/plugin.json` (the Copilot CLI
descriptor at `plugins/spec-flow/plugin.json`) was not bumped, while `.claude-plugin/plugin.json`
and `marketplace.json` were. The plan listed three of the four version-bearing files; it did not
read `releasing.md` to derive the full list. The fix was a one-line version bump; triage returned
no-re-dispatch.

This is the **second recorded instance** of `plugins/spec-flow/plugin.json` being missed in a
version bump — `releasing.md` records the first at v3.7.0 as a post-merge catch. Two hits
confirms the pattern is systemic.

---

## Key Learnings

### L-1: Plan skill must read releasing.md for version-bump phases

When authoring a version-bump phase, the plan skill derives the target file list from memory
rather than from `plugins/spec-flow/docs/releasing.md`. The releasing.md doc exists exactly
because the Copilot CLI descriptor is easy to miss — but it is not consulted at plan authoring
time. The fix: the plan skill's version-bump phase template should include a `Read releasing.md`
step and derive the `**In scope:**` list from it mechanically.

**Improvement backlog candidate:** add "version-bump phase completeness" check to plan/SKILL.md
and a corresponding qa-plan criterion.

### L-2: FR-8 skip predicate worked correctly on Phase 3

The CHANGELOG insertion and version bumps correctly satisfied all three FR-8 conditions
(additions-only, literal scalars, no new SKILL.md, no procedural scripts). Phase 3 skipped Opus
QA and ran verify commands only. The missed file was a plan enumeration gap, not a correctness
issue with the changes that were made — the skip was the right call.

### L-3: doc-as-code board (2 seeded edge-case reviewers) added coverage

The edge-case-A (structural/pointer-integrity) and edge-case-B (content/semantic) seeded
reviewers found the CHANGELOG "re-converging" wording inaccuracy that would have been missed by
a generic reviewer. Edge-case-B independently confirmed the same issue as the Integration
reviewer, which was sufficient for the triage agent to settle the finding without full-board
re-dispatch.

### L-4: Criterion renumbering was safe — downstream refs were already latently correct

Renumbering Authored-tests from #33 → #32 resolved latent drift in `execute/SKILL.md:1040`
and the `tests/e2e/` fixtures, which had always said "criterion 32" (the correct post-change
number). The renumbering required zero downstream edits. Worth remembering: downstream
cross-references can be latently correct when a renumbering restores an earlier state.

---

## Follow-up items routed to improvement-backlog.md

- **Version-bump completeness (plan + qa-plan + execute):** plan/SKILL.md, qa-plan.md, and
  execute/SKILL.md should all derive the version-bump file list from releasing.md rather than
  from plan memory. See `docs/improvement-backlog.md` item added 2026-06-12.
- **qa-plan.agent.md body drift at criterion #32:** the production dispatch file has a condensed
  form that omits the `**Must-fix**` severity marker on sub-clause (b) (Red-manifest collision).
  See improvement-backlog item added 2026-06-12.
