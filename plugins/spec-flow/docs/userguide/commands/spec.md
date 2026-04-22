# /spec-flow:spec

Author a detailed specification for one piece from the manifest. Runs a Socratic brainstorm, writes `docs/specs/<piece-name>/spec.md`, runs adversarial QA on it, and flips the piece's status to `specced`.

## What it does

Turns a piece entry in the manifest into a detailed spec with concrete **acceptance criteria** (testable, independently-verifiable assertions), functional requirements, and explicit citations of the charter entries the piece honors.

## When to run it

- **A piece is `open` in the manifest** and has all its dependencies `done`.
- Called as `/spec-flow:spec <piece-name>`, or without an argument to have the skill pick the next unblocked `open` piece.

## Prerequisites

- `docs/prd/manifest.yaml` exists (run `/spec-flow:prd` first).
- The piece's status is `open`.
- All pieces the target piece depends on are `done`.

## The flow

1. **Load context** — the skill reads the piece's manifest entry, the mapped PRD sections, the charter (or legacy architecture docs if charter is absent), and any learnings from prior completed pieces.
2. **Brainstorm (Socratic)** — one question at a time:
   - Confirm the piece's scope matches what the manifest said.
   - Propose 2–3 approaches with trade-offs and a recommendation.
   - Resolve every `[NEEDS CLARIFICATION]` marker before writing.
3. **Create worktree** — `git worktree add worktrees/<piece-name> -b spec/<piece-name>`. All subsequent work happens on this branch.
4. **Write the spec** at `docs/specs/<piece-name>/spec.md` using the spec template.
5. **qa-spec agent review** (Opus, adversarial):
   - Does the spec address every PRD section the manifest mapped to this piece?
   - Is every acceptance criterion testable?
   - Is every charter citation real (ID exists) and current (not retired)?
   - Are the "how this piece honors it" lines concrete, not vague?
   - Any surviving `[NEEDS CLARIFICATION]` markers? → must-fix.
6. **Fix loop** — fix-doc agent makes targeted fixes, qa-spec re-reviews the delta only. Up to 3 iterations; then escalate.
7. **You sign off.**
8. Manifest on `master` updated: piece status → `specced`.
9. Spec commits on the worktree branch.

## Loops

- **Brainstorm loop** — iterates on questions until scope, approach, and acceptance criteria are resolved. No retry cap — you drive the pace.
- **QA loop** — qa-spec → fix-doc → qa-spec, up to 3 iterations, circuit breaker on iteration 4.

## What you get

A spec document at `docs/specs/<piece-name>/spec.md` with this shape:

```markdown
# Spec: <piece-name>

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

Brainstorm surfaces three approaches:
1. Server-side zip + download link
2. Streaming JSON over a long-lived connection
3. Chunked CSV with resume support

You pick option 1 as MVP, defer option 3 to a future piece. Brainstorm resolves 7 clarifications (what formats? what scopes? what auth?).

Spec is written with 9 acceptance criteria, 7 functional requirements, citations of NN-C-003 (auth tokens) and CR-011 (error response shape). qa-spec flags two vague honoring lines in iteration 1; fix-doc makes them concrete in iteration 2; iteration 2 clears. You sign off.

```
docs/specs/PI-104-data-export/spec.md    (380 lines, status: draft → approved)
```

Manifest shows `PI-104-data-export: status: specced`. Worktree `worktrees/PI-104-data-export/` is ready for `/spec-flow:plan`.

## Common brainstorm issues

- **Scope creep during brainstorm** — the manifest said one thing, you find yourself discussing three. The skill flags this and asks: amend the manifest, or narrow the scope?
- **Approach indecision** — you can't pick between two approaches. The skill will press for a decision rather than defer it; deferred architecture decisions leak into plan-time and execute-time as waste.
- **Surviving `[NEEDS CLARIFICATION]`** — qa-spec will flag any of these as must-fix. They're the skill's signal that brainstorming didn't resolve everything.

## Where to go next

- [/spec-flow:plan](./plan.md) — turn this spec into a phase-by-phase plan.
- [QA loop concepts](../concepts/qa-loop.md) — how the review iterations work.
- [Charter system concepts](../concepts/charter-system.md) — how Non-Negotiables Honored gets verified.
