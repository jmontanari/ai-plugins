# Plan: {{piece_name}}

**Spec:** docs/specs/{{piece_name}}/spec.md
**Status:** draft

## Overview
{{implementation_approach_summary}}

## Phases

Each phase uses exactly ONE of two tracks:

- **TDD track** — phase contains `[TDD-Red]`. Use for behavior-bearing code that benefits from test-driven design.
- **Implement track** — phase contains `[Implement]` (and NO `[TDD-Red]`). Use for config, infrastructure, scaffolding, glue/wiring code, docs-as-code, fixtures, and migrations — anything where unit-level TDD would be ceremony without payoff. The `[Verify]` step on this track runs whatever command validates the work (lint, type check, build, smoke run, integration test) — the plan author picks.

A phase must have exactly one of these markers. The executor branches mechanically on the checkbox it finds.

### Phase 1 (TDD track example): {{phase_name}}
**Exit Gate:** {{exit_criteria}}
**ACs Covered:** {{ac_list}}

- [ ] **[TDD-Red]** Write failing tests
  - {{test_details}}

- [ ] **[Build]** Write minimal code to pass
  - Order bullets in checkpoint progression (types → constructors → public API → internals → error paths). The implementer commits at each logical checkpoint; good ordering gives it natural boundaries.
  - {{implementation_details}}

- [ ] **[Verify]** Confirm tests pass
  - Run: {{test_command}}
  - Expected: all tests pass, no warnings
  - Verify: no test files modified since TDD-Red step

- [ ] **[Refactor]** Clean up (scope: Phase 1 files only)
  - Check for: duplication, naming, extract helpers
  - Constraint: only modify files created/changed in this phase

- [ ] **[QA]** Phase review
  - Review against: {{ac_list}}
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 2 (Implement track example): {{phase_name}}
**Exit Gate:** {{exit_criteria}}
**ACs Covered:** {{ac_list}}

- [ ] **[Implement]** Write code per the plan
  - Order sub-items in checkpoint progression (schema/types → core wiring → wrappers/adapters → edge paths). The implementer commits at each logical checkpoint; good ordering gives it natural boundaries.
  - Files: {{file_paths_with_signatures_or_structure}}
  - Follow existing patterns: {{pattern_pointers}}
  - Architecture constraints this phase must honor: {{arch_constraints}}

- [ ] **[Verify]** Confirm the implementation is sound
  - Run: {{verification_command}}  (e.g. `ruff check .`, `tsc --noEmit`, `terraform validate`, `make build`, `pytest tests/integration/...`)
  - Expected: {{expected_output}}

- [ ] **[Refactor]** (optional — include only if cleanup is likely needed) Clean up (scope: Phase 2 files only)
  - Check for: duplication, naming, extract helpers
  - Constraint: only modify files created/changed in this phase

- [ ] **[QA]** Phase review
  - Review against: {{ac_list}}
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

## Parallel Execution Notes
{{parallel_notes}}

## Agent Context Summary
| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| TDD-Red | Phase requirements, test patterns, spec ACs | Implementation code, prior conversation |
| Implementer (Mode: TDD) | `Mode: TDD` flag, failing tests (verbatim), plan details, arch constraints, pattern pointers | Spec rationale, brainstorming history |
| Implementer (Mode: Implement) | `Mode: Implement` flag, plan [Implement] tasks, spec ACs, plan's [Verify] command, arch constraints, pattern pointers | Spec rationale, brainstorming history |
| Verify | Verification output (tests or plan-specified command), spec ACs | Implementation reasoning |
| Refactor | Current code (phase files only), mode's verification command, quality principles | Prior agent conversations |
| QA | Phase diff, spec, plan, PRD sections | Any agent conversation history |
