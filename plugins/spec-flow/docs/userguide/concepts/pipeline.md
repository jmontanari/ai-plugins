# The pipeline

spec-flow is a chain of five stages. Each stage takes an ambiguous artifact and produces a less ambiguous one. Each artifact is reviewed before the next stage runs.

```
charter → prd → spec → plan → execute
```

Each arrow is a sign-off gate — you approve the artifact before the next stage starts.

## Why five stages and not one

A PRD is ambiguous. That's fine — product requirements are *supposed* to describe intent, not implementation. But an AI agent fed a PRD and told "build this" will confidently close the ambiguity gap with whatever pattern it's seen most often in training. Sometimes that matches what you wanted; usually it doesn't.

Each stage in spec-flow exists to squeeze out a specific kind of ambiguity:

| Stage | Input | Output | Ambiguity resolved |
|---|---|---|---|
| **charter** | Your project's beliefs | Six binding constraint files | Architectural direction, coding conventions, non-negotiables |
| **prd** | Product intent | Enumerated requirements + piece breakdown | What exists, how it's prioritized, which work unit it belongs to |
| **spec** | One piece from the PRD | Acceptance criteria for that piece | What "done" means for this piece, concretely and testably |
| **plan** | An approved spec | Phase-by-phase file paths, signatures, test patterns | *How* the code will be shaped — class names, module layout, test structure |
| **execute** | An approved plan | Shipped code + green tests | Whether the plan actually produces correct behavior |

By the time `execute` runs, the implementer agent isn't designing anything. It's filling in signatures already specified, with test assertions already written, against architecture decisions already made. The only thing it resolves is: *does this implementation pass the oracle?*

## The artifacts

Each stage produces a concrete file you can read and sign off on. No artifact is AI-ephemeral — every one lives in `docs/` on disk and survives the session.

- **Charter** → `docs/charter/{architecture,non-negotiables,tools,processes,flows,coding-rules}.md`. Six files, hand-curated, shared across every PRD. Every downstream artifact inherits from them.
- **PRD + manifest** → `docs/prds/<prd-slug>/prd.md` + `docs/prds/<prd-slug>/manifest.yaml`. A project can have one or more PRDs — each gets its own slug and directory. The PRD captures intent; the manifest enumerates *pieces* — independently-shippable units of work — with status, dependencies, and pointers to their spec and plan once those exist.
- **Spec** → `docs/prds/<prd-slug>/specs/<piece-name>/spec.md`. Detailed requirements for one piece: acceptance criteria, functional requirements, non-negotiables cited by ID.
- **Plan** → `docs/prds/<prd-slug>/specs/<piece-name>/plan.md`. File-level implementation plan with Red/Build/Verify/Refactor phases, ordered by dependency.
- **Executed code** → committed to a worktree branch `spec/<prd-slug>-<piece-name>`, merged to `master` only after the 5-agent final review board clears the diff.

## Reviewers at every boundary

Every artifact passes through an adversarial reviewer before you see the sign-off prompt:

- **qa-charter** reviews charter authoring
- **qa-prd-review** reviews PRD completeness at end-of-pipeline
- **qa-spec** reviews each spec before plan authoring
- **qa-plan** reviews each plan before execute begins
- **qa-phase** reviews each executed phase before the next starts
- **review-board** (5 reviewers in parallel: blind, edge-case, spec-compliance, prd-alignment, architecture) reviews the cumulative merge diff before the piece lands

Reviewers have no context from the conversation that produced the artifact. They see only the artifact, the binding context (PRD, charter, spec), and the review criteria. This is deliberate — fresh context means the reviewer finds problems rather than confirming the hunches that shaped the artifact.

## Circuit breakers

Every QA loop has an iteration cap. If the artifact can't clear review after 3 iterations, the pipeline escalates to you. You decide whether to restructure, defer, or push through. The pipeline will not waste your compute looping on a doomed artifact.

Same pattern in `execute`: if a phase's tests won't turn green after 2 attempts, the implementer hits its retry cap and escalates.

## Stage dependencies

- **charter** is authored once per project (and rarely amended). It's a prerequisite for `prd` in v2.0.0+ projects.
- **prd** runs once per release cycle. It produces the manifest that `spec` pulls pieces from.
- **spec** runs per piece. Each piece's spec is independent except where the manifest declares `dependencies`.
- **plan** runs per piece. Depends on spec sign-off.
- **execute** runs per piece. Depends on plan sign-off.

`/spec-flow:status` is the stateless query that tells you which pieces are in which stage and what's blocking progress.

## Where to go next

- [TDD loop](./tdd-loop.md) — the Red/Build/Verify/Refactor cycle executed inside each `execute` phase.
- [QA loop](./qa-loop.md) — the iterative fix-and-re-review cycle that runs at every boundary.
- [Charter system](./charter-system.md) — how the six charter files govern every downstream decision.
- [Project layout](./project-layout.md) — the full directory tree with concrete file examples.
- [Orchestrator model](./orchestrator-model.md) — why skills orchestrate and agents implement.
