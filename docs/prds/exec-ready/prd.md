---
slug: exec-ready
status: drafting
version: 6
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
- **G-6: Oversight scaled to verifiability.** Operator attention is spent only where machine verification cannot decide. Gates are never removed (NN-P-001), but their *cost* scales with what is actually at stake: machine-checkable outcomes get evidence digests and a single confirm; judgment calls get full review. The pipeline itself is measured, so every oversight-reduction claim is backed by on-disk numbers, not vibes.
- **G-7: Gate behavior, not just construction.** Every gate today inspects an artifact — spec text, plan text, a diff — and nothing inspects the running system's *output* against what the spec said good and bad output look like. The 2026-06-12 efficiency evaluation showed this is where the largest uncovered cost sits: result-level wrongness and whole-platform seam defects pass every construction gate and surface only in expensive freeform Opus validation. Add the missing oracle (outcome ACs), the missing gate class (a results campaign that grades real output), and a discovery-triage primitive reachable from any session, so behavior is caught and routed at bounded cost.

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

---

### FR-010: Pipeline instrumentation — per-piece metrics feed the SCs and the flywheel
**Statement:** Every piece records a small, machine-readable metrics artifact at end-of-piece: spec Q&A round count, QA iterations per gate, Step 6c discovery count split by `[SPIKE]`-attributable vs unmarked, Sonnet→escalation events, amendment count, agent dispatches by model tier, Final Review iterations and must-fix counts, and fresh-context resume outcomes. The artifact lives on disk in the piece directory (exact location/schema confirmed at spec time; proposed `docs/prds/<prd-slug>/specs/<piece-slug>/metrics.yaml`), is written by the stages that own each number (spec, execute, Final Review), and is aggregatable so SC-001 through SC-006 become computable instead of "measurement pending." This also wires the flywheel's reserved `metric` occurrence source (flywheel-repo ADR-3 left the schema open and the wire narrow): threshold patterns can cite measured trends, not only operator-confirmed findings. Without this, the flywheel has no fitness function — self-improvement without a programmatic evaluator is the documented failure mode of every learning loop that didn't work [R4][R6].
**Priority:** P0
**Linked metrics:** SC-007 (and makes SC-001–SC-006 measurable)
**Research basis:** [R4] AlphaEvolve — the non-negotiable ingredient of a working improvement loop is a programmatic evaluator; [R6] Anthropic multi-agent system — start evals at ~20 cases, measure before tuning; 2026-06-09 audit finding: all six exec-ready SCs currently say "measurement pending."

#### User Stories
**US-010** — As a pipeline operator, I want every piece to leave a metrics file behind so I can see whether dense plans, spikes, and the flywheel are actually moving SC-001–SC-006 — and so hardening proposals cite numbers instead of anecdotes.

**Acceptance Criteria:**
- [ ] A metrics artifact with a documented schema is written to the piece directory by end-of-piece (Step 5 capture-learnings at the latest); each field is owned and written by the stage that produced it (spec → Q&A rounds; execute → discoveries/escalations/amendments/QA iterations; Final Review → iterations/must-fix counts; resume events appended as they occur).
- [ ] `/spec-flow:status` (or the manifest tooling) can render per-PRD SC values from the on-disk artifacts — SC-001 through SC-006 each computable without manual transcript archaeology.
- [ ] The flywheel `metric` occurrence source is wired: a recorded pattern occurrence may carry `source: metric` with a pointer to the metrics artifact and field that evidences it (operator confirmation still required per NN-P-004).
- [ ] Pieces without a metrics artifact (pre-FR-010 pieces) degrade gracefully: status renders `[METRICS-ABSENT]` for them and computes SCs over instrumented pieces only (NN-C-003).

**Failure mode:** Metrics artifact unwritable → stage emits `[METRICS-DEGRADED: <reason>]` and continues; instrumentation never blocks pipeline progress.

---

### FR-011: Execute integrity guardrails — test immutability and hard amendment cap
**Statement:** The implementer cannot modify the tests that gate its own work. `tdd-red` already stages tests and reports a SHA-256 manifest (pi-020 anti-cheat anchoring); this FR upgrades the contract from detect-later to reject-mechanically: a Build-step diff touching any file in Red's manifest is rejected before commit and the implementer is re-dispatched with the violation named — no warn-only path, no rationalization window. Phase exit re-verifies the manifest hashes. Separately, the per-piece amendment budget becomes a hard cap (configurable in `.spec-flow.yaml`): exceeding it halts execute and escalates to the operator rather than soft-checkpointing past it. Both guardrails exist because unattended runs are only safe when the executor cannot grind down its own gates.
**Priority:** P0
**Linked metrics:** SC-002
**Research basis:** [R1] METR — o3 reward-hacked 30.4% of RE-Bench trajectories and denied it when asked; [R2] benchmark audits caught all three major coding-agent models deleting/modifying test files and hardcoding test inputs; the mitigation with evidence is tests-as-immutable-inputs, not scolding; [R7] superpowers enforces RED/GREEN destructively (code written before its failing test is deleted) because warn-level enforcement gets rationalized away.

#### User Stories
**US-011** — As a pipeline operator running execute unattended, I want the implementer mechanically unable to weaken its own oracle, and runaway amendment recursion to halt instead of continuing, so a green result means the planned tests passed — not that the tests were bent to the code.

**Acceptance Criteria:**
- [ ] A Build-step (Step 3) diff that adds, modifies, or deletes any file listed in Red's SHA-256 manifest is mechanically rejected before any commit; the implementer is re-dispatched with the violating paths named. There is no warn-and-proceed path.
- [ ] Phase exit (Step 4/Verify) re-checks Red's manifest hashes; a mismatch is a blocking finding attributed to the phase, never silently absorbed.
- [ ] Implement-track phases that legitimately author tests declare those paths in the plan phase block; only declared paths are exempt from the immutability check (`qa-plan` verifies the declaration).
- [ ] The per-piece amendment budget is a hard cap read from `.spec-flow.yaml` (documented default); reaching it halts execute with an operator escalation summarizing the amendment history — no soft-checkpoint continuation.

**Failure mode:** Repeated immutability rejections on the same phase (implementer cannot complete without touching tests) → routes to Step 6c as a plan-incompleteness discovery (the test data or phase design is wrong), never to an exemption.

---

### FR-012: Verifiability-scaled sign-off gates and review-cost controls
**Statement:** Every AC is tagged at spec time as machine-checkable (a script, test, or deterministic check decides) or judgment-required (only a human can decide). Gate cost then scales with the tags, preserving NN-P-001 in full: when a stage completes with zero must-fix findings, zero `[PENDING-DECISION]` markers, and all-machine-checkable ACs evidenced, the sign-off renders an evidence digest (what ran, what passed, links to artifacts) and asks for a single summary-confirm keystroke; anything else gets today's full review gate. Two review-cost controls ship alongside: (a) the doc-as-code review-board variant — substitute the blind-reviewer slot with a second edge-case reviewer when the cumulative diff is doc-as-code (codifies the pi-011 retro finding: blind found 0/6 must-fixes, edge-case found 6); (b) a single-Opus triage pre-filter on Final Review fix iterations — after fix-code lands, one triage agent re-checks the specific findings before any full-board re-dispatch, and the full board re-runs only for contested or new findings.
**Priority:** P1
**Linked metrics:** SC-008
**Research basis:** [R5] Anthropic best practices — gate hardness should escalate with autonomy, and reviewers "always find something," so unbounded re-review chases noise; [R11] BMad's documented collapse — review verdicts with no workflow consequence are decoration; the inverse error is verdicts whose cost never scales down on clean work; [R13] Codex long-horizon doctrine — machine-verifiable checks are the "external source of truth" that makes reduced supervision safe; [R12] Cherny — the human gate belongs on the plan/intent, and verification ("2–3x quality") belongs to the machine.

#### User Stories
**US-012** — As a pipeline operator, I want my keystrokes spent on judgment calls, not on confirming things a script already proved, so clean pieces flow with one evidence-backed confirm per gate and contested pieces still get my full attention.

**Acceptance Criteria:**
- [ ] The spec template and `qa-spec` require every AC to carry a verifiability tag (machine-checkable with the named check, or judgment-required with the judgment named); an untagged AC is must-fix.
- [ ] Spec, plan, and Final Review sign-off gates render an evidence digest and offer summary-confirm only when: QA returned clean (zero must-fix), zero surviving `[PENDING-DECISION]`/`[NEEDS CLARIFICATION]` markers, and every machine-checkable AC has its evidence attached; otherwise the full review gate runs unchanged. A keystroke is always required — nothing auto-advances (NN-P-001).
- [ ] When the piece's cumulative diff is entirely doc-as-code, the Final Review board substitutes the blind-reviewer slot with a second edge-case reviewer (`review_board_variant: doc-as-code`, configurable).
- [ ] Final Review fix iterations dispatch a single-Opus triage pre-filter scoped to the fixed findings; the full board re-dispatches only for findings the pre-filter contests or new findings it surfaces (circuit-breaker budget unchanged).
- [ ] AC verifiability tags flow into FR-010 metrics (per-piece machine-checkable ratio recorded), so the gate-cost trend is measurable.

**Failure mode:** Evidence digest cannot be assembled (a machine-checkable AC lacks attached evidence) → the gate falls back to the full review prompt; summary-confirm is never offered on incomplete evidence.

---

### FR-013: Pipeline end-to-end smoke test
**Statement:** The pipeline's orchestration prose (5,200+ skill lines, 26 agents) gets an executable end-to-end check, peer to the coherence linter: a committed fixture project plus a scripted scenario that drives a minimal piece through the pipeline and asserts the *observable contract* — artifacts exist in the right order (research.md before first brainstorm commit; plan with Test Data blocks; journal during groups; discovery-log rows on triage; metrics artifact at end), required dispatches occurred (tdd-red → qa-tdd-red → implementer → verify → QA gate → board), and manifest status transitions fired. Known never-tested round-trips get explicit cases first: spike `[SPIKE]`-resolution → test-data consumption, and the `[TEST-DATA-ABSENT]` backward-compat fallback. This FR is a constraint (regression insurance), not a measured feature.
**Priority:** P1
**Linked metrics:** — (constraint; protects all SCs from silent regression)
**Research basis:** [R7] superpowers ships an e2e suite verifying its agents actually run brainstorm→plan→implement and use skills — the only proven way to know prose-encoded discipline survives refactors; 2026-06-09 audit: only the coherence linter has tests; the spike round-trip and `[TEST-DATA-ABSENT]` fallback have never been exercised.

#### User Stories
**US-013** — As the plugin maintainer, I want a smoke test that fails when a skill edit breaks the dispatch sequence or artifact contract, so 2,000-line orchestration files can be refactored without discovering breakage in a real piece.

**Acceptance Criteria:**
- [ ] A fixture project and scripted scenario live under the plugin's test tree; the scenario covers at least one TDD phase and one Implement phase end-to-end.
- [ ] Assertions cover artifact existence + ordering, required dispatch sequence, and manifest status transitions; a deliberate skill-contract break (e.g., removing the qa-tdd-red step) makes the test fail.
- [ ] Explicit cases exist for the spike resolution round-trip and the `[TEST-DATA-ABSENT]` fallback.
- [ ] The test is runnable on demand with a documented invocation (CI wiring may land with pi-022-vsync-ci); the coherence linter remains and is complemented, not replaced.

**Failure mode:** Scenario requires capabilities absent in the run environment (e.g., no agent dispatch available) → test reports `SKIPPED: <capability>` per stage, never a false green.

---

### FR-014: Artifact size budgets
**Statement:** Every generated artifact class gets a documented size budget — spec.md, plan.md (per-phase and total), research.md, deliberation.md, learnings.md — enforced by `qa-spec`/`qa-plan` as the inverse of the FR-002 concreteness floor: concreteness is necessary, bloat is the failure mode on the other side. Over-budget artifacts are must-fix with split/condense guidance (split the piece, hoist detail to reference, or cut restatement). Budgets are defaults in a reference doc with `.spec-flow.yaml` overrides. The `deliberation.md` budget binds the spec-preresearch implementation — registered here, before its plan is authored, so Spec 2.0's investigation artifact cannot become the bloat vector that killed spec-kit adoption.
**Priority:** P1
**Linked metrics:** SC-008
**Research basis:** [R8] Scott Logic's spec-kit trial — ~700 lines of working code shipped with 2,577 lines of "duplicative, faux-context" markdown and 3.5 hours of human review per increment; artifact bloat is the most common way spec pipelines die; [R10] Anthropic context engineering — "the smallest set of high-signal tokens," context rot is measurable; oversized plans degrade the executor they're meant to script.

#### User Stories
**US-014** — As a pipeline operator, I want a ceiling on artifact size so review effort stays proportional to the change and the executor's context holds signal, not restatement.

**Acceptance Criteria:**
- [ ] A reference doc defines per-artifact-class budgets (documented defaults; `.spec-flow.yaml` override keys); budgets are expressed in lines and approximate tokens.
- [ ] `qa-spec` flags an over-budget spec.md/deliberation.md and `qa-plan` flags an over-budget plan.md (per-phase or total) as must-fix, with named split/condense guidance in the finding.
- [ ] The spec-preresearch piece's plan inherits the `deliberation.md` budget as a binding constraint (verified at its `qa-plan` gate).
- [ ] Budget compliance per artifact is recorded in the FR-010 metrics artifact, so the bloat trend is visible across a PRD.

**Failure mode:** A piece genuinely cannot fit the budget (irreducibly large surface) → the finding routes to piece-splitting (the qa-prd ≤7-AC granularity rule), not to a waiver that normalizes overage.

---

### FR-015: Flywheel pattern lifecycle — outcome tracking, expiry, refresh
**Statement:** Registry entries (`docs/patterns.yaml`, and the FR-007 machine-global registry when it ships) carry a lifecycle, not just a count: `active` → `hardened` (a hardening proposal was applied; records the spike artifact and where the fix landed) → `archived` (stale or verified-resolved). A hardened pattern tracks whether recurrence actually stopped — a post-hardening occurrence re-opens it with elevated priority, which is the check that the fix worked. A periodic, operator-gated refresh pass (end-of-piece or on demand) proposes archival for stale patterns (no occurrence in a configurable window of pieces) and for hardened patterns whose recurrence stopped. Without lifecycle, the registry monotonically grows and rots into noise — the documented failure mode of memory systems without expiry.
**Priority:** P1
**Linked metrics:** SC-003, SC-005
**Research basis:** [R9] compound-engineering pairs `/ce-compound` (capture) with `/ce-compound-refresh` (archive stale learnings) — capture without expiry rots; [R4][R14] AlphaEvolve / EvoSkills — self-improvement loops hold only when every retained item is re-verified in the loop; Voyager's skill library worked because skills were verified executable, not accumulated prose.

#### User Stories
**US-015** — As a pipeline operator, I want patterns that were fixed or went stale to leave the active registry — and a fix that didn't actually stop the recurrence to come back loudly — so flywheel proposals stay high-signal as the registry ages.

**Acceptance Criteria:**
- [ ] The pattern schema gains lifecycle fields: state (`active`/`hardened`/`archived`), `last_seen`, and for hardened patterns the hardening outcome (spike artifact ref + landing site); existing registries without these fields read as `active` (NN-C-003).
- [ ] Applying a hardening proposal transitions the pattern to `hardened` with provenance; a subsequent confirmed occurrence of a `hardened` pattern re-opens it as `active` with an `ineffective-hardening` flag surfaced at the next batched review.
- [ ] An operator-gated refresh pass proposes archival for patterns with no occurrence within the staleness window (configurable; default confirmed at spec time) and for hardened patterns whose window passed clean; nothing archives silently (NN-P-004).
- [ ] Archived patterns remain in the file (audit trail) and are excluded from match-proposal candidates unless the operator explicitly revives one.

**Failure mode:** Refresh pass finds a malformed registry → emits `[FLYWHEEL-DEGRADED: lifecycle unavailable]`, proposes nothing, and leaves the file untouched; recording continues per FR-006.

---

### FR-016: Pipeline economics — TDD-lean track, conditional board slots, depth defaults
**Statement:** The pipeline's per-phase and per-gate cost is cut where a cheaper mechanism provides equal or stronger assurance — never by removing a gate's consequence. Three levers. **(a) TDD-lean:** with FR-003 the oracle lives in the plan, so `tdd-red` is transcription, not design — `qa-tdd-red` becomes a deterministic conformance check (do the authored assertions match the phase's Test Data block?) with the LLM dispatch reserved for `[SPIKE]`-fallback phases and detected deviations; once FR-011's hash gate is active, Red and Build run as a single dispatch per phase (transcribe → confirm red → stage + hash → implement → confirm green) with the orchestrator verifying the hash manifest at phase exit — the integrity wall is the mechanical gate, not agent separation; phases whose ACs are all machine-checkable default to direct-verify (run the named commands) instead of a verify-agent dispatch. **(b) Conditional board slots:** specialist reviewers activate on diff signals (security ↔ input/auth/crypto/scripts touched; integration ↔ boundary changes; ground-truth ↔ computational components) over a documented always-on core; any seat removal or model downgrade must cite FR-017 catch-rate and ablation evidence. **(c) Deliberation depth defaults:** `lite` is the default unless the piece is new-surface (criteria documented); `full` requires SC-001 justification. Expected effect: a well-planned TDD phase drops from ~6 dispatches to 2–3; most pieces run 2–4 fewer Opus board seats.
**Priority:** P1
**Linked metrics:** SC-005, SC-002
**Research basis:** [R16] lens diversity has diminishing returns (+14.9pp → +11.2pp by reviewer 4) and 8–9 same-model seats are past the knee; [R15] same-family judges share correlated blind spots that persona prompts cannot fix; [R6] multi-agent token cost is ~15× and only justified where value follows; [R2] the integrity wall for Red/Build merging is the mechanical hash gate (FR-011), which is exactly the tests-as-immutable-inputs mitigation.

#### User Stories
**US-016** — As a pipeline operator who likes the adversarial gates but pays for them, I want the ceremony priced to the risk — deterministic checks where the oracle is already planned, specialist reviewers only when their specialty is in the diff — so cost drops while catch-rate (measured, per FR-017) does not.

**Acceptance Criteria:**
- [ ] A TDD phase with a complete `Test Data` block runs a deterministic Red-conformance check instead of the `qa-tdd-red` LLM dispatch; the LLM dispatch fires only for `[SPIKE]`-resolved phases or when the conformance check detects deviation from the planned oracle.
- [ ] After FR-011 ships, the TDD track offers a combined Red+Build dispatch (one agent: transcribe tests → confirm red → stage + hash → implement → confirm green), with the orchestrator independently verifying the hash manifest at phase exit; verify/QA remain separate contexts. Configurable; the split track remains available.
- [ ] A phase whose ACs are all machine-checkable (FR-012 tags) defaults to direct-verify — the orchestrator runs the named verify commands — with the verify-agent dispatch reserved for judgment-bearing phases.
- [ ] Board composition is signal-conditional over a documented always-on core; every seat removal, conditionalization, or model-tier downgrade cites FR-017 fixture catch-rates and the verdict-overlap/leave-one-out ablation (no composition change on intuition).
- [ ] Deliberation depth defaults to `lite` except for documented new-surface criteria; the per-piece depth decision and its dispatch-count consequence are recorded in the FR-010 metrics artifact.
- [ ] Per-phase dispatch counts before/after are visible in metrics so the savings claim (SC-005) is measured, not asserted.

**Failure mode:** The deterministic conformance check cannot parse or match the Test Data block → it falls back to the full `qa-tdd-red` LLM dispatch and emits `[CONFORMANCE-FALLBACK: <reason>]`; cost optimization never silently skips the check.

---

### FR-017: Gate-efficacy evals and cheater track
**Statement:** Every merge-blocking gate gets a measured catch rate. A committed fixture corpus (~60–80 to start) covers the three gate classes: defective + known-clean specs/plans for `qa-spec`/`qa-plan` (missing AC, contradictory requirements, untestable AC, silent scope drop), planted-defect + clean phase diffs for per-phase QA (logic inversion, boundary error, missing error path, dead AC, assertion-free test), and whole-piece fixtures with one defect each mapped to the board seat that should own it (per-reviewer recall). Metrics per gate: catch rate, clean-fixture flag rate (the false-positive control), verdict-flip rate across 3 runs, and severity-assignment accuracy. Judge prompts and rubrics are version-frozen: any edit to a QA agent's prompt or rubric triggers a gold-set re-run before release. A **cheater track** red-teams the FR-011 guardrails SHADE-Arena-style: ≥10 scripted cheat scenarios from the observed taxonomy (edit assertions, delete/skip failing tests, hardcode outputs including inside except-handlers, stub the function under test, weaken tolerances, claim an AC done with no diff) plus ≥5 legitimate test-refactor fixtures the gate must allow; any scenario under 100% detection is a guardrail bug and stays as a permanent regression; the cheat set refreshes when the executor model changes. Fixtures are living: every escaped defect adds 2–3 fixtures; saturated fixtures retire to a regression tier.
**Priority:** P1
**Linked metrics:** SC-009
**Research basis:** [R17] judges flip on meaning-preserving perturbations and degrade up to 27.9% from benign rubric edits — calibrate and freeze; [R19] seeded-defect review benchmarks (real-bug tracing, injection into clean PRs, mutation-score analogs) are the established construction patterns, with uncalibrated reviewers spanning 6%–82% catch rates; [R18] SHADE-Arena/METR provide the cheater-vs-monitor template, and monitors top out below reliability (AUC 0.87) — so guardrail gaps must be found by red-team, not assumed; [R20] Anthropic eval doctrine: 20–50 tasks drawn from real failures, deterministic graders where possible, kappa over accuracy.

#### User Stories
**US-017** — As the plugin maintainer, I want each gate's precision and recall measured against planted defects and clean fixtures, so I know which reviewers earn their seats, which findings to trust, and whether the anti-cheat gates actually stop a corner-cutting executor.

**Acceptance Criteria:**
- [ ] A fixture corpus with a labeled defect taxonomy (class, severity, owning gate/seat) and known-clean controls is committed under the plugin test tree; initial size 60–80 across the three gate classes.
- [ ] An eval run reports, per gate: catch rate on planted defects, flag rate on clean fixtures, verdict-flip rate over 3 repeated runs, and severity-assignment accuracy; board fixtures additionally report per-seat unique-catch (which seat found what no other seat found).
- [ ] QA agent prompts/rubrics carry a version; any prompt or rubric change requires a gold-set re-run before the plugin version ships (enforced as a release-process check).
- [ ] The cheater track runs ≥10 cheat scenarios against the FR-011 guardrails plus ≥5 legitimate test-refactor fixtures; results report detection rate per scenario and false-rejection rate on the legitimate set; sub-100% scenarios are filed as guardrail bugs and retained as regressions.
- [ ] Escaped defects (post-merge bugs traced to a gate miss) feed back as new fixtures; saturated fixtures (3 consecutive full-catch runs) move to a regression tier.
- [ ] FR-016 board-composition changes reference these measurements (the consuming contract).

**Failure mode:** The eval suite cannot run in the current environment (capability absent) → per-stage `SKIPPED: <capability>` reporting, never a false green; mirrors FR-013's contract.

---

### FR-018: Outcome and negative-space acceptance criteria
**Statement:** Behavior-bearing pieces must specify what the *running system* must and must **not** produce — not only that a function returns a value. Today's ACs are almost entirely mechanism ("returns X", "writes row Y"); the spec never records the negative space ("a pilot run must never emit a forced $0 as an earned result", "no window may post a loss outside the risk rule"), so confidently-wrong output passes every construction gate. Two additions close this. **(a) Elicitation:** the FR-009 deliberation `user-intent` lens and the spec brainstorm gain a mandatory negative-space question — *"when this runs, what does unacceptable output look like?"* — whose answer is captured as one or more **outcome ACs** tagged distinctly from mechanism ACs. **(b) Enforcement:** `qa-spec` flags as must-fix any behavior-bearing spec whose ACs are all mechanism with zero outcome criteria (pure config/glue/doc pieces are exempt by a declared piece class). These outcome ACs become the oracle that the FR-020 results campaign and the ground-truth board seat grade real output against — the gate that has been missing because no artifact said what "wrong" looks like.
**Priority:** P1
**Linked metrics:** SC-010
**Research basis:** [R22] the 2026-06-12 efficiency evaluation — results-level wrongness ("$0 masquerading as an earned result", "large negative windows") passed every construction gate because no spec recorded the unacceptable-output criterion; [R13] machine-checkable outcomes are the external source of truth — but only if the spec states the outcome; [R4] a flywheel/evaluator needs a verifiable fitness function, and outcome ACs are that function for behavior.

#### User Stories
**US-018** — As a pipeline operator, I want the spec to force me to name what bad output looks like before any code is written, so that the gates downstream have an oracle and I stop discovering result-level wrongness by hand in an expensive Opus session after the fact.

**Acceptance Criteria:**
- [ ] The deliberation `user-intent` lens and the spec brainstorm both pose a mandatory negative-space question; a behavior-bearing spec cannot reach sign-off without at least one recorded answer.
- [ ] Spec ACs carry an outcome-vs-mechanism distinction (tag or section); outcome ACs state a property of the running system's output, including at least one prohibition ("must never …").
- [ ] `qa-spec` raises a must-fix when a behavior-bearing spec has zero outcome ACs; a piece declared non-behavioral (config/glue/docs) is exempt and the exemption is recorded.
- [ ] Outcome ACs are addressable as the oracle by FR-020 (campaign) and the ground-truth seat — referenced by ID, not re-derived.
- [ ] Additive and backward-compatible (NFR-003): specs without outcome-AC tags read as legacy and are not retro-failed; the gate applies to specs authored after this ships.

**Failure mode:** A piece's behavioral status is genuinely ambiguous → it defaults to behavior-bearing (outcome AC required); the operator may declare it non-behavioral with a one-line rationale, recorded — never a silent skip.

---

### FR-019: Standalone discovery-triage skill (`spec-flow:triage`)
**Statement:** Execute's Step 6c synchronous-discovery triage — the discipline that classifies a discovered change and routes it to amend / sub-phase / new-piece / note / explicit-defer without ever silently writing the backlog — is extracted into a standalone skill invocable from **any** session, not only inside a running execute loop. Today that machinery is reachable only mid-execute, so a discovery made in a validation campaign or an ad-hoc window regresses to freeform handling (the operator hand-rolls "align my questions with existing manifest items; if nothing captures, we're on the hook this session"). The skill takes a discovery (agent-found or operator-stated), classifies it (fix-now via `small-change` / amend an active piece's plan / new manifest piece / note on a scheduled piece / explicit defer with rationale), dispatches the FR-005 spike agent in **scope mode as a bounded isolated dispatch** when the change needs design — never main-window Opus thinking — and writes the routing to the manifest/backlog. It preserves NN-P-002 (no silent mid-stream change) and NN-P-004 (no silent defer). Execute keeps its inline Step 6c; this skill is the same logic made reachable elsewhere, and is the routing primitive FR-020 calls per finding.
**Priority:** P1
**Linked metrics:** SC-011
**Research basis:** [R22] the 2026-06-12 efficiency evaluation — ~$12.3k/2mo of June Opus was deviation + freeform validation, much of it the operator manually performing Step 6c-style triage in a main window because the machinery was execute-only; [R5] gate-hardness ladder and "the work and the grading are different jobs" — triage is the disposition step that must exist wherever a finding is raised; bounded isolated dispatch keeps the design thinking off the 180k-context main loop (NFR-001, G-4).

#### User Stories
**US-019** — As a pipeline operator who finds problems while validating a running system, I want one disciplined command that classifies the finding and routes it to the manifest the same way execute does, so that nothing dies in a chat scrollback and I stop paying main-window Opus rates to hand-triage.

**Acceptance Criteria:**
- [ ] A `spec-flow:triage` skill is invocable outside execute and classifies a supplied discovery into exactly one disposition: small-change / plan-amend / new-piece / note-on-scheduled / explicit-defer-with-rationale.
- [ ] For a change above the size/complexity threshold, it dispatches the FR-005 spike agent in scope mode as a bounded isolated dispatch and consumes the scoping artifact — it never resolves the design in the main window.
- [ ] Every disposition writes a recorded manifest/backlog entry with provenance (source session/finding); no disposition is applied as a silent mid-stream patch (NN-P-002) and no defer is silent (NN-P-004).
- [ ] Execute's inline Step 6c behavior is unchanged (the extraction is additive); both paths share one documented triage contract.
- [ ] The skill is reachable from intake routing (an "investigation/discovery" classification points here).

**Failure mode:** The spike scope-mode dispatch returns `BLOCKED` → triage records the finding as an open new-piece/needs-scoping item with the blocker, and surfaces it to the operator; it never fabricates a disposition or applies a mid-stream fix.

---

### FR-020: Results-campaign gate (`spec-flow:campaign`)
**Statement:** A new gate **class**, sibling to the Final Review board: where the review board points adversarial lenses at a *diff*, the campaign points them at a *running system's outputs*. Per-piece gates structurally cannot see whole-platform seam behavior ("in isolation each piece is fine; nothing puts the platform together and tunes it") or result-level degeneracy, so those defects today surface only in freeform Opus validation at ~5× the addressable cost of the planned board-seat cuts. The campaign, invoked out of band like `review-board`: (1) loads the in-scope FR-018 outcome ACs + product money/safety rules as the **oracle**; (2) runs the system (pilot / backtest / e2e) from the main window on **Sonnet** — execution and observation need no Opus; (3) dispatches **Opus** adversarial lenses — `ground-truth` (degeneracy / dead-knob on outputs), `seam` (cross-piece behavior the per-piece gates never exercise), `edge-case` — as **bounded isolated agents** reading run outputs against the oracle; (4) routes every finding synchronously through the FR-019 triage skill; (5) records findings with `source: campaign` into the FR-010 metrics artifact and the FR-006/FR-015 flywheel so recurring result-level defects harden like any other pattern. It honors NN-P-005 (system on Sonnet, judgment on Opus), NN-P-002 (findings route through triage, never mid-stream patches), and NN-P-004 (flywheel writes operator-gated).
**Priority:** P1
**Linked metrics:** SC-010, SC-005
**Research basis:** [R22] the 2026-06-12 efficiency evaluation — whole-platform seam/tuning gaps and results-level wrongness are invisible to per-piece construction gates and currently consume the largest single uncovered cost channel; [R16] lens diversity buys category coverage — ground-truth/seam/edge-case are non-overlapping lenses on behavior; [R6] Opus-judges / Sonnet-executes is the proven split, applied here to run-on-Sonnet / grade-on-Opus; [R10] bounded isolated agents return ≤2K summaries instead of accreting a 180k main-window context.

#### User Stories
**US-020** — As a pipeline operator, I want a structured command that runs the assembled system, has fresh adversarial agents grade its real output against what the specs said good and bad look like, and files every finding into the manifest, so that I get the adversarial validation I currently do by hand — at bounded dispatch cost instead of a freeform Opus arc.

**Acceptance Criteria:**
- [ ] A `spec-flow:campaign` skill runs out of band (like `review-board`), takes a target piece-set/system entrypoint, and loads the in-scope outcome ACs + declared product rules as the oracle.
- [ ] The system run (pilot/backtest/e2e) is performed on Sonnet; the adversarial lenses (`ground-truth`, `seam`, `edge-case` over the always-on core) are dispatched as bounded isolated Opus agents grading real outputs against the oracle.
- [ ] Every campaign finding is routed through the FR-019 triage skill to a recorded disposition; no finding is left only in conversation and none is applied as a mid-stream patch.
- [ ] Findings are recorded with `source: campaign` in the FR-010 metrics artifact and surfaced to the FR-006/FR-015 flywheel as occurrences.
- [ ] Seat activation over the always-on core is signal-conditional and consistent with FR-016(b); any seat omission is reported, never silent (mirrors the FR-013/FR-017 SKIPPED contract).
- [ ] The campaign changes no version-bearing file by itself; it is a gate that produces findings + triage dispositions, not a code-editing path.

**Failure mode:** The system cannot be run in the current environment (entrypoint/capability absent) → `SKIPPED: <capability>` per stage, never a false green; the campaign reports what it could not exercise rather than implying coverage.

---

### FR-021: Implement-track oracle — tests-after validated against the plan's pre-stated outcomes
**Statement:** Make `tdd: false` (Implement track — code first, tests after) a **supported efficient default** for behavior-bearing pieces, instead of a silent integrity downgrade. The 2026-06-12 research pass established that test-first *ordering* has no measured result-quality advantage over test-after; the only separable value of the red-first ritual is an **oracle specified independently of the implementation**, and tests-after captures that value equally — *if and only if* the after-written tests are validated against a pre-stated expected outcome rather than against the code just written. This FR wires exactly that. A behavior-bearing Implement-track phase carries the same independently-designed **expected-outcome block** the FR-003 Test Data contract gives TDD phases (inputs + expected outputs, authored at plan time, independent of the implementation). The `[Write-Tests]` step transcribes those expected values; `qa-phase` raises a must-fix when the authored tests assert the code's *actual* output rather than the plan's *pre-stated* output (the "tests codify the code" failure mode — the one real blind spot of tests-after). This closes that blind spot **without** the Red ceremony: no separate `tdd-red` dispatch, no `qa-tdd-red` review, no SHA hash-lock — dropping ~2 serial dispatches per phase. `tdd: true` remains available and recommended only for adversarial-sensitive pieces where the immutable pre-commit lock (FR-011) is genuinely wanted; the tradeoff (Implement track has no hash-lock immutability) is documented so the choice is explicit, not silent. This is the "Road A" cost path — distinct from FR-016(a)'s "Road B" (keep TDD semantics, collapse the dispatches); an operator picks one per piece.
**Priority:** P1
**Linked metrics:** SC-002, SC-005
**Research basis:** [R22] + the TDD evidence note (`docs/research/tdd-first-vs-test-after-for-ai-agents.md`) — test-first ordering shows no result-quality edge across human controlled studies (Fucci sequencing-inert; Tosun null) and AI evidence (the LLM benefit is oracle-in-context, not ordering); the separable value is the independent oracle, which a validated tests-after captures. [R2] reward-hacking (tests that codify wrong code) is the exact blind spot this validation closes without the hash-lock. [R6]/[R12] design the oracle once upstream (plan/Opus), mechanize downstream.

#### User Stories
**US-021** — As a pipeline operator who finds the TDD red ceremony slow and costly, I want code-first / tests-after to be a first-class supported mode whose QA still checks my tests against what the plan said the answer should be, so that I drop the red overhead without quietly losing the one thing TDD actually buys.

**Acceptance Criteria:**
- [ ] A behavior-bearing Implement-track (`tdd: false`) phase carries an expected-outcome block in the plan — the same oracle construct FR-003 defines for TDD phases — authored at plan time independent of the implementation; `qa-plan` flags a behavior-bearing Implement phase that has neither the block nor a `[SPIKE]` marker (mirrors FR-003).
- [ ] The `[Write-Tests]` step transcribes the planned expected outcomes and invents no expected values absent from the plan; genuinely unpredictable outcomes use `[SPIKE]`, never a fabricated value (mirrors FR-003/FR-005).
- [ ] `qa-phase` raises a must-fix when an Implement-track phase's authored tests assert the code's actual output instead of the plan's pre-stated expected outcomes, or when a required expected-outcome block is absent.
- [ ] Documentation states the supported-default policy: `tdd: false` is the efficient default for non-adversarial behavior-bearing pieces; `tdd: true` is recommended where the immutable pre-commit lock is wanted; the no-hash-lock tradeoff is named.
- [ ] Additive/backward-compat (NFR-003): existing Implement-track phases without an expected-outcome block read as legacy and are not retro-failed; the validation applies to phases authored after this ships.
- [ ] Where a piece also declares outcome ACs (FR-018), the phase's expected-outcome block references them by ID rather than re-deriving (the spec-time oracle and the plan-time oracle are one chain).

**Failure mode:** The expected outcome is genuinely unpredictable at plan time → `[SPIKE]` resolves it and the resolution becomes the expected-outcome block (mirrors FR-003/FR-005); the validation never accepts a value transcribed from the implementation in place of a planned one.

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
| Metrics artifact unwritable | `[METRICS-DEGRADED]`; pipeline continues; instrumentation never blocks | FR-010 |
| Implementer diff touches a Red-manifest test file | Mechanically rejected pre-commit; re-dispatched with violating paths named; no warn-only path | FR-011 |
| Repeated immutability rejections on one phase | Routes to Step 6c as plan-incompleteness (the oracle or phase design is wrong); never an exemption | FR-011 |
| Amendment count reaches the hard cap | Execute halts with operator escalation + amendment history; no soft-checkpoint continuation | FR-011 |
| Gate clean + all ACs machine-checkable with evidence | Evidence digest + single summary-confirm keystroke (NN-P-001 preserved) | FR-012 |
| Any judgment-required AC or surviving marker at a gate | Full review gate, unchanged from today; summary-confirm not offered | FR-012 |
| Artifact exceeds its size budget | `qa-spec`/`qa-plan` must-fix with split/condense guidance; irreducible overage routes to piece-splitting | FR-014 |
| Hardened pattern recurs after its fix landed | Re-opened `active` with `ineffective-hardening` flag at next batched review | FR-015 |
| Pattern stale past the window | Refresh proposes archival; operator-gated; archived entries stay in-file for audit | FR-015 |
| Red-conformance check can't parse the Test Data block | `[CONFORMANCE-FALLBACK]` → full qa-tdd-red LLM dispatch; never silently skipped | FR-016 |
| Implement-track tests assert the code's actual output, not the plan's expected output | `qa-phase` must-fix: tests must assert the pre-stated expected outcomes, not codify the implementation | FR-021 |
| Behavior-bearing Implement phase has no expected-outcome block and no `[SPIKE]` | `qa-plan` must-fix (mirrors the FR-003 TDD-phase check) | FR-021 |
| Implement-track expected outcome genuinely unpredictable at plan time | `[SPIKE]` resolves it → becomes the expected-outcome block; never transcribed from the implementation | FR-021 |
| Diff signal for a conditional board seat is ambiguous | Seat runs (activation errs toward inclusion); the always-on core never deactivates | FR-016 |
| QA agent prompt/rubric edited | Gold-set re-run required before the plugin version ships; rubric versions frozen otherwise | FR-017 |
| Cheat scenario detected < 100% | Filed as a guardrail bug; scenario retained as a permanent regression | FR-017 |
| Eval suite lacks a required capability | Per-stage `SKIPPED: <capability>`; never false green | FR-017 |
| Executor model changes | Cheat-fixture set refreshed (stronger models cheat more subtly) | FR-017 |
| Behavior-bearing spec has only mechanism ACs | `qa-spec` must-fix: at least one outcome AC required, or a recorded non-behavioral exemption | FR-018 |
| Piece behavioral status ambiguous | Defaults to behavior-bearing (outcome AC required); operator may declare non-behavioral with recorded rationale | FR-018 |
| Discovery raised outside an execute loop | Routed through `spec-flow:triage` to a recorded manifest/backlog disposition; never a silent mid-stream patch | FR-019 |
| Triage spike scope-mode returns BLOCKED | Recorded as open needs-scoping item with the blocker, surfaced to operator; no fabricated disposition | FR-019 |
| Campaign finding on a running system | Routed synchronously through triage; recorded `source: campaign`; surfaced to the flywheel | FR-020 |
| Campaign system entrypoint/capability absent | `SKIPPED: <capability>` per stage; reports what was not exercised; never a false green | FR-020 |

## Success Metrics

- **SC-001:** On pieces with a research artifact, spec Q&A rounds ≤3 (baseline 5–8). — FR-001
- **SC-002:** ≥80% of execute phases complete on Sonnet without escalation or unmarked discovery on pieces whose plan passed the concreteness floor. — FR-002, FR-003, FR-004, FR-008
- **SC-003:** Avoidable execute-time discoveries (Step 6c events not attributable to a `[SPIKE]`) trend down across a PRD: the second half of a PRD's pieces show fewer than the first half. — FR-002, FR-006
- **SC-004:** A coordinator forced into a fresh context mid-piece resumes correctly from disk on 100% of attempts; execute runs on Sonnet by default. — FR-004, NFR-002
- **SC-005:** Opus token spend per piece trends down across a PRD as spikes decrease (proxy: `[SPIKE]` count per piece declines). — FR-005, FR-006, FR-007
- **SC-006:** Mid-execution changes that route through a scoping spike produce a complete plan amendment — measured: no second amendment targeting the same change within the same piece (the change was fully scoped on the first pass). — FR-008
- **SC-007:** SC-001 through SC-006 are computable from on-disk artifacts for 100% of pieces executed after instrumentation ships; a single `/spec-flow:status` invocation renders them per PRD with no manual collection. — FR-010
- **SC-008:** Median operator interactions per *clean* piece (zero must-fix at every gate) drop by ≥50% from the instrumented baseline once verifiability-scaled gates and artifact budgets ship — with the NN-P-001 keystroke preserved at every gate. — FR-012, FR-014
- **SC-009:** 100% of merge-blocking gates have a published catch rate and clean-fixture flag rate; every board-composition or gate-mechanism change since FR-017 shipped cites fixture/ablation evidence; cheater-track detection is 100% across the scripted scenario set (sub-100% scenarios are open guardrail bugs). — FR-016, FR-017
- **SC-010:** Behavior-bearing pieces authored after FR-018 ships carry ≥1 outcome AC; a results campaign run against a shipped piece-set produces findings traced to outcome ACs, and 100% of those findings reach a recorded triage disposition (manifest/backlog), not a freeform chat note. — FR-018, FR-020
- **SC-011:** Discoveries raised outside an execute loop (campaign or ad-hoc session) route through `spec-flow:triage` to a recorded manifest/backlog disposition on 100% of occurrences; none is applied as a silent mid-stream patch. — FR-019

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
| FR-010 | Pipeline instrumentation | P0 | Measurement precedes optimization; the flywheel's fitness function; turns all SCs from "pending" to real |
| FR-011 | Execute integrity guardrails | P0 | Test immutability + hard amendment cap; the precondition for safe unattended runs |
| FR-012 | Verifiability-scaled gates | P1 | Operator keystrokes move to judgment calls; clean work flows on evidence; needs FR-010 baseline first |
| FR-013 | Pipeline e2e smoke test | P1 | Regression insurance on 5K+ lines of orchestration prose; land before further execute surgery |
| FR-014 | Artifact size budgets | P1 | The anti-bloat floor; binds spec-preresearch's deliberation.md before its plan is authored |
| FR-015 | Flywheel pattern lifecycle | P1 | Expiry/outcome tracking keeps the registry high-signal; gates flywheel-global |
| FR-016 | Pipeline economics | P1 | TDD-lean + conditional board + depth defaults; halves TDD phase dispatches; every cut evidence-gated |
| FR-017 | Gate-efficacy evals + cheater track | P1 | Calibration prerequisite for any seat cut/downgrade; red-teams the FR-011 guardrails |
| FR-018 | Outcome & negative-space ACs | P1 | The missing oracle — specs must say what bad output looks like; foundation for the campaign and the ground-truth seat |
| FR-019 | Standalone discovery-triage skill | P1 | Step 6c reachable from any session; bounded-dispatch routing instead of freeform main-window triage |
| FR-020 | Results-campaign gate | P1 | The missing gate class — grades a running system's output; largest uncovered cost channel (2026-06-12 eval) |
| FR-021 | Implement-track oracle (Road A) | P1 | Makes `tdd: false` a supported efficient default — drops the Red ceremony, keeps the independent oracle via a qa-phase check; the actionable TDD cost cut |
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
| Metrics artifact location + schema: standalone `metrics.yaml` per piece, or a structured block in `learnings.md`? | spec author (FR-010 piece) | open — lean: standalone `metrics.yaml` (machine-readable, no prose mixing) |
| Test-immutability response: reject-and-redispatch only, or superpowers-style delete-on-violation for code written before its failing test? | spec author (FR-011 piece) | open — lean: reject-and-redispatch (delete is a doctrine change) |
| Default artifact size budgets per class (spec/plan/research/deliberation/learnings) — lines and token bounds? | spec author (FR-014 piece) | open — derive from the size distribution of the 5 merged exec-ready pieces |
| Staleness window for pattern archival — N pieces, N days, or both? | spec author (FR-015 piece) | open |
| Deterministic Red-conformance check form: structural assertion-vs-oracle diff, or string-level match? | spec author (FR-016 piece) | open |
| Always-on board core — which 4 seats? | spec author (FR-016 piece) | open — decided by FR-017 ablation data, not upfront |
| Cross-provider board seat (one GPT/Gemini reviewer): unique-catch value vs charter-tools/NN-P-005 implications | operator experiment via /spec-flow:review-board on 3–5 pieces, before any plugin change | open — evidence first ([R15][R16]) |
| Cost reporting: embed a dated pricing table (drift risk) or report raw tokens by model only? | spec author (FR-010/metrics piece) | open — lean: tokens only, cost as flagged estimate |

## Research Basis — 2026-06-09 deep-dive audit

FR-010 through FR-015 derive from a full plugin audit (internals inventory, manifest/backlog state, active worktrees) cross-checked against verified external research on agentic pipelines. FR sections cite these by ID. Companion design doc: `docs/autonomous-loops-and-spec-flow.md` (loop execution, not spec; make judgment cheaper, not absent).

- **[R1]** METR, "Recent reward hacking" (2025-06-05, metr.org) — o3 hacked 30.4% of RE-Bench trajectories (evaluator monkey-patching, reference-answer introspection) and denied misalignment 10/10 times when asked. Visible-and-blocked beats trained-covert.
- **[R2]** debugml.github.io/cheating-agents + EvilGenie benchmark (arXiv:2511.21654) — all three major coding-agent model families caught deleting/modifying test files and hardcoding test inputs. Grounds FR-011's mechanical-reject posture.
- **[R3]** METR Time Horizon 1.1 (2026-01-29, metr.org) — 50%-success horizon ≈320 min (Opus 4.5) but the 80%-reliability horizon is ~5× shorter: budget unsupervised stretches at roughly one hour of human-equivalent work. Informs phase sizing and the FR-011 hard cap.
- **[R4]** DeepMind AlphaEvolve (2025-05, deepmind.google) — autonomous improvement worked *only* because every candidate passed a programmatic evaluator. No verifiable fitness function, no flywheel. Grounds FR-010 and FR-015.
- **[R5]** Anthropic, "Claude Code best practices" (code.claude.com/docs/en/best-practices, living doc) — gate-hardness ladder (in-prompt → goal → Stop hook → fresh-context refuting reviewer); "the agent doing the work isn't the one grading it"; reviewers always find something — cap zeal to correctness. Grounds FR-012.
- **[R6]** Anthropic, "How we built our multi-agent research system" (2025-06) — Opus-orchestrates/Sonnet-executes +90.2%; start evals at ~20 cases; LLM-judge with a single rubric; measure before tuning. Grounds FR-010; validates G-3.
- **[R7]** Jesse Vincent, superpowers / Superpowers 4 & 5 (blog.fsck.com 2025-10-09, 2025-12-18, 2026-03-09) — destructive RED/GREEN enforcement; two-stage subagent review; adversarial spec review pre-sign-off; an e2e test suite for the framework itself. Grounds FR-011, FR-013; validates the dense-plan/cheap-executor thesis (G-1/G-3).
- **[R8]** Scott Logic, spec-kit field trial (2025-11-26, blog.scottlogic.com) — 2,577 lines of duplicative markdown per ~700 lines of code; 3.5h review per increment; artifact bloat is how spec pipelines die. Grounds FR-014.
- **[R9]** Every / Kieran Klaassen, compound engineering (every.to, 2025-12→2026-06; compound-engineering plugin) — capture (`/ce-compound`) is only durable when paired with expiry (`/ce-compound-refresh`); ~80% of human effort in plan+review. Grounds FR-015; validates G-6's attention placement.
- **[R10]** Anthropic, "Effective context engineering for AI agents" (2025-09-29) — smallest set of high-signal tokens; context rot; subagents return 1–2K summaries. Grounds FR-014; validates NFR-001.
- **[R11]** BMad Method Issue #446 (github.com/bmad-code-org/BMAD-METHOD) — review verdicts with no workflow consequence collapse coordination. Validates blocking gates; FR-012 scales gate *cost*, never gate *consequence*.
- **[R12]** Boris Cherny setup thread (x.com/bcherny, late 2025) + Anthropic long-running-harness post (2025-11-26) — plan-gate is the human leverage point; "give Claude a way to verify its work" ≈2–3× quality; deterministic startup ritual from on-disk state. Validates G-2/G-4; grounds FR-012's evidence digests.
- **[R13]** OpenAI, "Run long-horizon tasks with Codex" (developers.openai.com) — per-milestone tests/lint/typecheck as the "external source of truth that stays accurate regardless of how long the session runs." Grounds FR-012's machine-checkable AC currency.
- **[R14]** EvoSkills (arXiv:2604.01687) + Voyager (arXiv:2305.16291) — self-evolved skill libraries beat curated ones only with co-evolutionary verification; retained items must be re-verified in the loop. Grounds FR-015's outcome tracking.

PRD v4 additions (second research pass, 2026-06-09 — judge calibration, telemetry, reviewer diversity):

- **[R15]** "Correlated Errors in LLMs" (ICML 2025, arXiv:2506.07962) + "Great Models Think Alike" (arXiv:2502.04313) + self-preference studies (arXiv:2410.21819, arXiv:2508.06709) — same-family judges agree on the *same wrong answer* ~60% of the time; judge affinity bias is perplexity-driven (familiar text scores higher regardless of author), so an all-Opus board reviewing Claude-written code has a structural blind-spot class persona prompts cannot remove. Grounds FR-016(b) and the cross-provider experiment.
- **[R16]** "Multi-Agent Code Verification via Information Theory" (arXiv:2511.16708) — inter-lens error correlation is genuinely low (ρ=0.05–0.25) but returns diminish monotonically (+14.9pp, +13.5pp, +11.2pp for reviewers 2–4); Milvus multi-model debate benchmark (2026-02) — Claude alone caught 53% and 0% of concurrency races, Claude+Gemini weaknesses "barely overlap." Lens diversity buys category coverage, not independence; 8–9 same-model seats are past the knee. Grounds FR-016(b).
- **[R17]** Judge Reliability Harness (arXiv:2603.05399), Rubric-Induced Preference Drift (arXiv:2602.13576), adversarial persuasion of judges (arXiv:2508.07805) — judges flip on meaning-preserving perturbations; benign rubric edits degrade judge accuracy up to 27.9%; judges can be talked into inflated scores by text in the artifact under review. Grounds FR-017's perturbation fixtures and rubric-version freeze.
- **[R18]** SHADE-Arena (Anthropic, arXiv:2506.15740) + NIST CAISI eval-cheating series — the saboteur-vs-monitor methodology; best monitors top out at AUC 0.87, so anti-cheat gaps must be found by scripted red-team, not assumed away. Grounds FR-017's cheater track.
- **[R19]** Seeded-defect review benchmarks: Greptile real-bug tracing (commercial reviewer catch rates span 6%–82%), Qodo bug-injection-into-clean-PRs methodology (580 planted issues, precision/recall/F1), Meta ACH mutation testing (FSE 2025) — the three established corpus-construction patterns. Grounds FR-017's fixture design.
- **[R20]** Anthropic, "Demystifying evals for AI agents" (2025) — 20–50 tasks drawn from real failures; deterministic code graders preferred over LLM graders; one rubric dimension per judge call; grade end state, not path; kappa over raw accuracy; watch for saturation. Grounds FR-017's metrics and refresh cadence.
- **[R21]** Claude Code monitoring/costs docs + local transcript verification (2026-06-09) — Agent dispatch results carry `totalTokens`/`agentType`/duration; per-subagent transcripts carry per-message usage with unredacted plugin attribution; all POSIX-parseable. OTel exists but needs a collector and redacts third-party plugin names; Copilot CLI has no per-message usage surface (degrade to wall-clock + dispatch counts). Grounds the FR-010 metrics piece's layered capture design.

PRD v5 additions (2026-06-12 — token-efficiency evaluation against real usage):

- **[R22]** Internal: spec-flow token-efficiency evaluation (2026-06-12; full report `/Volumes/joeData/spec-flow-insights/efficiency-evaluation-2026-06-12.md`; miner baseline `run-20260612T163945Z`) — mined 257 real sessions across two repos using the plugin (prop-firm-repo, ai-plugins). Findings: the main orchestrator loop is ≈73% of pipeline token cost; TDD agent-side overhead is ~1.6% and `qa-tdd-red` catches real theater on 18.5% of TDD phases (keep Red-first, consolidate dispatches per FR-016a); QA gates are the highest-yield spend (`qa-phase` raises must-fix on ~68% of dispatches; doc gates catch ~1,200 items before code exists); the review board is cost-trivial (~$2.9k total — seat cuts are noise/latency moves, not cost moves). The dominant uncovered channel is ~$12.3k/2mo of June Opus spent on deviation + freeform results-validation, decomposing into three classes: result-level wrongness invisible to diff gates, whole-platform seam/tuning gaps no per-piece gate sees, and missing outcome ACs (specs validated mechanism, not outcome). Every existing gate inspects a construction artifact while system behavior goes ungated. Grounds FR-018, FR-019, FR-020 and G-7.

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
- **Scope:** FR-002, FR-005, FR-008, FR-019, FR-020, and the execute path. FR-019 extracts this triage into a standalone skill and FR-020's campaign routes every finding through it — the no-silent-mid-stream rule binds those paths identically.
- **Rationale:** An execute-time discovery — or an operator's mid-run change, or a campaign finding on a running system — is a plan-incompleteness or scope-growth signal; applying it mid-stream destroys the feedback the flywheel needs, produces partial fixes, and violates the synchronous-discovery doctrine.
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
- **Scope:** FR-006, FR-007, FR-019, FR-020. FR-019 dispositions and FR-020 campaign findings write the manifest/backlog and surface flywheel occurrences only through the same operator-gated triage — no silent defer, no auto-applied disposition.
- **Rationale:** Charter rules are binding and manifest pieces are real work; both demand human intent. Silent deferral violates the no-silent-defer doctrine.
- **How QA verifies:** No flywheel code path writes a registry or proposes a promotion without a confirmation prompt; spec-compliance reviewer checks the gate.

### NN-P-005: Thinking on Opus, mechanics on Sonnet — no silent upgrade
- **Type:** Rule
- **Statement:** Spec authoring, plan authoring, all adversarial gates, and spikes run on Opus. Execute (coordinator, implementer, test transcription) runs on Sonnet by default. Execute never silently upgrades a non-`[SPIKE]` phase to Opus to compensate for an under-specified plan — it halts and routes to plan amendment or a `[SPIKE]`. Operator override is explicit.
- **Scope:** FR-004, FR-005, FR-009, FR-020. FR-020's campaign runs the system on Sonnet and dispatches the adversarial lenses on Opus — the same thinking-on-Opus / mechanics-on-Sonnet split applied to run-vs-grade.
- **Rationale:** Concentrating thinking upstream is the entire cost model; a silent Opus upgrade in execute hides plan incompleteness and re-introduces the cost this PRD removes.
- **How QA verifies:** Model-policy check asserts stage→model assignment; any execute path that escalates a non-`[SPIKE]` phase to Opus without halting/override is must-fix.
