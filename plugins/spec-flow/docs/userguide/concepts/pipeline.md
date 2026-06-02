# The pipeline

spec-flow is a chain of five stages. Each stage takes an ambiguous artifact and produces a less ambiguous one. Each artifact is reviewed before the next stage runs.

```
intake → charter → prd → spec → plan → execute
```

`charter → prd → spec → plan → execute` are the five artifact-producing stages — each arrow is a sign-off gate where you approve the artifact before the next stage starts.

**`intake` is the pre-stage.** Every work session begins with `/spec-flow:intake` (it runs `status` internally). Intake classifies the incoming work, sets the correct working directory, loads charter constraints, and routes you to the right stage — resuming an in-progress piece, entering at spec/plan/execute, or branching to a lighter track. It produces no artifact of its own; it makes sure you start at the right place with the right context.

**`small-change` is an alternate lightweight track.** Small, single-session work that doesn't warrant a full PRD skips prd/spec/plan: `/spec-flow:small-change` runs a focused brainstorm, writes a change brief with an inline plan to `docs/changes/<slug>/`, and routes straight to `execute`. It rejoins the main pipeline at the execute stage, so the same TDD loop, QA gates, and review board still apply.

## Why five stages and not one

A PRD is ambiguous. That's fine — product requirements are *supposed* to describe intent, not implementation. But an AI agent fed a PRD and told "build this" will confidently close the ambiguity gap with whatever pattern it's seen most often in training. Sometimes that matches what you wanted; usually it doesn't.

Each stage in spec-flow exists to squeeze out a specific kind of ambiguity:

| Stage | Input | Output | Ambiguity resolved |
|---|---|---|---|
| **charter** | Your project's beliefs | Seven binding constraint skills | Architectural direction, coding conventions, non-negotiables |
| **prd** | Product intent | Enumerated requirements + piece breakdown | What exists, how it's prioritized, which work unit it belongs to |
| **spec** | One piece from the PRD | Acceptance criteria for that piece | What "done" means for this piece, concretely and testably |
| **plan** | An approved spec | Phase-by-phase file paths, signatures, test patterns | *How* the code will be shaped — class names, module layout, test structure |
| **execute** | An approved plan | Shipped code + green tests | Whether the plan actually produces correct behavior |

By the time `execute` runs, the implementer agent isn't designing anything. It's filling in signatures already specified, with test assertions already written, against architecture decisions already made. The only thing it resolves is: *does this implementation pass the oracle?*

## The artifacts

Each stage produces a concrete file you can read and sign off on. No artifact is AI-ephemeral — every one lives in `docs/` on disk and survives the session.

- **Charter** → `<charter_root>/skills/charter-{architecture,non-negotiables,tools,processes,flows,coding-rules,integrations}/SKILL.md`, where `<charter_root>` is `.github` or `.claude` (resolved per [reference/charter-location.md](../../../reference/charter-location.md)). Seven host-loadable skill files, hand-curated, shared across every PRD. Every downstream artifact inherits from them.
- **PRD + manifest** → `docs/prds/<prd-slug>/prd.md` + `docs/prds/<prd-slug>/manifest.yaml`. A project can have one or more PRDs — each gets its own slug and directory. The PRD captures intent; the manifest enumerates *pieces* — independently-shippable units of work — with status, dependencies, and pointers to their spec and plan once those exist.
- **Spec** → `docs/prds/<prd-slug>/specs/<piece-name>/spec.md`. Detailed requirements for one piece: acceptance criteria, functional requirements, non-negotiables cited by ID.
- **Plan** → `docs/prds/<prd-slug>/specs/<piece-name>/plan.md`. File-level implementation plan with Red/Build/Verify/Refactor phases, an AC Coverage Matrix, Contracts, and Change Specification Blocks, ordered by dependency.
- **Executed code** → committed to the piece branch `piece/<prd-slug>-<piece-name>`, merged to `master` only after the 7-agent final review board (8 in fast mode) clears the diff.

## Reviewers at every boundary

Every artifact passes through an adversarial reviewer before you see the sign-off prompt:

- **qa-charter** reviews charter authoring
- **qa-prd-review** reviews PRD completeness at end-of-pipeline
- **qa-spec** reviews each spec before plan authoring
- **qa-plan** reviews each plan before execute begins
- **qa-phase** reviews each executed phase before the next starts
- **review-board** (7 reviewers in parallel: blind, edge-case, spec-compliance, prd-alignment, architecture, security, ground-truth) reviews the cumulative merge diff before the piece lands. Fast mode adds an 8th member (`verify` Mode: Piece Full) to compensate for the skipped per-phase QA gates.

Reviewers have no context from the conversation that produced the artifact. They see only the artifact, the binding context (PRD, charter, spec), and the review criteria. This is deliberate — fresh context means the reviewer finds problems rather than confirming the hunches that shaped the artifact.

## Circuit breakers

Every QA loop has an iteration cap. If the artifact can't clear review after 3 iterations, the pipeline escalates to you. You decide whether to restructure, defer, or push through. The pipeline will not waste your compute looping on a doomed artifact.

Same pattern in `execute`: if a phase's tests won't turn green after 2 attempts, the implementer hits its retry cap and escalates.

## Stage dependencies

- **charter** is authored once per project (and rarely amended). When `charter.required: true` in `.spec-flow.yaml`, it's a prerequisite for `prd` — prd/spec/plan/execute fail fast if no charter is found.
- **prd** runs once per release cycle. It produces the manifest that `spec` pulls pieces from.
- **spec** runs per piece. Each piece's spec is independent except where the manifest declares `dependencies`.
- **plan** runs per piece. Depends on spec sign-off.
- **execute** runs per piece. Depends on plan sign-off.

`/spec-flow:intake` is the session entry point that orients you and routes to the right stage; it runs `/spec-flow:status` internally, the stateless query that tells you which pieces are in which stage and what's blocking progress.

## Where to go next

- [TDD loop](./tdd-loop.md) — the Red/Build/Verify/Refactor cycle executed inside each `execute` phase.
- [QA loop](./qa-loop.md) — the iterative fix-and-re-review cycle that runs at every boundary.
- [Charter system](./charter-system.md) — how the seven charter skills govern every downstream decision.
- [Project layout](./project-layout.md) — the full directory tree with concrete file examples.
- [Orchestrator model](./orchestrator-model.md) — why skills orchestrate and agents implement.
