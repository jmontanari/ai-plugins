---
slug: exec-loop
status: drafting
version: 1
---

# Product Requirements Document — Autonomy & Self-Improving Pipeline

**Project:** spec-flow autonomy — research-first pipeline + unattended execute loop + learning flywheel
**Date:** 2026-06-06
**Status:** draft
**Charter:** .claude/skills/charter-*/SKILL.md (NN-C namespace — project-wide binding rules)

## Problem Statement

**Current situation:** The spec-flow pipeline requires the operator's attention at every stage. Spec brainstorm asks questions from a blank slate. Plan authoring repeats codebase exploration that spec already partially covered. Execute stops to ask whenever it hits an ambiguity not explicitly covered by the spec. When a piece finishes, the operator must manually start the next one. Learnings from completed pieces sit in `improvement-backlog.md` and `learnings.md` but don't automatically reduce future iteration or improve the pipeline itself.

**Problem:** Human attention is consumed by work the pipeline could do itself:
1. Gathering context that should have been gathered before questions were asked
2. Answering questions the pipeline could have researched and pre-answered
3. Babysitting execute while it waits for ambiguity resolution
4. Manually starting the next piece when the prior one finishes
5. Deciding which recurring process findings should become permanent rules

**Who is affected:** Any operator running multiple pieces through the spec-flow pipeline — specifically during spec Q&A rounds, execute supervision, and post-piece follow-up.

**Why now:** Boris Cherny's 2026 workflow (verified research, Jan–Jun 2026) demonstrates that the research → plan → implement separation with CLAUDE.md flywheel feedback is the current state of the art for agentic pipelines. The primitives exist in this install (`/loop`, `ScheduleWakeup`, `Agent`, `Workflow`). The pattern is proven. The gap is spec-flow-specific wiring.

## Goals

- G-1: Reduce spec Q&A rounds by front-loading research into a durable artifact that proposes answers before questions are asked
- G-2: Make execute unattended — Claude researches and commits decisions for spec-unspecified ambiguities; only escalates on genuine spec contradictions
- G-3: Enable a queue of planned pieces to execute serially without human involvement between pieces
- G-4: Create a learning flywheel where recurring process findings auto-promote to charter amendments and spec-flow improvement pieces
- G-5: Optimize all orchestration paths for Sonnet as the main-thread model — context stays lean, heavy work goes to sub-agents

## Non-Goals

- **Automated spec writing** — human approval gate on spec is preserved; research reduces rounds, not the gate itself
- **Automated plan approval** — same; human reviews the plan artifact before execute begins
- **Full unattended manifest autonomy** — the loop only runs on pieces already `planned`; it does not spec or plan unattended
- **Overnight/cloud Routines** — the loop runs locally via `/loop` + `ScheduleWakeup`; scheduled cloud Routines are a future extension
- **Replacing design judgment** — research proposes answers and execute documents decisions; it does not override human architectural direction
- **Cross-project learning** — the flywheel is scoped to this repo's charter and spec-flow plugin only

## Personas

### The Queue Operator
- **Role:** Has 3–5 planned pieces ready. Wants to start the loop, context-switch to spec/plan work on the next piece, and return to completed results.
- **Goals:** Zero babysitting of execute; parallel spec/plan work without blocking on execution completion; clear audit trail of decisions made autonomously.
- **Pain points today:** Execute stops to ask questions mid-run. Must manually restart after each piece completes. Learnings don't carry forward automatically.
- **Behaviors:** Approves spec + plan artifacts, then delegates execution. Reviews completed piece results and decisions.md before marking merged.

### The Focused Operator
- **Role:** Running a single piece. Wants spec Q&A to take 2-3 rounds instead of 6-8. Wants execute to resolve the common cases itself.
- **Goals:** Faster spec → approved artifact. Execute that surfaces only genuine blockers.
- **Pain points today:** Answers the same type of questions across every piece (charter patterns, existing code conventions) because the spec skill starts blind each time.
- **Behaviors:** Engages in spec brainstorm, approves plan, checks decisions.md after execute. Does not want to explain context Claude could have found itself.

## Functional Requirements

### FR-001: Research sub-agent produces a durable research.md artifact
**Statement:** Before any spec brainstorm Q&A begins, a dedicated research sub-agent runs in its own context, reads the codebase (relevant files, related skill implementations, charter rules, backlog items, and past learnings), and writes a structured `research.md` artifact to the piece's spec directory. The artifact is committed to disk before the first brainstorm question is asked.
**Priority:** P0
**Linked metrics:** SC-001

#### User Stories

**US-001** — As a focused operator, I want the spec skill to arrive at brainstorm already knowing the relevant codebase context, so that questions come pre-answered and I confirm rather than explain from scratch.

**Acceptance Criteria:**
- [ ] A `research.md` artifact exists at `docs/prds/<prd-slug>/specs/<piece-slug>/research.md` before the first spec brainstorm question
- [ ] `research.md` contains required schema sections: `relevant_files` (list with line refs), `charter_rules` (NN-C IDs + summaries), `backlog_items` (top 3), `proposed_answers` (keyed by topic)
- [ ] `research.md` is committed to the piece branch before brainstorm begins (verified via `git log --oneline -- research.md` showing a commit before the first spec Q&A commit)
- [ ] The research sub-agent is dispatched via `Agent(...)` (not inline file reads in main context); its return value is a structured object ≤2K tokens
- [ ] If research sub-agent errors or returns empty, spec emits `[RESEARCH-UNAVAILABLE: <reason>]` and proceeds without blocking

**Failure mode:** Research sub-agent errors or returns empty — spec falls back to current behavior (L-10 scan), emits a `[RESEARCH-UNAVAILABLE]` notice, and continues.

---

### FR-002: Spec skill consumes research.md to reduce brainstorm rounds
**Statement:** The spec skill reads `research.md` at brainstorm start and uses proposed answers as the default for each question, presenting them as "Based on [finding], I propose [answer] — confirm or correct?" instead of asking from a blank slate. Questions where research found no clear answer are asked normally.
**Priority:** P0
**Linked metrics:** SC-001

#### User Stories

**US-002** — As a focused operator, I want spec brainstorm questions to arrive with a proposed answer derived from codebase research, so that my role is to confirm or correct rather than construct answers from scratch.

**Acceptance Criteria:**
- [ ] For each brainstorm question where `research.md` has a relevant finding, the spec skill presents the finding and proposed answer before asking for confirmation
- [ ] The operator can override any proposed answer; the override is recorded in the spec
- [ ] Questions with no research coverage are asked normally (no degradation in baseline behavior)
- [ ] The research source is cited inline ("Based on: `plugins/spec-flow/skills/execute/SKILL.md:L142`")

**Failure mode:** research.md missing or malformed — spec proceeds with standard brainstorm, no research-feed questions.

---

### FR-003: Plan skill consumes research.md, skips redundant codebase exploration
**Statement:** The plan skill reads `research.md` as its primary codebase context. It does not re-run a full codebase exploration if `research.md` is present and covers the relevant files. Plan authoring begins from the research artifact, not from scratch.
**Priority:** P0
**Linked metrics:** SC-001

#### User Stories

**US-003** — As a queue operator, I want spec and plan to share a single research artifact so that the total spec→plan cycle time is shorter and no codebase context is rediscovered twice.

**Acceptance Criteria:**
- [ ] Plan skill checks for `research.md` at plan start; if present and non-empty, uses it as primary context instead of running a fresh `find`/`grep` sweep
- [ ] If `research.md` is absent or stale (> 7 days since commit), plan falls back to current codebase exploration and emits a notice
- [ ] When research.md is present, the plan skill emits `[RESEARCH-CONSUMED: <N> files]` and skips the file-discovery sweep; when absent, plan emits `[RESEARCH-ABSENT: running full exploration]` and runs the sweep normally

**Failure mode:** research.md absent — plan runs current full exploration without degradation.

---

### FR-004: Execute resolves spec-unspecified ambiguities without stopping
**Statement:** When an implementer agent encounters a case not explicitly covered by the spec, it runs a mini research step (reads spec, charter, research.md, related existing code), documents a decision with evidence in `decisions.md`, and continues. It stops and escalates only when the ambiguity directly contradicts the spec or when the research step produces genuinely undecidable results.
**Priority:** P0
**Linked metrics:** SC-002

#### User Stories

**US-004** — As a queue operator running execute unattended, I want the implementer to resolve common "spec didn't specify X" cases itself and document what it decided, so that I'm not interrupted for questions the codebase already answers.

**Acceptance Criteria:**
- [ ] Implementer dispatches a mini research step before any escalation to the operator
- [ ] A `decisions.md` artifact is written at `docs/prds/<prd-slug>/specs/<piece-slug>/decisions.md` recording each autonomous decision: what was ambiguous, what was found, what was decided, and why
- [ ] `decisions.md` is committed alongside each phase that used self-resolution
- [ ] Escalation to operator is reserved for: (a) direct spec contradiction, (b) research step returns ≥2 equally valid interpretations with no charter tiebreaker
- [ ] The operator reviews `decisions.md` as part of the final review gate before merge

**Failure mode:** Research step finds nothing useful → escalates to operator with context ("I looked at X, Y, Z and found no guidance; here are the options").

---

### FR-005: Execute loop driver runs a queue of planned pieces unattended
**Statement:** A loop driver reads the manifest, selects the highest-priority piece with `status: planned` and all dependencies `merged/done`, invokes `/spec-flow:execute` for that piece, waits for completion, and schedules the next iteration. Each iteration re-reads the manifest from disk. The main loop context stays bounded — it holds only the current piece's one-line status, not execute's full output.
**Priority:** P0
**Linked metrics:** SC-002, SC-003

#### User Stories

**US-005** — As a queue operator, I want to start a loop, switch to another tab to spec the next piece, and return to find the planned queue executed without any prompting.

**Acceptance Criteria:**
- [ ] A canonical loop prompt exists (in `docs/exec-loop/loop-driver.md` or as a `/loop` skill template) that operators can paste to start the queue
- [ ] Each iteration: reads manifest fresh, picks the next planned piece, invokes execute, records a one-line result (piece name + pass/fail), schedules next wakeup via `ScheduleWakeup`
- [ ] If no planned piece exists (or all have unmet deps), the loop reports "no executable work" and stops cleanly
- [ ] If execute fails (BLOCKED, Final Review not passing), the loop records the failure, skips that piece, and continues to the next planned piece rather than halting the whole queue
- [ ] The main loop context accumulation is bounded — each iteration's execute output is summarized to ≤200 tokens before being stored in main context
- [ ] The loop driver is re-entrant: if the session is interrupted and restarted, it re-reads the manifest and continues from the current manifest state

**Failure mode:** Execute exits with BLOCKED — piece is skipped, failure is recorded in a `loop-run.log` artifact, loop continues with next piece.

---

### FR-006: Orchestrator context discipline — Sonnet-optimized main thread
**Statement:** The spec-flow orchestration path enforces three concrete bounds: (1) no file >10KB is read directly into main context — oversized reads are routed to a summarizing sub-agent; (2) all sub-agent results returned to main context are schema-bounded summaries ≤2K tokens; (3) main context accumulation across a full piece execution stays below a configurable token budget (default: 80K tokens).
**Priority:** P1
**Linked metrics:** SC-004

#### User Stories

**US-006** — As a queue operator running a multi-piece session, I want the main context to stay lean so that sessions don't degrade or require `/compact` after 2-3 pieces.

**Acceptance Criteria:**
- [ ] No skill reads a file > 10KB directly into main context; large file reads go through a summarizing sub-agent
- [ ] All sub-agents called from execute return results via schema (structured output ≤2K tokens) not raw text
- [ ] A context-discipline reference doc (`reference/context-discipline.md`) documents the budget rules and which tools are context-safe
- [ ] Execute emits `[CTX-LOAD: <filename> <kb>]` for each file read into main context; any file >10KB triggers `[CTX-OVERSIZED: routing to summarizer]` and dispatches a sub-agent to summarize before the content reaches main context

**Failure mode:** Sub-agent fails to return structured output → main thread receives a truncated plain-text fallback with a `[CONTEXT-BUDGET-EXCEEDED]` warning.

---

### FR-007: Learning flywheel — recurring findings promote to charter amendments and spec-flow improvements
**Statement:** After every execute completion, the reflection agents record findings to `learnings.md`. A new flywheel step scans all learnings across the PRD's pieces, counts recurrences of semantically similar findings, and when a finding has appeared in ≥2 pieces:
  (a) For process findings about the project — proposes a charter amendment (new NN-C entry) for operator review
  (b) For process findings about the spec-flow pipeline itself — creates a new piece in the spec-flow shared manifest as a self-improvement item

The operator reviews proposed amendments/pieces and approves or rejects; approved proposals are committed immediately.
**Priority:** P1
**Linked metrics:** SC-003

#### User Stories

**US-007** — As a queue operator running many pieces over time, I want the pipeline to notice recurring mistakes and encode them as permanent rules, so that future pieces start with those lessons built in rather than rediscovering them.

**Acceptance Criteria:**
- [ ] A flywheel step runs after each execute's reflection phase; it reads all `learnings.md` files for the current PRD
- [ ] Findings are clustered by semantic similarity; any cluster with ≥2 occurrences triggers a promotion proposal
- [ ] Charter proposals are presented as a draft NN-C entry (type, statement, scope, rationale, QA verification) for operator one-time approval
- [ ] Spec-flow self-improvement proposals are presented as a draft manifest piece entry for the `shared` PRD for operator approval
- [ ] Rejected proposals are recorded with rationale in the PRD's `backlog.md` (not silently dropped)
- [ ] The flywheel step is non-blocking — if it fails or produces no proposals, execute's result is unaffected

**Failure mode:** Flywheel scan finds no recurring patterns → step exits silently; no operator prompt.

---

## Non-Functional Requirements

### NFR-001: Research sub-agent context isolation
**Statement:** The research sub-agent always runs in a fresh context isolated from the spec/plan main thread. It must not receive brainstorming history or prior conversational context. Its output to main context is bounded to a structured schema ≤2K tokens.
**Priority:** P0
**Linked metrics:** SC-004

### NFR-002: research.md is a durable, session-portable artifact
**Statement:** `research.md` is committed to the piece branch before spec Q&A begins. It remains valid for plan consumption across separate sessions (no time-limited cache). If more than 7 days pass between research commit and plan start, plan emits a staleness notice but does not block.
**Priority:** P0
**Linked metrics:** SC-001

### NFR-003: Backward compatibility — all new behavior is additive
**Statement:** All changes are additive and backward-compatible within the current major version (NN-C-003). Pieces without `research.md` run current spec/plan/execute behavior unchanged. The loop driver is opt-in. The flywheel is opt-in (can be disabled via `.spec-flow.yaml` key).
**Priority:** P0
**Linked metrics:** —

### NFR-004: decisions.md is operator-reviewable before merge
**Statement:** The Final Review gate in execute must include a check that `decisions.md` has been reviewed by the operator before the merge step proceeds. The review is a prompt — operator confirms they have read and accepted the autonomous decisions.
**Priority:** P1
**Linked metrics:** SC-002

## Edge Cases & Failure Modes

| Scenario | Expected behavior | FR reference |
|---|---|---|
| Research sub-agent times out or errors | Spec falls back to standard brainstorm with `[RESEARCH-UNAVAILABLE]` notice | FR-001 |
| research.md is stale (>7 days) | Plan emits staleness notice, proceeds with current codebase exploration as supplement | FR-003 |
| Execute hits direct spec contradiction during self-resolve | Escalates to operator with: what was ambiguous, what was found, the contradiction | FR-004 |
| Loop's current piece hits BLOCKED | Skip piece, log failure to `loop-run.log`, continue with next planned piece | FR-005 |
| All planned pieces have unmet deps | Loop reports "no executable work — N pieces blocked on dependencies" and stops | FR-005 |
| Loop session interrupted (laptop close, /clear) | Next session re-reads manifest from disk and resumes queue from current manifest state | FR-005 |
| Flywheel scan finds ≥5 simultaneous proposals | Batch-present all proposals in one operator review session (not 5 sequential prompts) | FR-007 |
| Recurring finding is a spec-flow pipeline bug | Creates spec-flow shared manifest piece with severity HIGH | FR-007 |
| Main context approaches Sonnet limit mid-piece | Execute checkpoints manifest state, emits `[CONTEXT-BUDGET-WARNING]`, suggests `/compact` | FR-006 |

## Success Metrics

- **SC-001:** Spec Q&A rounds ≤3 per piece on pieces with `research.md` present (current baseline: 5–8 rounds) — Linked to: FR-001, FR-002, FR-003
- **SC-002:** Execute completes without operator prompting on ≥80% of planned pieces in a queue run — Linked to: FR-004, FR-005
- **SC-003:** Recurring findings (≥2 occurrences) are promoted to charter or spec-flow manifest within the same PRD's lifetime — Linked to: FR-007
- **SC-004:** Main orchestrator context accumulation stays below 80K tokens across a 3-piece queue run — Linked to: FR-006, NFR-001

## Priority Tiers

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| FR-001 | Pre-spec research phase | P0 | Front-loads all context; feeds FR-002 and FR-003 |
| FR-002 | Spec consumes research.md | P0 | Direct reduction in Q&A rounds — highest operator impact |
| FR-003 | Plan consumes research.md | P0 | Eliminates redundant exploration; speeds spec→execute cycle |
| FR-004 | Execute self-resolve | P0 | Makes execute safe to run unattended — prerequisite for FR-005 |
| FR-005 | Execute loop driver | P0 | Core queue-operator capability |
| FR-006 | Sonnet context discipline | P1 | Enables long multi-piece sessions without degradation |
| FR-007 | Learning flywheel | P1 | Compounds value over time; not needed for first loop run |
| NFR-001 | Research isolation | P0 | NN-C-008 compliance; fresh context per dispatch |
| NFR-002 | research.md durability | P0 | Multi-session pipeline portability |
| NFR-003 | Backward compat | P0 | NN-C-003 — mandatory for minor bump |
| NFR-004 | decisions.md review gate | P1 | Operator oversight of autonomous decisions |

## Assumptions

- **Technical:** The `Agent` tool, `ScheduleWakeup`, and `/loop` skill are all available in this Claude Code install (verified in docs/autonomous-loops-and-spec-flow.md)
- **Technical:** Sonnet is the primary model for orchestration; Opus is dispatched only for QA/review-board agents (per existing execute behavior)
- **Technical:** `research.md` fits comfortably in the piece's spec directory without requiring a new layout version
- **User behavior:** The operator will review `decisions.md` before approving the merge gate — the gate is a prompt, not enforced technically
- **User behavior:** The operator runs `/loop` or the loop driver manually; there is no automatic trigger that starts the loop without explicit operator action
- **Pipeline:** Pieces passing the plan gate have well-formed specs and plans — the loop assumes valid artifacts, not garbage-in tolerance

## Open Questions

| Question | Owner | Status |
|---|---|---|
| Should `research.md` schema be versioned (v1/v2) or free-form markdown with frontmatter? | spec author | open |
| Flywheel recurrence threshold: exactly 2 occurrences, or configurable via `.spec-flow.yaml`? | spec author | open — default 2, configurable recommended |
| Should `decisions.md` be a new artifact template or appended to `learnings.md`? | spec author | open — separate file preferred for clarity |
| Context budget ceiling for FR-006: 80K tokens or configurable? | spec author | open — 80K starting point, configurable |
| Does the loop driver live as a skill (`/spec-flow:exec-loop`) or as a docs artifact (paste-to-use prompt)? | spec author | open — docs artifact first, skill if it proves stable |

## Non-Negotiables (Product)

### NN-P-001: Human approval gate on spec and plan is never removed
- **Type:** Rule
- **Statement:** The research phase and spec/plan optimization reduce the number of Q&A rounds but do not remove the human review and sign-off step. No spec or plan may advance to execute without explicit operator approval. Automation is upstream of the gate, not a replacement for it.
- **Scope:** FR-001, FR-002, FR-003 and any future additions to the research/spec/plan pipeline
- **Rationale:** Spec and plan encode design intent. The human is the only source of ground truth on "is this the right thing to build." Removing the gate conflates "Claude found context" with "Claude made the right design decision."
- **How QA verifies:** QA-spec and qa-plan agents confirm human sign-off is still required. Any diff that removes the sign-off prompt from spec or plan skills is a must-fix.

### NN-P-002: All autonomous decisions are auditable before merge
- **Type:** Rule
- **Statement:** Every decision made autonomously during execute (FR-004) must be recorded in `decisions.md` before the Final Review gate. The Final Review gate includes a `decisions.md` review prompt. No piece may merge with autonomous decisions that were not presented to the operator.
- **Scope:** FR-004, FR-005 (loop driver must not skip the decisions.md review gate)
- **Rationale:** Operators must be able to audit what Claude decided autonomously. Silent decisions that ship to production violate the operator's oversight contract.
- **How QA verifies:** Review-board spec-compliance reviewer checks that `decisions.md` exists and is non-empty whenever the implementer self-resolved ≥1 ambiguity.

### NN-P-003: Loop driver is opt-in and operator-started only
- **Type:** Rule
- **Statement:** No automated mechanism starts the execute loop without explicit operator action. The loop driver is a prompt or skill the operator invokes deliberately. It does not run on a schedule without explicit operator setup via `/schedule`.
- **Scope:** FR-005
- **Rationale:** Unattended execution is powerful; it should never start silently. The operator must consciously choose to hand off a queue.
- **How QA verifies:** Loop driver documentation and skill (if one exists) must begin with an operator-confirmation step before the first execute dispatch.

### NN-P-004: Flywheel proposals require operator one-time approval
- **Type:** Rule
- **Statement:** The learning flywheel (FR-007) may propose charter amendments and spec-flow manifest pieces but may not apply them without operator review. A proposal presented and ignored is re-surfaced on the next flywheel run; a proposal explicitly rejected is recorded in backlog.md with rationale and not re-proposed.
- **Scope:** FR-007
- **Rationale:** Charter amendments are binding rules. Spec-flow manifest pieces become real work. Neither should be created without human intent.
- **How QA verifies:** Flywheel step contains no code path that writes to charter files or manifest without a user-confirmation prompt.
