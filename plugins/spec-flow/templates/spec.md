---
charter_snapshot:
  architecture: {{date}}
  non-negotiables: {{date}}
  tools: {{date}}
  processes: {{date}}
  flows: {{date}}
  coding-rules: {{date}}
  integrations: {{date}}
piece_class: {{behavior-bearing|non-behavioral}}
behavior_rationale: {{required only when non-behavioral}}
integration_rationale: {{required only when behavior-bearing AND the piece declares it touches no integration boundary — see reference/behavior-classification.md}}
---

<!-- {{piece_slug}} optional — defaults to kebab-cased {{piece_name}} -->
# Spec: {{piece_name}}

**PRD Sections:** {{prd_sections}}
**Charter:** <charter_root>/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** {{dependencies}}

## Goal
{{goal}}

## In Scope
- {{deliverable_1}}

## Out of Scope / Non-Goals
- {{exclusion_1}}

## Requirements

### Functional Requirements
- {{fr_id}}: {{requirement}}

### Non-Functional Requirements
- {{nfr_id}}: {{requirement}}

### Non-Negotiables Honored

Enumerate every charter (`NN-C-xxx`) and product (`NN-P-xxx`) non-negotiable whose scope this piece touches, with a per-entry line on how the piece honors it.

**Project (NN-C — from `<charter_root>/skills/charter-non-negotiables/SKILL.md`):**
- {{nn_c_id}} ({{short_name}}): {{how_this_piece_honors_it}}

**Product (NN-P — from `docs/prds/<prd-slug>/prd.md`):**
- {{nn_p_id}} ({{short_name}}): {{how_this_piece_honors_it}}

### Coding Rules Honored

Cite relevant `CR-xxx` entries from `<charter_root>/skills/charter-coding-rules/SKILL.md` whose scope this piece touches, with how each is honored.

- {{cr_id}} ({{short_name}}): {{how_this_piece_honors_it}}

## Acceptance Criteria
AC-1: Given {{precondition}}, When {{action}}, Then {{outcome}} [mechanism]
  Independent Test [machine: <named check — a grep/script/test that decides>]: <how to verify>
  <!-- Alternative form: Independent Test [judgment: <named arbiter — who decides>]: <what they inspect> -->
<!-- AC-line tag (exactly one): [mechanism] | [outcome:result] | [outcome:integration].
     Per-facet N/A sentinel form: `Outcome N/A [outcome:<facet>]: <reason>`.
     A declared integration's allocated AC carries a production-call-site pointer on its
     Independent Test sub-line: `Independent Test [machine: prod-callsite=<production-rooted path>; <check>]: …`
     (path NOT under a test root). See plugins/spec-flow/reference/spec-flow-doctrine.md.
     Tokens defined in plugins/spec-flow/reference/behavior-classification.md (CR-005). -->

## Technical Approach
{{architecture_decisions_patterns_data_flow}}

## Testing Strategy
- Unit test focus areas
- Integration test boundaries
- Edge cases to cover

## Integration Coverage
- Integration: {{A}}→{{B}} — inside:{{components}}; doubled externals:{{ext}}(contract-tested); AC-{{id}}; completes phase {{N}}
- (A piece with no cross-component wiring writes "None in scope.")

## Open Questions
- OQ-1: {{question}} (Default: {{assumed_answer}})
