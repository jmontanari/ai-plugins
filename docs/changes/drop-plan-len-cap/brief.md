---
charter_snapshot:
  architecture: "2026-06-11"
  non-negotiables: "2026-06-11"
  tools: "2026-06-11"
  processes: "2026-06-11"
  flows: "2026-06-11"
  coding-rules: "2026-06-11"
  integrations: ~
jira_key: ~
jira_url: ~
---

# Brief: drop-plan-len-cap — Retire the plan.md length budget gate

## Problem Statement

The `plan.md` length budgets (total 750/1000, per-phase 90/220) are enforced as a **must-fix** by `qa-plan` criterion #32 (FR-014). This ceiling now fights the plan stage's own purpose. Over the exec-ready PRD (5.3–5.6.0) the plan stage was deliberately re-scoped toward **"dense plan, dumb execute"**: `qa-plan` criteria #22–31 enforce a thorough *concreteness floor* — verbatim CURRENT code in every change block (#23), inline pattern resolution so the executor never reads another file (#24), per-phase concreteness floor (#28), test-data blocks (#31), branch-enumeration ACs (#30). A plan that satisfies that floor is **long by construction**, and #32 then flags it as a must-fix for being long. The two pull in opposite directions; the ceiling is a holdover that predates the floor work. Line count is now a poor proxy for piece scope — the `qa-prd ≤7-AC` piece-split rule already carries the real scope gate, and removing the length gate loses no scope signal. Less plan content forces execution to re-derive design decisions; the cap institutionalizes exactly the thinness we want to eliminate.

## Functional Requirements

- FR-1: `qa-plan` no longer flags a plan for total or per-phase line count. The "Plan over budget" criterion is removed entirely (no soft advisory survives — a "this plan is long" nudge re-injects the shorter-is-better bias we are rejecting).
- FR-2: The `qa-prd ≤7-AC` piece-split rule remains the scope gate (unchanged).
- FR-3: The `qa-plan` concreteness floors (#22–31) remain the binding plan-quality bar (unchanged).
- FR-4: All sites coupled to the plan-length gate are removed with no dangling references: the `artifact-budgets.md` plan rows + override keys, the `plan/SKILL.md` Phase-3 `wc -l` budget-resolution sub-step and its `plan_md_*` metrics write, the `metrics-artifact.md` `plan.budget_compliance` schema, and the `pipeline-config.yaml` documented keys.
- FR-5: `spec.md` / `deliberation.md` / `research.md` / `learnings.md` budgets — and FR-014 as it applies to `qa-spec` #16 — are left fully intact.
- FR-6: The plugin version is bumped and the CHANGELOG records the removal with a backward-compatibility note (charter NN-C-009 / NN-C-001 / NN-C-007).

## Acceptance Criteria

1. AC-1: `qa-plan.md` no longer contains the "Plan over budget" criterion; the former criterion #33 ("Authored-tests declaration") is renumbered to #32. The result matches `qa-plan.agent.md` (which already omits the budget criterion). `grep -c "Plan over budget" plugins/spec-flow/agents/qa-plan.md` returns `0`.
2. AC-2: `reference/artifact-budgets.md` no longer lists the `plan.md (total)` or `plan.md (per-phase)` budget rows, the plan worked-example comment, or the `plan_md_total` / `plan_md_per_phase` override-key example and sentence. The `spec.md` and `deliberation.md` rows and the qa-spec #16 citation remain.
3. AC-3: `skills/plan/SKILL.md` no longer interpolates plan length budgets into the qa-plan prompt — the Phase-3 "Budget resolution" sub-step, its worked-example comment, the iteration-2 re-run clause, and the `plan_md_total` / `plan_md_max_phase` portion of the Phase-5a metrics write are gone. The `qa_iterations`, `concreteness_floor`, and `gate_scaling` metrics writes are preserved.
4. AC-4: `reference/metrics-artifact.md` no longer defines `plan.budget_compliance` (neither the example block nor the field definitions). `spec.budget_compliance` is unchanged.
5. AC-5: `templates/pipeline-config.yaml` no longer documents `plan_md_total` or `plan_md_per_phase` under `artifact_budgets`. `spec_md` and the other surviving classes remain.
6. AC-6: No dangling plan-length coupling remains: `grep -rnE "plan_md_total|plan_md_per_phase|plan_md_max_phase|plan\.md \(total\)|plan\.md \(per-phase\)|Plan over budget" plugins/spec-flow` returns matches only in `CHANGELOG.md` and this change's `docs/changes/` artifacts. Downstream "criterion 32" references in `skills/execute/SKILL.md` and `tests/e2e/` now resolve to the renumbered Authored-tests criterion (no reference to a criterion #33 remains).
7. AC-7: The spec/deliberation budget path is untouched (regression guard): `qa-spec.md` criterion #16, the `artifact-budgets.md` spec/deliberation rows, and `metrics-artifact.md` `spec.budget_compliance` are byte-identical to pre-change; and the plugin version + marketplace entry are in sync at the new version with a CHANGELOG entry (`diff <(jq -r .version plugins/spec-flow/.claude-plugin/plugin.json) <(jq -r '.plugins[] | select(.name == "spec-flow") | .version' .claude-plugin/marketplace.json)` produces no output).

## Non-Negotiables Honored

- NN-C-002 (markdown + config only): every change is a markdown/YAML/JSON text edit — no runtime code or dependency is introduced. *Cross-cutting — honored by all phases via text-only edits.*
- NN-C-003 (backward compatibility within a major version): the removed `plan_md_total` / `plan_md_per_phase` config keys remain parseable-but-ignored via the existing absent-⇒-default escape hatch; a CHANGELOG migration note documents the behavior change. Honored in Phase 3.
- NN-C-001 (version/marketplace sync): `plugin.json` and the root `marketplace.json` spec-flow entry are bumped together. Honored in Phase 3.
- NN-C-007 (CHANGELOG present, Keep a Changelog): a `[5.15.0]` entry is added. Honored in Phase 3.
- NN-C-009 (always bump version on plugin changes): minor bump 5.14.0 → 5.15.0. Honored in Phase 3.

## Coding Rules Honored

- CR-001 (agent frontmatter schema): the `qa-plan.md` `name` + `description` frontmatter is left valid and unchanged when the criterion is removed. Honored in Phase 1.
- CR-006 (CHANGELOG format — Keep a Changelog): the new entry uses the `Removed` / `Changed` sections and SemVer heading. Honored in Phase 3.

## Out of Scope

- `spec.md`, `deliberation.md`, `research.md`, `learnings.md` budgets and the `qa-spec` #16 gate — untouched.
- The `qa-prd ≤7-AC` piece-split rule — unchanged.
- Adding any *new* concreteness/detail-floor criterion to qa-plan (the existing #22–31 floor already enforces density; strengthening it is a separate, larger change).
- Editing the diverged `qa-plan.agent.md` beyond confirming it already matches the target numbering.
