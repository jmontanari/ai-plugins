---
charter_snapshot:
  architecture: "2026-06-11"
  non-negotiables: "2026-06-11"
  tools: "2026-06-11"
  processes: "2026-06-11"
  flows: "2026-06-11"
  coding-rules: "2026-06-11"
legacy_deferred_rows: false
fast: false
review_board_variant: doc-as-code   # skill/reference markdown IS the deliverable
---

# Plan: drop-plan-len-cap — Retire the plan.md length budget gate

**Brief:** docs/changes/drop-plan-len-cap/brief.md
**Charter:** .claude/skills/charter-*/SKILL.md (binding — each phase enumerates its honored NN-C/CR entries)
**Status:** final-review-pending

## Overview

Remove the plan.md length budget gate (qa-plan "Plan over budget" / FR-014-for-plan) from every coupled site, leaving the `qa-prd ≤7-AC` scope gate and the `qa-plan` #22–31 concreteness floors as the sole plan-quality controls. The change is pure doc-as-code: markdown/YAML/JSON text edits across five files, in three Implement-track phases — (1) remove the gate enforcement, (2) remove the budget definitions/docs, (3) bump version + CHANGELOG. The spec/deliberation budget path (qa-spec #16) is deliberately untouched, so FR-014 survives for those classes.

All phases are **Implement track** (`[Implement]` + `[Verify]`, no `[TDD-Red]`, no `[Write-Tests]`): the deliverable is reference/agent/skill markdown, and the oracle is a set of `grep`/`jq` assertions in each `[Verify]` block — unit tests over markdown deletions would be ceremony (sanctioned Implement-track / docs-as-code use).

## Architectural Decisions

### ADR-1: Remove the gate entirely rather than demote it to advisory
**Context:** The plan-length must-fix competes with the #22–31 concreteness floors. One option keeps a soft, advisory "this plan is long" note; the chosen option removes the budget outright.
**Decision:** Remove the plan-length budget entirely — no soft advisory survives.
**Alternatives considered:** (a) Demote to advisory-only — rejected: a "shorter is better" nudge re-injects the exact bias the change rejects, and dense plans would draw a steady stream of noise notes. (b) Raise the ceilings — rejected: any fixed line ceiling is a poor proxy for scope now that plans are dense by design; the `≤7-AC` rule already carries scope.
**Consequences:** Easier — dense exec-ready plans stop drawing must-fix/advisory noise. Harder — none; scope is still gated by `≤7-AC`. Irreversible within-major only via re-adding the criterion (cheap to reverse).
**Charter alignment:** NN-C-003 (keys remain parseable-but-ignored; migration note), NN-C-002 (text-only).

### ADR-2: Renumber Authored-tests #33 → #32 instead of leaving a tombstone
**Context:** Removing criterion #32 leaves a numbering gap. `skills/execute/SKILL.md:1040` and the `tests/e2e/` fixtures already refer to the Authored-tests criterion as "criterion 32" (latent drift from the v5.12.2 insertion of the budget criterion at #32).
**Decision:** Renumber the Authored-tests criterion #33 → #32 in `qa-plan.md`.
**Alternatives considered:** (a) Leave a `32. (removed)` tombstone — rejected: it preserves the existing wrong "criterion 32" downstream references. (b) Renumber and also touch every downstream reference — unnecessary: the references already say "32", so renumbering makes them correct with no further edits.
**Consequences:** Easier — `qa-plan.md` re-converges with `qa-plan.agent.md` (which already has Authored-tests at #32) and downstream "criterion 32" references become accurate. Harder — none.
**Charter alignment:** CR-001 (agent file structure stays valid).

## Phases

### Phase 1 (Implement track): Remove the gate enforcement
**Exit Gate:** `grep -c "Plan over budget" plugins/spec-flow/agents/qa-plan.md` returns `0`; the Authored-tests criterion is `32.`; `grep -nE "wc -l|soft 750|plan_md_max_phase" plugins/spec-flow/skills/plan/SKILL.md` returns no budget-resolution hits.
**ACs Covered:** AC-1, AC-3
**In scope:** `plugins/spec-flow/agents/qa-plan.md`, `plugins/spec-flow/skills/plan/SKILL.md`
**NOT in scope:** `qa-plan.agent.md` (already omits the budget criterion — confirmed, no edit); all budget *definition* files (Phase 2); version files (Phase 3).
**Steps traversed (P2):** `skills/plan/SKILL.md` Phase-3 (qa-plan dispatch, iter-1 and focused re-review budget sub-steps) and Phase-5a (metrics write) — the change removes the budget interpolation from the dispatch and the `plan_md_*` keys from the metrics write; no other step traversed.
**Dispatch sites (P3):** qa-plan agent dispatch (Phase-3 step 2 + step 3 re-dispatch) — the prompt no longer carries budget values; the agent template it reads (`agents/qa-plan.md`) no longer defines the criterion. No new dispatch site added or removed.
**Charter constraints honored in this phase:**
- CR-001 (agent frontmatter schema): the `qa-plan.md` `---\nname: qa-plan\ndescription: …\n---` frontmatter is untouched; only a body criterion is removed and the next renumbered.
- NN-C-002 (markdown + config only): markdown-only edits.

- [x] **[Implement]** Write code per the plan
  - Architecture constraints this phase must honor: `artifact-budgets.md` is the single source of truth (CR-008) — this phase removes only the *enforcement*; the *definition* removal is Phase 2, keeping the two edits coherent within the piece.

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/agents/qa-plan.md**
  - Anchor: criterion list, lines 193–205 (`32. **Plan over budget …**` through the start of `33. **Authored-tests declaration …**`)
  - Current:
    ```
    192:191
    193:32. **Plan over budget (FR-014) (activate when the orchestrator supplies budget values; skip if absent — not an error).** The orchestrator interpolates plan.md's total line count and its largest per-phase line count, each with soft + hard budgets (`plugins/spec-flow/reference/artifact-budgets.md`). Judge from the supplied counts — do NOT count lines yourself.
    194:    Flag (Must-fix):
    195:    - Total OR any per-phase count over its HARD ceiling → name which (total / largest phase), actual vs hard, and split/condense guidance (split the piece per the qa-prd ≤7-AC rule, or hoist detail to a reference doc). NO waiver.
    196:    Advisory only (NOT must-fix):
    197:    - A count over SOFT but under HARD → advisory note.
    198:    Do NOT flag:
    199:    - Counts at/under soft; no supplied budget (skip).
    200:    Evidence: quote the supplied count and the exceeded ceiling. **Must-fix on hard-ceiling breach only.**
    201:33. **Authored-tests declaration (activate only when a phase carries an `**Authored-tests:**` field; …
    ```
  - Target: delete the entire criterion #32 block (lines 193–200). Change the heading `33. **Authored-tests declaration …` to `32. **Authored-tests declaration …` (decrement only this one number; it is the last criterion, so no further renumbering cascades). Leave criterion #31 (Test Data) and all preceding criteria untouched.
  - Done: the criterion formerly at #33 now reads `32.`; no `Plan over budget` text remains; criteria are contiguous 1…32.
  - Verify: `grep -c "Plan over budget" plugins/spec-flow/agents/qa-plan.md` → `0`; `grep -nE "^3[0-9]\." plugins/spec-flow/agents/qa-plan.md | tail -3` shows `30.`, `31.`, `32.` with `32.` = Authored-tests.

  **T-2: MODIFY plugins/spec-flow/skills/plan/SKILL.md**
  - Anchor: Phase-3 qa-plan dispatch — the `**Budget resolution (artifact-budgets …)**` sub-step (line 627) + its worked-example HTML comment (line 629); the iteration-2 re-run clause (line 642); and the `budget_compliance` clause inside the Phase-5a metrics write (line 723).
  - Current (line 627, the sub-step to delete in full):
    ```
    627:   **Budget resolution (artifact-budgets, both dispatch sites — iter 1 and focused re-review):** Resolve `artifact_budgets` overrides from `.spec-flow.yaml` … Interpolate into the qa-plan prompt: `plan.md total is N lines; soft 750; hard 1000` and `largest phase is M lines; soft 90; hard 220` … so criterion #32 judges from the orchestrator-supplied counts, never from the interpolated text.
    629:   <!-- Example: artifact_budgets absent → plan_md_total hard=1000 … #32 must-fix on total; largest phase passes. -->
    ```
  - Current (line 642, the iter-2 clause to delete):
    ```
    642:   - Apply the **Budget resolution** sub-step from step 2 above (re-run `wc -l` and per-phase max on the current `plan.md`; interpolate updated counts) before composing the focused re-review prompt.
    ```
  - Current (line 723, the metrics clause to trim — remove only the `budget_compliance` plan portion):
    ```
    723:   … upsert the `plan:` block … with: `qa_iterations`, `concreteness_floor`, and `budget_compliance` — for each artifact measured in the Phase-3 budget-resolution sub-step (`plan_md_total` and `plan_md_max_phase`), write `{lines: N, soft: S, hard: H, status: pass|over}` … `budget_compliance` is passive metadata (ADR-3) … Also upsert `gate_scaling.plan_gate:` …
    ```
  - Target:
    - Delete the entire line-627 "Budget resolution" sub-step paragraph and its line-629 example comment.
    - Delete the line-642 "Apply the Budget resolution sub-step …" bullet.
    - In the line-723 metrics sentence, remove `, and `budget_compliance`` from the field list and excise the clause `— for each artifact measured in the Phase-3 budget-resolution sub-step (`plan_md_total` and `plan_md_max_phase`), write `{lines: N, soft: S, hard: H, status: pass|over}` … `budget_compliance` is passive metadata (ADR-3) — `scripts/metrics-aggregate` does NOT consume it.` so the sentence upserts only `qa_iterations`, `concreteness_floor`, and the `gate_scaling.plan_gate:` block. Preserve the `gate_scaling`, `last_updated`, and degraded-write behavior verbatim.
  - Done: no "Budget resolution" sub-step, no `wc -l`/`soft 750`/`plan_md_max_phase` references in Phase 3; the Phase-5a write lists `qa_iterations`, `concreteness_floor`, `gate_scaling` only.
  - Verify: `grep -nE "Budget resolution|wc -l|soft 750|plan_md_total|plan_md_max_phase" plugins/spec-flow/skills/plan/SKILL.md` → no matches.

- [x] **[Verify]** Confirm the implementation is sound
  **Per-change checks:**
  - T-1: `grep -c "Plan over budget" plugins/spec-flow/agents/qa-plan.md` — Expected: `0`. `grep -n "32. \*\*Authored-tests" plugins/spec-flow/agents/qa-plan.md` — Expected: one match.
  - T-2: `grep -nE "Budget resolution|wc -l|soft 750|plan_md" plugins/spec-flow/skills/plan/SKILL.md` — Expected: no output.
  **Phase-level check:**
  - Run: `grep -nE "criterion #?32|criterion #?33" plugins/spec-flow/agents/qa-plan.md`
  - Expected: no surviving self-reference to a removed criterion number inside qa-plan.md (the file numbers criteria by heading, not by cross-reference).
  - Failure: any remaining "Plan over budget" text, a non-contiguous criterion sequence, or a lost `gate_scaling`/`concreteness_floor` metrics write.

- [x] **[QA]** Phase review
  - Review against: AC-1, AC-3
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 2 (Implement track): Remove the budget definitions, docs, and sweep
**Exit Gate:** the AC-6 sweep `grep -rnE "plan_md_total|plan_md_per_phase|plan_md_max_phase|plan\.md \(total\)|plan\.md \(per-phase\)" plugins/spec-flow` returns hits only in `CHANGELOG.md`; spec/deliberation budget rows still present.
**ACs Covered:** AC-2, AC-4, AC-5, AC-6
**In scope:** `plugins/spec-flow/reference/artifact-budgets.md`, `plugins/spec-flow/reference/metrics-artifact.md`, `plugins/spec-flow/templates/pipeline-config.yaml`
**NOT in scope:** `spec.md`/`deliberation.md` budget rows and `spec.budget_compliance` (must remain); qa-spec #16 (Phase-7 regression guard, AC-7); version files (Phase 3).
**Charter constraints honored in this phase:**
- NN-C-002 (markdown + config only): markdown/YAML text edits only.

- [x] **[Implement]** Write code per the plan
  - Architecture constraints this phase must honor: `artifact-budgets.md` remains the single source of truth for the *surviving* classes (spec/deliberation/research/learnings); only the plan-class rows and the plan override keys are removed.

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/reference/artifact-budgets.md**
  - Anchor: line 3 (citation), lines 10–11 (plan budget rows), line 16 (plan worked-example comment), lines 55–60 (override example), line 72 (override-keys sentence).
  - Current (lines 10–11, 16):
    ```
    10:| plan.md (total) | 750 | 1000 | qa-plan #32 | ~25k |
    11:| plan.md (per-phase) | 90 | 220 | qa-plan #32 | ~5.5k |
    16:<!-- Worked example: a plan.md with total 940 lines … A plan.md total 1050 → must-fix with "split the piece or hoist detail to reference". -->
    ```
  - Current (line 3 citation fragment, and lines 55–60 / 72):
    ```
    3:… It is cited by `plugins/spec-flow/agents/qa-spec.md` (criterion #16), `plugins/spec-flow/agents/qa-plan.md` (criterion #32), `plugins/spec-flow/reference/metrics-artifact.md` (budget_compliance), `plugins/spec-flow/skills/spec/SKILL.md` and `plugins/spec-flow/skills/plan/SKILL.md` (resolve overrides + `wc -l` interpolation). …
    55:  plan_md_total:
    56:    soft: 900
    57:    hard: 1200
    58:  plan_md_per_phase:
    59:    soft: 120
    60:    hard: 280
    72:Override keys: `spec_md`, `plan_md_total`, `plan_md_per_phase` (stored in metrics.yaml as `plan_md_max_phase` …), `research_md`, `deliberation_md`, `learnings_md`. …
    ```
  - Target:
    - Delete table rows 10 and 11 (both plan.md rows).
    - Delete the line-16 plan worked-example comment (replace with a deliberation/spec-only example if one is wanted, else remove outright).
    - Line 3: remove the `` `plugins/spec-flow/agents/qa-plan.md` (criterion #32), `` citation and drop `and `plugins/spec-flow/skills/plan/SKILL.md`` / the `wc -l` mention so the citation lists qa-spec #16, metrics budget_compliance (spec), and the spec SKILL only. (artifact-budgets remains cited by the *spec* path.)
    - Delete the `plan_md_total:` and `plan_md_per_phase:` blocks from the lines 55–60 override example.
    - Line 72: remove `, `plan_md_total`, `plan_md_per_phase` (stored in metrics.yaml as `plan_md_max_phase` …)` from the override-keys sentence, leaving `spec_md`, `research_md`, `deliberation_md`, `learnings_md`.
    - Leave §6 "Irreducible overage" and §3 "Tiers and gates" intact — they still govern the surviving classes via qa-spec #16.
  - Done: no `plan.md (total)` / `plan.md (per-phase)` row, no `plan_md_*` key, no qa-plan #32 citation; spec/deliberation rows and override keys remain.
  - Verify: `grep -nE "plan\.md \(|plan_md_|qa-plan #32" plugins/spec-flow/reference/artifact-budgets.md` → no output; `grep -c "spec.md" plugins/spec-flow/reference/artifact-budgets.md` → ≥1.

  **T-2: MODIFY plugins/spec-flow/reference/metrics-artifact.md**
  - Anchor: lines 40–50 (the `budget_compliance:` example block under `plan:`) and lines 114–121 (the `plan.budget_compliance.*` field definitions).
  - Current (lines 40–50):
    ```
    40:  budget_compliance:
    41:    plan_md_total:
    42:      lines: 664
    43:      soft: 750
    44:      hard: 1000
    45:      status: pass
    46:    plan_md_max_phase:
    47:      lines: 91
    48:      soft: 90
    49:      hard: 220
    50:      status: pass
    ```
  - Current (lines 114–121): the eight `plan.budget_compliance.plan_md_total.*` and `plan.budget_compliance.plan_md_max_phase.*` definition bullets.
  - Target: delete the lines 40–50 `budget_compliance:` block from the `plan:` example (leaving `qa_iterations` and `concreteness_floor` under `plan:`), and delete the lines 114–121 `plan.budget_compliance.*` definition bullets. Leave every `spec.budget_compliance.*` definition (lines 106–113) untouched.
  - Done: no `plan.budget_compliance` schema or example; `spec.budget_compliance` definitions intact.
  - Verify: `grep -n "plan.budget_compliance\|plan_md_total\|plan_md_max_phase" plugins/spec-flow/reference/metrics-artifact.md` → no output; `grep -c "spec.budget_compliance" plugins/spec-flow/reference/metrics-artifact.md` → ≥1.

  **T-3: MODIFY plugins/spec-flow/templates/pipeline-config.yaml**
  - Anchor: the `artifact_budgets:` documentation block (lines 205–214), which lists classes and example overrides.
  - Current:
    ```
    207:#   Classes: spec_md, plan_md_total, plan_md_per_phase, research_md, deliberation_md, learnings_md.
    211:#   spec_md: {soft: 300, hard: 520}
    212:#   plan_md_total: {soft: 750, hard: 1000}
    213(approx):#   plan_md_per_phase: {soft: 90, hard: 220}
    ```
  - Target: remove `plan_md_total, plan_md_per_phase, ` from the line-207 class list, and delete the `plan_md_total:` and `plan_md_per_phase:` example-override comment lines. Leave `spec_md` and the remaining classes.
  - Done: no `plan_md_total`/`plan_md_per_phase` in the documented override surface.
  - Verify: `grep -nE "plan_md_total|plan_md_per_phase" plugins/spec-flow/templates/pipeline-config.yaml` → no output.

- [x] **[Verify]** Confirm the implementation is sound
  **Per-change checks:**
  - T-1: `grep -nE "plan\.md \(|plan_md_|qa-plan #32" plugins/spec-flow/reference/artifact-budgets.md` — Expected: no output.
  - T-2: `grep -nE "plan.budget_compliance|plan_md_total|plan_md_max_phase" plugins/spec-flow/reference/metrics-artifact.md` — Expected: no output.
  - T-3: `grep -nE "plan_md_total|plan_md_per_phase" plugins/spec-flow/templates/pipeline-config.yaml` — Expected: no output.
  **Phase-level check (AC-6 sweep):**
  - Run: `grep -rnE "plan_md_total|plan_md_per_phase|plan_md_max_phase|plan\.md \(total\)|plan\.md \(per-phase\)|Plan over budget" plugins/spec-flow`
  - Expected: matches only in `plugins/spec-flow/CHANGELOG.md` (history entries for 5.12.2 / 5.14.0). No match in `agents/`, `reference/`, `skills/`, `templates/`.
  - Failure: any surviving reference outside CHANGELOG.
  - Verify (regression): `grep -nE "criterion 32|criterion #32" plugins/spec-flow/skills/execute/SKILL.md plugins/spec-flow/tests/e2e/lib/contract.sh` still resolves to the Authored-tests behavior (now correctly #32) — Expected: present, unchanged.

- [x] **[QA]** Phase review
  - Review against: AC-2, AC-4, AC-5, AC-6
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 3 (Implement track): Version bump, CHANGELOG, marketplace sync
**Exit Gate:** `diff <(jq -r .version plugins/spec-flow/.claude-plugin/plugin.json) <(jq -r '.plugins[] | select(.name == "spec-flow") | .version' .claude-plugin/marketplace.json)` produces no output; both read `5.15.0`; CHANGELOG has a `[5.15.0]` section.
**ACs Covered:** AC-7
**In scope:** `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `plugins/spec-flow/CHANGELOG.md`
**NOT in scope:** any pipeline behavior file (done in Phases 1–2).
**Charter constraints honored in this phase:**
- NN-C-009 (always bump version): minor bump 5.14.0 → 5.15.0.
- NN-C-001 (version/marketplace sync): both descriptors updated together.
- NN-C-007 (CHANGELOG present) + CR-006 (Keep a Changelog format): new `[5.15.0]` entry with `Removed`/`Changed`.
- NN-C-003 (backward compatibility): migration note that the `plan_md_total`/`plan_md_per_phase` keys are now ignored, not errored.

- [x] **[Implement]** Write code per the plan

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/.claude-plugin/plugin.json**
  - Anchor: `"version"` field (line 4).
  - Current: `"version": "5.14.0",`
  - Target: `"version": "5.15.0",`
  - Done: plugin.json reads 5.15.0.
  - Verify: `jq -r .version plugins/spec-flow/.claude-plugin/plugin.json` — Expected: `5.15.0`.

  **T-2: MODIFY .claude-plugin/marketplace.json**
  - Anchor: the spec-flow plugin entry `"version"` (line 15, inside the object whose `"name": "spec-flow"` is at line 12).
  - Current: `"version": "5.14.0",`
  - Target: `"version": "5.15.0",`
  - Done: the spec-flow marketplace entry reads 5.15.0; the `rtk` entry at line 24 (1.1.1) is untouched.
  - Verify: `jq -r '.plugins[] | select(.name == "spec-flow") | .version' .claude-plugin/marketplace.json` — Expected: `5.15.0`.

  **T-3: MODIFY plugins/spec-flow/CHANGELOG.md**
  - Anchor: the `## [Unreleased]` heading (line 5) and the top of the version list.
  - Current:
    ```
    ## [Unreleased]

    ## [5.14.0] — 2026-06-11
    ```
  - Target: insert a new release section between `## [Unreleased]` and `## [5.14.0]`:
    ```
    ## [5.15.0] — 2026-06-11

    ### Removed
    - **Plan length budget gate (retires FR-014 for plan.md).** `qa-plan` no longer flags a plan for total or per-phase line count. Removed: the `qa-plan` "Plan over budget" criterion (its Authored-tests criterion is renumbered #33 → #32, re-converging `qa-plan.md` with `qa-plan.agent.md`); the `plan.md (total)`/`plan.md (per-phase)` rows + `plan_md_total`/`plan_md_per_phase` override keys in `reference/artifact-budgets.md`; the Phase-3 `wc -l` budget-resolution sub-step and the `plan.budget_compliance` metrics write in `skills/plan/SKILL.md`; the `plan.budget_compliance` schema in `reference/metrics-artifact.md`; and the documented keys in `templates/pipeline-config.yaml`.

    ### Changed
    - Plan scope is now gated solely by the `qa-prd ≤7-AC` piece-split rule; plan detail is governed solely by the `qa-plan` #22–31 concreteness floors. Length is no longer judged — dense, exec-ready plans no longer draw a length must-fix.

    ### Notes
    - **Backward compatibility (NN-C-003):** `spec.md`/`deliberation.md`/`research.md`/`learnings.md` budgets and the `qa-spec` #16 gate are unchanged. Existing `.spec-flow.yaml` projects that set `artifact_budgets.plan_md_total` or `plan_md_per_phase` keep parsing — those keys are now silently ignored (no error) via the absent-⇒-default escape hatch.
    ```
  - Done: a well-formed `[5.15.0]` Keep-a-Changelog section sits above `[5.14.0]`.
  - Verify: `grep -n "## \[5.15.0\]" plugins/spec-flow/CHANGELOG.md` — Expected: one match above the 5.14.0 heading.

- [x] **[Verify]** Confirm the implementation is sound
  **Per-change checks:**
  - T-1: `jq -r .version plugins/spec-flow/.claude-plugin/plugin.json` — Expected: `5.15.0`.
  - T-2: `jq -r '.plugins[] | select(.name == "spec-flow") | .version' .claude-plugin/marketplace.json` — Expected: `5.15.0`.
  - T-3: `grep -c "## \[5.15.0\]" plugins/spec-flow/CHANGELOG.md` — Expected: `1`.
  **Phase-level check (NN-C-001 sync):**
  - Run: `diff <(jq -r .version plugins/spec-flow/.claude-plugin/plugin.json) <(jq -r '.plugins[] | select(.name == "spec-flow") | .version' .claude-plugin/marketplace.json)`
  - Expected: no output (versions match).
  - Failure: any diff output (version drift) or a malformed CHANGELOG section.

- [x] **[QA]** Phase review
  - Review against: AC-7
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

## Executable AC Binding

| AC | Verification Type | Command/Check | Expected Result |
|----|-------------------|---------------|-----------------|
| AC-1 | shell | `grep -c "Plan over budget" plugins/spec-flow/agents/qa-plan.md; grep -n "^32. \*\*Authored-tests" plugins/spec-flow/agents/qa-plan.md` | `0`; Authored-tests heading is `32.` |
| AC-2 | shell | `grep -nE "plan\.md \(|plan_md_|qa-plan #32" plugins/spec-flow/reference/artifact-budgets.md; grep -c "spec.md \| 300" plugins/spec-flow/reference/artifact-budgets.md` | no plan matches; spec row present |
| AC-3 | shell | `grep -nE "Budget resolution\|wc -l\|soft 750\|plan_md" plugins/spec-flow/skills/plan/SKILL.md; grep -c "concreteness_floor" plugins/spec-flow/skills/plan/SKILL.md` | no budget matches; concreteness_floor write present |
| AC-4 | shell | `grep -n "plan.budget_compliance\|plan_md_total\|plan_md_max_phase" plugins/spec-flow/reference/metrics-artifact.md; grep -c "spec.budget_compliance" plugins/spec-flow/reference/metrics-artifact.md` | no plan matches; spec defs present |
| AC-5 | shell | `grep -nE "plan_md_total\|plan_md_per_phase" plugins/spec-flow/templates/pipeline-config.yaml` | no output |
| AC-6 | shell | `grep -rnE "plan_md_total\|plan_md_per_phase\|plan_md_max_phase\|plan\.md \(total\)\|plan\.md \(per-phase\)\|Plan over budget" plugins/spec-flow \| grep -v CHANGELOG \| grep -v docs/changes` | no output |
| AC-7 | shell | `diff <(jq -r .version plugins/spec-flow/.claude-plugin/plugin.json) <(jq -r '.plugins[]\|select(.name=="spec-flow")\|.version' .claude-plugin/marketplace.json); grep -c "criterion #16" plugins/spec-flow/agents/qa-spec.md` | no diff output; qa-spec #16 present |

## Contracts

No TDD-track phases — all phases are Implement track (doc-as-code). No code contracts to declare.
