# spec-flow

A PRD-to-code pipeline for Claude Code. Turns a product requirements document into shipped, reviewed code through a chain of skills and specialized agents — charter → prd → spec → plan → execute — with TDD doctrine, adversarial QA gates, and PRD traceability baked in at every stage.

---

## What is spec-flow

Spec-flow is a structured pipeline that refuses to let ambiguity compound. Every stage produces an artifact that is reviewed before the next stage runs. Three principles drive the design:

1. **Progressive narrowing.** A PRD is ambiguous by nature. A spec resolves requirements into acceptance criteria. A plan resolves the spec into file paths and signatures. By the time code is written, the model is a Sonnet-tier executor — all design decisions are already made.
2. **Adversarial review at every boundary.** Each artifact (spec, plan, phase diff, final worktree) passes through a dedicated reviewer agent before advancing. Reviewers are fresh — they see only the artifact, not the conversation that produced it.
3. **Context isolation via subagents.** Implementation agents never see brainstorming history, spec rationale, or each other's conversations. They see the plan and their oracle of done, nothing more.

See `plugins/spec-flow/README.md` for the canonical deeper reference on these principles, the full pipeline diagram, and the complete agent inventory.

---

## The pipeline: charter → prd → spec → plan → execute

Each stage has a single primary skill invocation, produces a concrete artifact, and has an explicit entry condition for the stage that follows.

- **charter** (`/spec-flow:charter`) — Runs a Socratic brainstorm to produce `docs/charter/` (six files: architecture, non-negotiables, tools, processes, flows, coding-rules). Passes through a QA-charter agent before sign-off. Enables prd once the charter is approved.
- **prd** (`/spec-flow:prd`) — Imports or normalizes a PRD, decomposes it into implementable pieces, and produces `docs/prd/prd.md` + `docs/prd/manifest.yaml`. Enables spec on each piece once the manifest is committed.
- **spec** (`/spec-flow:spec`) — Authors a detailed specification for one piece, including acceptance criteria, functional requirements, and non-negotiables. Passes through a QA-spec agent. Enables plan once the spec is approved.
- **plan** (`/spec-flow:plan`) — Reads the spec and explores the codebase to produce an exhaustive phase-by-phase implementation plan with file paths, signatures, and verification commands per phase. Passes through a QA-plan agent. Enables execute once the plan is approved.
- **execute** (`/spec-flow:execute`) — Orchestrates implementation phase-by-phase. Each phase dispatches a subagent (TDD mode or Implement mode) and runs an oracle gate before advancing. Reports DONE when all phases pass.

---

## TDD doctrine (summary)

Spec-flow enforces a strict TDD discipline on all behavior-bearing code phases. The Three Laws:

1. No production code without a failing test first.
2. No more test than sufficient to fail (one behavior per test).
3. No more production code than sufficient to pass the one failing test.

The Red/Build/Verify/Refactor cycle:

- **Red** — Write a single failing test. It must fail for the right reason (feature missing, not a typo or setup error). The failure output is reported verbatim to the orchestrator.
- **Build** — Write the simplest possible code that turns the failing test green. No optional parameters, no alternative strategies, no future-proofing.
- **Verify** — Run the full test suite, confirm all tests pass, check AC coverage, detect over-engineering.
- **Refactor** — Remove duplication, improve names, extract helpers. Tests stay green throughout. Scope is the current phase only.

See `plugins/spec-flow/reference/spec-flow-doctrine.md` for the full doctrine, agent-specific safeguards, the testing-strategy ratios, and the verification checklist.

---

## Entry-point skills

Start with `/spec-flow:status` if you are new to the project or resuming after a break — it shows the current pipeline state and recommends the next action.

| Skill | Purpose | Invocation |
|-------|---------|------------|
| status | Pipeline dashboard: shows which pieces are in which stage, what is blocked, and what to work on next. Start here. | `/spec-flow:status` |
| charter | Bootstrap, update, or retrofit the project charter (six binding constraint files). | `/spec-flow:charter` |
| prd | Import or normalize a PRD and decompose it into implementable pieces in the manifest. | `/spec-flow:prd` |
| spec | Author a detailed specification for one piece from the manifest. | `/spec-flow:spec` |
| plan | Turn an approved spec into an exhaustive phase-by-phase implementation plan. | `/spec-flow:plan` |
| execute | Orchestrate implementation of an approved plan phase-by-phase via subagents. | `/spec-flow:execute` |

---

For install instructions on GitHub Copilot CLI, see the "Install on GitHub Copilot CLI" section in `plugins/spec-flow/README.md`.
