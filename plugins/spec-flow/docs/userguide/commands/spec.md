# /spec-flow:spec

Author a detailed specification for one piece from the manifest. Runs a Socratic brainstorm, writes `docs/prds/<prd-slug>/specs/<piece-slug>/spec.md`, runs adversarial QA on it, and flips the piece's status to `specced`.

## What it does

Turns a piece entry in the manifest into a detailed spec with concrete **acceptance criteria** (testable, independently-verifiable assertions), functional requirements, and explicit citations of the charter entries the piece honors.

## When to run it

- **A piece is `open` in the manifest** and its dependencies are `merged`/`done` (or you triage the unmet ones).
- Called as `/spec-flow:spec <prd-slug>/<piece-slug>`, or without an argument to have the skill pick the next unblocked `open` piece.

## Prerequisites

- `docs/prds/<prd-slug>/manifest.yaml` exists (run `/spec-flow:prd` first).
- The piece's status is `open`.
- The pieces the target depends on are `merged`/`done` — otherwise the `depends_on:` triage (pull-deps-in / fork / proceed) fires.

## The flow

1. **Load context** — the skill reads the piece's manifest entry, the mapped PRD sections, the charter (v4: `<charter_root>/skills/charter-*/SKILL.md`, where `<charter_root>` is `.github` or `.claude`, resolved per [reference/charter-location.md](../../../reference/charter-location.md)), the PRD-local `backlog.md`, and learnings from prior completed pieces. It runs a **`depends_on:` precondition check**: if any dependency isn't `merged`/`done`, you triage — pull the dep's work into this piece, fork to spec the prerequisite first, or proceed `--ignore-deps`. (`superseded`/`blocked` deps refuse the proceed option.) On an amend/re-run it also runs a **charter-drift re-review** against the spec's `charter_snapshot:`.
2. **Brainstorm (Socratic)** — one question at a time, inference-first (lead with what's already known from the PRD and codebase; ask only what's genuinely unresolved). Structured passes:
   - **Convention scan** (L-10) — surface existing codebase conventions before asking.
   - **PRD assumption audit** (C-1) — probe dimensions the PRD doesn't mention (security/auth, data sensitivity, backward compat, rate limits, operational readiness); each unresolved gap becomes a required open question.
   - **Approach framing** (H-6) — propose 2–3 lightweight approaches and pick one as the design anchor; full trade-off analysis comes after design exploration.
   - **Mandatory security sub-block** (C-2) for any piece doing I/O, and an **NFR sub-block** (H-4) scaled to piece complexity.
   - Resolve every `[NEEDS CLARIFICATION]` marker before writing.
3. **Create worktree** — branch name is `piece/<prd-slug>-<piece-slug>`. If the manifest sets `feature_branch:`, the piece branch bases off it (and fails loudly if that branch is absent); otherwise it bases off the default branch. All subsequent work happens on this branch.
4. **Write the spec** at `docs/prds/<prd-slug>/specs/<piece-slug>/spec.md` using the spec template.
5. **qa-spec agent review** (Opus, adversarial):
   - Does the spec address every PRD section the manifest mapped to this piece?
   - Is every acceptance criterion testable, with no weasel words (vague unverifiable terms are flagged)?
   - Is every charter citation real (ID exists) and current (not retired)?
   - Are the "how this piece honors it" lines concrete, not vague?
   - Any surviving `[NEEDS CLARIFICATION]` or `[PENDING-DECISION]` markers? → must-fix.
6. **Fix loop** — fix-doc agent makes targeted fixes, qa-spec re-reviews the delta only. Up to 3 iterations; then escalate.
7. **You sign off.**
8. Manifest on the piece branch updated: status → `specced` (main advances on merge/PR).
9. Spec commits on the worktree branch.

When Jira integration is configured (`auto_create_tasks: true`), the piece-level issue is created at the start of brainstorm and its `jira_key:` / `jira_url:` recorded in spec.md front-matter.

## Marker lifecycle: `[NEEDS CLARIFICATION]` vs `[PENDING-DECISION]`

- `[NEEDS CLARIFICATION: <topic>]` — ambiguity that must be resolved *before* the spec is complete. qa-spec flags surviving markers as must-fix; none may reach the spec output.
- `[PENDING-DECISION: <area>]` — a deliberate deferral the user explicitly chooses not to resolve during brainstorm. These may carry into spec.md *only* with explicit confirmation, but qa-spec still flags them as must-fix at sign-off, and **they block the plan stage** — `/spec-flow:plan` refuses to proceed while any survive in spec.md. PRD-level `[PENDING-DECISION]` markers inherited from the mapped PRD section are surfaced here as open questions to resolve.

## Loops

- **Brainstorm loop** — iterates on questions until scope, approach, and acceptance criteria are resolved. No retry cap — you drive the pace.
- **QA loop** — qa-spec → fix-doc → qa-spec, up to 3 iterations, circuit breaker on iteration 4.

## What you get

A spec document at `docs/prds/<prd-slug>/specs/<piece-slug>/spec.md` with this shape:

```markdown
---
slug: <piece-slug>
prd: docs/prds/<prd-slug>/prd.md
status: specced
created: <date>
approved: <date>
branch: piece/<prd-slug>-<piece-slug>
charter_snapshot:
  non-negotiables: <date>
  architecture: <date>
  coding-rules: <date>
---

# Spec: <piece-slug>

**PRD Sections:** <list>
**Status:** draft
**Dependencies:** <list>

## Goal
<what this piece exists to accomplish, 1–2 paragraphs>

## In Scope
- <deliverable 1>
- <deliverable 2>

## Out of Scope
- <explicit non-goals>

## Acceptance Criteria
- **AC-1:** Given <precondition>, when <action>, then <assertion>
  - Independent test: <how to verify this AC in isolation>
- **AC-2:** ...

## Functional Requirements
- **FR-<piece>-001:** ...

## Non-Negotiables Honored
- **NN-C-001:** how this piece honors it — <concrete mechanism>
- **CR-006:** CHANGELOG follows Keep a Changelog format — this piece's CHANGELOG entry uses `## [vX.Y.Z]` + `### Added / Changed / Removed`

## Open Questions
<only if genuinely ambiguous; ideally empty after brainstorm>
```

And the manifest flips the piece's `status: open` → `status: specced`.

## Handoff

Next: `/spec-flow:plan` (inside the worktree) to generate the implementation plan.

## Worked example

Piece: `PI-104-data-export`. Mapped PRD sections: `G-2`, `FR-005`, `FR-006`, `FR-007`, `SC-002`. Dependencies: none.

The convention scan surfaces the project's existing export helpers; the PRD assumption audit probes auth and data sensitivity (the PRD said nothing about either). Approach framing offers three:
1. Server-side zip + download link
2. Streaming JSON over a long-lived connection
3. Chunked CSV with resume support

You anchor on option 1 as MVP and defer option 3 to a future piece. The mandatory security sub-block fixes the auth model (this piece does I/O); the NFR sub-block sets a best-effort latency posture. Brainstorm resolves 7 clarifications (what formats? what scopes? what auth?).

Spec is written with 9 acceptance criteria, 7 functional requirements, citations of NN-C-003 (auth tokens) and CR-011 (error response shape). qa-spec flags two weasel-worded honoring lines in iteration 1; fix-doc makes them concrete in iteration 2; iteration 2 clears. You sign off.

```
docs/prds/my-product/specs/PI-104-data-export/spec.md    (380 lines, status: draft → approved)
```

Manifest shows `PI-104-data-export: status: specced`. Worktree `worktrees/prd-my-product/piece-PI-104-data-export/` (branch `piece/my-product-PI-104-data-export`) is ready for `/spec-flow:plan`.

## Common brainstorm issues

- **Scope creep during brainstorm** — the manifest said one thing, you find yourself discussing three. The skill flags this and asks: amend the manifest, or narrow the scope?
- **Approach indecision** — you can't pick between two approaches. The skill will press for a decision rather than defer it; deferred architecture decisions leak into plan-time and execute-time as waste.
- **Surviving `[NEEDS CLARIFICATION]` or `[PENDING-DECISION]`** — qa-spec flags both as must-fix. `[PENDING-DECISION]` additionally blocks the plan stage, so resolve it before handing off.

## Where to go next

- [/spec-flow:plan](./plan.md) — turn this spec into a phase-by-phase plan.
- [QA loop concepts](../concepts/qa-loop.md) — how the review iterations work.
- [Charter system concepts](../concepts/charter-system.md) — how Non-Negotiables Honored gets verified.
