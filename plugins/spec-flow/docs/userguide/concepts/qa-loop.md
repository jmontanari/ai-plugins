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
| End-of-piece merge | review-board (7 agents in parallel) | Blind / edge-case / spec-compliance / prd-alignment / architecture / security / ground-truth |
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

Four fix agents exist, specialized for different kinds of finding:

- **fix-doc** — fixes spec.md, plan.md, charter files from must-fix findings. Outputs a unified diff; does NOT commit. The orchestrator stages and commits after QA passes.
- **fix-code** — fixes production code from must-fix findings (or Verify findings during execute). Same output contract: unified diff, orchestrator commits.
- **plan-amend** — used when a finding requires a *structural* plan change (a new phase, a re-scoped phase, a corrected contract) rather than a patch. Re-runs qa-plan after the amend.
- **spec-amend** — used when a finding reveals a missing FR/AC or a contradiction in the spec itself. Re-runs qa-spec after the amend.

All four have one hard rule: **fix only what the findings identify**. No scope creep. No "while I'm here" cleanups. If a finding requires user input to resolve (genuine ambiguity, not a technical error), the fix agent reports BLOCKED and the orchestrator escalates.

### When a finding needs a spec/plan change, not a code patch

Some execute-time findings can't be resolved by editing code or docs at the same altitude — they reveal that the *plan* or *spec* is wrong. Execute routes these through **Step 6c discovery triage**: the operator picks a resolution per finding —

- **amend** — dispatch `plan-amend` (or `spec-amend`) to correct the plan/spec in place, then re-QA.
- **fork** — split the work into a new piece rather than expanding the current one.
- **defer** — record it via `/spec-flow:defer` to the backlog as future work.

Amendments are budgeted: **5 amendments total per piece, of which at most 1 may be a spec amendment.** When the budget is exhausted the orchestrator refuses further amends and escalates (fork or block the piece). This keeps a piece from silently growing without an operator deciding it should.

## The circuit breaker

Every QA loop caps at **3 iterations**. If the artifact still has must-fix findings after iteration 3, the orchestrator escalates to you. You have three options:

1. **Push through** — accept the remaining findings as out-of-scope. Rare, but sometimes a finding is a future-piece opportunity dressed up as a current-piece blocker.
2. **Restructure** — the artifact has a structural problem the fix agent can't resolve. You author a different spec / plan / implementation and retry.
3. **Defer the piece** — park this piece, work on something else. Useful when the piece turns out to depend on infrastructure you haven't built yet.

The circuit breaker exists because AI agents will *cheerfully loop on the same failure forever*. Without the cap, a stubborn finding can burn hours of compute producing no progress. Three iterations is enough to confirm the pipeline can't solve it alone; more is wasteful.

## The end-of-piece review board

At merge time, spec-flow runs a different kind of QA — seven reviewers **in parallel**, each with a specialized lens:

| Reviewer | Sees | Asks |
|---|---|---|
| **blind** | Just the diff | Does this code do what it appears to claim? Bugs? Dead references? |
| **edge-case** | Diff + spec + learnings | What breaks at boundaries? Stale caches, version floors, failure modes? |
| **spec-compliance** | Diff + spec + plan | Does the diff honor every acceptance criterion? |
| **prd-alignment** | Diff + PRD + charter | Does this advance PRD goals and honor non-negotiables? |
| **architecture** | Diff + charter + coding rules | Layer boundaries respected? CR-xxx rules obeyed? |
| **security** | Diff + spec | CWE Top 25 covered? Injection, crypto, auth/authz, supply chain, language anti-patterns? |
| **ground-truth** | Diff + spec | Do computed/measured outputs reproduce an *independently-derived* correct answer — not just match the plan or a self-captured golden file? Degenerate results, lookahead leakage, scope contamination, parity mismatch, silent truncation? |

Parallel dispatch means all seven return in roughly the time of the slowest — about one Opus round-trip. Catches problems that a single reviewer would rationalize away because each lens has a different priority.

**Fast mode** trades per-phase rigor for speed: when the plan declares `fast: true`, execute skips the per-phase inline QA gates (`qa-tdd-red`, `qa-phase`, `qa-phase-lite`) and runs the phase test command directly instead of dispatching `verify`. To compensate for the skipped gates, the end-of-piece board gains an **8th member — `verify` Mode: Piece Full** — which runs the full verification pass over the whole piece at merge time. So standard mode = 7 board members; fast mode = 8.

Must-fix findings from the board are resolved the same way as any other QA boundary: fix-doc or fix-code makes targeted fixes (or plan-amend/spec-amend via Step 6c when the finding is structural), the affected reviewers re-review, up to 3 iterations.

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
