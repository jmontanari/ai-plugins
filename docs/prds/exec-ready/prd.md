---
slug: exec-ready
status: drafting
version: 2
---

# Product Requirements Document — Execution-Ready Plans

**Project:** spec-flow — make spec/plan dense enough that execution is mechanical, run the mechanics on a cheap model, and let a learning flywheel drive the cost curve down over time.
**Date:** 2026-06-06
**Status:** draft
**Charter:** .claude/skills/charter-*/SKILL.md (NN-C namespace — project-wide binding rules)

## Problem Statement

**Current situation:** spec-flow's stated philosophy is *progressive narrowing* — "by the time code is written, the model is a Sonnet-tier executor; all design decisions are already made." In practice the pipeline does not deliver this. The plan is not dense enough to be a complete script, so execute still has to *think*: it infers where code goes, designs test data live (in `tdd-red`), and resolves ambiguities the spec/plan never settled. Thinking means discovering, and discovery at execute time means surprises — the exact thing the pipeline was built to prevent. Worse, every surprise is invisible feedback: the operator's own backlog (`docs/improvement-backlog.md`) shows the *same* pipeline weaknesses recurring across pi-009, pi-011, and pi-013 (sibling-branch fix misses, too-loose QA-skip predicates, missing branch-enumeration ACs) with no mechanism to detect the recurrence and harden against it.

**Problem:** Effort and cost sit in the wrong places.
1. The plan is under-specified, so execute discovers work that should have been resolved upstream — and an execute-time "discovery" is really evidence the plan was incomplete, not an execution defect.
2. Because execute must think, it must run on an expensive model (Opus), purely to keep long-running state in a large context window — paying for a thinking model to do mechanical work.
3. `tdd-red` *designs* tests at execute time; test data and expected outcomes are a design decision that belongs in the plan.
4. Recurring pipeline defects are rediscovered piece after piece because nothing counts occurrences or routes the fix to where it belongs.
5. spec-flow is installed across many repos; a plugin-level defect that appears once per repo never crosses a local recurrence threshold, so the plugin never learns from its own field failures.

**Who is affected:** the pipeline operator running spec-flow pieces (paying for Opus on mechanical work, babysitting execute surprises) and the plugin maintainer (whose plugin cannot self-harden from defects spread thin across installations).

**Why now:** Verified 2026 research on Boris Cherny's workflow shows the real leverage is *not* a heavyweight autonomy subsystem (he keeps tooling "surprisingly vanilla") — it is resolving ambiguity at the plan gate with a human, then running a locked plan with aggressive self-verification, and folding recurring lessons back into durable rules. spec-flow already ships the execute loop, journal resume, auto Final Review, and reflection agents (capability audit, 2026-06-06). The gap is not autonomy — it is *plan density*, *model placement*, and *cross-install learning*.

## Goals

- **G-1: Execution-ready plans.** Every decision knowable from the spec + codebase is resolved at plan time — exact file, location, content, signatures, and (for TDD) concrete test data with expected outcomes. Execute transcribes; it does not design.
- **G-2: No unplanned, mid-stream discovery.** Genuine unknowns (real external behavior that cannot be predicted) are explicit `[SPIKE]` markers in the plan, resolved by an isolated thinking agent. Any mid-execution scope change — whether agent-discovered or operator-initiated — is scoped by a spike and folded into the plan before code changes, never applied as a silent mid-stream patch. The bar is *zero avoidable discovery and zero mid-stream fixes*.
- **G-3: Right model in the right place.** Opus does the thinking (spec, plan, all adversarial gates, spikes); Sonnet runs the mechanics (coordinator, implementer, test transcription). Execute never silently upgrades to Opus to mask an under-specified plan.
- **G-4: File-based, re-derivable state.** All coordinator state needed to resume lives on disk; a fresh, cheap context re-derives the pipeline from disk. The transcript is disposable, so the large-context-window crutch (and its cost) is removed.
- **G-5: A self-hardening flywheel.** Recurring avoidable-discovery patterns are counted against a durable registry and routed to the right hardening home — repo (charter/project/PRD) or plugin (machine-global) — operator-gated, driving spikes and Opus cost down piece over piece.

## Non-Goals

- **Automated spec/plan approval** — the human review-and-sign-off gate on spec and plan is preserved. Density reduces rounds; it does not remove the gate.
- **Execute self-resolving ambiguity** — explicitly cut. An execute-time ambiguity is a plan-incompleteness signal; it routes to plan amendment (Step 6c) or a `[SPIKE]`, never a silent in-execute decision log.
- **Autonomous multi-piece queue orchestration** — driving a backlog of pieces unattended is out of scope; the single-piece execute loop already ships and is sufficient.
- **Cross-machine plugin-pattern correlation** — the plugin pattern registry is machine-global (`~/`), not cross-machine. Solving cross-machine correlation requires a shared remote backend, deliberately not built here.
- **Token micro-budgeting for its own sake** — the objective is file-based statelessness (G-4), not counting tokens. A token ceiling is not a requirement.
- **Replacing design judgment** — research and spikes inform decisions; the human still owns architectural direction at the spec/plan gate.

## Personas

### The Pipeline Operator
- **Role:** Runs spec-flow pieces through spec → plan → execute. Wants the thinking concentrated at plan time so execution is predictable and cheap.
- **Goals:** Execute runs on Sonnet without surprises; no babysitting; pay for Opus only where judgment actually happens.
- **Pain points today:** Execute discovers work the plan missed and stops or improvises; `tdd-red` designs tests live; Opus drives execution purely for its context window.
- **Behaviors:** Invests in a dense plan, approves it, hands a locked plan to a cheap executor, reviews the result.

### The Plugin Maintainer
- **Role:** Maintains the spec-flow plugin, which is installed across many repos and machines.
- **Goals:** Recurring *pipeline* defects (not project-specific ones) surface globally so the plugin self-hardens, rather than being rediscovered in every repo.
- **Pain points today:** A plugin defect that appears once per repo never crosses a per-repo recurrence threshold; the plugin's own field failures are invisible in aggregate. Reflection findings append to per-repo backlogs and stay there.
- **Behaviors:** Reviews batched hardening proposals; promotes confirmed plugin patterns into spec-flow self-improvement pieces in the plugin's home repo.

## Functional Requirements

### FR-001: Unified research artifact feeds both spec and plan
**Statement:** A single deep codebase-gathering step runs once, before spec brainstorm, in an isolated context, and writes a durable research artifact to the piece's spec directory. Both the spec skill (for proposed answers during brainstorm) and the plan skill (as primary codebase context) consume the same artifact; the plan skill no longer re-derives codebase context from scratch. The artifact folds in what the L-10 convention scan and the plan-stage `introspection.md` gather today, so there is exactly one gathering pass, not three.
**Priority:** P0
**Linked metrics:** SC-001

#### User Stories
**US-001** — As a pipeline operator, I want spec and plan to share one research artifact so codebase context is gathered once and brainstorm questions arrive pre-answered, instead of paying for the same exploration twice.

**Acceptance Criteria:**
- [ ] A research artifact exists at `docs/prds/<prd-slug>/specs/<piece-slug>/research.md` before the first spec brainstorm question, committed to the piece branch (verified via `git log --oneline -- research.md` showing a commit before the first spec Q&A commit).
- [ ] The research step is dispatched as an isolated sub-agent (Opus); its return value to the main thread is a structured summary ≤2K tokens; the on-disk artifact may be richer.
- [ ] The plan skill consumes `research.md` as primary context and emits `[RESEARCH-CONSUMED: <N> files]`, skipping the redundant `introspection.md` re-derivation; when the artifact is absent it emits `[RESEARCH-ABSENT: running full exploration]` and runs the legacy sweep.
- [ ] If the research sub-agent errors or returns empty, the spec skill emits `[RESEARCH-UNAVAILABLE: <reason>]` and falls back to the current L-10 behavior without blocking.

**Failure mode:** Research sub-agent errors → `[RESEARCH-UNAVAILABLE]`, spec proceeds on the legacy L-10 scan, plan runs its legacy sweep.

---

### FR-002: Plan concreteness contract
**Statement:** The plan skill produces an execution-ready plan: each phase specifies the exact file, the exact location within it, and the exact content or signatures to add — not "implement X." Genuine unknowns that cannot be resolved from the spec + codebase are recorded as explicit `[SPIKE: <unknown>]` markers, never left implicit. For doc-as-code phases (no test data), concreteness means the exact prose to write plus a branch-enumeration AC for every conditional in the deliverable (codifying the pi-011 finding). `qa-plan` enforces a concreteness floor and rejects vague phases and unmarked unknowns.
**Priority:** P0
**Linked metrics:** SC-002, SC-003

#### User Stories
**US-002** — As a pipeline operator, I want the plan to be a complete script so the executor transcribes rather than infers, eliminating avoidable execute-time discovery.

**Acceptance Criteria:**
- [ ] Each plan phase names the target file, the location/anchor within it, and the concrete content or signature to add; `qa-plan` flags any phase whose deliverable is non-specific ("implement", "handle", "add support for") as must-fix.
- [ ] Any decision the plan cannot resolve from spec + codebase is written as an explicit `[SPIKE: <unknown>]` marker; `qa-plan` flags an unresolved-but-unmarked ambiguity as must-fix.
- [ ] For doc-as-code phases, every conditional branch in the deliverable has a corresponding branch-enumeration AC; `qa-plan` flags a missing branch AC as must-fix.
- [ ] A piece whose plan passes the concreteness floor produces zero unmarked execute-time discoveries (measured: Step 6c discovery events that are *not* attributable to a `[SPIKE]` marker).

**Failure mode:** Plan cannot reach the concreteness floor for a phase and the unknown is not spike-able → `qa-plan` returns must-fix; the phase is re-planned, not passed downstream.

---

### FR-003: Test data defined upfront for TDD phases
**Statement:** For TDD phases, the plan defines the concrete test cases — inputs and expected outcomes — so `tdd-red` transcribes the oracle from the plan instead of designing it at execute time. Test-case design becomes a plan-stage (Opus) decision, not an execute-stage one.
**Priority:** P0
**Linked metrics:** SC-002

#### User Stories
**US-003** — As a pipeline operator, I want expected outcomes defined in the plan so `tdd-red` writes the failing test from a spec, not from its own live judgment about what "correct" means.

**Acceptance Criteria:**
- [ ] Each TDD phase in the plan includes a `Test Data` block: concrete inputs and expected outputs/oracle for each behavior under test.
- [ ] `tdd-red` reads the phase's `Test Data` block and authors the failing test from it; it does not invent inputs or expected outcomes not present in the plan.
- [ ] When a TDD phase's expected outcome genuinely cannot be predicted (non-deterministic / real external behavior), the phase carries a `[SPIKE]` marker instead of fabricated test data.
- [ ] `qa-plan` flags a TDD phase with no `Test Data` block and no `[SPIKE]` marker as must-fix.

**Failure mode:** Expected outcome is unpredictable → phase marked `[SPIKE]`; the spike agent resolves the real outcome, which is recorded as the test data before the TDD phase runs.

---

### FR-004: Sonnet-driven coordinator on file-based state
**Statement:** The execute coordinator runs on Sonnet by default. All state required to resume — phase progress, journal, triage decisions, model assignments — is persisted to disk so a fresh context re-derives the pipeline position from disk without relying on the in-context transcript. The execute pre-flight *already* nudges toward Sonnet — it prompts (Override / Change-now / Cancel) when the active model is **not** Sonnet (`bbcf58c`), so Sonnet-default is already the enforced posture. This piece generalizes that single execute-start prompt into a per-stage **model policy**: coordinator and implementer are assigned Sonnet, and only the exceptions are flagged (the FR-005 spike path and operator override), so an Opus spike inside execute is sanctioned rather than treated as a violation. The Final Review circuit-breaker becomes configurable (default raised for doc-as-code pieces, codifying the pi-011 finding that a hard limit of 3 is wrong for non-TDD pieces).
**Priority:** P0
**Linked metrics:** SC-004, SC-002

#### User Stories
**US-004** — As a pipeline operator, I want the coordinator to run on Sonnet and re-derive everything from disk, so I stop paying for Opus's context window just to keep a long-running task in memory.

**Acceptance Criteria:**
- [ ] Execute assigns Sonnet to the coordinator and implementer by default; the model policy reports the per-stage assignment and flags only exceptions (FR-005 spike / operator override), rather than the current single execute-start prompt that fires when the active model is non-Sonnet (`bbcf58c`).
- [ ] All resume-critical coordinator state is on disk; a coordinator started in a fresh context (after `/clear` or interruption) resumes from the last clean checkpoint using only on-disk state, re-running no passing phase.
- [ ] The Final Review circuit-breaker limit is read from `.spec-flow.yaml` (configurable; documented default that differs for doc-as-code vs TDD pieces) rather than hard-coded.
- [ ] No coordinator decision required to resume is held only in the transcript (verified: a forced fresh-context resume mid-piece reaches the same next action).

**Failure mode:** Resume-critical state missing from disk → coordinator emits `[STATE-INCOMPLETE: <field>]` and escalates rather than guessing.

---

### FR-005: Opus spike agent and model policy
**Statement:** When execute reaches a `[SPIKE]` phase, it dispatches a dedicated spike agent on Opus in an isolated context — the one sanctioned path for "a thinking model infers as it goes" during execution, exactly parallel to why spec/plan are Opus. The spike agent investigates the genuine unknown, returns the resolved answer, and the resolution is recorded to a durable artifact so the unknown becomes known (and feeds FR-003 test data where applicable). An operator override allows forcing Opus for a specific piece/phase at invocation. Execute never silently upgrades a non-`[SPIKE]` phase to Opus to compensate for an under-specified plan.
**Priority:** P0
**Linked metrics:** SC-005

#### User Stories
**US-005** — As a pipeline operator, I want genuine unknowns resolved by an isolated Opus spike agent whose answer is recorded, so the mechanical work proceeds on Sonnet and the unknown never recurs as a surprise.

**Acceptance Criteria:**
- [ ] A `[SPIKE]` phase dispatches the spike agent on Opus in an isolated context; the agent's return is a structured resolution recorded to a durable artifact in the piece directory.
- [ ] A non-`[SPIKE]` phase that the implementer cannot complete on Sonnet halts and routes to plan amendment (Step 6c) — it does not silently re-run on Opus.
- [ ] An operator can force Opus for a named piece/phase at invocation (documented override flag/config).
- [ ] The spike resolution is consumable downstream (e.g., as FR-003 test data) so the same unknown is not spiked twice within a piece.

**Failure mode:** Spike agent cannot resolve the unknown → it returns `BLOCKED` with what it tried; execute escalates to the operator with the spike's findings (no fabricated resolution).

---

### FR-006: Repo-level self-hardening flywheel
**Statement:** Recurring patterns are made countable against a durable, stable-ID registry at `docs/patterns.yaml` in the repo. This registry holds **repo-level** patterns (charter/project/PRD concerns) and correlates them across PRDs within that repo. When a finding is recorded, the flywheel proposes a match to an existing pattern ID (or "new"); the operator confirms the match and scope at the Step 6c triage moment (LLM-proposed, human-confirmed) — no silent write. Count = number of dated occurrences. When a pattern reaches the threshold (default 2, configurable), a hardening proposal is surfaced in a single batched operator review and routed to its repo home: a charter amendment, a local QA hardening, or PRD work. All writes and promotions are operator-gated; the step is non-blocking.
**Priority:** P1
**Linked metrics:** SC-003, SC-005

#### User Stories
**US-007** — As a pipeline operator, I want recurring repo-level patterns to count against a registry and propose the right hardening (charter / QA / PRD) once they hit the threshold, with my confirmation, so the next plan starts denser.

**Acceptance Criteria:**
- [ ] Repo-level patterns are recorded to `docs/patterns.yaml` with stable IDs; each occurrence carries provenance (piece, date, source finding); count = occurrences length.
- [ ] On recording a finding, the flywheel proposes a match to an existing pattern ID or "new"; the operator confirms the classification and scope before any write (no silent write).
- [ ] When a pattern's count ≥ threshold (default 2, configurable in `.spec-flow.yaml`), a hardening proposal is surfaced in a single batched operator review, routed to its repo home (charter amendment / local QA hardening / PRD work).
- [ ] Rejected proposals are recorded with rationale and not re-proposed; the flywheel step is non-blocking — failure does not affect the execute result.

**Failure mode:** `docs/patterns.yaml` unwritable → flywheel emits `[FLYWHEEL-DEGRADED: repo registry unavailable]` and does not block execute; the finding still flows to normal end-of-piece reflection.

---

### FR-007: Plugin-global cross-install flywheel
**Statement:** **Plugin-level** patterns (spec-flow pipeline/agent/QA defects, distinct from project concerns) are recorded to a machine-global registry under `~/` (proposed `~/.claude/spec-flow/patterns.yaml`, path confirmed at spec time) that survives plugin updates and is read/written by any repo's flywheel run on that machine. This is what lets a defect appearing once per repo correlate across all repos on the machine. Same stable-ID + human-confirmed-match + count mechanics as FR-006. When a plugin pattern reaches the threshold, the proposal is to create a spec-flow self-improvement piece in the plugin's home repo. Cross-machine correlation is an explicit non-goal (no shared remote backend).
**Priority:** P1
**Linked metrics:** SC-005

#### User Stories
**US-006** — As a plugin maintainer, I want plugin-level defects that each appear once in different repos to correlate in one machine-global registry, so a recurring spec-flow weakness is detected and hardened instead of rediscovered everywhere.

**Acceptance Criteria:**
- [ ] Plugin-level patterns are recorded to a machine-global registry under `~/` (path confirmed at spec time) that survives plugin updates and is read/written by any repo's flywheel run on that machine.
- [ ] Each plugin-pattern occurrence carries provenance including the originating repo; the operator confirms scope = plugin before any write (no silent write).
- [ ] When a plugin pattern's count ≥ threshold, the batched review proposes creating a spec-flow self-improvement piece in the plugin's home repo (operator-gated).
- [ ] If the machine-global registry is unwritable, the flywheel emits `[FLYWHEEL-DEGRADED: plugin registry unavailable]`, repo-level recording (FR-006) continues, and execute is not blocked. Cross-machine correlation is documented as out of scope.

**Failure mode:** Two machines hit the same plugin defect → not correlated (per-machine registries); accepted limitation, see Non-Goals.

---

### FR-008: Scoping spike for mid-execution changes
**Statement:** Any mid-execution scope change is routed through one disciplined workflow before any code change, never applied as a mid-stream patch. Two triggers converge on it: **(a) agent-discovered** found-work surfaced at Step 6c (`qa-phase`/`qa-phase-lite` findings, AC-matrix NOT-COVERED rows, Build missing-prerequisite escalations) and **(b) operator-initiated** change requests issued while execute is running ("add X", "change Y", "I think we should do X"). Both triggers follow the **same regime**: the change enters Step 6c triage rather than being applied mid-stream, and a size/complexity threshold (the existing Step 6c diff-ratio gate, default 50% of cumulative diff) decides the path. Above the threshold, a scoping spike runs first — the FR-005 spike agent (Opus, isolated context) understands the change's full scope and enumerates its task list / blast-radius, recording a durable scoping artifact that `plan-amend` then consumes. Below the threshold, the change amends the plan directly as today (no scoping spike). Either way the resulting amendment phases are added to the plan/task list at a dependency-correct position and do **not** preempt the in-progress phase — current work-in-progress completes first; preemption occurs only when the operator explicitly force-stops current work.
**Priority:** P0
**Linked metrics:** SC-002, SC-006

#### User Stories
**US-008** — As a pipeline operator, when I realize mid-execution that something must be added or changed (or an agent surfaces found-work), I want it scoped and folded into the plan before any code is written, so the change is implemented completely and in order — instead of patched halfway, taking over my current work, or forgotten.

**Acceptance Criteria:**
- [ ] A mid-execution change — agent-discovered OR operator-initiated ("add/change/do X") — enters the Step 6c triage workflow and is not applied as a mid-stream patch.
- [ ] When the change exceeds the size/complexity threshold (the Step 6c diff-ratio gate, default 50% of cumulative diff), a scoping spike (FR-005 agent, Opus, isolated) runs before `plan-amend` and writes a durable scoping artifact (scope + enumerated task list) that `plan-amend` consumes; below the threshold the change amends the plan directly with no scoping spike.
- [ ] The scoping artifact is recorded to the piece directory and referenced by the resulting `chore(plan): amend` commit and its `.discovery-log.md` row (audit trail).
- [ ] Amendment phases produced by the workflow are added to the plan/task list at a dependency-correct position and do NOT preempt the in-progress phase; current WIP completes first. Preemption occurs only when the operator explicitly force-stops current work.
- [ ] If the scoping spike returns `BLOCKED` (cannot scope the change), execute escalates to the operator with the spike's findings; no plan amendment is produced and no mid-stream patch is applied.
- [ ] No execute path applies an above-threshold mid-execution change without a scoping spike followed by a plan amendment; `qa-plan` / review-board verify the gate (NN-P-002).

**Failure mode:** Scoping spike cannot resolve the change's scope → returns `BLOCKED` with findings; execute escalates to the operator (no fabricated scope, no mid-stream patch, no plan amendment).

---

### FR-009: Investigation-First Design Protocol (Deliberation)
**Statement:** Before any user-facing question is asked, the spec, prd, small-change, and charter skills run a structured multi-agent deliberation protocol. **Tier 1** is a 5-phase pipeline: a coordinator, parallel per-decision-unit-cluster viability agents, a synthesis pass, a parallel single-model multi-lens adversarial board, and a convergence phase — executed across four calling skills (spec, prd, small-change, charter) with a configurable depth policy (full/lite/off). The output is a structured `deliberation.md` artifact with 7 core sections; the plan skill consumes the deliberation's recommendation so design decisions survive into implementation. Only questions the protocol could not resolve are surfaced to the operator, each traceable to a finding via a stable `VOQ-N` ID. **Tier 2** is an answer-validation loop that auto-fires a lite scoped `deliberation-validate` pass when an operator's free-form answer introduces an assertion outside the evaluated path-set, returning CONFIRM / FLAG-HARD / FLAG-SOFT and making grounding bidirectional. The protocol also includes an Opus pre-flight (FR-009-N) that recommends Opus for spec/prd/plan/charter calls (the inverse of execute's Sonnet check). Together: (a) the protocol runs before any user-facing question; (b) Tier 2 validates the operator's own answers against the deliberation's path-set; (c) the output is a structured `deliberation.md` (7 core sections + optional `## Validation Rounds` section appended by Tier 2); (d) only unresolved questions are asked, each traceable to a finding; (e) the plan skill consumes the recommendation so design decisions survive intact into implementation.
**Priority:** P0

#### User Stories
**US-009** — As a pipeline operator, I want the spec/prd/charter/small-change skills to investigate the problem space before asking any questions, to validate my own free-form answers against that investigation, and for the plan skill to build on it — so that every design choice (mine or the AI's) that reaches the spec is grounded, and implementation follows the approved approach without re-deriving it.

**Acceptance Criteria:**
- [ ] Full FR-009 AC set: AC-1 through AC-24 (including AC-10b) from the spec-preresearch spec — see `docs/prds/exec-ready/specs/spec-preresearch/spec.md`.

**Failure mode:** Deliberation fails on any of the 5 fatal triggers defined in `reference/deliberation-artifact.md` (Phase A/C/E BLOCKED, `deliberation.md` missing-or-empty after Phase E, or its commit failing) → the calling skill emits `[DELIBERATION-UNAVAILABLE]` and falls back to the current brainstorm flow. (Note: `depth=off` is the separate `[DELIBERATION-SKIPPED]` path, and a Phase D all-BLOCKED board is a non-fatal partial — neither is a fatal trigger.)

## Non-Functional Requirements

### NFR-001: Research and spike agents are context-isolated
**Statement:** The FR-001 research agent and the FR-005 spike agent always run in fresh, isolated contexts (no brainstorm or coordinator history). Each returns a structured summary ≤2K tokens to the main thread; richer detail lives in the on-disk artifact.
**Priority:** P0
**Linked metrics:** SC-001

### NFR-002: Coordinator state is fully re-derivable from disk
**Statement:** No resume-critical coordinator state exists only in the in-context transcript. A coordinator re-started in a fresh context reaches the same next action from on-disk state alone. This is the property that makes a cheap-model coordinator viable (G-4).
**Priority:** P0
**Linked metrics:** SC-004

### NFR-003: Backward compatibility — additive
**Statement:** All changes are additive and backward-compatible within the current major (NN-C-003). Pieces without a research artifact, concreteness contract, or test-data blocks run current spec/plan/execute behavior. The flywheel and the model policy are opt-out via `.spec-flow.yaml`.
**Priority:** P0
**Linked metrics:** —

### NFR-004: Plugin version bump and self-containment
**Statement:** Each piece that changes plugin behavior bumps the plugin version (NN-C-009) and keeps every new/edited agent self-contained with a bare `name:` (NN-C-004, NN-C-008). The root `plugin.json` and `.claude-plugin/plugin.json` versions are kept in sync (the 5.2.1 skew is corrected when first touched).
**Priority:** P1
**Linked metrics:** —

## Edge Cases & Failure Modes

| Scenario | Expected behavior | FR |
|---|---|---|
| Research sub-agent errors | `[RESEARCH-UNAVAILABLE]`; spec falls back to L-10; plan runs legacy sweep | FR-001 |
| Plan cannot concretize a phase and it is not spike-able | `qa-plan` must-fix; phase re-planned, not passed downstream | FR-002 |
| TDD expected outcome genuinely unpredictable | Phase marked `[SPIKE]`; spike resolves real outcome → becomes test data | FR-003, FR-005 |
| Coordinator interrupted mid-piece (`/clear`, laptop close) | Fresh context resumes from disk to the same next action; no passing phase re-run | FR-004, NFR-002 |
| Non-`[SPIKE]` phase can't complete on Sonnet | Halt → plan amendment (Step 6c); no silent Opus upgrade | FR-005 |
| Operator requests a change mid-execute ("add/change X") | Enters Step 6c; above threshold → scoping spike → plan amendment → queued task; not applied mid-stream | FR-008 |
| Mid-execution change scoped while a phase is in progress | Amendment phases queued at dependency-correct position; current WIP finishes first unless operator force-stops | FR-008 |
| Scoping spike cannot scope a mid-execution change | `BLOCKED` with findings; execute escalates; no amendment, no mid-stream patch | FR-008 |
| Trivial mid-execution change below size threshold | Amends the plan directly (no scoping spike), as today | FR-008 |
| Doc-as-code piece needs >3 Final Review iterations | Configurable circuit-breaker (raised default) allows it; cascade detection still applies | FR-004 |
| Same finding appears in two repos (plugin scope) | Both occurrences land in the machine-global `~/` registry; 2nd write trips threshold → spec-flow self-improvement proposal | FR-007 |
| Same finding twice in one repo (repo scope) | Two occurrences in `docs/patterns.yaml`; threshold trips → charter/QA/PRD proposal | FR-006 |
| Two machines, same plugin defect | Not correlated (per-machine registries) — accepted limitation; see Non-Goals | FR-007 |
| Flywheel match ambiguous | LLM proposes match; operator confirms/corrects at Step 6c; no silent assignment | FR-006, FR-007 |

## Success Metrics

- **SC-001:** On pieces with a research artifact, spec Q&A rounds ≤3 (baseline 5–8). — FR-001
- **SC-002:** ≥80% of execute phases complete on Sonnet without escalation or unmarked discovery on pieces whose plan passed the concreteness floor. — FR-002, FR-003, FR-004, FR-008
- **SC-003:** Avoidable execute-time discoveries (Step 6c events not attributable to a `[SPIKE]`) trend down across a PRD: the second half of a PRD's pieces show fewer than the first half. — FR-002, FR-006
- **SC-004:** A coordinator forced into a fresh context mid-piece resumes correctly from disk on 100% of attempts; execute runs on Sonnet by default. — FR-004, NFR-002
- **SC-005:** Opus token spend per piece trends down across a PRD as spikes decrease (proxy: `[SPIKE]` count per piece declines). — FR-005, FR-006, FR-007
- **SC-006:** Mid-execution changes that route through a scoping spike produce a complete plan amendment — measured: no second amendment targeting the same change within the same piece (the change was fully scoped on the first pass). — FR-008

## Priority Tiers

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| FR-001 | Unified research artifact | P0 | One gathering pass feeds spec + plan; prerequisite for dense plans |
| FR-002 | Plan concreteness contract | P0 | The core — makes execute mechanical |
| FR-003 | Test data upfront | P0 | Moves test design from execute to plan |
| FR-004 | Sonnet coordinator on file state | P0 | Removes the Opus-as-driver cost; enables cheap mechanics |
| FR-005 | Opus spike agent + model policy | P0 | The sanctioned thinking path; keeps "dumb execute" honest |
| FR-006 | Repo-level flywheel | P1 | Drives the spike/Opus curve down; repo charter/QA/PRD hardening |
| FR-007 | Plugin-global flywheel | P1 | Cross-install plugin learning; machine-global correlation |
| FR-008 | Scoping spike for mid-execution changes | P0 | Routes all mid-run scope change (agent + operator) through scope→amend→execute; kills mid-stream patching |
| FR-009 | Investigation-first deliberation protocol | P0 | Grounds every design choice before spec authoring begins; bidirectional validation removes post-hoc re-derivation |
| NFR-001 | Agent isolation | P0 | NN-C-008; ≤2K returns |
| NFR-002 | File-derivable state | P0 | The property that makes cheap coordination viable |
| NFR-003 | Backward compat | P0 | NN-C-003 |
| NFR-004 | Version bump + self-containment | P1 | NN-C-004/008/009 |

## Assumptions

- **Technical:** `Agent` (isolated sub-agents), per-stage model selection, and `.spec-flow.yaml` config are available (verified in the capability audit, 2026-06-06).
- **Technical:** spec-flow already ships the execute loop, journal resume, auto Final Review with fix/re-review, and reflection agents — this PRD upgrades plan density, model placement, and learning, not the loop mechanics.
- **Technical:** The plan-stage `introspection.md` already performs deep codebase gathering; FR-001 unifies it with the pre-spec scan rather than adding a third mechanism.
- **User behavior:** The operator invests in a dense plan at the Opus gate and reviews flywheel proposals; nothing is auto-applied.
- **Pipeline:** Pieces reaching execute have passed the human spec and plan gates.

## Open Questions

| Question | Owner | Status |
|---|---|---|
| Exact machine-global plugin-registry path (`~/.claude/spec-flow/patterns.yaml`?) and update-stability guarantees | spec author (FR-007 piece) | open — proposal `~/.claude/spec-flow/patterns.yaml` |
| Pattern occurrence granularity: one per piece where it appeared, or one per reflection finding? | spec author (FR-006/FR-007 pieces) | open |
| Doc-as-code "exact prose" concreteness bar — how exact is enforceable by `qa-plan`? | spec author (FR-002 piece) | open |
| Test-data-upfront for integration/non-deterministic phases — `[SPIKE]` fallback sufficient? | spec author (FR-003 piece) | open — lean: yes, spike then record |
| Which `.spec-flow.yaml` keys: `flywheel_threshold`, `circuit_breaker.docs`, `model_policy`? | spec author (FR-004/006/007 pieces) | open |
| How does execute reliably detect an operator-initiated mid-execution change request vs normal operator input/answers? | spec author (spike-agent / FR-008) | open |
| Spike-first threshold for mid-execution changes — reuse the 50% diff-ratio gate as-is, or add a separate `.spec-flow.yaml` key? | spec author (spike-agent / FR-008) | open — lean: reuse the 50% gate, configurable |

## Non-Negotiables (Product)

### NN-P-001: Human approval gate on spec and plan is never removed
- **Type:** Rule
- **Statement:** Research, density, and model placement reduce rounds and cost but never remove the human review-and-sign-off on spec and plan. No spec or plan advances to execute without explicit operator approval.
- **Scope:** FR-001, FR-002, FR-003 and any research/spec/plan additions
- **Rationale:** Spec and plan encode design intent; the human is the only ground truth on "is this the right thing, scoped right."
- **How QA verifies:** `qa-spec`/`qa-plan` confirm sign-off remains; any diff removing the sign-off prompt is must-fix.

### NN-P-002: No silent or mid-stream execute-time change
- **Type:** Rule
- **Statement:** Execute never silently resolves a spec/plan ambiguity and proceeds, and never applies a mid-execution scope change as a mid-stream patch. Genuine planned unknowns are explicit `[SPIKE]` markers resolved by a recorded spike agent. ANY mid-execution scope change — whether agent-discovered (Step 6c) or operator-initiated ("add/change/do X" during execute) — enters Step 6c triage: above the size/complexity threshold it is first scoped by a recorded spike agent, below it amends the plan directly; either way it routes through plan amendment for synchronous operator triage and executes in dependency order. There is no in-execute decision log that ships unreviewed and no mid-stream fix that bypasses the Step 6c → amend → execute workflow.
- **Scope:** FR-002, FR-005, FR-008, and the execute path
- **Rationale:** An execute-time discovery — or an operator's mid-run change — is a plan-incompleteness or scope-growth signal; applying it mid-stream destroys the feedback the flywheel needs, produces partial fixes, and violates the synchronous-discovery doctrine.
- **How QA verifies:** Review-board / `qa-plan` confirm every planned unknown is a `[SPIKE]` (with recorded resolution), and every above-threshold mid-execution change is a scoping spike + Step 6c amendment; no silent decision artifact and no mid-stream patch exists.

### NN-P-003: Execute loop is operator-invoked only
- **Type:** Rule
- **Statement:** No automated mechanism starts execute. The operator invokes it deliberately; the loop then runs to completion, but the initial invocation is always manual.
- **Scope:** FR-004
- **Rationale:** Unattended execution is powerful; it must never start silently.
- **How QA verifies:** Execute contains no self-invocation path on an unstarted piece.

### NN-P-004: Flywheel writes and promotions are operator-gated
- **Type:** Rule
- **Statement:** Both registries (repo `docs/patterns.yaml` and machine-global `~/`) are written only after operator confirmation at triage. Pattern matches are LLM-proposed, human-confirmed. Promotions (charter amendments, QA hardening, spec-flow self-improvement pieces) require operator approval. Rejected proposals are recorded with rationale and not re-proposed. Nothing is auto-applied; nothing is silently deferred.
- **Scope:** FR-006, FR-007
- **Rationale:** Charter rules are binding and manifest pieces are real work; both demand human intent. Silent deferral violates the no-silent-defer doctrine.
- **How QA verifies:** No flywheel code path writes a registry or proposes a promotion without a confirmation prompt; spec-compliance reviewer checks the gate.

### NN-P-005: Thinking on Opus, mechanics on Sonnet — no silent upgrade
- **Type:** Rule
- **Statement:** Spec authoring, plan authoring, all adversarial gates, and spikes run on Opus. Execute (coordinator, implementer, test transcription) runs on Sonnet by default. Execute never silently upgrades a non-`[SPIKE]` phase to Opus to compensate for an under-specified plan — it halts and routes to plan amendment or a `[SPIKE]`. Operator override is explicit.
- **Scope:** FR-004, FR-005, FR-009
- **Rationale:** Concentrating thinking upstream is the entire cost model; a silent Opus upgrade in execute hides plan incompleteness and re-introduces the cost this PRD removes.
- **How QA verifies:** Model-policy check asserts stage→model assignment; any execute path that escalates a non-`[SPIKE]` phase to Opus without halting/override is must-fix.
