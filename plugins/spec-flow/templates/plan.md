---
charter_snapshot:
  architecture: {{date}}
  non-negotiables: {{date}}
  tools: {{date}}
  processes: {{date}}
  flows: {{date}}
  coding-rules: {{date}}
---

<!-- {{piece_slug}} optional — defaults to kebab-cased {{piece_name}} -->
# Plan: {{piece_name}}

**Spec:** docs/prds/{{prd_slug}}/specs/{{piece_slug}}/spec.md
**Charter:** docs/charter/ (binding — each phase enumerates its honored NN-C/NN-P/CR entries)
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
**Charter constraints honored in this phase:**
- {{nn_c_id_or_cr_id}} ({{short_name}}): {{how_this_phase_honors_it}}

- [ ] **[TDD-Red]** Write failing tests
  - {{test_details}}

- [ ] **[QA-Red]** Reject theater tests before Build
  - Review Red's authored tests against the theater-pattern catalog (tautology, mock-echo, truthy-only, no-assertion, name/body mismatch, implementation coupling, etc.)
  - Verify each test adversarially binds to its claimed AC ({{ac_list}})
  - On FAIL: one Red retry with findings surfaced, then escalate

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
**Charter constraints honored in this phase:**
- {{nn_c_id_or_cr_id}} ({{short_name}}): {{how_this_phase_honors_it}}

- [ ] **[Implement]** Write code per the plan
  - Order sub-items in checkpoint progression (schema/types → core wiring → wrappers/adapters → edge paths). The implementer commits at each logical checkpoint; good ordering gives it natural boundaries.
  - Files: {{file_paths_with_signatures_or_structure}}
  - Follow existing patterns: {{pattern_pointers}}
  - Architecture constraints this phase must honor: {{arch_constraints}}

- [ ] **[Verify]** Confirm the implementation is sound
  - Run: {{verification_command}}  (e.g. `ruff check .`, `tsc --noEmit`, `terraform validate`, `make build`, `pytest tests/integration/...`) — For YAML/JSON validation: use LLM-agent-step framing (e.g., "Read the file at <path> and confirm it parses as valid YAML/JSON; report any error inline") rather than yq/jq/language-specific runtime shell-outs. For other validations (lint, type check, build, smoke run): standard shell commands are fine.
  - Expected: {{expected_output}}

- [ ] **[Refactor]** (optional — include only if cleanup is likely needed) Clean up (scope: Phase 2 files only)
  - Check for: duplication, naming, extract helpers
  - Constraint: only modify files created/changed in this phase

- [ ] **[QA]** Phase review
  - Review against: {{ac_list}}
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

## Phase Group A (example): {{group_name}}
**Exit Gate:** all sub-phases pass their oracles + group Deep QA clean
**ACs Covered:** {{group_ac_list}}

#### Sub-Phase A.1 [P]: {{sub_phase_name}}
**Scope:** {{literal_file_paths_comma_separated}}
**ACs:** {{sub_phase_ac_subset}}

- [ ] **[TDD-Red]** Write failing tests for this sub-phase
  - {{test_details}}

- [ ] **[QA-Red]** Reject theater tests before Build
  - Review Red's authored tests against the theater-pattern catalog
  - Verify adversarial binding to this sub-phase's ACs ({{sub_phase_ac_subset}})
  - On FAIL: one Red retry with findings surfaced, then escalate

- [ ] **[Build]** Implement this sub-phase
  - Order bullets in checkpoint progression (types → constructors → public API → internals → error paths). The implementer commits at each logical checkpoint; good ordering gives it natural boundaries.
  - {{implementation_details}}

- [ ] **[Verify]** Confirm tests pass
  - Run: {{test_command}}
  - Expected: all tests for this sub-phase pass
  - Verify: no test files modified since [TDD-Red] step

- [ ] **[QA-lite]** Sonnet narrow review
  - Scope: this sub-phase only
  - Review: plan alignment, AC matrix spot-check, structural sanity, scope discipline

#### Sub-Phase A.2 [P]: {{sub_phase_name}}
**Scope:** {{literal_file_paths_comma_separated}}
... (same shape as A.1)

#### Group-level tasks
- [ ] **[Refactor]** (optional — auto-skipped when all Builds clean)
  - Scope: union of all sub-phase files in this group
  - Check for: cross-sub-phase dedup opportunities, inconsistent naming
  - Constraint: only modify files created/changed in this group

- [ ] **[QA]** Opus deep review
  - Review against: group ACs (union)
  - Diff baseline: git diff {{group_start_tag}}..HEAD
  - Surface map composed by orchestrator (Files changed, Public symbols, Integration callers)

- [ ] **[Progress]** Single commit for the group

## Parallel Execution Notes
{{parallel_notes}}

## Agent Context Summary
| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| TDD-Red | Phase requirements, test patterns, spec ACs | Implementation code, prior conversation. **Stages** tests (does NOT commit — v2.7.0+); the implementer's unified commit captures Red's staged tests + Build's production code together. |
| QA-TDD-Red | Red's `## Tests Written` list, authored test source (read from staging area / working tree), phase's [TDD-Red] block, phase ACs, Red's oracle block | Production source, prior phases' tests, brainstorming history |
| Implementer (Mode: TDD) | `Mode: TDD` flag, failing tests (verbatim), Red's `## Staged test manifest` (paths + SHA-256), plan details, arch constraints, pattern pointers. Working tree starts with Red's tests already staged. | Spec rationale, brainstorming history. **Creates ONE unified commit** containing Red's staged tests + Build's production code; orchestrator verifies integrity via SHA-256 re-hash and file-list reconciliation post-commit. |
| Implementer (Mode: Implement) | `Mode: Implement` flag, plan [Implement] tasks, spec ACs, plan's [Verify] command, arch constraints, pattern pointers | Spec rationale, brainstorming history |
| Verify | Verification output (tests or plan-specified command), spec ACs | Implementation reasoning |
| QA-lite (sub-phase) | `Mode:` flag, sub-phase diff, sub-phase ACs, AC matrix (from Build), sub-phase scope block | Full piece spec, PRD sections, other sub-phases' diffs |
| Refactor | Current code (phase files only), mode's verification command, quality principles | Prior agent conversations |
| QA | Phase diff, spec, plan, PRD sections | Any agent conversation history |
