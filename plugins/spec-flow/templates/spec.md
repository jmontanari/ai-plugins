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
# Spec: {{piece_name}}

**PRD Sections:** {{prd_sections}}
**Charter:** docs/charter/ (binding — see Non-Negotiables Honored / Coding Rules Honored below)
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

**Project (NN-C — from `docs/charter/non-negotiables.md`):**
- {{nn_c_id}} ({{short_name}}): {{how_this_piece_honors_it}}

**Product (NN-P — from `docs/prd/prd.md`):**
- {{nn_p_id}} ({{short_name}}): {{how_this_piece_honors_it}}

### Coding Rules Honored

Cite relevant `CR-xxx` entries from `docs/charter/coding-rules.md` whose scope this piece touches, with how each is honored.

- {{cr_id}} ({{short_name}}): {{how_this_piece_honors_it}}

## Acceptance Criteria
AC-1: Given {{precondition}}, When {{action}}, Then {{outcome}}
  Independent Test: {{how_to_verify_in_isolation}}

## Technical Approach
{{architecture_decisions_patterns_data_flow}}

## Testing Strategy
- Unit test focus areas
- Integration test boundaries
- Edge cases to cover

## Open Questions
- OQ-1: {{question}} (Default: {{assumed_answer}})
