# spec-flow

A PRD-to-code pipeline for Claude Code. Turns a product requirements document into shipped, reviewed code through a chain of skills and specialized agents, with TDD doctrine, adversarial QA gates, and PRD traceability baked in.

---

## The principle

Good AI-assisted engineering fails at the seams between intent and execution. A user says "build feature X," the model guesses, produces code, and ambiguity lives forever in the diff. Spec-flow refuses to let ambiguity compound: every stage produces an artifact that is reviewed *before* the next stage runs.

Three ideas drive the design:

1. **Progressive narrowing.** A PRD is ambiguous by nature. A spec resolves requirements into acceptance criteria. A plan resolves the spec into file paths and signatures. Implementation then has no design decisions left — just execution. By the time code is written, the model is a Sonnet-tier executor, not a designer.
2. **Adversarial review at every boundary.** Each artifact (spec, plan, phase diff, final worktree) passes through a dedicated reviewer agent before advancing. Reviewers are fresh — they see only the artifact, not the conversation that produced it. This is the check against model bias and self-justification.
3. **Context isolation via subagents.** Implementation agents never see brainstorming history, spec rationale, or each other's conversations. They see the plan and their oracle of done. This prevents scope creep and keeps each agent cheap to rerun.

One consequence: the orchestrator (the main conversation) writes **zero** implementation code. It reads plans, dispatches agents, evaluates reports, and decides proceed/retry/escalate. Code comes exclusively from subagents.

---

## How it's structured

The plugin ships five skills, a pool of specialized agents, reusable templates, and a doctrine document loaded on every session.

```
plugins/spec-flow/
├── skills/          # Entry points — invoked via /status, /prd, /spec, /plan, /execute
│   ├── status/      # Pipeline dashboard + next-action recommendation
│   ├── prd/         # Import/normalize PRD, decompose into pieces, update manifest
│   ├── spec/        # Author a spec for one piece (Socratic brainstorm + QA)
│   ├── plan/        # Turn spec into exhaustive implementation plan + QA
│   └── execute/     # Orchestrate implementation phase-by-phase with subagents
│
├── agents/          # Subagent templates dispatched by the skills above
│   ├── tdd-red.md           # Writes failing tests (TDD mode only)
│   ├── implementer.md       # Unified code-writer; runs in Mode: TDD or Mode: Implement
│   ├── verify.md            # Confirms correctness against spec ACs
│   ├── refactor.md          # Phase-scoped cleanup
│   ├── qa-phase.md          # Reviews each completed phase
│   ├── qa-spec.md           # Reviews spec before plan
│   ├── qa-plan.md           # Reviews plan before execution
│   ├── qa-prd-review.md     # End-of-pipeline: did we actually fulfill the PRD?
│   ├── fix-code.md          # Targeted fixes after QA findings
│   ├── fix-doc.md           # Same, for spec/plan documents
│   └── review-board/        # Final 5-agent parallel review before merge
│       ├── blind.md, edge-case.md, spec-compliance.md,
│       └── prd-alignment.md, architecture.md
│
├── templates/       # Starting shapes for PRD, spec, plan, manifest
├── reference/       # spec-flow-doctrine.md — auto-loaded on session start
└── hooks/           # SessionStart hook that loads the doctrine
```

Every skill is a thin orchestrator. Every agent is a narrow executor. Templates are shared shapes. The doctrine is shared philosophy.

---

## The chain of events

A piece of work flows through the pipeline linearly. Each stage has an output, a QA gate, and a status update in the manifest.

```
                              ┌──────────────────────────────────────────┐
                              │              docs/prd.md                 │
                              │         docs/manifest.yaml               │
                              │   (FR-001…, NFR-001…, NN-001…, SC-001…) │
                              └──────────────────────────────────────────┘
                                               │
                                       per piece ↓
  status: open ─────────────────────────────────┐
                                                ▼
  ┌──────────┐   Socratic   ┌─────────┐   QA    ┌───────────────────────┐
  │   spec   │─ brainstorm ▶│  spec   │──loop──▶│ docs/specs/<p>/spec.md│
  └──────────┘              └─────────┘  (Opus) │   + human sign-off    │
                                                └───────────────────────┘
  status: specced ──────────────────────────────┐
                                                ▼
  ┌──────────┐   read-only  ┌─────────┐   QA    ┌───────────────────────┐
  │   plan   │─ exploration▶│  plan   │──loop──▶│ docs/specs/<p>/plan.md│
  └──────────┘              └─────────┘  (Opus) │   + human sign-off    │
                                                └───────────────────────┘
  status: planned ──────────────────────────────┐
                                                ▼
  ┌──────────┐     per-phase loop:
  │ execute  │     ┌───────────────────────────────────────────────────┐
  └──────────┘     │  (TDD mode)   tdd-red → implementer → verify →    │
                   │                refactor → qa-phase                │
                   │  (Implement)  implementer → verify → (refactor?)→ │
                   │                qa-phase                           │
                   └───────────────────────────────────────────────────┘
                                                ▼
                   final review:   5 parallel reviewers (Opus)
                   ─────────────   blind, edge-case, spec-compliance,
                                   prd-alignment, architecture
                                                ▼
                                   learnings.md, squash-merge to main
  status: done ─────────────────────────────────┘

  When all pieces are done: /prd --review validates the full PRD.
```

### What each stage does

| Stage | Input | Output | Reviewer | Main model |
|---|---|---|---|---|
| **prd** | Existing requirements docs (BMad, speckit, `.md`, etc.) | Normalized `docs/prd.md` + `docs/manifest.yaml` with numbered FR/NFR/NN/SC and a piece list | Human (during brainstorm) | — |
| **spec** | One `open` piece + PRD sections mapped to it | `docs/specs/<piece>/spec.md` with acceptance criteria | `qa-spec` (Opus, up to 3 fix loops) | — |
| **plan** | Approved spec | `docs/specs/<piece>/plan.md` with per-phase TDD or Implement tracks, semantic anchors, exit gates | `qa-plan` (Opus, up to 3 fix loops) | — |
| **execute** | Approved plan | Working code on `spec/<piece>` branch, phase-by-phase, with commits | `qa-phase` per phase + 5-agent final review | `implementer` (Sonnet, Mode: TDD or Implement) |
| **merge** | Clean final review | Squash-merge to `main`, manifest updated to `done`, `learnings.md` | — | — |

---

## The two tracks (TDD vs Implement)

Not all code benefits from test-first development. A YAML config, a Terraform module, a migration script, or wiring between two existing services doesn't. The plan skill picks one track per phase:

- **TDD track** — phase has a `[TDD-Red]` checkbox. Used for behavior-bearing code. Flow: failing tests → implementer (Mode: TDD) → verify → refactor → QA.
- **Implement track** — phase has an `[Implement]` checkbox (no `[TDD-Red]`). Used for config, infra, scaffolding, glue code, docs-as-code. Flow: implementer (Mode: Implement) → verify against a plan-specified command (lint, build, smoke run, integration test) → optional refactor → QA.

The same `implementer.md` agent handles both. The orchestrator sets a `Mode: TDD` or `Mode: Implement` flag at the top of the agent's prompt, and the mode determines the oracle of done — failing tests going green (TDD) or a verification command passing (Implement). Every other rule is shared: follow the plan exactly, respect architecture, stay in scope, BLOCKED over guessing.

A phase must pick exactly one track. Both markers, or neither, is treated as a malformed plan and escalates to the human.

---

## Getting started

**Install the plugin** via the marketplace at the repo root:

```bash
claude plugin install spec-flow
```

**First session on a project with an existing PRD:**

1. `/status` — reports "No pipeline initialized."
2. `/prd` — imports your PRD (BMad output, speckit specs, a raw `docs/prd.md`, or anything else), normalizes it, decomposes it into pieces with you, writes `docs/manifest.yaml`.
3. `/spec` — authors a spec for the first `open` piece. Brainstorms with you, creates a worktree on `spec/<piece>`, runs `qa-spec`, asks for sign-off.
4. `/plan` — does read-only codebase exploration, writes an exhaustive plan, runs `qa-plan`, asks for sign-off.
5. `/execute` — runs the per-phase loop until all phases are green and the 5-agent final review is clean. Asks for merge approval.
6. Repeat `/spec` → `/plan` → `/execute` for each remaining piece.
7. When the manifest shows all pieces `done`, `/prd --review` validates that the full PRD was actually fulfilled.

**Every session:** start with `/status` to see where you are. The SessionStart hook loads the doctrine so every conversation knows the rules.

---

## Key concepts

- **Manifest** (`docs/manifest.yaml`) — the source of truth for what pieces exist, what PRD sections each covers, and their statuses (`open` → `specced` → `planned` → `implementing` → `done`). PRD traceability is a first-class concept.
- **Piece** — an independently implementable, testable unit of work that maps to specific PRD sections.
- **Worktree** — each piece gets its own `spec/<piece>` branch in a separate working directory. No cross-piece contamination. Merged via squash when done.
- **Non-negotiables (NN-xxx)** — constraints the PRD flags as binding (security, compliance, architecture). Every QA gate checks against them.
- **Oracle of done** — the single objective check that proves a phase is complete. TDD mode: green tests. Implement mode: the plan's `[Verify]` command passes. The implementer agent refuses to report DONE without passing its oracle.
- **Circuit breakers** — every retry loop caps at 2–3 attempts, then escalates to the human. The pipeline refuses to burn tokens on stuck problems.

---

## Configuration

On first use, a `.spec-flow.yaml` is created at the project root:

```yaml
docs_root: docs            # Where prd.md, specs/, manifest.yaml live
worktrees_root: worktrees  # Where feature branches get checked out

# Orchestrator behavior
refactor: auto             # auto | always | never — skip Refactor when Build is clean
qa_iter2: auto             # auto | always — skip QA iter-2 re-dispatch when fix diff is small + self-verified
phase_groups: auto         # auto | always | off — use Phase Group scheduler when plan has groups
reflection: auto           # auto | off — dispatch end-of-piece reflection agents (Step 4.5)
```

Edit if your project uses different layouts (e.g., `docs_root: repo/docs`) or wants different orchestrator defaults. The `refactor` and `qa_iter2` keys both default to `auto` — they skip low-yield steps based on the Build agent's own self-reported cleanliness. Set to `always` if you want every phase to get a Refactor pass and every fix-code iteration to get an Opus QA re-review regardless of self-report — costs ~20–30 min/phase of extra wall time but catches anything the skip predicates might miss. Set `refactor: never` for repetitive-pattern tracks (e.g. adapter boilerplate) where Refactor historically produces only comment cleanups.

The `phase_groups` key controls the v1.4.0 Phase Scheduler. In `auto` (default), plans that use Phase Group headings (`## Phase Group <letter>:`) dispatch their Sub-Phases concurrently; plans using only flat phases (`### Phase <N>`) run serially as before. Set to `off` to disable the scheduler entirely (treats groups as flat serial phases) — useful for rollback if you hit scheduler bugs in a new release. Set to `always` to have the orchestrator warn when a plan has only flat phases in a piece that looks parallelizable — catches over-flat plans during doctrine adoption.

The `reflection` key (new in v1.5.0) controls Step 4.5 of Final Review. In `auto` (default), two read-only Sonnet reflection agents fire after Human Sign-Off and before Capture Learnings: a process retro examining session metrics + escalation log + cumulative diff to identify what worked / what didn't in the orchestration flow, and a future-opportunities agent examining the spec/plan/diff/manifest to surface candidate future pieces. Their findings get appended to `<docs_root>/improvement-backlog.md` (committed) and feed Step 5's `learnings.md` synthesis. Set to `off` to skip Step 4.5 entirely (preserves pre-v1.5 behavior — `learnings.md` authored without reflection-agent input).

### Recommended project-level setup

Spec-flow delegates a few concerns to the project's own tooling rather than owning them in the skill — this keeps the plugin language-agnostic and avoids reinventing battle-tested tools per ecosystem.

**Keep pre-commit hooks cheap.** Every intermediate commit the orchestrator and agents make runs pre-commit hooks. Pre-commit should be lint + format + type-check only — the kind of checks that run in a few seconds against a small diff. The orchestrator already runs the test suite explicitly as the phase's oracle gate (Step 3 item 5) and again as Step 6b's sanity sweep; a test hook in pre-commit is redundant and expensive.

**Move expensive checks to pre-push or orchestrator gates.** Full test suites, whole-repo type checks, documentation builds, license scanners — anything that can't complete in a few seconds against a small diff — should live at the `pre-push` stage or run as explicit orchestrator gates between phases. The `pre-push` stage still gates the final squash-merge to main, so you get the coverage without the per-commit cost.

**Diff-scoped test selection (if tests must stay in a hook).** If your project has a hard requirement to run tests on commit (e.g. a regulated industry requiring local verification before push), narrow to tests actually affected by the changed files rather than running the full suite. Each ecosystem has a tool for this:

| Ecosystem | Tool / approach |
|---|---|
| Python (pytest) | [`pytest-testmon`](https://pytest-testmon.readthedocs.io/) — coverage-based, transitive-import-aware |
| JavaScript / TypeScript (Jest) | `jest --findRelatedTests <changed files>` |
| JavaScript / TypeScript (Vitest) | `vitest related <changed files>` or `vitest --changed` |
| Go | `go test` with a diff-to-package resolver (e.g. shell script piping `git diff --name-only` to `go list`) |
| Rust | `cargo nextest` with `--changed-since` (via `cargo-nextest` + git) |
| Ruby | `rspec --only-failures` combined with a diff-aware runner like `test_queue` |
| Other | any incremental/selective test runner for your language; fall back to the full suite only when the scope resolver is unsafe (e.g. build config or hook config changed) |

The common shape for a test hook: take `pass_filenames: true`, receive the changed file list, and either run the narrowed command or fall back to the full suite on ambiguity. A 1000-test suite typically drops from 90 s+ to under 10 s once selective runs stabilize.

**Scaffold-first commits for multi-phase coordination-file edits.** See the [scaffold-first phase guidance in the plan skill](skills/plan/SKILL.md) — when a piece has ≥2 phases each appending to the same shared coordination files, authoring a single scaffold phase upfront unblocks parallel dispatch of the later phases.

### Phase Groups (v1.4.0+) — parallel execution of independent work

When a piece contains multiple independent units of work (N adapters, N endpoints, per-table migrations), the plan skill can decompose them into a **Phase Group** with parallel-eligible Sub-Phases. The execute skill's Phase Scheduler dispatches the Sub-Phases concurrently, runs each through its own Red → Build → Verify → QA-lite cycle, then runs one group-level Refactor + Opus QA on the cumulative diff.

**When to use Phase Groups:**
- Work decomposes into ≥2 units with disjoint file scopes
- Sub-units have no symbol dependencies on each other
- You want wall-time parallelism on independent work

**When to stay flat:**
- Single-file or tightly-coupled work
- Regulatory requirement for per-unit deep Opus review

**Tiered QA model:**
- Per Sub-Phase: **Sonnet QA-lite** runs a narrow fast review (plan alignment, AC matrix spot-check, structural sanity)
- Per Phase Group: **Opus QA** runs a deep adversarial review once on the cumulative group diff

This tiering drops net Opus QA cost: instead of N Opus dispatches per group (one per sub-phase), there's one Opus dispatch per group plus N cheap Sonnet dispatches.

**Failure handling is autonomous.** If sub-phases fail in pass 1, the orchestrator auto-triages against a decision matrix (fix-code for local defects, Refactor for repeated-pattern failures, reset-and-re-dispatch for contamination/scope-violation, immediate escalation for BLOCKED categories). A focused pass-2 re-check runs on recovered sub-phases only. Hard cap: 2 passes then escalate. Humans are involved only when the matrix says "stop and think."

See the plan skill's rule 8 for Phase Group structure; see `skills/execute/SKILL.md` "Phase Group Loop" for the execution flow.

### Reflection stage (v1.5.0+) — end-of-piece retros + improvement backlog

Each piece ends with a two-agent reflection stage (Step 4.5 in execute) before the synthesized `learnings.md` gets written. The agents run in parallel:

- **Process retro** (Sonnet, read-only) examines session metrics, per-phase escalation log, and the cumulative diff to identify orchestration patterns worth keeping or changing for future pieces. Output: `must-improve` / `worked-well` / `metrics` sections.
- **Future opportunities** (Sonnet, read-only) examines the spec, plan, cumulative diff, current improvement backlog, and manifest to surface candidate future pieces (deferred ACs, hinted features, tech debt accrued, dependencies unlocked, cross-piece patterns). Every item must reference a concrete artifact — no speculation.

Findings get appended to `<docs_root>/improvement-backlog.md` (project-level, committed, accumulates across pieces). The `spec` skill reads this file at brainstorm start (Phase 1, step 6) and surfaces ~5 most-relevant items as candidate considerations for the new piece. Items the user marks `incorporated` or `obsolete` during brainstorm get pruned from the backlog after spec sign-off (Phase 5, step 4); `deferred` items stay for future surface-up.

The improvement backlog is intentionally pruneable working state, not an immutable log. Manually delete entries when they're addressed or no longer relevant.

Disable the stage with `reflection: off` in `.spec-flow.yaml` if you prefer the pre-v1.5 single-shot `learnings.md` flow.

---

## Extending

- **Templates** — edit `templates/prd.md`, `spec.md`, `plan.md`, `manifest.yaml` to match your team's shape.
- **Doctrine** — `reference/spec-flow-doctrine.md` is loaded on every session. Adjust the TDD laws, safeguards, or testing ratios to your engineering culture.
- **Agents** — each agent is a short Markdown template under `agents/`. Rules, context shape, and output format are all text you can tune.
- **Review board** — add or remove reviewers under `agents/review-board/`. The final review dispatches whatever is in that directory in parallel.
- **Internal vs. user-facing agents** — user-facing skills (`spec-flow:prd`, `spec-flow:spec`, `spec-flow:plan`, `spec-flow:execute`, `spec-flow:status`) are the documented API. Internal agents (`implementer`, `tdd-red`, `verify`, `refactor`, `qa-phase`, `qa-phase-lite`, `fix-code`) are dispatched by the execute skill with orchestrator-injected context; they are not meant to be called directly and will BLOCK on a first-turn entrypoint check if invoked without the correct context. If you customize an internal agent, preserve the Rule 0 check — it's the safety net against direct-dispatch contamination.

---

## Design choices worth knowing

**Why the orchestrator writes no code.** Main-window context grows with brainstorming, review history, and agent reports. Keeping it out of the code path means it never has partial state that biases implementation. Subagents get exactly the context they need; nothing more.

**Why specs and plans exist as separate artifacts.** A spec defines *what* from the user's perspective (acceptance criteria). A plan defines *how* from the codebase's perspective (file paths, signatures, test patterns). Separating them means spec review catches requirements gaps and plan review catches implementation gaps — two different failure modes, two different reviewers.

**Why the implementer is a single agent with a mode flag** (not two agents). The rules of good implementation — follow the plan, respect architecture, stay in scope, don't guess — are identical regardless of whether the oracle is failing tests or a lint command. Splitting them created drift. One file, one flag, shared doctrine.

**Why five parallel reviewers at merge time.** Each reviewer has a lens: blind (no context, just the diff), edge-case, spec-compliance, PRD-alignment, architecture. Running them in parallel with fresh context is cheap (one round-trip) and catches the things a single reviewer would rationalize away.

**Why circuit breakers everywhere.** AI coding agents will cheerfully loop on the same failure forever. 2 build attempts, 3 QA cycles, 3 review cycles — then escalate. If the pipeline can't make progress, the human is the right solver, not another retry.
