# The QA loop

Every spec-flow boundary runs an adversarial review. If the review finds problems, a fix agent makes targeted edits, and a fresh reviewer re-reviews the delta. The cycle caps at 3 iterations, then escalates. This page explains how that cycle works and why.

## The boundaries

Every artifact in the pipeline hits at least one QA gate:

| Boundary | Reviewer agent | Scope |
|---|---|---|
| Charter authoring | qa-charter | Six charter files, completeness, non-overlapping concerns |
| Spec authoring | qa-spec | PRD coverage, architecture alignment, AC testability, ambiguity |
| Plan authoring | qa-plan | Phase boundaries, TDD structure, semantic anchors, charter allocation |
| Phase execution | qa-phase (Opus) | Phase diff vs mapped ACs, regression risk, spec deviation |
| Sub-phase execution | qa-phase-lite (Sonnet) | Narrow spot-check for sub-phase boundaries inside Phase Groups |
| End-of-piece merge | review-board (5 agents in parallel) | Blind / edge-case / spec-compliance / prd-alignment / architecture |
| End-of-pipeline | qa-prd-review | Whole PRD fulfillment across all completed specs |

Every reviewer is spawned fresh — no conversation history, no prior-iteration context. They see only the artifact, the binding references (PRD, charter), and their review criteria. Fresh context is deliberate: it prevents the reviewer from rationalizing away problems they saw the author work through.

## The iteration cycle

```
┌──────────────┐      ┌──────────────┐     ┌──────────────┐
│ Reviewer N   │ ───▶ │ must-fix     │ ──▶ │ Fix agent    │
│ (Full mode)  │      │ findings     │     │              │
└──────────────┘      └──────────────┘     └──────────────┘
                                                   │
                                                   ▼
                                           ┌──────────────┐
                                           │ Diff of      │
                                           │ changes      │
                                           └──────────────┘
                                                   │
                                                   ▼
                                           ┌──────────────┐
                                           │ Reviewer N+1 │
                                           │ (Focused re- │
                                           │  review —    │
                                           │  delta only) │
                                           └──────────────┘
```

**Iteration 1** is "Full mode" — the reviewer sees the complete artifact.
**Iterations 2+** are "Focused re-review mode" — the reviewer sees only the fix agent's diff plus the prior iteration's must-fix findings. They verify each prior finding is resolved and scan the delta for regressions. They do NOT re-examine unchanged sections.

This saves context, keeps iterations fast, and prevents the reviewer from drifting into nice-to-have territory.

## The fix agents

Two fix agents exist, specialized for different artifacts:

- **fix-doc** — fixes spec.md, plan.md, charter files from must-fix findings. Outputs a unified diff; does NOT commit. The orchestrator stages and commits after QA passes.
- **fix-code** — fixes production code from must-fix findings (or Verify findings during execute). Same output contract: unified diff, orchestrator commits.

Both agents have one hard rule: **fix only what the findings identify**. No scope creep. No "while I'm here" cleanups. If a finding requires user input to resolve (genuine ambiguity, not a technical error), the fix agent reports BLOCKED and the orchestrator escalates.

## The circuit breaker

Every QA loop caps at **3 iterations**. If the artifact still has must-fix findings after iteration 3, the orchestrator escalates to you. You have three options:

1. **Push through** — accept the remaining findings as out-of-scope. Rare, but sometimes a finding is a future-piece opportunity dressed up as a current-piece blocker.
2. **Restructure** — the artifact has a structural problem the fix agent can't resolve. You author a different spec / plan / implementation and retry.
3. **Defer the piece** — park this piece, work on something else. Useful when the piece turns out to depend on infrastructure you haven't built yet.

The circuit breaker exists because AI agents will *cheerfully loop on the same failure forever*. Without the cap, a stubborn finding can burn hours of compute producing no progress. Three iterations is enough to confirm the pipeline can't solve it alone; more is wasteful.

## The end-of-piece review board

At merge time, spec-flow runs a different kind of QA — five reviewers **in parallel**, each with a specialized lens:

| Reviewer | Sees | Asks |
|---|---|---|
| **blind** | Just the diff | Does this code do what it appears to claim? Bugs? Dead references? |
| **edge-case** | Diff + spec + learnings | What breaks at boundaries? Stale caches, version floors, failure modes? |
| **spec-compliance** | Diff + spec + plan | Does the diff honor every acceptance criterion? |
| **prd-alignment** | Diff + PRD + charter | Does this advance PRD goals and honor non-negotiables? |
| **architecture** | Diff + charter + coding rules | Layer boundaries respected? CR-xxx rules obeyed? |

Parallel dispatch means all five return in roughly the time of the slowest — about one Opus round-trip. Catches problems that a single reviewer would rationalize away because each lens has a different priority.

Must-fix findings from the board are resolved the same way as any other QA boundary: fix-doc or fix-code makes targeted fixes, the affected reviewers re-review, up to 3 iterations.

## The focused-re-review discipline

A subtle but important property: **iteration N+1 reviewers do not re-read what iteration N already reviewed.** They see:

- The prior must-fix findings (so they know what was supposed to be fixed)
- The fix agent's diff (the unified diff of what actually changed)

And nothing else. If the delta resolves each prior finding *and* introduces no regressions in the touched sections, the artifact passes. Unchanged sections are not re-examined — iteration 1 already covered them.

This keeps iterations cheap and prevents review drift ("while we're re-reading, let me flag this thing I missed last time"). Reviewers that drift past their focused scope are easy to spot — they waste context and produce findings that weren't there before.

## Where to go next

- [TDD loop](./tdd-loop.md) — the Red/Build/Verify/Refactor cycle that runs inside each phase.
- [Charter system](./charter-system.md) — how NN-C / NN-P / CR entries get cited and verified at every review.
- [commands/execute.md](../commands/execute.md) — where the majority of QA iterations happen.
