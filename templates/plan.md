# Plan: {{piece_name}}

**Spec:** docs/specs/{{piece_name}}/spec.md
**Status:** draft

## Overview
{{implementation_approach_summary}}

## Phases

### Phase 1: {{phase_name}}
**Exit Gate:** {{exit_criteria}}
**ACs Covered:** {{ac_list}}

- [ ] **[TDD-Red]** Write failing tests
  - {{test_details}}

- [ ] **[Build]** Write minimal code to pass
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

## Parallel Execution Notes
{{parallel_notes}}

## Agent Context Summary
| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| TDD-Red | Phase requirements, test patterns, spec ACs | Implementation code, prior conversation |
| Builder | Failing tests (verbatim output), plan details, arch constraints | Spec rationale, brainstorming history |
| Verify | Test output, spec ACs | Implementation reasoning |
| Refactor | Current code (phase files only), test suite, quality principles | Prior agent conversations |
| QA | Phase diff, spec, plan, PRD sections | Any agent conversation history |
