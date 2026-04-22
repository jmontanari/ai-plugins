# The orchestrator model

spec-flow's design separates two distinct roles: the **orchestrator** (a skill) and the **executor** (an agent). Skills orchestrate — they read plans, construct prompts, dispatch agents, run verification commands, and decide what happens next. Agents execute — they write code, author artifacts, run reviews.

This page explains why the separation exists and how it shapes the pipeline.

## Skills vs. agents — the division of labor

| | Skill (the orchestrator) | Agent (the executor) |
|---|---|---|
| Context | Full session history, brainstorming, prior iterations, review findings | Only what the orchestrator injects |
| Purpose | Decide what happens next | Do exactly one thing well |
| Writes code | **Never** | Always (when that's the agent's job) |
| Writes reviews | **Never** | Always (when that's the agent's job) |
| Dispatched by | You | The orchestrator, via the Agent tool |

Every spec-flow command is a *skill*. Skills never write implementation code. They dispatch agents to do the writing. This isn't a suggestion — it's a structural rule enforced by the shape of the code.

## Why the orchestrator writes no code

Main-window context grows with every brainstorm answer, every sign-off prompt, every prior-iteration finding, every review transcript. By the time a skill has authored three artifacts and reviewed them twice, its context holds dozens of partial decisions, revised opinions, and abandoned approaches.

If that same context wrote the code, the code would inherit all of it — not deliberately, but by accident. The implementation would be biased toward the first approach tried, the rejected alternatives would leak in as conditional branches, the dead discussion would influence naming and structure.

Keeping the orchestrator out of the code path means the main-window's context never participates in writing code. The implementer agent gets exactly what the plan says to build, plus a pre-flight snapshot, plus an oracle of done. Nothing more. It makes decisions the plan already made.

## Why agents are context-isolated

Agents are spawned with *exactly the context they need*. The implementer sees the plan's `[Build]` block, the failing test output, and pre-flight facts. It does not see:

- The brainstorm that produced the spec
- The spec's rationale
- Prior agents' reports
- The user's earlier clarifications
- What other agents are running in parallel

This is deliberate. An agent with too much context starts hedging — "this test looks wrong but maybe the user meant..." becomes "let me make it pass both ways just in case." Focused context produces focused code.

## The Agent tool — the dispatch boundary

Skills dispatch agents via Claude Code's (or Copilot CLI's) Agent tool. The tool spawns a subagent with a fresh context, runs it to completion, and returns the result as a single tool-call response. The skill sees only that result — not the agent's internal tool calls, intermediate thoughts, or scratchpad.

This is the API boundary. The skill composes a prompt with exactly what the agent needs, dispatches, and reads back the report. The agent's internals are opaque by design.

## Why internal agents block on direct invocation

Several spec-flow agents (implementer, tdd-red, verify, refactor, qa-phase, fix-code, reflection-process-retro, reflection-future-opportunities) have a **first-turn entrypoint check** that rejects the dispatch if orchestrator-injected context is missing. If you invoke `implementer` directly (without the execute skill) it will respond:

> BLOCKED — entrypoint violation. This agent is dispatched internally by `spec-flow:execute`. Calling it directly bypasses context-injection invariants (Mode flag, pre-flight snapshot, oracle anchors, matrix validation). Re-run through `spec-flow:execute` with a valid plan.

The guard prevents a class of contamination bug where an agent runs with broken invariants: no mode flag, no oracle, no pre-flight data. The agent's rules assume those invariants; without them, its behavior is undefined.

This guard runs identically on Claude Code and Copilot CLI — both hosts respect the Rule 0 check because it's in the agent prompt itself, not enforced by the harness.

## The pre-flight snapshot — collapsing discovery work

When execute is about to dispatch an agent, it first runs a pre-flight pass — cheap reads that the agent would otherwise have to discover:

- **LOC snapshot** — `wc -l` on each phase-scoped file.
- **Schema shape** — `head -20` of one existing sibling file if the phase writes a config family.
- **Symbol presence** — `git grep` for each type/class/function the plan names.
- **Pre-commit hook inventory** — reads `.pre-commit-config.yaml` and flags any test-running hooks.

The results are spliced into the agent's prompt as a `## Pre-flight snapshot` block. The agent starts with the facts it would have discovered in its first 5–15 tool calls, saving that round-trip budget for actual work.

This is explicitly part of the orchestrator's job. *Synthesis* and *code-writing* come from agents; *cheap factual reads* come from the orchestrator.

## Orchestrator pre-decisions — resolving plan conditionals

Plans sometimes contain conditionals: *"extract to helper if the function exceeds 200 LOC"*, *"if utils.py exists, reuse; otherwise create helpers.py"*. The orchestrator resolves these conditionals using pre-flight data before dispatching the agent. The resolved choices become bullets in a `## Orchestrator pre-decisions` block attached to the prompt.

The implementer agent treats pre-decisions as binding — it does not re-deliberate, re-measure, or second-guess them. If a pre-decision conflicts with reality (stale LOC figure, for instance), the agent reports BLOCKED and the orchestrator re-resolves.

This keeps plan conditionals from forcing every agent to redo the same fact-gathering.

## The separation, in one image

```
┌─────────────────────────────────────────────────────────────┐
│  Orchestrator (the skill)                                   │
│  - Reads plan, composes prompt                              │
│  - Gathers pre-flight facts                                 │
│  - Resolves plan conditionals                               │
│  - Dispatches agents                                        │
│  - Runs verification (tests, lint, build)                   │
│  - Decides: proceed / retry / escalate                      │
│  - Tracks progress via plan checkboxes                      │
│                                                             │
│  Writes ZERO implementation code                            │
│                                                             │
│        ┌──────────────────┐  ┌─────────────────┐            │
│        │  implementer     │  │  verify         │    ...     │
│        │  (narrow exec)   │  │  (narrow exec)  │            │
│        └──────────────────┘  └─────────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

The orchestrator is a pure conductor. Agents are narrow executors. The Agent tool is the one-way dispatch boundary.

## Where to go next

- [TDD loop](./tdd-loop.md) — how the four execute-time agents coordinate inside the orchestrator.
- [QA loop](./qa-loop.md) — the review agents and the fresh-context principle.
- [commands/execute.md](../commands/execute.md) — the orchestrator walkthrough.
