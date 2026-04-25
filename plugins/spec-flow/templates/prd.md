---
# slug, status, version are required.
# slug: short id (≤10 chars, [a-z0-9-]); see plugins/spec-flow/reference/slug-validator.md
slug: {{prd_slug}}
status: drafting   # drafting | active | shipped | archived
version: 1
---

# Product Requirements Document

**Project:** {{project_name}}
**Date:** {{date}}
**Status:** draft
**Charter:** docs/charter/ (NN-C namespace — project-wide binding rules; applies to every piece)

## Goals
- {{goal_1}}

## Non-Goals
- {{non_goal_1}}

## Functional Requirements
- FR-001: {{requirement}}

## Non-Functional Requirements
- NFR-001: {{requirement}}

## Success Metrics
- SC-001: {{metric}} — Target: {{target}}

## Non-Negotiables (Product)

`NN-P-xxx` — product-specific binding rules. Tied to this PRD. For project-wide rules (security, compliance, architecture, tooling), see `docs/charter/non-negotiables.md` (`NN-C-xxx`).

### NN-P-001: {{name}}
- **Type:** Rule
- **Statement:** {{inline_rule_body}}
- **Scope:** {{where_it_applies}}
- **Rationale:** {{why_binding}}
- **How QA verifies:** {{verification_approach}}
