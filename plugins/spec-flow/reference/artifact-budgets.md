# Artifact size budgets

This document is the single source of truth for per-artifact-class size budgets. It is cited by `plugins/spec-flow/agents/qa-spec.md` (criterion #16), `plugins/spec-flow/agents/qa-plan.md` (criterion #32), `plugins/spec-flow/reference/metrics-artifact.md` (budget_compliance), `plugins/spec-flow/skills/spec/SKILL.md` and `plugins/spec-flow/skills/plan/SKILL.md` (resolve overrides + `wc -l` interpolation). Any definition, threshold, or budget value lives here and nowhere else; the consuming files cite this document and do not restate its definitions.

## 1. Budget table

| Class | Soft (advisory) | Hard (must-fix) | Gate | Approx tokens (hard) |
|---|---|---|---|---|
| spec.md | 300 | 520 | qa-spec #16 | ~13k |
| plan.md (total) | 750 | 1000 | qa-plan #32 | ~25k |
| plan.md (per-phase) | 90 | 220 | qa-plan #32 | ~5.5k |
| research.md | 200 | 320 | documented-only | ~8k |
| deliberation.md | 200 | 350 | qa-spec #16 | ~9k |
| learnings.md | 30 | 50 | documented-only | ~1.5k |

<!-- Worked example: a plan.md with total 940 lines (under hard 1000, over soft 750) and a worst phase of 210 lines (under hard 220) → qa-plan #32 emits an advisory note on total, no must-fix. A plan.md total 1050 → must-fix with "split the piece or hoist detail to reference". -->

## 2. Derivation

- **Soft ceiling** = corpus p75 (rounded to a convenient line count)
- **Hard ceiling** = observed corpus max + ~10% headroom (rounded)
- **Token estimate** = chars ÷ 4 (advisory secondary metric; the `wc -l` line count is the primary, machine-checkable measure)

Corpus: 9 merged pieces from the exec-ready PRD — research-unify, plan-concrete, test-data-up, sonnet-coord, spike-agent, spec-preresearch, flywheel-repo, metrics, pipeline-e2e. These pieces provide the observed distribution from which p75 (soft) and observed-max (hard) are drawn.

## 3. Tiers and gates

Three tiers govern how a budget finding is handled:

1. **Over hard ceiling → must-fix.** The QA agent flags the artifact and the piece cannot advance until it passes. Resolution options: split the piece per the qa-prd ≤7-AC rule, or hoist supplementary detail to a dedicated reference doc (follow the pattern in `plugins/spec-flow/reference/`).
2. **Over soft, under hard → advisory only.** The QA agent emits a note but does not block. No round-trip is required.
3. **Budget unresolvable or absent** (class not in table, or `.spec-flow.yaml` override malformed) → skip the gate check. This is the NN-C-003 non-blocking escape hatch; the artifact is not flagged.

**Documented-only classes:** `research.md` and `learnings.md` budgets are recorded here for reference; no QA agent reviews them at the pipeline gate. Authors should self-enforce.

## 4. deliberation.md (forward-binding and grandfathered baseline)

**Zero on-disk samples** existed when these budgets were authored, so the thresholds are set analytically rather than from a measured corpus distribution.

- **Hard ceiling of 350 lines** is set generously, derived from the expected 7-section structure defined in `plugins/spec-flow/reference/deliberation-artifact.md` and by analogy with the research.md hard ceiling (320 lines).
- **Soft ceiling of 200 lines** mirrors research.md's soft ceiling as the closest structural analogue.
- This document **binds future deliberation.md producers** at the qa-spec #16 gate from the date of publication forward.
- The already-merged spec-preresearch plan (885 lines) is recorded as the **grandfathered baseline**. It predates this budget definition and is NOT retroactively flagged as a violation.
- **ADR-4 rationale:** closing the budget loop today avoids an open-ended "define later" gap. No re-bind obligation exists for artifacts merged before this document was committed.

## 5. Overrides

Projects may override per-class thresholds via `.spec-flow.yaml`:

```yaml
artifact_budgets:
  spec_md:
    soft: 400
    hard: 650
  plan_md_total:
    soft: 900
    hard: 1200
  plan_md_per_phase:
    soft: 120
    hard: 280
  research_md:
    soft: 250
    hard: 400
  deliberation_md:
    soft: 250
    hard: 400
  learnings_md:
    soft: 40
    hard: 70
```

Override keys: `spec_md`, `plan_md_total`, `plan_md_per_phase` (stored in metrics.yaml as `plan_md_max_phase` — the budget class name and the metrics field name differ by intent: the config key names the measurement scope, the metrics field records the actual measurement), `research_md`, `deliberation_md`, `learnings_md`. Each key supports `soft` and/or `hard` independently; omitted sub-keys fall back to the table defaults.

`Absent ⇒ table defaults (non-blocking; NN-C-003)` — a missing `artifact_budgets:` block or a missing per-class key never blocks the pipeline.

See `plugins/spec-flow/templates/pipeline-config.yaml` for example syntax and additional configuration options.

## 6. Irreducible overage

When an artifact exceeds the hard ceiling and cannot be reduced by condensing prose, the resolution path is the **qa-prd ≤7-AC piece-split rule**: decompose the piece into smaller pieces, each with at most 7 acceptance criteria, so that each artifact stays within budget.

There is no waiver. An artifact that cannot be reduced below the hard ceiling must be decomposed into smaller pieces. Inline waiver comment dialects (e.g., `<!-- budget-waived -->` or similar) are not accepted and will not suppress a must-fix finding.

## 7. No secrets

Budget records capture only line counts and token estimates. Artifact content is never transcribed into budget records, review findings, or metrics entries. If an artifact contains sensitive material, cite its path and line count only.
