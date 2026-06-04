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

The plugin ships ten skills, a pool of 26 specialized agents, reusable templates, and a doctrine document loaded on every session.

```
plugins/spec-flow/
├── skills/          # Entry points — /intake, /status, /charter, /prd, /spec, /plan, /execute, /defer, /small-change, /review-board
│   ├── intake/      # Session-start triage: classify work, set CWD, load charter, route to the right skill — run first
│   ├── status/      # Pipeline dashboard + next-action recommendation + charter divergence resolver
│   ├── charter/     # Bootstrap/update charter — project-wide binding constraints (7 domains as skills under .github or .claude)
│   ├── prd/         # Import/create/update PRD, decompose into pieces, update manifest
│   ├── spec/        # Author a spec for one piece (Socratic brainstorm + QA)
│   ├── plan/        # Turn spec into exhaustive implementation plan + QA
│   ├── execute/     # Orchestrate implementation phase-by-phase with subagents
│   ├── defer/       # Record a non-blocking finding to a backlog file with provenance
│   ├── small-change/  # Single-session combined flow: brainstorm, scope-gate, plan, and hand off to execute
│   └── review-board/  # On-demand: run the Final Review board on any PR/branch/diff, out of band
│
├── agents/          # 26 subagent templates dispatched by the skills above
│   ├── tdd-red.md           # Writes failing tests (TDD mode only)
│   ├── qa-tdd-red.md        # Reviews Red's tests for theater patterns before Build (TDD mode only)
│   ├── implementer.md       # Unified code-writer; runs in Mode: TDD or Mode: Implement
│   ├── verify.md            # Confirms correctness against spec ACs
│   ├── refactor.md          # Phase-scoped cleanup
│   ├── qa-phase.md          # Reviews each completed phase (Opus)
│   ├── qa-phase-lite.md     # Narrow Sonnet review of a Phase Group sub-phase
│   ├── qa-spec.md           # Reviews spec before plan
│   ├── qa-plan.md           # Reviews plan before execution
│   ├── qa-prd.md            # Reviews PRD completeness before manifest creation
│   ├── qa-charter.md        # Reviews charter files before sign-off
│   ├── qa-prd-review.md     # End-of-pipeline: did we actually fulfill the PRD?
│   ├── fix-code.md          # Targeted fixes after QA findings
│   ├── fix-doc.md           # Same, for spec/plan/charter documents
│   ├── plan-amend.md        # Amends the plan in response to a discovery
│   ├── spec-amend.md        # Amends the spec in response to a discovery
│   ├── review-board-blind.md            # Final Review — blind reviewer (diff-only)
│   ├── review-board-edge-case.md        # Final Review — edge-case hunter
│   ├── review-board-spec-compliance.md  # Final Review — spec compliance
│   ├── review-board-prd-alignment.md    # Final Review — PRD alignment
│   ├── review-board-architecture.md     # Final Review — architecture + charter
│   ├── review-board-security.md         # Final Review — security audit (SAST + semantic)
│   ├── review-board-ground-truth.md     # Final Review — ground-truth / oracle correctness
│   ├── review-board-integration.md      # Final Review — integration / path-coverage
│   ├── reflection-process-retro.md      # End-of-piece — orchestration retro
│   └── reflection-future-opportunities.md  # End-of-piece — forward-looking ideas
│
├── templates/       # Starting shapes for PRD, spec, plan, manifest, charter
│   └── charter/     # Seven charter templates (architecture, non-negotiables, tools, processes, flows, coding-rules, integrations)
├── reference/       # spec-flow-doctrine.md — auto-loaded on session start
└── hooks/           # SessionStart hook that loads the doctrine + charter files
```

Every skill is a thin orchestrator. Every agent is a narrow executor. Templates are shared shapes. The doctrine is shared philosophy.

---

## Documentation

The user guide covers the full pipeline with per-command walkthroughs, concept deep-dives, and concrete file examples:

| Page | What it covers |
|---|---|
| **[User guide overview](./docs/userguide/README.md)** | Index of all pages + quickstart |
| [Project layout](./docs/userguide/concepts/project-layout.md) | Full directory tree after running the pipeline; annotated examples of every file type (charter, PRD, manifest, spec, plan, learnings) |
| [Pipeline concepts](./docs/userguide/concepts/pipeline.md) | Why `charter → prd → spec → plan → execute` is staged, and what each artifact is and isn't |
| [Charter system](./docs/userguide/concepts/charter-system.md) | NN-C / NN-P / CR namespaces; how citations flow through specs and plans |
| [TDD loop](./docs/userguide/concepts/tdd-loop.md) | Red / Build / Verify / Refactor enforced by the orchestrator |
| [QA loop](./docs/userguide/concepts/qa-loop.md) | Iterative fix-and-re-review; circuit-breaker behavior |
| [Orchestrator model](./docs/userguide/concepts/orchestrator-model.md) | Why skills orchestrate and agents implement; context isolation |
| [/intake command](./docs/userguide/commands/intake.md) | Session-start triage and routing — run first every session |
| [/charter command](./docs/userguide/commands/charter.md) | Bootstrap or update the charter — full walkthrough |
| [/prd command](./docs/userguide/commands/prd.md) | Import, create, or update a PRD; decompose into pieces; multi-PRD layout |
| [/spec command](./docs/userguide/commands/spec.md) | Author a spec for one piece |
| [/plan command](./docs/userguide/commands/plan.md) | Turn a spec into an implementation plan |
| [/execute command](./docs/userguide/commands/execute.md) | Run the plan phase-by-phase via subagents |
| [/status command](./docs/userguide/commands/status.md) | Pipeline dashboard |
| [/small-change command](./docs/userguide/commands/small-change.md) | One-session track for small focused changes |
| [/review-board command](./docs/userguide/commands/review-board.md) | Run the Final Review board out of band on any PR/branch/diff |
| [/defer command](./docs/userguide/commands/defer.md) | Record a non-blocking finding to a backlog with provenance |

---

## Multi-PRD support

A repo can host multiple PRDs in parallel under a single project-wide charter, each with its own pieces, specs, plans, manifest, and lifecycle state. The charter remains one per project — it captures project-wide architectural constraints that apply across every PRD, and lives as charter skills under the project's charter root, `.github/skills/charter-*/` or `.claude/skills/charter-*/` (see [Charter](#charter)).

**Layout.** The charter lives under `<charter_root>/skills/` (`<charter_root>` is `.github` or `.claude`); each PRD lives at `docs/prds/<prd-slug>/`:

```
<charter_root>/skills/                 # Project-wide charter (.github or .claude) — applies to every PRD
├── charter-architecture/SKILL.md
├── charter-non-negotiables/SKILL.md  # NN-C-xxx (project-wide)
├── charter-coding-rules/SKILL.md     # CR-xxx
├── charter-tools/SKILL.md
├── charter-processes/SKILL.md
├── charter-flows/SKILL.md
└── charter-integrations/SKILL.md     # external integrations (Jira, MCP, CI, webhooks)

docs/
├── prds/                             # One subdirectory per PRD
│   ├── <prd-slug>/
│   │   ├── prd.md                    # Includes status front-matter
│   │   ├── manifest.yaml             # PRD-local piece manifest
│   │   ├── backlog.md                # PRD-local deferred work
│   │   └── specs/
│   │       └── <piece-slug>/
│   │           ├── spec.md
│   │           ├── plan.md
│   │           ├── introspection.md  # codebase exploration notes (untracked)
│   │           └── learnings.md
│   └── <other-prd-slug>/
│       └── ...
│
├── changes/                          # small-change track artifacts
│   └── <slug>/
│       ├── change-brief.md
│       └── plan.md
│
└── improvement-backlog.md            # Global — cross-PRD learnings + spec-flow process retros
```

See `plugins/spec-flow/reference/v3-path-conventions.md` for the canonical path map (every input/output by skill, plus worktree and branch shapes).

**PRD lifecycle states.** Each PRD declares `status:` in its front-matter — one of `drafting | active | shipped | archived`. `/spec-flow:status` filters by status (active by default; archived hidden unless `--include-archived`). Archived PRDs stay in place as a historical record; there is no `docs/archive/` move convention.

**Slug naming.** Slugs (≤20 chars, charset `[a-z0-9-]`, ≤50-char branch length when combined with `<prd-slug>-<piece-slug>`) keep paths and branches readable. See `plugins/spec-flow/reference/slug-validator.md` for rules and the validator behavior the skills enforce.

**Cross-PRD piece dependencies.** A piece in PRD A can declare a dependency on a piece in PRD B via a qualified `depends_on:` ref of the shape `<prd-slug>/<piece-slug>` (unqualified refs continue to mean same-PRD). `/spec-flow:execute` blocks on unmerged cross-PRD dependencies by default; pass `--ignore-deps` for deliberate deviations.

**Branching topology.** Each manifest captures the PRD's branch strategy in front-matter — `feature_branch:` (an optional accumulator branch that pieces merge into), `merge_target:` (where pieces merge — an accumulator branch or `main`/`master`), and `pr_required:` (whether the merge goes through a pull request). `/spec-flow:execute` reads these to decide each piece's merge destination; a piece does not always merge straight to `main`.

**Dual backlog routing.** Two distinct backlogs serve two distinct audiences:

- **`docs/prds/<prd-slug>/backlog.md`** (PRD-local) — capability-scoped deferred work surfaced by `reflection-future-opportunities`. Items here are candidates for future pieces *within this PRD*.
- **`docs/improvement-backlog.md`** (global) — cross-PRD learnings and spec-flow process retros surfaced by `reflection-process-retro`. Items here inform pipeline-level improvements, not capability-level ones.

The `spec` skill reads the PRD-local backlog at brainstorm start to surface candidate considerations for new pieces; the global backlog is read by spec-flow's own retros and is not surfaced into per-piece brainstorms.

---

## The chain of events

A piece of work flows through the pipeline linearly. Each stage has an output, a QA gate, and a status update in the manifest.

```
  ┌──────────┐   Socratic   ┌─────────┐   QA    ┌──────────────────────────────────┐
  │ charter  │─ brainstorm ▶│ charter │──loop──▶│ <charter_root>/skills/charter-* (7)│
  │          │              │         │  (Opus) │  architecture, tools, flows,     │
  │          │              │         │         │  processes, coding-rules,        │
  │          │              │         │         │  integrations,                   │
  │          │              │         │         │  non-negotiables (NN-C-xxx)      │
  └──────────┘              └─────────┘         └──────────────────────────────────┘
                                               │
                                   binds everything below ↓
                              ┌──────────────────────────────────────────────┐
                              │     docs/prds/<prd-slug>/prd.md              │
                              │     docs/prds/<prd-slug>/manifest.yaml       │
                              │   (FR-001…, NFR-001…, NN-P-001…, SC-001…)   │
                              └──────────────────────────────────────────────┘
                                               │
                                       per piece ↓
  status: open ─────────────────────────────────┐
                                                ▼
  ┌──────────┐   Socratic   ┌─────────┐   QA    ┌──────────────────────────────────────────┐
  │   spec   │─ brainstorm ▶│  spec   │──loop──▶│ docs/prds/<prd-slug>/specs/<piece>/spec.md│
  └──────────┘              └─────────┘  (Opus) │           + human sign-off               │
                                                └──────────────────────────────────────────┘
  status: specced ──────────────────────────────┐
                                                ▼
  ┌──────────┐   read-only  ┌─────────┐   QA    ┌──────────────────────────────────────────┐
  │   plan   │─ exploration▶│  plan   │──loop──▶│ docs/prds/<prd-slug>/specs/<piece>/plan.md│
  └──────────┘              └─────────┘  (Opus) │           + human sign-off               │
                                                └──────────────────────────────────────────┘
  status: planned ──────────────────────────────┐
                                                ▼
  ┌──────────┐     per-phase loop:
  │ execute  │     ┌───────────────────────────────────────────────────┐
  └──────────┘     │  (TDD mode)   tdd-red → qa-tdd-red → implementer │
                   │                → verify → refactor → qa-phase     │
                   │  (Implement)  implementer → verify → (refactor?)→ │
                   │                qa-phase                           │
                   └───────────────────────────────────────────────────┘
                                                ▼
                   final review:   8 parallel reviewers (Opus); 9 in fast mode
                   ─────────────   blind, edge-case, spec-compliance,
                                   prd-alignment, architecture, security,
                                   ground-truth, integration
                                   (+ verify Piece Full in fast mode)
                                                ▼
                                   learnings.md, squash-merge to main
  status: done ─────────────────────────────────┘

  When all pieces are done: /prd --review validates the full PRD.
```

### What each stage does

| Stage | Input | Output | Reviewer | Main model |
|---|---|---|---|---|
| **charter** | Detection signals + user-supplied sources (team wikis, handbooks) | `<charter_root>/skills/charter-*/` (`.github` or `.claude`) — seven domain skills (architecture, non-negotiables, coding-rules, tools, processes, flows, integrations) | `qa-charter` (Opus, up to 3 fix loops) | — |
| **prd** | Existing requirements docs (BMad, speckit, `.md`, etc.) or a from-scratch interview | Normalized `docs/prds/<prd-slug>/prd.md` + `docs/prds/<prd-slug>/manifest.yaml` with numbered FR/NFR/NN-P/SC, branching fields, and a piece list | `qa-prd` (Opus, up to 3 fix loops) | — |
| **spec** | One `open` piece + PRD sections mapped to it + charter | `docs/prds/<prd-slug>/specs/<piece-slug>/spec.md` with acceptance criteria, cited NN-C/NN-P/CR, and any `[PENDING-DECISION]` markers | `qa-spec` (Opus, up to 3 fix loops) | — |
| **plan** | Approved spec + charter | `docs/prds/<prd-slug>/specs/<piece-slug>/plan.md` with per-phase TDD or Implement tracks, AC Coverage Matrix, Contracts, Architectural Decisions, Executable AC Binding, and Change Specification Blocks | `qa-plan` (Opus, up to 3 fix loops) | — |
| **execute** | Approved plan | Working code on `piece/<prd-slug>-<piece-slug>` branch, phase-by-phase, with commits. Synchronous discovery triage at end-of-phase (Step 6c) and end-of-piece (Step 8: Final Review Triage) routes discoveries to plan-amend / spec-amend / fork / defer per the per-piece amendment budget (5 total, max 1 spec). | `qa-tdd-red` between Red and Build (TDD phases only) + `qa-phase` per phase + final review board (8 agents; 9 in fast mode) | `implementer` (Sonnet, Mode: TDD or Implement) |
| **small-change** | User description of a small focused change | `docs/changes/<slug>/change-brief.md` + `plan.md` on `change/<slug>` branch; worktree ready for `/spec-flow:execute change/<slug>`. Use when the change fits in 1–3 implementation phases and doesn't require the full PRD → spec → plan pipeline. | scoped brainstorm (5–8 questions) + scope gate | — |
| **review-board** | A PR #, branch, path(s), or working-tree changes (out of band — no piece required) | Consolidated adversarial findings by severity; `--fix` routes findings into `/spec-flow:small-change` for a planned, QA-gated, board-reviewed fix (never patches the tree directly); `--comment` posts inline PR comments. Never merges, amends, forks, or signs off. | the Final Review board itself (blind, edge-case, security, ground-truth, architecture, integration; +spec-compliance/prd-alignment when context supplied) | routes to `/spec-flow:small-change` (with `--fix`) |
| **merge** | Clean final review | Squash-merge to `main`, manifest updated to `done`, `learnings.md` | — | — |

### Synchronous discovery triage

The execution that finds the work also fixes it. Discoveries surfaced during a phase — a missing AC, an architectural assumption that turned out wrong, an unanticipated dependency — get triaged at end-of-phase rather than silently deferred to a backlog where they decay.

`/spec-flow:execute` runs the triage at two points:

- **Step 6c: Discovery Triage** — fires at the end of each phase, synchronously, before the next phase dispatches. Each discovery picks one route:
  - **plan-amend** — the plan was incomplete; insert suffix-named amendment phases via the `plan-amend` agent.
  - **spec-amend** — the spec was wrong within the piece's stated goals; rewrite affected sections via the `spec-amend` agent (max 1 per piece).
  - **fork** — the discovery exceeds the piece's goals; spawn a new piece in the manifest.
  - **defer** — the discovery does not block the piece's goals; record to a backlog via `/spec-flow:defer` with provenance.
- **Step 8: Final Review Triage** — applies the same Step 6c routing to findings surfaced by the final review board (8 agents standard; 9 in fast mode) at end-of-piece, before merge.

**Per-piece amendment budget.** A piece may take at most **5 amendments total** (combined plan-amend + spec-amend), with **at most 1 spec-amend**. Hitting the budget forces fork-or-defer for any further discovery — the piece is either done as scoped or the work belongs in another piece. The budget is the load-bearing safeguard against a piece amending itself indefinitely.

**Per-piece artifact.** Every amend / fork / defer decision lands a row in `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/.discovery-log.md` with provenance (phase, AC ID, route, rationale). The AC matrix grows a `Reason:` field with values `does-not-block-goal | requires-amendment | requires-fork` so the route is auditable from the matrix alone.

**Precondition checks.** `/spec-flow:spec` and `/spec-flow:plan` consult `depends_on:` in the manifest at brainstorm time — if a dependency is absent or in the wrong state, the skill offers three triage options (re-plan, fork, defer) before authoring proceeds. Discovery triage is therefore not just an end-of-phase concept — it threads through spec and plan time as well.

See `plugins/spec-flow/reference/ac-matrix-contract.md` and `plugins/spec-flow/reference/depends-on-precondition.md` for the load-bearing references.

---

## The two tracks (TDD vs Implement)

Not all code benefits from test-first development. A YAML config, a Terraform module, a migration script, or wiring between two existing services doesn't. The plan skill picks one track per phase:

- **TDD track** — phase has a `[TDD-Red]` checkbox. Used for behavior-bearing code. Flow: failing tests → qa-tdd-red (theater-pattern gate) → implementer (Mode: TDD) → verify → refactor → QA.
- **Implement track** — phase has an `[Implement]` checkbox (no `[TDD-Red]`). Used for config, infra, scaffolding, glue code, docs-as-code. Flow: implementer (Mode: Implement) → verify against a plan-specified command (lint, build, smoke run, integration test) → optional refactor → QA.

The same `implementer.md` agent handles both. The orchestrator sets a `Mode: TDD` or `Mode: Implement` flag at the top of the agent's prompt, and the mode determines the oracle of done — failing tests going green (TDD) or a verification command passing (Implement). Every other rule is shared: follow the plan exactly, respect architecture, stay in scope, BLOCKED over guessing.

A phase must pick exactly one track. Both markers, or neither, is treated as a malformed plan and escalates to the human.

---

## Charter

Charter is the pre-PRD stage that captures project-wide binding constraints — the stuff that doesn't change when the product changes. Seven focused domains are published as charter **skills** under the project's charter root — `.github/skills/charter-<domain>/SKILL.md` or `.claude/skills/charter-<domain>/SKILL.md` (resolved per [`reference/charter-location.md`](./reference/charter-location.md)). They are the single source of truth — there is no `docs/charter/` directory. Each is loaded by the host either always-on or on-demand (see [Charter system](./docs/userguide/concepts/charter-system.md)):

| Domain (`<charter_root>/skills/charter-<domain>/SKILL.md`) | Content | Loading |
|---|---|---|
| `architecture` | Layers, dependency direction, component ownership, module boundaries | always-on |
| `non-negotiables` | `NN-C-xxx` — project-wide binding rules (security, compliance, architecture, tooling) | always-on |
| `coding-rules` | `CR-xxx` — numbered coding conventions, citable from specs and plans | on-demand |
| `tools` | Language, framework, test runner, linter, CI, approved/banned libraries | on-demand |
| `processes` | Branching, review policy, release cadence, CI gates, incident response | on-demand |
| `flows` | Request flow, auth flow, data-write path, other critical end-to-end flows | on-demand |
| `integrations` | External integrations — Jira/issue tracker, MCP servers, CI systems, webhooks | on-demand |

### Two modes

- **Bootstrap** — no `charter-*/SKILL.md` files exist under either skills root. Charter detects which host directory the project already has (`.github/` or `.claude/`) and recommends that root — prompting you to choose if both or neither exist (never assuming a default). Full Socratic flow → write seven domain skills to `<charter_root>/skills/` → QA → per-domain commits → write `.spec-flow.yaml` with `layout_version: 4`, `charter_root`, and `charter.required: true`.
- **Update** — scoped re-run of Socratic on specific domains under the resolved charter root. Retirement UX (retire-vs-delete) preserves historical traceability via tombstones. Post-commit, in-flight pieces get a divergence notice.

### Entry schema — `Rule` vs `Reference`

Numbered entries (NN-C and CR) declare a `Type`:

- **`Type: Rule`** — inline, self-contained. The `Statement:` field IS the rule.
- **`Type: Reference`** — defers to external content. The `Source:` field (URL or local path) is what agents must consult.

Reference entries let you point at Maven conventions, Google Java Style, your own `.pre-commit-config.yaml`, Uncle Bob's Clean Architecture, etc. without transcribing them inline. QA agents do surface-level validity checks (URL format, local path existence) but don't fetch content in v2.0 — the summary under `Statement:` is what agents rely on.

---

## Non-negotiables: two namespaces

- **`NN-C-xxx`** (Charter) — project-wide. Applies across every product and every piece in the repo. Lives in `<charter_root>/skills/charter-non-negotiables/SKILL.md`. Changes rarely.
- **`NN-P-xxx`** (Product) — product-specific. Tied to a single PRD. Lives in `docs/prds/<prd-slug>/prd.md` under `## Non-Negotiables (Product)`. Grows with each PRD import.
- **`CR-xxx`** (Coding Rules) — a third citable namespace for coding conventions, separate from binding rules. Lives in `<charter_root>/skills/charter-coding-rules/SKILL.md`.

Specs and plans cite specific IDs. Every piece's spec enumerates the NN-C, NN-P, and CR entries its scope touches under `### Non-Negotiables Honored` and `### Coding Rules Honored`, with a per-entry "how this piece honors it" line. Plans allocate each cited entry to exactly one phase's "Charter constraints honored in this phase" slot. QA checks that every claim is demonstrably honored in the final diff.

**IDs are write-once.** A number once assigned is never reused. Retired entries stay as tombstones (strikethrough title + `RETIRED YYYY-MM-DD` + reason + pieces that cited them). Specs citing retired IDs are must-fix by QA — you either drop the citation or upgrade to the superseding entry.

**Divergence.** When a piece's spec or plan was written against an older charter and the charter has since changed, the piece is **diverged**. `/status` surfaces this passively; `/status --resolve <piece>` walks you through three options (re-spec the citations, re-plan the allocations, or accept with a documented rationale). Divergence is informational — never blocks execution. Human judgment resolves it.

---

## Getting started

**Install the plugin** via the marketplace at the repo root:

```bash
claude plugin install spec-flow
```

**First session on a new project:**

1. `/spec-flow:intake` — classifies the work and routes you. On an uninitialized project it reports "no charter yet" and points you to charter.
2. `/spec-flow:charter` — Socratic bootstrap of the charter skills. It first picks a charter root (`.github/skills/` or `.claude/skills/`) by detecting which host directory your project already has, then detects existing signals (`README`, `package.json`, `.github/workflows/`, etc.), asks for any additional sources (team wikis, handbooks), and walks you through seven domains one question at a time. `qa-charter` reviews. Per-domain commits.
3. `/prd` — imports (or creates) your PRD. Classifies each extracted non-negotiable as `NN-C` (adds to charter) or `NN-P` (stays in PRD). Decomposes into pieces with you, writes `docs/prds/<prd-slug>/manifest.yaml`.
4. `/spec` — authors a spec for the first `open` piece. Loads charter, identifies the NN-C/NN-P/CR entries this piece touches, brainstorms with you, creates a worktree on `piece/<prd-slug>-<piece-slug>`, runs `qa-spec`, asks for sign-off.
5. `/plan` — reads charter + spec, allocates every cited NN/CR to a specific phase, writes an exhaustive plan, runs `qa-plan`, asks for sign-off.
6. `/execute` — runs the per-phase loop until all phases are green and the final review board is clean. Asks for merge approval.
7. Repeat `/spec` → `/plan` → `/execute` for each remaining piece.
8. When the manifest shows all pieces `done`, `/prd --review` validates full PRD fulfillment.

**Every session:** start with `/spec-flow:intake` — it sets the working directory, loads charter constraints, and routes you to the right skill (`/status` runs inside it for a read-only snapshot). The SessionStart hook loads the TDD doctrine and the always-on charter domains (non-negotiables + architecture); the remaining charter domains load on-demand by description.

---

## Key concepts

- **Manifest** (`docs/prds/<prd-slug>/manifest.yaml`, one per PRD) — the source of truth for what pieces exist within a PRD, what PRD sections each covers, and their statuses (`open` → `specced` → `planned` → `in-progress` → `merged`; `done` is the v2 backward-compatible alias of `merged`). Terminal statuses outside the happy path: `superseded`, `blocked`. PRD traceability is a first-class concept.
- **Piece** — an independently implementable, testable unit of work that maps to specific PRD sections within a single PRD.
- **Worktree** — each piece gets its own `piece/<prd-slug>-<piece-slug>` branch in a separate working directory at `<worktrees_root>/prd-<prd-slug>/piece-<piece-slug>/`. No cross-piece contamination. Merged via squash when done.
- **Non-negotiables (NN-xxx)** — constraints the PRD flags as binding (security, compliance, architecture). Every QA gate checks against them.
- **Oracle of done** — the single objective check that proves a phase is complete. TDD mode: green tests. Implement mode: the plan's `[Verify]` command passes. The implementer agent refuses to report DONE without passing its oracle.
- **Circuit breakers** — every retry loop caps at 2–3 attempts, then escalates to the human. The pipeline refuses to burn tokens on stuck problems.

---

## Configuration

On first use, a `.spec-flow.yaml` is created at the project root:

```yaml
docs_root: docs            # Where prds/ and improvement-backlog.md live (charter lives in .github/skills/)
worktrees_root: worktrees  # Where feature branches get checked out
layout_version: 4          # charter as skills under <charter_root>/skills/ + multi-PRD docs/prds/<prd-slug>/
charter_root: .github      # .github or .claude — where charter skills live (written by /spec-flow:charter)

# Orchestrator behavior
refactor: auto             # auto | always | never — skip Refactor when Build is clean
phase_groups: auto         # auto | always | off — use Phase Group scheduler when plan has groups
reflection: auto           # auto | off — dispatch end-of-piece reflection agents (Step 4.5)
```

Edit if your project uses different layouts (e.g., `docs_root: repo/docs`) or wants different orchestrator defaults. The `refactor` key defaults to `auto` — it skips low-yield steps based on the Build agent's own self-reported cleanliness. Set to `always` if you want every phase to get a Refactor pass regardless of self-report — costs ~20–30 min/phase of extra wall time but catches anything the skip predicate might miss. Set `refactor: never` for repetitive-pattern tracks (e.g. adapter boilerplate) where Refactor historically produces only comment cleanups.

> **Deprecated keys.** `qa_iter2` and `charter.doctrine_load` are still parsed for backward compatibility but no longer drive behavior: QA iter-2 re-dispatch is always on, and v4 loads charter via the charter-skill scan (always-on for `non-negotiables` + `architecture`, on-demand for the rest).

**Fast mode** is a per-plan toggle, not a `.spec-flow.yaml` key. Set `fast: true` in a plan's front-matter to skip the per-phase `qa-tdd-red` and `qa-phase` gates and compensate with a 9th end-of-piece reviewer (`verify` Mode: Piece Full). See [/plan](./docs/userguide/commands/plan.md).

The `phase_groups` key controls the Phase Scheduler. In `auto` (default), plans that use Phase Group headings (`## Phase Group <letter>:`) dispatch their Sub-Phases concurrently; plans using only flat phases (`### Phase <N>`) run serially as before. Set to `off` to disable the scheduler entirely (treats groups as flat serial phases) — useful for rollback if you hit scheduler bugs in a new release. Set to `always` to have the orchestrator warn when a plan has only flat phases in a piece that looks parallelizable — catches over-flat plans during doctrine adoption.

The `reflection` key controls Step 4.5 of Final Review. In `auto` (default), two read-only Sonnet reflection agents fire after Human Sign-Off and before Capture Learnings: a process retro examining session metrics + escalation log + cumulative diff to identify what worked / what didn't in the orchestration flow, and a future-opportunities agent examining the spec/plan/diff/manifest to surface candidate future pieces. Findings are emitted to the orchestrator as structured reports; the orchestrator routes each finding through Step 6c discovery triage (amend / fork / defer). Only the operator-chosen `defer` resolution writes to a backlog file — via `/spec-flow:defer` — producing one `chore(<piece-slug>): defer ...` commit per deferred finding. Step 5's `learnings.md` synthesis consumes the same reflection outputs and is unchanged. Set to `off` to skip Step 4.5 entirely (`learnings.md` is then authored without reflection-agent input).

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

### Phase Groups — parallel execution of independent work

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

### Reflection stage — end-of-piece retros + improvement backlog

Each piece ends with a two-agent reflection stage (Step 4.5 in execute) before the synthesized `learnings.md` gets written. The agents run in parallel:

- **Process retro** (Sonnet, read-only) examines session metrics, per-phase escalation log, and the cumulative diff to identify orchestration patterns worth keeping or changing for future pieces. Output: `must-improve` / `worked-well` / `metrics` sections.
- **Future opportunities** (Sonnet, read-only) examines the spec, plan, cumulative diff, current improvement backlog, and manifest to surface candidate future pieces (deferred ACs, hinted features, tech debt accrued, dependencies unlocked, cross-piece patterns). Every item must reference a concrete artifact — no speculation.

**Routing (synchronous triage, not auto-write).** Reflection agent findings are emitted as structured reports to the orchestrator. The orchestrator routes each finding through Step 6c discovery triage — the operator chooses amend, fork, or defer per finding. Only the `defer` choice writes to a backlog file, via `/spec-flow:defer`, with one `chore(<piece-slug>): defer ...` commit per deferred finding. There is no automatic backlog-write commit at the end of the reflection step.

Backlog routing by target — applies to defer resolutions:

- **Future-opportunities findings** (capability-scoped) route to `docs/prds/<prd-slug>/backlog.md` (PRD-local) when deferred. The `spec` skill reads this file at brainstorm start (Phase 1, step 6) and surfaces ~5 most-relevant items as candidate considerations for new pieces *within the same PRD*. Items the user marks `incorporated` or `obsolete` during brainstorm get pruned after spec sign-off (Phase 5, step 4); `deferred` items stay for future surface-up.
- **Process-retro findings** (cross-PRD, pipeline-level) route to `docs/improvement-backlog.md` (global) when deferred. Spec-flow's own retros consume this; per-piece brainstorms do not.

The improvement backlog is intentionally pruneable working state, not an immutable log. Manually delete entries when they're addressed or no longer relevant.

Disable the stage with `reflection: off` in `.spec-flow.yaml` if you prefer the single-shot `learnings.md` flow without reflection agents.

---

## Extending

- **Templates** — edit `templates/prd.md`, `spec.md`, `plan.md`, `manifest.yaml` to match your team's shape.
- **Doctrine** — `reference/spec-flow-doctrine.md` is loaded on every session. Adjust the TDD laws, safeguards, or testing ratios to your engineering culture.
- **Agents** — each agent is a short Markdown template under `agents/`. Rules, context shape, and output format are all text you can tune.
- **Review board** — add or remove reviewers by dropping / deleting `agents/review-board-<lens>.md` files. The final review dispatches whatever flat-name agents match that prefix in parallel.
- **Internal vs. user-facing agents** — the user-facing skills (`spec-flow:intake`, `:status`, `:charter`, `:prd`, `:spec`, `:plan`, `:execute`, `:small-change`, `:review-board`, `:defer`) are the documented API. Internal agents (`implementer`, `tdd-red`, `qa-tdd-red`, `verify`, `refactor`, `qa-phase`, `qa-phase-lite`, `fix-code`, `fix-doc`, `spec-amend`, `plan-amend`, `reflection-*`) are dispatched by the skills with orchestrator-injected context; they are not meant to be called directly and will BLOCK on a first-turn entrypoint check if invoked without the correct context. If you customize an internal agent, preserve the Rule 0 check — it's the safety net against direct-dispatch contamination.

---

## Design choices worth knowing

**Why the orchestrator writes no code.** Main-window context grows with brainstorming, review history, and agent reports. Keeping it out of the code path means it never has partial state that biases implementation. Subagents get exactly the context they need; nothing more.

**Why specs and plans exist as separate artifacts.** A spec defines *what* from the user's perspective (acceptance criteria). A plan defines *how* from the codebase's perspective (file paths, signatures, test patterns). Separating them means spec review catches requirements gaps and plan review catches implementation gaps — two different failure modes, two different reviewers.

**Why the implementer is a single agent with a mode flag** (not two agents). The rules of good implementation — follow the plan, respect architecture, stay in scope, don't guess — are identical regardless of whether the oracle is failing tests or a lint command. Splitting them created drift. One file, one flag, shared doctrine.

**Why eight parallel reviewers at merge time (nine in fast mode).** Each reviewer has a lens: blind (no context, just the diff), edge-case, spec-compliance, PRD-alignment, architecture, security (CWE Top 25, injection, crypto, auth/authz, supply chain), ground-truth (do computed outputs reproduce an independently-derived correct answer?), and integration (real wired paths across each boundary; path coverage; mock-avalanche detection). Running them in parallel with fresh context is cheap (one round-trip) and catches the things a single reviewer would rationalize away. In fast mode, a 9th reviewer (`verify Mode: Piece Full`) is added — it applies the full theater-pattern catalog and AC binding check across the entire piece's test surface, compensating for the per-phase `qa-tdd-red` and `qa-phase` gates that fast mode skips.

**Why circuit breakers everywhere.** AI coding agents will cheerfully loop on the same failure forever. 2 build attempts, 3 QA cycles, 3 review cycles — then escalate. If the pipeline can't make progress, the human is the right solver, not another retry.

## Install on GitHub Copilot CLI

spec-flow installs on GitHub Copilot CLI directly from this multi-plugin marketplace. No mirror branch, no sync script — one source tree serves both hosts. Two install paths are supported; pick whichever fits your workflow.

**Option 1 — direct subdirectory install (1 step):**

```text
/plugin install jmontanari/ai-plugins:plugins/spec-flow
```

Installs spec-flow only, without registering the marketplace. Copilot CLI's `owner/repo:path/to/plugin` syntax discovers `.claude-plugin/plugin.json` at `plugins/spec-flow/.claude-plugin/plugin.json` and loads from the repo's default branch.

**Option 2 — marketplace install (2 steps):**

```text
/plugin marketplace add jmontanari/ai-plugins
/plugin install spec-flow@shared-plugins
```

Registers the `shared-plugins` marketplace, then installs spec-flow from it. Future plugins added to this marketplace become discoverable by name afterward. Recommended if you expect to install multiple plugins from this repo over time.

Both paths confirmed with Copilot CLI v1.0.34. **Minimum version: v1.0.34** — earlier Copilot CLI builds may not support the `/plugin` command family. Check with `copilot --version`.

**Recovery for the "plugins/plugins/spec-flow" error.** spec-flow v2.1.0 ships a fix for a path-duplication bug in the marketplace manifest that affected early adopters who registered the marketplace before this release. If you hit `Plugin source directory not found: .../plugins/plugins/spec-flow` during `/plugin install spec-flow@shared-plugins`, refresh the stale marketplace cache before retrying:

```text
/plugin marketplace remove jmontanari/ai-plugins
/plugin marketplace add jmontanari/ai-plugins
/plugin install spec-flow@shared-plugins
```

Once installed, spec-flow exposes the same skills on either host:

| Command | Description |
|---|---|
| `/spec-flow:intake` | Session-start triage — classify work, set CWD, load charter, route to the right skill. Run first. |
| `/spec-flow:status` | Pipeline dashboard — shows which pieces are in which stage and what to work on next. |
| `/spec-flow:charter` | Bootstrap or update the project charter (seven domain skills under `.github/skills/` or `.claude/skills/`). |
| `/spec-flow:prd` | Import, create, or update a PRD and decompose it into pieces. |
| `/spec-flow:spec` | Author a detailed specification for one piece. |
| `/spec-flow:plan` | Generate an exhaustive phase-by-phase implementation plan from an approved spec. |
| `/spec-flow:execute` | Orchestrate implementation phase-by-phase via subagents. |
| `/spec-flow:small-change` | One-session track for a small focused change that doesn't warrant the full PRD pipeline. |
| `/spec-flow:review-board` | Run the Final Review board out of band on a PR, branch, working tree, or files. |
| `/spec-flow:defer` | Record a non-blocking discovery to a backlog file with provenance. Sole supported path for writing to `<docs_root>/prds/<prd-slug>/backlog.md` or `<docs_root>/improvement-backlog.md`. |

**Dual-path details that make this work:**

- `plugins/spec-flow/CLAUDE.md` is read by both hosts. Copilot CLI reads CLAUDE.md directly as plugin context; Claude Code treats it as the plugin-level overview. No `AGENTS.md` symlink needed.
- `plugins/spec-flow/skills/<name>/SKILL.md` is the cross-tool Agent Skills open standard — identical file, both hosts.
- `plugins/spec-flow/agents/<name>.md` are plain Markdown files with YAML frontmatter. Copilot CLI's custom-agent loader scans both `*.md` and `*.agent.md` and deduplicates by basename per its [Custom agents configuration](https://docs.github.com/en/copilot/reference/custom-agents-configuration) reference, so the same files Claude Code discovers are picked up by Copilot CLI — no symlinks or dual extensions needed. All agents ship flat at `agents/*.md` (no nested subdirectories) with prefixed names (`review-board-<lens>.md`, `reflection-<scope>.md`) so Copilot CLI's flat-glob loader finds every agent.

**Known limitations on Copilot CLI:**

- Copilot CLI does not support branch-pinning (`#branch` or `@branch`) in `/plugin install` as of v1.0.34 (tracked in `github/copilot-cli#1296`). Users always install from the repo's default branch.
