---
# slug, status, version are required.
# slug: short id (≤20 chars, [a-z0-9-]); see plugins/spec-flow/reference/slug-validator.md
slug: {{prd_slug}}
status: drafting   # drafting | active | shipped | archived
version: 1
---

# Product Requirements Document

**Project:** {{project_name}}
**Date:** {{date}}
**Status:** draft
**Charter:** <charter_root>/skills/charter-*/SKILL.md (NN-C namespace — project-wide binding rules; applies to every piece)

## Problem Statement

> *What problem are we solving, for whom, and why now?*

**Current situation:** {{describe_current_state}}

**Problem:** {{describe_problem}}

**Who is affected:** {{primary_users_affected}}

**Why now:** {{why_this_is_the_right_time}}

## Goals

- {{goal_1}}

## Non-Goals

> *Explicitly document what this product will NOT do. Minimum one entry per 3 FRs.*

- {{non_goal_1}}

## Personas

> *One block per distinct user type. Minimum one persona required.*

### {{persona_name}}
- **Role:** {{role}}
- **Goals:** {{what_they_want_to_accomplish}}
- **Pain points:** {{what_frustrates_them_today}}
- **Behaviors:** {{how_they_currently_work}}

## Functional Requirements

> *Each FR must be falsifiable, user-anchored (≥1 user story below), and metric-linked.*
> *Flag any FR not yet meeting all three as `[NEEDS EXPANSION: <reason>]`.*

### FR-001: {{requirement_name}}
**Statement:** {{requirement}}
**Priority:** P0 / P1 / P2  *(P0 = must-ship MVP; P1 = should-ship; P2 = nice-to-have)*
**Linked metrics:** SC-001  *(or: "constraint — not directly measurable")*

#### User Stories

**US-001** — As a {{persona}}, I want {{capability}}, so that {{value}}.

**Acceptance Criteria:**
- [ ] {{criterion_1}}
- [ ] {{criterion_2}}

**Failure mode:** {{what_happens_when_it_fails}}

## Non-Functional Requirements

### NFR-001: {{requirement_name}}
**Statement:** {{requirement}}
**Priority:** P0 / P1 / P2
**Linked metrics:** SC-xxx *(or: "constraint")*

## Edge Cases & Failure Modes

> *At least one entry per major feature area.*

| Scenario | Expected behavior | FR reference |
|---|---|---|
| {{edge_case_description}} | {{how_system_should_respond}} | FR-xxx |

## Success Metrics

> *Each SC must be linked to at least one FR or NFR. Unlinked metrics are flagged `[NEEDS LINKAGE]`.*

- SC-001: {{metric}} — Target: {{target}} — Linked to: FR-xxx

## Priority Tiers

> *Summary view of FR/NFR priorities for MVP scoping decisions.*

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| FR-001 | {{name}} | P0 | {{why_must_ship}} |

## Assumptions

> *What are we taking as given? Tech, user behavior, market, regulatory.*

- **Technical:** {{assumption}}
- **User behavior:** {{assumption}}
- **Business/market:** {{assumption}}

## Open Questions

> *Things still to be decided or researched.*

| Question | Owner | Status |
|---|---|---|
| {{question}} | {{owner}} | open / resolved |

## Non-Negotiables (Product)

`NN-P-xxx` — product-specific binding rules. Tied to this PRD. For project-wide rules (security, compliance, architecture, tooling), see `<charter_root>/skills/charter-non-negotiables/SKILL.md` (`NN-C-xxx`).

### NN-P-001: {{name}}
- **Type:** Rule
- **Statement:** {{inline_rule_body}}
- **Scope:** {{where_it_applies}}
- **Rationale:** {{why_binding}}
- **How QA verifies:** {{verification_approach}}
